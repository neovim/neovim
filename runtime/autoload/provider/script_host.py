"""Legacy python/python3-vim emulation."""
import imp
import io
import logging
import os
import sys

import neovim

__all__ = ('ScriptHost',)


logger = logging.getLogger(__name__)
debug, info, warn = (logger.debug, logger.info, logger.warn,)

IS_PYTHON3 = sys.version_info >= (3, 0)

if IS_PYTHON3:
    basestring = str

    if sys.version_info >= (3, 4):
        from importlib.machinery import PathFinder


@neovim.plugin
class ScriptHost(object):

    """Provides an environment for running python plugins created for Vim."""

    def __init__(self, nvim):
        """Initialize the legacy python-vim environment."""
        self.setup(nvim)
        # context where all code will run
        self.module = imp.new_module('__main__')
        nvim.script_context = self.module
        # it seems some plugins assume 'sys' is already imported, so do it now
        exec('import sys', self.module.__dict__)
        self.legacy_vim = nvim.with_hook(LegacyEvalHook())
        sys.modules['vim'] = self.legacy_vim

    def setup(self, nvim):
        """Setup import hooks and global streams.

        This will add import hooks for importing modules from runtime
        directories and patch the sys module so 'print' calls will be
        forwarded to Nvim.
        """
        self.nvim = nvim
        info('install import hook/path')
        self.hook = path_hook(nvim)
        sys.path_hooks.append(self.hook)
        nvim.VIM_SPECIAL_PATH = '_vim_path_'
        sys.path.append(nvim.VIM_SPECIAL_PATH)
        info('redirect sys.stdout and sys.stderr')
        self.saved_stdout = sys.stdout
        self.saved_stderr = sys.stderr
        sys.stdout = RedirectStream(lambda data: nvim.out_write(data))
        sys.stderr = RedirectStream(lambda data: nvim.err_write(data))

    def teardown(self):
        """Restore state modified from the `setup` call."""
        for plugin in self.installed_plugins:
            if hasattr(plugin, 'on_teardown'):
                plugin.teardown()
        nvim = self.nvim
        info('uninstall import hook/path')
        sys.path.remove(nvim.VIM_SPECIAL_PATH)
        sys.path_hooks.remove(self.hook)
        info('restore sys.stdout and sys.stderr')
        sys.stdout = self.saved_stdout
        sys.stderr = self.saved_stderr

    @neovim.rpc_export('python_execute', sync=True)
    def python_execute(self, script, range_start, range_stop):
        """Handle the `python` ex command."""
        self._set_current_range(range_start, range_stop)
        exec(script, self.module.__dict__)

    @neovim.rpc_export('python_execute_file', sync=True)
    def python_execute_file(self, file_path, range_start, range_stop):
        """Handle the `pyfile` ex command."""
        self._set_current_range(range_start, range_stop)
        with open(file_path) as f:
            script = compile(f.read(), file_path, 'exec')
            exec(script, self.module.__dict__)

    @neovim.rpc_export('python_do_range', sync=True)
    def python_do_range(self, start, stop, code):
        """Handle the `pydo` ex command."""
        self._set_current_range(start, stop)
        nvim = self.nvim
        start -= 1
        stop -= 1
        fname = '_vim_pydo'

        # define the function
        function_def = 'def %s(line, linenr):\n %s' % (fname, code,)
        exec(function_def, self.module.__dict__)
        # get the function
        function = self.module.__dict__[fname]
        while start <= stop:
            # Process batches of 5000 to avoid the overhead of making multiple
            # API calls for every line. Assuming an average line length of 100
            # bytes, approximately 488 kilobytes will be transferred per batch,
            # which can be done very quickly in a single API call.
            sstart = start
            sstop = min(start + 5000, stop)
            lines = nvim.current.buffer.get_line_slice(sstart, sstop, True,
                                                       True)

            exception = None
            newlines = []
            linenr = sstart + 1
            for i, line in enumerate(lines):
                result = function(line, linenr)
                if result is None:
                    # Update earlier lines, and skip to the next
                    if newlines:
                        end = sstart + len(newlines) - 1
                        nvim.current.buffer.set_line_slice(sstart, end,
                                                           True, True,
                                                           newlines)
                    sstart += len(newlines) + 1
                    newlines = []
                    pass
                elif isinstance(result, basestring):
                    newlines.append(result)
                else:
                    exception = TypeError('pydo should return a string ' +
                                          'or None, found %s instead'
                                          % result.__class__.__name__)
                    break
                linenr += 1

            start = sstop + 1
            if newlines:
                end = sstart + len(newlines) - 1
                nvim.current.buffer.set_line_slice(sstart, end, True, True,
                                                   newlines)
            if exception:
                raise exception
        # delete the function
        del self.module.__dict__[fname]

    @neovim.rpc_export('python_eval', sync=True)
    def python_eval(self, expr):
        """Handle the `pyeval` vim function."""
        return eval(expr, self.module.__dict__)

    def _set_current_range(self, start, stop):
        current = self.legacy_vim.current
        current.range = current.buffer.range(start, stop)


