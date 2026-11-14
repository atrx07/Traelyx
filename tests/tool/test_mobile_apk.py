"""Privacy manifest and packaged model corruption checks, standard library only."""

import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

from ml import verify_mobile_apk as verifier

MANIFEST = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="io.github.atrx07.traelyx.mlbenchmark">
<application android:allowBackup="false" android:usesCleartextTraffic="false" />
<instrumentation android:name="io.github.atrx07.traelyx.mlbenchmark.BenchmarkInstrumentation" android:targetPackage="io.github.atrx07.traelyx.mlbenchmark" />
</manifest>'''


class MobilePrivacyTests(unittest.TestCase):
    def test_permission_provider_and_wrong_instrumentation_are_rejected(self):
        verifier.verify_manifest(MANIFEST)
        for modified in [MANIFEST.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/><application'),
                         MANIFEST.replace('<application', '<uses-permission-sdk-23 android:name="android.permission.INTERNET"/><application'),
                         MANIFEST.replace('false" />', 'false"><provider android:name="ai.onnxruntime.TelemetryInitializer"/></application>'),
                         MANIFEST.replace('android:targetPackage="io.github.atrx07.traelyx.mlbenchmark"', 'android:targetPackage="another.app"'),
                         MANIFEST.replace('android:allowBackup="false"', 'android:allowBackup="true"')]:
            with self.subTest(manifest=modified), self.assertRaises(ValueError):
                verifier.verify_manifest(modified)

    def test_packaged_assets_and_digests_fail_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            manifest = root / 'manifest.xml'
            manifest.write_text(MANIFEST, encoding='utf-8')
            fixtures = {'version': 'eventnet-onnx-mobile-v1', 'fixture_origin': 'generated_not_sensors_or_recorded_tasks',
                        'shape': [1, 6, 7], 'cases': [{}] * 8, 'models': {}}
            for kind in ['fp32', 'int8']:
                fixtures['models'][kind] = {'file': f'eventnet-{kind}.onnx', 'bytes': 3, 'sha256': hashlib.sha256(b'abc').hexdigest()}
            for variation in ['valid', 'digest', 'extra', 'abi']:
                apk = root / (variation + '.apk')
                with zipfile.ZipFile(apk, 'w') as archive:
                    archive.writestr('assets/fixtures.json', json.dumps(fixtures))
                    for kind in ['fp32', 'int8']:
                        archive.writestr(f'assets/eventnet-{kind}.onnx', b'bad' if variation == 'digest' else b'abc')
                    for library in ['libonnxruntime.so', 'libonnxruntime4j_jni.so']:
                        archive.writestr('lib/arm64-v8a/' + library, b'library')
                    if variation == 'extra': archive.writestr('assets/private.csv', b'forbidden')
                    if variation == 'abi': archive.writestr('lib/x86/test.so', b'forbidden')
                if variation == 'valid':
                    self.assertEqual(verifier.verify(apk, manifest)['permissions'], [])
                else:
                    with self.assertRaises(ValueError): verifier.verify(apk, manifest)


if __name__ == '__main__':
    unittest.main()
