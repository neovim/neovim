" Test for python 3 commands.

source check.vim
CheckFeature python3

" This function should be called first. This sets up python functions used by
" the other tests.
func Test_AAA_python3_setup()
  py3 << trim EOF
    import vim
    import sys
    import re

    py33_type_error_pattern = re.compile(r'^__call__\(\) takes (\d+) positional argument but (\d+) were given$')
    py37_exception_repr = re.compile(r'([^\(\),])(\)+)$')
    py39_type_error_pattern = re.compile(r'\w+\.([^(]+\(\) takes)')
    py310_type_error_pattern = re.compile(r'takes (\d+) positional argument but (\d+) were given')
    py314_type_error_tuple_pattern = re.compile(r'must be (\d+)-item tuple')

    def emsg(ei):
      return ei[0].__name__ + ':' + repr(ei[1].args)

    def ee(expr, g=globals(), l=locals()):
        cb = vim.current.buffer
        try:
            try:
                exec(expr, g, l)
            except Exception as e:
                if sys.version_info >= (3, 3) and e.__class__ is AttributeError and str(e).find('has no attribute')>=0 and not str(e).startswith("'vim."):
                    msg = repr((e.__class__, AttributeError(str(e)[str(e).rfind(" '") + 2:-1])))
                elif sys.version_info >= (3, 3) and e.__class__ is ImportError and str(e).find('No module named \'') >= 0:
                    msg = repr((e.__class__, ImportError(str(e).replace("'", ''))))
                elif sys.version_info >= (3, 6) and e.__class__ is ModuleNotFoundError:
                    # Python 3.6 gives ModuleNotFoundError, change it to an ImportError
                    msg = repr((ImportError, ImportError(str(e).replace("'", ''))))
                elif sys.version_info >= (3, 3) and e.__class__ is TypeError:
                    m = py33_type_error_pattern.search(str(e))
                    if m:
                        msg = '__call__() takes exactly {0} positional argument ({1} given)'.format(m.group(1), m.group(2))
                        msg = repr((e.__class__, TypeError(msg)))
                    else:
                        msg = repr((e.__class__, e))
                        # Messages changed with Python 3.6, change new to old.
                        newmsg1 = """'argument must be str, bytes or bytearray, not None'"""
                        oldmsg1 = '''"Can't convert 'NoneType' object to str implicitly"'''
                        if msg.find(newmsg1) > -1:
                            msg = msg.replace(newmsg1, oldmsg1)
                        newmsg2 = """'argument must be str, bytes or bytearray, not int'"""
                        oldmsg2 = '''"Can't convert 'int' object to str implicitly"'''
                        if msg.find(newmsg2) > -1:
                            msg = msg.replace(newmsg2, oldmsg2)
                        # Python 3.9 reports errors like "vim.command() takes ..." instead of "command() takes ..."
                        msg = py39_type_error_pattern.sub(r'\1', msg)
                        msg = py310_type_error_pattern.sub(r'takes exactly \1 positional argument (\2 given)', msg)
                        # Python 3.14 has specific error messages for Tuple's
                        msg = py314_type_error_tuple_pattern.sub(r'must be \1-item sequence', msg)
                elif sys.version_info >= (3, 5) and e.__class__ is ValueError and str(e) == 'embedded null byte':
                    msg = repr((TypeError, TypeError('expected bytes with no null')))
                else:
                    msg = repr((e.__class__, e))
                    # Some Python versions say can't, others cannot.
                    if msg.find('can\'t') > -1:
                        msg = msg.replace('can\'t', 'cannot')
                    # Some Python versions use single quote, some double quote
                    if msg.find('"cannot ') > -1:
                        msg = msg.replace('"cannot ', '\'cannot ')
                    if msg.find(' attributes"') > -1:
                        msg = msg.replace(' attributes"', ' attributes\'')
                if sys.version_info >= (3, 7):
                    msg = py37_exception_repr.sub(r'\1,\2', msg)
                cb.append(expr + ':' + msg)
            else:
                cb.append(expr + ':NOT FAILED')
        except Exception as e:
            msg = repr((e.__class__, e))
            if sys.version_info >= (3, 7):
                msg = py37_exception_repr.sub(r'\1,\2', msg)
            cb.append(expr + '::' + msg)
  EOF
endfunc

func Test_py3do()
  " Check deleting lines does not trigger an ml_get error.
  py3 import vim
  new
  call setline(1, ['one', 'two', 'three'])
  py3do vim.command("%d_")
  bwipe!

  " Disabled until neovim/neovim#8554 is resolved
  if 0
    " Check switching to another buffer does not trigger an ml_get error.
    new
    let wincount = winnr('$')
    call setline(1, ['one', 'two', 'three'])
    py3do vim.command("new")
    call assert_equal(wincount + 1, winnr('$'))
    bwipe!
    bwipe!
  endif
endfunc

func Test_set_cursor()
  " Check that setting the cursor position works.
  py3 import vim
  new
  call setline(1, ['first line', 'second line'])
  normal gg
  py3do vim.current.window.cursor = (1, 5)
  call assert_equal([1, 6], [line('.'), col('.')])

  " Check that movement after setting cursor position keeps current column.
  normal j
  call assert_equal([2, 6], [line('.'), col('.')])
endfunc

func Test_vim_function()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  " Check creating vim.Function object
  py3 import vim

  func s:foo()
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+_foo$')
  endfunc
  let name = '<SNR>' . s:foo()

  try
    py3 f = vim.bindeval('function("s:foo")')
    call assert_equal(name, py3eval('f.name'))
  catch
    call assert_false(v:exception)
  endtry

  try
    py3 f = vim.Function(b'\x80\xfdR' + vim.eval('s:foo()').encode())
    call assert_equal(name, 'f.name'->py3eval())
  catch
    call assert_false(v:exception)
  endtry

  let caught_vim_err = v:false
  try
    let x = py3eval('f.abc')
  catch
    call assert_match("AttributeError: 'vim.function' object has no attribute 'abc'", v:exception)
    let caught_vim_err = v:true
  endtry
  call assert_equal(v:true, caught_vim_err)

  py3 del f
  delfunc s:foo
endfunc

func Test_skipped_python3_command_does_not_affect_pyxversion()
  throw 'Skipped: Nvim hardcodes pyxversion=3'
  set pyxversion=0
  if 0
    python3 import vim
  endif
  call assert_equal(0, &pyxversion)  " This assertion would have failed with Vim 8.0.0251. (pyxversion was introduced in 8.0.0251.)
endfunc

func _SetUpHiddenBuffer()
  py3 import vim
  new
  edit hidden
  setlocal bufhidden=hide

  enew
  let lnum = 0
  while lnum < 10
    call append( 1, string( lnum ) )
    let lnum = lnum + 1
  endwhile
  normal G

  call assert_equal( line( '.' ), 11 )
endfunc

func _CleanUpHiddenBuffer()
  bwipe! hidden
  bwipe!
endfunc

func Test_Write_To_HiddenBuffer_Does_Not_Fix_Cursor_Clear()
  call _SetUpHiddenBuffer()
  py3 vim.buffers[ int( vim.eval( 'bufnr("hidden")' ) ) ][:] = None
  call assert_equal( line( '.' ), 11 )
  call _CleanUpHiddenBuffer()
endfunc

func Test_Write_To_HiddenBuffer_Does_Not_Fix_Cursor_List()
  call _SetUpHiddenBuffer()
  py3 vim.buffers[ int( vim.eval( 'bufnr("hidden")' ) ) ][:] = [ 'test' ]
  call assert_equal( line( '.' ), 11 )
  call _CleanUpHiddenBuffer()
endfunc

func Test_Write_To_HiddenBuffer_Does_Not_Fix_Cursor_Str()
  call _SetUpHiddenBuffer()
  py3 vim.buffers[ int( vim.eval( 'bufnr("hidden")' ) ) ][0] = 'test'
  call assert_equal( line( '.' ), 11 )
  call _CleanUpHiddenBuffer()
endfunc

func Test_Write_To_HiddenBuffer_Does_Not_Fix_Cursor_ClearLine()
  call _SetUpHiddenBuffer()
  py3 vim.buffers[ int( vim.eval( 'bufnr("hidden")' ) ) ][0] = None
  call assert_equal( line( '.' ), 11 )
  call _CleanUpHiddenBuffer()
endfunc

func _SetUpVisibleBuffer()
  py3 import vim
  new
  let lnum = 0
  while lnum < 10
    call append( 1, string( lnum ) )
    let lnum = lnum + 1
  endwhile
  normal G
  call assert_equal( line( '.' ), 11 )
endfunc

func Test_Write_To_Current_Buffer_Fixes_Cursor_Clear()
  call _SetUpVisibleBuffer()

  py3 vim.current.buffer[:] = None
  call assert_equal( line( '.' ), 1 )

  bwipe!
endfunc

func Test_Write_To_Current_Buffer_Fixes_Cursor_List()
  call _SetUpVisibleBuffer()

  py3 vim.current.buffer[:] = [ 'test' ]
  call assert_equal( line( '.' ), 1 )

  bwipe!
endfunc

func Test_Write_To_Current_Buffer_Fixes_Cursor_Str()
  call _SetUpVisibleBuffer()

  py3 vim.current.buffer[-1] = None
  call assert_equal( line( '.' ), 10 )

  bwipe!
endfunc

func Test_Catch_Exception_Message()
  try
    py3 raise RuntimeError( 'TEST' )
  catch /.*/
    call assert_match('^Vim(.*):.*RuntimeError: TEST.*$', v:exception )
  endtry
endfunc

func Test_unicode()
  " this crashed Vim once
  throw "Skipped: nvim does not support changing 'encoding'"

  set encoding=utf32
  py3 print('hello')

  if !has('win32')
    set encoding=debug
    py3 print('hello')

    set encoding=euc-tw
    py3 print('hello')
  endif

  set encoding=utf8
endfunc

" Test vim.eval() with various types.
func Test_python3_vim_val()
  call assert_equal("\n8",             execute('py3 print(vim.eval("3+5"))'))
  if has('float')
    call assert_equal("\n3.1399999999999997",    execute('py3 print(vim.eval("1.01+2.13"))'))
    call assert_equal("\n0.0",    execute('py3 print(vim.eval("0.0/(1.0/0.0)"))'))
    call assert_equal("\n0.0",    execute('py3 print(vim.eval("0.0/(1.0/0.0)"))'))
    call assert_equal("\n-0.0",   execute('py3 print(vim.eval("0.0/(-1.0/0.0)"))'))
    " Commented out: output of infinity and nan depend on platforms.
    " call assert_equal("\ninf",         execute('py3 print(vim.eval("1.0/0.0"))'))
    " call assert_equal("\n-inf",        execute('py3 print(vim.eval("-1.0/0.0"))'))
    " call assert_equal("\n-nan",        execute('py3 print(vim.eval("0.0/0.0"))'))
  endif
  call assert_equal("\nabc",           execute('py3 print(vim.eval("\"abc\""))'))
  call assert_equal("\n['1', '2']",    execute('py3 print(vim.eval("[1, 2]"))'))
  call assert_equal("\n{'1': '2'}",    execute('py3 print(vim.eval("{1:2}"))'))
  call assert_equal("\nTrue",          execute('py3 print(vim.eval("v:true"))'))
  call assert_equal("\nFalse",         execute('py3 print(vim.eval("v:false"))'))
  call assert_equal("\nNone",          execute('py3 print(vim.eval("v:null"))'))
  " call assert_equal("\nNone",          execute('py3 print(vim.eval("v:none"))'))
  " call assert_equal("\nb'\\xab\\x12'", execute('py3 print(vim.eval("0zab12"))'))

  call assert_fails('py3 vim.eval("1+")', 'E5108:')
endfunc

" Test range objects, see :help python-range
func Test_python3_range()
  new
  py3 b = vim.current.buffer

  call setline(1, range(1, 6))
  py3 r = b.range(2, 4)
  call assert_equal(6, py3eval('len(b)'))
  call assert_equal(3, py3eval('len(r)'))
  call assert_equal('3', py3eval('b[2]'))
  call assert_equal('4', py3eval('r[2]'))

  " call assert_fails('py3 r[3] = "x"', 'IndexError: line number out of range')
  " call assert_fails('py3 x = r[3]', 'IndexError: line number out of range')
  call assert_fails('py3 r["a"] = "x"', 'TypeError')
  call assert_fails('py3 x = r["a"]', 'TypeError')

  py3 del r[:]
  call assert_equal(['1', '5', '6'], getline(1, '$'))

  %d | call setline(1, range(1, 6))
  py3 r = b.range(2, 5)
  py3 del r[2]
  call assert_equal(['1', '2', '3', '5', '6'], getline(1, '$'))

  %d | call setline(1, range(1, 6))
  py3 r = b.range(2, 4)
  py3 vim.command("%d,%dnorm Ax" % (r.start + 1, r.end + 1))
  call assert_equal(['1', '2x', '3x', '4x', '5', '6'], getline(1, '$'))

  %d | call setline(1, range(1, 4))
  py3 r = b.range(2, 3)
  py3 r.append(['a', 'b'])
  call assert_equal(['1', '2', '3', 'a', 'b', '4'], getline(1, '$'))
  py3 r.append(['c', 'd'], 0)
  call assert_equal(['1', 'c', 'd', '2', '3', 'a', 'b', '4'], getline(1, '$'))

  %d | call setline(1, range(1, 5))
  py3 r = b.range(2, 4)
  py3 r.append('a')
  call assert_equal(['1', '2', '3', '4', 'a', '5'], getline(1, '$'))
  py3 r.append('b', 1)
  call assert_equal(['1', '2', 'b', '3', '4', 'a', '5'], getline(1, '$'))

  bwipe!
endfunc

" Test for resetting options with local values to global values
func Test_python3_opt_reset_local_to_global()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  new

  py3 curbuf = vim.current.buffer
  py3 curwin = vim.current.window

  " List of buffer-local options. Each list item has [option name, global
  " value, buffer-local value, buffer-local value after reset] to use in the
  " test.
  let bopts = [
        \ ['autoread', 1, 0, -1],
        \ ['equalprg', 'geprg', 'leprg', ''],
        \ ['keywordprg', 'gkprg', 'lkprg', ''],
        \ ['path', 'gpath', 'lpath', ''],
        \ ['backupcopy', 'yes', 'no', ''],
        \ ['tags', 'gtags', 'ltags', ''],
        \ ['tagcase', 'ignore', 'match', ''],
        \ ['define', 'gdef', 'ldef', ''],
        \ ['include', 'ginc', 'linc', ''],
        \ ['dict', 'gdict', 'ldict', ''],
        \ ['thesaurus', 'gtsr', 'ltsr', ''],
        \ ['formatprg', 'gfprg', 'lfprg', ''],
        \ ['errorformat', '%f:%l:%m', '%s-%l-%m', ''],
        \ ['grepprg', 'ggprg', 'lgprg', ''],
        \ ['makeprg', 'gmprg', 'lmprg', ''],
        \ ['balloonexpr', 'gbexpr', 'lbexpr', ''],
        \ ['cryptmethod', 'blowfish2', 'zip', ''],
        \ ['lispwords', 'abc', 'xyz', ''],
        \ ['makeencoding', 'utf-8', 'latin1', ''],
        \ ['undolevels', 100, 200, -123456]]

  " Set the global and buffer-local option values and then clear the
  " buffer-local option value.
  for opt in bopts
    py3 << trim END
      pyopt = vim.bindeval("opt")
      vim.options[pyopt[0]] = pyopt[1]
      curbuf.options[pyopt[0]] = pyopt[2]
    END
    exe "call assert_equal(opt[2], &" .. opt[0] .. ")"
    exe "call assert_equal(opt[1], &g:" .. opt[0] .. ")"
    exe "call assert_equal(opt[2], &l:" .. opt[0] .. ")"
    py3 del curbuf.options[pyopt[0]]
    exe "call assert_equal(opt[1], &" .. opt[0] .. ")"
    exe "call assert_equal(opt[1], &g:" .. opt[0] .. ")"
    exe "call assert_equal(opt[3], &l:" .. opt[0] .. ")"
    exe "set " .. opt[0] .. "&"
  endfor

  " Set the global and window-local option values and then clear the
  " window-local option value.
  let wopts = [
        \ ['scrolloff', 5, 10, -1],
        \ ['sidescrolloff', 6, 12, -1],
        \ ['statusline', '%<%f', '%<%F', '']]
  for opt in wopts
    py3 << trim
      pyopt = vim.bindeval("opt")
      vim.options[pyopt[0]] = pyopt[1]
      curwin.options[pyopt[0]] = pyopt[2]
    .
    exe "call assert_equal(opt[2], &" .. opt[0] .. ")"
    exe "call assert_equal(opt[1], &g:" .. opt[0] .. ")"
    exe "call assert_equal(opt[2], &l:" .. opt[0] .. ")"
    py3 del curwin.options[pyopt[0]]
    exe "call assert_equal(opt[1], &" .. opt[0] .. ")"
    exe "call assert_equal(opt[1], &g:" .. opt[0] .. ")"
    exe "call assert_equal(opt[3], &l:" .. opt[0] .. ")"
    exe "set " .. opt[0] .. "&"
  endfor

  close!
endfunc

" Test for various heredoc syntax
func Test_python3_heredoc()
  python3 << END
s='A'
END
  python3 <<
s+='B'
.
  python3 << trim END
    s+='C'
  END
  python3 << trim
    s+='D'
  .
  python3 << trim eof
    s+='E'
  eof
  python3 << trimm
s+='F'
trimm
  call assert_equal('ABCDEF', pyxeval('s'))
endfunc

" Test for the python List object
func Test_python3_list()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  let l = []
  py3 l = vim.bindeval('l')
  py3 f = vim.bindeval('function("strlen")')
  " Extending List directly with different types
  py3 l += [1, "as'd", [1, 2, f, {'a': 1}]]
  call assert_equal([1, "as'd", [1, 2, function("strlen"), {'a': 1}]], l)
  call assert_equal([1, 2, function("strlen"), {'a': 1}], l[-1])
  call assert_fails('echo l[-4]', 'E684:')

  " List assignment
  py3 l[0] = 0
  call assert_equal([0, "as'd", [1, 2, function("strlen"), {'a': 1}]], l)
  py3 l[-2] = f
  call assert_equal([0, function("strlen"), [1, 2, function("strlen"), {'a': 1}]], l)
endfunc

" Extending Dictionary directly with different types
func Test_python3_dict_extend()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  let d = {}
  func d.f()
    return 1
  endfunc

  py3 f = vim.bindeval('function("strlen")')
  py3 << trim EOF
    d = vim.bindeval('d')
    d['1'] = 'asd'
    d.update()  # Must not do anything, including throwing errors
    d.update(b = [1, 2, f])
    d.update((('-1', {'a': 1}),))
    d.update({'0': -1})
    dk = d.keys()
    dv = d.values()
    di = d.items()
    dk.sort(key=repr)
    dv.sort(key=repr)
    di.sort(key=repr)
  EOF

  call assert_equal(1, py3eval("d['f'](self={})"))
  call assert_equal("[b'-1', b'0', b'1', b'b', b'f']", py3eval('repr(dk)'))
  call assert_equal("[-1, <vim.Function '1'>, <vim.dictionary object at >, <vim.list object at >, b'asd']", substitute(py3eval('repr(dv)'),'0x\x\+','','g'))
  call assert_equal("[(b'-1', <vim.dictionary object at >), (b'0', -1), (b'1', b'asd'), (b'b', <vim.list object at >), (b'f', <vim.Function '1'>)]", substitute(py3eval('repr(di)'),'0x\x\+','','g'))
  call assert_equal(['0', '1', 'b', 'f', '-1'], keys(d))
  call assert_equal("[-1, 'asd', [1, 2, function('strlen')], function('1'), {'a': 1}]", string(values(d)))
  py3 del dk
  py3 del di
  py3 del dv
