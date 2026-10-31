#!/usr/bin/env python3
"""Bundle the repository's real update history for the in-app acknowledgements page."""
import json
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parent.parent
history = subprocess.check_output(['git', 'log', '--format=%h%x09%s'], cwd=root, text=True)
entries = [{'id': 'current-release', 'title': 'Open update history and supporters with an expanding lightning animation.'}]
for line in history.splitlines():
    identifier, title = line.split('\t', 1)
    entries.append({'id': identifier, 'title': title})
(root / 'MyHabits/UpdateHistory.json').write_text(json.dumps(entries, ensure_ascii=False, indent=2) + '\n')
print(f'Bundled {len(entries)} update entries.')
