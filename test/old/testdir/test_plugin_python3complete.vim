" Tests for the Python omni-completion plugin (runtime/autoload/python3complete.vim).
"
CheckFeature python3

" Run omni-completion against the given buffer contents and assert that the
" marker file was not created.  Pre-patch behaviour exec()s reconstructed
" def/class headers, which evaluates the buffer-supplied expression and
" creates the marker file.  Post-patch, the expressions are stripped.
func s:CompleteAndExpectNoMarker(buffer_lines, marker_path, msg)
  call delete(a:marker_path)
  defer delete(a:marker_path)
  let g:pythoncomplete_allow_import = 0
  new
  setfiletype python
  call setline(1, a:buffer_lines)
  call cursor(line('$'), col([line('$'), '$']))

  " The PoC trigger -- direct invocation of the omnifunc with an empty base.
  " This is the same path Vim takes for CTRL-X CTRL-O.
  silent! call python3complete#Complete(0, '')

  call assert_false(filereadable(a:marker_path),
        \ a:msg . ' (marker ' . a:marker_path . ' was created)')

  bwipe!
  unlet! g:pythoncomplete_allow_import
endfunc

func Test_python3complete_no_exec_via_function_default()
  let marker = tempname()
  call s:CompleteAndExpectNoMarker([
        \ 'def f(x=open(' . string(marker) . ', "w").close()):',
        \ '    pass',
        \ 'f.',
        \ ], marker,
        \ 'function default expression was evaluated during omni-completion')
endfunc

func Test_python3complete_no_exec_via_function_annotation()
  let marker = tempname()
  call s:CompleteAndExpectNoMarker([
        \ 'def f(x: open(' . string(marker) . ', "w").close()):',
        \ '    pass',
        \ 'f.',
        \ ], marker,
        \ 'function annotation expression was evaluated during omni-completion')
endfunc

func Test_python3complete_no_exec_via_class_base()
  let marker = tempname()
  " "or object" gives the class a valid base after the side-effecting
  " open().close() expression returns None.  Without "or object" the
  " exec would raise TypeError, but the file would still be created
  " before the exception -- the assertion would still hold.  Using
  " "or object" keeps the buffer parseable as valid Python.
  call s:CompleteAndExpectNoMarker([
        \ 'class Foo(open(' . string(marker) . ', "w").close() or object):',
        \ '    pass',
        \ 'Foo.',
        \ ], marker,
        \ 'class base expression was evaluated during omni-completion')
endfunc

func Test_python3complete_no_exec_with_multiple_params()
  " The strip must apply to every parameter, not just the first.
  let marker = tempname()
  call s:CompleteAndExpectNoMarker([
        \ 'def f(a, b=1, c=open(' . string(marker) . ', "w").close(), d=2):',
        \ '    pass',
        \ 'f.',
        \ ], marker,
        \ 'non-first parameter default was evaluated during omni-completion')
endfunc

func Test_python3complete_no_exec_via_starargs_default()
  " "*args" and "**kw" must still be preserved after stripping; ensure a
  " default following them is also stripped.
  let marker = tempname()
  call s:CompleteAndExpectNoMarker([
        \ 'def f(*args, key=open(' . string(marker) . ', "w").close(), **kw):',
        \ '    pass',
        \ 'f.',
        \ ], marker,
        \ 'keyword-only default after *args was evaluated during omni-completion')
endfunc

func Test_python3complete_normal_completion_still_works()
  " Positive control: completion against a buffer with a legitimate class
  " must still produce completion items.  The stripping logic should not
  " break the normal completion path.
  let g:pythoncomplete_allow_import = 0

  new
  setfiletype python
  call setline(1, [
        \ 'class MyHelper:',
        \ '    def alpha(self): pass',
        \ '    def beta(self): pass',
        \ 'h = MyHelper()',
        \ 'h.',
        \ ])
  call cursor(5, 3)

  " First call returns the column to start completion at; second returns
  " the list of completion items.
  let start = python3complete#Complete(1, '')
  call assert_true(start >= 0,
        \ 'python3complete#Complete(1, "") returned ' . start)

  let items = python3complete#Complete(0, '')
  " Items should be a list (possibly empty if the parser can't resolve "h",
  " but should not be a parse error from our stripping changes).
  call assert_equal(type([]), type(items),
        \ 'python3complete#Complete(0, "") did not return a list')

  bwipe!
  unlet! g:pythoncomplete_allow_import
