#!/usr/local/bin/python3.9
import os
import pathlib
import sys
from shutil import which

# work around https://github.com/Homebrew/homebrew-core/issues/30445
os.environ.pop('__PYVENV_LAUNCHER__', None)
ARGS = ['hook-impl', '--config=.pre-commit-config.yaml', f'--hook-type={pathlib.Path(__file__).name}',
        '--skip-on-missing-config']
ARGS.extend(('--hook-dir', os.path.realpath(os.path.dirname(__file__))))
ARGS.append('--')
ARGS.extend(sys.argv[1:])

DNE = '`pre-commit` not found'
if which('pre-commit'):
    CMD = ['pre-commit']
else:
    raise SystemExit(DNE)

CMD.extend(ARGS)
os.execvp(CMD[0], CMD)
