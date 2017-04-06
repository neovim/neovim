#!/usr/bin/env python

import sys
import re
import os

from subprocess import Popen, PIPE
from argparse import ArgumentParser


GENERATED_INCLUDE_RE = re.compile(
  r'^\s*#\s*include\s*"([/a-z_0-9.]+\.generated\.h)"(\s+//.*)?$')


def main(argv):
  argparser = ArgumentParser()
  argparser.add_argument('--generated-includes-dir', action='append',
                         help='Directory where generated includes are located.')
  argparser.add_argument('--file', type=open, help='File to check.')
  argparser.add_argument('iwyu_args', nargs='*',
                         help='IWYU arguments, must go after --.')
  args = argparser.parse_args(argv)

  with args.file:
    include_dirs = []

    iwyu = Popen(['include-what-you-use', '-xc'] + args.iwyu_args + ['/dev/stdin'],
                stdin=PIPE, stdout=PIPE, stderr=PIPE)

    for line in args.file:
      match = GENERATED_INCLUDE_RE.match(line)
      if match:
        for d in args.generated_includes_dir:
          try:
            f = open(os.path.join(d, match.group(1)))
          except IOError:
            continue
          else:
            with f:
              for generated_line in f:
                iwyu.stdin.write(generated_line)
              break
        else:
          raise IOError('Failed to find {0}'.format(match.group(1)))
      else:
        iwyu.stdin.write(line)

  iwyu.stdin.close()

  out = iwyu.stdout.read()
  err = iwyu.stderr.read()

  ret = iwyu.wait()

  if ret != 2:
    print('IWYU failed with exit code {0}:'.format(ret))
    print('{0} stdout {0}'.format('=' * ((80 - len(' stdout ')) // 2)))
    print(out)
    print('{0} stderr {0}'.format('=' * ((80 - len(' stderr ')) // 2)))
    print(err)
    return 1
  return 0


if __name__ == '__main__':
  raise SystemExit(main(sys.argv[1:]))