endfunc

func Test_python3_list_del_items()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  " removing items with del
  let l = [0, function("strlen"), [1, 2, function("strlen"), {'a': 1}]]
  py3 l = vim.bindeval('l')
  py3 del l[2]
  call assert_equal("[0, function('strlen')]", string(l))

  let l = range(8)
  py3 l = vim.bindeval('l')
  py3 del l[:3]
  py3 del l[1:]
  call assert_equal([3], l)

  " removing items out of range: silently skip items that don't exist

  " The following two ranges delete nothing as they match empty list:
  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  py3 del l[2:1]
  call assert_equal([0, 1, 2, 3], l)
  py3 del l[2:2]
  call assert_equal([0, 1, 2, 3], l)
  py3 del l[2:3]
  call assert_equal([0, 1, 3], l)

  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  py3 del l[2:4]
  call assert_equal([0, 1], l)

  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  py3 del l[2:5]
  call assert_equal([0, 1], l)

  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  py3 del l[2:6]
  call assert_equal([0, 1], l)

  " The following two ranges delete nothing as they match empty list:
  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  py3 del l[-1:2]
  call assert_equal([0, 1, 2, 3], l)
  py3 del l[-2:2]
  call assert_equal([0, 1, 2, 3], l)
  py3 del l[-3:2]
  call assert_equal([0, 2, 3], l)

  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  py3 del l[-4:2]
  call assert_equal([2, 3], l)

  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  py3 del l[-5:2]
  call assert_equal([2, 3], l)

  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  py3 del l[-6:2]
  call assert_equal([2, 3], l)

  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  py3 del l[::2]
  call assert_equal([1, 3], l)

  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  py3 del l[3:0:-2]
  call assert_equal([0, 2], l)

  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  py3 del l[2:4:-2]
  let l = [0, 1, 2, 3]
endfunc

func Test_python3_dict_del_items()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  let d = eval("{'0' : -1, '1' : 'asd', 'b' : [1, 2, function('strlen')], 'f' : function('min'), '-1' : {'a': 1}}")
  py3 d = vim.bindeval('d')
  py3 del d['-1']
  py3 del d['f']
  call assert_equal([1, 2, function('strlen')], py3eval('d.get(''b'', 1)'))
  call assert_equal([1, 2, function('strlen')], py3eval('d.pop(''b'')'))
  call assert_equal(1, py3eval('d.get(''b'', 1)'))
  call assert_equal('asd', py3eval('d.pop(''1'', 2)'))
  call assert_equal(2, py3eval('d.pop(''1'', 2)'))
  call assert_equal('True', py3eval('repr(d.has_key(''0''))'))
  call assert_equal('False', py3eval('repr(d.has_key(''1''))'))
  call assert_equal('True', py3eval('repr(''0'' in d)'))
  call assert_equal('False', py3eval('repr(''1'' in d)'))
  call assert_equal("[b'0']", py3eval('repr(list(iter(d)))'))
  call assert_equal({'0' : -1}, d)
  call assert_equal("(b'0', -1)", py3eval('repr(d.popitem())'))
  call assert_equal('None', py3eval('repr(d.get(''0''))'))
  call assert_equal('[]', py3eval('repr(list(iter(d)))'))
endfunc

" Slice assignment to a list
func Test_python3_slice_assignment()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  py3 l[0:0] = ['a']
  call assert_equal(['a', 0, 1, 2, 3], l)

  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  py3 l[1:2] = ['b']
  call assert_equal([0, 'b', 2, 3], l)

  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  py3 l[2:4] = ['c']
  call assert_equal([0, 1, 'c'], l)

  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  py3 l[4:4] = ['d']
  call assert_equal([0, 1, 2, 3, 'd'], l)

  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  py3 l[-1:2] = ['e']
  call assert_equal([0, 1, 2, 'e', 3], l)

  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  py3 l[-10:2] = ['f']
  call assert_equal(['f', 2, 3], l)

  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  py3 l[2:-10] = ['g']
  call assert_equal([0, 1, 'g', 2, 3], l)

  let l = []
  py3 l = vim.bindeval('l')
  py3 l[0:0] = ['h']
  call assert_equal(['h'], l)

  let l = range(8)
  py3 l = vim.bindeval('l')
  py3 l[2:6:2] = [10, 20]
  call assert_equal([0, 1, 10, 3, 20, 5, 6, 7], l)

  let l = range(8)
  py3 l = vim.bindeval('l')
  py3 l[6:2:-2] = [10, 20]
  call assert_equal([0, 1, 2, 3, 20, 5, 10, 7], l)

  let l = range(8)
  py3 l = vim.bindeval('l')
  py3 l[6:2] = ()
  call assert_equal([0, 1, 2, 3, 4, 5, 6, 7], l)

  let l = range(8)
  py3 l = vim.bindeval('l')
  py3 l[6:2:1] = ()
  call assert_equal([0, 1, 2, 3, 4, 5, 6, 7], l)

  let l = range(8)
  py3 l = vim.bindeval('l')
  py3 l[2:2:1] = ()
  call assert_equal([0, 1, 2, 3, 4, 5, 6, 7], l)
endfunc

" Locked variables
func Test_python3_lockedvar()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  new
  py3 cb = vim.current.buffer
  let l = [0, 1, 2, 3]
  py3 l = vim.bindeval('l')
  lockvar! l
  py3 << trim EOF
    try:
        l[2]='i'
    except vim.error:
        cb.append('l[2] threw vim.error: ' + emsg(sys.exc_info()))
  EOF
  call assert_equal(['', "l[2] threw vim.error: error:('list is locked',)"],
        \ getline(1, '$'))
  call assert_equal([0, 1, 2, 3], l)
  unlockvar! l
  close!
endfunc

" Test for calling a function
func Test_python3_function_call()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  func New(...)
    return ['NewStart'] + a:000 + ['NewEnd']
  endfunc

  func DictNew(...) dict
    return ['DictNewStart'] + a:000 + ['DictNewEnd', self]
  endfunc

  new
  let l = [function('New'), function('DictNew')]
  py3 l = vim.bindeval('l')
  py3 l.extend(list(l[0](1, 2, 3)))
  call assert_equal([function('New'), function('DictNew'), 'NewStart', 1, 2, 3, 'NewEnd'], l)
  py3 l.extend(list(l[1](1, 2, 3, self={'a': 'b'})))
  call assert_equal([function('New'), function('DictNew'), 'NewStart', 1, 2, 3, 'NewEnd', 'DictNewStart', 1, 2, 3, 'DictNewEnd', {'a': 'b'}], l)
  py3 l += [[l[0].name]]
  call assert_equal([function('New'), function('DictNew'), 'NewStart', 1, 2, 3, 'NewEnd', 'DictNewStart', 1, 2, 3, 'DictNewEnd', {'a': 'b'}, ['New']], l)
  py3 ee('l[1](1, 2, 3)')
  call assert_equal("l[1](1, 2, 3):(<class 'vim.error'>, error('Vim:E725: Calling dict function without Dictionary: DictNew',))", getline(2))
  %d
  py3 f = l[0]
  delfunction New
  py3 ee('f(1, 2, 3)')
  call assert_equal("f(1, 2, 3):(<class 'vim.error'>, error('Vim:E117: Unknown function: New',))", getline(2))
  close!
  delfunction DictNew
endfunc

func Test_python3_float()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  CheckFeature float
  let l = [0.0]
  py3 l = vim.bindeval('l')
  py3 l.extend([0.0])
  call assert_equal([0.0, 0.0], l)
endfunc

" Test for Dict key errors
func Test_python3_dict_key_error()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  let messages = []
  py3 << trim EOF
    import sys
    d = vim.bindeval('{}')
    m = vim.bindeval('messages')
    def em(expr, g=globals(), l=locals()):
      try:
        exec(expr, g, l)
      except Exception as e:
        if sys.version_info >= (3, 5) and e.__class__ is ValueError and str(e) == 'embedded null byte':
          m.extend([TypeError.__name__])
        else:
          m.extend([e.__class__.__name__])

    em('d["abc1"]')
    em('d["abc1"]="\\0"')
    em('d["abc1"]=vim')
    em('d[""]=1')
    em('d["a\\0b"]=1')
    em('d[b"a\\0b"]=1')
    em('d.pop("abc1")')
    em('d.popitem()')
    del em
    del m
  EOF

  call assert_equal(['KeyError', 'TypeError', 'TypeError', 'ValueError',
        \ 'TypeError', 'TypeError', 'KeyError', 'KeyError'], messages)
  unlet messages
endfunc

" Test for locked and scope attributes
func Test_python3_lock_scope_attr()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  let d = {} | let dl = {} | lockvar dl
  let res = []
  for s in split("d dl v: g:")
    let name = tr(s, ':', 's')
    execute 'py3 ' .. name .. ' = vim.bindeval("' .. s .. '")'
    call add(res, s .. ' : ' .. join(map(['locked', 'scope'],
          \ 'v:val .. ":" .. py3eval(name .. "." .. v:val)'), ';'))
  endfor
  call assert_equal(['d : locked:0;scope:0', 'dl : locked:1;scope:0',
        \ 'v: : locked:2;scope:1', 'g: : locked:0;scope:2'], res)

  silent! let d.abc2 = 1
  silent! let dl.abc3 = 1
  py3 d.locked = True
  py3 dl.locked = False
  silent! let d.def = 1
  silent! let dl.def = 1
  call assert_equal({'abc2': 1}, d)
  call assert_equal({'def': 1}, dl)
  unlet d dl

  let l = [] | let ll = [] | lockvar ll
  let res = []
  for s in split("l ll")
    let name = tr(s, ':', 's')
    execute 'py3 ' .. name .. '=vim.bindeval("' .. s .. '")'
    call add(res, s .. ' : locked:' .. py3eval(name .. '.locked'))
  endfor
  call assert_equal(['l : locked:0', 'll : locked:1'], res)

  silent! call extend(l, [0])
  silent! call extend(ll, [0])
  py3 l.locked = True
  py3 ll.locked = False
  silent! call extend(l, [1])
  silent! call extend(ll, [1])
  call assert_equal([0], l)
  call assert_equal([1], ll)
  unlet l ll
endfunc

" Test for py3eval()
func Test_python3_pyeval()
  let l = py3eval('[0, 1, 2]')
  call assert_equal([0, 1, 2], l)

  let d = py3eval('{"a": "b", "c": 1, "d": ["e"]}')
  call assert_equal([['a', 'b'], ['c', 1], ['d', ['e']]], sort(items(d)))

  let v:errmsg = ''
  " call assert_equal(v:none, py3eval('None'))
  call assert_equal('', v:errmsg)

  if has('float')
    call assert_equal(0, py3eval('0.0'))
  endif

  " Invalid values:
  " let caught_859 = 0
  " try
  "   let v = py3eval('"\0"')
  " catch /E859:/
  "   let caught_859 = 1
  " endtry
  " call assert_equal(1, caught_859)

  " let caught_859 = 0
  " try
  "   let v = py3eval('{"\0" : 1}')
  " catch /E859:/
  "   let caught_859 = 1
  " endtry
  " call assert_equal(1, caught_859)

  let caught_nameerr = 0
  try
    let v = py3eval("undefined_name")
  catch /NameError: name 'undefined_name'/
    let caught_nameerr = 1
  endtry
  call assert_equal(1, caught_nameerr)

  let caught_859 = 0
  try
    let v = py3eval("vim")
  catch /can not serialize 'LegacyVim' object/
    let caught_859 = 1
  endtry
  call assert_equal(1, caught_859)
endfunc

" threading
" Running py3do command (Test_pydo) before this test, stops the python thread
" from running. So this test should be run before the pydo test
func Test_aaa_python_threading()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  let l = [0]
  py3 l = vim.bindeval('l')
  py3 << trim EOF
    import threading
    import time

    class T(threading.Thread):
      def __init__(self):
        threading.Thread.__init__(self)
        self.t = 0
        self.running = True

      def run(self):
        while self.running:
          self.t += 1
          time.sleep(0.1)

    t = T()
    del T
    t.start()
  EOF

  sleep 1
  py3 t.running = False
  py3 t.join()

  " Check if the background thread is working.  Count should be 10, but on a
  " busy system (AppVeyor) it can be much lower.
  py3 l[0] = t.t > 4
  py3 del time
  py3 del threading
  py3 del t
  call assert_equal([1], l)
endfunc

" settrace
func Test_python3_settrace()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  let l = []
  py3 l = vim.bindeval('l')
  py3 << trim EOF
    import sys

    def traceit(frame, event, arg):
      global l
      if event == "line":
        l += [frame.f_lineno]
      return traceit

    def trace_main():
      for i in range(5):
        pass
  EOF
  py3 sys.settrace(traceit)
  py3 trace_main()
  py3 sys.settrace(None)
  py3 del traceit
  py3 del trace_main
  call assert_equal([1, 10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10, 1], l)
endfunc

" Slice
func Test_python3_list_slice()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  py3 ll = vim.bindeval('[0, 1, 2, 3, 4, 5]')
  py3 l = ll[:4]
  call assert_equal([0, 1, 2, 3], py3eval('l'))
  py3 l = ll[2:]
  call assert_equal([2, 3, 4, 5], py3eval('l'))
  py3 l = ll[:-4]
  call assert_equal([0, 1], py3eval('l'))
  py3 l = ll[-2:]
  call assert_equal([4, 5], py3eval('l'))
  py3 l = ll[2:4]
  call assert_equal([2, 3], py3eval('l'))
  py3 l = ll[4:2]
  call assert_equal([], py3eval('l'))
  py3 l = ll[-4:-2]
  call assert_equal([2, 3], py3eval('l'))
  py3 l = ll[-2:-4]
  call assert_equal([], py3eval('l'))
  py3 l = ll[:]
  call assert_equal([0, 1, 2, 3, 4, 5], py3eval('l'))
  py3 l = ll[0:6]
  call assert_equal([0, 1, 2, 3, 4, 5], py3eval('l'))
  py3 l = ll[-10:10]
  call assert_equal([0, 1, 2, 3, 4, 5], py3eval('l'))
  py3 l = ll[4:2:-1]
  call assert_equal([4, 3], py3eval('l'))
  py3 l = ll[::2]
  call assert_equal([0, 2, 4], py3eval('l'))
  py3 l = ll[4:2:1]
  call assert_equal([], py3eval('l'))
  py3 del l
endfunc

" Vars
func Test_python3_vars()
  let g:foo = 'bac'
  let w:abc3 = 'def'
  let b:baz = 'bar'
  let t:bar = 'jkl'
  try
    throw "Abc"
  catch /Abc/
    call assert_equal('Abc', py3eval('vim.vvars[''exception'']'))
  endtry
  call assert_equal('bac', py3eval('vim.vars[''foo'']'))
  call assert_equal('def', py3eval('vim.current.window.vars[''abc3'']'))
  call assert_equal('bar', py3eval('vim.current.buffer.vars[''baz'']'))
  call assert_equal('jkl', py3eval('vim.current.tabpage.vars[''bar'']'))
endfunc

