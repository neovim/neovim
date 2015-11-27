-- Test for option autocommand

local helpers = require('test.functional.helpers')
local feed, source = helpers.feed, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('autocmd_option', function()
  setup(clear)

  it('is working', function()
    execute('so small.vim')

    source([[
      fu! AutoCommand(match)
        let c=g:testcase
        let item=remove(g:options, 0)
        let c.=printf("Expected: Name: <%s>, Oldval: <%s>, NewVal: <%s>, Scope: <%s>\n",
                      \item[0], item[1], item[2], item[3])
        let c.=printf("Autocmd Option: <%s>,", a:match)
        let c.=printf(" OldVal: <%s>,", v:option_old)
        let c.=printf(" NewVal: <%s>,", v:option_new)
        let c.=printf(" Scope: <%s>\n", v:option_type)
        call setreg('r', printf("%s\n%s", getreg('r'), c))
      endfu
    ]])

    execute('au OptionSet * :call AutoCommand(expand("<amatch>"))')

    source([=[
      let g:testcase="1: Setting number option\n"
      let g:options=[['number', 0, 1, 'global']]
      set nu
      let g:testcase="2: Setting local number option\n"
      let g:options=[['number', 1, 0, 'local']]
      setlocal nonu
      let g:testcase="3: Setting global number option\n"
      let g:options=[['number', 1, 0, 'global']]
      setglobal nonu
      let g:testcase="4: Setting local autoindent option\n"
      let g:options=[['autoindent', 0, 1, 'local']]
      setlocal ai
      let g:testcase="5: Setting global autoindent option\n"
      let g:options=[['autoindent', 0, 1, 'global']]
      setglobal ai
      let g:testcase="6: Setting global autoindent option\n"
      let g:options=[['autoindent', 1, 0, 'global']]
      set ai!
    ]=])

    -- Should not print anything, use :noa.
    source([=[
      noa :set nonu
      let g:testcase="7: Setting several global list and number option\n"
      let g:options=[['list', 0, 1, 'global'], ['number', 0, 1, 'global']]
      set list nu
      noa set nolist nonu
      let g:testcase="8: Setting global acd\n"
      let g:options=[['autochdir', 0, 1, 'global']]
      setlocal acd
      let g:testcase="9: Setting global autoread\n"
      let g:options=[['autoread', 1, 0, 'global']]
      set noar
      let g:testcase="10: Setting local autoread\n"
      let g:options=[['autoread', 0, 1, 'local']]
      setlocal ar
      let g:testcase="11: Setting global autoread\n"
      let g:options=[['autoread', 0, 1, 'global']]
      setglobal invar
      let g:testcase="12: Setting option backspace through :let\n"
      let g:options=[['backspace', 'indent,eol,start', '', 'global']]
      let &bs=""
      let g:testcase="13: Setting option backspace through setbufvar()\n"
      let g:options=[['backup', '', '1', 'local']]
    ]=])

    -- Try twice, first time, shouldn't trigger because option name is invalid, second time, it should trigger.
    execute('call setbufvar(1, "&l:bk", 1)')
    -- Should trigger, use correct option name.
    execute('call setbufvar(1, "&backup", 1)')
    -- Write register now
    execute('$put! r')

    -- Remove the first and last blank lines.
    feed('ggddGdd')

    -- Assert buffer contents.
    expect([=[
      1: Setting number option
      Expected: Name: <number>, Oldval: <0>, NewVal: <1>, Scope: <global>
      Autocmd Option: <number>, OldVal: <0>, NewVal: <1>, Scope: <global>
      
      2: Setting local number option
      Expected: Name: <number>, Oldval: <1>, NewVal: <0>, Scope: <local>
      Autocmd Option: <number>, OldVal: <1>, NewVal: <0>, Scope: <local>
      
      3: Setting global number option
      Expected: Name: <number>, Oldval: <1>, NewVal: <0>, Scope: <global>
      Autocmd Option: <number>, OldVal: <1>, NewVal: <0>, Scope: <global>
      
      4: Setting local autoindent option
      Expected: Name: <autoindent>, Oldval: <0>, NewVal: <1>, Scope: <local>
      Autocmd Option: <autoindent>, OldVal: <0>, NewVal: <1>, Scope: <local>
      
      5: Setting global autoindent option
      Expected: Name: <autoindent>, Oldval: <0>, NewVal: <1>, Scope: <global>
      Autocmd Option: <autoindent>, OldVal: <0>, NewVal: <1>, Scope: <global>
      
      6: Setting global autoindent option
      Expected: Name: <autoindent>, Oldval: <1>, NewVal: <0>, Scope: <global>
      Autocmd Option: <autoindent>, OldVal: <1>, NewVal: <0>, Scope: <global>
      
      7: Setting several global list and number option
      Expected: Name: <list>, Oldval: <0>, NewVal: <1>, Scope: <global>
      Autocmd Option: <list>, OldVal: <0>, NewVal: <1>, Scope: <global>
      
      7: Setting several global list and number option
      Expected: Name: <number>, Oldval: <0>, NewVal: <1>, Scope: <global>
      Autocmd Option: <number>, OldVal: <0>, NewVal: <1>, Scope: <global>
      
      8: Setting global acd
      Expected: Name: <autochdir>, Oldval: <0>, NewVal: <1>, Scope: <global>
      Autocmd Option: <autochdir>, OldVal: <0>, NewVal: <1>, Scope: <local>
      
      9: Setting global autoread
      Expected: Name: <autoread>, Oldval: <1>, NewVal: <0>, Scope: <global>
      Autocmd Option: <autoread>, OldVal: <1>, NewVal: <0>, Scope: <global>
      
      10: Setting local autoread
      Expected: Name: <autoread>, Oldval: <0>, NewVal: <1>, Scope: <local>
      Autocmd Option: <autoread>, OldVal: <0>, NewVal: <1>, Scope: <local>
      
      11: Setting global autoread
      Expected: Name: <autoread>, Oldval: <0>, NewVal: <1>, Scope: <global>
      Autocmd Option: <autoread>, OldVal: <0>, NewVal: <1>, Scope: <global>
      
      12: Setting option backspace through :let
      Expected: Name: <backspace>, Oldval: <indent,eol,start>, NewVal: <>, Scope: <global>
      Autocmd Option: <backspace>, OldVal: <indent,eol,start>, NewVal: <>, Scope: <global>
      
      13: Setting option backspace through setbufvar()
      Expected: Name: <backup>, Oldval: <>, NewVal: <1>, Scope: <local>
      Autocmd Option: <backup>, OldVal: <0>, NewVal: <1>, Scope: <local>]=])
  end)
end)
