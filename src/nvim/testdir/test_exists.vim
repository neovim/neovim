" Tests for the exists() function
func Test_exists()
  augroup myagroup
      autocmd! BufEnter       *.my     echo "myfile edited"
      autocmd! FuncUndefined  UndefFun exec "fu UndefFun()\nendfu"
  augroup END
  set rtp+=./sautest

  " valid autocmd group
  call assert_equal(1, exists('#myagroup'))
  " valid autocmd group with garbage
  call assert_equal(0, exists('#myagroup+b'))
  " Valid autocmd group and event
  call assert_equal(1, exists('#myagroup#BufEnter'))
  " Valid autocmd group, event and pattern
  call assert_equal(1, exists('#myagroup#BufEnter#*.my'))
  " Valid autocmd event
  call assert_equal(1, exists('#BufEnter'))
  " Valid autocmd event and pattern
  call assert_equal(1, exists('#BufEnter#*.my'))
  " Non-existing autocmd group or event
  call assert_equal(0, exists('#xyzagroup'))
  " Non-existing autocmd group and valid autocmd event
  call assert_equal(0, exists('#xyzagroup#BufEnter'))
  " Valid autocmd group and event with no matching pattern
  call assert_equal(0, exists('#myagroup#CmdwinEnter'))
  " Valid autocmd group and non-existing autocmd event
  call assert_equal(0, exists('#myagroup#xyzacmd'))
  " Valid autocmd group and event and non-matching pattern
  call assert_equal(0, exists('#myagroup#BufEnter#xyzpat'))
  " Valid autocmd event and non-matching pattern
  call assert_equal(0, exists('#BufEnter#xyzpat'))
  " Empty autocmd group, event and pattern
  call assert_equal(0, exists('###'))
  " Empty autocmd group and event or empty event and pattern
  call assert_equal(0, exists('##'))
  " Valid autocmd event
  call assert_equal(1, exists('##FileReadCmd'))
  " Non-existing autocmd event
  call assert_equal(0, exists('##MySpecialCmd'))

  " Existing and working option (long form)
  call assert_equal(1, exists('&textwidth'))
  " Existing and working option (short form)
  call assert_equal(1, exists('&tw'))
  " Existing and working option with garbage
  call assert_equal(0, exists('&tw-'))
  " Global option
  call assert_equal(1, exists('&g:errorformat'))
  " Local option
  call assert_equal(1, exists('&l:errorformat'))
  " Negative form of existing and working option (long form)
  call assert_equal(0, exists('&nojoinspaces'))
  " Negative form of existing and working option (short form)
  call assert_equal(0, exists('&nojs'))
  " Non-existing option
  call assert_equal(0, exists('&myxyzoption'))

  " Existing and working option (long form)
  call assert_equal(1, exists('+incsearch'))
  " Existing and working option with garbage
  call assert_equal(0, exists('+incsearch!1'))
  " Existing and working option (short form)
  call assert_equal(1, exists('+is'))
  " Existing option that is hidden.
  call assert_equal(0, exists('+autoprint'))

  " Existing environment variable
  let $EDITOR_NAME = 'Vim Editor'
  call assert_equal(1, exists('$EDITOR_NAME'))
  " Non-existing environment variable
  call assert_equal(0, exists('$NON_ENV_VAR'))

  " Valid internal function
  call assert_equal(1, exists('*bufnr'))
  " Valid internal function with ()
  call assert_equal(1, exists('*bufnr()'))
  " Non-existing internal function
  call assert_equal(0, exists('*myxyzfunc'))
  " Valid internal function with garbage
  call assert_equal(0, exists('*bufnr&6'))
  " Valid user defined function
  call assert_equal(1, exists('*Test_exists'))
  " Non-existing user defined function
  call assert_equal(0, exists('*MyxyzFunc'))
  " Function that may be created by FuncUndefined event
  call assert_equal(0, exists('*UndefFun'))
  " Function that may be created by script autoloading
  call assert_equal(0, exists('*footest#F'))

  " Valid internal command (full match)
  call assert_equal(2, exists(':edit'))
  " Valid internal command (full match) with garbage
  call assert_equal(0, exists(':edit/a'))
  " Valid internal command (partial match)
  call assert_equal(1, exists(':q'))
  " Non-existing internal command
  call assert_equal(0, exists(':invalidcmd'))

  " User defined command (full match)
  command! MyCmd :echo 'My command'
  call assert_equal(2, exists(':MyCmd'))
  " User defined command (partial match)
  command! MyOtherCmd :echo 'Another command'
  call assert_equal(3, exists(':My'))

  " Command modifier
  call assert_equal(2, exists(':rightbelow'))

  " Non-existing user defined command (full match)
  delcommand MyCmd
  call assert_equal(0, exists(':MyCmd'))

  " Non-existing user defined command (partial match)
  delcommand MyOtherCmd
  call assert_equal(0, exists(':My'))

  " Valid local variable
  let local_var = 1
  call assert_equal(1, exists('local_var'))
  " Valid local variable with garbage
  call assert_equal(0, exists('local_var%n'))
  " Non-existing local variable
  unlet local_var
  call assert_equal(0, exists('local_var'))

  " Non-existing autoload variable that may be autoloaded
  call assert_equal(0, exists('footest#x'))

  " Valid local list
  let local_list = ["blue", "orange"]
  call assert_equal(1, exists('local_list'))
  " Valid local list item
  call assert_equal(1, exists('local_list[1]'))
  " Valid local list item with garbage
  call assert_equal(0, exists('local_list[1]+5'))
  " Invalid local list item
  call assert_equal(0, exists('local_list[2]'))
  " Non-existing local list
  unlet local_list
  call assert_equal(0, exists('local_list'))
  " Valid local dictionary
  let local_dict = {"xcord":100, "ycord":2}
  call assert_equal(1, exists('local_dict'))
  " Non-existing local dictionary
  unlet local_dict
  call assert_equal(0, exists('local_dict'))
  " Existing local curly-brace variable
  let str = "local"
  let curly_{str}_var = 1
  call assert_equal(1, exists('curly_{str}_var'))
  " Non-existing local curly-brace variable
  unlet curly_{str}_var
  call assert_equal(0, exists('curly_{str}_var'))

  " Existing global variable
  let g:global_var = 1
  call assert_equal(1, exists('g:global_var'))
  " Existing global variable with garbage
  call assert_equal(0, exists('g:global_var-n'))
  " Non-existing global variable
  unlet g:global_var
  call assert_equal(0, exists('g:global_var'))
  " Existing global list
  let g:global_list = ["blue", "orange"]
  call assert_equal(1, exists('g:global_list'))
  " Non-existing global list
  unlet g:global_list
  call assert_equal(0, exists('g:global_list'))
  " Existing global dictionary
  let g:global_dict = {"xcord":100, "ycord":2}
  call assert_equal(1, exists('g:global_dict'))
  " Non-existing global dictionary
  unlet g:global_dict
  call assert_equal(0, exists('g:global_dict'))
  " Existing global curly-brace variable
  let str = "global"
  let g:curly_{str}_var = 1
  call assert_equal(1, exists('g:curly_{str}_var'))
  " Non-existing global curly-brace variable
  unlet g:curly_{str}_var
  call assert_equal(0, exists('g:curly_{str}_var'))

  " Existing window variable
  let w:window_var = 1
  call assert_equal(1, exists('w:window_var'))
  " Non-existing window variable
  unlet w:window_var
  call assert_equal(0, exists('w:window_var'))
  " Existing window list
  let w:window_list = ["blue", "orange"]
  call assert_equal(1, exists('w:window_list'))
  " Non-existing window list
  unlet w:window_list
  call assert_equal(0, exists('w:window_list'))
  " Existing window dictionary
  let w:window_dict = {"xcord":100, "ycord":2}
  call assert_equal(1, exists('w:window_dict'))
  " Non-existing window dictionary
  unlet w:window_dict
  call assert_equal(0, exists('w:window_dict'))
  " Existing window curly-brace variable
  let str = "window"
  let w:curly_{str}_var = 1
  call assert_equal(1, exists('w:curly_{str}_var'))
  " Non-existing window curly-brace variable
  unlet w:curly_{str}_var
  call assert_equal(0, exists('w:curly_{str}_var'))

  " Existing tab variable
  let t:tab_var = 1
  call assert_equal(1, exists('t:tab_var'))
  " Non-existing tab variable
  unlet t:tab_var
  call assert_equal(0, exists('t:tab_var'))
  " Existing tab list
  let t:tab_list = ["blue", "orange"]
  call assert_equal(1, exists('t:tab_list'))
  " Non-existing tab list
  unlet t:tab_list
  call assert_equal(0, exists('t:tab_list'))
  " Existing tab dictionary
  let t:tab_dict = {"xcord":100, "ycord":2}
  call assert_equal(1, exists('t:tab_dict'))
  " Non-existing tab dictionary
  unlet t:tab_dict
  call assert_equal(0, exists('t:tab_dict'))
  " Existing tab curly-brace variable
  let str = "tab"
  let t:curly_{str}_var = 1
  call assert_equal(1, exists('t:curly_{str}_var'))
  " Non-existing tab curly-brace variable
  unlet t:curly_{str}_var
  call assert_equal(0, exists('t:curly_{str}_var'))

  " Existing buffer variable
  let b:buffer_var = 1
  call assert_equal(1, exists('b:buffer_var'))
  " Non-existing buffer variable
  unlet b:buffer_var
  call assert_equal(0, exists('b:buffer_var'))
  " Existing buffer list
  let b:buffer_list = ["blue", "orange"]
  call assert_equal(1, exists('b:buffer_list'))
  " Non-existing buffer list
  unlet b:buffer_list
  call assert_equal(0, exists('b:buffer_list'))
  " Existing buffer dictionary
  let b:buffer_dict = {"xcord":100, "ycord":2}
  call assert_equal(1, exists('b:buffer_dict'))
  " Non-existing buffer dictionary
  unlet b:buffer_dict
  call assert_equal(0, exists('b:buffer_dict'))
  " Existing buffer curly-brace variable
  let str = "buffer"
  let b:curly_{str}_var = 1
  call assert_equal(1, exists('b:curly_{str}_var'))
  " Non-existing buffer curly-brace variable
  unlet b:curly_{str}_var
  call assert_equal(0, exists('b:curly_{str}_var'))

  " Existing Vim internal variable
  call assert_equal(1, exists('v:version'))
  " Non-existing Vim internal variable
  call assert_equal(0, exists('v:non_exists_var'))

  " Existing script-local variable
  let s:script_var = 1
  call assert_equal(1, exists('s:script_var'))
  " Non-existing script-local variable
  unlet s:script_var
  call assert_equal(0, exists('s:script_var'))
  " Existing script-local list
  let s:script_list = ["blue", "orange"]
  call assert_equal(1, exists('s:script_list'))
  " Non-existing script-local list
  unlet s:script_list
  call assert_equal(0, exists('s:script_list'))
  " Existing script-local dictionary
  let s:script_dict = {"xcord":100, "ycord":2}
  call assert_equal(1, exists('s:script_dict'))
  " Non-existing script-local dictionary
  unlet s:script_dict
  call assert_equal(0, exists('s:script_dict'))
  " Existing script curly-brace variable
  let str = "script"
  let s:curly_{str}_var = 1
  call assert_equal(1, exists('s:curly_{str}_var'))
  " Non-existing script-local curly-brace variable
  unlet s:curly_{str}_var
  call assert_equal(0, exists('s:curly_{str}_var'))

  " Existing script-local function
  function! s:my_script_func()
  endfunction

  echo '*s:my_script_func: 1'
  call assert_equal(1, exists('*s:my_script_func'))

  " Non-existing script-local function
  delfunction s:my_script_func

  call assert_equal(0, exists('*s:my_script_func'))
  unlet str

  call assert_equal(1, g:footest#x)
  call assert_equal(0, footest#F())
  call assert_equal(0, UndefFun())
endfunc

" exists() test for Function arguments
func FuncArg_Tests(func_arg, ...)
  call assert_equal(1, exists('a:func_arg'))
  call assert_equal(0, exists('a:non_exists_arg'))
  call assert_equal(1, exists('a:1'))
  call assert_equal(0, exists('a:2'))
endfunc

func Test_exists_funcarg()
  call FuncArg_Tests("arg1", "arg2")
endfunc