" Options
" paste:          boolean, global
" previewheight   number,  global
" operatorfunc:   string,  global
" number:         boolean, window-local
" numberwidth:    number,  window-local
" colorcolumn:    string,  window-local
" statusline:     string,  window-local/global
" autoindent:     boolean, buffer-local
" shiftwidth:     number,  buffer-local
" omnifunc:       string,  buffer-local
" preserveindent: boolean, buffer-local/global
" path:           string,  buffer-local/global
func Test_python3_opts()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  let g:res = []
  let g:bufs = [bufnr('%')]
  new
  let g:bufs += [bufnr('%')]
  vnew
  let g:bufs += [bufnr('%')]
  wincmd j
  vnew
  let g:bufs += [bufnr('%')]
  wincmd l

  func RecVars(opt)
    let gval = string(eval('&g:' .. a:opt))
    let wvals = join(map(range(1, 4),
          \ 'v:val .. ":" .. string(getwinvar(v:val, "&" .. a:opt))'))
    let bvals = join(map(copy(g:bufs),
          \ 'v:val .. ":" .. string(getbufvar(v:val, "&" .. a:opt))'))
    call add(g:res, '  G: ' .. gval)
    call add(g:res, '  W: ' .. wvals)
    call add(g:res, '  B: ' .. wvals)
  endfunc

  py3 << trim EOF
    def e(s, g=globals(), l=locals()):
      try:
        exec(s, g, l)
      except Exception as e:
        vim.command('return ' + repr(e.__class__.__name__))

    def ev(s, g=globals(), l=locals()):
      try:
        return eval(s, g, l)
      except Exception as e:
        vim.command('let exc=' + repr(e.__class__.__name__))
        return 0
  EOF

  func E(s)
    python3 e(vim.eval('a:s'))
  endfunc

  func Ev(s)
    let r = py3eval('ev(vim.eval("a:s"))')
    if exists('exc')
      throw exc
    endif
    return r
  endfunc

  py3 gopts1 = vim.options
  py3 wopts1 = vim.windows[2].options
  py3 wopts2 = vim.windows[0].options
  py3 wopts3 = vim.windows[1].options
  py3 bopts1 = vim.buffers[vim.bindeval("g:bufs")[2]].options
  py3 bopts2 = vim.buffers[vim.bindeval("g:bufs")[1]].options
  py3 bopts3 = vim.buffers[vim.bindeval("g:bufs")[0]].options
  call add(g:res, 'wopts iters equal: ' ..
        \ py3eval('list(wopts1) == list(wopts2)'))
  call add(g:res, 'bopts iters equal: ' ..
        \ py3eval('list(bopts1) == list(bopts2)'))
  py3 gset = set(iter(gopts1))
  py3 wset = set(iter(wopts1))
  py3 bset = set(iter(bopts1))

  set path=.,..,,
  let lst = []
  let lst += [['paste', 1, 0, 1, 2, 1, 1, 0]]
  let lst += [['previewheight', 5, 1, 6, 'a', 0, 1, 0]]
  let lst += [['operatorfunc', 'A', 'B', 'C', 2, 0, 1, 0]]
  let lst += [['number', 0, 1, 1, 0, 1, 0, 1]]
  let lst += [['numberwidth', 2, 3, 5, -100, 0, 0, 1]]
  let lst += [['colorcolumn', '+1', '+2', '+3', 'abc4', 0, 0, 1]]
  let lst += [['statusline', '1', '2', '4', 0, 0, 1, 1]]
  let lst += [['autoindent', 0, 1, 1, 2, 1, 0, 2]]
  let lst += [['shiftwidth', 0, 2, 1, 3, 0, 0, 2]]
  let lst += [['omnifunc', 'A', 'B', 'C', 1, 0, 0, 2]]
  let lst += [['preserveindent', 0, 1, 1, 2, 1, 1, 2]]
  let lst += [['path', '.,,', ',,', '.', 0, 0, 1, 2]]
  for  [oname, oval1, oval2, oval3, invval, bool, global, local] in lst
    py3 oname = vim.eval('oname')
    py3 oval1 = vim.bindeval('oval1')
    py3 oval2 = vim.bindeval('oval2')
    py3 oval3 = vim.bindeval('oval3')
    if invval is 0 || invval is 1
      py3 invval = bool(vim.bindeval('invval'))
    else
      py3 invval = vim.bindeval('invval')
    endif
    if bool
      py3 oval1 = bool(oval1)
      py3 oval2 = bool(oval2)
      py3 oval3 = bool(oval3)
    endif
    call add(g:res, '>>> ' .. oname)
    call add(g:res, '  g/w/b:' .. py3eval('oname in gset') .. '/' ..
          \ py3eval('oname in wset') .. '/' .. py3eval('oname in bset'))
    call add(g:res, '  g/w/b (in):' .. py3eval('oname in gopts1') .. '/' ..
          \ py3eval('oname in wopts1') .. '/' .. py3eval('oname in bopts1'))
    for v in ['gopts1', 'wopts1', 'bopts1']
      try
        call add(g:res, '  p/' .. v .. ': ' .. Ev('repr(' .. v .. '[''' .. oname .. '''])'))
      catch
        call add(g:res, '  p/' .. v .. '! ' .. v:exception)
      endtry
      let r = E(v .. '[''' .. oname .. ''']=invval')
      if r isnot 0
        call add(g:res, '  inv: ' .. string(invval) .. '! ' .. r)
      endif
      for vv in (v is# 'gopts1' ? [v] : [v, v[:-2] .. '2', v[:-2] .. '3'])
        let val = substitute(vv, '^.opts', 'oval', '')
        let r = E(vv .. '[''' .. oname .. ''']=' .. val)
        if r isnot 0
            call add(g:res, '  ' .. vv .. '! ' .. r)
        endif
      endfor
    endfor
    call RecVars(oname)
    for v in ['wopts3', 'bopts3']
      let r = E('del ' .. v .. '["' .. oname .. '"]')
      if r isnot 0
        call add(g:res, '  del ' .. v .. '! ' .. r)
      endif
    endfor
    call RecVars(oname)
  endfor
  delfunction RecVars
  delfunction E
  delfunction Ev
  py3 del ev
  py3 del e
  only
  for buf in g:bufs[1:]
    execute 'bwipeout!' buf
  endfor
  py3 del gopts1
  py3 del wopts1
  py3 del wopts2
  py3 del wopts3
  py3 del bopts1
  py3 del bopts2
  py3 del bopts3
  py3 del oval1
  py3 del oval2
  py3 del oval3
  py3 del oname
  py3 del invval

  let expected =<< trim END
    wopts iters equal: 1
    bopts iters equal: 1
    >>> paste
      g/w/b:1/0/0
      g/w/b (in):1/0/0
      p/gopts1: False
      p/wopts1! KeyError
      inv: 2! KeyError
      wopts1! KeyError
      wopts2! KeyError
      wopts3! KeyError
      p/bopts1! KeyError
      inv: 2! KeyError
      bopts1! KeyError
      bopts2! KeyError
      bopts3! KeyError
      G: 1
      W: 1:1 2:1 3:1 4:1
      B: 1:1 2:1 3:1 4:1
      del wopts3! KeyError
      del bopts3! KeyError
      G: 1
      W: 1:1 2:1 3:1 4:1
      B: 1:1 2:1 3:1 4:1
    >>> previewheight
      g/w/b:1/0/0
      g/w/b (in):1/0/0
      p/gopts1: 12
      inv: 'a'! TypeError
      p/wopts1! KeyError
      inv: 'a'! KeyError
      wopts1! KeyError
      wopts2! KeyError
      wopts3! KeyError
      p/bopts1! KeyError
      inv: 'a'! KeyError
      bopts1! KeyError
      bopts2! KeyError
      bopts3! KeyError
      G: 5
      W: 1:5 2:5 3:5 4:5
      B: 1:5 2:5 3:5 4:5
      del wopts3! KeyError
      del bopts3! KeyError
      G: 5
      W: 1:5 2:5 3:5 4:5
      B: 1:5 2:5 3:5 4:5
    >>> operatorfunc
      g/w/b:1/0/0
      g/w/b (in):1/0/0
      p/gopts1: b''
      inv: 2! TypeError
      p/wopts1! KeyError
      inv: 2! KeyError
      wopts1! KeyError
      wopts2! KeyError
      wopts3! KeyError
      p/bopts1! KeyError
      inv: 2! KeyError
      bopts1! KeyError
      bopts2! KeyError
      bopts3! KeyError
      G: 'A'
      W: 1:'A' 2:'A' 3:'A' 4:'A'
      B: 1:'A' 2:'A' 3:'A' 4:'A'
      del wopts3! KeyError
      del bopts3! KeyError
      G: 'A'
      W: 1:'A' 2:'A' 3:'A' 4:'A'
      B: 1:'A' 2:'A' 3:'A' 4:'A'
    >>> number
      g/w/b:0/1/0
      g/w/b (in):0/1/0
      p/gopts1! KeyError
      inv: 0! KeyError
      gopts1! KeyError
      p/wopts1: False
      p/bopts1! KeyError
      inv: 0! KeyError
      bopts1! KeyError
      bopts2! KeyError
      bopts3! KeyError
      G: 0
      W: 1:1 2:1 3:0 4:0
      B: 1:1 2:1 3:0 4:0
      del wopts3! ValueError
      del bopts3! KeyError
      G: 0
      W: 1:1 2:1 3:0 4:0
      B: 1:1 2:1 3:0 4:0
    >>> numberwidth
      g/w/b:0/1/0
      g/w/b (in):0/1/0
      p/gopts1! KeyError
      inv: -100! KeyError
      gopts1! KeyError
      p/wopts1: 4
      inv: -100! error
      p/bopts1! KeyError
      inv: -100! KeyError
      bopts1! KeyError
      bopts2! KeyError
      bopts3! KeyError
      G: 4
      W: 1:3 2:5 3:2 4:4
      B: 1:3 2:5 3:2 4:4
      del wopts3! ValueError
      del bopts3! KeyError
      G: 4
      W: 1:3 2:5 3:2 4:4
      B: 1:3 2:5 3:2 4:4
    >>> colorcolumn
      g/w/b:0/1/0
      g/w/b (in):0/1/0
      p/gopts1! KeyError
      inv: 'abc4'! KeyError
      gopts1! KeyError
      p/wopts1: b''
      inv: 'abc4'! error
      p/bopts1! KeyError
      inv: 'abc4'! KeyError
      bopts1! KeyError
      bopts2! KeyError
      bopts3! KeyError
      G: ''
      W: 1:'+2' 2:'+3' 3:'+1' 4:''
      B: 1:'+2' 2:'+3' 3:'+1' 4:''
      del wopts3! ValueError
      del bopts3! KeyError
      G: ''
      W: 1:'+2' 2:'+3' 3:'+1' 4:''
      B: 1:'+2' 2:'+3' 3:'+1' 4:''
    >>> statusline
      g/w/b:1/1/0
      g/w/b (in):1/1/0
      p/gopts1: b''
      inv: 0! TypeError
      p/wopts1: None
      inv: 0! TypeError
      p/bopts1! KeyError
      inv: 0! KeyError
      bopts1! KeyError
      bopts2! KeyError
      bopts3! KeyError
      G: '1'
      W: 1:'2' 2:'4' 3:'1' 4:'1'
      B: 1:'2' 2:'4' 3:'1' 4:'1'
      del bopts3! KeyError
      G: '1'
      W: 1:'2' 2:'1' 3:'1' 4:'1'
      B: 1:'2' 2:'1' 3:'1' 4:'1'
    >>> autoindent
      g/w/b:0/0/1
      g/w/b (in):0/0/1
      p/gopts1! KeyError
      inv: 2! KeyError
      gopts1! KeyError
      p/wopts1! KeyError
      inv: 2! KeyError
      wopts1! KeyError
      wopts2! KeyError
      wopts3! KeyError
      p/bopts1: False
      G: 0
      W: 1:0 2:1 3:0 4:1
      B: 1:0 2:1 3:0 4:1
      del wopts3! KeyError
      del bopts3! ValueError
      G: 0
      W: 1:0 2:1 3:0 4:1
      B: 1:0 2:1 3:0 4:1
    >>> shiftwidth
      g/w/b:0/0/1
      g/w/b (in):0/0/1
      p/gopts1! KeyError
      inv: 3! KeyError
      gopts1! KeyError
      p/wopts1! KeyError
      inv: 3! KeyError
      wopts1! KeyError
      wopts2! KeyError
      wopts3! KeyError
      p/bopts1: 8
      G: 8
      W: 1:0 2:2 3:8 4:1
      B: 1:0 2:2 3:8 4:1
      del wopts3! KeyError
      del bopts3! ValueError
      G: 8
      W: 1:0 2:2 3:8 4:1
      B: 1:0 2:2 3:8 4:1
    >>> omnifunc
      g/w/b:0/0/1
      g/w/b (in):0/0/1
      p/gopts1! KeyError
      inv: 1! KeyError
      gopts1! KeyError
      p/wopts1! KeyError
      inv: 1! KeyError
      wopts1! KeyError
      wopts2! KeyError
      wopts3! KeyError
      p/bopts1: b''
      inv: 1! TypeError
      G: ''
      W: 1:'A' 2:'B' 3:'' 4:'C'
      B: 1:'A' 2:'B' 3:'' 4:'C'
      del wopts3! KeyError
      del bopts3! ValueError
      G: ''
      W: 1:'A' 2:'B' 3:'' 4:'C'
      B: 1:'A' 2:'B' 3:'' 4:'C'
    >>> preserveindent
      g/w/b:0/0/1
      g/w/b (in):0/0/1
      p/gopts1! KeyError
      inv: 2! KeyError
      gopts1! KeyError
      p/wopts1! KeyError
      inv: 2! KeyError
      wopts1! KeyError
      wopts2! KeyError
      wopts3! KeyError
      p/bopts1: False
      G: 0
      W: 1:0 2:1 3:0 4:1
      B: 1:0 2:1 3:0 4:1
      del wopts3! KeyError
      del bopts3! ValueError
      G: 0
      W: 1:0 2:1 3:0 4:1
      B: 1:0 2:1 3:0 4:1
    >>> path
      g/w/b:1/0/1
      g/w/b (in):1/0/1
      p/gopts1: b'.,..,,'
      inv: 0! TypeError
      p/wopts1! KeyError
      inv: 0! KeyError
      wopts1! KeyError
      wopts2! KeyError
      wopts3! KeyError
      p/bopts1: None
      inv: 0! TypeError
      G: '.,,'
      W: 1:'.,,' 2:',,' 3:'.,,' 4:'.'
      B: 1:'.,,' 2:',,' 3:'.,,' 4:'.'
      del wopts3! KeyError
      G: '.,,'
      W: 1:'.,,' 2:',,' 3:'.,,' 4:'.,,'
      B: 1:'.,,' 2:',,' 3:'.,,' 4:'.,,'
  END

  call assert_equal(expected, g:res)
  unlet g:res
endfunc

" Test for vim.buffer object
func Test_python3_buffer()
  throw 'Skipped: TODO: '
  new
  call setline(1, "Hello\nWorld")
  call assert_fails("let x = py3eval('vim.current.buffer[0]')", 'E859:')
  %bw!

  edit Xfile1
  let bnr1 = bufnr()
  py3 cb = vim.current.buffer
  vnew Xfile2
  let bnr2 = bufnr()
  call setline(1, ['First line', 'Second line', 'Third line'])
  py3 b = vim.current.buffer
  wincmd w

  " Tests BufferAppend and BufferItem
  py3 cb.append(b[0])
  call assert_equal(['First line'], getbufline(bnr1, 2))
  %d

  " Tests BufferSlice and BufferAssSlice
  py3 cb.append('abc5') # Will be overwritten
  py3 cb[-1:] = b[:-2]
  call assert_equal(['First line'], getbufline(bnr1, 2))
  %d

  " Test BufferLength and BufferAssSlice
  py3 cb.append('def') # Will not be overwritten
  py3 cb[len(cb):] = b[:]
  call assert_equal(['def', 'First line', 'Second line', 'Third line'],
        \ getbufline(bnr1, 2, '$'))
  %d

  " Test BufferAssItem and BufferMark
  call setbufline(bnr1, 1, ['one', 'two', 'three'])
  call cursor(1, 3)
  normal ma
  py3 cb.append('ghi') # Will be overwritten
  py3 cb[-1] = repr((len(cb) - cb.mark('a')[0], cb.mark('a')[1]))
  call assert_equal(['(3, 2)'], getbufline(bnr1, 4))
  %d

  " Test BufferRepr
  py3 cb.append(repr(cb) + repr(b))
  call assert_equal(['<buffer Xfile1><buffer Xfile2>'], getbufline(bnr1, 2))
  %d

  " Modify foreign buffer
  py3 << trim EOF
    b.append('foo')
    b[0]='bar'
    b[0:0]=['baz']
    vim.command('call append("$", getbufline(%i, 1, "$"))' % b.number)
  EOF
  call assert_equal(['baz', 'bar', 'Second line', 'Third line', 'foo'],
        \ getbufline(bnr2, 1, '$'))
  %d

  " Test assigning to name property
  augroup BUFS
    autocmd BufFilePost * python3 cb.append(vim.eval('expand("<abuf>")') + ':BufFilePost:' + vim.eval('bufnr("%")'))
    autocmd BufFilePre * python3 cb.append(vim.eval('expand("<abuf>")') + ':BufFilePre:' + vim.eval('bufnr("%")'))
  augroup END
  py3 << trim EOF
    import os
    old_name = cb.name
    cb.name = 'foo'
    cb.append(cb.name[-11:].replace(os.path.sep, '/'))
    b.name = 'bar'
    cb.append(b.name[-11:].replace(os.path.sep, '/'))
    cb.name = old_name
    cb.append(cb.name[-14:].replace(os.path.sep, '/'))
    del old_name
  EOF
  call assert_equal([bnr1 .. ':BufFilePre:' .. bnr1,
        \ bnr1 .. ':BufFilePost:' .. bnr1,
        \ 'testdir/foo',
        \ bnr2 .. ':BufFilePre:' .. bnr2,
        \ bnr2 .. ':BufFilePost:' .. bnr2,
        \ 'testdir/bar',
        \ bnr1 .. ':BufFilePre:' .. bnr1,
        \ bnr1 .. ':BufFilePost:' .. bnr1,
        \ 'testdir/Xfile1'], getbufline(bnr1, 2, '$'))
  %d

  " Test CheckBuffer
  py3 << trim EOF
    for _b in vim.buffers:
      if _b is not cb:
        vim.command('bwipeout! ' + str(_b.number))
    del _b
    cb.append('valid: b:%s, cb:%s' % (repr(b.valid), repr(cb.valid)))
  EOF
  call assert_equal('valid: b:False, cb:True', getline(2))
  %d

  py3 << trim EOF
    for expr in ('b[1]','b[:] = ["A", "B"]','b[:]','b.append("abc6")'):
      try:
        exec(expr)
      except vim.error:
        pass
      else:
        # Usually a SEGV here
        # Should not happen in any case
        cb.append('No exception for ' + expr)
    vim.command('cd .')
    del b
  EOF
  call assert_equal([''], getline(1, '$'))

  augroup BUFS
    autocmd!
  augroup END
  augroup! BUFS
  %bw!
endfunc

" Test vim.buffers object
func Test_python3_buffers()
  throw 'Skipped: TODO: '
  %bw!
  edit Xfile
  py3 cb = vim.current.buffer
  set hidden
  edit a
  buffer #
  edit b
  buffer #
  edit c
  buffer #
  py3 << trim EOF
    # Check GCing iterator that was not fully exhausted
    i = iter(vim.buffers)
    cb.append('i:' + str(next(i)))
    # and also check creating more than one iterator at a time
    i2 = iter(vim.buffers)
    cb.append('i2:' + str(next(i2)))
    cb.append('i:' + str(next(i)))
    # The following should trigger GC and not cause any problems
    del i
    del i2
    i3 = iter(vim.buffers)
    cb.append('i3:' + str(next(i3)))
    del i3
  EOF
  call assert_equal(['i:<buffer Xfile>',
        \ 'i2:<buffer Xfile>', 'i:<buffer a>', 'i3:<buffer Xfile>'],
        \ getline(2, '$'))
  %d

  py3 << trim EOF
    prevnum = 0
    for b in vim.buffers:
      # Check buffer order
      if prevnum >= b.number:
        cb.append('!!! Buffer numbers not in strictly ascending order')
      # Check indexing: vim.buffers[number].number == number
      cb.append(str(b.number) + ':' + repr(vim.buffers[b.number]) + \
                                                            '=' + repr(b))
      prevnum = b.number
    del prevnum

    cb.append(str(len(vim.buffers)))
  EOF
  call assert_equal([bufnr('Xfile') .. ':<buffer Xfile>=<buffer Xfile>',
        \ bufnr('a') .. ':<buffer a>=<buffer a>',
        \ bufnr('b') .. ':<buffer b>=<buffer b>',
        \ bufnr('c') .. ':<buffer c>=<buffer c>', '4'], getline(2, '$'))
  %d

  py3 << trim EOF
    bnums = list(map(lambda b: b.number, vim.buffers))[1:]

    # Test wiping out buffer with existing iterator
    i4 = iter(vim.buffers)
    cb.append('i4:' + str(next(i4)))
    vim.command('bwipeout! ' + str(bnums.pop(0)))
    try:
      next(i4)
    except vim.error:
      pass
    else:
      cb.append('!!!! No vim.error')
    i4 = iter(vim.buffers)
    vim.command('bwipeout! ' + str(bnums.pop(-1)))
    vim.command('bwipeout! ' + str(bnums.pop(-1)))
    cb.append('i4:' + str(next(i4)))
    try:
      next(i4)
    except StopIteration:
      cb.append('StopIteration')
    del i4
    del bnums
  EOF
  call assert_equal(['i4:<buffer Xfile>',
        \ 'i4:<buffer Xfile>', 'StopIteration'], getline(2, '$'))
  %bw!
endfunc

" Test vim.{tabpage,window}list and vim.{tabpage,window} objects
func Test_python3_tabpage_window()
  throw 'Skipped: TODO: '
  %bw
  edit Xfile
  py3 cb = vim.current.buffer
  tabnew 0
  tabnew 1
  vnew a.1
  tabnew 2
  vnew a.2
  vnew b.2
  vnew c.2

  py3 << trim EOF
    cb.append('Number of tabs: ' + str(len(vim.tabpages)))
    cb.append('Current tab pages:')
    def W(w):
      if '(unknown)' in repr(w):
        return '<window object (unknown)>'
      else:
        return repr(w)

    def Cursor(w, start=len(cb)):
      if w.buffer is cb:
        return repr((start - w.cursor[0], w.cursor[1]))
      else:
        return repr(w.cursor)

    for t in vim.tabpages:
      cb.append('  ' + repr(t) + '(' + str(t.number) + ')' + ': ' + \
                str(len(t.windows)) + ' windows, current is ' + W(t.window))
      cb.append('  Windows:')
      for w in t.windows:
        cb.append('    ' + W(w) + '(' + str(w.number) + ')' + \
                                  ': displays buffer ' + repr(w.buffer) + \
                                  '; cursor is at ' + Cursor(w))
        # Other values depend on the size of the terminal, so they are checked
        # partly:
        for attr in ('height', 'row', 'width', 'col'):
          try:
            aval = getattr(w, attr)
            if type(aval) is not int:
              raise TypeError
            if aval < 0:
              raise ValueError
          except Exception as e:
            cb.append('!!!!!! Error while getting attribute ' + attr + \
                                            ': ' + e.__class__.__name__)
        del aval
        del attr
        w.cursor = (len(w.buffer), 0)
    del W
    del Cursor
    cb.append('Number of windows in current tab page: ' + \
                                                    str(len(vim.windows)))
    if list(vim.windows) != list(vim.current.tabpage.windows):
      cb.append('!!!!!! Windows differ')
  EOF

  let expected =<< trim END
    Number of tabs: 4
    Current tab pages:
      <tabpage 0>(1): 1 windows, current is <window object (unknown)>
      Windows:
        <window object (unknown)>(1): displays buffer <buffer Xfile>; cursor is at (2, 0)
      <tabpage 1>(2): 1 windows, current is <window object (unknown)>
      Windows:
        <window object (unknown)>(1): displays buffer <buffer 0>; cursor is at (1, 0)
      <tabpage 2>(3): 2 windows, current is <window object (unknown)>
      Windows:
        <window object (unknown)>(1): displays buffer <buffer a.1>; cursor is at (1, 0)
        <window object (unknown)>(2): displays buffer <buffer 1>; cursor is at (1, 0)
      <tabpage 3>(4): 4 windows, current is <window 0>
      Windows:
        <window 0>(1): displays buffer <buffer c.2>; cursor is at (1, 0)
        <window 1>(2): displays buffer <buffer b.2>; cursor is at (1, 0)
        <window 2>(3): displays buffer <buffer a.2>; cursor is at (1, 0)
        <window 3>(4): displays buffer <buffer 2>; cursor is at (1, 0)
    Number of windows in current tab page: 4
  END
  call assert_equal(expected, getbufline(bufnr('Xfile'), 2, '$'))
  %bw!
endfunc

" Test vim.current
func Test_python3_vim_current()
  throw 'Skipped: TODO: '
  %bw
  edit Xfile
  py3 cb = vim.current.buffer
  tabnew 0
  tabnew 1
  vnew a.1
  tabnew 2
  vnew a.2
  vnew b.2
  vnew c.2

  py3 << trim EOF
    def H(o):
      return repr(o)
    cb.append('Current tab page: ' + repr(vim.current.tabpage))
    cb.append('Current window: ' + repr(vim.current.window) + ': ' + \
               H(vim.current.window) + ' is ' + H(vim.current.tabpage.window))
    cb.append('Current buffer: ' + repr(vim.current.buffer) + ': ' + \
               H(vim.current.buffer) + ' is ' + H(vim.current.window.buffer)+ \
               ' is ' + H(vim.current.tabpage.window.buffer))
    del H
  EOF
  let expected =<< trim END
    Current tab page: <tabpage 3>
    Current window: <window 0>: <window 0> is <window 0>
    Current buffer: <buffer c.2>: <buffer c.2> is <buffer c.2> is <buffer c.2>
  END
  call assert_equal(expected, getbufline(bufnr('Xfile'), 2, '$'))
  call deletebufline(bufnr('Xfile'), 1, '$')

  " Assigning: fails
  py3 << trim EOF
    try:
      vim.current.window = vim.tabpages[0].window
    except ValueError:
      cb.append('ValueError at assigning foreign tab window')

    for attr in ('window', 'tabpage', 'buffer'):
      try:
        setattr(vim.current, attr, None)
      except TypeError:
        cb.append('Type error at assigning None to vim.current.' + attr)
    del attr
  EOF

  let expected =<< trim END
    ValueError at assigning foreign tab window
    Type error at assigning None to vim.current.window
    Type error at assigning None to vim.current.tabpage
    Type error at assigning None to vim.current.buffer
  END
  call assert_equal(expected, getbufline(bufnr('Xfile'), 2, '$'))
  call deletebufline(bufnr('Xfile'), 1, '$')

  call setbufline(bufnr('Xfile'), 1, 'python interface')
  py3 << trim EOF
    # Assigning: success
    vim.current.tabpage = vim.tabpages[-2]
    vim.current.buffer = cb
    vim.current.window = vim.windows[0]
    vim.current.window.cursor = (len(vim.current.buffer), 0)
    cb.append('Current tab page: ' + repr(vim.current.tabpage))
    cb.append('Current window: ' + repr(vim.current.window))
    cb.append('Current buffer: ' + repr(vim.current.buffer))
    cb.append('Current line: ' + repr(vim.current.line))
  EOF

  let expected =<< trim END
    Current tab page: <tabpage 2>
    Current window: <window 0>
    Current buffer: <buffer Xfile>
    Current line: 'python interface'
  END
  call assert_equal(expected, getbufline(bufnr('Xfile'), 2, '$'))
  call deletebufline(bufnr('Xfile'), 1, '$')

  py3 << trim EOF
    ws = list(vim.windows)
    ts = list(vim.tabpages)
    for b in vim.buffers:
      if b is not cb:
        vim.command('bwipeout! ' + str(b.number))
    del b
    cb.append('w.valid: ' + repr([w.valid for w in ws]))
    cb.append('t.valid: ' + repr([t.valid for t in ts]))
    del w
    del t
    del ts
    del ws
  EOF
  let expected =<< trim END
    w.valid: [True, False]
    t.valid: [True, False, True, False]
  END
  call assert_equal(expected, getbufline(bufnr('Xfile'), 2, '$'))
  %bw!
endfunc

" Test types
func Test_python3_types()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  %d
  py3 cb = vim.current.buffer
  py3 << trim EOF
    for expr, attr in (
      ('vim.vars',                         'Dictionary'),
      ('vim.options',                      'Options'),
      ('vim.bindeval("{}")',               'Dictionary'),
      ('vim.bindeval("[]")',               'List'),
      ('vim.bindeval("function(\'tr\')")', 'Function'),
      ('vim.current.buffer',               'Buffer'),
      ('vim.current.range',                'Range'),
      ('vim.current.window',               'Window'),
      ('vim.current.tabpage',              'TabPage'),
    ):
      cb.append(expr + ':' + attr + ':' + \
                                repr(type(eval(expr)) is getattr(vim, attr)))
    del expr
    del attr
  EOF
  let expected =<< trim END
    vim.vars:Dictionary:True
    vim.options:Options:True
    vim.bindeval("{}"):Dictionary:True
    vim.bindeval("[]"):List:True
    vim.bindeval("function('tr')"):Function:True
    vim.current.buffer:Buffer:True
    vim.current.range:Range:True
    vim.current.window:Window:True
    vim.current.tabpage:TabPage:True
  END
  call assert_equal(expected, getline(2, '$'))
endfunc

" Test __dir__() method
func Test_python3_dir_method()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  %d
  py3 cb = vim.current.buffer
  py3 << trim EOF
    for name, o in (
            ('current',    vim.current),
            ('buffer',     vim.current.buffer),
            ('window',     vim.current.window),
            ('tabpage',    vim.current.tabpage),
            ('range',      vim.current.range),
            ('dictionary', vim.bindeval('{}')),
            ('list',       vim.bindeval('[]')),
            ('function',   vim.bindeval('function("tr")')),
            ('output',     sys.stdout),
        ):
        cb.append(name + ':' + ','.join(dir(o)))
    del name
    del o
  EOF
  let expected =<< trim END
    current:__dir__,buffer,line,range,tabpage,window
    buffer:__dir__,append,mark,name,number,options,range,valid,vars
    window:__dir__,buffer,col,cursor,height,number,options,row,tabpage,valid,vars,width
    tabpage:__dir__,number,valid,vars,window,windows
    range:__dir__,append,end,start
    dictionary:__dir__,get,has_key,items,keys,locked,pop,popitem,scope,update,values
    list:__dir__,extend,locked
    function:__dir__,args,auto_rebind,self,softspace
    output:__dir__,close,closed,flush,isatty,readable,seekable,softspace,writable,write,writelines
  END
  call assert_equal(expected, getline(2, '$'))
endfunc

" Test vim.*.__new__
func Test_python3_new()
  throw "Skipped: Nvim: 'LegacyVim' object has no attribute 'Dictionary'"
  call assert_equal({}, py3eval('vim.Dictionary({})'))
  call assert_equal({'a': 1}, py3eval('vim.Dictionary(a=1)'))
  call assert_equal({'a': 1}, py3eval('vim.Dictionary(((''a'', 1),))'))
  call assert_equal([], py3eval('vim.List()'))
  call assert_equal(['a', 'b', 'c', '7'], py3eval('vim.List(iter(''abc7''))'))
  call assert_equal(function('tr'), py3eval('vim.Function(''tr'')'))
  call assert_equal(function('tr', [123, 3, 4]),
        \ py3eval('vim.Function(''tr'', args=[123, 3, 4])'))
  call assert_equal(function('tr'), py3eval('vim.Function(''tr'', args=[])'))
  call assert_equal(function('tr', {}),
        \ py3eval('vim.Function(''tr'', self={})'))
  call assert_equal(function('tr', [123, 3, 4], {}),
        \ py3eval('vim.Function(''tr'', args=[123, 3, 4], self={})'))
  call assert_equal(function('tr'),
        \ py3eval('vim.Function(''tr'', auto_rebind=False)'))
  call assert_equal(function('tr', [123, 3, 4]),
        \ py3eval('vim.Function(''tr'', args=[123, 3, 4], auto_rebind=False)'))
  call assert_equal(function('tr'),
        \ py3eval('vim.Function(''tr'', args=[], auto_rebind=False)'))
  call assert_equal(function('tr', {}),
        \ py3eval('vim.Function(''tr'', self={}, auto_rebind=False)'))
  call assert_equal(function('tr', [123, 3, 4], {}),
        \ py3eval('vim.Function(''tr'', args=[123, 3, 4], self={}, auto_rebind=False)'))
endfunc

" Test vim.Function
func Test_python3_vim_func()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  function Args(...)
    return a:000
  endfunc

  function SelfArgs(...) dict
    return [a:000, self]
  endfunc

  " The following four lines should not crash
  let Pt = function('tr', [[]], {'l': []})
  py3 Pt = vim.bindeval('Pt')
  unlet Pt
  py3 del Pt

  %bw!
  py3 cb = vim.current.buffer
  py3 << trim EOF
    def ecall(out_prefix, func, *args, **kwargs):
        line = out_prefix + ': '
        try:
            ret = func(*args, **kwargs)
        except Exception:
            line += '!exception: ' + emsg(sys.exc_info())
        else:
            line += '!result: ' + str(vim.Function('string')(ret), 'utf-8')
        cb.append(line)
    a = vim.Function('Args')
    pa1 = vim.Function('Args', args=['abcArgsPA1'])
    pa2 = vim.Function('Args', args=[])
    pa3 = vim.Function('Args', args=['abcArgsPA3'], self={'abcSelfPA3': 'abcSelfPA3Val'})
    pa4 = vim.Function('Args', self={'abcSelfPA4': 'abcSelfPA4Val'})
    cb.append('a: ' + repr(a))
    cb.append('pa1: ' + repr(pa1))
    cb.append('pa2: ' + repr(pa2))
    cb.append('pa3: ' + repr(pa3))
    cb.append('pa4: ' + repr(pa4))
    sa = vim.Function('SelfArgs')
    psa1 = vim.Function('SelfArgs', args=['abcArgsPSA1'])
    psa2 = vim.Function('SelfArgs', args=[])
    psa3 = vim.Function('SelfArgs', args=['abcArgsPSA3'], self={'abcSelfPSA3': 'abcSelfPSA3Val'})
    psa4 = vim.Function('SelfArgs', self={'abcSelfPSA4': 'abcSelfPSA4Val'})
    psa5 = vim.Function('SelfArgs', self={'abcSelfPSA5': 'abcSelfPSA5Val'}, auto_rebind=0)
    psa6 = vim.Function('SelfArgs', args=['abcArgsPSA6'], self={'abcSelfPSA6': 'abcSelfPSA6Val'}, auto_rebind=())
    psa7 = vim.Function('SelfArgs', args=['abcArgsPSA7'], auto_rebind=[])
    psa8 = vim.Function('SelfArgs', auto_rebind=False)
    psa9 = vim.Function('SelfArgs', self={'abcSelfPSA9': 'abcSelfPSA9Val'}, auto_rebind=True)
    psaA = vim.Function('SelfArgs', args=['abcArgsPSAA'], self={'abcSelfPSAA': 'abcSelfPSAAVal'}, auto_rebind=1)
    psaB = vim.Function('SelfArgs', args=['abcArgsPSAB'], auto_rebind={'abcARPSAB': 'abcARPSABVal'})
    psaC = vim.Function('SelfArgs', auto_rebind=['abcARPSAC'])
    cb.append('sa: ' + repr(sa))
    cb.append('psa1: ' + repr(psa1))
    cb.append('psa2: ' + repr(psa2))
    cb.append('psa3: ' + repr(psa3))
    cb.append('psa4: ' + repr(psa4))
    cb.append('psa5: ' + repr(psa5))
    cb.append('psa6: ' + repr(psa6))
    cb.append('psa7: ' + repr(psa7))
    cb.append('psa8: ' + repr(psa8))
    cb.append('psa9: ' + repr(psa9))
    cb.append('psaA: ' + repr(psaA))
    cb.append('psaB: ' + repr(psaB))
    cb.append('psaC: ' + repr(psaC))

    psar = vim.Function('SelfArgs', args=[{'abcArgsPSAr': 'abcArgsPSArVal'}], self={'abcSelfPSAr': 'abcSelfPSArVal'})
    psar.args[0]['abcArgsPSAr2'] = [psar.self, psar.args[0]]
    psar.self['rec'] = psar
    psar.self['self'] = psar.self
    psar.self['args'] = psar.args

    try:
      cb.append('psar: ' + repr(psar))
    except Exception:
      cb.append('!!!!!!!! Caught exception: ' + emsg(sys.exc_info()))
  EOF

  let expected =<< trim END
    a: <vim.Function 'Args'>
    pa1: <vim.Function 'Args', args=['abcArgsPA1']>
    pa2: <vim.Function 'Args'>
    pa3: <vim.Function 'Args', args=['abcArgsPA3'], self={'abcSelfPA3': 'abcSelfPA3Val'}>
    pa4: <vim.Function 'Args', self={'abcSelfPA4': 'abcSelfPA4Val'}>
    sa: <vim.Function 'SelfArgs'>
    psa1: <vim.Function 'SelfArgs', args=['abcArgsPSA1']>
    psa2: <vim.Function 'SelfArgs'>
    psa3: <vim.Function 'SelfArgs', args=['abcArgsPSA3'], self={'abcSelfPSA3': 'abcSelfPSA3Val'}>
    psa4: <vim.Function 'SelfArgs', self={'abcSelfPSA4': 'abcSelfPSA4Val'}>
    psa5: <vim.Function 'SelfArgs', self={'abcSelfPSA5': 'abcSelfPSA5Val'}>
    psa6: <vim.Function 'SelfArgs', args=['abcArgsPSA6'], self={'abcSelfPSA6': 'abcSelfPSA6Val'}>
    psa7: <vim.Function 'SelfArgs', args=['abcArgsPSA7']>
    psa8: <vim.Function 'SelfArgs'>
    psa9: <vim.Function 'SelfArgs', self={'abcSelfPSA9': 'abcSelfPSA9Val'}, auto_rebind=True>
    psaA: <vim.Function 'SelfArgs', args=['abcArgsPSAA'], self={'abcSelfPSAA': 'abcSelfPSAAVal'}, auto_rebind=True>
    psaB: <vim.Function 'SelfArgs', args=['abcArgsPSAB']>
    psaC: <vim.Function 'SelfArgs'>
    psar: <vim.Function 'SelfArgs', args=[{'abcArgsPSAr2': [{'rec': function('SelfArgs', [{...}], {...}), 'self': {...}, 'abcSelfPSAr': 'abcSelfPSArVal', 'args': [{...}]}, {...}], 'abcArgsPSAr': 'abcArgsPSArVal'}], self={'rec': function('SelfArgs', [{'abcArgsPSAr2': [{...}, {...}], 'abcArgsPSAr': 'abcArgsPSArVal'}], {...}), 'self': {...}, 'abcSelfPSAr': 'abcSelfPSArVal', 'args': [{'abcArgsPSAr2': [{...}, {...}], 'abcArgsPSAr': 'abcArgsPSArVal'}]}>
  END
  call assert_equal(expected, getline(2, '$'))
  %d

  call assert_equal(function('Args'), py3eval('a'))
  call assert_equal(function('Args', ['abcArgsPA1']), py3eval('pa1'))
  call assert_equal(function('Args'), py3eval('pa2'))
  call assert_equal(function('Args', ['abcArgsPA3'], {'abcSelfPA3': 'abcSelfPA3Val'}), py3eval('pa3'))
  call assert_equal(function('Args', {'abcSelfPA4': 'abcSelfPA4Val'}), py3eval('pa4'))
  call assert_equal(function('SelfArgs'), py3eval('sa'))
  call assert_equal(function('SelfArgs', ['abcArgsPSA1']), py3eval('psa1'))
  call assert_equal(function('SelfArgs'), py3eval('psa2'))
  call assert_equal(function('SelfArgs', ['abcArgsPSA3'], {'abcSelfPSA3': 'abcSelfPSA3Val'}), py3eval('psa3'))
  call assert_equal(function('SelfArgs', {'abcSelfPSA4': 'abcSelfPSA4Val'}), py3eval('psa4'))
  call assert_equal(function('SelfArgs', {'abcSelfPSA5': 'abcSelfPSA5Val'}), py3eval('psa5'))
  call assert_equal(function('SelfArgs', ['abcArgsPSA6'], {'abcSelfPSA6': 'abcSelfPSA6Val'}), py3eval('psa6'))
  call assert_equal(function('SelfArgs', ['abcArgsPSA7']), py3eval('psa7'))
  call assert_equal(function('SelfArgs'), py3eval('psa8'))
  call assert_equal(function('SelfArgs', {'abcSelfPSA9': 'abcSelfPSA9Val'}), py3eval('psa9'))
  call assert_equal(function('SelfArgs', ['abcArgsPSAA'], {'abcSelfPSAA': 'abcSelfPSAAVal'}), py3eval('psaA'))
  call assert_equal(function('SelfArgs', ['abcArgsPSAB']), py3eval('psaB'))
  call assert_equal(function('SelfArgs'), py3eval('psaC'))

  let res = []
  for v in ['sa', 'psa1', 'psa2', 'psa3', 'psa4', 'psa5', 'psa6', 'psa7',
        \ 'psa8', 'psa9', 'psaA', 'psaB', 'psaC']
    let d = {'f': py3eval(v)}
    call add(res, 'd.' .. v .. '(): ' .. string(d.f()))
  endfor

  let expected =<< trim END
    d.sa(): [[], {'f': function('SelfArgs')}]
    d.psa1(): [['abcArgsPSA1'], {'f': function('SelfArgs', ['abcArgsPSA1'])}]
    d.psa2(): [[], {'f': function('SelfArgs')}]
    d.psa3(): [['abcArgsPSA3'], {'abcSelfPSA3': 'abcSelfPSA3Val'}]
    d.psa4(): [[], {'abcSelfPSA4': 'abcSelfPSA4Val'}]
    d.psa5(): [[], {'abcSelfPSA5': 'abcSelfPSA5Val'}]
    d.psa6(): [['abcArgsPSA6'], {'abcSelfPSA6': 'abcSelfPSA6Val'}]
    d.psa7(): [['abcArgsPSA7'], {'f': function('SelfArgs', ['abcArgsPSA7'])}]
    d.psa8(): [[], {'f': function('SelfArgs')}]
    d.psa9(): [[], {'f': function('SelfArgs', {'abcSelfPSA9': 'abcSelfPSA9Val'})}]
    d.psaA(): [['abcArgsPSAA'], {'f': function('SelfArgs', ['abcArgsPSAA'], {'abcSelfPSAA': 'abcSelfPSAAVal'})}]
    d.psaB(): [['abcArgsPSAB'], {'f': function('SelfArgs', ['abcArgsPSAB'])}]
    d.psaC(): [[], {'f': function('SelfArgs')}]
  END
  call assert_equal(expected, res)

  py3 ecall('a()', a, )
  py3 ecall('pa1()', pa1, )
  py3 ecall('pa2()', pa2, )
  py3 ecall('pa3()', pa3, )
  py3 ecall('pa4()', pa4, )
  py3 ecall('sa()', sa, )
  py3 ecall('psa1()', psa1, )
  py3 ecall('psa2()', psa2, )
  py3 ecall('psa3()', psa3, )
  py3 ecall('psa4()', psa4, )

  py3 ecall('a(42, 43)', a, 42, 43)
  py3 ecall('pa1(42, 43)', pa1, 42, 43)
  py3 ecall('pa2(42, 43)', pa2, 42, 43)
  py3 ecall('pa3(42, 43)', pa3, 42, 43)
  py3 ecall('pa4(42, 43)', pa4, 42, 43)
  py3 ecall('sa(42, 43)', sa, 42, 43)
  py3 ecall('psa1(42, 43)', psa1, 42, 43)
  py3 ecall('psa2(42, 43)', psa2, 42, 43)
  py3 ecall('psa3(42, 43)', psa3, 42, 43)
  py3 ecall('psa4(42, 43)', psa4, 42, 43)

  py3 ecall('a(42, self={"20": 1})', a, 42, self={'20': 1})
  py3 ecall('pa1(42, self={"20": 1})', pa1, 42, self={'20': 1})
  py3 ecall('pa2(42, self={"20": 1})', pa2, 42, self={'20': 1})
  py3 ecall('pa3(42, self={"20": 1})', pa3, 42, self={'20': 1})
  py3 ecall('pa4(42, self={"20": 1})', pa4, 42, self={'20': 1})
  py3 ecall('sa(42, self={"20": 1})', sa, 42, self={'20': 1})
  py3 ecall('psa1(42, self={"20": 1})', psa1, 42, self={'20': 1})
  py3 ecall('psa2(42, self={"20": 1})', psa2, 42, self={'20': 1})
  py3 ecall('psa3(42, self={"20": 1})', psa3, 42, self={'20': 1})
  py3 ecall('psa4(42, self={"20": 1})', psa4, 42, self={'20': 1})

  py3 ecall('a(self={"20": 1})', a, self={'20': 1})
  py3 ecall('pa1(self={"20": 1})', pa1, self={'20': 1})
  py3 ecall('pa2(self={"20": 1})', pa2, self={'20': 1})
  py3 ecall('pa3(self={"20": 1})', pa3, self={'20': 1})
  py3 ecall('pa4(self={"20": 1})', pa4, self={'20': 1})
  py3 ecall('sa(self={"20": 1})', sa, self={'20': 1})
  py3 ecall('psa1(self={"20": 1})', psa1, self={'20': 1})
  py3 ecall('psa2(self={"20": 1})', psa2, self={'20': 1})
  py3 ecall('psa3(self={"20": 1})', psa3, self={'20': 1})
  py3 ecall('psa4(self={"20": 1})', psa4, self={'20': 1})

  py3 << trim EOF
    def s(v):
        if v is None:
            return repr(v)
        else:
            return str(vim.Function('string')(v), 'utf-8')

    cb.append('a.args: ' + s(a.args))
    cb.append('pa1.args: ' + s(pa1.args))
    cb.append('pa2.args: ' + s(pa2.args))
    cb.append('pa3.args: ' + s(pa3.args))
    cb.append('pa4.args: ' + s(pa4.args))
    cb.append('sa.args: ' + s(sa.args))
    cb.append('psa1.args: ' + s(psa1.args))
    cb.append('psa2.args: ' + s(psa2.args))
    cb.append('psa3.args: ' + s(psa3.args))
    cb.append('psa4.args: ' + s(psa4.args))

    cb.append('a.self: ' + s(a.self))
    cb.append('pa1.self: ' + s(pa1.self))
    cb.append('pa2.self: ' + s(pa2.self))
    cb.append('pa3.self: ' + s(pa3.self))
    cb.append('pa4.self: ' + s(pa4.self))
    cb.append('sa.self: ' + s(sa.self))
    cb.append('psa1.self: ' + s(psa1.self))
    cb.append('psa2.self: ' + s(psa2.self))
    cb.append('psa3.self: ' + s(psa3.self))
    cb.append('psa4.self: ' + s(psa4.self))

    cb.append('a.name: ' + s(a.name))
    cb.append('pa1.name: ' + s(pa1.name))
    cb.append('pa2.name: ' + s(pa2.name))
    cb.append('pa3.name: ' + s(pa3.name))
    cb.append('pa4.name: ' + s(pa4.name))
    cb.append('sa.name: ' + s(sa.name))
    cb.append('psa1.name: ' + s(psa1.name))
    cb.append('psa2.name: ' + s(psa2.name))
    cb.append('psa3.name: ' + s(psa3.name))
    cb.append('psa4.name: ' + s(psa4.name))

    cb.append('a.auto_rebind: ' + s(a.auto_rebind))
    cb.append('pa1.auto_rebind: ' + s(pa1.auto_rebind))
    cb.append('pa2.auto_rebind: ' + s(pa2.auto_rebind))
    cb.append('pa3.auto_rebind: ' + s(pa3.auto_rebind))
    cb.append('pa4.auto_rebind: ' + s(pa4.auto_rebind))
    cb.append('sa.auto_rebind: ' + s(sa.auto_rebind))
    cb.append('psa1.auto_rebind: ' + s(psa1.auto_rebind))
    cb.append('psa2.auto_rebind: ' + s(psa2.auto_rebind))
    cb.append('psa3.auto_rebind: ' + s(psa3.auto_rebind))
    cb.append('psa4.auto_rebind: ' + s(psa4.auto_rebind))
    cb.append('psa5.auto_rebind: ' + s(psa5.auto_rebind))
    cb.append('psa6.auto_rebind: ' + s(psa6.auto_rebind))
    cb.append('psa7.auto_rebind: ' + s(psa7.auto_rebind))
    cb.append('psa8.auto_rebind: ' + s(psa8.auto_rebind))
    cb.append('psa9.auto_rebind: ' + s(psa9.auto_rebind))
    cb.append('psaA.auto_rebind: ' + s(psaA.auto_rebind))
    cb.append('psaB.auto_rebind: ' + s(psaB.auto_rebind))
    cb.append('psaC.auto_rebind: ' + s(psaC.auto_rebind))

    del s

    del a
    del pa1
    del pa2
    del pa3
    del pa4
    del sa
    del psa1
    del psa2
    del psa3
    del psa4
    del psa5
    del psa6
    del psa7
    del psa8
    del psa9
    del psaA
    del psaB
    del psaC
    del psar

    del ecall
  EOF

  let expected =<< trim END
    a(): !result: []
    pa1(): !result: ['abcArgsPA1']
    pa2(): !result: []
    pa3(): !result: ['abcArgsPA3']
    pa4(): !result: []
    sa(): !exception: error:('Vim:E725: Calling dict function without Dictionary: SelfArgs',)
    psa1(): !exception: error:('Vim:E725: Calling dict function without Dictionary: SelfArgs',)
    psa2(): !exception: error:('Vim:E725: Calling dict function without Dictionary: SelfArgs',)
    psa3(): !result: [['abcArgsPSA3'], {'abcSelfPSA3': 'abcSelfPSA3Val'}]
    psa4(): !result: [[], {'abcSelfPSA4': 'abcSelfPSA4Val'}]
    a(42, 43): !result: [42, 43]
    pa1(42, 43): !result: ['abcArgsPA1', 42, 43]
    pa2(42, 43): !result: [42, 43]
    pa3(42, 43): !result: ['abcArgsPA3', 42, 43]
    pa4(42, 43): !result: [42, 43]
    sa(42, 43): !exception: error:('Vim:E725: Calling dict function without Dictionary: SelfArgs',)
    psa1(42, 43): !exception: error:('Vim:E725: Calling dict function without Dictionary: SelfArgs',)
    psa2(42, 43): !exception: error:('Vim:E725: Calling dict function without Dictionary: SelfArgs',)
    psa3(42, 43): !result: [['abcArgsPSA3', 42, 43], {'abcSelfPSA3': 'abcSelfPSA3Val'}]
    psa4(42, 43): !result: [[42, 43], {'abcSelfPSA4': 'abcSelfPSA4Val'}]
    a(42, self={"20": 1}): !result: [42]
    pa1(42, self={"20": 1}): !result: ['abcArgsPA1', 42]
    pa2(42, self={"20": 1}): !result: [42]
    pa3(42, self={"20": 1}): !result: ['abcArgsPA3', 42]
    pa4(42, self={"20": 1}): !result: [42]
    sa(42, self={"20": 1}): !result: [[42], {'20': 1}]
    psa1(42, self={"20": 1}): !result: [['abcArgsPSA1', 42], {'20': 1}]
    psa2(42, self={"20": 1}): !result: [[42], {'20': 1}]
    psa3(42, self={"20": 1}): !result: [['abcArgsPSA3', 42], {'20': 1}]
    psa4(42, self={"20": 1}): !result: [[42], {'20': 1}]
    a(self={"20": 1}): !result: []
    pa1(self={"20": 1}): !result: ['abcArgsPA1']
    pa2(self={"20": 1}): !result: []
    pa3(self={"20": 1}): !result: ['abcArgsPA3']
    pa4(self={"20": 1}): !result: []
    sa(self={"20": 1}): !result: [[], {'20': 1}]
    psa1(self={"20": 1}): !result: [['abcArgsPSA1'], {'20': 1}]
    psa2(self={"20": 1}): !result: [[], {'20': 1}]
    psa3(self={"20": 1}): !result: [['abcArgsPSA3'], {'20': 1}]
    psa4(self={"20": 1}): !result: [[], {'20': 1}]
    a.args: None
    pa1.args: ['abcArgsPA1']
    pa2.args: None
    pa3.args: ['abcArgsPA3']
    pa4.args: None
    sa.args: None
    psa1.args: ['abcArgsPSA1']
    psa2.args: None
    psa3.args: ['abcArgsPSA3']
    psa4.args: None
    a.self: None
    pa1.self: None
    pa2.self: None
    pa3.self: {'abcSelfPA3': 'abcSelfPA3Val'}
    pa4.self: {'abcSelfPA4': 'abcSelfPA4Val'}
    sa.self: None
    psa1.self: None
    psa2.self: None
    psa3.self: {'abcSelfPSA3': 'abcSelfPSA3Val'}
    psa4.self: {'abcSelfPSA4': 'abcSelfPSA4Val'}
    a.name: 'Args'
    pa1.name: 'Args'
    pa2.name: 'Args'
    pa3.name: 'Args'
    pa4.name: 'Args'
    sa.name: 'SelfArgs'
    psa1.name: 'SelfArgs'
    psa2.name: 'SelfArgs'
    psa3.name: 'SelfArgs'
    psa4.name: 'SelfArgs'
    a.auto_rebind: 1
    pa1.auto_rebind: 1
    pa2.auto_rebind: 1
    pa3.auto_rebind: 0
    pa4.auto_rebind: 0
    sa.auto_rebind: 1
    psa1.auto_rebind: 1
    psa2.auto_rebind: 1
    psa3.auto_rebind: 0
    psa4.auto_rebind: 0
    psa5.auto_rebind: 0
    psa6.auto_rebind: 0
    psa7.auto_rebind: 1
    psa8.auto_rebind: 1
    psa9.auto_rebind: 1
    psaA.auto_rebind: 1
    psaB.auto_rebind: 1
    psaC.auto_rebind: 1
  END
  call assert_equal(expected, getline(2, '$'))
  %bw!
endfunc

" Test stdout/stderr
func Test_python3_stdin_stderr()
  throw 'Skipped: TODO: '
  let caught_writeerr = 0
  let caught_writelineerr = 0
  redir => messages
  py3 sys.stdout.write('abc8') ; sys.stdout.write('def')
  try
    py3 sys.stderr.write('abc9') ; sys.stderr.write('def')
  catch /abc9def/
    let caught_writeerr = 1
  endtry
  py3 sys.stdout.writelines(iter('abcA'))
  try
    py3 sys.stderr.writelines(iter('abcB'))
  catch /abcB/
    let caught_writelineerr = 1
  endtry
  redir END
  call assert_equal("\nabc8def\nabcA", messages)
  call assert_equal(1, caught_writeerr)
  call assert_equal(1, caught_writelineerr)
endfunc

" Test subclassing
func Test_python3_subclass()
  throw "Skipped: Nvim: 'LegacyVim' object has no attribute 'Dictionary'"
  new
  func Put(...)
    return a:000
  endfunc

  py3 << trim EOF
    class DupDict(vim.Dictionary):
      def __setitem__(self, key, value):
        super(DupDict, self).__setitem__(key, value)
        super(DupDict, self).__setitem__('dup_' + key, value)
    dd = DupDict()
    dd['a'] = 'b'

    class DupList(vim.List):
      def __getitem__(self, idx):
        return [super(DupList, self).__getitem__(idx)] * 2

    dl = DupList()
    dl2 = DupList(iter('abcC'))
    dl.extend(dl2[0])

    class DupFun(vim.Function):
      def __call__(self, arg):
        return super(DupFun, self).__call__(arg, arg)

    df = DupFun('Put')
  EOF

  call assert_equal(['a', 'dup_a'], sort(keys(py3eval('dd'))))
  call assert_equal(['a', 'a'], py3eval('dl'))
  call assert_equal(['a', 'b', 'c', 'C'], py3eval('dl2'))
  call assert_equal([2, 2], py3eval('df(2)'))
  call assert_equal(1, py3eval('dl') is# py3eval('dl'))
  call assert_equal(1, py3eval('dd') is# py3eval('dd'))
  call assert_equal(function('Put'), py3eval('df'))
  delfunction Put
  py3 << trim EOF
    del DupDict
    del DupList
    del DupFun
    del dd
    del dl
    del dl2
    del df
  EOF
  close!
endfunc

" Test chdir
func Test_python3_chdir()
  throw "Skipped: Nvim: 'LegacyVim' object has no attribute 'Function'"
  new Xfile
  py3 cb = vim.current.buffer
  py3 << trim EOF
    import os
    fnamemodify = vim.Function('fnamemodify')
    cb.append(str(fnamemodify('.', ':p:h:t')))
    cb.append(vim.eval('@%'))
    os.chdir('..')
    path = fnamemodify('.', ':p:h:t')
    if path != b'src' and path != b'src2':
      # Running tests from a shadow directory, so move up another level
      # This will result in @% looking like shadow/testdir/Xfile, hence the
      # slicing to remove the leading path and path separator
      os.chdir('..')
      cb.append(str(fnamemodify('.', ':p:h:t')))
      cb.append(vim.eval('@%')[len(path)+1:].replace(os.path.sep, '/'))
      os.chdir(path)
      del path
    else:
      # Also accept running from src2/testdir/ for MS-Windows CI.
      cb.append(str(fnamemodify('.', ':p:h:t').replace(b'src2', b'src')))
      cb.append(vim.eval('@%').replace(os.path.sep, '/'))
    del path
    os.chdir('testdir')
    cb.append(str(fnamemodify('.', ':p:h:t')))
    cb.append(vim.eval('@%'))
    del fnamemodify
  EOF
  call assert_equal(["b'testdir'", 'Xfile', "b'src'", 'testdir/Xfile',
        \"b'testdir'", 'Xfile'], getline(2, '$'))
  close!
endfunc

" Test errors
func Test_python3_errors()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  func F() dict
  endfunc

  func D()
  endfunc

  new
  py3 cb = vim.current.buffer

  py3 << trim EOF
    import os
    d = vim.Dictionary()
    ned = vim.Dictionary(foo='bar', baz='abcD')
    dl = vim.Dictionary(a=1)
    dl.locked = True
    l = vim.List()
    ll = vim.List('abcE')
    ll.locked = True
    nel = vim.List('abcO')
    f = vim.Function('string')
    fd = vim.Function('F')
    fdel = vim.Function('D')
    vim.command('delfunction D')

    def subexpr_test(expr, name, subexprs):
        cb.append('>>> Testing %s using %s' % (name, expr))
        for subexpr in subexprs:
            ee(expr % subexpr)
        cb.append('<<< Finished')

    def stringtochars_test(expr):
        return subexpr_test(expr, 'StringToChars', (
            '1',       # Fail type checks
            'b"\\0"',  # Fail PyString_AsStringAndSize(object, , NULL) check
            '"\\0"',   # Fail PyString_AsStringAndSize(bytes, , NULL) check
        ))

    class Mapping(object):
        def __init__(self, d):
            self.d = d

        def __getitem__(self, key):
            return self.d[key]

        def keys(self):
            return self.d.keys()

        def items(self):
            return self.d.items()

    def convertfrompyobject_test(expr, recurse=True):
        # pydict_to_tv
        stringtochars_test(expr % '{%s : 1}')
        if recurse:
            convertfrompyobject_test(expr % '{"abcF" : %s}', False)
        # pymap_to_tv
        stringtochars_test(expr % 'Mapping({%s : 1})')
        if recurse:
            convertfrompyobject_test(expr % 'Mapping({"abcG" : %s})', False)
        # pyseq_to_tv
        iter_test(expr)
        return subexpr_test(expr, 'ConvertFromPyObject', (
            'None',                 # Not conversible
            '{b"": 1}',             # Empty key not allowed
            '{"": 1}',              # Same, but with unicode object
            'FailingMapping()',     #
            'FailingMappingKey()',  #
            'FailingNumber()',      #
        ))

    def convertfrompymapping_test(expr):
        convertfrompyobject_test(expr)
        return subexpr_test(expr, 'ConvertFromPyMapping', (
            '[]',
        ))

    def iter_test(expr):
        return subexpr_test(expr, '*Iter*', (
            'FailingIter()',
            'FailingIterNext()',
        ))

    def number_test(expr, natural=False, unsigned=False):
        if natural:
            unsigned = True
        return subexpr_test(expr, 'NumberToLong', (
            '[]',
            'None',
        ) + (('-1',) if unsigned else ())
        + (('0',) if natural else ()))

    class FailingTrue(object):
        def __bool__(self):
            raise NotImplementedError('bool')

    class FailingIter(object):
        def __iter__(self):
            raise NotImplementedError('iter')

    class FailingIterNext(object):
        def __iter__(self):
            return self

        def __next__(self):
          raise NotImplementedError('next')

    class FailingIterNextN(object):
        def __init__(self, n):
            self.n = n

        def __iter__(self):
            return self

        def __next__(self):
            if self.n:
                self.n -= 1
                return 1
            else:
                raise NotImplementedError('next N')

    class FailingMappingKey(object):
        def __getitem__(self, item):
            raise NotImplementedError('getitem:mappingkey')

        def keys(self):
            return list("abcH")

    class FailingMapping(object):
        def __getitem__(self):
            raise NotImplementedError('getitem:mapping')

        def keys(self):
            raise NotImplementedError('keys')

    class FailingList(list):
        def __getitem__(self, idx):
            if i == 2:
                raise NotImplementedError('getitem:list')
            else:
                return super(FailingList, self).__getitem__(idx)

    class NoArgsCall(object):
        def __call__(self):
            pass

    class FailingCall(object):
        def __call__(self, path):
            raise NotImplementedError('call')

    class FailingNumber(object):
        def __int__(self):
            raise NotImplementedError('int')

    cb.append("> Output")
    cb.append(">> OutputSetattr")
    ee('del sys.stdout.softspace')
    number_test('sys.stdout.softspace = %s', unsigned=True)
    number_test('sys.stderr.softspace = %s', unsigned=True)
    ee('assert sys.stdout.isatty()==False')
    ee('assert sys.stdout.seekable()==False')
    ee('sys.stdout.close()')
    ee('sys.stdout.flush()')
    ee('assert sys.stderr.isatty()==False')
    ee('assert sys.stderr.seekable()==False')
    ee('sys.stderr.close()')
    ee('sys.stderr.flush()')
    ee('sys.stdout.attr = None')
    cb.append(">> OutputWrite")
    ee('assert sys.stdout.writable()==True')
    ee('assert sys.stdout.readable()==False')
    ee('assert sys.stderr.writable()==True')
    ee('assert sys.stderr.readable()==False')
    ee('assert sys.stdout.closed()==False')
    ee('assert sys.stderr.closed()==False')
    ee('assert sys.stdout.errors=="strict"')
    ee('assert sys.stderr.errors=="strict"')
    ee('assert sys.stdout.encoding==sys.stderr.encoding')
    ee('sys.stdout.write(None)')
    cb.append(">> OutputWriteLines")
    ee('sys.stdout.writelines(None)')
    ee('sys.stdout.writelines([1])')
    iter_test('sys.stdout.writelines(%s)')
    cb.append("> VimCommand")
    stringtochars_test('vim.command(%s)')
    ee('vim.command("", 2)')
    #! Not checked: vim->python exceptions translating: checked later
    cb.append("> VimToPython")
    #! Not checked: everything: needs errors in internal python functions
    cb.append("> VimEval")
    stringtochars_test('vim.eval(%s)')
    ee('vim.eval("", FailingTrue())')
    #! Not checked: everything: needs errors in internal python functions
    cb.append("> VimEvalPy")
    stringtochars_test('vim.bindeval(%s)')
    ee('vim.eval("", 2)')
    #! Not checked: vim->python exceptions translating: checked later
    cb.append("> VimStrwidth")
    stringtochars_test('vim.strwidth(%s)')
    cb.append("> VimForeachRTP")
    ee('vim.foreach_rtp(None)')
    ee('vim.foreach_rtp(NoArgsCall())')
    ee('vim.foreach_rtp(FailingCall())')
    ee('vim.foreach_rtp(int, 2)')
    cb.append('> import')
    old_rtp = vim.options['rtp']
    vim.options['rtp'] = os.getcwd().replace('\\', '\\\\').replace(',', '\\,')
    ee('import xxx_no_such_module_xxx')
    ee('import failing_import')
    ee('import failing')
    vim.options['rtp'] = old_rtp
    del old_rtp
    cb.append("> Options")
    cb.append(">> OptionsItem")
    ee('vim.options["abcQ"]')
    ee('vim.options[""]')
    stringtochars_test('vim.options[%s]')
    cb.append(">> OptionsContains")
    stringtochars_test('%s in vim.options')
    cb.append("> Dictionary")
    cb.append(">> DictionaryConstructor")
    ee('vim.Dictionary("abcI")')
    ##! Not checked: py_dict_alloc failure
    cb.append(">> DictionarySetattr")
    ee('del d.locked')
    ee('d.locked = FailingTrue()')
    ee('vim.vvars.locked = False')
    ee('d.scope = True')
    ee('d.xxx = True')
    cb.append(">> _DictionaryItem")
    ee('d.get("a", 2, 3)')
    stringtochars_test('d.get(%s)')
    ee('d.pop("a")')
    ee('dl.pop("a")')
    cb.append(">> DictionaryContains")
    ee('"" in d')
    ee('0 in d')
    cb.append(">> DictionaryIterNext")
    ee('for i in ned: ned["a"] = 1')
    del i
    cb.append(">> DictionaryAssItem")
    ee('dl["b"] = 1')
    stringtochars_test('d[%s] = 1')
    convertfrompyobject_test('d["a"] = %s')
    cb.append(">> DictionaryUpdate")
    cb.append(">>> kwargs")
    cb.append(">>> iter")
    ee('d.update(FailingMapping())')
    ee('d.update([FailingIterNext()])')
    ee('d.update([FailingIterNextN(1)])')
    iter_test('d.update(%s)')
    convertfrompyobject_test('d.update(%s)')
    stringtochars_test('d.update(((%s, 0),))')
    convertfrompyobject_test('d.update((("a", %s),))')
    cb.append(">> DictionaryPopItem")
    ee('d.popitem(1, 2)')
    cb.append(">> DictionaryHasKey")
    ee('d.has_key()')
    cb.append("> List")
    cb.append(">> ListConstructor")
    ee('vim.List(1, 2)')
    ee('vim.List(a=1)')
    iter_test('vim.List(%s)')
    convertfrompyobject_test('vim.List([%s])')
    cb.append(">> ListItem")
    ee('l[1000]')
    cb.append(">> ListAssItem")
    ee('ll[1] = 2')
    ee('l[1000] = 3')
    cb.append(">> ListAssSlice")
    ee('ll[1:100] = "abcJ"')
    iter_test('l[:] = %s')
    ee('nel[1:10:2]  = "abcK"')
    cb.append(repr(tuple(nel)))
    ee('nel[1:10:2]  = "a"')
    cb.append(repr(tuple(nel)))
    ee('nel[1:1:-1]  = "a"')
    cb.append(repr(tuple(nel)))
    ee('nel[:] = FailingIterNextN(2)')
    cb.append(repr(tuple(nel)))
    convertfrompyobject_test('l[:] = [%s]')
    cb.append(">> ListConcatInPlace")
    iter_test('l.extend(%s)')
    convertfrompyobject_test('l.extend([%s])')
    cb.append(">> ListSetattr")
    ee('del l.locked')
    ee('l.locked = FailingTrue()')
    ee('l.xxx = True')
    cb.append("> Function")
    cb.append(">> FunctionConstructor")
    cb.append(">>> FunctionConstructor")
    ee('vim.Function("123")')
    ee('vim.Function("xxx_non_existent_function_xxx")')
    ee('vim.Function("xxx#non#existent#function#xxx")')
    ee('vim.Function("xxx_non_existent_function_xxx2", args=[])')
    ee('vim.Function("xxx_non_existent_function_xxx3", self={})')
    ee('vim.Function("xxx_non_existent_function_xxx4", args=[], self={})')
    cb.append(">>> FunctionNew")
    ee('vim.Function("tr", self="abcFuncSelf")')
    ee('vim.Function("tr", args=427423)')
    ee('vim.Function("tr", self="abcFuncSelf2", args="abcFuncArgs2")')
    ee('vim.Function(self="abcFuncSelf2", args="abcFuncArgs2")')
    ee('vim.Function("tr", "", self="abcFuncSelf2", args="abcFuncArgs2")')
    ee('vim.Function("tr", "")')
    cb.append(">> FunctionCall")
    convertfrompyobject_test('f(%s)')
    convertfrompymapping_test('fd(self=%s)')
    cb.append("> TabPage")
    cb.append(">> TabPageAttr")
    ee('vim.current.tabpage.xxx')
    cb.append("> TabList")
    cb.append(">> TabListItem")
    ee('vim.tabpages[1000]')
    cb.append("> Window")
    cb.append(">> WindowAttr")
    ee('vim.current.window.xxx')
    cb.append(">> WindowSetattr")
    ee('vim.current.window.buffer = 0')
    ee('vim.current.window.cursor = (100000000, 100000000)')
    ee('vim.current.window.cursor = True')
    number_test('vim.current.window.height = %s', unsigned=True)
    number_test('vim.current.window.width = %s', unsigned=True)
    ee('vim.current.window.xxxxxx = True')
    cb.append("> WinList")
    cb.append(">> WinListItem")
    ee('vim.windows[1000]')
    cb.append("> Buffer")
    cb.append(">> StringToLine (indirect)")
    ee('vim.current.buffer[0] = "\\na"')
    ee('vim.current.buffer[0] = b"\\na"')
    cb.append(">> SetBufferLine (indirect)")
    ee('vim.current.buffer[0] = True')
    cb.append(">> SetBufferLineList (indirect)")
    ee('vim.current.buffer[:] = True')
    ee('vim.current.buffer[:] = ["\\na", "bc"]')
    cb.append(">> InsertBufferLines (indirect)")
    ee('vim.current.buffer.append(None)')
    ee('vim.current.buffer.append(["\\na", "bc"])')
    ee('vim.current.buffer.append("\\nbc")')
    cb.append(">> RBItem")
    ee('vim.current.buffer[100000000]')
    cb.append(">> RBAsItem")
    ee('vim.current.buffer[100000000] = ""')
    cb.append(">> BufferAttr")
    ee('vim.current.buffer.xxx')
    cb.append(">> BufferSetattr")
    ee('vim.current.buffer.name = True')
    ee('vim.current.buffer.xxx = True')
    cb.append(">> BufferMark")
    ee('vim.current.buffer.mark(0)')
    ee('vim.current.buffer.mark("abcM")')
    ee('vim.current.buffer.mark("!")')
    cb.append(">> BufferRange")
    ee('vim.current.buffer.range(1, 2, 3)')
    cb.append("> BufMap")
    cb.append(">> BufMapItem")
    ee('vim.buffers[100000000]')
    number_test('vim.buffers[%s]', natural=True)
    cb.append("> Current")
    cb.append(">> CurrentGetattr")
    ee('vim.current.xxx')
    cb.append(">> CurrentSetattr")
    ee('vim.current.line = True')
    ee('vim.current.buffer = True')
    ee('vim.current.window = True')
    ee('vim.current.tabpage = True')
    ee('vim.current.xxx = True')
    del d
    del ned
    del dl
    del l
    del ll
    del nel
    del f
    del fd
    del fdel
    del subexpr_test
    del stringtochars_test
    del Mapping
    del convertfrompyobject_test
    del convertfrompymapping_test
    del iter_test
    del number_test
    del FailingTrue
    del FailingIter
    del FailingIterNext
    del FailingIterNextN
    del FailingMapping
    del FailingMappingKey
    del FailingList
    del NoArgsCall
    del FailingCall
    del FailingNumber
  EOF
  delfunction F

  let expected =<< trim END
    > Output
    >> OutputSetattr
    del sys.stdout.softspace:(<class 'AttributeError'>, AttributeError('cannot delete OutputObject attributes',))
    >>> Testing NumberToLong using sys.stdout.softspace = %s
    sys.stdout.softspace = []:(<class 'TypeError'>, TypeError('expected int() or something supporting coercing to int(), but got list',))
    sys.stdout.softspace = None:(<class 'TypeError'>, TypeError('expected int() or something supporting coercing to int(), but got NoneType',))
    sys.stdout.softspace = -1:(<class 'ValueError'>, ValueError('number must be greater or equal to zero',))
    <<< Finished
    >>> Testing NumberToLong using sys.stderr.softspace = %s
    sys.stderr.softspace = []:(<class 'TypeError'>, TypeError('expected int() or something supporting coercing to int(), but got list',))
    sys.stderr.softspace = None:(<class 'TypeError'>, TypeError('expected int() or something supporting coercing to int(), but got NoneType',))
    sys.stderr.softspace = -1:(<class 'ValueError'>, ValueError('number must be greater or equal to zero',))
    <<< Finished
    assert sys.stdout.isatty()==False:NOT FAILED
    assert sys.stdout.seekable()==False:NOT FAILED
    sys.stdout.close():NOT FAILED
    sys.stdout.flush():NOT FAILED
    assert sys.stderr.isatty()==False:NOT FAILED
    assert sys.stderr.seekable()==False:NOT FAILED
    sys.stderr.close():NOT FAILED
    sys.stderr.flush():NOT FAILED
    sys.stdout.attr = None:(<class 'AttributeError'>, AttributeError('invalid attribute: attr',))
    >> OutputWrite
    assert sys.stdout.writable()==True:NOT FAILED
    assert sys.stdout.readable()==False:NOT FAILED
    assert sys.stderr.writable()==True:NOT FAILED
    assert sys.stderr.readable()==False:NOT FAILED
    assert sys.stdout.closed()==False:NOT FAILED
    assert sys.stderr.closed()==False:NOT FAILED
    assert sys.stdout.errors=="strict":NOT FAILED
    assert sys.stderr.errors=="strict":NOT FAILED
    assert sys.stdout.encoding==sys.stderr.encoding:NOT FAILED
    sys.stdout.write(None):(<class 'TypeError'>, TypeError("Can't convert 'NoneType' object to str implicitly",))
    >> OutputWriteLines
    sys.stdout.writelines(None):(<class 'TypeError'>, TypeError("'NoneType' object is not iterable",))
    sys.stdout.writelines([1]):(<class 'TypeError'>, TypeError("Can't convert 'int' object to str implicitly",))
    >>> Testing *Iter* using sys.stdout.writelines(%s)
    sys.stdout.writelines(FailingIter()):(<class 'NotImplementedError'>, NotImplementedError('iter',))
    sys.stdout.writelines(FailingIterNext()):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    > VimCommand
    >>> Testing StringToChars using vim.command(%s)
    vim.command(1):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    vim.command(b"\0"):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    vim.command("\0"):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    vim.command("", 2):(<class 'TypeError'>, TypeError('command() takes exactly one argument (2 given)',))
    > VimToPython
    > VimEval
    >>> Testing StringToChars using vim.eval(%s)
    vim.eval(1):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    vim.eval(b"\0"):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    vim.eval("\0"):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    vim.eval("", FailingTrue()):(<class 'TypeError'>, TypeError('function takes exactly 1 argument (2 given)',))
    > VimEvalPy
    >>> Testing StringToChars using vim.bindeval(%s)
    vim.bindeval(1):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    vim.bindeval(b"\0"):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    vim.bindeval("\0"):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    vim.eval("", 2):(<class 'TypeError'>, TypeError('function takes exactly 1 argument (2 given)',))
    > VimStrwidth
    >>> Testing StringToChars using vim.strwidth(%s)
    vim.strwidth(1):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    vim.strwidth(b"\0"):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    vim.strwidth("\0"):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    > VimForeachRTP
    vim.foreach_rtp(None):(<class 'TypeError'>, TypeError("'NoneType' object is not callable",))
    vim.foreach_rtp(NoArgsCall()):(<class 'TypeError'>, TypeError('__call__() takes exactly 1 positional argument (2 given)',))
    vim.foreach_rtp(FailingCall()):(<class 'NotImplementedError'>, NotImplementedError('call',))
    vim.foreach_rtp(int, 2):(<class 'TypeError'>, TypeError('foreach_rtp() takes exactly one argument (2 given)',))
    > import
    import xxx_no_such_module_xxx:(<class 'ImportError'>, ImportError('No module named xxx_no_such_module_xxx',))
    import failing_import:(<class 'ImportError'>, ImportError())
    import failing:(<class 'NotImplementedError'>, NotImplementedError())
    > Options
    >> OptionsItem
    vim.options["abcQ"]:(<class 'KeyError'>, KeyError('abcQ',))
    vim.options[""]:(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    >>> Testing StringToChars using vim.options[%s]
    vim.options[1]:(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    vim.options[b"\0"]:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    vim.options["\0"]:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >> OptionsContains
    >>> Testing StringToChars using %s in vim.options
    1 in vim.options:(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    b"\0" in vim.options:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    "\0" in vim.options:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    > Dictionary
    >> DictionaryConstructor
    vim.Dictionary("abcI"):(<class 'ValueError'>, ValueError('expected sequence element of size 2, but got sequence of size 1',))
    >> DictionarySetattr
    del d.locked:(<class 'AttributeError'>, AttributeError('cannot delete vim.Dictionary attributes',))
    d.locked = FailingTrue():(<class 'NotImplementedError'>, NotImplementedError('bool',))
    vim.vvars.locked = False:(<class 'TypeError'>, TypeError('cannot modify fixed dictionary',))
    d.scope = True:(<class 'AttributeError'>, AttributeError('cannot set attribute scope',))
    d.xxx = True:(<class 'AttributeError'>, AttributeError('cannot set attribute xxx',))
    >> _DictionaryItem
    d.get("a", 2, 3):(<class 'TypeError'>, TypeError('function takes at most 2 arguments (3 given)',))
    >>> Testing StringToChars using d.get(%s)
    d.get(1):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d.get(b"\0"):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d.get("\0"):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    d.pop("a"):(<class 'KeyError'>, KeyError('a',))
    dl.pop("a"):(<class 'vim.error'>, error('dictionary is locked',))
    >> DictionaryContains
    "" in d:(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    0 in d:(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    >> DictionaryIterNext
    for i in ned: ned["a"] = 1:(<class 'RuntimeError'>, RuntimeError('hashtab changed during iteration',))
    >> DictionaryAssItem
    dl["b"] = 1:(<class 'vim.error'>, error('dictionary is locked',))
    >>> Testing StringToChars using d[%s] = 1
    d[1] = 1:(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d[b"\0"] = 1:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d["\0"] = 1:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using d["a"] = {%s : 1}
    d["a"] = {1 : 1}:(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d["a"] = {b"\0" : 1}:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d["a"] = {"\0" : 1}:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using d["a"] = {"abcF" : {%s : 1}}
    d["a"] = {"abcF" : {1 : 1}}:(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d["a"] = {"abcF" : {b"\0" : 1}}:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d["a"] = {"abcF" : {"\0" : 1}}:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using d["a"] = {"abcF" : Mapping({%s : 1})}
    d["a"] = {"abcF" : Mapping({1 : 1})}:(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d["a"] = {"abcF" : Mapping({b"\0" : 1})}:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d["a"] = {"abcF" : Mapping({"\0" : 1})}:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing *Iter* using d["a"] = {"abcF" : %s}
    d["a"] = {"abcF" : FailingIter()}:(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    d["a"] = {"abcF" : FailingIterNext()}:(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using d["a"] = {"abcF" : %s}
    d["a"] = {"abcF" : None}:NOT FAILED
    d["a"] = {"abcF" : {b"": 1}}:(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    d["a"] = {"abcF" : {"": 1}}:(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    d["a"] = {"abcF" : FailingMapping()}:(<class 'NotImplementedError'>, NotImplementedError('keys',))
    d["a"] = {"abcF" : FailingMappingKey()}:(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    d["a"] = {"abcF" : FailingNumber()}:(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >>> Testing StringToChars using d["a"] = Mapping({%s : 1})
    d["a"] = Mapping({1 : 1}):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d["a"] = Mapping({b"\0" : 1}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d["a"] = Mapping({"\0" : 1}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using d["a"] = Mapping({"abcG" : {%s : 1}})
    d["a"] = Mapping({"abcG" : {1 : 1}}):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d["a"] = Mapping({"abcG" : {b"\0" : 1}}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d["a"] = Mapping({"abcG" : {"\0" : 1}}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using d["a"] = Mapping({"abcG" : Mapping({%s : 1})})
    d["a"] = Mapping({"abcG" : Mapping({1 : 1})}):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d["a"] = Mapping({"abcG" : Mapping({b"\0" : 1})}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d["a"] = Mapping({"abcG" : Mapping({"\0" : 1})}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing *Iter* using d["a"] = Mapping({"abcG" : %s})
    d["a"] = Mapping({"abcG" : FailingIter()}):(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    d["a"] = Mapping({"abcG" : FailingIterNext()}):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using d["a"] = Mapping({"abcG" : %s})
    d["a"] = Mapping({"abcG" : None}):NOT FAILED
    d["a"] = Mapping({"abcG" : {b"": 1}}):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    d["a"] = Mapping({"abcG" : {"": 1}}):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    d["a"] = Mapping({"abcG" : FailingMapping()}):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    d["a"] = Mapping({"abcG" : FailingMappingKey()}):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    d["a"] = Mapping({"abcG" : FailingNumber()}):(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >>> Testing *Iter* using d["a"] = %s
    d["a"] = FailingIter():(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    d["a"] = FailingIterNext():(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using d["a"] = %s
    d["a"] = None:NOT FAILED
    d["a"] = {b"": 1}:(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    d["a"] = {"": 1}:(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    d["a"] = FailingMapping():(<class 'NotImplementedError'>, NotImplementedError('keys',))
    d["a"] = FailingMappingKey():(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    d["a"] = FailingNumber():(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >> DictionaryUpdate
    >>> kwargs
    >>> iter
    d.update(FailingMapping()):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    d.update([FailingIterNext()]):(<class 'NotImplementedError'>, NotImplementedError('next',))
    d.update([FailingIterNextN(1)]):(<class 'NotImplementedError'>, NotImplementedError('next N',))
    >>> Testing *Iter* using d.update(%s)
    d.update(FailingIter()):(<class 'NotImplementedError'>, NotImplementedError('iter',))
    d.update(FailingIterNext()):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing StringToChars using d.update({%s : 1})
    d.update({1 : 1}):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d.update({b"\0" : 1}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d.update({"\0" : 1}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using d.update({"abcF" : {%s : 1}})
    d.update({"abcF" : {1 : 1}}):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d.update({"abcF" : {b"\0" : 1}}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d.update({"abcF" : {"\0" : 1}}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using d.update({"abcF" : Mapping({%s : 1})})
    d.update({"abcF" : Mapping({1 : 1})}):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d.update({"abcF" : Mapping({b"\0" : 1})}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d.update({"abcF" : Mapping({"\0" : 1})}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing *Iter* using d.update({"abcF" : %s})
    d.update({"abcF" : FailingIter()}):(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    d.update({"abcF" : FailingIterNext()}):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using d.update({"abcF" : %s})
    d.update({"abcF" : None}):NOT FAILED
    d.update({"abcF" : {b"": 1}}):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    d.update({"abcF" : {"": 1}}):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    d.update({"abcF" : FailingMapping()}):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    d.update({"abcF" : FailingMappingKey()}):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    d.update({"abcF" : FailingNumber()}):(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >>> Testing StringToChars using d.update(Mapping({%s : 1}))
    d.update(Mapping({1 : 1})):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d.update(Mapping({b"\0" : 1})):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d.update(Mapping({"\0" : 1})):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using d.update(Mapping({"abcG" : {%s : 1}}))
    d.update(Mapping({"abcG" : {1 : 1}})):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d.update(Mapping({"abcG" : {b"\0" : 1}})):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d.update(Mapping({"abcG" : {"\0" : 1}})):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using d.update(Mapping({"abcG" : Mapping({%s : 1})}))
    d.update(Mapping({"abcG" : Mapping({1 : 1})})):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d.update(Mapping({"abcG" : Mapping({b"\0" : 1})})):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d.update(Mapping({"abcG" : Mapping({"\0" : 1})})):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing *Iter* using d.update(Mapping({"abcG" : %s}))
    d.update(Mapping({"abcG" : FailingIter()})):(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    d.update(Mapping({"abcG" : FailingIterNext()})):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using d.update(Mapping({"abcG" : %s}))
    d.update(Mapping({"abcG" : None})):NOT FAILED
    d.update(Mapping({"abcG" : {b"": 1}})):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    d.update(Mapping({"abcG" : {"": 1}})):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    d.update(Mapping({"abcG" : FailingMapping()})):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    d.update(Mapping({"abcG" : FailingMappingKey()})):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    d.update(Mapping({"abcG" : FailingNumber()})):(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >>> Testing *Iter* using d.update(%s)
    d.update(FailingIter()):(<class 'NotImplementedError'>, NotImplementedError('iter',))
    d.update(FailingIterNext()):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using d.update(%s)
    d.update(None):(<class 'TypeError'>, TypeError("'NoneType' object is not iterable",))
    d.update({b"": 1}):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    d.update({"": 1}):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    d.update(FailingMapping()):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    d.update(FailingMappingKey()):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    d.update(FailingNumber()):(<class 'TypeError'>, TypeError("'FailingNumber' object is not iterable",))
    <<< Finished
    >>> Testing StringToChars using d.update(((%s, 0),))
    d.update(((1, 0),)):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d.update(((b"\0", 0),)):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d.update((("\0", 0),)):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using d.update((("a", {%s : 1}),))
    d.update((("a", {1 : 1}),)):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d.update((("a", {b"\0" : 1}),)):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d.update((("a", {"\0" : 1}),)):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using d.update((("a", {"abcF" : {%s : 1}}),))
    d.update((("a", {"abcF" : {1 : 1}}),)):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d.update((("a", {"abcF" : {b"\0" : 1}}),)):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d.update((("a", {"abcF" : {"\0" : 1}}),)):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using d.update((("a", {"abcF" : Mapping({%s : 1})}),))
    d.update((("a", {"abcF" : Mapping({1 : 1})}),)):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d.update((("a", {"abcF" : Mapping({b"\0" : 1})}),)):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d.update((("a", {"abcF" : Mapping({"\0" : 1})}),)):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing *Iter* using d.update((("a", {"abcF" : %s}),))
    d.update((("a", {"abcF" : FailingIter()}),)):(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    d.update((("a", {"abcF" : FailingIterNext()}),)):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using d.update((("a", {"abcF" : %s}),))
    d.update((("a", {"abcF" : None}),)):(<class 'vim.error'>, error("failed to add key 'a' to dictionary",))
    d.update((("a", {"abcF" : {b"": 1}}),)):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    d.update((("a", {"abcF" : {"": 1}}),)):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    d.update((("a", {"abcF" : FailingMapping()}),)):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    d.update((("a", {"abcF" : FailingMappingKey()}),)):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    d.update((("a", {"abcF" : FailingNumber()}),)):(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >>> Testing StringToChars using d.update((("a", Mapping({%s : 1})),))
    d.update((("a", Mapping({1 : 1})),)):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d.update((("a", Mapping({b"\0" : 1})),)):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d.update((("a", Mapping({"\0" : 1})),)):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using d.update((("a", Mapping({"abcG" : {%s : 1}})),))
    d.update((("a", Mapping({"abcG" : {1 : 1}})),)):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d.update((("a", Mapping({"abcG" : {b"\0" : 1}})),)):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d.update((("a", Mapping({"abcG" : {"\0" : 1}})),)):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using d.update((("a", Mapping({"abcG" : Mapping({%s : 1})})),))
    d.update((("a", Mapping({"abcG" : Mapping({1 : 1})})),)):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    d.update((("a", Mapping({"abcG" : Mapping({b"\0" : 1})})),)):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    d.update((("a", Mapping({"abcG" : Mapping({"\0" : 1})})),)):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing *Iter* using d.update((("a", Mapping({"abcG" : %s})),))
    d.update((("a", Mapping({"abcG" : FailingIter()})),)):(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    d.update((("a", Mapping({"abcG" : FailingIterNext()})),)):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using d.update((("a", Mapping({"abcG" : %s})),))
    d.update((("a", Mapping({"abcG" : None})),)):(<class 'vim.error'>, error("failed to add key 'a' to dictionary",))
    d.update((("a", Mapping({"abcG" : {b"": 1}})),)):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    d.update((("a", Mapping({"abcG" : {"": 1}})),)):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    d.update((("a", Mapping({"abcG" : FailingMapping()})),)):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    d.update((("a", Mapping({"abcG" : FailingMappingKey()})),)):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    d.update((("a", Mapping({"abcG" : FailingNumber()})),)):(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >>> Testing *Iter* using d.update((("a", %s),))
    d.update((("a", FailingIter()),)):(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    d.update((("a", FailingIterNext()),)):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using d.update((("a", %s),))
    d.update((("a", None),)):(<class 'vim.error'>, error("failed to add key 'a' to dictionary",))
    d.update((("a", {b"": 1}),)):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    d.update((("a", {"": 1}),)):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    d.update((("a", FailingMapping()),)):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    d.update((("a", FailingMappingKey()),)):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    d.update((("a", FailingNumber()),)):(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >> DictionaryPopItem
    d.popitem(1, 2):(<class 'TypeError'>, TypeError('popitem() takes no arguments (2 given)',))
    >> DictionaryHasKey
    d.has_key():(<class 'TypeError'>, TypeError('has_key() takes exactly one argument (0 given)',))
    > List
    >> ListConstructor
    vim.List(1, 2):(<class 'TypeError'>, TypeError('function takes at most 1 argument (2 given)',))
    vim.List(a=1):(<class 'TypeError'>, TypeError('list constructor does not accept keyword arguments',))
    >>> Testing *Iter* using vim.List(%s)
    vim.List(FailingIter()):(<class 'NotImplementedError'>, NotImplementedError('iter',))
    vim.List(FailingIterNext()):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing StringToChars using vim.List([{%s : 1}])
    vim.List([{1 : 1}]):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    vim.List([{b"\0" : 1}]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    vim.List([{"\0" : 1}]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using vim.List([{"abcF" : {%s : 1}}])
    vim.List([{"abcF" : {1 : 1}}]):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    vim.List([{"abcF" : {b"\0" : 1}}]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    vim.List([{"abcF" : {"\0" : 1}}]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using vim.List([{"abcF" : Mapping({%s : 1})}])
    vim.List([{"abcF" : Mapping({1 : 1})}]):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    vim.List([{"abcF" : Mapping({b"\0" : 1})}]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    vim.List([{"abcF" : Mapping({"\0" : 1})}]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing *Iter* using vim.List([{"abcF" : %s}])
    vim.List([{"abcF" : FailingIter()}]):(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    vim.List([{"abcF" : FailingIterNext()}]):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using vim.List([{"abcF" : %s}])
    vim.List([{"abcF" : None}]):NOT FAILED
    vim.List([{"abcF" : {b"": 1}}]):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    vim.List([{"abcF" : {"": 1}}]):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    vim.List([{"abcF" : FailingMapping()}]):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    vim.List([{"abcF" : FailingMappingKey()}]):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    vim.List([{"abcF" : FailingNumber()}]):(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >>> Testing StringToChars using vim.List([Mapping({%s : 1})])
    vim.List([Mapping({1 : 1})]):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    vim.List([Mapping({b"\0" : 1})]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    vim.List([Mapping({"\0" : 1})]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using vim.List([Mapping({"abcG" : {%s : 1}})])
    vim.List([Mapping({"abcG" : {1 : 1}})]):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    vim.List([Mapping({"abcG" : {b"\0" : 1}})]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    vim.List([Mapping({"abcG" : {"\0" : 1}})]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using vim.List([Mapping({"abcG" : Mapping({%s : 1})})])
    vim.List([Mapping({"abcG" : Mapping({1 : 1})})]):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    vim.List([Mapping({"abcG" : Mapping({b"\0" : 1})})]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    vim.List([Mapping({"abcG" : Mapping({"\0" : 1})})]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing *Iter* using vim.List([Mapping({"abcG" : %s})])
    vim.List([Mapping({"abcG" : FailingIter()})]):(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    vim.List([Mapping({"abcG" : FailingIterNext()})]):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using vim.List([Mapping({"abcG" : %s})])
    vim.List([Mapping({"abcG" : None})]):NOT FAILED
    vim.List([Mapping({"abcG" : {b"": 1}})]):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    vim.List([Mapping({"abcG" : {"": 1}})]):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    vim.List([Mapping({"abcG" : FailingMapping()})]):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    vim.List([Mapping({"abcG" : FailingMappingKey()})]):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    vim.List([Mapping({"abcG" : FailingNumber()})]):(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >>> Testing *Iter* using vim.List([%s])
    vim.List([FailingIter()]):(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    vim.List([FailingIterNext()]):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using vim.List([%s])
    vim.List([None]):NOT FAILED
    vim.List([{b"": 1}]):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    vim.List([{"": 1}]):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    vim.List([FailingMapping()]):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    vim.List([FailingMappingKey()]):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    vim.List([FailingNumber()]):(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >> ListItem
    l[1000]:(<class 'IndexError'>, IndexError('list index out of range',))
    >> ListAssItem
    ll[1] = 2:(<class 'vim.error'>, error('list is locked',))
    l[1000] = 3:(<class 'IndexError'>, IndexError('list index out of range',))
    >> ListAssSlice
    ll[1:100] = "abcJ":(<class 'vim.error'>, error('list is locked',))
    >>> Testing *Iter* using l[:] = %s
    l[:] = FailingIter():(<class 'NotImplementedError'>, NotImplementedError('iter',))
    l[:] = FailingIterNext():(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    nel[1:10:2]  = "abcK":(<class 'ValueError'>, ValueError('attempt to assign sequence of size greater than 2 to extended slice',))
    (b'a', b'b', b'c', b'O')
    nel[1:10:2]  = "a":(<class 'ValueError'>, ValueError('attempt to assign sequence of size 1 to extended slice of size 2',))
    (b'a', b'b', b'c', b'O')
    nel[1:1:-1]  = "a":(<class 'ValueError'>, ValueError('attempt to assign sequence of size greater than 0 to extended slice',))
    (b'a', b'b', b'c', b'O')
    nel[:] = FailingIterNextN(2):(<class 'NotImplementedError'>, NotImplementedError('next N',))
    (b'a', b'b', b'c', b'O')
    >>> Testing StringToChars using l[:] = [{%s : 1}]
    l[:] = [{1 : 1}]:(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    l[:] = [{b"\0" : 1}]:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    l[:] = [{"\0" : 1}]:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using l[:] = [{"abcF" : {%s : 1}}]
    l[:] = [{"abcF" : {1 : 1}}]:(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    l[:] = [{"abcF" : {b"\0" : 1}}]:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    l[:] = [{"abcF" : {"\0" : 1}}]:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using l[:] = [{"abcF" : Mapping({%s : 1})}]
    l[:] = [{"abcF" : Mapping({1 : 1})}]:(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    l[:] = [{"abcF" : Mapping({b"\0" : 1})}]:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    l[:] = [{"abcF" : Mapping({"\0" : 1})}]:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing *Iter* using l[:] = [{"abcF" : %s}]
    l[:] = [{"abcF" : FailingIter()}]:(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    l[:] = [{"abcF" : FailingIterNext()}]:(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using l[:] = [{"abcF" : %s}]
    l[:] = [{"abcF" : None}]:NOT FAILED
    l[:] = [{"abcF" : {b"": 1}}]:(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    l[:] = [{"abcF" : {"": 1}}]:(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    l[:] = [{"abcF" : FailingMapping()}]:(<class 'NotImplementedError'>, NotImplementedError('keys',))
    l[:] = [{"abcF" : FailingMappingKey()}]:(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    l[:] = [{"abcF" : FailingNumber()}]:(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >>> Testing StringToChars using l[:] = [Mapping({%s : 1})]
    l[:] = [Mapping({1 : 1})]:(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    l[:] = [Mapping({b"\0" : 1})]:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    l[:] = [Mapping({"\0" : 1})]:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using l[:] = [Mapping({"abcG" : {%s : 1}})]
    l[:] = [Mapping({"abcG" : {1 : 1}})]:(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    l[:] = [Mapping({"abcG" : {b"\0" : 1}})]:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    l[:] = [Mapping({"abcG" : {"\0" : 1}})]:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using l[:] = [Mapping({"abcG" : Mapping({%s : 1})})]
    l[:] = [Mapping({"abcG" : Mapping({1 : 1})})]:(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    l[:] = [Mapping({"abcG" : Mapping({b"\0" : 1})})]:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    l[:] = [Mapping({"abcG" : Mapping({"\0" : 1})})]:(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing *Iter* using l[:] = [Mapping({"abcG" : %s})]
    l[:] = [Mapping({"abcG" : FailingIter()})]:(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    l[:] = [Mapping({"abcG" : FailingIterNext()})]:(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using l[:] = [Mapping({"abcG" : %s})]
    l[:] = [Mapping({"abcG" : None})]:NOT FAILED
    l[:] = [Mapping({"abcG" : {b"": 1}})]:(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    l[:] = [Mapping({"abcG" : {"": 1}})]:(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    l[:] = [Mapping({"abcG" : FailingMapping()})]:(<class 'NotImplementedError'>, NotImplementedError('keys',))
    l[:] = [Mapping({"abcG" : FailingMappingKey()})]:(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    l[:] = [Mapping({"abcG" : FailingNumber()})]:(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >>> Testing *Iter* using l[:] = [%s]
    l[:] = [FailingIter()]:(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    l[:] = [FailingIterNext()]:(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using l[:] = [%s]
    l[:] = [None]:NOT FAILED
    l[:] = [{b"": 1}]:(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    l[:] = [{"": 1}]:(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    l[:] = [FailingMapping()]:(<class 'NotImplementedError'>, NotImplementedError('keys',))
    l[:] = [FailingMappingKey()]:(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    l[:] = [FailingNumber()]:(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >> ListConcatInPlace
    >>> Testing *Iter* using l.extend(%s)
    l.extend(FailingIter()):(<class 'NotImplementedError'>, NotImplementedError('iter',))
    l.extend(FailingIterNext()):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing StringToChars using l.extend([{%s : 1}])
    l.extend([{1 : 1}]):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    l.extend([{b"\0" : 1}]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    l.extend([{"\0" : 1}]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using l.extend([{"abcF" : {%s : 1}}])
    l.extend([{"abcF" : {1 : 1}}]):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    l.extend([{"abcF" : {b"\0" : 1}}]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    l.extend([{"abcF" : {"\0" : 1}}]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using l.extend([{"abcF" : Mapping({%s : 1})}])
    l.extend([{"abcF" : Mapping({1 : 1})}]):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    l.extend([{"abcF" : Mapping({b"\0" : 1})}]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    l.extend([{"abcF" : Mapping({"\0" : 1})}]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing *Iter* using l.extend([{"abcF" : %s}])
    l.extend([{"abcF" : FailingIter()}]):(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    l.extend([{"abcF" : FailingIterNext()}]):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using l.extend([{"abcF" : %s}])
    l.extend([{"abcF" : None}]):NOT FAILED
    l.extend([{"abcF" : {b"": 1}}]):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    l.extend([{"abcF" : {"": 1}}]):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    l.extend([{"abcF" : FailingMapping()}]):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    l.extend([{"abcF" : FailingMappingKey()}]):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    l.extend([{"abcF" : FailingNumber()}]):(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >>> Testing StringToChars using l.extend([Mapping({%s : 1})])
    l.extend([Mapping({1 : 1})]):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    l.extend([Mapping({b"\0" : 1})]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    l.extend([Mapping({"\0" : 1})]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using l.extend([Mapping({"abcG" : {%s : 1}})])
    l.extend([Mapping({"abcG" : {1 : 1}})]):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    l.extend([Mapping({"abcG" : {b"\0" : 1}})]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    l.extend([Mapping({"abcG" : {"\0" : 1}})]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using l.extend([Mapping({"abcG" : Mapping({%s : 1})})])
    l.extend([Mapping({"abcG" : Mapping({1 : 1})})]):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    l.extend([Mapping({"abcG" : Mapping({b"\0" : 1})})]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    l.extend([Mapping({"abcG" : Mapping({"\0" : 1})})]):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing *Iter* using l.extend([Mapping({"abcG" : %s})])
    l.extend([Mapping({"abcG" : FailingIter()})]):(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    l.extend([Mapping({"abcG" : FailingIterNext()})]):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using l.extend([Mapping({"abcG" : %s})])
    l.extend([Mapping({"abcG" : None})]):NOT FAILED
    l.extend([Mapping({"abcG" : {b"": 1}})]):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    l.extend([Mapping({"abcG" : {"": 1}})]):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    l.extend([Mapping({"abcG" : FailingMapping()})]):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    l.extend([Mapping({"abcG" : FailingMappingKey()})]):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    l.extend([Mapping({"abcG" : FailingNumber()})]):(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >>> Testing *Iter* using l.extend([%s])
    l.extend([FailingIter()]):(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    l.extend([FailingIterNext()]):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using l.extend([%s])
    l.extend([None]):NOT FAILED
    l.extend([{b"": 1}]):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    l.extend([{"": 1}]):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    l.extend([FailingMapping()]):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    l.extend([FailingMappingKey()]):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    l.extend([FailingNumber()]):(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >> ListSetattr
    del l.locked:(<class 'AttributeError'>, AttributeError('cannot delete vim.List attributes',))
    l.locked = FailingTrue():(<class 'NotImplementedError'>, NotImplementedError('bool',))
    l.xxx = True:(<class 'AttributeError'>, AttributeError('cannot set attribute xxx',))
    > Function
    >> FunctionConstructor
    >>> FunctionConstructor
    vim.Function("123"):(<class 'ValueError'>, ValueError('unnamed function 123 does not exist',))
    vim.Function("xxx_non_existent_function_xxx"):(<class 'ValueError'>, ValueError('function xxx_non_existent_function_xxx does not exist',))
    vim.Function("xxx#non#existent#function#xxx"):NOT FAILED
    vim.Function("xxx_non_existent_function_xxx2", args=[]):(<class 'ValueError'>, ValueError('function xxx_non_existent_function_xxx2 does not exist',))
    vim.Function("xxx_non_existent_function_xxx3", self={}):(<class 'ValueError'>, ValueError('function xxx_non_existent_function_xxx3 does not exist',))
    vim.Function("xxx_non_existent_function_xxx4", args=[], self={}):(<class 'ValueError'>, ValueError('function xxx_non_existent_function_xxx4 does not exist',))
    >>> FunctionNew
    vim.Function("tr", self="abcFuncSelf"):(<class 'AttributeError'>, AttributeError('keys',))
    vim.Function("tr", args=427423):(<class 'TypeError'>, TypeError('unable to convert int to a Vim list',))
    vim.Function("tr", self="abcFuncSelf2", args="abcFuncArgs2"):(<class 'AttributeError'>, AttributeError('keys',))
    vim.Function(self="abcFuncSelf2", args="abcFuncArgs2"):(<class 'AttributeError'>, AttributeError('keys',))
    vim.Function("tr", "", self="abcFuncSelf2", args="abcFuncArgs2"):(<class 'AttributeError'>, AttributeError('keys',))
    vim.Function("tr", ""):(<class 'TypeError'>, TypeError('function takes exactly 1 argument (2 given)',))
    >> FunctionCall
    >>> Testing StringToChars using f({%s : 1})
    f({1 : 1}):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    f({b"\0" : 1}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    f({"\0" : 1}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using f({"abcF" : {%s : 1}})
    f({"abcF" : {1 : 1}}):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    f({"abcF" : {b"\0" : 1}}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    f({"abcF" : {"\0" : 1}}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using f({"abcF" : Mapping({%s : 1})})
    f({"abcF" : Mapping({1 : 1})}):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    f({"abcF" : Mapping({b"\0" : 1})}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    f({"abcF" : Mapping({"\0" : 1})}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing *Iter* using f({"abcF" : %s})
    f({"abcF" : FailingIter()}):(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    f({"abcF" : FailingIterNext()}):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using f({"abcF" : %s})
    f({"abcF" : None}):NOT FAILED
    f({"abcF" : {b"": 1}}):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    f({"abcF" : {"": 1}}):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    f({"abcF" : FailingMapping()}):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    f({"abcF" : FailingMappingKey()}):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    f({"abcF" : FailingNumber()}):(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >>> Testing StringToChars using f(Mapping({%s : 1}))
    f(Mapping({1 : 1})):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    f(Mapping({b"\0" : 1})):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    f(Mapping({"\0" : 1})):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using f(Mapping({"abcG" : {%s : 1}}))
    f(Mapping({"abcG" : {1 : 1}})):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    f(Mapping({"abcG" : {b"\0" : 1}})):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    f(Mapping({"abcG" : {"\0" : 1}})):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using f(Mapping({"abcG" : Mapping({%s : 1})}))
    f(Mapping({"abcG" : Mapping({1 : 1})})):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    f(Mapping({"abcG" : Mapping({b"\0" : 1})})):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    f(Mapping({"abcG" : Mapping({"\0" : 1})})):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing *Iter* using f(Mapping({"abcG" : %s}))
    f(Mapping({"abcG" : FailingIter()})):(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    f(Mapping({"abcG" : FailingIterNext()})):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using f(Mapping({"abcG" : %s}))
    f(Mapping({"abcG" : None})):NOT FAILED
    f(Mapping({"abcG" : {b"": 1}})):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    f(Mapping({"abcG" : {"": 1}})):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    f(Mapping({"abcG" : FailingMapping()})):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    f(Mapping({"abcG" : FailingMappingKey()})):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    f(Mapping({"abcG" : FailingNumber()})):(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >>> Testing *Iter* using f(%s)
    f(FailingIter()):(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    f(FailingIterNext()):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using f(%s)
    f(None):NOT FAILED
    f({b"": 1}):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    f({"": 1}):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    f(FailingMapping()):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    f(FailingMappingKey()):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    f(FailingNumber()):(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >>> Testing StringToChars using fd(self={%s : 1})
    fd(self={1 : 1}):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    fd(self={b"\0" : 1}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    fd(self={"\0" : 1}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using fd(self={"abcF" : {%s : 1}})
    fd(self={"abcF" : {1 : 1}}):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    fd(self={"abcF" : {b"\0" : 1}}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    fd(self={"abcF" : {"\0" : 1}}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using fd(self={"abcF" : Mapping({%s : 1})})
    fd(self={"abcF" : Mapping({1 : 1})}):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    fd(self={"abcF" : Mapping({b"\0" : 1})}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    fd(self={"abcF" : Mapping({"\0" : 1})}):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing *Iter* using fd(self={"abcF" : %s})
    fd(self={"abcF" : FailingIter()}):(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    fd(self={"abcF" : FailingIterNext()}):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using fd(self={"abcF" : %s})
    fd(self={"abcF" : None}):NOT FAILED
    fd(self={"abcF" : {b"": 1}}):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    fd(self={"abcF" : {"": 1}}):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    fd(self={"abcF" : FailingMapping()}):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    fd(self={"abcF" : FailingMappingKey()}):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    fd(self={"abcF" : FailingNumber()}):(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >>> Testing StringToChars using fd(self=Mapping({%s : 1}))
    fd(self=Mapping({1 : 1})):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    fd(self=Mapping({b"\0" : 1})):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    fd(self=Mapping({"\0" : 1})):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using fd(self=Mapping({"abcG" : {%s : 1}}))
    fd(self=Mapping({"abcG" : {1 : 1}})):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    fd(self=Mapping({"abcG" : {b"\0" : 1}})):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    fd(self=Mapping({"abcG" : {"\0" : 1}})):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing StringToChars using fd(self=Mapping({"abcG" : Mapping({%s : 1})}))
    fd(self=Mapping({"abcG" : Mapping({1 : 1})})):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    fd(self=Mapping({"abcG" : Mapping({b"\0" : 1})})):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    fd(self=Mapping({"abcG" : Mapping({"\0" : 1})})):(<class 'TypeError'>, TypeError('expected bytes with no null',))
    <<< Finished
    >>> Testing *Iter* using fd(self=Mapping({"abcG" : %s}))
    fd(self=Mapping({"abcG" : FailingIter()})):(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim structure',))
    fd(self=Mapping({"abcG" : FailingIterNext()})):(<class 'NotImplementedError'>, NotImplementedError('next',))
    <<< Finished
    >>> Testing ConvertFromPyObject using fd(self=Mapping({"abcG" : %s}))
    fd(self=Mapping({"abcG" : None})):NOT FAILED
    fd(self=Mapping({"abcG" : {b"": 1}})):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    fd(self=Mapping({"abcG" : {"": 1}})):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    fd(self=Mapping({"abcG" : FailingMapping()})):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    fd(self=Mapping({"abcG" : FailingMappingKey()})):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    fd(self=Mapping({"abcG" : FailingNumber()})):(<class 'NotImplementedError'>, NotImplementedError('int',))
    <<< Finished
    >>> Testing *Iter* using fd(self=%s)
    fd(self=FailingIter()):(<class 'TypeError'>, TypeError('unable to convert FailingIter to a Vim dictionary',))
    fd(self=FailingIterNext()):(<class 'TypeError'>, TypeError('unable to convert FailingIterNext to a Vim dictionary',))
    <<< Finished
    >>> Testing ConvertFromPyObject using fd(self=%s)
    fd(self=None):(<class 'TypeError'>, TypeError('unable to convert NoneType to a Vim dictionary',))
    fd(self={b"": 1}):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    fd(self={"": 1}):(<class 'ValueError'>, ValueError('empty keys are not allowed',))
    fd(self=FailingMapping()):(<class 'NotImplementedError'>, NotImplementedError('keys',))
    fd(self=FailingMappingKey()):(<class 'NotImplementedError'>, NotImplementedError('getitem:mappingkey',))
    fd(self=FailingNumber()):(<class 'TypeError'>, TypeError('unable to convert FailingNumber to a Vim dictionary',))
    <<< Finished
    >>> Testing ConvertFromPyMapping using fd(self=%s)
    fd(self=[]):(<class 'AttributeError'>, AttributeError('keys',))
    <<< Finished
    > TabPage
    >> TabPageAttr
    vim.current.tabpage.xxx:(<class 'AttributeError'>, AttributeError("'vim.tabpage' object has no attribute 'xxx'",))
    > TabList
    >> TabListItem
    vim.tabpages[1000]:(<class 'IndexError'>, IndexError('no such tab page',))
    > Window
    >> WindowAttr
    vim.current.window.xxx:(<class 'AttributeError'>, AttributeError("'vim.window' object has no attribute 'xxx'",))
    >> WindowSetattr
    vim.current.window.buffer = 0:(<class 'TypeError'>, TypeError('readonly attribute: buffer',))
    vim.current.window.cursor = (100000000, 100000000):(<class 'vim.error'>, error('cursor position outside buffer',))
    vim.current.window.cursor = True:(<class 'TypeError'>, TypeError('argument must be 2-item sequence, not bool',))
    >>> Testing NumberToLong using vim.current.window.height = %s
    vim.current.window.height = []:(<class 'TypeError'>, TypeError('expected int() or something supporting coercing to int(), but got list',))
    vim.current.window.height = None:(<class 'TypeError'>, TypeError('expected int() or something supporting coercing to int(), but got NoneType',))
    vim.current.window.height = -1:(<class 'ValueError'>, ValueError('number must be greater or equal to zero',))
    <<< Finished
    >>> Testing NumberToLong using vim.current.window.width = %s
    vim.current.window.width = []:(<class 'TypeError'>, TypeError('expected int() or something supporting coercing to int(), but got list',))
    vim.current.window.width = None:(<class 'TypeError'>, TypeError('expected int() or something supporting coercing to int(), but got NoneType',))
    vim.current.window.width = -1:(<class 'ValueError'>, ValueError('number must be greater or equal to zero',))
    <<< Finished
    vim.current.window.xxxxxx = True:(<class 'AttributeError'>, AttributeError('xxxxxx',))
    > WinList
    >> WinListItem
    vim.windows[1000]:(<class 'IndexError'>, IndexError('no such window',))
    > Buffer
    >> StringToLine (indirect)
    vim.current.buffer[0] = "\na":(<class 'vim.error'>, error('string cannot contain newlines',))
    vim.current.buffer[0] = b"\na":(<class 'vim.error'>, error('string cannot contain newlines',))
    >> SetBufferLine (indirect)
    vim.current.buffer[0] = True:(<class 'TypeError'>, TypeError('bad argument type for built-in operation',))
    >> SetBufferLineList (indirect)
    vim.current.buffer[:] = True:(<class 'TypeError'>, TypeError('bad argument type for built-in operation',))
    vim.current.buffer[:] = ["\na", "bc"]:(<class 'vim.error'>, error('string cannot contain newlines',))
    >> InsertBufferLines (indirect)
    vim.current.buffer.append(None):(<class 'TypeError'>, TypeError('bad argument type for built-in operation',))
    vim.current.buffer.append(["\na", "bc"]):(<class 'vim.error'>, error('string cannot contain newlines',))
    vim.current.buffer.append("\nbc"):(<class 'vim.error'>, error('string cannot contain newlines',))
    >> RBItem
    vim.current.buffer[100000000]:(<class 'IndexError'>, IndexError('line number out of range',))
    >> RBAsItem
    vim.current.buffer[100000000] = "":(<class 'IndexError'>, IndexError('line number out of range',))
    >> BufferAttr
    vim.current.buffer.xxx:(<class 'AttributeError'>, AttributeError("'vim.buffer' object has no attribute 'xxx'",))
    >> BufferSetattr
    vim.current.buffer.name = True:(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got bool',))
    vim.current.buffer.xxx = True:(<class 'AttributeError'>, AttributeError('xxx',))
    >> BufferMark
    vim.current.buffer.mark(0):(<class 'TypeError'>, TypeError('expected bytes() or str() instance, but got int',))
    vim.current.buffer.mark("abcM"):(<class 'ValueError'>, ValueError('mark name must be a single character',))
    vim.current.buffer.mark("!"):(<class 'vim.error'>, error('invalid mark name',))
    >> BufferRange
    vim.current.buffer.range(1, 2, 3):(<class 'TypeError'>, TypeError('function takes exactly 2 arguments (3 given)',))
    > BufMap
    >> BufMapItem
    vim.buffers[100000000]:(<class 'KeyError'>, KeyError(100000000,))
    >>> Testing NumberToLong using vim.buffers[%s]
    vim.buffers[[]]:(<class 'TypeError'>, TypeError('expected int() or something supporting coercing to int(), but got list',))
    vim.buffers[None]:(<class 'TypeError'>, TypeError('expected int() or something supporting coercing to int(), but got NoneType',))
    vim.buffers[-1]:(<class 'ValueError'>, ValueError('number must be greater than zero',))
    vim.buffers[0]:(<class 'ValueError'>, ValueError('number must be greater than zero',))
    <<< Finished
    > Current
    >> CurrentGetattr
    vim.current.xxx:(<class 'AttributeError'>, AttributeError("'vim.currentdata' object has no attribute 'xxx'",))
    >> CurrentSetattr
    vim.current.line = True:(<class 'TypeError'>, TypeError('bad argument type for built-in operation',))
    vim.current.buffer = True:(<class 'TypeError'>, TypeError('expected vim.Buffer object, but got bool',))
    vim.current.window = True:(<class 'TypeError'>, TypeError('expected vim.Window object, but got bool',))
    vim.current.tabpage = True:(<class 'TypeError'>, TypeError('expected vim.TabPage object, but got bool',))
    vim.current.xxx = True:(<class 'AttributeError'>, AttributeError('xxx',))
  END

  let actual = getline(2, '$')
  let n_expected = len(expected)
  let n_actual = len(actual)
  call assert_equal(n_expected, n_actual, 'number of lines to compare')

  " Compare line by line so the errors are easier to understand.  Missing lines
  " are compared with an empty string.
  for i in range(n_expected > n_actual ? n_expected : n_actual)
    call assert_equal(i >= n_expected ? '' : expected[i], i >= n_actual ? '' : actual[i])
  endfor
  close!
endfunc

" Test import
func Test_python3_import()
  throw 'Skipped: TODO: '
  new
  py3 cb = vim.current.buffer

  py3 << trim EOF
    sys.path.insert(0, os.path.join(os.getcwd(), 'python_before'))
    sys.path.append(os.path.join(os.getcwd(), 'python_after'))
    vim.options['rtp'] = os.getcwd().replace(',', '\\,').replace('\\', '\\\\')
    l = []
    def callback(path):
        l.append(os.path.relpath(path))
    vim.foreach_rtp(callback)
    cb.append(repr(l))
    del l
    def callback(path):
        return os.path.relpath(path)
    cb.append(repr(vim.foreach_rtp(callback)))
    del callback
    from module import dir as d
    from modulex import ddir
    cb.append(d + ',' + ddir)
    import before
    cb.append(before.dir)
    import after
    cb.append(after.dir)
    import topmodule as tm
    import topmodule.submodule as tms
    import topmodule.submodule.subsubmodule.subsubsubmodule as tmsss
    cb.append(tm.__file__.replace(os.path.sep, '/')[-len('modulex/topmodule/__init__.py'):])
    cb.append(tms.__file__.replace(os.path.sep, '/')[-len('modulex/topmodule/submodule/__init__.py'):])
    cb.append(tmsss.__file__.replace(os.path.sep, '/')[-len('modulex/topmodule/submodule/subsubmodule/subsubsubmodule.py'):])

    del before
    del after
    del d
    del ddir
    del tm
    del tms
    del tmsss
  EOF

  let expected =<< trim END
    ['.']
    '.'
    3,xx
    before
    after
    pythonx/topmodule/__init__.py
    pythonx/topmodule/submodule/__init__.py
    pythonx/topmodule/submodule/subsubmodule/subsubsubmodule.py
  END
  call assert_equal(expected, getline(2, '$'))
  close!
endfunc

" Test exceptions
func Test_python3_exception()
  throw 'Skipped: Nvim does not support vim.bindeval()'
  func Exe(e)
    execute a:e
  endfunc

  new
  py3 cb = vim.current.buffer

  py3 << trim EOF
    Exe = vim.bindeval('function("Exe")')
    ee('vim.command("throw \'abcN\'")')
    ee('Exe("throw \'def\'")')
    ee('vim.eval("Exe(\'throw \'\'ghi\'\'\')")')
    ee('vim.eval("Exe(\'echoerr \'\'jkl\'\'\')")')
    ee('vim.eval("Exe(\'xxx_non_existent_command_xxx\')")')
    ee('vim.eval("xxx_unknown_function_xxx()")')
    ee('vim.bindeval("Exe(\'xxx_non_existent_command_xxx\')")')
    del Exe
  EOF
  delfunction Exe

  let expected =<< trim END
    vim.command("throw 'abcN'"):(<class 'vim.error'>, error('abcN',))
    Exe("throw 'def'"):(<class 'vim.error'>, error('def',))
    vim.eval("Exe('throw ''ghi''')"):(<class 'vim.error'>, error('ghi',))
    vim.eval("Exe('echoerr ''jkl''')"):(<class 'vim.error'>, error('Vim(echoerr):jkl',))
    vim.eval("Exe('xxx_non_existent_command_xxx')"):(<class 'vim.error'>, error('Vim:E492: Not an editor command: xxx_non_existent_command_xxx',))
    vim.eval("xxx_unknown_function_xxx()"):(<class 'vim.error'>, error('Vim:E117: Unknown function: xxx_unknown_function_xxx',))
    vim.bindeval("Exe('xxx_non_existent_command_xxx')"):(<class 'vim.error'>, error('Vim:E492: Not an editor command: xxx_non_existent_command_xxx',))
  END
  call assert_equal(expected, getline(2, '$'))
  close!
endfunc

" Regression: interrupting vim.command propagates to next vim.command
func Test_python3_keyboard_interrupt()
  new
  py3 cb = vim.current.buffer
  py3 << trim EOF
    def test_keyboard_interrupt():
        try:
            vim.command('while 1 | endwhile')
        except KeyboardInterrupt:
            cb.append('Caught KeyboardInterrupt')
        except Exception:
            cb.append('!!!!!!!! Caught exception: ' + emsg(sys.exc_info()))
        else:
            cb.append('!!!!!!!! No exception')
        try:
            vim.command('$ put =\'Running :put\'')
        except KeyboardInterrupt:
            cb.append('!!!!!!!! Caught KeyboardInterrupt')
        except Exception:
            cb.append('!!!!!!!! Caught exception: ' + emsg(sys.exc_info()))
        else:
            cb.append('No exception')
  EOF

  debuggreedy
  call inputsave()
  call feedkeys("s\ns\ns\ns\nq\n")
  redir => output
  debug silent! py3 test_keyboard_interrupt()
  redir END
  0 debuggreedy
  call inputrestore()
  py3 del test_keyboard_interrupt

  let expected =<< trim END
    !!!!!!!! Caught exception: NvimError:('Keyboard interrupt',)
    Running :put
    No exception
  END
  call assert_equal(expected, getline(2, '$'))
  call assert_equal('', output)
  close!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
