#!/usr/bin/env python3
"""Structural validation usable without Xcode; does not compile Swift."""
from pathlib import Path
import plistlib
import json
import struct
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
for pattern in ['*.plist', '*.entitlements', '*.xcprivacy']:
    for path in root.rglob(pattern):
        plistlib.loads(path.read_bytes())
project = (root/'MyHabits.xcodeproj/project.pbxproj').read_text()
definitions = set(re.findall(r'^([0-9A-F]{24}) =', project, re.M))
references = set(re.findall(r'\b[0-9A-F]{24}\b', project))
assert definitions == references, f'Unresolved project references: {references - definitions}'
objects = dict(re.findall(r'^([0-9A-F]{24}) = \{(.*)\};$', project, re.M))
for scheme in (root/'MyHabits.xcodeproj/xcshareddata/xcschemes').glob('*.xcscheme'):
    for reference in ET.parse(scheme).iter('BuildableReference'):
        target = objects[reference.attrib['BlueprintIdentifier']]
        assert 'isa = PBXNativeTarget;' in target
        assert 'name = ' + reference.attrib['BlueprintName'] + ';' in target
personal = next(body for body in objects.values() if 'isa = PBXNativeTarget;' in body and 'name = MyHabitsPersonal;' in body)
assert 'dependencies = ();' in personal, 'Personal Team build must not depend on widgets.'
config_list_id = re.search(r'buildConfigurationList = ([0-9A-F]{24});', personal)[1]
config_ids = re.search(r'buildConfigurations = \(([^)]*)\)', objects[config_list_id])[1]
for config_id in re.findall(r'[0-9A-F]{24}', config_ids):
    assert 'PERSONAL_TEAM' in objects[config_id]
    assert 'CODE_SIGN_ENTITLEMENTS' not in objects[config_id], 'Personal build must not use App Group entitlements.'
phase_ids = re.search(r'buildPhases = \(([^)]*)\)', personal)[1]
for phase_id in re.findall(r'[0-9A-F]{24}', phase_ids):
    assert 'PBXCopyFilesBuildPhase' not in objects[phase_id], 'Personal build must not embed an extension.'
    if 'PBXSourcesBuildPhase' in objects[phase_id]:
        for build_id in re.findall(r'[0-9A-F]{24}', objects[phase_id]):
            file_id = re.search(r'fileRef = ([0-9A-F]{24});', objects[build_id])[1]
            assert 'MyHabitsWidget/' not in objects[file_id]
icon_set = root/'MyHabits/Assets.xcassets/AppIcon.appiconset'
icon_info = json.loads((icon_set/'Contents.json').read_text())
for entry in icon_info['images']:
    png = (icon_set/entry['filename']).read_bytes()
    assert png[:8] == b'\x89PNG\r\n\x1a\n'
    width, height, depth, colour_type = struct.unpack('>IIBB', png[16:26])
    assert (width, height, depth, colour_type) == (1024, 1024, 8, 2), 'App icon must be 1024px opaque RGB PNG.'
for name in ['MyHabits', 'MyHabitsPersonal']:
    target = next(body for body in objects.values() if 'isa = PBXNativeTarget;' in body and 'name = '+name+';' in body)
    config_list_id = re.search(r'buildConfigurationList = ([0-9A-F]{24});', target)[1]
    config_ids = re.search(r'buildConfigurations = \(([^)]*)\)', objects[config_list_id])[1]
    for config_id in re.findall(r'[0-9A-F]{24}', config_ids):
        assert 'ASSETCATALOG_COMPILER_APPICON_NAME = "AppIcon";' in objects[config_id]
paths = re.findall(r'path = "([^"]+)"; sourceTree = "<group>";', project)
for path in paths:
    assert (root/path).exists(), f'Missing project file: {path}'
for path in root.rglob('*.swift'):
    assert str(path.relative_to(root)) in paths, f'Swift source missing from project: {path}'
for path in root.rglob('*'):
    if path.is_file() and '.git' not in path.parts and path.suffix in {'.swift', '.py', '.md', '.pbxproj'}:
        for number, line in enumerate(path.read_text().splitlines(), 1):
            assert line == line.rstrip(), f'Trailing whitespace: {path}:{number}'
print('PASS: property lists, schemes, project references, source membership, Personal Team isolation, app icon and whitespace.')
print('Apple SDK compilation and runtime tests still require Xcode on macOS.')
