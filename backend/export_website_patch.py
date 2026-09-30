"""Export only Python source changes from the inspected website checkout."""
import argparse
import ast
import difflib
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--checkout', default='.repo_ref/website-batches-6-13')
args = parser.parse_args()
root = Path(args.checkout)
files = subprocess.check_output(['git', '-C', str(root), 'diff', '--name-only'], text=True).splitlines()
files += subprocess.check_output(['git', '-C', str(root), 'ls-files', '--others', '--exclude-standard'], text=True).splitlines()
patch = []
count = 0
for filename in sorted(set(files)):
    if not filename.endswith('.py') or not filename.startswith('v2-supabase-live/'):
        continue
    try:
        old = subprocess.check_output(['git', '-C', str(root), 'show', 'HEAD:' + filename], stderr=subprocess.DEVNULL).decode('utf-8-sig').replace('\r\n', '\n')
    except subprocess.CalledProcessError:
        old = ''
    new = (root / filename).read_text(encoding='utf-8-sig')
    ast.parse(new, filename=filename)
    diff = difflib.unified_diff(old.splitlines(True), new.splitlines(True), fromfile='a/' + filename if old else '/dev/null', tofile='b/' + filename)
    for line in diff:
        patch.append(line if line.endswith('\n') else line + '\n\\ No newline at end of file\n')
    count += 1
out = Path(__file__).with_name('website-batches-6-13.patch')
out.write_text(''.join(patch), encoding='utf-8')
print(f'Exported {count} Python files to {out}')
