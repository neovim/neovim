-- Tests for the exists() and has() functions.

local helpers = require('test.functional.helpers')(after_each)
local source = helpers.source
local clear, expect = helpers.clear, helpers.expect
local write_file = helpers.write_file

describe('exists() and has() functions', function()
  setup(function()
    clear()
    -- Create a temporary script needed for the test.
    write_file('test60.vim', [[
      " Vim script for exists() function test
      " Script-local variables are checked here

      " Existing script-local variable
      let s:script_var = 1
      echo 's:script_var: 1'
      if exists('s:script_var')
          echo "OK"
      else
          echo "FAILED"
      endif

      " Non-existing script-local variable
      unlet s:script_var
      echo 's:script_var: 0'
      if !exists('s:script_var')
          echo "OK"
      else
          echo "FAILED"
      endif

      " Existing script-local list
      let s:script_list = ["blue", "orange"]
      echo 's:script_list: 1'
      if exists('s:script_list')
          echo "OK"
      else
          echo "FAILED"
      endif

      " Non-existing script-local list
      unlet s:script_list
      echo 's:script_list: 0'
      if !exists('s:script_list')
          echo "OK"
      else
          echo "FAILED"
      endif

      " Existing script-local dictionary
      let s:script_dict = {"xcord":100, "ycord":2}
      echo 's:script_dict: 1'
      if exists('s:script_dict')
          echo "OK"
      else
          echo "FAILED"
      endif

      " Non-existing script-local dictionary
      unlet s:script_dict
      echo 's:script_dict: 0'
      if !exists('s:script_dict')
          echo "OK"
      else
          echo "FAILED"
      endif

      " Existing script curly-brace variable
      let str = "script"
      let s:curly_{str}_var = 1
      echo 's:curly_' . str . '_var: 1'
      if exists('s:curly_{str}_var')
          echo "OK"
      else
          echo "FAILED"
      endif

      " Non-existing script-local curly-brace variable
      unlet s:curly_{str}_var
      echo 's:curly_' . str . '_var: 0'
      if !exists('s:curly_{str}_var')
          echo "OK"
      else
          echo "FAILED"
      endif

      " Existing script-local function
      function! s:my_script_func()
      endfunction

      echo '*s:my_script_func: 1'
      if exists('*s:my_script_func')
          echo "OK"
      else
          echo "FAILED"
      endif

      " Non-existing script-local function
      delfunction s:my_script_func

      echo '*s:my_script_func: 0'
      if !exists('*s:my_script_func')
          echo "OK"
      else
          echo "FAILED"
      endif
      unlet str
      ]])
  end)
  teardown(function()
    os.remove('test.out')
    os.remove('test60.vim')
  end)

  it('is working', function()

    source([=[
      " Add the special directory with test scripts to &rtp
      set rtp+=test/functional/fixtures
      set wildchar=^E
      function! RunTest(str, result)
          if exists(a:str) == a:result
              echo "OK"
          else
              echo "FAILED: Checking for " . a:str
          endif
      endfunction
      function! TestExists()
          augroup myagroup
          autocmd! BufEnter       *.my     echo "myfile edited"
          autocmd! FuncUndefined  UndefFun exec "fu UndefFun()\nendfu"
          augroup END
          set rtp+=./sautest
          let test_cases = []
          " Valid autocmd group.
          let test_cases += [['#myagroup', 1]]
          " Valid autocmd group with garbage.
          let test_cases += [['#myagroup+b', 0]]
          " Valid autocmd group and event.
          let test_cases += [['#myagroup#BufEnter', 1]]
          " Valid autocmd group, event and pattern.
          let test_cases += [['#myagroup#BufEnter#*.my', 1]]
          " Valid autocmd event.
          let test_cases += [['#BufEnter', 1]]
          " Valid autocmd event and pattern.
          let test_cases += [['#BufEnter#*.my', 1]]
          " Non-existing autocmd group or event.
          let test_cases += [['#xyzagroup', 0]]
          " Non-existing autocmd group and valid autocmd event.
          let test_cases += [['#xyzagroup#BufEnter', 0]]
          " Valid autocmd group and event with no matching pattern.
          let test_cases += [['#myagroup#CmdwinEnter', 0]]
          " Valid autocmd group and non-existing autocmd event.
          let test_cases += [['#myagroup#xyzacmd', 0]]
          " Valid autocmd group and event and non-matching pattern.
          let test_cases += [['#myagroup#BufEnter#xyzpat', 0]]
          " Valid autocmd event and non-matching pattern.
          let test_cases += [['#BufEnter#xyzpat', 0]]
          " Empty autocmd group, event and pattern.
          let test_cases += [['###', 0]]
          " Empty autocmd group and event or empty event and pattern.
          let test_cases += [['##', 0]]
          " Valid autocmd event.
          let test_cases += [['##FileReadCmd', 1]]
          " Non-existing autocmd event.
          let test_cases += [['##MySpecialCmd', 0]]
          " Existing and working option (long form).
          let test_cases += [['&textwidth', 1]]
          " Existing and working option (short form).
          let test_cases += [['&tw', 1]]
          " Existing and working option with garbage.
          let test_cases += [['&tw-', 0]]
          " Global option.
          let test_cases += [['&g:errorformat', 1]]
          " Local option.
          let test_cases += [['&l:errorformat', 1]]
          " Negative form of existing and working option (long form).
          let test_cases += [['&nojoinspaces', 0]]
          " Negative form of existing and working option (short form).
          let test_cases += [['&nojs', 0]]
          " Non-existing option.
          let test_cases += [['&myxyzoption', 0]]
          " Existing and working option (long form).
          let test_cases += [['+incsearch', 1]]
          " Existing and working option with garbage.
          let test_cases += [['+incsearch!1', 0]]
          " Existing and working option (short form).
          let test_cases += [['+is', 1]]
          " Existing option that is hidden.
          let test_cases += [['+mouseshape', 0]]
          " Existing environment variable.
          let $EDITOR_NAME = 'Vim Editor'
          let test_cases += [['$EDITOR_NAME', 1]]
          " Non-existing environment variable.
          let test_cases += [['$NON_ENV_VAR', 0]]
          " Valid internal function.
          let test_cases += [['*bufnr', 1]]
          " Valid internal function with ().
          let test_cases += [['*bufnr()', 1]]
          " Non-existing internal function.
          let test_cases += [['*myxyzfunc', 0]]
          " Valid internal function with garbage.
          let test_cases += [['*bufnr&6', 0]]
          " Valid user defined function.
          let test_cases += [['*TestExists', 1]]
          " Non-existing user defined function.
          let test_cases += [['*MyxyzFunc', 0]]
          " Function that may be created by FuncUndefined event.
          let test_cases += [['*UndefFun', 0]]
          " Function that may be created by script autoloading.
          let test_cases += [['*footest#F', 0]]
          redir! > test.out
          for [test_case, result] in test_cases
              echo test_case . ": " . result
              call RunTest(test_case, result)
          endfor
          " Valid internal command (full match).
          echo ':edit: 2'
          if exists(':edit') == 2
            echo "OK"
          else
            echo "FAILED"
          endif
          " Valid internal command (full match) with garbage.
          echo ':edit/a: 0'
          if exists(':edit/a') == 0
            echo "OK"
          else
            echo "FAILED"
          endif
          " Valid internal command (partial match).
          echo ':q: 1'
          if exists(':q') == 1
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing internal command.
          echo ':invalidcmd: 0'
          if !exists(':invalidcmd')
            echo "OK"
          else
            echo "FAILED"
          endif
          " User defined command (full match).
          command! MyCmd :echo 'My command'
          echo ':MyCmd: 2'
          if exists(':MyCmd') == 2
            echo "OK"
          else
            echo "FAILED"
          endif
          " User defined command (partial match).
          command! MyOtherCmd :echo 'Another command'
          echo ':My: 3'
          if exists(':My') == 3
            echo "OK"
          else
            echo "FAILED"
          endif
          " Command modifier.
          echo ':rightbelow: 2'
          if exists(':rightbelow') == 2
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing user defined command (full match).
          delcommand MyCmd
          echo ':MyCmd: 0'
          if !exists(':MyCmd')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing user defined command (partial match).
          delcommand MyOtherCmd
          echo ':My: 0'
          if !exists(':My')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Valid local variable.
          let local_var = 1
          echo 'local_var: 1'
          if exists('local_var')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Valid local variable with garbage.
          let local_var = 1
          echo 'local_var%n: 0'
          if !exists('local_var%n')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing local variable.
          unlet local_var
          echo 'local_var: 0'
          if !exists('local_var')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing autoload variable that may be autoloaded.
          echo 'footest#x: 0'
          if !exists('footest#x')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Valid local list.
          let local_list = ["blue", "orange"]
          echo 'local_list: 1'
          if exists('local_list')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Valid local list item.
          echo 'local_list[1]: 1'
          if exists('local_list[1]')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Valid local list item with garbage.
          echo 'local_list[1]+5: 0'
          if !exists('local_list[1]+5')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Invalid local list item.
          echo 'local_list[2]: 0'
          if !exists('local_list[2]')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing local list.
          unlet local_list
          echo 'local_list: 0'
          if !exists('local_list')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Valid local dictionary.
          let local_dict = {"xcord":100, "ycord":2}
          echo 'local_dict: 1'
          if exists('local_dict')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing local dictionary.
          unlet local_dict
          echo 'local_dict: 0'
          if !exists('local_dict')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Existing local curly-brace variable.
          let str = "local"
          let curly_{str}_var = 1
          echo 'curly_' . str . '_var: 1'
          if exists('curly_{str}_var')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing local curly-brace variable.
          unlet curly_{str}_var
          echo 'curly_' . str . '_var: 0'
          if !exists('curly_{str}_var')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Existing global variable.
          let g:global_var = 1
          echo 'g:global_var: 1'
          if exists('g:global_var')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Existing global variable with garbage.
          echo 'g:global_var-n: 1'
          if !exists('g:global_var-n')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing global variable.
          unlet g:global_var
          echo 'g:global_var: 0'
          if !exists('g:global_var')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Existing global list.
          let g:global_list = ["blue", "orange"]
          echo 'g:global_list: 1'
          if exists('g:global_list')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing global list.
          unlet g:global_list
          echo 'g:global_list: 0'
          if !exists('g:global_list')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Existing global dictionary.
          let g:global_dict = {"xcord":100, "ycord":2}
          echo 'g:global_dict: 1'
          if exists('g:global_dict')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing global dictionary.
          unlet g:global_dict
          echo 'g:global_dict: 0'
          if !exists('g:global_dict')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Existing global curly-brace variable.
          let str = "global"
          let g:curly_{str}_var = 1
          echo 'g:curly_' . str . '_var: 1'
          if exists('g:curly_{str}_var')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing global curly-brace variable.
          unlet g:curly_{str}_var
          echo 'g:curly_' . str . '_var: 0'
          if !exists('g:curly_{str}_var')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Existing window variable.
          echo 'w:window_var: 1'
          let w:window_var = 1
          if exists('w:window_var')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing window variable.
          unlet w:window_var
          echo 'w:window_var: 0'
          if !exists('w:window_var')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Existing window list.
          let w:window_list = ["blue", "orange"]
          echo 'w:window_list: 1'
          if exists('w:window_list')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing window list.
          unlet w:window_list
          echo 'w:window_list: 0'
          if !exists('w:window_list')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Existing window dictionary.
          let w:window_dict = {"xcord":100, "ycord":2}
          echo 'w:window_dict: 1'
          if exists('w:window_dict')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing window dictionary.
          unlet w:window_dict
          echo 'w:window_dict: 0'
          if !exists('w:window_dict')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Existing window curly-brace variable.
          let str = "window"
          let w:curly_{str}_var = 1
          echo 'w:curly_' . str . '_var: 1'
          if exists('w:curly_{str}_var')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing window curly-brace variable.
          unlet w:curly_{str}_var
          echo 'w:curly_' . str . '_var: 0'
          if !exists('w:curly_{str}_var')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Existing buffer variable.
          echo 'b:buffer_var: 1'
          let b:buffer_var = 1
          if exists('b:buffer_var')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing buffer variable.
          unlet b:buffer_var
          echo 'b:buffer_var: 0'
          if !exists('b:buffer_var')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Existing buffer list.
          let b:buffer_list = ["blue", "orange"]
          echo 'b:buffer_list: 1'
          if exists('b:buffer_list')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing buffer list.
          unlet b:buffer_list
          echo 'b:buffer_list: 0'
          if !exists('b:buffer_list')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Existing buffer dictionary.
          let b:buffer_dict = {"xcord":100, "ycord":2}
          echo 'b:buffer_dict: 1'
          if exists('b:buffer_dict')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing buffer dictionary.
          unlet b:buffer_dict
          echo 'b:buffer_dict: 0'
          if !exists('b:buffer_dict')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Existing buffer curly-brace variable.
          let str = "buffer"
          let b:curly_{str}_var = 1
          echo 'b:curly_' . str . '_var: 1'
          if exists('b:curly_{str}_var')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing buffer curly-brace variable.
          unlet b:curly_{str}_var
          echo 'b:curly_' . str . '_var: 0'
          if !exists('b:curly_{str}_var')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Script-local tests.
          source test60.vim
          " Existing Vim internal variable.
          echo 'v:version: 1'
          if exists('v:version')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Non-existing Vim internal variable.
          echo 'v:non_exists_var: 0'
          if !exists('v:non_exists_var')
            echo "OK"
          else
            echo "FAILED"
          endif
          " Function arguments.
          function TestFuncArg(func_arg, ...)
              echo 'a:func_arg: 1'
              if exists('a:func_arg')
                  echo "OK"
              else
                  echo "FAILED"
              endif
              echo 'a:non_exists_arg: 0'
              if !exists('a:non_exists_arg')
                  echo "OK"
              else
                  echo "FAILED"
              endif
              echo 'a:1: 1'
              if exists('a:1')
                  echo "OK"
              else
                  echo "FAILED"
              endif
              echo 'a:2: 0'
              if !exists('a:2')
                  echo "OK"
              else
                  echo "FAILED"
              endif
          endfunction
          call TestFuncArg("arg1", "arg2")
          echo ' g:footest#x =' g:footest#x
          echo '   footest#F()' footest#F()
          echo 'UndefFun()' UndefFun()
          redir END
      endfunction

      call TestExists()

      edit! test.out
      set ff=unix
    ]=])

    -- Assert buffer contents.
    expect([[

      #myagroup: 1
      OK
      #myagroup+b: 0
      OK
      #myagroup#BufEnter: 1
      OK
      #myagroup#BufEnter#*.my: 1
      OK
      #BufEnter: 1
      OK
      #BufEnter#*.my: 1
      OK
      #xyzagroup: 0
      OK
      #xyzagroup#BufEnter: 0
      OK
      #myagroup#CmdwinEnter: 0
      OK
      #myagroup#xyzacmd: 0
      OK
      #myagroup#BufEnter#xyzpat: 0
      OK
      #BufEnter#xyzpat: 0
      OK
      ###: 0
      OK
      ##: 0
      OK
      ##FileReadCmd: 1
      OK
      ##MySpecialCmd: 0
      OK
      &textwidth: 1
      OK
      &tw: 1
      OK
      &tw-: 0
      OK
      &g:errorformat: 1
      OK
      &l:errorformat: 1
      OK
      &nojoinspaces: 0
      OK
      &nojs: 0
      OK
      &myxyzoption: 0
      OK
      +incsearch: 1
      OK
      +incsearch!1: 0
      OK
      +is: 1
      OK
      +mouseshape: 0
      OK
      $EDITOR_NAME: 1
      OK
      $NON_ENV_VAR: 0
      OK
      *bufnr: 1
      OK
      *bufnr(): 1
      OK
      *myxyzfunc: 0
      OK
      *bufnr&6: 0
      OK
      *TestExists: 1
      OK
      *MyxyzFunc: 0
      OK
      *UndefFun: 0
      OK
      *footest#F: 0
      OK
      :edit: 2
      OK
      :edit/a: 0
      OK
      :q: 1
      OK
      :invalidcmd: 0
      OK
      :MyCmd: 2
      OK
      :My: 3
      OK
      :rightbelow: 2
      OK
      :MyCmd: 0
      OK
      :My: 0
      OK
      local_var: 1
      OK
      local_var%n: 0
      OK
      local_var: 0
      OK
      footest#x: 0
      OK
      local_list: 1
      OK
      local_list[1]: 1
      OK
      local_list[1]+5: 0
      OK
      local_list[2]: 0
      OK
      local_list: 0
      OK
      local_dict: 1
      OK
      local_dict: 0
      OK
      curly_local_var: 1
      OK
      curly_local_var: 0
      OK
      g:global_var: 1
      OK
      g:global_var-n: 1
      OK
      g:global_var: 0
      OK
      g:global_list: 1
      OK
      g:global_list: 0
      OK
      g:global_dict: 1
      OK
      g:global_dict: 0
      OK
      g:curly_global_var: 1
      OK
      g:curly_global_var: 0
      OK
      w:window_var: 1
      OK
      w:window_var: 0
      OK
      w:window_list: 1
      OK
      w:window_list: 0
      OK
      w:window_dict: 1
      OK
      w:window_dict: 0
      OK
      w:curly_window_var: 1
      OK
      w:curly_window_var: 0
      OK
      b:buffer_var: 1
      OK
      b:buffer_var: 0
      OK
      b:buffer_list: 1
      OK
      b:buffer_list: 0
      OK
      b:buffer_dict: 1
      OK
      b:buffer_dict: 0
      OK
      b:curly_buffer_var: 1
      OK
      b:curly_buffer_var: 0
      OK
      s:script_var: 1
      OK
      s:script_var: 0
      OK
      s:script_list: 1
      OK
      s:script_list: 0
      OK
      s:script_dict: 1
      OK
      s:script_dict: 0
      OK
      s:curly_script_var: 1
      OK
      s:curly_script_var: 0
      OK
      *s:my_script_func: 1
      OK
      *s:my_script_func: 0
      OK
      v:version: 1
      OK
      v:non_exists_var: 0
      OK
      a:func_arg: 1
      OK
      a:non_exists_arg: 0
      OK
      a:1: 1
      OK
      a:2: 0
      OK
       g:footest#x = 1
         footest#F() 0
      UndefFun() 0]])

  end)
end)
