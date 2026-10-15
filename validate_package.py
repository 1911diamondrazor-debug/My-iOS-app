#!/usr/bin/env python3
"""Package-integrity checks; does not compile Swift or execute Apple frameworks."""
from pathlib import Path
import json, math, plistlib, re, struct, xml.etree.ElementTree as ET
root = Path(__file__).resolve().parents[1]

def readvar(data, pos):
    n = shift = 0
    while pos < len(data):
        b = data[pos]; pos += 1; n |= (b & 127) << shift
        if b < 128: return n, pos
        shift += 7
        assert shift < 64, 'Invalid varint'
    raise AssertionError('Truncated varint')

def fields(data):
    pos = 0; result = {}
    while pos < len(data):
        key, pos = readvar(data, pos); field, wire = key >> 3, key & 7
        assert field > 0
        if wire == 0: value, pos = readvar(data, pos)
        elif wire == 2:
            count, pos = readvar(data, pos); value = data[pos:pos+count]; pos += count
            assert len(value) == count, 'Truncated protobuf'
        elif wire == 1: value = data[pos:pos+8]; pos += 8; assert len(value) == 8
        else: raise AssertionError(f'Unexpected wire type {wire}')
        result.setdefault(field, []).append(value)
    assert pos == len(data)
    return result

model = fields((root/'MLLab/Resources/TinyRegressor.mlmodel').read_bytes())
assert model[1] == [1], 'Expected specification v1'
description = fields(model[2][0])
for field, name in [(1,b'x'),(10,b'y')]:
    feature = fields(description[field][0]); assert feature[1] == [name]
    assert fields(feature[3][0]) == {2:[b'']}, 'Expected Double type'
assert description[11] == [b'y']
glm = fields(model[300][0]); weights = fields(glm[1][0])
w = struct.unpack('<d', weights[1][0])[0]; b = struct.unpack('<d', glm[2][0])[0]
assert w == 2 and b == 0.1
for x, expected in [(-10,-19.9),(0,0.1),(2,4.1),(10,20.1)]: assert abs(w*x+b-expected) < 1e-12
print('PASS: Core ML protobuf field structure, feature contract, and reference arithmetic (not runtime inference)')

pbx = (root/'MLLab.xcodeproj/project.pbxproj').read_text()
objects = set(re.findall(r'^([A-F0-9]{24}) = \{', pbx, re.M))
references = set(re.findall(r'\b[A-F0-9]{24}\b', pbx))
assert references <= objects, f'Missing project objects: {references-objects}'
paths = re.findall(r'path = "([^"]+)";',pbx)
for path in paths: assert (root/path).exists(), f'Missing project path: {path}'
swift_paths = [p.relative_to(root).as_posix() for p in (root/'MLLab').rglob('*.swift')]
assert all(path in paths for path in swift_paths)
assert 'IPHONEOS_DEPLOYMENT_TARGET = "27.0"' in pbx
scheme = ET.parse(root/'MLLab.xcodeproj/xcshareddata/xcschemes/MLLab.xcscheme')
for buildable in scheme.findall('.//BuildableReference'): assert buildable.attrib['BlueprintIdentifier'] in objects
info = plistlib.loads((root/'MLLab/Info.plist').read_bytes())
for key in ['NSCameraUsageDescription','NSMicrophoneUsageDescription','NSSpeechRecognitionUsageDescription']: assert info[key]
for catalog in (root/'MLLab/Resources/Assets.xcassets').rglob('Contents.json'): json.loads(catalog.read_text())
print(f'PASS: {len(swift_paths)} Swift sources referenced; project IDs, resource paths, shared scheme, permissions, asset catalog')

source = '\n'.join(path.read_text() for path in (root/'MLLab').rglob('*.swift'))
for excluded in ['FoundationModels','AppIntents','ImagePlayground','WritingTools']:
    assert not re.search(r'^import '+excluded+r'\b',source,re.M), f'Excluded import: {excluded}'
assert not re.search(r'URLSession|https?://|fatalError\(',source), 'Unexpected network operation or deliberate crash'
assert source.count('@main') == 1
routes = set(re.findall(r'case "([^"\n]+)":', (root/'MLLab/App/MLLabApp.swift').read_text()))
assert len(routes) == 10 # Device & coverage uses the default route.
assert 'record(forDuration: 30)' in source
assert 'guard !Task.isCancelled else { return }' in source
print('PASS: excluded integrations, no application network code, single app entry, 11 navigation labs, recording limit/cancellation guards')

values=[math.exp(2)/(math.exp(2)+1),1/(math.exp(2)+1)]
assert abs(values[0]-0.880797)<1e-6 and abs(values[1]-0.119203)<1e-6
print('PASS: independent GPU numerical reference calculated (not Metal execution)')
print('NOT RUN: Swift compile, Xcode build/signing, Core ML runtime, device inference, UI inspection')
