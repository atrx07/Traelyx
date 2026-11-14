"""Generated-data export/runtime regressions; no dataset downloads or phone access."""

from pathlib import Path
import json
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
import onnx
import torch

from ml import datasets as ds, eventnet as net, mobile_export as mobile


class MobileExportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        torch.set_num_threads(1)
        torch.manual_seed(7)
        cls.temporary = tempfile.TemporaryDirectory()
        cls.root = Path(cls.temporary.name)
        cls.inputs = mobile.generated_inputs()
        cls.normalizer = net.fit_normalizer(torch.from_numpy(np.concatenate(cls.inputs)))
        cls.model = net.EventNet().eval()
        cls.wrapper = mobile.export_pair(cls.model, cls.normalizer, cls.inputs, cls.root / 'one')
        cls.sessions = {kind: mobile.session(cls.root / 'one' / name) for kind, name in mobile.MODEL_FILES.items()}

    @classmethod
    def tearDownClass(cls):
        cls.sessions.clear()
        cls.temporary.cleanup()

    def test_fp32_parity_and_finite_quantized_outputs(self):
        for value in self.inputs:
            with torch.inference_mode():
                expected = self.model(net.normalize(torch.from_numpy(value), self.normalizer)).numpy()[0]
            np.testing.assert_allclose(mobile.predict(self.sessions['fp32'], value), expected, rtol=0, atol=1e-4)
            self.assertTrue(np.isfinite(mobile.predict(self.sessions['int8'], value)).all())

    def test_static_shape_and_quantized_graph(self):
        graph = onnx.load(self.root / 'one' / mobile.MODEL_FILES['int8'])
        self.assertEqual([v.dim_value for v in graph.graph.input[0].type.tensor_type.shape.dim], [1, 6, 7])
        self.assertTrue(any(v.data_type == onnx.TensorProto.INT8 for v in graph.graph.initializer))
        self.assertTrue(any(v.op_type == 'DequantizeLinear' for v in graph.graph.node))

    def test_export_repeat_is_byte_identical(self):
        mobile.export_pair(self.model, self.normalizer, self.inputs, self.root / 'two')
        for filename in mobile.MODEL_FILES.values():
            self.assertEqual((self.root / 'one' / filename).read_bytes(), (self.root / 'two' / filename).read_bytes())

    def test_reader_copies_only_supplied_windows_and_stops(self):
        supplied = [self.inputs[0].copy()]
        reader = mobile.TrainingReader(supplied)
        supplied[0][:] = 123
        self.assertEqual(float(reader.get_next()['features'][0, 0, 0]), 0)
        self.assertIsNone(reader.get_next())
        with self.assertRaises(ds.InvalidDataset):
            mobile.TrainingReader([])

    def test_invalid_shapes_types_and_numbers_fail_before_runtime(self):
        for value in [np.zeros((1, 7, 6), dtype=np.float32), np.zeros((1, 6, 7)),
                      np.full((1, 6, 7), np.nan, dtype=np.float32),
                      np.full((1, 6, 7), np.inf, dtype=np.float32)]:
            with self.subTest(shape=value.shape), self.assertRaises(ds.InvalidDataset):
                mobile.predict(self.sessions['fp32'], value)

    def test_invalid_normalization_and_temperature_rejected(self):
        with self.assertRaises(ds.InvalidDataset):
            mobile.NormalizedModel(self.model, {'mean': [[[0]]], 'scale': [[[1]]]})
        for temperature in [0, float('nan'), float('inf')]:
            with self.assertRaises(ds.InvalidDataset):
                mobile.probabilities(np.zeros(4), temperature)
        np.testing.assert_allclose(mobile.probabilities(np.array([10000, 0, -10000, 1]), 1).sum(), 1)

    def test_corrupt_model_and_existing_destination_fail_closed(self):
        broken = self.root / 'broken.onnx'
        broken.write_bytes(b'not a model')
        with self.assertRaises(Exception):
            mobile.session(broken)
        with self.assertRaises(ds.InvalidDataset):
            mobile.export_pair(self.model, self.normalizer, self.inputs, self.root / 'one')

    def test_orchestration_uses_training_only_and_retains_rejection(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'ml/checkpoints').mkdir(parents=True)
            calibrator = {'source_model_sha256': 'frozen-model', 'production_eligible': False, 'temperature': 1.0}
            raw = ds.canonical_json(calibrator)
            (root / 'calibrator.json').write_bytes(raw)
            manifest = {'generated': True}
            baseline = {'model_sha256': 'frozen-model', 'import_manifest_sha256': ds.sha256(ds.canonical_json(manifest)),
                        'attribution': 'Generated test only'}
            audit = {'calibrator_sha256': ds.sha256(raw), 'limitations': ['Generated test only']}
            partitions = {name: [{'label': 0, 'values': np.full((7, 6), sentinel).tolist()}]
                          for name, sentinel in [('train', 1), ('validation', 10), ('test', 100)]}

            def export(model, normalizer, training, destination):
                self.assertEqual(len(training), 1)
                np.testing.assert_array_equal(training[0], np.ones((1, 6, 7), dtype=np.float32))
                destination.mkdir()
                for filename in mobile.MODEL_FILES.values(): (destination / filename).write_bytes(b'generated')

            def comparison(wrapper, sessions, rows, temperature):
                return {'fp32_max_logit_error': 0, 'int8_max_probability_error': .051,
                        'fp32_metrics': {'macro_f1': .5}, 'int8_metrics': {'macro_f1': .5}}

            with patch.object(ds, 'ROOT', root), patch.object(mobile.cal, 'load_frozen', return_value=(None, None, baseline, b'preserved')), \
                 patch.object(ds, 'load_json', return_value=audit), patch.object(net, 'imported_windows', return_value=(partitions, manifest)), \
                 patch.object(mobile, 'export_pair', side_effect=export) as exporter, patch.object(mobile, 'session'), \
                 patch.object(mobile, 'compare', side_effect=comparison), patch.object(mobile, 'predict', return_value=np.zeros(4)), \
                 patch.object(mobile, 'provenance', return_value={'export_source_dirty': False}):
                result = mobile.run(root, root, root, 'generated-rejected')
                self.assertFalse(result['quantized_numerical_gate_pass'])
                self.assertFalse(result['production_eligible'])
                self.assertEqual(exporter.call_count, 1)
                saved = json.loads((root / 'ml/checkpoints/generated-rejected/export-report.json').read_bytes())
                self.assertFalse(saved['quantized_numerical_gate_pass'])
                self.assertEqual((root / 'calibrator.json').read_bytes(), raw)
                with self.assertRaises(ds.InvalidDataset): mobile.run(root, root, root, 'generated-rejected')
                self.assertEqual(exporter.call_count, 1)


if __name__ == '__main__':
    unittest.main()
