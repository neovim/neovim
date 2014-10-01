# Run functional tests using lua, busted and the python client

import os
import sys
import textwrap

from lupa import LuaRuntime, as_attrgetter
from neovim import Nvim, spawn_session


# Extract arguments
busted_script = sys.argv[1]
busted_argv = sys.argv[2:]

# Setup a lua state for running busted
lua = LuaRuntime(unpack_returned_tuples=True)
lua_globals = lua.globals()

# helper to transform iterables into lua tables
list_to_table = lua.eval('''
function(l)
  local t = {}
  for i, item in python.enumerate(l) do t[i + 1] = item end
  return t
end
''')

dict_to_table = lua.eval('''
function(d)
  local t = {}
  for k, v in python.iterex(d.items()) do t[k] = v end
  return t
end
''')

def to_table(obj):
    if type(obj) in [tuple, list]:
        return list_to_table(list(to_table(e) for e in obj))
    if type(obj) is dict:
        return dict_to_table(as_attrgetter(
            dict((k, to_table(v)) for k, v in obj.items())))
    return obj

nvim_prog = os.environ.get('NVIM_PROG', 'build/bin/nvim')
nvim_argv = [nvim_prog, '-u', 'NONE', '--embed']

if 'VALGRIND' in os.environ:
    log_file = os.environ.get('VALGRIND_LOG', 'valgrind-%p.log')
    valgrind_argv = ['valgrind', '-q', '--tool=memcheck', '--leak-check=yes',
                     '--track-origins=yes', '--suppressions=.valgrind.supp',
                     '--log-file={0}'.format(log_file)]
    if 'VALGRIND_GDB' in os.environ:
        valgrind_argv += ['--vgdb=yes', '--vgdb-error=0']
    nvim_argv = valgrind_argv + nvim_argv

session = spawn_session(nvim_argv)
nvim = Nvim.from_session(session)

def nvim_command(cmd):
    nvim.command(cmd)

def nvim_eval(expr):
    return to_table(nvim.eval(expr))

def nvim_feed(input, mode=''):
    nvim.feedkeys(input)

def buffer_slice(start=None, stop=None, buffer_idx=None):
    rv = '\n'.join(nvim.buffers[buffer_idx or 0][start:stop])
    return rv

def nvim_replace_termcodes(input, *opts):
    return nvim.replace_termcodes(input, *opts)

expose = [
    nvim_command,
    nvim_eval,
    nvim_feed,
    nvim_replace_termcodes,
    buffer_slice,
    textwrap.dedent,
]

for fn in expose:
    lua_globals[fn.__name__] = fn

# Set 'arg' global to let busted parse arguments
lua_globals['arg'] = list_to_table(busted_argv)

# Read the busted script and execute in the lua state
with open(busted_script) as f:
    busted_setup = f.read()
lua.execute(busted_setup)