endfunc

func Test_python3complete_inherited_completion_via_dotted_base()
  " Positive control for the class-base whitelist: a dotted-name base class
  " (the common, safe case) must still be carried into the reconstructed
  " source so that completion on a subclass can resolve inherited members.
  let g:pythoncomplete_allow_import = 0

  new
  setfiletype python
  call setline(1, [
        \ 'class Base:',
        \ '    def shared(self): pass',
        \ 'class Derived(Base):',
        \ '    def own(self): pass',
        \ 'd = Derived()',
        \ 'd.',
        \ ])
  call cursor(6, 3)

  let items = python3complete#Complete(0, '')
  call assert_equal(type([]), type(items),
        \ 'completion against a subclass with a dotted base did not return a list')

  bwipe!
  unlet! g:pythoncomplete_allow_import
endfunc

" Build a tiny Python module that creates a marker file as a side effect of
" being imported, add its directory to sys.path, run omni-completion against
" a buffer containing `import vimtest_marker_mod`, and report whether the
" marker file was created.  Used by the two allow_import tests below.
func s:RunImportCompletion(allow_import_value)
  let g:pythoncomplete_allow_import = a:allow_import_value
  let marker = tempname()
  let module_dir = tempname()
  call mkdir(module_dir, 'R')

  call writefile([
        \ 'open(' . string(marker) . ', "w").close()',
        \ ], module_dir . '/vimtest_marker_mod.py')

  defer delete(marker)

  " Pass module_dir to Python via a g: variable so vim.eval() can read it.
  let g:pythoncomplete_test_module_dir = module_dir
  py3 << EOF
import sys, vim
_p = vim.eval('g:pythoncomplete_test_module_dir')
if _p not in sys.path:
    sys.path.insert(0, _p)
# Drop any cached copy so the module body re-runs and the marker side
# effect fires on import.
sys.modules.pop('vimtest_marker_mod', None)
EOF

  new
  setfiletype python
  call setline(1, [
        \ 'import vimtest_marker_mod',
        \ 'vimtest_marker_mod.',
        \ ])
  call cursor(2, 2)

  silent! call python3complete#Complete(0, '')

  let ran = filereadable(marker)

  bwipe!
  unlet g:pythoncomplete_allow_import

  " Teardown: restore sys.path, drop the cached module so a subsequent
  " test run starts clean, clean up the temp module dir.
  py3 << EOF
import sys, vim
_p = vim.eval('g:pythoncomplete_test_module_dir')
if _p in sys.path:
    sys.path.remove(_p)
sys.modules.pop('vimtest_marker_mod', None)
EOF
  unlet g:pythoncomplete_test_module_dir
  call delete(module_dir, 'rf')
  call delete(marker)
  unlet! g:pythoncomplete_allow_import

  return ran
endfunc

func Test_python3complete_allow_import_off_blocks_imports()
  " GHSA-52mc-rq6p-rc7c mitigation: with the default flag value (0), an
  " `import` line harvested from the buffer must NOT be exec()'d.  The
  " marker module's side effect (creating a file when its body runs) is
  " the observable proof that the exec did or did not happen.
  call assert_false(s:RunImportCompletion(0),
        \ 'g:pythoncomplete_allow_import=0 did not block the buffer import')
endfunc

func Test_python3complete_allow_import_on_runs_imports()
  " Symmetric positive control: with the flag set to non-zero, the harvested
  " import IS exec()'d and the module loads.  Without this control the
  " negative test above could pass for unrelated reasons (e.g. completion
  " failing to parse the buffer at all).
  call assert_true(s:RunImportCompletion(1),
        \ 'g:pythoncomplete_allow_import=1 did not run the buffer import')
endfunc

func Test_python3complete_no_exec_via_class_docstring()
  " A class-body docstring is emitted verbatim between triple quotes by
  " get_code() and runs at class-definition time during exec().  A single-
  " quoted source docstring lets an embedded """ survive doc()'s leading/
  " trailing quote strip and break out of the generated literal.
  let marker = tempname()
  call s:CompleteAndExpectNoMarker([
        \ 'class Foo:',
        \ '    ''x"""+open("' . marker . '", "w").close()+"""y''',
        \ '    pass',
        \ 'Foo.',
        \ ], marker,
        \ 'class docstring expression was evaluated during omni-completion')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
