import hashlib
import io
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest import mock

from ml import qualify_eventnet_sources as q


HEADER = 'start,end,event,target,timesync,sample\n'


def database(rows=None, extra_sql=None):
    connection = sqlite3.connect(":memory:")
    try:
        connection.execute("CREATE TABLE SENSOR_TABLE (TIME DATETIME, ACCEL_X REAL, ACCEL_Y REAL, ACCEL_Z REAL, GYRO_X REAL, GYRO_Y REAL, GYRO_Z REAL, CURRENT_SPEED REAL, ACTIVITY TEXT)")
        connection.executemany("INSERT INTO SENSOR_TABLE VALUES (?,?,?,?,?,?,?,?,?)", rows or [
            ("12:34:56", 1.23456789, -2.987654321, 9.71, 0.12, 0.23, 0.34, 12.5, "Brake"),
            ("12:34:56", 1, 2, 3, 4, 5, 6, 7, "Idling"),
            ("12:34:55", 1, 2, 3, 4, 5, 6, 7, "Aggressive Brake"),
        ])
        if extra_sql:
            connection.execute(extra_sql)
        connection.commit()
        return connection.serialize()
    finally:
        connection.close()


class SourceQualificationTest(unittest.TestCase):
    def test_exact_decimal_intervals_and_explicit_release_aliases(self):
        raw = (HEADER+'0.1,0.3,non-aggressive event,0,1,0\n'
               '0.3,0.6,evento n\u00e3o agressivo,0,1,1\n'
               '0.6,1.1,aggressive lane change to the right ,3,1,2\n').encode()
        report = q.label_summary(raw)
        self.assertEqual(report['annotated_nonaggressive_seconds'], 0.5)
        self.assertEqual(report['intervals'], 3)
        self.assertEqual(report['explicit_spelling_aliases'], 2)

    def test_rejects_ambiguous_or_inconsistent_label_intervals(self):
        bad = ['1,2,aggressive braking,1,0,0', '2,1,aggressive braking,4,0,0',
               'NaN,2,aggressive braking,4,0,0', '0,Infinity,aggressive braking,4,0,0',
               '0,2,aggressive braking,4,0,1', '0,2,aggressive braking,4,-1,0',
               '0,2,inferred normal,0,0,0', '0,2,aggressive braking,4,0,0,unexpected']
        for row in bad:
            with self.subTest(row=row), self.assertRaises(q.InvalidSource):
                q.label_summary((HEADER+row+'\n').encode())
        for tail in ['1,3,aggressive braking,4,0,1', '2,3,aggressive braking,4,1,1']:
            with self.assertRaises(q.InvalidSource):
                q.label_summary((HEADER+'0,2,aggressive braking,4,0,0\n'+tail+'\n').encode())

    def test_rejects_empty_wrong_schema_and_oversized_labels(self):
        for raw in [b'', HEADER.encode(), b'start,end,event\n0,1,normal\n', b'x'*16385]:
            with self.assertRaises(q.InvalidSource):
                q.label_summary(raw)

    def test_database_only_emits_schema_and_quality_aggregates(self):
        report = q.harvard_summary(database())
        self.assertEqual(report['rows'], 3)
        self.assertEqual(report['adjacent_equal_timestamp_pairs'], 1)
        self.assertEqual(report['adjacent_backward_timestamp_pairs'], 1)
        self.assertIsNone(report['verified_ordinary_driving_exposure_seconds'])
        self.assertFalse(report['driver_or_trip_column_present'])
        rendered = json.dumps(report)
        for private in ['12:34:56', '12:34:55', '1.23456789', '-2.987654321']:
            self.assertNotIn(private, rendered)

    def test_database_rejects_views_triggers_and_unexpected_tables(self):
        for sql in ['CREATE VIEW private_view AS SELECT * FROM SENSOR_TABLE',
                    'CREATE TABLE private_accounts (email TEXT)',
                    'CREATE TRIGGER unexpected AFTER INSERT ON SENSOR_TABLE BEGIN DELETE FROM SENSOR_TABLE; END']:
            with self.subTest(sql=sql), self.assertRaises(q.InvalidSource):
                q.harvard_summary(database(extra_sql=sql))

    def test_database_rejects_invalid_time_labels_and_numeric_values(self):
        original = ['12:34:56', 1, 2, 3, 4, 5, 6, 7, 'Brake']
        for index, value in [(0, '24:00:00'), (0, '12:99:00'), (0, 'private-date'),
                             (8, 'unknown normal'), (2, float('inf')), (3, None), (4, 'not numeric')]:
            row = original.copy(); row[index] = value
            with self.subTest(index=index, value=value), self.assertRaises(q.InvalidSource):
                q.harvard_summary(database(rows=[tuple(row)]))

    def test_database_bounds_and_wrong_schema_fail_closed(self):
        with mock.patch.object(q, 'MAX_ROWS', 1), self.assertRaises(q.InvalidSource):
            q.harvard_summary(database())
        for raw in [b'', b'not a database', b'x'*(16*1024*1024+1)]:
            with self.assertRaises((q.InvalidSource, sqlite3.Error)):
                q.harvard_summary(raw)
        connection = sqlite3.connect(':memory:')
        try:
            connection.execute('CREATE TABLE SENSOR_TABLE (TIME TEXT)')
            with self.assertRaises(q.InvalidSource):
                q.harvard_summary(connection.serialize())
        finally:
            connection.close()

    def test_pinned_snapshot_preserves_source_and_rejects_hash_or_size_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'input.db'; raw = database(); path.write_bytes(raw)
            pin = (len(raw), hashlib.sha256(raw).hexdigest())
            self.assertEqual(q.pinned_bytes(path, pin), raw)
            self.assertEqual(path.read_bytes(), raw)
            for invalid in [(len(raw)+1, pin[1]), (len(raw), '0'*64)]:
                with self.assertRaises(q.InvalidSource):
                    q.pinned_bytes(path, invalid)
            self.assertEqual(list(Path(directory).iterdir()), [path])

    def test_even_valid_data_is_qualification_only_with_no_inferred_admission(self):
        with mock.patch.object(q, 'pinned_bytes', return_value=database()):
            result = q.qualify('harvard-f5jzhf-v1', Path('unused'))
        for field in ['training_admitted', 'production_evaluation_admitted', 'model_predictions_computed', 'fresh_locked_evaluation_eligible']:
            self.assertFalse(result[field])
        self.assertIn('driver_trip_grouping_missing', result['blocking_evidence'])

    def test_zenodo_aggregate_keeps_single_driver_and_stream_limits_explicit(self):
        raw = (HEADER+'0,1,non-aggressive event,0,0,0\n1,2,aggressive braking,4,0,1\n').encode()
        with mock.patch.object(q, 'pinned_bytes', return_value=raw):
            result = q.qualify('zenodo-6570972-v1-labels', Path('unused'))
        self.assertEqual(result['findings']['intervals'], 6)
        self.assertEqual(result['findings']['publisher_driver_count'], 1)
        self.assertFalse(result['findings']['streams_inspected'])
        self.assertFalse(result['training_admitted'])

    def test_cli_failure_hides_input_path_and_database_error(self):
        import contextlib
        captured = io.StringIO()
        with mock.patch('sys.argv', ['qualify', '--source', 'harvard-f5jzhf-v1', '--input', 'private-home-route.db']), contextlib.redirect_stderr(captured):
            self.assertEqual(q.main(), 2)
        self.assertNotIn('private-home', captured.getvalue())
        self.assertNotIn('Traceback', captured.getvalue())


if __name__ == '__main__':
    unittest.main()