class RedirectStream(io.IOBase):
    def __init__(self, redirect_handler):
        self.redirect_handler = redirect_handler

    def write(self, data):
        self.redirect_handler(data)

    def writelines(self, seq):
        self.redirect_handler('\n'.join(seq))


class LegacyEvalHook(neovim.SessionHook):

    """Injects legacy `vim.eval` behavior to a Nvim instance."""

    def __init__(self):
        super(LegacyEvalHook, self).__init__(from_nvim=self._string_eval)

    def _string_eval(self, obj, session, method, kind):
        if method == 'vim_eval':
            if IS_PYTHON3:
                if isinstance(obj, (int, float)):
                    return str(obj)
            elif isinstance(obj, (int, long, float)):
                return str(obj)
        return obj


# This was copied/adapted from nvim-python help
def path_hook(nvim):
    def _get_paths():
        return discover_runtime_directories(nvim)

    def _find_module(fullname, oldtail, path):
        idx = oldtail.find('.')
        if idx > 0:
            name = oldtail[:idx]
            tail = oldtail[idx+1:]
            fmr = imp.find_module(name, path)
            module = imp.find_module(fullname[:-len(oldtail)] + name, *fmr)
            return _find_module(fullname, tail, module.__path__)
        else:
            return imp.find_module(fullname, path)

    class VimModuleLoader(object):
        def __init__(self, module):
            self.module = module

        def load_module(self, fullname, path=None):
            # Check sys.modules, required for reload (see PEP302).
            if fullname in sys.modules:
                return sys.modules[fullname]
            return imp.load_module(fullname, *self.module)

    class VimPathFinder(object):
        @staticmethod
        def find_module(fullname, path=None):
            "Method for Python 2.7 and 3.3."
            try:
                return VimModuleLoader(
                    _find_module(fullname, fullname, path or _get_paths()))
            except ImportError:
                return None

        @staticmethod
        def find_spec(fullname, path=None, target=None):
            "Method for Python 3.4+."
            return PathFinder.find_spec(fullname, path or _get_paths(), target)

    def hook(path):
        if path == nvim.VIM_SPECIAL_PATH:
            return VimPathFinder
        else:
            raise ImportError

    return hook


def discover_runtime_directories(nvim):
    rv = []
    for path in nvim.list_runtime_paths():
        if not os.path.exists(path):
            continue
        path1 = os.path.join(path, 'pythonx')
        if IS_PYTHON3:
            path2 = os.path.join(path, 'python3')
        else:
            path2 = os.path.join(path, 'python2')
        if os.path.exists(path1):
            rv.append(path1)
        if os.path.exists(path2):
            rv.append(path2)
    return rv
