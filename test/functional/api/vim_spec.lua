local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local global_helpers = require('test.helpers')

local NIL = helpers.NIL
local clear, nvim, eq, neq = helpers.clear, helpers.nvim, helpers.eq, helpers.neq
local ok, nvim_async, feed = helpers.ok, helpers.nvim_async, helpers.feed
local os_name = helpers.os_name
local meths = helpers.meths
local funcs = helpers.funcs
local request = helpers.request
local meth_pcall = helpers.meth_pcall
local command = helpers.command

local REMOVE_THIS = global_helpers.REMOVE_THIS
local intchar2lua = global_helpers.intchar2lua
local format_string = global_helpers.format_string
local mergedicts_copy = global_helpers.mergedicts_copy

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

  describe('nvim_parse_expression', function()
    local function simplify_east_api_node(line, east_api_node)
      if east_api_node == NIL then
        return nil
      end
      if east_api_node.children then
        for k, v in pairs(east_api_node.children) do
          east_api_node.children[k] = simplify_east_api_node(line, v)
        end
      end
      local typ = east_api_node.type
      if typ == 'Register' then
        typ = typ .. ('(name=%s)'):format(
          tostring(intchar2lua(east_api_node.name)))
        east_api_node.name = nil
      elseif typ == 'PlainIdentifier' then
        typ = typ .. ('(scope=%s,ident=%s)'):format(
          tostring(intchar2lua(east_api_node.scope)), east_api_node.ident)
        east_api_node.scope = nil
        east_api_node.ident = nil
      elseif typ == 'PlainKey' then
        typ = typ .. ('(key=%s)'):format(east_api_node.ident)
        east_api_node.ident = nil
      elseif typ == 'Comparison' then
        typ = typ .. ('(type=%s,inv=%u,ccs=%s)'):format(
          east_api_node.cmp_type, east_api_node.invert and 1 or 0,
          east_api_node.ccs_strategy)
        east_api_node.ccs_strategy = nil
        east_api_node.cmp_type = nil
        east_api_node.invert = nil
      elseif typ == 'Integer' then
        typ = typ .. ('(val=%u)'):format(east_api_node.ivalue)
        east_api_node.ivalue = nil
      elseif typ == 'Float' then
        typ = typ .. ('(val=%e)'):format(east_api_node.fvalue)
        east_api_node.fvalue = nil
      elseif typ == 'SingleQuotedString' or typ == 'DoubleQuotedString' then
        typ = format_string('%s(val=%q)', typ, east_api_node.svalue)
        east_api_node.svalue = nil
      elseif typ == 'Option' then
        typ = ('%s(scope=%s,ident=%s)'):format(
          typ,
          tostring(intchar2lua(east_api_node.scope)),
          east_api_node.ident)
        east_api_node.ident = nil
        east_api_node.scope = nil
      elseif typ == 'Environment' then
        typ = ('%s(ident=%s)'):format(typ, east_api_node.ident)
        east_api_node.ident = nil
      end
      typ = ('%s:%u:%u:%s'):format(
        typ, east_api_node.start[1], east_api_node.start[2],
        line:sub(east_api_node.start[2] + 1,
                 east_api_node.start[2] + 1 + east_api_node.len - 1))
      assert(east_api_node.start[2] + east_api_node.len - 1 <= #line)
      for k, _ in pairs(east_api_node.start) do
        assert(({true, true})[k])
      end
      east_api_node.start = nil
      east_api_node.type = nil
      east_api_node.len = nil
      local can_simplify = true
      for _, _ in pairs(east_api_node) do
        if can_simplify then can_simplify = false end
      end
      if can_simplify then
        return typ
      else
        east_api_node[1] = typ
        return east_api_node
      end
    end
    local function simplify_east_api(line, east_api)
      if east_api.error then
        east_api.err = east_api.error
        east_api.error = nil
        east_api.err.msg = east_api.err.message
        east_api.err.message = nil
      end
      if east_api.ast then
        east_api.ast = {simplify_east_api_node(line, east_api.ast)}
      end
      if east_api.len == #line then
        east_api.len = nil
      end
      return east_api
    end
    local function simplify_east_hl(line, east_hl)
      for i, v in ipairs(east_hl) do
        east_hl[i] = ('%s:%u:%u:%s'):format(
          v[4],
          v[1],
          v[2],
          line:sub(v[2] + 1, v[3]))
      end
      return east_hl
    end
    local FLAGS_TO_STR = {
      [0] = "",
      [1] = "m",
      [2] = "E",
      [3] = "mE",
    }
    local function check_parsing(str, exp_ast, exp_highlighting_fs,
                                 nz_flags_exps)
      nz_flags_exps = nz_flags_exps or {}
      for _, flags in ipairs({0, 1, 2, 3}) do
        local err, msg = pcall(function()
          local east_api = meths.parse_expression(str, FLAGS_TO_STR[flags], true)
          local east_hl = east_api.highlight
          east_api.highlight = nil
          local ast = simplify_east_api(str, east_api)
          local hls = simplify_east_hl(str, east_hl)
          local exps = {
            ast = exp_ast,
            hl_fs = exp_highlighting_fs,
          }
          local add_exps = nz_flags_exps[flags]
          if not add_exps and flags == 3 then
            add_exps = nz_flags_exps[1] or nz_flags_exps[2]
          end
          if add_exps then
            if add_exps.ast then
              exps.ast = mergedicts_copy(exps.ast, add_exps.ast)
            end
            if add_exps.hl_fs then
              exps.hl_fs = mergedicts_copy(exps.hl_fs, add_exps.hl_fs)
            end
          end
          eq(exps.ast, ast)
          if exp_highlighting_fs then
            local exp_highlighting = {}
            local next_col = 0
            for i, h in ipairs(exps.hl_fs) do
              exp_highlighting[i], next_col = h(next_col)
            end
            eq(exp_highlighting, hls)
          end
        end)
        if not err then
          msg = format_string('Error while processing test (%r, %s):\n%s',
                              str, FLAGS_TO_STR[flags], msg)
          error(msg)
        end
      end
    end
    local function hl(group, str, shift)
      return function(next_col)
        local col = next_col + (shift or 0)
        return (('%s:%u:%u:%s'):format(
          'NVim' .. group,
          0,
          col,
          str)), (col + #str)
      end
    end
    it('works with + and @a', function()
      check_parsing('@a', {
        ast = {
          'Register(name=a):0:0:@a',
        },
      }, {
        hl('Register', '@a'),
      })
      check_parsing('+@a', {
        ast = {
          {
            'UnaryPlus:0:0:+',
            children = {
              'Register(name=a):0:1:@a',
            },
          },
        },
      }, {
        hl('UnaryPlus', '+'),
        hl('Register', '@a'),
      })
      check_parsing('@a+@b', {
        ast = {
          {
            'BinaryPlus:0:2:+',
            children = {
              'Register(name=a):0:0:@a',
              'Register(name=b):0:3:@b',
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('BinaryPlus', '+'),
        hl('Register', '@b'),
      })
      check_parsing('@a+@b+@c', {
        ast = {
          {
            'BinaryPlus:0:5:+',
            children = {
              {
                'BinaryPlus:0:2:+',
                children = {
                  'Register(name=a):0:0:@a',
                  'Register(name=b):0:3:@b',
                },
              },
              'Register(name=c):0:6:@c',
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('BinaryPlus', '+'),
        hl('Register', '@b'),
        hl('BinaryPlus', '+'),
        hl('Register', '@c'),
      })
      check_parsing('+@a+@b', {
        ast = {
          {
            'BinaryPlus:0:3:+',
            children = {
              {
                'UnaryPlus:0:0:+',
                children = {
                  'Register(name=a):0:1:@a',
                },
              },
              'Register(name=b):0:4:@b',
            },
          },
        },
      }, {
        hl('UnaryPlus', '+'),
        hl('Register', '@a'),
        hl('BinaryPlus', '+'),
        hl('Register', '@b'),
      })
      check_parsing('+@a++@b', {
        ast = {
          {
            'BinaryPlus:0:3:+',
            children = {
              {
                'UnaryPlus:0:0:+',
                children = {
                  'Register(name=a):0:1:@a',
                },
              },
              {
                'UnaryPlus:0:4:+',
                children = {
                  'Register(name=b):0:5:@b',
                },
              },
            },
          },
        },
      }, {
        hl('UnaryPlus', '+'),
        hl('Register', '@a'),
        hl('BinaryPlus', '+'),
        hl('UnaryPlus', '+'),
        hl('Register', '@b'),
      })
      check_parsing('@a@b', {
        ast = {
          {
            'OpMissing:0:2:',
            children = {
              'Register(name=a):0:0:@a',
              'Register(name=b):0:2:@b',
            },
          },
        },
        err = {
          arg = '@b',
          msg = 'E15: Missing operator: %.*s',
        },
      }, {
        hl('Register', '@a'),
        hl('InvalidRegister', '@b'),
      }, {
        [1] = {
          ast = {
            len = 2,
            err = REMOVE_THIS,
            ast = {
              'Register(name=a):0:0:@a'
            },
          },
          hl_fs = {
            [2] = REMOVE_THIS,
          },
        },
      })
      check_parsing(' @a \t @b', {
        ast = {
          {
            'OpMissing:0:3:',
            children = {
              'Register(name=a):0:0: @a',
              'Register(name=b):0:3: \t @b',
            },
          },
        },
        err = {
          arg = '@b',
          msg = 'E15: Missing operator: %.*s',
        },
      }, {
        hl('Register', '@a', 1),
        hl('InvalidSpacing', ' \t '),
        hl('Register', '@b'),
      }, {
        [1] = {
          ast = {
            len = 6,
            err = REMOVE_THIS,
            ast = {
              'Register(name=a):0:0: @a'
            },
          },
          hl_fs = {
            [2] = REMOVE_THIS,
            [3] = REMOVE_THIS,
          },
        },
      })
      check_parsing('+', {
        ast = {
          'UnaryPlus:0:0:+',
        },
        err = {
          arg = '',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
        hl('UnaryPlus', '+'),
      })
      check_parsing(' +', {
        ast = {
          'UnaryPlus:0:0: +',
        },
        err = {
          arg = '',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
        hl('UnaryPlus', '+', 1),
      })
      check_parsing('@a+  ', {
        ast = {
          {
            'BinaryPlus:0:2:+',
            children = {
              'Register(name=a):0:0:@a',
            },
          },
        },
        err = {
          arg = '',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
        hl('Register', '@a'),
        hl('BinaryPlus', '+'),
      })
    end)
    it('works with @a, + and parenthesis', function()
      check_parsing('(@a)', {
        ast = {
          {
            'Nested:0:0:(',
            children = {
              'Register(name=a):0:1:@a',
            },
          },
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('Register', '@a'),
        hl('NestingParenthesis', ')'),
      })
      check_parsing('()', {
        ast = {
          {
            'Nested:0:0:(',
            children = {
              'Missing:0:1:',
            },
          },
        },
        err = {
          arg = ')',
          msg = 'E15: Expected value, got parenthesis: %.*s',
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('InvalidNestingParenthesis', ')'),
      })
      check_parsing(')', {
        ast = {
          {
            'Nested:0:0:',
            children = {
              'Missing:0:0:',
            },
          },
        },
        err = {
          arg = ')',
          msg = 'E15: Expected value, got parenthesis: %.*s',
        },
      }, {
        hl('InvalidNestingParenthesis', ')'),
      })
      check_parsing('+)', {
        ast = {
          {
            'Nested:0:1:',
            children = {
              {
                'UnaryPlus:0:0:+',
                children = {
                  'Missing:0:1:',
                },
              },
            },
          },
        },
        err = {
          arg = ')',
          msg = 'E15: Expected value, got parenthesis: %.*s',
        },
      }, {
        hl('UnaryPlus', '+'),
        hl('InvalidNestingParenthesis', ')'),
      })
      check_parsing('+@a(@b)', {
        ast = {
          {
            'UnaryPlus:0:0:+',
            children = {
              {
                'Call:0:3:(',
                children = {
                  'Register(name=a):0:1:@a',
                  'Register(name=b):0:4:@b',
                },
              },
            },
          },
        },
      }, {
        hl('UnaryPlus', '+'),
        hl('Register', '@a'),
        hl('CallingParenthesis', '('),
        hl('Register', '@b'),
        hl('CallingParenthesis', ')'),
      })
      check_parsing('@a+@b(@c)', {
        ast = {
          {
            'BinaryPlus:0:2:+',
            children = {
              'Register(name=a):0:0:@a',
              {
                'Call:0:5:(',
                children = {
                  'Register(name=b):0:3:@b',
                  'Register(name=c):0:6:@c',
                },
              },
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('BinaryPlus', '+'),
        hl('Register', '@b'),
        hl('CallingParenthesis', '('),
        hl('Register', '@c'),
        hl('CallingParenthesis', ')'),
      })
      check_parsing('@a()', {
        ast = {
          {
            'Call:0:2:(',
            children = {
              'Register(name=a):0:0:@a',
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('CallingParenthesis', '('),
        hl('CallingParenthesis', ')'),
      })
      check_parsing('@a ()', {
        ast = {
          {
            'OpMissing:0:2:',
            children = {
              'Register(name=a):0:0:@a',
              {
                'Nested:0:2: (',
                children = {
                  'Missing:0:4:',
                },
              },
            },
          },
        },
        err = {
          arg = '()',
          msg = 'E15: Missing operator: %.*s',
        },
      }, {
        hl('Register', '@a'),
        hl('InvalidSpacing', ' '),
        hl('NestingParenthesis', '('),
        hl('InvalidNestingParenthesis', ')'),
      }, {
        [1] = {
          ast = {
            len = 3,
            err = REMOVE_THIS,
            ast = {
              'Register(name=a):0:0:@a',
            },
          },
          hl_fs = {
            [2] = REMOVE_THIS,
            [3] = REMOVE_THIS,
            [4] = REMOVE_THIS,
          },
        },
      })
      check_parsing('@a + (@b)', {
        ast = {
          {
            'BinaryPlus:0:2: +',
            children = {
              'Register(name=a):0:0:@a',
              {
                'Nested:0:4: (',
                children = {
                  'Register(name=b):0:6:@b',
                },
              },
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('BinaryPlus', '+', 1),
        hl('NestingParenthesis', '(', 1),
        hl('Register', '@b'),
        hl('NestingParenthesis', ')'),
      })
      check_parsing('@a + (+@b)', {
        ast = {
          {
            'BinaryPlus:0:2: +',
            children = {
              'Register(name=a):0:0:@a',
              {
                'Nested:0:4: (',
                children = {
                  {
                    'UnaryPlus:0:6:+',
                    children = {
                      'Register(name=b):0:7:@b',
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('BinaryPlus', '+', 1),
        hl('NestingParenthesis', '(', 1),
        hl('UnaryPlus', '+'),
        hl('Register', '@b'),
        hl('NestingParenthesis', ')'),
      })
      check_parsing('@a + (@b + @c)', {
        ast = {
          {
            'BinaryPlus:0:2: +',
            children = {
              'Register(name=a):0:0:@a',
              {
                'Nested:0:4: (',
                children = {
                  {
                    'BinaryPlus:0:8: +',
                    children = {
                      'Register(name=b):0:6:@b',
                      'Register(name=c):0:10: @c',
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('BinaryPlus', '+', 1),
        hl('NestingParenthesis', '(', 1),
        hl('Register', '@b'),
        hl('BinaryPlus', '+', 1),
        hl('Register', '@c', 1),
        hl('NestingParenthesis', ')'),
      })
      check_parsing('(@a)+@b', {
        ast = {
          {
            'BinaryPlus:0:4:+',
            children = {
              {
                'Nested:0:0:(',
                children = {
                  'Register(name=a):0:1:@a',
                },
              },
              'Register(name=b):0:5:@b',
            },
          },
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('Register', '@a'),
        hl('NestingParenthesis', ')'),
        hl('BinaryPlus', '+'),
        hl('Register', '@b'),
      })
      check_parsing('@a+(@b)(@c)', {
        --           01234567890
        ast = {
          {
            'BinaryPlus:0:2:+',
            children = {
              'Register(name=a):0:0:@a',
              {
                'Call:0:7:(',
                children = {
                  {
                    'Nested:0:3:(',
                    children = { 'Register(name=b):0:4:@b' },
                  },
                  'Register(name=c):0:8:@c',
                },
              },
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('BinaryPlus', '+'),
        hl('NestingParenthesis', '('),
        hl('Register', '@b'),
        hl('NestingParenthesis', ')'),
        hl('CallingParenthesis', '('),
        hl('Register', '@c'),
        hl('CallingParenthesis', ')'),
      })
      check_parsing('@a+((@b))(@c)', {
        --           01234567890123456890123456789
        --           0         1        2
        ast = {
          {
            'BinaryPlus:0:2:+',
            children = {
              'Register(name=a):0:0:@a',
              {
                'Call:0:9:(',
                children = {
                  {
                    'Nested:0:3:(',
                    children = {
                      {
                        'Nested:0:4:(',
                        children = { 'Register(name=b):0:5:@b' }
                      },
                    },
                  },
                  'Register(name=c):0:10:@c',
                },
              },
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('BinaryPlus', '+'),
        hl('NestingParenthesis', '('),
        hl('NestingParenthesis', '('),
        hl('Register', '@b'),
        hl('NestingParenthesis', ')'),
        hl('NestingParenthesis', ')'),
        hl('CallingParenthesis', '('),
        hl('Register', '@c'),
        hl('CallingParenthesis', ')'),
      })
      check_parsing('@a+((@b))+@c', {
        --           01234567890123456890123456789
        --           0         1        2
        ast = {
          {
            'BinaryPlus:0:9:+',
            children = {
              {
                'BinaryPlus:0:2:+',
                children = {
                  'Register(name=a):0:0:@a',
                  {
                    'Nested:0:3:(',
                    children = {
                      {
                        'Nested:0:4:(',
                        children = { 'Register(name=b):0:5:@b' }
                      },
                    },
                  },
                },
              },
              'Register(name=c):0:10:@c',
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('BinaryPlus', '+'),
        hl('NestingParenthesis', '('),
        hl('NestingParenthesis', '('),
        hl('Register', '@b'),
        hl('NestingParenthesis', ')'),
        hl('NestingParenthesis', ')'),
        hl('BinaryPlus', '+'),
        hl('Register', '@c'),
      })
      check_parsing(
        '@a + (@b + @c) + @d(@e) + (+@f) + ((+@g(@h))(@j)(@k))(@l)', {--[[
         | | | | | |   | |  ||  | | ||  | | ||| ||   ||  ||   ||
         000000000011111111112222222222333333333344444444445555555
         012345678901234567890123456789012345678901234567890123456
        ]]
          ast = {{
            'BinaryPlus:0:31: +',
            children = {
              {
                'BinaryPlus:0:23: +',
                children = {
                  {
                    'BinaryPlus:0:14: +',
                    children = {
                      {
                        'BinaryPlus:0:2: +',
                        children = {
                          'Register(name=a):0:0:@a',
                          {
                            'Nested:0:4: (',
                            children = {
                              {
                                'BinaryPlus:0:8: +',
                                children = {
                                  'Register(name=b):0:6:@b',
                                  'Register(name=c):0:10: @c',
                                },
                              },
                            },
                          },
                        },
                      },
                      {
                        'Call:0:19:(',
                        children = {
                          'Register(name=d):0:16: @d',
                          'Register(name=e):0:20:@e',
                        },
                      },
                    },
                  },
                  {
                    'Nested:0:25: (',
                    children = {
                      {
                        'UnaryPlus:0:27:+',
                        children = {
                          'Register(name=f):0:28:@f',
                        },
                      },
                    },
                  },
                },
              },
              {
                'Call:0:53:(',
                children = {
                  {
                    'Nested:0:33: (',
                    children = {
                      {
                        'Call:0:48:(',
                        children = {
                          {
                            'Call:0:44:(',
                            children = {
                              {
                                'Nested:0:35:(',
                                children = {
                                  {
                                    'UnaryPlus:0:36:+',
                                    children = {
                                      {
                                        'Call:0:39:(',
                                        children = {
                                          'Register(name=g):0:37:@g',
                                          'Register(name=h):0:40:@h',
                                        },
                                      },
                                    },
                                  },
                                },
                              },
                              'Register(name=j):0:45:@j',
                            },
                          },
                          'Register(name=k):0:49:@k',
                        },
                      },
                    },
                  },
                  'Register(name=l):0:54:@l',
                },
              },
            },
          }},
        }, {
          hl('Register', '@a'),
          hl('BinaryPlus', '+', 1),
          hl('NestingParenthesis', '(', 1),
          hl('Register', '@b'),
          hl('BinaryPlus', '+', 1),
          hl('Register', '@c', 1),
          hl('NestingParenthesis', ')'),
          hl('BinaryPlus', '+', 1),
          hl('Register', '@d', 1),
          hl('CallingParenthesis', '('),
          hl('Register', '@e'),
          hl('CallingParenthesis', ')'),
          hl('BinaryPlus', '+', 1),
          hl('NestingParenthesis', '(', 1),
          hl('UnaryPlus', '+'),
          hl('Register', '@f'),
          hl('NestingParenthesis', ')'),
          hl('BinaryPlus', '+', 1),
          hl('NestingParenthesis', '(', 1),
          hl('NestingParenthesis', '('),
          hl('UnaryPlus', '+'),
          hl('Register', '@g'),
          hl('CallingParenthesis', '('),
          hl('Register', '@h'),
          hl('CallingParenthesis', ')'),
          hl('NestingParenthesis', ')'),
          hl('CallingParenthesis', '('),
          hl('Register', '@j'),
          hl('CallingParenthesis', ')'),
          hl('CallingParenthesis', '('),
          hl('Register', '@k'),
          hl('CallingParenthesis', ')'),
          hl('NestingParenthesis', ')'),
          hl('CallingParenthesis', '('),
          hl('Register', '@l'),
          hl('CallingParenthesis', ')'),
        })
      check_parsing('@a)', {
        --           012
        ast = {
          {
            'Nested:0:2:',
            children = {
              'Register(name=a):0:0:@a',
            },
          },
        },
        err = {
          arg = ')',
          msg = 'E15: Unexpected closing parenthesis: %.*s',
        },
      }, {
        hl('Register', '@a'),
        hl('InvalidNestingParenthesis', ')'),
      })
      check_parsing('(@a', {
        --           012
        ast = {
          {
            'Nested:0:0:(',
            children = {
              'Register(name=a):0:1:@a',
            },
          },
        },
        err = {
          arg = '(@a',
          msg = 'E110: Missing closing parenthesis for nested expression: %.*s',
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('Register', '@a'),
      })
      check_parsing('@a(@b', {
        --           01234
        ast = {
          {
            'Call:0:2:(',
            children = {
              'Register(name=a):0:0:@a',
              'Register(name=b):0:3:@b',
            },
          },
        },
        err = {
          arg = '(@b',
          msg = 'E116: Missing closing parenthesis for function call: %.*s',
        },
      }, {
        hl('Register', '@a'),
        hl('CallingParenthesis', '('),
        hl('Register', '@b'),
      })
      check_parsing('@a(@b, @c, @d, @e)', {
        --           012345678901234567
        --           0         1
        ast = {
          {
            'Call:0:2:(',
            children = {
              'Register(name=a):0:0:@a',
              {
                'Comma:0:5:,',
                children = {
                  'Register(name=b):0:3:@b',
                  {
                    'Comma:0:9:,',
                    children = {
                      'Register(name=c):0:6: @c',
                      {
                        'Comma:0:13:,',
                        children = {
                          'Register(name=d):0:10: @d',
                          'Register(name=e):0:14: @e',
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('CallingParenthesis', '('),
        hl('Register', '@b'),
        hl('Comma', ','),
        hl('Register', '@c', 1),
        hl('Comma', ','),
        hl('Register', '@d', 1),
        hl('Comma', ','),
        hl('Register', '@e', 1),
        hl('CallingParenthesis', ')'),
      })
      check_parsing('@a(@b(@c))', {
        --           01234567890123456789012345678901234567
        --           0         1         2         3
        ast = {
          {
            'Call:0:2:(',
            children = {
              'Register(name=a):0:0:@a',
              {
                'Call:0:5:(',
                children = {
                  'Register(name=b):0:3:@b',
                  'Register(name=c):0:6:@c',
                },
              },
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('CallingParenthesis', '('),
        hl('Register', '@b'),
        hl('CallingParenthesis', '('),
        hl('Register', '@c'),
        hl('CallingParenthesis', ')'),
        hl('CallingParenthesis', ')'),
      })
      check_parsing('@a(@b(@c(@d(@e), @f(@g(@h), @i(@j)))))', {
        --           01234567890123456789012345678901234567
        --           0         1         2         3
        ast = {
          {
            'Call:0:2:(',
            children = {
              'Register(name=a):0:0:@a',
              {
                'Call:0:5:(',
                children = {
                  'Register(name=b):0:3:@b',
                  {
                    'Call:0:8:(',
                    children = {
                      'Register(name=c):0:6:@c',
                      {
                        'Comma:0:15:,',
                        children = {
                          {
                            'Call:0:11:(',
                            children = {
                              'Register(name=d):0:9:@d',
                              'Register(name=e):0:12:@e',
                            },
                          },
                          {
                            'Call:0:19:(',
                            children = {
                              'Register(name=f):0:16: @f',
                              {
                                'Comma:0:26:,',
                                children = {
                                  {
                                    'Call:0:22:(',
                                    children = {
                                      'Register(name=g):0:20:@g',
                                      'Register(name=h):0:23:@h',
                                    },
                                  },
                                  {
                                    'Call:0:30:(',
                                    children = {
                                      'Register(name=i):0:27: @i',
                                      'Register(name=j):0:31:@j',
                                    },
                                  },
                                },
                              },
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('CallingParenthesis', '('),
        hl('Register', '@b'),
        hl('CallingParenthesis', '('),
        hl('Register', '@c'),
        hl('CallingParenthesis', '('),
        hl('Register', '@d'),
        hl('CallingParenthesis', '('),
        hl('Register', '@e'),
        hl('CallingParenthesis', ')'),
        hl('Comma', ','),
        hl('Register', '@f', 1),
        hl('CallingParenthesis', '('),
        hl('Register', '@g'),
        hl('CallingParenthesis', '('),
        hl('Register', '@h'),
        hl('CallingParenthesis', ')'),
        hl('Comma', ','),
        hl('Register', '@i', 1),
        hl('CallingParenthesis', '('),
        hl('Register', '@j'),
        hl('CallingParenthesis', ')'),
        hl('CallingParenthesis', ')'),
        hl('CallingParenthesis', ')'),
        hl('CallingParenthesis', ')'),
        hl('CallingParenthesis', ')'),
      })
    end)
    it('works with variable names, including curly braces ones', function()
      check_parsing('var', {
          ast = {
            'PlainIdentifier(scope=0,ident=var):0:0:var',
          },
      }, {
        hl('IdentifierName', 'var'),
      })
      check_parsing('g:var', {
          ast = {
            'PlainIdentifier(scope=g,ident=var):0:0:g:var',
          },
      }, {
        hl('IdentifierScope', 'g'),
        hl('IdentifierScopeDelimiter', ':'),
        hl('IdentifierName', 'var'),
      })
      check_parsing('g:', {
          ast = {
            'PlainIdentifier(scope=g,ident=):0:0:g:',
          },
      }, {
        hl('IdentifierScope', 'g'),
        hl('IdentifierScopeDelimiter', ':'),
      })
      check_parsing('{a}', {
        --           012
        ast = {
          {
            'CurlyBracesIdentifier:0:0:{',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:1:a',
            },
          },
        },
      }, {
        hl('Curly', '{'),
        hl('IdentifierName', 'a'),
        hl('Curly', '}'),
      })
      check_parsing('{a:b}', {
        --           012
        ast = {
          {
            'CurlyBracesIdentifier:0:0:{',
            children = {
              'PlainIdentifier(scope=a,ident=b):0:1:a:b',
            },
          },
        },
      }, {
        hl('Curly', '{'),
        hl('IdentifierScope', 'a'),
        hl('IdentifierScopeDelimiter', ':'),
        hl('IdentifierName', 'b'),
        hl('Curly', '}'),
      })
      check_parsing('{a:@b}', {
        --           012345
        ast = {
          {
            'CurlyBracesIdentifier:0:0:{',
            children = {
              {
                'OpMissing:0:3:',
                children={
                  'PlainIdentifier(scope=a,ident=):0:1:a:',
                  'Register(name=b):0:3:@b',
                },
              },
            },
          },
        },
        err = {
          arg = '@b}',
          msg = 'E15: Missing operator: %.*s',
        },
      }, {
        hl('Curly', '{'),
        hl('IdentifierScope', 'a'),
        hl('IdentifierScopeDelimiter', ':'),
        hl('InvalidRegister', '@b'),
        hl('Curly', '}'),
      })
      check_parsing('{@a}', {
        ast = {
          {
            'CurlyBracesIdentifier:0:0:{',
            children = {
              'Register(name=a):0:1:@a',
            },
          },
        },
      }, {
        hl('Curly', '{'),
        hl('Register', '@a'),
        hl('Curly', '}'),
      })
      check_parsing('{@a}{@b}', {
        --           01234567
        ast = {
          {
            'ComplexIdentifier:0:4:',
            children = {
              {
                'CurlyBracesIdentifier:0:0:{',
                children = {
                  'Register(name=a):0:1:@a',
                },
              },
              {
                'CurlyBracesIdentifier:0:4:{',
                children = {
                  'Register(name=b):0:5:@b',
                },
              },
            },
          },
        },
      }, {
        hl('Curly', '{'),
        hl('Register', '@a'),
        hl('Curly', '}'),
        hl('Curly', '{'),
        hl('Register', '@b'),
        hl('Curly', '}'),
      })
      check_parsing('g:{@a}', {
        --           01234567
        ast = {
          {
            'ComplexIdentifier:0:2:',
            children = {
              'PlainIdentifier(scope=g,ident=):0:0:g:',
              {
                'CurlyBracesIdentifier:0:2:{',
                children = {
                  'Register(name=a):0:3:@a',
                },
              },
            },
          },
        },
      }, {
        hl('IdentifierScope', 'g'),
        hl('IdentifierScopeDelimiter', ':'),
        hl('Curly', '{'),
        hl('Register', '@a'),
        hl('Curly', '}'),
      })
      check_parsing('{@a}_test', {
        --           012345678
        ast = {
          {
            'ComplexIdentifier:0:4:',
            children = {
              {
                'CurlyBracesIdentifier:0:0:{',
                children = {
                  'Register(name=a):0:1:@a',
                },
              },
              'PlainIdentifier(scope=0,ident=_test):0:4:_test',
            },
          },
        },
      }, {
        hl('Curly', '{'),
        hl('Register', '@a'),
        hl('Curly', '}'),
        hl('IdentifierName', '_test'),
      })
      check_parsing('g:{@a}_test', {
        --           01234567890
        ast = {
          {
            'ComplexIdentifier:0:2:',
            children = {
              'PlainIdentifier(scope=g,ident=):0:0:g:',
              {
                'ComplexIdentifier:0:6:',
                children = {
                  {
                    'CurlyBracesIdentifier:0:2:{',
                    children = {
                      'Register(name=a):0:3:@a',
                    },
                  },
                  'PlainIdentifier(scope=0,ident=_test):0:6:_test',
                },
              },
            },
          },
        },
      }, {
        hl('IdentifierScope', 'g'),
        hl('IdentifierScopeDelimiter', ':'),
        hl('Curly', '{'),
        hl('Register', '@a'),
        hl('Curly', '}'),
        hl('IdentifierName', '_test'),
      })
      check_parsing('g:{@a}_test()', {
        --           0123456789012
        ast = {
          {
            'Call:0:11:(',
            children = {
              {
                'ComplexIdentifier:0:2:',
                children = {
                  'PlainIdentifier(scope=g,ident=):0:0:g:',
                  {
                    'ComplexIdentifier:0:6:',
                    children = {
                      {
                        'CurlyBracesIdentifier:0:2:{',
                        children = {
                          'Register(name=a):0:3:@a',
                        },
                      },
                      'PlainIdentifier(scope=0,ident=_test):0:6:_test',
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('IdentifierScope', 'g'),
        hl('IdentifierScopeDelimiter', ':'),
        hl('Curly', '{'),
        hl('Register', '@a'),
        hl('Curly', '}'),
        hl('IdentifierName', '_test'),
        hl('CallingParenthesis', '('),
        hl('CallingParenthesis', ')'),
      })
      check_parsing('{@a} ()', {
        --           0123456789012
        ast = {
          {
            'Call:0:4: (',
            children = {
              {
                'CurlyBracesIdentifier:0:0:{',
                children = {
                  'Register(name=a):0:1:@a',
                },
              },
            },
          },
        },
      }, {
        hl('Curly', '{'),
        hl('Register', '@a'),
        hl('Curly', '}'),
        hl('CallingParenthesis', '(', 1),
        hl('CallingParenthesis', ')'),
      })
      check_parsing('g:{@a} ()', {
        --           0123456789012
        ast = {
          {
            'Call:0:6: (',
            children = {
              {
                'ComplexIdentifier:0:2:',
                children = {
                  'PlainIdentifier(scope=g,ident=):0:0:g:',
                  {
                    'CurlyBracesIdentifier:0:2:{',
                    children = {
                      'Register(name=a):0:3:@a',
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('IdentifierScope', 'g'),
        hl('IdentifierScopeDelimiter', ':'),
        hl('Curly', '{'),
        hl('Register', '@a'),
        hl('Curly', '}'),
        hl('CallingParenthesis', '(', 1),
        hl('CallingParenthesis', ')'),
      })
      check_parsing('{@a', {
        --           012
        ast = {
          {
            'UnknownFigure:0:0:{',
            children = {
              'Register(name=a):0:1:@a',
            },
          },
        },
        err = {
          arg = '{@a',
          msg = 'E15: Missing closing figure brace: %.*s',
        },
      }, {
        hl('FigureBrace', '{'),
        hl('Register', '@a'),
      })
    end)
    it('works with lambdas and dictionaries', function()
      check_parsing('{}', {
        ast = {
          'DictLiteral:0:0:{',
        },
      }, {
        hl('Dict', '{'),
        hl('Dict', '}'),
      })
      check_parsing('{->@a}', {
        ast = {
          {
            'Lambda:0:0:{',
            children = {
              {
                'Arrow:0:1:->',
                children = {
                  'Register(name=a):0:3:@a',
                },
              },
            },
          },
        },
      }, {
        hl('Lambda', '{'),
        hl('Arrow', '->'),
        hl('Register', '@a'),
        hl('Lambda', '}'),
      })
      check_parsing('{->@a+@b}', {
        --           012345678
        ast = {
          {
            'Lambda:0:0:{',
            children = {
              {
                'Arrow:0:1:->',
                children = {
                  {
                    'BinaryPlus:0:5:+',
                    children = {
                      'Register(name=a):0:3:@a',
                      'Register(name=b):0:6:@b',
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('Lambda', '{'),
        hl('Arrow', '->'),
        hl('Register', '@a'),
        hl('BinaryPlus', '+'),
        hl('Register', '@b'),
        hl('Lambda', '}'),
      })
      check_parsing('{a->@a}', {
        --           012345678
        ast = {
          {
            'Lambda:0:0:{',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:1:a',
              {
                'Arrow:0:2:->',
                children = {
                  'Register(name=a):0:4:@a',
                },
              },
            },
          },
        },
      }, {
        hl('Lambda', '{'),
        hl('IdentifierName', 'a'),
        hl('Arrow', '->'),
        hl('Register', '@a'),
        hl('Lambda', '}'),
      })
      check_parsing('{a,b->@a}', {
        --           012345678
        ast = {
          {
            'Lambda:0:0:{',
            children = {
              {
                'Comma:0:2:,',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                  'PlainIdentifier(scope=0,ident=b):0:3:b',
                },
              },
              {
                'Arrow:0:4:->',
                children = {
                  'Register(name=a):0:6:@a',
                },
              },
            },
          },
        },
      }, {
        hl('Lambda', '{'),
        hl('IdentifierName', 'a'),
        hl('Comma', ','),
        hl('IdentifierName', 'b'),
        hl('Arrow', '->'),
        hl('Register', '@a'),
        hl('Lambda', '}'),
      })
      check_parsing('{a,b,c->@a}', {
        --           01234567890
        ast = {
          {
            'Lambda:0:0:{',
            children = {
              {
                'Comma:0:2:,',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                  {
                    'Comma:0:4:,',
                    children = {
                      'PlainIdentifier(scope=0,ident=b):0:3:b',
                      'PlainIdentifier(scope=0,ident=c):0:5:c',
                    },
                  },
                },
              },
              {
                'Arrow:0:6:->',
                children = {
                  'Register(name=a):0:8:@a',
                },
              },
            },
          },
        },
      }, {
        hl('Lambda', '{'),
        hl('IdentifierName', 'a'),
        hl('Comma', ','),
        hl('IdentifierName', 'b'),
        hl('Comma', ','),
        hl('IdentifierName', 'c'),
        hl('Arrow', '->'),
        hl('Register', '@a'),
        hl('Lambda', '}'),
      })
      check_parsing('{a,b,c,d->@a}', {
        --           0123456789012
        ast = {
          {
            'Lambda:0:0:{',
            children = {
              {
                'Comma:0:2:,',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                  {
                    'Comma:0:4:,',
                    children = {
                      'PlainIdentifier(scope=0,ident=b):0:3:b',
                      {
                        'Comma:0:6:,',
                        children = {
                          'PlainIdentifier(scope=0,ident=c):0:5:c',
                          'PlainIdentifier(scope=0,ident=d):0:7:d',
                        },
                      },
                    },
                  },
                },
              },
              {
                'Arrow:0:8:->',
                children = {
                  'Register(name=a):0:10:@a',
                },
              },
            },
          },
        },
      }, {
        hl('Lambda', '{'),
        hl('IdentifierName', 'a'),
        hl('Comma', ','),
        hl('IdentifierName', 'b'),
        hl('Comma', ','),
        hl('IdentifierName', 'c'),
        hl('Comma', ','),
        hl('IdentifierName', 'd'),
        hl('Arrow', '->'),
        hl('Register', '@a'),
        hl('Lambda', '}'),
      })
      check_parsing('{a,b,c,d,->@a}', {
        --           01234567890123
        ast = {
          {
            'Lambda:0:0:{',
            children = {
              {
                'Comma:0:2:,',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                  {
                    'Comma:0:4:,',
                    children = {
                      'PlainIdentifier(scope=0,ident=b):0:3:b',
                      {
                        'Comma:0:6:,',
                        children = {
                          'PlainIdentifier(scope=0,ident=c):0:5:c',
                          {
                            'Comma:0:8:,',
                            children = {
                              'PlainIdentifier(scope=0,ident=d):0:7:d',
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
              {
                'Arrow:0:9:->',
                children = {
                  'Register(name=a):0:11:@a',
                },
              },
            },
          },
        },
      }, {
        hl('Lambda', '{'),
        hl('IdentifierName', 'a'),
        hl('Comma', ','),
        hl('IdentifierName', 'b'),
        hl('Comma', ','),
        hl('IdentifierName', 'c'),
        hl('Comma', ','),
        hl('IdentifierName', 'd'),
        hl('Comma', ','),
        hl('Arrow', '->'),
        hl('Register', '@a'),
        hl('Lambda', '}'),
      })
      check_parsing('{a,b->{c,d->{e,f->@a}}}', {
        --           01234567890123456789012
        --           0         1         2
        ast = {
          {
            'Lambda:0:0:{',
            children = {
              {
                'Comma:0:2:,',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                  'PlainIdentifier(scope=0,ident=b):0:3:b',
                },
              },
              {
                'Arrow:0:4:->',
                children = {
                  {
                    'Lambda:0:6:{',
                    children = {
                      {
                        'Comma:0:8:,',
                        children = {
                          'PlainIdentifier(scope=0,ident=c):0:7:c',
                          'PlainIdentifier(scope=0,ident=d):0:9:d',
                        },
                      },
                      {
                        'Arrow:0:10:->',
                        children = {
                          {
                            'Lambda:0:12:{',
                            children = {
                              {
                                'Comma:0:14:,',
                                children = {
                                  'PlainIdentifier(scope=0,ident=e):0:13:e',
                                  'PlainIdentifier(scope=0,ident=f):0:15:f',
                                },
                              },
                              {
                                'Arrow:0:16:->',
                                children = {
                                  'Register(name=a):0:18:@a',
                                },
                              },
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('Lambda', '{'),
        hl('IdentifierName', 'a'),
        hl('Comma', ','),
        hl('IdentifierName', 'b'),
        hl('Arrow', '->'),
        hl('Lambda', '{'),
        hl('IdentifierName', 'c'),
        hl('Comma', ','),
        hl('IdentifierName', 'd'),
        hl('Arrow', '->'),
        hl('Lambda', '{'),
        hl('IdentifierName', 'e'),
        hl('Comma', ','),
        hl('IdentifierName', 'f'),
        hl('Arrow', '->'),
        hl('Register', '@a'),
        hl('Lambda', '}'),
        hl('Lambda', '}'),
        hl('Lambda', '}'),
      })
      check_parsing('{a,b->c,d}', {
        --           0123456789
        ast = {
          {
            'Lambda:0:0:{',
            children = {
              {
                'Comma:0:2:,',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                  'PlainIdentifier(scope=0,ident=b):0:3:b',
                },
              },
              {
                'Arrow:0:4:->',
                children = {
                  {
                    'Comma:0:7:,',
                    children = {
                      'PlainIdentifier(scope=0,ident=c):0:6:c',
                      'PlainIdentifier(scope=0,ident=d):0:8:d',
                    },
                  },
                },
              },
            },
          },
        },
        err = {
          arg = ',d}',
          msg = 'E15: Comma outside of call, lambda or literal: %.*s',
        },
      }, {
        hl('Lambda', '{'),
        hl('IdentifierName', 'a'),
        hl('Comma', ','),
        hl('IdentifierName', 'b'),
        hl('Arrow', '->'),
        hl('IdentifierName', 'c'),
        hl('InvalidComma', ','),
        hl('IdentifierName', 'd'),
        hl('Lambda', '}'),
      })
      check_parsing('a,b,c,d', {
        --           0123456789
        ast = {
          {
            'Comma:0:1:,',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              {
                'Comma:0:3:,',
                children = {
                'PlainIdentifier(scope=0,ident=b):0:2:b',
                  {
                    'Comma:0:5:,',
                    children = {
                      'PlainIdentifier(scope=0,ident=c):0:4:c',
                      'PlainIdentifier(scope=0,ident=d):0:6:d',
                    },
                  },
                },
              },
            },
          },
        },
        err = {
          arg = ',b,c,d',
          msg = 'E15: Comma outside of call, lambda or literal: %.*s',
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('InvalidComma', ','),
        hl('IdentifierName', 'b'),
        hl('InvalidComma', ','),
        hl('IdentifierName', 'c'),
        hl('InvalidComma', ','),
        hl('IdentifierName', 'd'),
      })
      check_parsing('a,b,c,d,', {
        --           0123456789
        ast = {
          {
            'Comma:0:1:,',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              {
                'Comma:0:3:,',
                children = {
                'PlainIdentifier(scope=0,ident=b):0:2:b',
                  {
                    'Comma:0:5:,',
                    children = {
                      'PlainIdentifier(scope=0,ident=c):0:4:c',
                      {
                        'Comma:0:7:,',
                        children = {
                          'PlainIdentifier(scope=0,ident=d):0:6:d',
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
        err = {
          arg = ',b,c,d,',
          msg = 'E15: Comma outside of call, lambda or literal: %.*s',
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('InvalidComma', ','),
        hl('IdentifierName', 'b'),
        hl('InvalidComma', ','),
        hl('IdentifierName', 'c'),
        hl('InvalidComma', ','),
        hl('IdentifierName', 'd'),
        hl('InvalidComma', ','),
      })
      check_parsing(',', {
        --           0123456789
        ast = {
          {
            'Comma:0:0:,',
            children = {
              'Missing:0:0:',
            },
          },
        },
        err = {
          arg = ',',
          msg = 'E15: Expected value, got comma: %.*s',
        },
      }, {
        hl('InvalidComma', ','),
      })
      check_parsing('{,a->@a}', {
        --           0123456789
        ast = {
          {
            'CurlyBracesIdentifier:0:0:{',
            children = {
              {
                'Arrow:0:3:->',
                children = {
                  {
                    'Comma:0:1:,',
                    children = {
                      'Missing:0:1:',
                      'PlainIdentifier(scope=0,ident=a):0:2:a',
                    },
                  },
                  'Register(name=a):0:5:@a',
                },
              },
            },
          },
        },
        err = {
          arg = ',a->@a}',
          msg = 'E15: Expected value, got comma: %.*s',
        },
      }, {
        hl('Curly', '{'),
        hl('InvalidComma', ','),
        hl('IdentifierName', 'a'),
        hl('InvalidArrow', '->'),
        hl('Register', '@a'),
        hl('Curly', '}'),
      })
      check_parsing('}', {
        --           0123456789
        ast = {
          'UnknownFigure:0:0:',
        },
        err = {
          arg = '}',
          msg = 'E15: Unexpected closing figure brace: %.*s',
        },
      }, {
        hl('InvalidFigureBrace', '}'),
      })
      check_parsing('{->}', {
        --           0123456789
        ast = {
          {
            'Lambda:0:0:{',
            children = {
              'Arrow:0:1:->',
            },
          },
        },
        err = {
          arg = '}',
          msg = 'E15: Expected value, got closing figure brace: %.*s',
        },
      }, {
        hl('Lambda', '{'),
        hl('Arrow', '->'),
        hl('InvalidLambda', '}'),
      })
      check_parsing('{a,b}', {
        --           0123456789
        ast = {
          {
            'Lambda:0:0:{',
            children = {
              {
                'Comma:0:2:,',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                  'PlainIdentifier(scope=0,ident=b):0:3:b',
                },
              },
            },
          },
        },
        err = {
          arg = '}',
          msg = 'E15: Expected lambda arguments list or arrow: %.*s',
        },
      }, {
        hl('Lambda', '{'),
        hl('IdentifierName', 'a'),
        hl('Comma', ','),
        hl('IdentifierName', 'b'),
        hl('InvalidLambda', '}'),
      })
      check_parsing('{a,}', {
        --           0123456789
        ast = {
          {
            'Lambda:0:0:{',
            children = {
              {
                'Comma:0:2:,',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                },
              },
            },
          },
        },
        err = {
          arg = '}',
          msg = 'E15: Expected lambda arguments list or arrow: %.*s',
        },
      }, {
        hl('Lambda', '{'),
        hl('IdentifierName', 'a'),
        hl('Comma', ','),
        hl('InvalidLambda', '}'),
      })
      check_parsing('{@a:@b}', {
        --           0123456789
        ast = {
          {
            'DictLiteral:0:0:{',
            children = {
              {
                'Colon:0:3::',
                children = {
                  'Register(name=a):0:1:@a',
                  'Register(name=b):0:4:@b',
                },
              },
            },
          },
        },
      }, {
        hl('Dict', '{'),
        hl('Register', '@a'),
        hl('Colon', ':'),
        hl('Register', '@b'),
        hl('Dict', '}'),
      })
      check_parsing('{@a:@b,@c:@d}', {
        --           0123456789012
        --           0         1
        ast = {
          {
            'DictLiteral:0:0:{',
            children = {
              {
                'Comma:0:6:,',
                children = {
                  {
                    'Colon:0:3::',
                    children = {
                      'Register(name=a):0:1:@a',
                      'Register(name=b):0:4:@b',
                    },
                  },
                  {
                    'Colon:0:9::',
                    children = {
                      'Register(name=c):0:7:@c',
                      'Register(name=d):0:10:@d',
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('Dict', '{'),
        hl('Register', '@a'),
        hl('Colon', ':'),
        hl('Register', '@b'),
        hl('Comma', ','),
        hl('Register', '@c'),
        hl('Colon', ':'),
        hl('Register', '@d'),
        hl('Dict', '}'),
      })
      check_parsing('{@a:@b,@c:@d,@e:@f,}', {
        --           01234567890123456789
        --           0         1
        ast = {
          {
            'DictLiteral:0:0:{',
            children = {
              {
                'Comma:0:6:,',
                children = {
                  {
                    'Colon:0:3::',
                    children = {
                      'Register(name=a):0:1:@a',
                      'Register(name=b):0:4:@b',
                    },
                  },
                  {
                    'Comma:0:12:,',
                    children = {
                      {
                        'Colon:0:9::',
                        children = {
                          'Register(name=c):0:7:@c',
                          'Register(name=d):0:10:@d',
                        },
                      },
                      {
                        'Comma:0:18:,',
                        children = {
                          {
                            'Colon:0:15::',
                            children = {
                              'Register(name=e):0:13:@e',
                              'Register(name=f):0:16:@f',
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('Dict', '{'),
        hl('Register', '@a'),
        hl('Colon', ':'),
        hl('Register', '@b'),
        hl('Comma', ','),
        hl('Register', '@c'),
        hl('Colon', ':'),
        hl('Register', '@d'),
        hl('Comma', ','),
        hl('Register', '@e'),
        hl('Colon', ':'),
        hl('Register', '@f'),
        hl('Comma', ','),
        hl('Dict', '}'),
      })
      check_parsing('{@a:@b,@c:@d,@e:@f,@g:}', {
        --           01234567890123456789012
        --           0         1         2
        ast = {
          {
            'DictLiteral:0:0:{',
            children = {
              {
                'Comma:0:6:,',
                children = {
                  {
                    'Colon:0:3::',
                    children = {
                      'Register(name=a):0:1:@a',
                      'Register(name=b):0:4:@b',
                    },
                  },
                  {
                    'Comma:0:12:,',
                    children = {
                      {
                        'Colon:0:9::',
                        children = {
                          'Register(name=c):0:7:@c',
                          'Register(name=d):0:10:@d',
                        },
                      },
                      {
                        'Comma:0:18:,',
                        children = {
                          {
                            'Colon:0:15::',
                            children = {
                              'Register(name=e):0:13:@e',
                              'Register(name=f):0:16:@f',
                            },
                          },
                          {
                            'Colon:0:21::',
                            children = {
                              'Register(name=g):0:19:@g',
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
        err = {
          arg = '}',
          msg = 'E15: Expected value, got closing figure brace: %.*s',
        },
      }, {
        hl('Dict', '{'),
        hl('Register', '@a'),
        hl('Colon', ':'),
        hl('Register', '@b'),
        hl('Comma', ','),
        hl('Register', '@c'),
        hl('Colon', ':'),
        hl('Register', '@d'),
        hl('Comma', ','),
        hl('Register', '@e'),
        hl('Colon', ':'),
        hl('Register', '@f'),
        hl('Comma', ','),
        hl('Register', '@g'),
        hl('Colon', ':'),
        hl('InvalidDict', '}'),
      })
      check_parsing('{@a:@b,}', {
        --           01234567890123
        --           0         1
        ast = {
          {
            'DictLiteral:0:0:{',
            children = {
              {
                'Comma:0:6:,',
                children = {
                  {
                    'Colon:0:3::',
                    children = {
                      'Register(name=a):0:1:@a',
                      'Register(name=b):0:4:@b',
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('Dict', '{'),
        hl('Register', '@a'),
        hl('Colon', ':'),
        hl('Register', '@b'),
        hl('Comma', ','),
        hl('Dict', '}'),
      })
      check_parsing('{({f -> g})(@h)(@i)}', {
        --           01234567890123456789
        --           0         1
        ast = {
          {
            'CurlyBracesIdentifier:0:0:{',
            children = {
              {
                'Call:0:15:(',
                children = {
                  {
                    'Call:0:11:(',
                    children = {
                      {
                        'Nested:0:1:(',
                        children = {
                          {
                            'Lambda:0:2:{',
                            children = {
                              'PlainIdentifier(scope=0,ident=f):0:3:f',
                              {
                                'Arrow:0:4: ->',
                                children = {
                                  'PlainIdentifier(scope=0,ident=g):0:7: g',
                                },
                              },
                            },
                          },
                        },
                      },
                      'Register(name=h):0:12:@h',
                    },
                  },
                  'Register(name=i):0:16:@i',
                },
              },
            },
          },
        },
      }, {
        hl('Curly', '{'),
        hl('NestingParenthesis', '('),
        hl('Lambda', '{'),
        hl('IdentifierName', 'f'),
        hl('Arrow', '->', 1),
        hl('IdentifierName', 'g', 1),
        hl('Lambda', '}'),
        hl('NestingParenthesis', ')'),
        hl('CallingParenthesis', '('),
        hl('Register', '@h'),
        hl('CallingParenthesis', ')'),
        hl('CallingParenthesis', '('),
        hl('Register', '@i'),
        hl('CallingParenthesis', ')'),
        hl('Curly', '}'),
      })
      check_parsing('a:{b()}c', {
        --           01234567
        ast = {
          {
            'ComplexIdentifier:0:2:',
            children = {
              'PlainIdentifier(scope=a,ident=):0:0:a:',
              {
                'ComplexIdentifier:0:7:',
                children = {
                  {
                    'CurlyBracesIdentifier:0:2:{',
                    children = {
                      {
                        'Call:0:4:(',
                        children = {
                          'PlainIdentifier(scope=0,ident=b):0:3:b',
                        },
                      },
                    },
                  },
                  'PlainIdentifier(scope=0,ident=c):0:7:c',
                },
              },
            },
          },
        },
      }, {
        hl('IdentifierScope', 'a'),
        hl('IdentifierScopeDelimiter', ':'),
        hl('Curly', '{'),
        hl('IdentifierName', 'b'),
        hl('CallingParenthesis', '('),
        hl('CallingParenthesis', ')'),
        hl('Curly', '}'),
        hl('IdentifierName', 'c'),
      })
      check_parsing('a:{{b, c -> @d + @e + ({f -> g})(@h)}(@i)}j', {
        --           01234567890123456789012345678901234567890123456
        --           0         1         2         3         4
        ast = {
          {
            'ComplexIdentifier:0:2:',
            children = {
              'PlainIdentifier(scope=a,ident=):0:0:a:',
              {
                'ComplexIdentifier:0:42:',
                children = {
                  {
                    'CurlyBracesIdentifier:0:2:{',
                    children = {
                      {
                        'Call:0:37:(',
                        children = {
                          {
                            'Lambda:0:3:{',
                            children = {
                              {
                                'Comma:0:5:,',
                                children = {
                                  'PlainIdentifier(scope=0,ident=b):0:4:b',
                                  'PlainIdentifier(scope=0,ident=c):0:6: c',
                                },
                              },
                              {
                                'Arrow:0:8: ->',
                                children = {
                                  {
                                    'BinaryPlus:0:19: +',
                                    children = {
                                      {
                                        'BinaryPlus:0:14: +',
                                        children = {
                                          'Register(name=d):0:11: @d',
                                          'Register(name=e):0:16: @e',
                                        },
                                      },
                                      {
                                        'Call:0:32:(',
                                        children = {
                                          {
                                            'Nested:0:21: (',
                                            children = {
                                              {
                                                'Lambda:0:23:{',
                                                children = {
                                                  'PlainIdentifier(scope=0,ident=f):0:24:f',
                                                  {
                                                    'Arrow:0:25: ->',
                                                    children = {
                                                      'PlainIdentifier(scope=0,ident=g):0:28: g',
                                                    },
                                                  },
                                                },
                                              },
                                            },
                                          },
                                          'Register(name=h):0:33:@h',
                                        },
                                      },
                                    },
                                  },
                                },
                              },
                            },
                          },
                          'Register(name=i):0:38:@i',
                        },
                      },
                    },
                  },
                  'PlainIdentifier(scope=0,ident=j):0:42:j',
                },
              },
            },
          },
        },
      }, {
        hl('IdentifierScope', 'a'),
        hl('IdentifierScopeDelimiter', ':'),
        hl('Curly', '{'),
        hl('Lambda', '{'),
        hl('IdentifierName', 'b'),
        hl('Comma', ','),
        hl('IdentifierName', 'c', 1),
        hl('Arrow', '->', 1),
        hl('Register', '@d', 1),
        hl('BinaryPlus', '+', 1),
        hl('Register', '@e', 1),
        hl('BinaryPlus', '+', 1),
        hl('NestingParenthesis', '(', 1),
        hl('Lambda', '{'),
        hl('IdentifierName', 'f'),
        hl('Arrow', '->', 1),
        hl('IdentifierName', 'g', 1),
        hl('Lambda', '}'),
        hl('NestingParenthesis', ')'),
        hl('CallingParenthesis', '('),
        hl('Register', '@h'),
        hl('CallingParenthesis', ')'),
        hl('Lambda', '}'),
        hl('CallingParenthesis', '('),
        hl('Register', '@i'),
        hl('CallingParenthesis', ')'),
        hl('Curly', '}'),
        hl('IdentifierName', 'j'),
      })
      check_parsing('{@a + @b : @c + @d, @e + @f : @g + @i}', {
        --           01234567890123456789012345678901234567
        --           0         1         2         3
        ast = {
          {
            'DictLiteral:0:0:{',
            children = {
              {
                'Comma:0:18:,',
                children = {
                  {
                    'Colon:0:8: :',
                    children = {
                      {
                        'BinaryPlus:0:3: +',
                        children = {
                          'Register(name=a):0:1:@a',
                          'Register(name=b):0:5: @b',
                        },
                      },
                      {
                        'BinaryPlus:0:13: +',
                        children = {
                          'Register(name=c):0:10: @c',
                          'Register(name=d):0:15: @d',
                        },
                      },
                    },
                  },
                  {
                    'Colon:0:27: :',
                    children = {
                      {
                        'BinaryPlus:0:22: +',
                        children = {
                          'Register(name=e):0:19: @e',
                          'Register(name=f):0:24: @f',
                        },
                      },
                      {
                        'BinaryPlus:0:32: +',
                        children = {
                          'Register(name=g):0:29: @g',
                          'Register(name=i):0:34: @i',
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('Dict', '{'),
        hl('Register', '@a'),
        hl('BinaryPlus', '+', 1),
        hl('Register', '@b', 1),
        hl('Colon', ':', 1),
        hl('Register', '@c', 1),
        hl('BinaryPlus', '+', 1),
        hl('Register', '@d', 1),
        hl('Comma', ','),
        hl('Register', '@e', 1),
        hl('BinaryPlus', '+', 1),
        hl('Register', '@f', 1),
        hl('Colon', ':', 1),
        hl('Register', '@g', 1),
        hl('BinaryPlus', '+', 1),
        hl('Register', '@i', 1),
        hl('Dict', '}'),
      })
      check_parsing('-> -> ->', {
        --           01234567
        ast = {
          {
            'Arrow:0:0:->',
            children = {
              'Missing:0:0:',
              {
                'Arrow:0:2: ->',
                children = {
                  'Missing:0:2:',
                  {
                    'Arrow:0:5: ->',
                    children = {
                      'Missing:0:5:',
                    },
                  },
                },
              },
            },
          },
        },
        err = {
          arg = '-> -> ->',
          msg = 'E15: Unexpected arrow: %.*s',
        },
      }, {
        hl('InvalidArrow', '->'),
        hl('InvalidArrow', '->', 1),
        hl('InvalidArrow', '->', 1),
      })
      check_parsing('a -> b -> c -> d', {
        --           0123456789012345
        --           0         1
        ast = {
          {
            'Arrow:0:1: ->',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              {
                'Arrow:0:6: ->',
                children = {
                  'PlainIdentifier(scope=0,ident=b):0:4: b',
                  {
                    'Arrow:0:11: ->',
                    children = {
                      'PlainIdentifier(scope=0,ident=c):0:9: c',
                      'PlainIdentifier(scope=0,ident=d):0:14: d',
                    },
                  },
                },
              },
            },
          },
        },
        err = {
          arg = '-> b -> c -> d',
          msg = 'E15: Arrow outside of lambda: %.*s',
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('InvalidArrow', '->', 1),
        hl('IdentifierName', 'b', 1),
        hl('InvalidArrow', '->', 1),
        hl('IdentifierName', 'c', 1),
        hl('InvalidArrow', '->', 1),
        hl('IdentifierName', 'd', 1),
      })
      check_parsing('{a -> b -> c}', {
        --           0123456789012
        --           0         1
        ast = {
          {
            'Lambda:0:0:{',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:1:a',
              {
                'Arrow:0:2: ->',
                children = {
                  {
                    'Arrow:0:7: ->',
                    children = {
                      'PlainIdentifier(scope=0,ident=b):0:5: b',
                      'PlainIdentifier(scope=0,ident=c):0:10: c',
                    },
                  },
                },
              },
            },
          },
        },
        err = {
          arg = '-> c}',
          msg = 'E15: Arrow outside of lambda: %.*s',
        },
      }, {
        hl('Lambda', '{'),
        hl('IdentifierName', 'a'),
        hl('Arrow', '->', 1),
        hl('IdentifierName', 'b', 1),
        hl('InvalidArrow', '->', 1),
        hl('IdentifierName', 'c', 1),
        hl('Lambda', '}'),
      })
      check_parsing('{a: -> b}', {
        --           012345678
        ast = {
          {
            'CurlyBracesIdentifier:0:0:{',
            children = {
              {
                'Arrow:0:3: ->',
                children = {
                  'PlainIdentifier(scope=a,ident=):0:1:a:',
                  'PlainIdentifier(scope=0,ident=b):0:6: b',
                },
              },
            },
          },
        },
        err = {
          arg = '-> b}',
          msg = 'E15: Arrow outside of lambda: %.*s',
        },
      }, {
        hl('Curly', '{'),
        hl('IdentifierScope', 'a'),
        hl('IdentifierScopeDelimiter', ':'),
        hl('InvalidArrow', '->', 1),
        hl('IdentifierName', 'b', 1),
        hl('Curly', '}'),
      })

      check_parsing('{a:b -> b}', {
        --           0123456789
        ast = {
          {
            'CurlyBracesIdentifier:0:0:{',
            children = {
              {
                'Arrow:0:4: ->',
                children = {
                  'PlainIdentifier(scope=a,ident=b):0:1:a:b',
                  'PlainIdentifier(scope=0,ident=b):0:7: b',
                },
              },
            },
          },
        },
        err = {
          arg = '-> b}',
          msg = 'E15: Arrow outside of lambda: %.*s',
        },
      }, {
        hl('Curly', '{'),
        hl('IdentifierScope', 'a'),
        hl('IdentifierScopeDelimiter', ':'),
        hl('IdentifierName', 'b'),
        hl('InvalidArrow', '->', 1),
        hl('IdentifierName', 'b', 1),
        hl('Curly', '}'),
      })

      check_parsing('{a#b -> b}', {
        --           0123456789
        ast = {
          {
            'CurlyBracesIdentifier:0:0:{',
            children = {
              {
                'Arrow:0:4: ->',
                children = {
                  'PlainIdentifier(scope=0,ident=a#b):0:1:a#b',
                  'PlainIdentifier(scope=0,ident=b):0:7: b',
                },
              },
            },
          },
        },
        err = {
          arg = '-> b}',
          msg = 'E15: Arrow outside of lambda: %.*s',
        },
      }, {
        hl('Curly', '{'),
        hl('IdentifierName', 'a#b'),
        hl('InvalidArrow', '->', 1),
        hl('IdentifierName', 'b', 1),
        hl('Curly', '}'),
      })
      check_parsing('{a : b : c}', {
        --           01234567890
        --           0         1
        ast = {
          {
            'DictLiteral:0:0:{',
            children = {
              {
                'Colon:0:2: :',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                  {
                    'Colon:0:6: :',
                    children = {
                      'PlainIdentifier(scope=0,ident=b):0:4: b',
                      'PlainIdentifier(scope=0,ident=c):0:8: c',
                    },
                  },
                },
              },
            },
          },
        },
        err = {
          arg = ': c}',
          msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
        },
      }, {
        hl('Dict', '{'),
        hl('IdentifierName', 'a'),
        hl('Colon', ':', 1),
        hl('IdentifierName', 'b', 1),
        hl('InvalidColon', ':', 1),
        hl('IdentifierName', 'c', 1),
        hl('Dict', '}'),
      })
      check_parsing('{', {
        --           0
        ast = {
          'UnknownFigure:0:0:{',
        },
        err = {
          arg = '{',
          msg = 'E15: Missing closing figure brace: %.*s',
        },
      }, {
        hl('FigureBrace', '{'),
      })
      check_parsing('{a', {
        --           01
        ast = {
          {
            'UnknownFigure:0:0:{',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:1:a',
            },
          },
        },
        err = {
          arg = '{a',
          msg = 'E15: Missing closing figure brace: %.*s',
        },
      }, {
        hl('FigureBrace', '{'),
        hl('IdentifierName', 'a'),
      })
      check_parsing('{a,b', {
        --           0123
        ast = {
          {
            'Lambda:0:0:{',
            children = {
              {
                'Comma:0:2:,',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                  'PlainIdentifier(scope=0,ident=b):0:3:b',
                },
              },
            },
          },
        },
        err = {
          arg = '{a,b',
          msg = 'E15: Missing closing figure brace for lambda: %.*s',
        },
      }, {
        hl('Lambda', '{'),
        hl('IdentifierName', 'a'),
        hl('Comma', ','),
        hl('IdentifierName', 'b'),
      })
      check_parsing('{a,b->', {
        --           012345
        ast = {
          {
            'Lambda:0:0:{',
            children = {
              {
                'Comma:0:2:,',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                  'PlainIdentifier(scope=0,ident=b):0:3:b',
                },
              },
              'Arrow:0:4:->',
            },
          },
        },
        err = {
          arg = '',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
        hl('Lambda', '{'),
        hl('IdentifierName', 'a'),
        hl('Comma', ','),
        hl('IdentifierName', 'b'),
        hl('Arrow', '->'),
      })
      check_parsing('{a,b->c', {
        --           0123456
        ast = {
          {
            'Lambda:0:0:{',
            children = {
              {
                'Comma:0:2:,',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                  'PlainIdentifier(scope=0,ident=b):0:3:b',
                },
              },
              {
                'Arrow:0:4:->',
                children = {
                  'PlainIdentifier(scope=0,ident=c):0:6:c',
                },
              },
            },
          },
        },
        err = {
          arg = '{a,b->c',
          msg = 'E15: Missing closing figure brace for lambda: %.*s',
        },
      }, {
        hl('Lambda', '{'),
        hl('IdentifierName', 'a'),
        hl('Comma', ','),
        hl('IdentifierName', 'b'),
        hl('Arrow', '->'),
        hl('IdentifierName', 'c'),
      })
      check_parsing('{a : b', {
        --           012345
        ast = {
          {
            'DictLiteral:0:0:{',
            children = {
              {
                'Colon:0:2: :',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                  'PlainIdentifier(scope=0,ident=b):0:4: b',
                },
              },
            },
          },
        },
        err = {
          arg = '{a : b',
          msg = 'E723: Missing end of Dictionary \'}\': %.*s',
        },
      }, {
        hl('Dict', '{'),
        hl('IdentifierName', 'a'),
        hl('Colon', ':', 1),
        hl('IdentifierName', 'b', 1),
      })
      check_parsing('{a : b,', {
        --           0123456
        ast = {
          {
            'DictLiteral:0:0:{',
            children = {
              {
                'Comma:0:6:,',
                children = {
                  {
                    'Colon:0:2: :',
                    children = {
                      'PlainIdentifier(scope=0,ident=a):0:1:a',
                      'PlainIdentifier(scope=0,ident=b):0:4: b',
                    },
                  },
                },
              },
            },
          },
        },
        err = {
          arg = '',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
        hl('Dict', '{'),
        hl('IdentifierName', 'a'),
        hl('Colon', ':', 1),
        hl('IdentifierName', 'b', 1),
        hl('Comma', ','),
      })
    end)
    it('works with ternary operator', function()
      check_parsing('a ? b : c', {
        --           012345678
        ast = {
          {
            'Ternary:0:1: ?',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              {
                'TernaryValue:0:5: :',
                children = {
                  'PlainIdentifier(scope=0,ident=b):0:3: b',
                  'PlainIdentifier(scope=0,ident=c):0:7: c',
                },
              },
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Ternary', '?', 1),
        hl('IdentifierName', 'b', 1),
        hl('TernaryColon', ':', 1),
        hl('IdentifierName', 'c', 1),
      })
      check_parsing('@a?@b?@c:@d:@e', {
        --           01234567890123
        --           0         1
        ast = {
          {
            'Ternary:0:2:?',
            children = {
              'Register(name=a):0:0:@a',
              {
                'TernaryValue:0:11::',
                children = {
                  {
                    'Ternary:0:5:?',
                    children = {
                      'Register(name=b):0:3:@b',
                      {
                        'TernaryValue:0:8::',
                        children = {
                          'Register(name=c):0:6:@c',
                          'Register(name=d):0:9:@d',
                        },
                      },
                    },
                  },
                  'Register(name=e):0:12:@e',
                },
              },
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('Ternary', '?'),
        hl('Register', '@b'),
        hl('Ternary', '?'),
        hl('Register', '@c'),
        hl('TernaryColon', ':'),
        hl('Register', '@d'),
        hl('TernaryColon', ':'),
        hl('Register', '@e'),
      })
      check_parsing('@a?@b:@c?@d:@e', {
        --           01234567890123
        --           0         1
        ast = {
          {
            'Ternary:0:2:?',
            children = {
              'Register(name=a):0:0:@a',
              {
                'TernaryValue:0:5::',
                children = {
                  'Register(name=b):0:3:@b',
                  {
                    'Ternary:0:8:?',
                    children = {
                      'Register(name=c):0:6:@c',
                      {
                        'TernaryValue:0:11::',
                        children = {
                          'Register(name=d):0:9:@d',
                          'Register(name=e):0:12:@e',
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('Ternary', '?'),
        hl('Register', '@b'),
        hl('TernaryColon', ':'),
        hl('Register', '@c'),
        hl('Ternary', '?'),
        hl('Register', '@d'),
        hl('TernaryColon', ':'),
        hl('Register', '@e'),
      })
      check_parsing('@a?@b?@c?@d:@e?@f:@g:@h?@i:@j:@k', {
        --           01234567890123456789012345678901
        --           0         1         2         3
        ast = {
          {
            'Ternary:0:2:?',
            children = {
              'Register(name=a):0:0:@a',
              {
                'TernaryValue:0:29::',
                children = {
                  {
                    'Ternary:0:5:?',
                    children = {
                      'Register(name=b):0:3:@b',
                      {
                        'TernaryValue:0:20::',
                        children = {
                          {
                            'Ternary:0:8:?',
                            children = {
                              'Register(name=c):0:6:@c',
                              {
                                'TernaryValue:0:11::',
                                children = {
                                  'Register(name=d):0:9:@d',
                                  {
                                    'Ternary:0:14:?',
                                    children = {
                                      'Register(name=e):0:12:@e',
                                      {
                                        'TernaryValue:0:17::',
                                        children = {
                                          'Register(name=f):0:15:@f',
                                          'Register(name=g):0:18:@g',
                                        },
                                      },
                                    },
                                  },
                                },
                              },
                            },
                          },
                          {
                            'Ternary:0:23:?',
                            children = {
                              'Register(name=h):0:21:@h',
                              {
                                'TernaryValue:0:26::',
                                children = {
                                  'Register(name=i):0:24:@i',
                                  'Register(name=j):0:27:@j',
                                },
                              },
                            },
                          },
                        },
                      },
                    },
                  },
                  'Register(name=k):0:30:@k',
                },
              },
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('Ternary', '?'),
        hl('Register', '@b'),
        hl('Ternary', '?'),
        hl('Register', '@c'),
        hl('Ternary', '?'),
        hl('Register', '@d'),
        hl('TernaryColon', ':'),
        hl('Register', '@e'),
        hl('Ternary', '?'),
        hl('Register', '@f'),
        hl('TernaryColon', ':'),
        hl('Register', '@g'),
        hl('TernaryColon', ':'),
        hl('Register', '@h'),
        hl('Ternary', '?'),
        hl('Register', '@i'),
        hl('TernaryColon', ':'),
        hl('Register', '@j'),
        hl('TernaryColon', ':'),
        hl('Register', '@k'),
      })
      check_parsing('?', {
        --           0
        ast = {
          {
            'Ternary:0:0:?',
            children = {
              'Missing:0:0:',
              'TernaryValue:0:0:?',
            },
          },
        },
        err = {
          arg = '?',
          msg = 'E15: Expected value, got question mark: %.*s',
        },
      }, {
        hl('InvalidTernary', '?'),
      })

      check_parsing('?:', {
        --           01
        ast = {
          {
            'Ternary:0:0:?',
            children = {
              'Missing:0:0:',
              {
                'TernaryValue:0:1::',
                children = {
                  'Missing:0:1:',
                },
              },
            },
          },
        },
        err = {
          arg = '?:',
          msg = 'E15: Expected value, got question mark: %.*s',
        },
      }, {
        hl('InvalidTernary', '?'),
        hl('InvalidTernaryColon', ':'),
      })

      check_parsing('?::', {
        --           012
        ast = {
          {
            'Colon:0:2::',
            children = {
              {
                'Ternary:0:0:?',
                children = {
                  'Missing:0:0:',
                  {
                    'TernaryValue:0:1::',
                    children = {
                      'Missing:0:1:',
                      'Missing:0:2:',
                    },
                  },
                },
              },
            },
          },
        },
        err = {
          arg = '?::',
          msg = 'E15: Expected value, got question mark: %.*s',
        },
      }, {
        hl('InvalidTernary', '?'),
        hl('InvalidTernaryColon', ':'),
        hl('InvalidColon', ':'),
      })

      check_parsing('a?b', {
        --           012
        ast = {
          {
            'Ternary:0:1:?',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              {
                'TernaryValue:0:1:?',
                children = {
                  'PlainIdentifier(scope=0,ident=b):0:2:b',
                },
              },
            },
          },
        },
        err = {
          arg = '?b',
          msg = 'E109: Missing \':\' after \'?\': %.*s',
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Ternary', '?'),
        hl('IdentifierName', 'b'),
      })
      check_parsing('a?b:', {
        --           0123
        ast = {
          {
            'Ternary:0:1:?',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              {
                'TernaryValue:0:1:?',
                children = {
                  'PlainIdentifier(scope=b,ident=):0:2:b:',
                },
              },
            },
          },
        },
        err = {
          arg = '?b:',
          msg = 'E109: Missing \':\' after \'?\': %.*s',
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Ternary', '?'),
        hl('IdentifierScope', 'b'),
        hl('IdentifierScopeDelimiter', ':'),
      })

      check_parsing('a?b::c', {
        --           012345
        ast = {
          {
            'Ternary:0:1:?',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              {
                'TernaryValue:0:4::',
                children = {
                  'PlainIdentifier(scope=b,ident=):0:2:b:',
                  'PlainIdentifier(scope=0,ident=c):0:5:c',
                },
              },
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Ternary', '?'),
        hl('IdentifierScope', 'b'),
        hl('IdentifierScopeDelimiter', ':'),
        hl('TernaryColon', ':'),
        hl('IdentifierName', 'c'),
      })

      check_parsing('a?b :', {
        --           01234
        ast = {
          {
            'Ternary:0:1:?',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              {
                'TernaryValue:0:3: :',
                children = {
                  'PlainIdentifier(scope=0,ident=b):0:2:b',
                },
              },
            },
          },
        },
        err = {
          arg = '',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Ternary', '?'),
        hl('IdentifierName', 'b'),
        hl('TernaryColon', ':', 1),
      })

      check_parsing('(@a?@b:@c)?@d:@e', {
        --           0123456789012345
        --           0         1
        ast = {
          {
            'Ternary:0:10:?',
            children = {
              {
                'Nested:0:0:(',
                children = {
                  {
                    'Ternary:0:3:?',
                    children = {
                      'Register(name=a):0:1:@a',
                      {
                        'TernaryValue:0:6::',
                        children = {
                          'Register(name=b):0:4:@b',
                          'Register(name=c):0:7:@c',
                        },
                      },
                    },
                  },
                },
              },
              {
                'TernaryValue:0:13::',
                children = {
                  'Register(name=d):0:11:@d',
                  'Register(name=e):0:14:@e',
                },
              },
            },
          },
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('Register', '@a'),
        hl('Ternary', '?'),
        hl('Register', '@b'),
        hl('TernaryColon', ':'),
        hl('Register', '@c'),
        hl('NestingParenthesis', ')'),
        hl('Ternary', '?'),
        hl('Register', '@d'),
        hl('TernaryColon', ':'),
        hl('Register', '@e'),
      })

      check_parsing('(@a?@b:@c)?(@d?@e:@f):(@g?@h:@i)', {
        --           01234567890123456789012345678901
        --           0         1         2         3
        ast = {
          {
            'Ternary:0:10:?',
            children = {
              {
                'Nested:0:0:(',
                children = {
                  {
                    'Ternary:0:3:?',
                    children = {
                      'Register(name=a):0:1:@a',
                      {
                        'TernaryValue:0:6::',
                        children = {
                          'Register(name=b):0:4:@b',
                          'Register(name=c):0:7:@c',
                        },
                      },
                    },
                  },
                },
              },
              {
                'TernaryValue:0:21::',
                children = {
                  {
                    'Nested:0:11:(',
                    children = {
                      {
                        'Ternary:0:14:?',
                        children = {
                          'Register(name=d):0:12:@d',
                          {
                            'TernaryValue:0:17::',
                            children = {
                              'Register(name=e):0:15:@e',
                              'Register(name=f):0:18:@f',
                            },
                          },
                        },
                      },
                    },
                  },
                  {
                    'Nested:0:22:(',
                    children = {
                      {
                        'Ternary:0:25:?',
                        children = {
                          'Register(name=g):0:23:@g',
                          {
                            'TernaryValue:0:28::',
                            children = {
                              'Register(name=h):0:26:@h',
                              'Register(name=i):0:29:@i',
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('Register', '@a'),
        hl('Ternary', '?'),
        hl('Register', '@b'),
        hl('TernaryColon', ':'),
        hl('Register', '@c'),
        hl('NestingParenthesis', ')'),
        hl('Ternary', '?'),
        hl('NestingParenthesis', '('),
        hl('Register', '@d'),
        hl('Ternary', '?'),
        hl('Register', '@e'),
        hl('TernaryColon', ':'),
        hl('Register', '@f'),
        hl('NestingParenthesis', ')'),
        hl('TernaryColon', ':'),
        hl('NestingParenthesis', '('),
        hl('Register', '@g'),
        hl('Ternary', '?'),
        hl('Register', '@h'),
        hl('TernaryColon', ':'),
        hl('Register', '@i'),
        hl('NestingParenthesis', ')'),
      })

      check_parsing('(@a?@b:@c)?@d?@e:@f:@g?@h:@i', {
        --           0123456789012345678901234567
        --           0         1         2
        ast = {
          {
            'Ternary:0:10:?',
            children = {
              {
                'Nested:0:0:(',
                children = {
                  {
                    'Ternary:0:3:?',
                    children = {
                      'Register(name=a):0:1:@a',
                      {
                        'TernaryValue:0:6::',
                        children = {
                          'Register(name=b):0:4:@b',
                          'Register(name=c):0:7:@c',
                        },
                      },
                    },
                  },
                },
              },
              {
                'TernaryValue:0:19::',
                children = {
                  {
                    'Ternary:0:13:?',
                    children = {
                      'Register(name=d):0:11:@d',
                      {
                        'TernaryValue:0:16::',
                        children = {
                          'Register(name=e):0:14:@e',
                          'Register(name=f):0:17:@f',
                        },
                      },
                    },
                  },
                  {
                    'Ternary:0:22:?',
                    children = {
                      'Register(name=g):0:20:@g',
                      {
                        'TernaryValue:0:25::',
                        children = {
                          'Register(name=h):0:23:@h',
                          'Register(name=i):0:26:@i',
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('Register', '@a'),
        hl('Ternary', '?'),
        hl('Register', '@b'),
        hl('TernaryColon', ':'),
        hl('Register', '@c'),
        hl('NestingParenthesis', ')'),
        hl('Ternary', '?'),
        hl('Register', '@d'),
        hl('Ternary', '?'),
        hl('Register', '@e'),
        hl('TernaryColon', ':'),
        hl('Register', '@f'),
        hl('TernaryColon', ':'),
        hl('Register', '@g'),
        hl('Ternary', '?'),
        hl('Register', '@h'),
        hl('TernaryColon', ':'),
        hl('Register', '@i'),
      })
      check_parsing('a?b{cdef}g:h', {
        --           012345678901
        --           0         1
        ast = {
          {
            'Ternary:0:1:?',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              {
                'TernaryValue:0:10::',
                children = {
                  {
                    'ComplexIdentifier:0:3:',
                    children = {
                      'PlainIdentifier(scope=0,ident=b):0:2:b',
                      {
                        'ComplexIdentifier:0:9:',
                        children = {
                          {
                            'CurlyBracesIdentifier:0:3:{',
                            children = {
                              'PlainIdentifier(scope=0,ident=cdef):0:4:cdef',
                            },
                          },
                          'PlainIdentifier(scope=0,ident=g):0:9:g',
                        },
                      },
                    },
                  },
                  'PlainIdentifier(scope=0,ident=h):0:11:h',
                },
              },
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Ternary', '?'),
        hl('IdentifierName', 'b'),
        hl('Curly', '{'),
        hl('IdentifierName', 'cdef'),
        hl('Curly', '}'),
        hl('IdentifierName', 'g'),
        hl('TernaryColon', ':'),
        hl('IdentifierName', 'h'),
      })
      check_parsing('a ? b : c : d', {
        --           0123456789012
        --           0         1
        ast = {
          {
            'Colon:0:9: :',
            children = {
              {
                'Ternary:0:1: ?',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:0:a',
                  {
                    'TernaryValue:0:5: :',
                    children = {
                      'PlainIdentifier(scope=0,ident=b):0:3: b',
                      'PlainIdentifier(scope=0,ident=c):0:7: c',
                    },
                  },
                },
              },
              'PlainIdentifier(scope=0,ident=d):0:11: d',
            },
          },
        },
        err = {
          arg = ': d',
          msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Ternary', '?', 1),
        hl('IdentifierName', 'b', 1),
        hl('TernaryColon', ':', 1),
        hl('IdentifierName', 'c', 1),
        hl('InvalidColon', ':', 1),
        hl('IdentifierName', 'd', 1),
      })
    end)
    it('works with comparison operators', function()
      check_parsing('a == b', {
        --           012345
        ast = {
          {
            'Comparison(type=Equal,inv=0,ccs=UseOption):0:1: ==',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              'PlainIdentifier(scope=0,ident=b):0:4: b',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Comparison', '==', 1),
        hl('IdentifierName', 'b', 1),
      })

      check_parsing('a ==? b', {
        --           0123456
        ast = {
          {
            'Comparison(type=Equal,inv=0,ccs=IgnoreCase):0:1: ==?',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              'PlainIdentifier(scope=0,ident=b):0:5: b',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Comparison', '==', 1),
        hl('ComparisonModifier', '?'),
        hl('IdentifierName', 'b', 1),
      })

      check_parsing('a ==# b', {
        --           0123456
        ast = {
          {
            'Comparison(type=Equal,inv=0,ccs=MatchCase):0:1: ==#',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              'PlainIdentifier(scope=0,ident=b):0:5: b',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Comparison', '==', 1),
        hl('ComparisonModifier', '#'),
        hl('IdentifierName', 'b', 1),
      })

      check_parsing('a !=# b', {
        --           0123456
        ast = {
          {
            'Comparison(type=Equal,inv=1,ccs=MatchCase):0:1: !=#',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              'PlainIdentifier(scope=0,ident=b):0:5: b',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Comparison', '!=', 1),
        hl('ComparisonModifier', '#'),
        hl('IdentifierName', 'b', 1),
      })

      check_parsing('a <=# b', {
        --           0123456
        ast = {
          {
            'Comparison(type=Greater,inv=1,ccs=MatchCase):0:1: <=#',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              'PlainIdentifier(scope=0,ident=b):0:5: b',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Comparison', '<=', 1),
        hl('ComparisonModifier', '#'),
        hl('IdentifierName', 'b', 1),
      })

      check_parsing('a >=# b', {
        --           0123456
        ast = {
          {
            'Comparison(type=GreaterOrEqual,inv=0,ccs=MatchCase):0:1: >=#',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              'PlainIdentifier(scope=0,ident=b):0:5: b',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Comparison', '>=', 1),
        hl('ComparisonModifier', '#'),
        hl('IdentifierName', 'b', 1),
      })

      check_parsing('a ># b', {
        --           012345
        ast = {
          {
            'Comparison(type=Greater,inv=0,ccs=MatchCase):0:1: >#',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              'PlainIdentifier(scope=0,ident=b):0:4: b',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Comparison', '>', 1),
        hl('ComparisonModifier', '#'),
        hl('IdentifierName', 'b', 1),
      })

      check_parsing('a <# b', {
        --           012345
        ast = {
          {
            'Comparison(type=GreaterOrEqual,inv=1,ccs=MatchCase):0:1: <#',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              'PlainIdentifier(scope=0,ident=b):0:4: b',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Comparison', '<', 1),
        hl('ComparisonModifier', '#'),
        hl('IdentifierName', 'b', 1),
      })

      check_parsing('a is#b', {
        --           012345
        ast = {
          {
            'Comparison(type=Identical,inv=0,ccs=MatchCase):0:1: is#',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              'PlainIdentifier(scope=0,ident=b):0:5:b',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Comparison', 'is', 1),
        hl('ComparisonModifier', '#'),
        hl('IdentifierName', 'b'),
      })

      check_parsing('a is?b', {
        --           012345
        ast = {
          {
            'Comparison(type=Identical,inv=0,ccs=IgnoreCase):0:1: is?',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              'PlainIdentifier(scope=0,ident=b):0:5:b',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Comparison', 'is', 1),
        hl('ComparisonModifier', '?'),
        hl('IdentifierName', 'b'),
      })

      check_parsing('a isnot b', {
        --           012345678
        ast = {
          {
            'Comparison(type=Identical,inv=1,ccs=UseOption):0:1: isnot',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              'PlainIdentifier(scope=0,ident=b):0:7: b',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Comparison', 'isnot', 1),
        hl('IdentifierName', 'b', 1),
      })

      check_parsing('a < b < c', {
        --           012345678
        ast = {
          {
            'Comparison(type=GreaterOrEqual,inv=1,ccs=UseOption):0:1: <',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              {
                'Comparison(type=GreaterOrEqual,inv=1,ccs=UseOption):0:5: <',
                children = {
                  'PlainIdentifier(scope=0,ident=b):0:3: b',
                  'PlainIdentifier(scope=0,ident=c):0:7: c',
                },
              },
            },
          },
        },
        err = {
          arg = ' < c',
          msg = 'E15: Operator is not associative: %.*s',
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Comparison', '<', 1),
        hl('IdentifierName', 'b', 1),
        hl('InvalidComparison', '<', 1),
        hl('IdentifierName', 'c', 1),
      })

      check_parsing('a < b <# c', {
        --           012345678
        ast = {
          {
            'Comparison(type=GreaterOrEqual,inv=1,ccs=UseOption):0:1: <',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              {
                'Comparison(type=GreaterOrEqual,inv=1,ccs=MatchCase):0:5: <#',
                children = {
                  'PlainIdentifier(scope=0,ident=b):0:3: b',
                  'PlainIdentifier(scope=0,ident=c):0:8: c',
                },
              },
            },
          },
        },
        err = {
          arg = ' <# c',
          msg = 'E15: Operator is not associative: %.*s',
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Comparison', '<', 1),
        hl('IdentifierName', 'b', 1),
        hl('InvalidComparison', '<', 1),
        hl('InvalidComparisonModifier', '#'),
        hl('IdentifierName', 'c', 1),
      })

      check_parsing('a += b', {
        --           012345
        ast = {
          {
            'Comparison(type=Equal,inv=0,ccs=UseOption):0:3:=',
            children = {
              {
                'BinaryPlus:0:1: +',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:0:a',
                  'Missing:0:3:',
                },
              },
              'PlainIdentifier(scope=0,ident=b):0:4: b',
            },
          },
        },
        err = {
          arg = '= b',
          msg = 'E15: Expected == or =~: %.*s',
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('BinaryPlus', '+', 1),
        hl('InvalidComparison', '='),
        hl('IdentifierName', 'b', 1),
      })
      check_parsing('a + b == c + d', {
        --           01234567890123
        --           0         1
        ast = {
          {
            'Comparison(type=Equal,inv=0,ccs=UseOption):0:5: ==',
            children = {
              {
                'BinaryPlus:0:1: +',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:0:a',
                  'PlainIdentifier(scope=0,ident=b):0:3: b',
                },
              },
              {
                'BinaryPlus:0:10: +',
                children = {
                  'PlainIdentifier(scope=0,ident=c):0:8: c',
                  'PlainIdentifier(scope=0,ident=d):0:12: d',
                },
              },
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('BinaryPlus', '+', 1),
        hl('IdentifierName', 'b', 1),
        hl('Comparison', '==', 1),
        hl('IdentifierName', 'c', 1),
        hl('BinaryPlus', '+', 1),
        hl('IdentifierName', 'd', 1),
      })
      check_parsing('+ a == + b', {
        --           0123456789
        ast = {
          {
            'Comparison(type=Equal,inv=0,ccs=UseOption):0:3: ==',
            children = {
              {
                'UnaryPlus:0:0:+',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1: a',
                },
              },
              {
                'UnaryPlus:0:6: +',
                children = {
                  'PlainIdentifier(scope=0,ident=b):0:8: b',
                },
              },
            },
          },
        },
      }, {
        hl('UnaryPlus', '+'),
        hl('IdentifierName', 'a', 1),
        hl('Comparison', '==', 1),
        hl('UnaryPlus', '+', 1),
        hl('IdentifierName', 'b', 1),
      })
    end)
    it('works with concat/subscript', function()
      check_parsing('.', {
        --           0
        ast = {
          {
            'ConcatOrSubscript:0:0:.',
            children = {
              'Missing:0:0:',
            },
          },
        },
        err = {
          arg = '.',
          msg = 'E15: Unexpected dot: %.*s',
        },
      }, {
        hl('InvalidConcatOrSubscript', '.'),
      })

      check_parsing('a.', {
        --           01
        ast = {
          {
            'ConcatOrSubscript:0:1:.',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
            },
          },
        },
        err = {
          arg = '',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('ConcatOrSubscript', '.'),
      })

      check_parsing('a.b', {
        --           012
        ast = {
          {
            'ConcatOrSubscript:0:1:.',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              'PlainKey(key=b):0:2:b',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('ConcatOrSubscript', '.'),
        hl('IdentifierKey', 'b'),
      })

      check_parsing('1.2', {
        --           012
        ast = {
          'Float(val=1.200000e+00):0:0:1.2',
        },
      }, {
        hl('Float', '1.2'),
      })

      check_parsing('1.2 + 1.3e-5', {
        --           012345678901
        --           0         1
        ast = {
          {
            'BinaryPlus:0:3: +',
            children = {
              'Float(val=1.200000e+00):0:0:1.2',
              'Float(val=1.300000e-05):0:5: 1.3e-5',
            },
          },
        },
      }, {
        hl('Float', '1.2'),
        hl('BinaryPlus', '+', 1),
        hl('Float', '1.3e-5', 1),
      })

      check_parsing('a . 1.2 + 1.3e-5', {
        --           0123456789012345
        --           0         1
        ast = {
          {
            'BinaryPlus:0:7: +',
            children = {
              {
                'Concat:0:1: .',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:0:a',
                  {
                    'ConcatOrSubscript:0:5:.',
                    children = {
                      'Integer(val=1):0:3: 1',
                      'PlainKey(key=2):0:6:2',
                    },
                  },
                },
              },
              'Float(val=1.300000e-05):0:9: 1.3e-5',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Concat', '.', 1),
        hl('Number', '1', 1),
        hl('ConcatOrSubscript', '.'),
        hl('IdentifierKey', '2'),
        hl('BinaryPlus', '+', 1),
        hl('Float', '1.3e-5', 1),
      })

      check_parsing('1.3e-5 + 1.2 . a', {
        --           0123456789012345
        --           0         1
        ast = {
          {
            'Concat:0:12: .',
            children = {
              {
                'BinaryPlus:0:6: +',
                children = {
                  'Float(val=1.300000e-05):0:0:1.3e-5',
                  'Float(val=1.200000e+00):0:8: 1.2',
                },
              },
              'PlainIdentifier(scope=0,ident=a):0:14: a',
            },
          },
        },
      }, {
        hl('Float', '1.3e-5'),
        hl('BinaryPlus', '+', 1),
        hl('Float', '1.2', 1),
        hl('Concat', '.', 1),
        hl('IdentifierName', 'a', 1),
      })

      check_parsing('1.3e-5 + a . 1.2', {
        --           0123456789012345
        --           0         1
        ast = {
          {
            'Concat:0:10: .',
            children = {
              {
                'BinaryPlus:0:6: +',
                children = {
                  'Float(val=1.300000e-05):0:0:1.3e-5',
                  'PlainIdentifier(scope=0,ident=a):0:8: a',
                },
              },
              {
                'ConcatOrSubscript:0:14:.',
                children = {
                  'Integer(val=1):0:12: 1',
                  'PlainKey(key=2):0:15:2',
                },
              },
            },
          },
        },
      }, {
        hl('Float', '1.3e-5'),
        hl('BinaryPlus', '+', 1),
        hl('IdentifierName', 'a', 1),
        hl('Concat', '.', 1),
        hl('Number', '1', 1),
        hl('ConcatOrSubscript', '.'),
        hl('IdentifierKey', '2'),
      })

      check_parsing('1.2.3', {
        --           01234
        ast = {
          {
            'ConcatOrSubscript:0:3:.',
            children = {
              {
                'ConcatOrSubscript:0:1:.',
                children = {
                  'Integer(val=1):0:0:1',
                  'PlainKey(key=2):0:2:2',
                },
              },
              'PlainKey(key=3):0:4:3',
            },
          },
        },
      }, {
        hl('Number', '1'),
        hl('ConcatOrSubscript', '.'),
        hl('IdentifierKey', '2'),
        hl('ConcatOrSubscript', '.'),
        hl('IdentifierKey', '3'),
      })

      check_parsing('a.1.2', {
        --           01234
        ast = {
          {
            'ConcatOrSubscript:0:3:.',
            children = {
              {
                'ConcatOrSubscript:0:1:.',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:0:a',
                  'PlainKey(key=1):0:2:1',
                },
              },
              'PlainKey(key=2):0:4:2',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('ConcatOrSubscript', '.'),
        hl('IdentifierKey', '1'),
        hl('ConcatOrSubscript', '.'),
        hl('IdentifierKey', '2'),
      })

      check_parsing('a . 1.2', {
        --           0123456
        ast = {
          {
            'Concat:0:1: .',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              {
                'ConcatOrSubscript:0:5:.',
                children = {
                  'Integer(val=1):0:3: 1',
                  'PlainKey(key=2):0:6:2',
                },
              },
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Concat', '.', 1),
        hl('Number', '1', 1),
        hl('ConcatOrSubscript', '.'),
        hl('IdentifierKey', '2'),
      })

      check_parsing('+a . +b', {
        --           0123456
        ast = {
          {
            'Concat:0:2: .',
            children = {
              {
                'UnaryPlus:0:0:+',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                },
              },
              {
                'UnaryPlus:0:4: +',
                children = {
                  'PlainIdentifier(scope=0,ident=b):0:6:b',
                },
              },
            },
          },
        },
      }, {
        hl('UnaryPlus', '+'),
        hl('IdentifierName', 'a'),
        hl('Concat', '.', 1),
        hl('UnaryPlus', '+', 1),
        hl('IdentifierName', 'b'),
      })

      check_parsing('a. b', {
        --           0123
        ast = {
          {
            'Concat:0:1:.',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              'PlainIdentifier(scope=0,ident=b):0:2: b',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('ConcatOrSubscript', '.'),
        hl('IdentifierName', 'b', 1),
      })

      check_parsing('a. 1', {
        --           0123
        ast = {
          {
            'Concat:0:1:.',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              'Integer(val=1):0:2: 1',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('ConcatOrSubscript', '.'),
        hl('Number', '1', 1),
      })
    end)
    it('works with bracket subscripts', function()
      check_parsing(':', {
        --           0
        ast = {
          {
            'Colon:0:0::',
            children = {
              'Missing:0:0:',
            },
          },
        },
        err = {
          arg = ':',
          msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
        },
      }, {
        hl('InvalidColon', ':'),
      })
      check_parsing('a[]', {
        --           012
        ast = {
          {
            'Subscript:0:1:[',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
            },
          },
        },
        err = {
          arg = ']',
          msg = 'E15: Expected value, got closing bracket: %.*s',
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('SubscriptBracket', '['),
        hl('InvalidSubscriptBracket', ']'),
      })
      check_parsing('a[b:]', {
        --           01234
        ast = {
          {
            'Subscript:0:1:[',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              'PlainIdentifier(scope=b,ident=):0:2:b:',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('SubscriptBracket', '['),
        hl('IdentifierScope', 'b'),
        hl('IdentifierScopeDelimiter', ':'),
        hl('SubscriptBracket', ']'),
      })

      check_parsing('a[b:c]', {
        --           012345
        ast = {
          {
            'Subscript:0:1:[',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              'PlainIdentifier(scope=b,ident=c):0:2:b:c',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('SubscriptBracket', '['),
        hl('IdentifierScope', 'b'),
        hl('IdentifierScopeDelimiter', ':'),
        hl('IdentifierName', 'c'),
        hl('SubscriptBracket', ']'),
      })
      check_parsing('a[b : c]', {
        --           01234567
        ast = {
          {
            'Subscript:0:1:[',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              {
                'Colon:0:3: :',
                children = {
                  'PlainIdentifier(scope=0,ident=b):0:2:b',
                  'PlainIdentifier(scope=0,ident=c):0:5: c',
                },
              },
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('SubscriptBracket', '['),
        hl('IdentifierName', 'b'),
        hl('SubscriptColon', ':', 1),
        hl('IdentifierName', 'c', 1),
        hl('SubscriptBracket', ']'),
      })

      check_parsing('a[: b]', {
        --           012345
        ast = {
          {
            'Subscript:0:1:[',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              {
                'Colon:0:2::',
                children = {
                  'Missing:0:2:',
                  'PlainIdentifier(scope=0,ident=b):0:3: b',
                },
              },
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('SubscriptBracket', '['),
        hl('SubscriptColon', ':'),
        hl('IdentifierName', 'b', 1),
        hl('SubscriptBracket', ']'),
      })

      check_parsing('a[b :]', {
        --           012345
        ast = {
          {
            'Subscript:0:1:[',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
              {
                'Colon:0:3: :',
                children = {
                  'PlainIdentifier(scope=0,ident=b):0:2:b',
                },
              },
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('SubscriptBracket', '['),
        hl('IdentifierName', 'b'),
        hl('SubscriptColon', ':', 1),
        hl('SubscriptBracket', ']'),
      })
      check_parsing('a[b][c][d](e)(f)(g)', {
        --           0123456789012345678
        --           0         1
        ast = {
          {
            'Call:0:16:(',
            children = {
              {
                'Call:0:13:(',
                children = {
                  {
                    'Call:0:10:(',
                    children = {
                      {
                        'Subscript:0:7:[',
                        children = {
                          {
                            'Subscript:0:4:[',
                            children = {
                              {
                                'Subscript:0:1:[',
                                children = {
                                  'PlainIdentifier(scope=0,ident=a):0:0:a',
                                  'PlainIdentifier(scope=0,ident=b):0:2:b',
                                },
                              },
                              'PlainIdentifier(scope=0,ident=c):0:5:c',
                            },
                          },
                          'PlainIdentifier(scope=0,ident=d):0:8:d',
                        },
                      },
                      'PlainIdentifier(scope=0,ident=e):0:11:e',
                    },
                  },
                  'PlainIdentifier(scope=0,ident=f):0:14:f',
                },
              },
              'PlainIdentifier(scope=0,ident=g):0:17:g',
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('SubscriptBracket', '['),
        hl('IdentifierName', 'b'),
        hl('SubscriptBracket', ']'),
        hl('SubscriptBracket', '['),
        hl('IdentifierName', 'c'),
        hl('SubscriptBracket', ']'),
        hl('SubscriptBracket', '['),
        hl('IdentifierName', 'd'),
        hl('SubscriptBracket', ']'),
        hl('CallingParenthesis', '('),
        hl('IdentifierName', 'e'),
        hl('CallingParenthesis', ')'),
        hl('CallingParenthesis', '('),
        hl('IdentifierName', 'f'),
        hl('CallingParenthesis', ')'),
        hl('CallingParenthesis', '('),
        hl('IdentifierName', 'g'),
        hl('CallingParenthesis', ')'),
      })
      check_parsing('{a}{b}{c}[d][e][f]', {
        --           012345678901234567
        --           0         1
        ast = {
          {
            'Subscript:0:15:[',
            children = {
              {
                'Subscript:0:12:[',
                children = {
                  {
                    'Subscript:0:9:[',
                    children = {
                      {
                        'ComplexIdentifier:0:3:',
                        children = {
                          {
                            'CurlyBracesIdentifier:0:0:{',
                            children = {
                              'PlainIdentifier(scope=0,ident=a):0:1:a',
                            },
                          },
                          {
                            'ComplexIdentifier:0:6:',
                            children = {
                              {
                                'CurlyBracesIdentifier:0:3:{',
                                children = {
                                  'PlainIdentifier(scope=0,ident=b):0:4:b',
                                },
                              },
                              {
                                'CurlyBracesIdentifier:0:6:{',
                                children = {
                                  'PlainIdentifier(scope=0,ident=c):0:7:c',
                                },
                              },
                            },
                          },
                        },
                      },
                      'PlainIdentifier(scope=0,ident=d):0:10:d',
                    },
                  },
                  'PlainIdentifier(scope=0,ident=e):0:13:e',
                },
              },
              'PlainIdentifier(scope=0,ident=f):0:16:f',
            },
          },
        },
      }, {
        hl('Curly', '{'),
        hl('IdentifierName', 'a'),
        hl('Curly', '}'),
        hl('Curly', '{'),
        hl('IdentifierName', 'b'),
        hl('Curly', '}'),
        hl('Curly', '{'),
        hl('IdentifierName', 'c'),
        hl('Curly', '}'),
        hl('SubscriptBracket', '['),
        hl('IdentifierName', 'd'),
        hl('SubscriptBracket', ']'),
        hl('SubscriptBracket', '['),
        hl('IdentifierName', 'e'),
        hl('SubscriptBracket', ']'),
        hl('SubscriptBracket', '['),
        hl('IdentifierName', 'f'),
        hl('SubscriptBracket', ']'),
      })
    end)
    it('supports list literals', function()
      check_parsing('[]', {
        --           01
        ast = {
          'ListLiteral:0:0:[',
        },
      }, {
        hl('List', '['),
        hl('List', ']'),
      })

      check_parsing('[a]', {
        --           012
        ast = {
          {
            'ListLiteral:0:0:[',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:1:a',
            },
          },
        },
      }, {
        hl('List', '['),
        hl('IdentifierName', 'a'),
        hl('List', ']'),
      })

      check_parsing('[a, b]', {
        --           012345
        ast = {
          {
            'ListLiteral:0:0:[',
            children = {
              {
                'Comma:0:2:,',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                  'PlainIdentifier(scope=0,ident=b):0:3: b',
                },
              },
            },
          },
        },
      }, {
        hl('List', '['),
        hl('IdentifierName', 'a'),
        hl('Comma', ','),
        hl('IdentifierName', 'b', 1),
        hl('List', ']'),
      })

      check_parsing('[a, b, c]', {
        --           012345678
        ast = {
          {
            'ListLiteral:0:0:[',
            children = {
              {
                'Comma:0:2:,',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                  {
                    'Comma:0:5:,',
                    children = {
                      'PlainIdentifier(scope=0,ident=b):0:3: b',
                      'PlainIdentifier(scope=0,ident=c):0:6: c',
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('List', '['),
        hl('IdentifierName', 'a'),
        hl('Comma', ','),
        hl('IdentifierName', 'b', 1),
        hl('Comma', ','),
        hl('IdentifierName', 'c', 1),
        hl('List', ']'),
      })

      check_parsing('[a, b, c, ]', {
        --           01234567890
        --           0         1
        ast = {
          {
            'ListLiteral:0:0:[',
            children = {
              {
                'Comma:0:2:,',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                  {
                    'Comma:0:5:,',
                    children = {
                      'PlainIdentifier(scope=0,ident=b):0:3: b',
                      {
                        'Comma:0:8:,',
                        children = {
                          'PlainIdentifier(scope=0,ident=c):0:6: c',
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      }, {
        hl('List', '['),
        hl('IdentifierName', 'a'),
        hl('Comma', ','),
        hl('IdentifierName', 'b', 1),
        hl('Comma', ','),
        hl('IdentifierName', 'c', 1),
        hl('Comma', ','),
        hl('List', ']', 1),
      })

      check_parsing('[a : b, c : d]', {
        --           01234567890123
        --           0         1
        ast = {
          {
            'ListLiteral:0:0:[',
            children = {
              {
                'Comma:0:6:,',
                children = {
                  {
                    'Colon:0:2: :',
                    children = {
                      'PlainIdentifier(scope=0,ident=a):0:1:a',
                      'PlainIdentifier(scope=0,ident=b):0:4: b',
                    },
                  },
                  {
                    'Colon:0:9: :',
                    children = {
                      'PlainIdentifier(scope=0,ident=c):0:7: c',
                      'PlainIdentifier(scope=0,ident=d):0:11: d',
                    },
                  },
                },
              },
            },
          },
        },
        err = {
          arg = ': b, c : d]',
          msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
        },
      }, {
        hl('List', '['),
        hl('IdentifierName', 'a'),
        hl('InvalidColon', ':', 1),
        hl('IdentifierName', 'b', 1),
        hl('Comma', ','),
        hl('IdentifierName', 'c', 1),
        hl('InvalidColon', ':', 1),
        hl('IdentifierName', 'd', 1),
        hl('List', ']'),
      })

      check_parsing(']', {
        --           0
        ast = {
          'ListLiteral:0:0:',
        },
        err = {
          arg = ']',
          msg = 'E15: Unexpected closing figure brace: %.*s',
        },
      }, {
        hl('InvalidList', ']'),
      })

      check_parsing('a]', {
        --           01
        ast = {
          {
            'ListLiteral:0:1:',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
            },
          },
        },
        err = {
          arg = ']',
          msg = 'E15: Unexpected closing figure brace: %.*s',
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('InvalidList', ']'),
      })

      check_parsing('[] []', {
        --           01234
        ast = {
          {
            'OpMissing:0:2:',
            children = {
              'ListLiteral:0:0:[',
              'ListLiteral:0:2: [',
            },
          },
        },
        err = {
          arg = '[]',
          msg = 'E15: Missing operator: %.*s',
        },
      }, {
        hl('List', '['),
        hl('List', ']'),
        hl('InvalidSpacing', ' '),
        hl('List', '['),
        hl('List', ']'),
      }, {
        [1] = {
          ast = {
            len = 3,
            err = REMOVE_THIS,
            ast = {
              'ListLiteral:0:0:[',
            },
          },
          hl_fs = {
            [3] = REMOVE_THIS,
            [4] = REMOVE_THIS,
            [5] = REMOVE_THIS,
          },
        },
      })

      check_parsing('[][]', {
        --           0123
        ast = {
          {
            'Subscript:0:2:[',
            children = {
              'ListLiteral:0:0:[',
            },
          },
        },
        err = {
          arg = ']',
          msg = 'E15: Expected value, got closing bracket: %.*s',
        },
      }, {
        hl('List', '['),
        hl('List', ']'),
        hl('SubscriptBracket', '['),
        hl('InvalidSubscriptBracket', ']'),
      })

      check_parsing('[', {
        --           0
        ast = {
          'ListLiteral:0:0:[',
        },
        err = {
          arg = '',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
        hl('List', '['),
      })

      check_parsing('[1', {
        --           01
        ast = {
          {
            'ListLiteral:0:0:[',
            children = {
              'Integer(val=1):0:1:1',
            },
          },
        },
        err = {
          arg = '[1',
          msg = 'E697: Missing end of List \']\': %.*s',
        },
      }, {
        hl('List', '['),
        hl('Number', '1'),
      })
    end)
    it('works with strings', function()
      check_parsing('\'abc\'', {
        --           01234
        ast = {
          'SingleQuotedString(val="abc"):0:0:\'abc\'',
        },
      }, {
        hl('SingleQuote', '\''),
        hl('SingleQuotedBody', 'abc'),
        hl('SingleQuote', '\''),
      })
      check_parsing('"abc"', {
        --           01234
        ast = {
          'DoubleQuotedString(val="abc"):0:0:"abc"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedBody', 'abc'),
        hl('DoubleQuote', '"'),
      })
      check_parsing('\'\'', {
        --           01
        ast = {
          'SingleQuotedString(val=""):0:0:\'\'',
        },
      }, {
        hl('SingleQuote', '\''),
        hl('SingleQuote', '\''),
      })
      check_parsing('""', {
        --           01
        ast = {
          'DoubleQuotedString(val=""):0:0:""',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuote', '"'),
      })
      check_parsing('"', {
        --           0
        ast = {
          'DoubleQuotedString(val=""):0:0:"',
        },
        err = {
          arg = '"',
          msg = 'E114: Missing double quote: %.*s',
        },
      }, {
        hl('InvalidDoubleQuote', '"'),
      })
      check_parsing('\'', {
        --           0
        ast = {
          'SingleQuotedString(val=""):0:0:\'',
        },
        err = {
          arg = '\'',
          msg = 'E115: Missing single quote: %.*s',
        },
      }, {
        hl('InvalidSingleQuote', '\''),
      })
      check_parsing('"a', {
        --           01
        ast = {
          'DoubleQuotedString(val="a"):0:0:"a',
        },
        err = {
          arg = '"a',
          msg = 'E114: Missing double quote: %.*s',
        },
      }, {
        hl('InvalidDoubleQuote', '"'),
        hl('InvalidDoubleQuotedBody', 'a'),
      })
      check_parsing('\'a', {
        --           01
        ast = {
          'SingleQuotedString(val="a"):0:0:\'a',
        },
        err = {
          arg = '\'a',
          msg = 'E115: Missing single quote: %.*s',
        },
      }, {
        hl('InvalidSingleQuote', '\''),
        hl('InvalidSingleQuotedBody', 'a'),
      })
      check_parsing('\'abc\'\'def\'', {
        --           0123456789
        ast = {
          'SingleQuotedString(val="abc\'def"):0:0:\'abc\'\'def\'',
        },
      }, {
        hl('SingleQuote', '\''),
        hl('SingleQuotedBody', 'abc'),
        hl('SingleQuotedQuote', '\'\''),
        hl('SingleQuotedBody', 'def'),
        hl('SingleQuote', '\''),
      })
      check_parsing('\'abc\'\'', {
        --           012345
        ast = {
          'SingleQuotedString(val="abc\'"):0:0:\'abc\'\'',
        },
        err = {
          arg = '\'abc\'\'',
          msg = 'E115: Missing single quote: %.*s',
        },
      }, {
        hl('InvalidSingleQuote', '\''),
        hl('InvalidSingleQuotedBody', 'abc'),
        hl('InvalidSingleQuotedQuote', '\'\''),
      })
      check_parsing('\'\'\'\'\'\'\'\'', {
        --           01234567
        ast = {
          'SingleQuotedString(val="\'\'\'"):0:0:\'\'\'\'\'\'\'\'',
        },
      }, {
        hl('SingleQuote', '\''),
        hl('SingleQuotedQuote', '\'\''),
        hl('SingleQuotedQuote', '\'\''),
        hl('SingleQuotedQuote', '\'\''),
        hl('SingleQuote', '\''),
      })
      check_parsing('\'\'\'a\'\'\'\'bc\'', {
        --           01234567890
        --           0         1
        ast = {
          'SingleQuotedString(val="\'a\'\'bc"):0:0:\'\'\'a\'\'\'\'bc\'',
        },
      }, {
        hl('SingleQuote', '\''),
        hl('SingleQuotedQuote', '\'\''),
        hl('SingleQuotedBody', 'a'),
        hl('SingleQuotedQuote', '\'\''),
        hl('SingleQuotedQuote', '\'\''),
        hl('SingleQuotedBody', 'bc'),
        hl('SingleQuote', '\''),
      })
      check_parsing('"\\"\\"\\"\\""', {
        --           0123456789
        ast = {
          'DoubleQuotedString(val="\\"\\"\\"\\""):0:0:"\\"\\"\\"\\""',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\"'),
        hl('DoubleQuotedEscape', '\\"'),
        hl('DoubleQuotedEscape', '\\"'),
        hl('DoubleQuotedEscape', '\\"'),
        hl('DoubleQuote', '"'),
      })
      check_parsing('"abc\\"def\\"ghi\\"jkl\\"mno"', {
        --           0123456789012345678901234
        --           0         1         2
        ast = {
          'DoubleQuotedString(val="abc\\"def\\"ghi\\"jkl\\"mno"):0:0:"abc\\"def\\"ghi\\"jkl\\"mno"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedBody', 'abc'),
        hl('DoubleQuotedEscape', '\\"'),
        hl('DoubleQuotedBody', 'def'),
        hl('DoubleQuotedEscape', '\\"'),
        hl('DoubleQuotedBody', 'ghi'),
        hl('DoubleQuotedEscape', '\\"'),
        hl('DoubleQuotedBody', 'jkl'),
        hl('DoubleQuotedEscape', '\\"'),
        hl('DoubleQuotedBody', 'mno'),
        hl('DoubleQuote', '"'),
      })
      check_parsing('"\\b\\e\\f\\r\\t\\\\"', {
        --           0123456789012345
        --           0         1
        ast = {
          [[DoubleQuotedString(val="\8\27\12\13\9\\"):0:0:"\b\e\f\r\t\\"]],
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\b'),
        hl('DoubleQuotedEscape', '\\e'),
        hl('DoubleQuotedEscape', '\\f'),
        hl('DoubleQuotedEscape', '\\r'),
        hl('DoubleQuotedEscape', '\\t'),
        hl('DoubleQuotedEscape', '\\\\'),
        hl('DoubleQuote', '"'),
      })
      check_parsing('"\\n\n"', {
        --           01234
        ast = {
          'DoubleQuotedString(val="\\\n\\\n"):0:0:"\\n\n"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\n'),
        hl('DoubleQuotedBody', '\n'),
        hl('DoubleQuote', '"'),
      })
      check_parsing('"\\x00"', {
        --           012345
        ast = {
          'DoubleQuotedString(val="\\0"):0:0:"\\x00"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\x00'),
        hl('DoubleQuote', '"'),
      })
      check_parsing('"\\xFF"', {
        --           012345
        ast = {
          'DoubleQuotedString(val="\255"):0:0:"\\xFF"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\xFF'),
        hl('DoubleQuote', '"'),
      })
      check_parsing('"\\xF"', {
        --           012345
        ast = {
          'DoubleQuotedString(val="\\15"):0:0:"\\xF"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\xF'),
        hl('DoubleQuote', '"'),
      })
      check_parsing('"\\u00AB"', {
        --           01234567
        ast = {
          'DoubleQuotedString(val="«"):0:0:"\\u00AB"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\u00AB'),
        hl('DoubleQuote', '"'),
      })
      check_parsing('"\\U000000AB"', {
        --           01234567
        ast = {
          'DoubleQuotedString(val="«"):0:0:"\\U000000AB"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\U000000AB'),
        hl('DoubleQuote', '"'),
      })
      check_parsing('"\\x"', {
        --           0123
        ast = {
          'DoubleQuotedString(val="x"):0:0:"\\x"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedUnknownEscape', '\\x'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\x', {
        --           012
        ast = {
          'DoubleQuotedString(val="x"):0:0:"\\x',
        },
        err = {
          arg = '"\\x',
          msg = 'E114: Missing double quote: %.*s',
        },
      }, {
        hl('InvalidDoubleQuote', '"'),
        hl('InvalidDoubleQuotedUnknownEscape', '\\x'),
      })

      check_parsing('"\\xF', {
        --           0123
        ast = {
          'DoubleQuotedString(val="\\15"):0:0:"\\xF',
        },
        err = {
          arg = '"\\xF',
          msg = 'E114: Missing double quote: %.*s',
        },
      }, {
        hl('InvalidDoubleQuote', '"'),
        hl('InvalidDoubleQuotedEscape', '\\xF'),
      })

      check_parsing('"\\u"', {
        --           0123
        ast = {
          'DoubleQuotedString(val="u"):0:0:"\\u"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedUnknownEscape', '\\u'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\u', {
        --           012
        ast = {
          'DoubleQuotedString(val="u"):0:0:"\\u',
        },
        err = {
          arg = '"\\u',
          msg = 'E114: Missing double quote: %.*s',
        },
      }, {
        hl('InvalidDoubleQuote', '"'),
        hl('InvalidDoubleQuotedUnknownEscape', '\\u'),
      })

      check_parsing('"\\U', {
        --           012
        ast = {
          'DoubleQuotedString(val="U"):0:0:"\\U',
        },
        err = {
          arg = '"\\U',
          msg = 'E114: Missing double quote: %.*s',
        },
      }, {
        hl('InvalidDoubleQuote', '"'),
        hl('InvalidDoubleQuotedUnknownEscape', '\\U'),
      })

      check_parsing('"\\U"', {
        --           0123
        ast = {
          'DoubleQuotedString(val="U"):0:0:"\\U"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedUnknownEscape', '\\U'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\xFX"', {
        --           012345
        ast = {
          'DoubleQuotedString(val="\\15X"):0:0:"\\xFX"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\xF'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\XFX"', {
        --           012345
        ast = {
          'DoubleQuotedString(val="\\15X"):0:0:"\\XFX"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\XF'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\xX"', {
        --           01234
        ast = {
          'DoubleQuotedString(val="xX"):0:0:"\\xX"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedUnknownEscape', '\\x'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\XX"', {
        --           01234
        ast = {
          'DoubleQuotedString(val="XX"):0:0:"\\XX"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedUnknownEscape', '\\X'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\uX"', {
        --           01234
        ast = {
          'DoubleQuotedString(val="uX"):0:0:"\\uX"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedUnknownEscape', '\\u'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\UX"', {
        --           01234
        ast = {
          'DoubleQuotedString(val="UX"):0:0:"\\UX"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedUnknownEscape', '\\U'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\x0X"', {
        --           012345
        ast = {
          'DoubleQuotedString(val="\\0X"):0:0:"\\x0X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\x0'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\X0X"', {
        --           012345
        ast = {
          'DoubleQuotedString(val="\\0X"):0:0:"\\X0X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\X0'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\u0X"', {
        --           012345
        ast = {
          'DoubleQuotedString(val="\\0X"):0:0:"\\u0X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\u0'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\U0X"', {
        --           012345
        ast = {
          'DoubleQuotedString(val="\\0X"):0:0:"\\U0X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\U0'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\x00X"', {
        --           0123456
        ast = {
          'DoubleQuotedString(val="\\0X"):0:0:"\\x00X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\x00'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\X00X"', {
        --           0123456
        ast = {
          'DoubleQuotedString(val="\\0X"):0:0:"\\X00X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\X00'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\u00X"', {
        --           0123456
        ast = {
          'DoubleQuotedString(val="\\0X"):0:0:"\\u00X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\u00'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\U00X"', {
        --           0123456
        ast = {
          'DoubleQuotedString(val="\\0X"):0:0:"\\U00X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\U00'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\u000X"', {
        --           01234567
        ast = {
          'DoubleQuotedString(val="\\0X"):0:0:"\\u000X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\u000'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\U000X"', {
        --           01234567
        ast = {
          'DoubleQuotedString(val="\\0X"):0:0:"\\U000X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\U000'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\u0000X"', {
        --           012345678
        ast = {
          'DoubleQuotedString(val="\\0X"):0:0:"\\u0000X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\u0000'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\U0000X"', {
        --           012345678
        ast = {
          'DoubleQuotedString(val="\\0X"):0:0:"\\U0000X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\U0000'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\U00000X"', {
        --           0123456789
        ast = {
          'DoubleQuotedString(val="\\0X"):0:0:"\\U00000X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\U00000'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\U000000X"', {
        --           01234567890
        --           0         1
        ast = {
          'DoubleQuotedString(val="\\0X"):0:0:"\\U000000X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\U000000'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\U0000000X"', {
        --           012345678901
        --           0         1
        ast = {
          'DoubleQuotedString(val="\\0X"):0:0:"\\U0000000X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\U0000000'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\U00000000X"', {
        --           0123456789012
        --           0         1
        ast = {
          'DoubleQuotedString(val="\\0X"):0:0:"\\U00000000X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\U00000000'),
        hl('DoubleQuotedBody', 'X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\x000X"', {
        --           01234567
        ast = {
          'DoubleQuotedString(val="\\0000X"):0:0:"\\x000X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\x00'),
        hl('DoubleQuotedBody', '0X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\X000X"', {
        --           01234567
        ast = {
          'DoubleQuotedString(val="\\0000X"):0:0:"\\X000X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\X00'),
        hl('DoubleQuotedBody', '0X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\u00000X"', {
        --           0123456789
        ast = {
          'DoubleQuotedString(val="\\0000X"):0:0:"\\u00000X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\u0000'),
        hl('DoubleQuotedBody', '0X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\U000000000X"', {
        --           01234567890123
        --           0         1
        ast = {
          'DoubleQuotedString(val="\\0000X"):0:0:"\\U000000000X"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\U00000000'),
        hl('DoubleQuotedBody', '0X'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\0"', {
        --           0123
        ast = {
          'DoubleQuotedString(val="\\0"):0:0:"\\0"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\0'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\00"', {
        --           01234
        ast = {
          'DoubleQuotedString(val="\\0"):0:0:"\\00"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\00'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\000"', {
        --           012345
        ast = {
          'DoubleQuotedString(val="\\0"):0:0:"\\000"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\000'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\0000"', {
        --           0123456
        ast = {
          'DoubleQuotedString(val="\\0000"):0:0:"\\0000"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\000'),
        hl('DoubleQuotedBody', '0'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\8"', {
        --           0123
        ast = {
          'DoubleQuotedString(val="8"):0:0:"\\8"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedUnknownEscape', '\\8'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\08"', {
        --           01234
        ast = {
          'DoubleQuotedString(val="\\0008"):0:0:"\\08"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\0'),
        hl('DoubleQuotedBody', '8'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\008"', {
        --           012345
        ast = {
          'DoubleQuotedString(val="\\0008"):0:0:"\\008"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\00'),
        hl('DoubleQuotedBody', '8'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\0008"', {
        --           0123456
        ast = {
          'DoubleQuotedString(val="\\0008"):0:0:"\\0008"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\000'),
        hl('DoubleQuotedBody', '8'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\777"', {
        --           012345
        ast = {
          'DoubleQuotedString(val="\255"):0:0:"\\777"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\777'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\050"', {
        --           012345
        ast = {
          'DoubleQuotedString(val="\40"):0:0:"\\050"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\050'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\<C-u>"', {
        --           012345
        ast = {
          'DoubleQuotedString(val="\\21"):0:0:"\\<C-u>"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedEscape', '\\<C-u>'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\<', {
        --           012
        ast = {
          'DoubleQuotedString(val="<"):0:0:"\\<',
        },
        err = {
          arg = '"\\<',
          msg = 'E114: Missing double quote: %.*s',
        },
      }, {
        hl('InvalidDoubleQuote', '"'),
        hl('InvalidDoubleQuotedUnknownEscape', '\\<'),
      })

      check_parsing('"\\<"', {
        --           0123
        ast = {
          'DoubleQuotedString(val="<"):0:0:"\\<"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedUnknownEscape', '\\<'),
        hl('DoubleQuote', '"'),
      })

      check_parsing('"\\<C-u"', {
        --           0123456
        ast = {
          'DoubleQuotedString(val="<C-u"):0:0:"\\<C-u"',
        },
      }, {
        hl('DoubleQuote', '"'),
        hl('DoubleQuotedUnknownEscape', '\\<'),
        hl('DoubleQuotedBody', 'C-u'),
        hl('DoubleQuote', '"'),
      })
    end)
    it('works with multiplication-like operators', function()
      check_parsing('2+2*2', {
        --           01234
        ast = {
          {
            'BinaryPlus:0:1:+',
            children = {
              'Integer(val=2):0:0:2',
              {
                'Multiplication:0:3:*',
                children = {
                  'Integer(val=2):0:2:2',
                  'Integer(val=2):0:4:2',
                },
              },
            },
          },
        },
      }, {
        hl('Number', '2'),
        hl('BinaryPlus', '+'),
        hl('Number', '2'),
        hl('Multiplication', '*'),
        hl('Number', '2'),
      })

      check_parsing('2+2*', {
        --           0123
        ast = {
          {
            'BinaryPlus:0:1:+',
            children = {
              'Integer(val=2):0:0:2',
              {
                'Multiplication:0:3:*',
                children = {
                  'Integer(val=2):0:2:2',
                },
              },
            },
          },
        },
        err = {
          arg = '',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
        hl('Number', '2'),
        hl('BinaryPlus', '+'),
        hl('Number', '2'),
        hl('Multiplication', '*'),
      })

      check_parsing('2+*2', {
        --           0123
        ast = {
          {
            'BinaryPlus:0:1:+',
            children = {
              'Integer(val=2):0:0:2',
              {
                'Multiplication:0:2:*',
                children = {
                  'Missing:0:2:',
                  'Integer(val=2):0:3:2',
                },
              },
            },
          },
        },
        err = {
          arg = '*2',
          msg = 'E15: Unexpected multiplication-like operator: %.*s',
        },
      }, {
        hl('Number', '2'),
        hl('BinaryPlus', '+'),
        hl('InvalidMultiplication', '*'),
        hl('Number', '2'),
      })

      check_parsing('2+2/2', {
        --           01234
        ast = {
          {
            'BinaryPlus:0:1:+',
            children = {
              'Integer(val=2):0:0:2',
              {
                'Division:0:3:/',
                children = {
                  'Integer(val=2):0:2:2',
                  'Integer(val=2):0:4:2',
                },
              },
            },
          },
        },
      }, {
        hl('Number', '2'),
        hl('BinaryPlus', '+'),
        hl('Number', '2'),
        hl('Division', '/'),
        hl('Number', '2'),
      })

      check_parsing('2+2/', {
        --           0123
        ast = {
          {
            'BinaryPlus:0:1:+',
            children = {
              'Integer(val=2):0:0:2',
              {
                'Division:0:3:/',
                children = {
                  'Integer(val=2):0:2:2',
                },
              },
            },
          },
        },
        err = {
          arg = '',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
        hl('Number', '2'),
        hl('BinaryPlus', '+'),
        hl('Number', '2'),
        hl('Division', '/'),
      })

      check_parsing('2+/2', {
        --           0123
        ast = {
          {
            'BinaryPlus:0:1:+',
            children = {
              'Integer(val=2):0:0:2',
              {
                'Division:0:2:/',
                children = {
                  'Missing:0:2:',
                  'Integer(val=2):0:3:2',
                },
              },
            },
          },
        },
        err = {
          arg = '/2',
          msg = 'E15: Unexpected multiplication-like operator: %.*s',
        },
      }, {
        hl('Number', '2'),
        hl('BinaryPlus', '+'),
        hl('InvalidDivision', '/'),
        hl('Number', '2'),
      })

      check_parsing('2+2%2', {
        --           01234
        ast = {
          {
            'BinaryPlus:0:1:+',
            children = {
              'Integer(val=2):0:0:2',
              {
                'Mod:0:3:%',
                children = {
                  'Integer(val=2):0:2:2',
                  'Integer(val=2):0:4:2',
                },
              },
            },
          },
        },
      }, {
        hl('Number', '2'),
        hl('BinaryPlus', '+'),
        hl('Number', '2'),
        hl('Mod', '%'),
        hl('Number', '2'),
      })

      check_parsing('2+2%', {
        --           0123
        ast = {
          {
            'BinaryPlus:0:1:+',
            children = {
              'Integer(val=2):0:0:2',
              {
                'Mod:0:3:%',
                children = {
                  'Integer(val=2):0:2:2',
                },
              },
            },
          },
        },
        err = {
          arg = '',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
        hl('Number', '2'),
        hl('BinaryPlus', '+'),
        hl('Number', '2'),
        hl('Mod', '%'),
      })

      check_parsing('2+%2', {
        --           0123
        ast = {
          {
            'BinaryPlus:0:1:+',
            children = {
              'Integer(val=2):0:0:2',
              {
                'Mod:0:2:%',
                children = {
                  'Missing:0:2:',
                  'Integer(val=2):0:3:2',
                },
              },
            },
          },
        },
        err = {
          arg = '%2',
          msg = 'E15: Unexpected multiplication-like operator: %.*s',
        },
      }, {
        hl('Number', '2'),
        hl('BinaryPlus', '+'),
        hl('InvalidMod', '%'),
        hl('Number', '2'),
      })
    end)
    it('works with -', function()
      check_parsing('@a', {
        ast = {
          'Register(name=a):0:0:@a',
        },
      }, {
        hl('Register', '@a'),
      })
      check_parsing('-@a', {
        ast = {
          {
            'UnaryMinus:0:0:-',
            children = {
              'Register(name=a):0:1:@a',
            },
          },
        },
      }, {
        hl('UnaryMinus', '-'),
        hl('Register', '@a'),
      })
      check_parsing('@a-@b', {
        ast = {
          {
            'BinaryMinus:0:2:-',
            children = {
              'Register(name=a):0:0:@a',
              'Register(name=b):0:3:@b',
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('BinaryMinus', '-'),
        hl('Register', '@b'),
      })
      check_parsing('@a-@b-@c', {
        ast = {
          {
            'BinaryMinus:0:5:-',
            children = {
              {
                'BinaryMinus:0:2:-',
                children = {
                  'Register(name=a):0:0:@a',
                  'Register(name=b):0:3:@b',
                },
              },
              'Register(name=c):0:6:@c',
            },
          },
        },
      }, {
        hl('Register', '@a'),
        hl('BinaryMinus', '-'),
        hl('Register', '@b'),
        hl('BinaryMinus', '-'),
        hl('Register', '@c'),
      })
      check_parsing('-@a-@b', {
        ast = {
          {
            'BinaryMinus:0:3:-',
            children = {
              {
                'UnaryMinus:0:0:-',
                children = {
                  'Register(name=a):0:1:@a',
                },
              },
              'Register(name=b):0:4:@b',
            },
          },
        },
      }, {
        hl('UnaryMinus', '-'),
        hl('Register', '@a'),
        hl('BinaryMinus', '-'),
        hl('Register', '@b'),
      })
      check_parsing('-@a--@b', {
        ast = {
          {
            'BinaryMinus:0:3:-',
            children = {
              {
                'UnaryMinus:0:0:-',
                children = {
                  'Register(name=a):0:1:@a',
                },
              },
              {
                'UnaryMinus:0:4:-',
                children = {
                  'Register(name=b):0:5:@b',
                },
              },
            },
          },
        },
      }, {
        hl('UnaryMinus', '-'),
        hl('Register', '@a'),
        hl('BinaryMinus', '-'),
        hl('UnaryMinus', '-'),
        hl('Register', '@b'),
      })
      check_parsing('-', {
        ast = {
          'UnaryMinus:0:0:-',
        },
        err = {
          arg = '',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
        hl('UnaryMinus', '-'),
      })
      check_parsing(' -', {
        ast = {
          'UnaryMinus:0:0: -',
        },
        err = {
          arg = '',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
        hl('UnaryMinus', '-', 1),
      })
      check_parsing('@a-  ', {
        ast = {
          {
            'BinaryMinus:0:2:-',
            children = {
              'Register(name=a):0:0:@a',
            },
          },
        },
        err = {
          arg = '',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
        hl('Register', '@a'),
        hl('BinaryMinus', '-'),
      })
    end)
    it('works with logical operators', function()
      check_parsing('a && b || c && d', {
        --           0123456789012345
        --           0         1
        ast = {
          {
            'Or:0:6: ||',
            children = {
              {
                'And:0:1: &&',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:0:a',
                  'PlainIdentifier(scope=0,ident=b):0:4: b',
                },
              },
              {
                'And:0:11: &&',
                children = {
                  'PlainIdentifier(scope=0,ident=c):0:9: c',
                  'PlainIdentifier(scope=0,ident=d):0:14: d',
                },
              },
            },
          },
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('And', '&&', 1),
        hl('IdentifierName', 'b', 1),
        hl('Or', '||', 1),
        hl('IdentifierName', 'c', 1),
        hl('And', '&&', 1),
        hl('IdentifierName', 'd', 1),
      })

      check_parsing('&& a', {
        --           0123
        ast = {
          {
            'And:0:0:&&',
            children = {
              'Missing:0:0:',
              'PlainIdentifier(scope=0,ident=a):0:2: a',
            },
          },
        },
        err = {
          arg = '&& a',
          msg = 'E15: Unexpected and operator: %.*s',
        },
      }, {
        hl('InvalidAnd', '&&'),
        hl('IdentifierName', 'a', 1),
      })

      check_parsing('|| a', {
        --           0123
        ast = {
          {
            'Or:0:0:||',
            children = {
              'Missing:0:0:',
              'PlainIdentifier(scope=0,ident=a):0:2: a',
            },
          },
        },
        err = {
          arg = '|| a',
          msg = 'E15: Unexpected or operator: %.*s',
        },
      }, {
        hl('InvalidOr', '||'),
        hl('IdentifierName', 'a', 1),
      })

      check_parsing('a||', {
        --           012
        ast = {
          {
            'Or:0:1:||',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
            },
          },
        },
        err = {
          arg = '',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('Or', '||'),
      })

      check_parsing('a&&', {
        --           012
        ast = {
          {
            'And:0:1:&&',
            children = {
              'PlainIdentifier(scope=0,ident=a):0:0:a',
            },
          },
        },
        err = {
          arg = '',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
        hl('IdentifierName', 'a'),
        hl('And', '&&'),
      })

      check_parsing('(&&)', {
        --           0123
        ast = {
          {
            'Nested:0:0:(',
            children = {
              {
                'And:0:1:&&',
                children = {
                  'Missing:0:1:',
                  'Missing:0:3:',
                },
              },
            },
          },
        },
        err = {
          arg = '&&)',
          msg = 'E15: Unexpected and operator: %.*s',
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('InvalidAnd', '&&'),
        hl('InvalidNestingParenthesis', ')'),
      })

      check_parsing('(||)', {
        --           0123
        ast = {
          {
            'Nested:0:0:(',
            children = {
              {
                'Or:0:1:||',
                children = {
                  'Missing:0:1:',
                  'Missing:0:3:',
                },
              },
            },
          },
        },
        err = {
          arg = '||)',
          msg = 'E15: Unexpected or operator: %.*s',
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('InvalidOr', '||'),
        hl('InvalidNestingParenthesis', ')'),
      })

      check_parsing('(a||)', {
        --           01234
        ast = {
          {
            'Nested:0:0:(',
            children = {
              {
                'Or:0:2:||',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                  'Missing:0:4:',
                },
              },
            },
          },
        },
        err = {
          arg = ')',
          msg = 'E15: Expected value, got parenthesis: %.*s',
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('IdentifierName', 'a'),
        hl('Or', '||'),
        hl('InvalidNestingParenthesis', ')'),
      })

      check_parsing('(a&&)', {
        --           01234
        ast = {
          {
            'Nested:0:0:(',
            children = {
              {
                'And:0:2:&&',
                children = {
                  'PlainIdentifier(scope=0,ident=a):0:1:a',
                  'Missing:0:4:',
                },
              },
            },
          },
        },
        err = {
          arg = ')',
          msg = 'E15: Expected value, got parenthesis: %.*s',
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('IdentifierName', 'a'),
        hl('And', '&&'),
        hl('InvalidNestingParenthesis', ')'),
      })

      check_parsing('(&&a)', {
        --           01234
        ast = {
          {
            'Nested:0:0:(',
            children = {
              {
                'And:0:1:&&',
                children = {
                  'Missing:0:1:',
                  'PlainIdentifier(scope=0,ident=a):0:3:a',
                },
              },
            },
          },
        },
        err = {
          arg = '&&a)',
          msg = 'E15: Unexpected and operator: %.*s',
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('InvalidAnd', '&&'),
        hl('IdentifierName', 'a'),
        hl('NestingParenthesis', ')'),
      })

      check_parsing('(||a)', {
        --           01234
        ast = {
          {
            'Nested:0:0:(',
            children = {
              {
                'Or:0:1:||',
                children = {
                  'Missing:0:1:',
                  'PlainIdentifier(scope=0,ident=a):0:3:a',
                },
              },
            },
          },
        },
        err = {
          arg = '||a)',
          msg = 'E15: Unexpected or operator: %.*s',
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('InvalidOr', '||'),
        hl('IdentifierName', 'a'),
        hl('NestingParenthesis', ')'),
      })
    end)
    it('works with &opt', function()
      check_parsing('&', {
        --           0
        ast = {
          'Option(scope=0,ident=):0:0:&',
        },
        err = {
          arg = '&',
          msg = 'E112: Option name missing: %.*s',
        },
      }, {
        hl('InvalidOptionSigil', '&'),
      })

      check_parsing('&opt', {
        --           0123
        ast = {
          'Option(scope=0,ident=opt):0:0:&opt',
        },
      }, {
        hl('OptionSigil', '&'),
        hl('OptionName', 'opt'),
      })

      check_parsing('&l:opt', {
        --           012345
        ast = {
          'Option(scope=l,ident=opt):0:0:&l:opt',
        },
      }, {
        hl('OptionSigil', '&'),
        hl('OptionScope', 'l'),
        hl('OptionScopeDelimiter', ':'),
        hl('OptionName', 'opt'),
      })

      check_parsing('&g:opt', {
        --           012345
        ast = {
          'Option(scope=g,ident=opt):0:0:&g:opt',
        },
      }, {
        hl('OptionSigil', '&'),
        hl('OptionScope', 'g'),
        hl('OptionScopeDelimiter', ':'),
        hl('OptionName', 'opt'),
      })

      check_parsing('&s:opt', {
        --           012345
        ast = {
          {
            'Colon:0:2::',
            children = {
              'Option(scope=0,ident=s):0:0:&s',
              'PlainIdentifier(scope=0,ident=opt):0:3:opt',
            },
          },
        },
        err = {
          arg = ':opt',
          msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
        },
      }, {
        hl('OptionSigil', '&'),
        hl('OptionName', 's'),
        hl('InvalidColon', ':'),
        hl('IdentifierName', 'opt'),
      })

      check_parsing('& ', {
        --           01
        ast = {
          'Option(scope=0,ident=):0:0:&',
        },
        err = {
          arg = '& ',
          msg = 'E112: Option name missing: %.*s',
        },
      }, {
        hl('InvalidOptionSigil', '&'),
      })

      check_parsing('&-', {
        --           01
        ast = {
          {
            'BinaryMinus:0:1:-',
            children = {
              'Option(scope=0,ident=):0:0:&',
            },
          },
        },
        err = {
          arg = '&-',
          msg = 'E112: Option name missing: %.*s',
        },
      }, {
        hl('InvalidOptionSigil', '&'),
        hl('BinaryMinus', '-'),
      })

      check_parsing('&A', {
        --           01
        ast = {
          'Option(scope=0,ident=A):0:0:&A',
        },
      }, {
        hl('OptionSigil', '&'),
        hl('OptionName', 'A'),
      })

      check_parsing('&xxx_yyy', {
        --           01234567
        ast = {
          {
            'OpMissing:0:4:',
            children = {
              'Option(scope=0,ident=xxx):0:0:&xxx',
              'PlainIdentifier(scope=0,ident=_yyy):0:4:_yyy',
            },
          },
        },
        err = {
          arg = '_yyy',
          msg = 'E15: Missing operator: %.*s',
        },
      }, {
        hl('OptionSigil', '&'),
        hl('OptionName', 'xxx'),
        hl('InvalidIdentifierName', '_yyy'),
      }, {
        [1] = {
          ast = {
            len = 4,
            err = REMOVE_THIS,
            ast = {
              'Option(scope=0,ident=xxx):0:0:&xxx',
            },
          },
          hl_fs = {
            [3] = REMOVE_THIS,
          },
        },
      })

      check_parsing('(1+&)', {
        --           01234
        ast = {
          {
            'Nested:0:0:(',
            children = {
              {
                'BinaryPlus:0:2:+',
                children = {
                  'Integer(val=1):0:1:1',
                  'Option(scope=0,ident=):0:3:&',
                },
              },
            },
          },
        },
        err = {
          arg = '&)',
          msg = 'E112: Option name missing: %.*s',
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('Number', '1'),
        hl('BinaryPlus', '+'),
        hl('InvalidOptionSigil', '&'),
        hl('NestingParenthesis', ')'),
      })

      check_parsing('(&+1)', {
        --           01234
        ast = {
          {
            'Nested:0:0:(',
            children = {
              {
                'BinaryPlus:0:2:+',
                children = {
                  'Option(scope=0,ident=):0:1:&',
                  'Integer(val=1):0:3:1',
                },
              },
            },
          },
        },
        err = {
          arg = '&+1)',
          msg = 'E112: Option name missing: %.*s',
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('InvalidOptionSigil', '&'),
        hl('BinaryPlus', '+'),
        hl('Number', '1'),
        hl('NestingParenthesis', ')'),
      })
    end)
    it('works with $ENV', function()
      check_parsing('$', {
        --           0
        ast = {
          'Environment(ident=):0:0:$',
        },
        err = {
          arg = '$',
          msg = 'E15: Environment variable name missing',
        },
      }, {
        hl('InvalidEnvironmentSigil', '$'),
      })

      check_parsing('$g:A', {
        --           0123
        ast = {
          {
            'Colon:0:2::',
            children = {
              'Environment(ident=g):0:0:$g',
              'PlainIdentifier(scope=0,ident=A):0:3:A',
            },
          },
        },
        err = {
          arg = ':A',
          msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
        },
      }, {
        hl('EnvironmentSigil', '$'),
        hl('EnvironmentName', 'g'),
        hl('InvalidColon', ':'),
        hl('IdentifierName', 'A'),
      })

      check_parsing('$A', {
        --           01
        ast = {
          'Environment(ident=A):0:0:$A',
        },
      }, {
        hl('EnvironmentSigil', '$'),
        hl('EnvironmentName', 'A'),
      })

      check_parsing('$ABC', {
        --           0123
        ast = {
          'Environment(ident=ABC):0:0:$ABC',
        },
      }, {
        hl('EnvironmentSigil', '$'),
        hl('EnvironmentName', 'ABC'),
      })

      check_parsing('(1+$)', {
        --           01234
        ast = {
          {
            'Nested:0:0:(',
            children = {
              {
                'BinaryPlus:0:2:+',
                children = {
                  'Integer(val=1):0:1:1',
                  'Environment(ident=):0:3:$',
                },
              },
            },
          },
        },
        err = {
          arg = '$)',
          msg = 'E15: Environment variable name missing',
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('Number', '1'),
        hl('BinaryPlus', '+'),
        hl('InvalidEnvironmentSigil', '$'),
        hl('NestingParenthesis', ')'),
      })

      check_parsing('($+1)', {
        --           01234
        ast = {
          {
            'Nested:0:0:(',
            children = {
              {
                'BinaryPlus:0:2:+',
                children = {
                  'Environment(ident=):0:1:$',
                  'Integer(val=1):0:3:1',
                },
              },
            },
          },
        },
        err = {
          arg = '$+1)',
          msg = 'E15: Environment variable name missing',
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('InvalidEnvironmentSigil', '$'),
        hl('BinaryPlus', '+'),
        hl('Number', '1'),
        hl('NestingParenthesis', ')'),
      })

      check_parsing('$_ABC', {
        --           01234
        ast = {
          'Environment(ident=_ABC):0:0:$_ABC',
        },
      }, {
        hl('EnvironmentSigil', '$'),
        hl('EnvironmentName', '_ABC'),
      })

      check_parsing('$_', {
        --           01
        ast = {
          'Environment(ident=_):0:0:$_',
        },
      }, {
        hl('EnvironmentSigil', '$'),
        hl('EnvironmentName', '_'),
      })

      check_parsing('$ABC_DEF', {
        --           01234567
        ast = {
          'Environment(ident=ABC_DEF):0:0:$ABC_DEF',
        },
      }, {
        hl('EnvironmentSigil', '$'),
        hl('EnvironmentName', 'ABC_DEF'),
      })
    end)
    it('works with unary !', function()
      check_parsing('!', {
        --           0
        ast = {
          'Not:0:0:!',
        },
        err = {
          arg = '',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
        hl('Not', '!'),
      })

      check_parsing('!!', {
        --           01
        ast = {
          {
            'Not:0:0:!',
            children = {
              'Not:0:1:!',
            },
          },
        },
        err = {
          arg = '',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
        hl('Not', '!'),
        hl('Not', '!'),
      })

      check_parsing('!!1', {
        --           012
        ast = {
          {
            'Not:0:0:!',
            children = {
              {
                'Not:0:1:!',
                children = {
                  'Integer(val=1):0:2:1',
                },
              },
            },
          },
        },
      }, {
        hl('Not', '!'),
        hl('Not', '!'),
        hl('Number', '1'),
      })

      check_parsing('!1', {
        --           01
        ast = {
          {
            'Not:0:0:!',
            children = {
              'Integer(val=1):0:1:1',
            },
          },
        },
      }, {
        hl('Not', '!'),
        hl('Number', '1'),
      })

      check_parsing('(!1)', {
        --           0123
        ast = {
          {
            'Nested:0:0:(',
            children = {
              {
                'Not:0:1:!',
                children = {
                  'Integer(val=1):0:2:1',
                },
              },
            },
          },
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('Not', '!'),
        hl('Number', '1'),
        hl('NestingParenthesis', ')'),
      })

      check_parsing('(!)', {
        --           012
        ast = {
          {
            'Nested:0:0:(',
            children = {
              {
                'Not:0:1:!',
                children = {
                  'Missing:0:2:',
                },
              },
            },
          },
        },
        err = {
          arg = ')',
          msg = 'E15: Expected value, got parenthesis: %.*s',
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('Not', '!'),
        hl('InvalidNestingParenthesis', ')'),
      })

      check_parsing('(1!2)', {
        --           01234
        ast = {
          {
            'Nested:0:0:(',
            children = {
              {
                'OpMissing:0:2:',
                children = {
                  'Integer(val=1):0:1:1',
                  {
                    'Not:0:2:!',
                    children = {
                      'Integer(val=2):0:3:2',
                    },
                  },
                },
              },
            },
          },
        },
        err = {
          arg = '!2)',
          msg = 'E15: Missing operator: %.*s',
        },
      }, {
        hl('NestingParenthesis', '('),
        hl('Number', '1'),
        hl('InvalidNot', '!'),
        hl('Number', '2'),
        hl('NestingParenthesis', ')'),
      })

      check_parsing('1!2', {
        --           012
        ast = {
          {
            'OpMissing:0:1:',
            children = {
              'Integer(val=1):0:0:1',
              {
                'Not:0:1:!',
                children = {
                  'Integer(val=2):0:2:2',
                },
              },
            },
          },
        },
        err = {
          arg = '!2',
          msg = 'E15: Missing operator: %.*s',
        },
      }, {
        hl('Number', '1'),
        hl('InvalidNot', '!'),
        hl('Number', '2'),
      }, {
        [1] = {
          ast = {
            len = 1,
            err = REMOVE_THIS,
            ast = {
              'Integer(val=1):0:0:1',
            },
          },
          hl_fs = {
            [2] = REMOVE_THIS,
            [3] = REMOVE_THIS,
          },
        },
      })
    end)
    it('highlights numbers with prefix', function()
      check_parsing('0xABCDEF', {
        --           01234567
        ast = {
          'Integer(val=11259375):0:0:0xABCDEF',
        },
      }, {
        hl('NumberPrefix', '0x'),
        hl('Number', 'ABCDEF'),
      })

      check_parsing('0Xabcdef', {
        --           01234567
        ast = {
          'Integer(val=11259375):0:0:0Xabcdef',
        },
      }, {
        hl('NumberPrefix', '0X'),
        hl('Number', 'abcdef'),
      })

      check_parsing('0XABCDEF', {
        --           01234567
        ast = {
          'Integer(val=11259375):0:0:0XABCDEF',
        },
      }, {
        hl('NumberPrefix', '0X'),
        hl('Number', 'ABCDEF'),
      })

      check_parsing('0xabcdef', {
        --           01234567
        ast = {
          'Integer(val=11259375):0:0:0xabcdef',
        },
      }, {
        hl('NumberPrefix', '0x'),
        hl('Number', 'abcdef'),
      })

      check_parsing('0b001', {
        --           01234
        ast = {
          'Integer(val=1):0:0:0b001',
        },
      }, {
        hl('NumberPrefix', '0b'),
        hl('Number', '001'),
      })

      check_parsing('0B001', {
        --           01234
        ast = {
          'Integer(val=1):0:0:0B001',
        },
      }, {
        hl('NumberPrefix', '0B'),
        hl('Number', '001'),
      })

      check_parsing('0B00', {
        --           0123
        ast = {
          'Integer(val=0):0:0:0B00',
        },
      }, {
        hl('NumberPrefix', '0B'),
        hl('Number', '00'),
      })

      check_parsing('00', {
        --           01
        ast = {
          'Integer(val=0):0:0:00',
        },
      }, {
        hl('NumberPrefix', '0'),
        hl('Number', '0'),
      })

      check_parsing('001', {
        --           012
        ast = {
          'Integer(val=1):0:0:001',
        },
      }, {
        hl('NumberPrefix', '0'),
        hl('Number', '01'),
      })

      check_parsing('01', {
        --           01
        ast = {
          'Integer(val=1):0:0:01',
        },
      }, {
        hl('NumberPrefix', '0'),
        hl('Number', '1'),
      })

      check_parsing('1', {
        --           0
        ast = {
          'Integer(val=1):0:0:1',
        },
      }, {
        hl('Number', '1'),
      })
    end)
    it('errors out on unknown flags', function()
      eq({false, 'Invalid flag: \'F\' (70)'},
         meth_pcall(meths.parse_expression, '', 'F', true))
      eq({false, 'Invalid flag: \'\\0\' (0)'},
         meth_pcall(meths.parse_expression, '', '\0', true))
      eq({false, 'Invalid flag: \'\1\' (1)'},
         meth_pcall(meths.parse_expression, '', 'm\1E', true))
    end)
    it('respects highlight argument', function()
      eq({
        len = 1,
        ast = {
          ivalue = 1,
          len = 1,
          start = {0, 0},
          type = 'Integer'
        },
      }, meths.parse_expression('1', '', false))
      eq({
        len = 1,
        ast = {
          ivalue = 1,
          len = 1,
          start = {0, 0},
          type = 'Integer'
        },
        highlight = {
          {0, 0, 1, 'NVimNumber'}
        },
      }, meths.parse_expression('1', '', true))
    end)
    it('works (KLEE tests)', function()
      check_parsing('\0002&A:\000', {
        ast = {},
        len = 0,
        err = {
          arg = '\0002&A:\0',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
      }, {
        [2] = {
          ast = {
            len = REMOVE_THIS,
            ast = {
              {
                'Colon:0:4::',
                children = {
                  {
                    'OpMissing:0:2:',
                    children = {
                      'Integer(val=2):0:1:2',
                      'Option(scope=0,ident=A):0:2:&A',
                    },
                  },
                },
              },
            },
            err = {
              msg = 'E15: Unexpected EOC character: %.*s',
            },
          },
          hl_fs = {
            hl('InvalidSpacing', '\0'),
            hl('Number', '2'),
            hl('InvalidOptionSigil', '&'),
            hl('InvalidOptionName', 'A'),
            hl('InvalidColon', ':'),
            hl('InvalidSpacing', '\0'),
          },
        },
        [3] = {
          ast = {
            len = 2,
            ast = {
              'Integer(val=2):0:1:2',
            },
            err = {
              msg = 'E15: Unexpected EOC character: %.*s',
            },
          },
          hl_fs = {
            hl('InvalidSpacing', '\0'),
            hl('Number', '2'),
          },
        },
      })
      check_parsing('"\\U\\', {
        --           0123
        ast = {
          [[DoubleQuotedString(val="U\\"):0:0:"\U\]],
        },
        err = {
          arg = '"\\U\\',
          msg = 'E114: Missing double quote: %.*s',
        },
      }, {
        hl('InvalidDoubleQuote', '"'),
        hl('InvalidDoubleQuotedUnknownEscape', '\\U'),
        hl('InvalidDoubleQuotedBody', '\\'),
      })
      check_parsing('"\\U', {
        --           012
        ast = {
          'DoubleQuotedString(val="U"):0:0:"\\U',
        },
        err = {
          arg = '"\\U',
          msg = 'E114: Missing double quote: %.*s',
        },
      }, {
        hl('InvalidDoubleQuote', '"'),
        hl('InvalidDoubleQuotedUnknownEscape', '\\U'),
      })
      check_parsing('|"\\U\\', {
        --           01234
        ast = {},
        len = 0,
        err = {
          arg = '|"\\U\\',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
      }, {
        [2] = {
          ast = {
            len = REMOVE_THIS,
            ast = {
              {
                'Or:0:0:|',
                children = {
                  'Missing:0:0:',
                  'DoubleQuotedString(val="U\\\\"):0:1:"\\U\\',
                },
              },
            },
            err = {
              msg = 'E15: Unexpected EOC character: %.*s',
            },
          },
          hl_fs = {
            hl('InvalidOr', '|'),
            hl('InvalidDoubleQuote', '"'),
            hl('InvalidDoubleQuotedUnknownEscape', '\\U'),
            hl('InvalidDoubleQuotedBody', '\\'),
          },
        },
      })
      check_parsing('|"\\e"', {
        --           01234
        ast = {},
        len = 0,
        err = {
          arg = '|"\\e"',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
      }, {
        [2] = {
          ast = {
            len = REMOVE_THIS,
            ast = {
              {
                'Or:0:0:|',
                children = {
                  'Missing:0:0:',
                  'DoubleQuotedString(val="\\27"):0:1:"\\e"',
                },
              },
            },
            err = {
              msg = 'E15: Unexpected EOC character: %.*s',
            },
          },
          hl_fs = {
            hl('InvalidOr', '|'),
            hl('DoubleQuote', '"'),
            hl('DoubleQuotedEscape', '\\e'),
            hl('DoubleQuote', '"'),
          },
        },
      })
      check_parsing('|\029', {
        --           01
        ast = {},
        len = 0,
        err = {
          arg = '|\029',
          msg = 'E15: Expected value, got EOC: %.*s',
        },
      }, {
      }, {
        [2] = {
          ast = {
            len = REMOVE_THIS,
            ast = {
              {
                'Or:0:0:|',
                children = {
                  'Missing:0:0:',
                  'PlainIdentifier(scope=0,ident=\029):0:1:\029',
                },
              },
            },
            err = {
              msg = 'E15: Unexpected EOC character: %.*s',
            },
          },
          hl_fs = {
            hl('InvalidOr', '|'),
            hl('InvalidIdentifierName', '\029'),
          },
        },
      })
      check_parsing('"\\<', {
        --           012
        ast = {
          'DoubleQuotedString(val="<"):0:0:"\\<',
        },
        err = {
          arg = '"\\<',
          msg = 'E114: Missing double quote: %.*s',
        },
      }, {
        hl('InvalidDoubleQuote', '"'),
        hl('InvalidDoubleQuotedUnknownEscape', '\\<'),
      })
      check_parsing('"\\1', {
        --           012
        ast = {
          'DoubleQuotedString(val="\\1"):0:0:"\\1',
        },
        err = {
          arg = '"\\1',
          msg = 'E114: Missing double quote: %.*s',
        },
      }, {
        hl('InvalidDoubleQuote', '"'),
        hl('InvalidDoubleQuotedEscape', '\\1'),
      })
      check_parsing('}l', {
        --           01
        ast = {
          {
            'OpMissing:0:1:',
            children = {
              'UnknownFigure:0:0:',
              'PlainIdentifier(scope=0,ident=l):0:1:l',
            },
          },
        },
        err = {
          arg = '}l',
          msg = 'E15: Unexpected closing figure brace: %.*s',
        },
      }, {
        hl('InvalidFigureBrace', '}'),
        hl('InvalidIdentifierName', 'l'),
      }, {
        [1] = {
          ast = {
            len = 1,
            ast = {
              'UnknownFigure:0:0:',
            },
          },
          hl_fs = {
            [2] = REMOVE_THIS,
          },
        },
      })
      check_parsing(':?\000\000\000\000\000\000\000', {
        ast = {
          {
            'Colon:0:0::',
            children = {
              'Missing:0:0:',
              {
                'Ternary:0:1:?',
                children = {
                  'Missing:0:1:',
                  'TernaryValue:0:1:?',
                },
              },
            },
          },
        },
        len = 2,
        err = {
          arg = ':?\000\000\000\000\000\000\000',
          msg = 'E15: Colon outside of dictionary or ternary operator: %.*s',
        },
      }, {
        hl('InvalidColon', ':'),
        hl('InvalidTernary', '?'),
      }, {
        [2] = {
          ast = {
            len = REMOVE_THIS,
          },
          hl_fs = {
            [3] = hl('InvalidSpacing', '\0'),
            [4] = hl('InvalidSpacing', '\0'),
            [5] = hl('InvalidSpacing', '\0'),
            [6] = hl('InvalidSpacing', '\0'),
            [7] = hl('InvalidSpacing', '\0'),
            [8] = hl('InvalidSpacing', '\0'),
            [9] = hl('InvalidSpacing', '\0'),
          },
        },
      })
    end)
  end)

end)
