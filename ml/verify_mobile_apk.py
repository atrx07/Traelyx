"""Fail closed on the standalone benchmark's packaged privacy/asset contract."""

import argparse
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET
import zipfile

PACKAGE = 'io.github.atrx07.traelyx.mlbenchmark'
ANDROID = '{http://schemas.android.com/apk/res/android}'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify_manifest(text):
    require(len(text) <= 100000, 'manifest too large')
    root = ET.fromstring(text)
    require(root.tag == 'manifest' and root.get('package') == PACKAGE, 'unexpected package')
    require(not any(element.tag.startswith('uses-permission') for element in root.iter()), 'permissions forbidden')
    application = root.find('application')
    require(application is not None and application.get(ANDROID + 'allowBackup') == 'false', 'backup forbidden')
    require(application.get(ANDROID + 'usesCleartextTraffic') == 'false', 'cleartext forbidden')
    require(not any(application.findall(tag) for tag in ['provider', 'activity', 'activity-alias', 'service', 'receiver']),
            'application components forbidden')
    instruments = root.findall('instrumentation')
    require(len(instruments) == 1 and instruments[0].get(ANDROID + 'targetPackage') == PACKAGE and
            instruments[0].get(ANDROID + 'name') == PACKAGE + '.BenchmarkInstrumentation', 'self-targeting instrumentation required')


def verify(apk, manifest):
    verify_manifest(manifest.read_text(encoding='utf-8-sig'))
    with zipfile.ZipFile(apk) as archive:
        names = archive.namelist()
        require(len(names) == len(set(names)), 'duplicate ZIP entries')
        assets = {name for name in names if name.startswith('assets/') and not name.endswith('/')}
        require(assets == {'assets/fixtures.json', 'assets/eventnet-fp32.onnx', 'assets/eventnet-int8.onnx'}, 'unexpected assets')
        require(archive.getinfo('assets/fixtures.json').file_size <= 100000, 'fixtures too large')
        fixtures = json.loads(archive.read('assets/fixtures.json'))
        require(fixtures['version'] == 'eventnet-onnx-mobile-v1' and
                fixtures['fixture_origin'] == 'generated_not_sensors_or_recorded_tasks' and
                fixtures['shape'] == [1, 6, 7] and len(fixtures['cases']) == 8, 'fixture contract mismatch')
        for kind in ['fp32', 'int8']:
            metadata = fixtures['models'][kind]
            name = f'eventnet-{kind}.onnx'
            require(metadata['file'] == name, 'unexpected model name')
            require(archive.getinfo('assets/' + name).file_size <= 1000000, 'model too large')
            model = archive.read('assets/' + name)
            require(len(model) == metadata['bytes'] and hashlib.sha256(model).hexdigest() == metadata['sha256'], 'model digest mismatch')
        native = {name for name in names if name.startswith('lib/') and not name.endswith('/')}
        require(native == {'lib/arm64-v8a/libonnxruntime.so', 'lib/arm64-v8a/libonnxruntime4j_jni.so'}, 'unexpected native runtime/ABI')
        return {'package': PACKAGE, 'permissions': [], 'providers': [],
                'apk_bytes': apk.stat().st_size, 'apk_sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
                'fixtures_sha256': hashlib.sha256(archive.read('assets/fixtures.json')).hexdigest(),
                'native_bytes': {name: archive.getinfo(name).file_size for name in sorted(native)}}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('manifest', type=Path, help='UTF-8 apkanalyzer manifest print output from this exact APK')
    args = parser.parse_args()
    print(json.dumps(verify(args.apk, args.manifest), sort_keys=True))
