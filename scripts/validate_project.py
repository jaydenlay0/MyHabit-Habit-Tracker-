#!/usr/bin/env python3
"""Structural validation usable without Xcode; does not compile Swift."""
from pathlib import Path
import plistlib
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
for pattern in ['*.plist', '*.entitlements', '*.xcprivacy']:
    for path in root.rglob(pattern):
        plistlib.loads(path.read_bytes())
ET.parse(root/'MyHabits.xcodeproj/xcshareddata/xcschemes/MyHabits.xcscheme')
project = (root/'MyHabits.xcodeproj/project.pbxproj').read_text()
definitions = set(re.findall(r'^([0-9A-F]{24}) =', project, re.M))
references = set(re.findall(r'\b[0-9A-F]{24}\b', project))
assert definitions == references, f'Unresolved project references: {references - definitions}'
paths = re.findall(r'path = "([^"]+)"; sourceTree = "<group>";', project)
for path in paths:
    assert (root/path).is_file(), f'Missing project file: {path}'
for path in root.rglob('*.swift'):
    assert str(path.relative_to(root)) in paths, f'Swift source missing from project: {path}'
for path in root.rglob('*'):
    if path.is_file() and '.git' not in path.parts and path.suffix in {'.swift', '.py', '.md', '.pbxproj'}:
        for number, line in enumerate(path.read_text().splitlines(), 1):
            assert line == line.rstrip(), f'Trailing whitespace: {path}:{number}'
print('PASS: property lists, scheme XML, project references, source membership and whitespace.')
print('Apple SDK compilation and runtime tests still require Xcode on macOS.')
