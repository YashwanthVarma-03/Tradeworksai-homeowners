"""Export reviewed changes rebased on the current platform main checkout."""
from pathlib import Path
import os
import subprocess

root = Path(__file__).resolve().parents[1]
checkout = root / '.repo_ref/platform-current-20260930'
paths = [
    'backend/services/api/homeowner/routes.py',
    'backend/services/api/homeowner/home_profile_routes.py',
    'backend/services/api/homeowner/account_routes.py',
    'backend/services/api/public/routes.py',
    'backend/services/api/contractor/routes.py',
    'backend/services/api/shared/routes.py',
    'backend/services/api/shared/notify.py',
    'backend/sql/rpcs/book_slot.sql',
    'backend/sql/rpcs/public_contractor_search_pre.sql',
    'backend/sql/rpcs/public_contractor_profile_get.sql',
]
local_migrations = [
    'backend/migrations/20260926_review_metadata.sql',
    'backend/migrations/20260926_arrival_cases.sql',
    'backend/migrations/20260928_platform_home_context.sql',
]
git_env = dict(os.environ, GIT_NO_LAZY_FETCH='1')
patch = subprocess.run(['git', '-c', f'safe.directory={checkout.as_posix()}',
                        '-C', str(checkout), 'diff', 'HEAD', '--no-color',
                        '--full-index', '--', *paths], check=True,
                       capture_output=True, env=git_env).stdout
# Migrations are authored in this app workspace because the sparse platform
# checkout does not contain a migrations directory. Include them as new files.
for relative in local_migrations:
    candidate = root / relative
    if not candidate.is_file():
        raise FileNotFoundError(candidate)
    patch += subprocess.run(['git', 'diff', '--no-index', '--no-color', '--full-index',
                             '--', os.devnull, relative], cwd=root, capture_output=True).stdout
output = root / 'backend/platform-batches-1-17-current.patch'
output.write_bytes(patch)
print(f'Exported {len(patch)} bytes to {output}')
