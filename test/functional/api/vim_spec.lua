local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local NIL = helpers.NIL
local clear, nvim, eq, neq = helpers.clear, helpers.nvim, helpers.eq, helpers.neq
local ok, nvim_async, feed = helpers.ok, helpers.nvim_async, helpers.feed
local os_name = helpers.os_name
local meths = helpers.meths
local funcs = helpers.funcs
local request = helpers.request
local meth_pcall = helpers.meth_pcall
local command = helpers.command

describe('api', function()
  before_each(clear)

  describe('nvim_command', function()
    it('works', function()
      local fname = helpers.tmpname()
      nvim('command', 'new')
      nvim('command', 'edit '..fname)
      nvim('command', 'normal itesting\napi')
      nvim('command', 'w')
      local f = io.open(fname)
      ok(f ~= nil)
      if os_name() == 'windows' then
        eq('testing\r\napi\r\n', f:read('*a'))
      else
        eq('testing\napi\n', f:read('*a'))
      end
      f:close()
      os.remove(fname)
    end)

    it("VimL error: fails (VimL error), does NOT update v:errmsg", function()
      -- Most API methods return generic errors (or no error) if a VimL
      -- expression fails; nvim_command returns the VimL error details.
      local status, rv = pcall(nvim, "command", "bogus_command")
      eq(false, status)                       -- nvim_command() failed.
      eq("E492:", string.match(rv, "E%d*:"))  -- VimL error was returned.
      eq("", nvim("eval", "v:errmsg"))        -- v:errmsg was not updated.
    end)
  end)

  describe('nvim_eval', function()
    it('works', function()
      nvim('command', 'let g:v1 = "a"')
      nvim('command', 'let g:v2 = [1, 2, {"v3": 3}]')
      eq({v1 = 'a', v2 = { 1, 2, { v3 = 3 } } }, nvim('eval', 'g:'))
    end)

    it('handles NULL-initialized strings correctly', function()
      eq(1, nvim('eval',"matcharg(1) == ['', '']"))
      eq({'', ''}, nvim('eval','matcharg(1)'))
    end)

    it('works under deprecated name', function()
      eq(2, request("vim_eval", "1+1"))
    end)

    it("VimL error: fails (generic error), does NOT update v:errmsg", function()
      local status, rv = pcall(nvim, "eval", "bogus expression")
      eq(false, status)                 -- nvim_eval() failed.
      ok(nil ~= string.find(rv, "Failed to evaluate expression"))
      eq("", nvim("eval", "v:errmsg"))  -- v:errmsg was not updated.
    end)
  end)

  describe('nvim_call_function', function()
    it('works', function()
      nvim('call_function', 'setqflist', { { { filename = 'something', lnum = 17 } }, 'r' })
      eq(17, nvim('call_function', 'getqflist', {})[1].lnum)
      eq(17, nvim('call_function', 'eval', {17}))
      eq('foo', nvim('call_function', 'simplify', {'this/./is//redundant/../../../foo'}))
    end)

    it("VimL error: fails (generic error), does NOT update v:errmsg", function()
      local status, rv = pcall(nvim, "call_function", "bogus function", {"arg1"})
      eq(false, status)                 -- nvim_call_function() failed.
      ok(nil ~= string.find(rv, "Error calling function"))
      eq("", nvim("eval", "v:errmsg"))  -- v:errmsg was not updated.
    end)
  end)

  describe('nvim_execute_lua', function()
    it('works', function()
      meths.execute_lua('vim.api.nvim_set_var("test", 3)', {})
      eq(3, meths.get_var('test'))

      eq(17, meths.execute_lua('a, b = ...\nreturn a + b', {10,7}))

      eq(NIL, meths.execute_lua('function xx(a,b)\nreturn a..b\nend',{}))
      eq("xy", meths.execute_lua('return xx(...)', {'x','y'}))
    end)

    it('reports errors', function()
      eq({false, 'Error loading lua: [string "<nvim>"]:1: '..
                 "'=' expected near '+'"},
         meth_pcall(meths.execute_lua, 'a+*b', {}))

      eq({false, 'Error loading lua: [string "<nvim>"]:1: '..
                 "unexpected symbol near '1'"},
         meth_pcall(meths.execute_lua, '1+2', {}))

      eq({false, 'Error loading lua: [string "<nvim>"]:1: '..
                 "unexpected symbol"},
         meth_pcall(meths.execute_lua, 'aa=bb\0', {}))

      eq({false, 'Error executing lua: [string "<nvim>"]:1: '..
                 "attempt to call global 'bork' (a nil value)"},
         meth_pcall(meths.execute_lua, 'bork()', {}))
    end)
  end)

  describe('nvim_input', function()
    it("VimL error: does NOT fail, updates v:errmsg", function()
      local status, _ = pcall(nvim, "input", ":call bogus_fn()<CR>")
      local v_errnum = string.match(nvim("eval", "v:errmsg"), "E%d*:")
      eq(true, status)        -- nvim_input() did not fail.
      eq("E117:", v_errnum)   -- v:errmsg was updated.
    end)
  end)

  describe('nvim_strwidth', function()
    it('works', function()
      eq(3, nvim('strwidth', 'abc'))
      -- 6 + (neovim)
      -- 19 * 2 (each japanese character occupies two cells)
      eq(44, nvim('strwidth', 'neovimのデザインかなりまともなのになってる。'))
    end)

    it('cannot handle NULs', function()
      eq(0, nvim('strwidth', '\0abc'))
    end)
  end)

  describe('nvim_get_current_line, nvim_set_current_line', function()
    it('works', function()
      eq('', nvim('get_current_line'))
      nvim('set_current_line', 'abc')
      eq('abc', nvim('get_current_line'))
    end)
  end)

  describe('nvim_get_var, nvim_set_var, nvim_del_var', function()
    it('works', function()
      nvim('set_var', 'lua', {1, 2, {['3'] = 1}})
      eq({1, 2, {['3'] = 1}}, nvim('get_var', 'lua'))
      eq({1, 2, {['3'] = 1}}, nvim('eval', 'g:lua'))
      eq(1, funcs.exists('g:lua'))
      meths.del_var('lua')
      eq(0, funcs.exists('g:lua'))
      eq({false, 'Key does not exist: lua'}, meth_pcall(meths.del_var, 'lua'))
      meths.set_var('lua', 1)
      command('lockvar lua')
      eq({false, 'Key is locked: lua'}, meth_pcall(meths.del_var, 'lua'))
      eq({false, 'Key is locked: lua'}, meth_pcall(meths.set_var, 'lua', 1))
    end)

    it('vim_set_var returns the old value', function()
      local val1 = {1, 2, {['3'] = 1}}
      local val2 = {4, 7}
      eq(NIL, request('vim_set_var', 'lua', val1))
      eq(val1, request('vim_set_var', 'lua', val2))
    end)

    it('vim_del_var returns the old value', function()
      local val1 = {1, 2, {['3'] = 1}}
      local val2 = {4, 7}
      eq(NIL,  request('vim_set_var', 'lua', val1))
      eq(val1, request('vim_set_var', 'lua', val2))
      eq(val2, request('vim_del_var', 'lua'))
    end)

    it('truncates values with NULs in them', function()
      nvim('set_var', 'xxx', 'ab\0cd')
      eq('ab', nvim('get_var', 'xxx'))
    end)
  end)

  describe('nvim_get_option, nvim_set_option', function()
    it('works', function()
      ok(nvim('get_option', 'equalalways'))
      nvim('set_option', 'equalalways', false)
      ok(not nvim('get_option', 'equalalways'))
    end)

    it('works to get global value of local options', function()
      eq(false, nvim('get_option', 'lisp'))
      eq(8, nvim('get_option', 'shiftwidth'))
    end)

    it('works to set global value of local options', function()
      nvim('set_option', 'lisp', true)
      eq(true, nvim('get_option', 'lisp'))
      eq(false, helpers.curbuf('get_option', 'lisp'))
      eq(nil, nvim('command_output', 'setglobal lisp?'):match('nolisp'))
      eq('nolisp', nvim('command_output', 'setlocal lisp?'):match('nolisp'))
      nvim('set_option', 'shiftwidth', 20)
      eq('20', nvim('command_output', 'setglobal shiftwidth?'):match('%d+'))
      eq('8', nvim('command_output', 'setlocal shiftwidth?'):match('%d+'))
    end)

    it('most window-local options have no global value', function()
      local status, err = pcall(nvim, 'get_option', 'foldcolumn')
      eq(false, status)
      ok(err:match('Invalid option name') ~= nil)
    end)
  end)

  describe('nvim_{get,set}_current_buf, nvim_list_bufs', function()
    it('works', function()
      eq(1, #nvim('list_bufs'))
      eq(nvim('list_bufs')[1], nvim('get_current_buf'))
      nvim('command', 'new')
      eq(2, #nvim('list_bufs'))
      eq(nvim('list_bufs')[2], nvim('get_current_buf'))
      nvim('set_current_buf', nvim('list_bufs')[1])
      eq(nvim('list_bufs')[1], nvim('get_current_buf'))
    end)
  end)

  describe('nvim_{get,set}_current_win, nvim_list_wins', function()
    it('works', function()
      eq(1, #nvim('list_wins'))
      eq(nvim('list_wins')[1], nvim('get_current_win'))
      nvim('command', 'vsplit')
      nvim('command', 'split')
      eq(3, #nvim('list_wins'))
      eq(nvim('list_wins')[1], nvim('get_current_win'))
      nvim('set_current_win', nvim('list_wins')[2])
      eq(nvim('list_wins')[2], nvim('get_current_win'))
    end)
  end)

  describe('nvim_{get,set}_current_tabpage, nvim_list_tabpages', function()
    it('works', function()
      eq(1, #nvim('list_tabpages'))
      eq(nvim('list_tabpages')[1], nvim('get_current_tabpage'))
      nvim('command', 'tabnew')
      eq(2, #nvim('list_tabpages'))
      eq(2, #nvim('list_wins'))
      eq(nvim('list_wins')[2], nvim('get_current_win'))
      eq(nvim('list_tabpages')[2], nvim('get_current_tabpage'))
      nvim('set_current_win', nvim('list_wins')[1])
      -- Switching window also switches tabpages if necessary
      eq(nvim('list_tabpages')[1], nvim('get_current_tabpage'))
      eq(nvim('list_wins')[1], nvim('get_current_win'))
      nvim('set_current_tabpage', nvim('list_tabpages')[2])
      eq(nvim('list_tabpages')[2], nvim('get_current_tabpage'))
      eq(nvim('list_wins')[2], nvim('get_current_win'))
    end)
  end)

  describe('nvim_get_mode', function()
    it("during normal-mode `g` returns blocking=true", function()
      nvim("input", "o")                -- add a line
      eq({mode='i', blocking=false}, nvim("get_mode"))
      nvim("input", [[<C-\><C-N>]])
      eq(2, nvim("eval", "line('.')"))
      eq({mode='n', blocking=false}, nvim("get_mode"))

      nvim("input", "g")
      eq({mode='n', blocking=true}, nvim("get_mode"))

      nvim("input", "k")                -- complete the operator
      eq(1, nvim("eval", "line('.')"))  -- verify the completed operator
      eq({mode='n', blocking=false}, nvim("get_mode"))
    end)

    it("returns the correct result multiple consecutive times", function()
      for _ = 1,5 do
        eq({mode='n', blocking=false}, nvim("get_mode"))
      end
      nvim("input", "g")
      for _ = 1,4 do
        eq({mode='n', blocking=true}, nvim("get_mode"))
      end
      nvim("input", "g")
      for _ = 1,7 do
        eq({mode='n', blocking=false}, nvim("get_mode"))
      end
    end)

    it("during normal-mode CTRL-W, returns blocking=true", function()
      nvim("input", "<C-W>")
      eq({mode='n', blocking=true}, nvim("get_mode"))

      nvim("input", "s")                  -- complete the operator
      eq(2, nvim("eval", "winnr('$')"))   -- verify the completed operator
      eq({mode='n', blocking=false}, nvim("get_mode"))
    end)

    it("during press-enter prompt returns blocking=true", function()
      eq({mode='n', blocking=false}, nvim("get_mode"))
      command("echom 'msg1'")
      command("echom 'msg2'")
      command("echom 'msg3'")
      command("echom 'msg4'")
      command("echom 'msg5'")
      eq({mode='n', blocking=false}, nvim("get_mode"))
      nvim("input", ":messages<CR>")
      eq({mode='r', blocking=true}, nvim("get_mode"))
    end)

    it("during getchar() returns blocking=false", function()
      nvim("input", ":let g:test_input = nr2char(getchar())<CR>")
      -- Events are enabled during getchar(), RPC calls are *not* blocked. #5384
      eq({mode='n', blocking=false}, nvim("get_mode"))
      eq(0, nvim("eval", "exists('g:test_input')"))
      nvim("input", "J")
      eq("J", nvim("eval", "g:test_input"))
      eq({mode='n', blocking=false}, nvim("get_mode"))
    end)

    -- TODO: bug #6247#issuecomment-286403810
    it("batched with input", function()
      eq({mode='n', blocking=false}, nvim("get_mode"))
      command("echom 'msg1'")
      command("echom 'msg2'")
      command("echom 'msg3'")
      command("echom 'msg4'")
      command("echom 'msg5'")

      local req = {
        {'nvim_get_mode', {}},
        {'nvim_input',    {':messages<CR>'}},
        {'nvim_get_mode', {}},
        {'nvim_eval',     {'1'}},
      }
      eq({ { {mode='n', blocking=false},
             13,
             {mode='n', blocking=false},  -- TODO: should be blocked=true ?
             1 },
           NIL}, meths.call_atomic(req))
      eq({mode='r', blocking=true}, nvim("get_mode"))
    end)
    it("during insert-mode map-pending, returns blocking=true #6166", function()
      command("inoremap xx foo")
      nvim("input", "ix")
      eq({mode='i', blocking=true}, nvim("get_mode"))
    end)
    it("during normal-mode gU, returns blocking=false #6166", function()
      nvim("input", "gu")
      eq({mode='no', blocking=false}, nvim("get_mode"))
    end)
  end)

  describe('RPC (K_EVENT) #6166', function()
    it('does not complete ("interrupt") normal-mode operator-pending', function()
      helpers.insert([[
        FIRST LINE
        SECOND LINE]])
      nvim('input', 'gg')
      nvim('input', 'gu')
      -- Make any RPC request (can be non-async: op-pending does not block).
      nvim('get_current_buf')
      -- Buffer should not change.
      helpers.expect([[
        FIRST LINE
        SECOND LINE]])
      -- Now send input to complete the operator.
      nvim('input', 'j')
      helpers.expect([[
        first line
        second line]])
    end)

    it('does not complete ("interrupt") `d` #3732', function()
      local screen = Screen.new(20, 4)
      screen:attach()
      command('set listchars=eol:$')
      command('set list')
      feed('ia<cr>b<cr>c<cr><Esc>kkk')
      feed('d')
      -- Make any RPC request (can be non-async: op-pending does not block).
      nvim('get_current_buf')
      screen:expect([[
       ^a$                  |
       b$                  |
       c$                  |
                           |
      ]])
    end)

    it('does not complete ("interrupt") normal-mode map-pending', function()
      command("nnoremap dd :let g:foo='it worked...'<CR>")
      helpers.insert([[
        FIRST LINE
        SECOND LINE]])
      nvim('input', 'gg')
      nvim('input', 'd')
      -- Make any RPC request (must be async, because map-pending blocks).
      nvim('get_api_info')
      -- Send input to complete the mapping.
      nvim('input', 'd')
      helpers.expect([[
        FIRST LINE
        SECOND LINE]])
      eq('it worked...', helpers.eval('g:foo'))
    end)
    it('does not complete ("interrupt") insert-mode map-pending', function()
      command('inoremap xx foo')
      command('set timeoutlen=9999')
      helpers.insert([[
        FIRST LINE
        SECOND LINE]])
      nvim('input', 'ix')
      -- Make any RPC request (must be async, because map-pending blocks).
      nvim('get_api_info')
      -- Send input to complete the mapping.
      nvim('input', 'x')
      helpers.expect([[
        FIRST LINE
        SECOND LINfooE]])
    end)
  end)

  describe('nvim_replace_termcodes', function()
    it('escapes K_SPECIAL as K_SPECIAL KS_SPECIAL KE_FILLER', function()
      eq('\128\254X', helpers.nvim('replace_termcodes', '\128', true, true, true))
    end)

    it('leaves non-K_SPECIAL string unchanged', function()
      eq('abc', helpers.nvim('replace_termcodes', 'abc', true, true, true))
    end)

    it('converts <expressions>', function()
      eq('\\', helpers.nvim('replace_termcodes', '<Leader>', true, true, true))
    end)

    it('converts <LeftMouse> to K_SPECIAL KS_EXTRA KE_LEFTMOUSE', function()
      -- K_SPECIAL KS_EXTRA KE_LEFTMOUSE
      -- 0x80      0xfd     0x2c
      -- 128       253      44
      eq('\128\253\44', helpers.nvim('replace_termcodes',
                                     '<LeftMouse>', true, true, true))
    end)

    it('converts keycodes', function()
      eq('\nx\27x\rx<x', helpers.nvim('replace_termcodes',
         '<NL>x<Esc>x<CR>x<lt>x', true, true, true))
    end)

    it('does not convert keycodes if special=false', function()
      eq('<NL>x<Esc>x<CR>x<lt>x', helpers.nvim('replace_termcodes',
         '<NL>x<Esc>x<CR>x<lt>x', true, true, false))
    end)

    it('does not crash when transforming an empty string', function()
      -- Actually does not test anything, because current code will use NULL for
      -- an empty string.
      --
      -- Problem here is that if String argument has .data in allocated memory
      -- then `return str` in vim_replace_termcodes body will make Neovim free
      -- `str.data` twice: once when freeing arguments, then when freeing return
      -- value.
      eq('', meths.replace_termcodes('', true, true, true))
    end)
  end)

  describe('nvim_feedkeys', function()
    it('CSI escaping', function()
      local function on_setup()
        -- notice the special char(…) \xe2\80\xa6
        nvim('feedkeys', ':let x1="…"\n', '', true)

        -- Both nvim_replace_termcodes and nvim_feedkeys escape \x80
        local inp = helpers.nvim('replace_termcodes', ':let x2="…"<CR>', true, true, true)
        nvim('feedkeys', inp, '', true)   -- escape_csi=true

        -- nvim_feedkeys with CSI escaping disabled
        inp = helpers.nvim('replace_termcodes', ':let x3="…"<CR>', true, true, true)
        nvim('feedkeys', inp, '', false)  -- escape_csi=false

        helpers.stop()
      end

      -- spin the loop a bit
      helpers.run(nil, nil, on_setup)

      eq(nvim('get_var', 'x1'), '…')
      -- Because of the double escaping this is neq
      neq(nvim('get_var', 'x2'), '…')
      eq(nvim('get_var', 'x3'), '…')
    end)
  end)

  describe('nvim_err_write', function()
    local screen

    before_each(function()
      clear()
      screen = Screen.new(40, 8)
      screen:attach()
      screen:set_default_attr_ids({
        [0] = {bold=true, foreground=Screen.colors.Blue},
        [1] = {foreground = Screen.colors.White, background = Screen.colors.Red},
        [2] = {bold = true, foreground = Screen.colors.SeaGreen}
      })
    end)

    it('can show one line', function()
      nvim_async('err_write', 'has bork\n')
      screen:expect([[
        ^                                        |
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {1:has bork}                                |
      ]])
    end)

    it('shows return prompt when more than &cmdheight lines', function()
      nvim_async('err_write', 'something happened\nvery bad\n')
      screen:expect([[
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {1:something happened}                      |
        {1:very bad}                                |
        {2:Press ENTER or type command to continue}^ |
      ]])
    end)

    it('shows return prompt after all lines are shown', function()
      nvim_async('err_write', 'FAILURE\nERROR\nEXCEPTION\nTRACEBACK\n')
      screen:expect([[
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {1:FAILURE}                                 |
        {1:ERROR}                                   |
        {1:EXCEPTION}                               |
        {1:TRACEBACK}                               |
        {2:Press ENTER or type command to continue}^ |
      ]])
    end)

    it('handles multiple calls', function()
      -- without linebreak text is joined to one line
      nvim_async('err_write', 'very ')
      nvim_async('err_write', 'fail\n')
      screen:expect([[
        ^                                        |
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {1:very fail}                               |
      ]])
      helpers.wait()

      -- shows up to &cmdheight lines
      nvim_async('err_write', 'more fail\ntoo fail\n')
      screen:expect([[
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {1:more fail}                               |
        {1:too fail}                                |
        {2:Press ENTER or type command to continue}^ |
      ]])
      feed('<cr>')  -- exit the press ENTER screen
    end)
  end)

  describe('nvim_call_atomic', function()
    it('works', function()
      meths.buf_set_lines(0, 0, -1, true, {'first'})
      local req = {
        {'nvim_get_current_line', {}},
        {'nvim_set_current_line', {'second'}},
      }
      eq({{'first', NIL}, NIL}, meths.call_atomic(req))
      eq({'second'}, meths.buf_get_lines(0, 0, -1, true))
    end)

    it('allows multiple return values', function()
      local req = {
        {'nvim_set_var', {'avar', true}},
        {'nvim_set_var', {'bvar', 'string'}},
        {'nvim_get_var', {'avar'}},
        {'nvim_get_var', {'bvar'}},
      }
      eq({{NIL, NIL, true, 'string'}, NIL}, meths.call_atomic(req))
    end)

    it('is aborted by errors in call', function()
      local error_types = meths.get_api_info()[2].error_types
      local req = {
        {'nvim_set_var', {'one', 1}},
        {'nvim_buf_set_lines', {}},
        {'nvim_set_var', {'two', 2}},
      }
      eq({{NIL}, {1, error_types.Exception.id,
                  'Wrong number of arguments: expecting 5 but got 0'}},
         meths.call_atomic(req))
      eq(1, meths.get_var('one'))
      eq(false, pcall(meths.get_var, 'two'))

      -- still returns all previous successful calls
      req = {
        {'nvim_set_var', {'avar', 5}},
        {'nvim_set_var', {'bvar', 'string'}},
        {'nvim_get_var', {'avar'}},
        {'nvim_buf_get_lines', {0, 10, 20, true}},
        {'nvim_get_var', {'bvar'}},
      }
      eq({{NIL, NIL, 5}, {3, error_types.Validation.id, 'Index out of bounds'}},
        meths.call_atomic(req))

      req = {
        {'i_am_not_a_method', {'xx'}},
        {'nvim_set_var', {'avar', 10}},
      }
      eq({{}, {0, error_types.Exception.id, 'Invalid method name'}},
         meths.call_atomic(req))
      eq(5, meths.get_var('avar'))
    end)

    it('throws error on malformed arguments', function()
      local req = {
        {'nvim_set_var', {'avar', 1}},
        {'nvim_set_var'},
        {'nvim_set_var', {'avar', 2}},
      }
      local status, err = pcall(meths.call_atomic, req)
      eq(false, status)
      ok(err:match(' All items in calls array must be arrays of size 2') ~= nil)
      -- call before was done, but not after
      eq(1, meths.get_var('avar'))

      req = {
        { 'nvim_set_var', { 'bvar', { 2, 3 } } },
        12,
      }
      status, err = pcall(meths.call_atomic, req)
      eq(false, status)
      ok(err:match('All items in calls array must be arrays') ~= nil)
      eq({2,3}, meths.get_var('bvar'))

      req = {
        {'nvim_set_current_line', 'little line'},
        {'nvim_set_var', {'avar', 3}},
      }
      status, err = pcall(meths.call_atomic, req)
      eq(false, status)
      ok(err:match('Args must be Array') ~= nil)
      -- call before was done, but not after
      eq(1, meths.get_var('avar'))
      eq({''}, meths.buf_get_lines(0, 0, -1, true))
    end)
  end)

  describe('list_runtime_paths', function()
    it('returns nothing with empty &runtimepath', function()
      meths.set_option('runtimepath', '')
      eq({}, meths.list_runtime_paths())
    end)
    it('returns single runtimepath', function()
      meths.set_option('runtimepath', 'a')
      eq({'a'}, meths.list_runtime_paths())
    end)
    it('returns two runtimepaths', function()
      meths.set_option('runtimepath', 'a,b')
      eq({'a', 'b'}, meths.list_runtime_paths())
    end)
    it('returns empty strings when appropriate', function()
      meths.set_option('runtimepath', 'a,,b')
      eq({'a', '', 'b'}, meths.list_runtime_paths())
      meths.set_option('runtimepath', ',a,b')
      eq({'', 'a', 'b'}, meths.list_runtime_paths())
      meths.set_option('runtimepath', 'a,b,')
      eq({'a', 'b', ''}, meths.list_runtime_paths())
    end)
    it('truncates too long paths', function()
      local long_path = ('/a'):rep(8192)
      meths.set_option('runtimepath', long_path)
      local paths_list = meths.list_runtime_paths()
      neq({long_path}, paths_list)
      eq({long_path:sub(1, #(paths_list[1]))}, paths_list)
    end)
  end)

  it('can throw exceptions', function()
    local status, err = pcall(nvim, 'get_option', 'invalid-option')
    eq(false, status)
    ok(err:match('Invalid option name') ~= nil)
  end)

  it('does not truncate error message <1 MB #5984', function()
    local very_long_name = 'A'..('x'):rep(10000)..'Z'
    local status, err = pcall(nvim, 'get_option', very_long_name)
    eq(false, status)
    eq(very_long_name, err:match('Ax+Z?'))
  end)

  it("does not leak memory on incorrect argument types", function()
    local status, err = pcall(nvim, 'set_current_dir',{'not', 'a', 'dir'})
    eq(false, status)
    ok(err:match(': Wrong type for argument 1, expecting String') ~= nil)
  end)

end)
