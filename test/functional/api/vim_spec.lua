-- Sanity checks for vim_* API calls via msgpack-rpc
local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local NIL = helpers.NIL
local clear, nvim, eq, neq = helpers.clear, helpers.nvim, helpers.eq, helpers.neq
local ok, nvim_async, feed = helpers.ok, helpers.nvim_async, helpers.feed
local os_name = helpers.os_name
local meths = helpers.meths
local funcs = helpers.funcs
local request = helpers.request

describe('vim_* functions', function()
  before_each(clear)

  describe('command', function()
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
  end)

  describe('eval', function()
    it('works', function()
      nvim('command', 'let g:v1 = "a"')
      nvim('command', 'let g:v2 = [1, 2, {"v3": 3}]')
      eq({v1 = 'a', v2 = {1, 2, {v3 = 3}}}, nvim('eval', 'g:'))
    end)

    it('handles NULL-initialized strings correctly', function()
      eq(1, nvim('eval',"matcharg(1) == ['', '']"))
      eq({'', ''}, nvim('eval','matcharg(1)'))
    end)

    it('works under deprecated name', function()
      eq(2, request("vim_eval", "1+1"))
    end)
  end)

  describe('call_function', function()
    it('works', function()
      nvim('call_function', 'setqflist', {{{ filename = 'something', lnum = 17}}, 'r'})
      eq(17, nvim('call_function', 'getqflist', {})[1].lnum)
      eq(17, nvim('call_function', 'eval', {17}))
      eq('foo', nvim('call_function', 'simplify', {'this/./is//redundant/../../../foo'}))
    end)
  end)

  describe('call_dict_function', function()
    it('works for vim variable dict', function()
      helpers.execute('function! F(name) dict\n  return self.greeting . ", " . a:name . "!"\nendfunction')
      nvim('set_var', 'dict_function_dict', { greeting = 'Hello', F = 'function("F")' })
      eq('Hello, World!', nvim('call_dict_function', 'g:dict_function_dict', false, 'F', {'World'}))
      eq({ greeting = 'Hello', F = 'function("F")' }, nvim('get_var', 'dict_function_dict'))
      nvim('set_var', 'dict_function_dict_i', { greeting = 'Hi', F = "F" })
      eq('Hi, Moon!', nvim('call_dict_function', 'g:dict_function_dict_i', true, 'F', {'Moon'}))
      eq({ greeting = 'Hi', F = "F" }, nvim('get_var', 'dict_function_dict_i'))
    end)
    it('works for a msgpack-rpc dict', function()
      helpers.execute('function! G() dict\n  return self.result\nendfunction')
      eq('self', nvim('call_dict_function', { result = 'self', G = 'G'}, false, 'G', {}))
    end)
    it('fails for a msgpack-rpc dictionary and internal set to true', function()
      local status, err = pcall(nvim, 'call_dict_function', { f = '' }, true, 'f', {1,2})
      ok(err:match('Function references are not supported') ~= nil)
    end)
    it('fails for an empty function name', function()
      local status, err = pcall(nvim, 'call_dict_function', "{ 'f': '' }", true, 'f', {1,2})
      ok(err:match('Trying to call an empty function') ~= nil)
    end)
  end)

  describe('strwidth', function()
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

  describe('{get,set}_current_line', function()
    it('works', function()
      eq('', nvim('get_current_line'))
      nvim('set_current_line', 'abc')
      eq('abc', nvim('get_current_line'))
    end)
  end)

  describe('{get,set,del}_var', function()
    it('works', function()
      nvim('set_var', 'lua', {1, 2, {['3'] = 1}})
      eq({1, 2, {['3'] = 1}}, nvim('get_var', 'lua'))
      eq({1, 2, {['3'] = 1}}, nvim('eval', 'g:lua'))
      eq(1, funcs.exists('g:lua'))
      meths.del_var('lua')
      eq(0, funcs.exists('g:lua'))
    end)

    it('set_var returns the old value', function()
      local val1 = {1, 2, {['3'] = 1}}
      local val2 = {4, 7}
      eq(NIL, nvim('set_var', 'lua', val1))
      eq(val1, nvim('set_var', 'lua', val2))
    end)

    it('del_var returns the old value', function()
      local val1 = {1, 2, {['3'] = 1}}
      local val2 = {4, 7}
      eq(NIL, meths.set_var('lua', val1))
      eq(val1, meths.set_var('lua', val2))
      eq(val2, meths.del_var('lua'))
    end)

    it('truncates values with NULs in them', function()
      nvim('set_var', 'xxx', 'ab\0cd')
      eq('ab', nvim('get_var', 'xxx'))
    end)
  end)

  describe('{get,set}_option', function()
    it('works', function()
      ok(nvim('get_option', 'equalalways'))
      nvim('set_option', 'equalalways', false)
      ok(not nvim('get_option', 'equalalways'))
    end)
  end)

  describe('{get,set}_current_buffer and get_buffers', function()
    it('works', function()
      eq(1, #nvim('get_buffers'))
      eq(nvim('get_buffers')[1], nvim('get_current_buffer'))
      nvim('command', 'new')
      eq(2, #nvim('get_buffers'))
      eq(nvim('get_buffers')[2], nvim('get_current_buffer'))
      nvim('set_current_buffer', nvim('get_buffers')[1])
      eq(nvim('get_buffers')[1], nvim('get_current_buffer'))
    end)
  end)

  describe('{get,set}_current_window and get_windows', function()
    it('works', function()
      eq(1, #nvim('get_windows'))
      eq(nvim('get_windows')[1], nvim('get_current_window'))
      nvim('command', 'vsplit')
      nvim('command', 'split')
      eq(3, #nvim('get_windows'))
      eq(nvim('get_windows')[1], nvim('get_current_window'))
      nvim('set_current_window', nvim('get_windows')[2])
      eq(nvim('get_windows')[2], nvim('get_current_window'))
    end)
  end)

  describe('{get,set}_current_tabpage and get_tabpages', function()
    it('works', function()
      eq(1, #nvim('get_tabpages'))
      eq(nvim('get_tabpages')[1], nvim('get_current_tabpage'))
      nvim('command', 'tabnew')
      eq(2, #nvim('get_tabpages'))
      eq(2, #nvim('get_windows'))
      eq(nvim('get_windows')[2], nvim('get_current_window'))
      eq(nvim('get_tabpages')[2], nvim('get_current_tabpage'))
      nvim('set_current_window', nvim('get_windows')[1])
      -- Switching window also switches tabpages if necessary
      eq(nvim('get_tabpages')[1], nvim('get_current_tabpage'))
      eq(nvim('get_windows')[1], nvim('get_current_window'))
      nvim('set_current_tabpage', nvim('get_tabpages')[2])
      eq(nvim('get_tabpages')[2], nvim('get_current_tabpage'))
      eq(nvim('get_windows')[2], nvim('get_current_window'))
    end)
  end)

  describe('replace_termcodes', function()
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
  end)

  describe('feedkeys', function()
    it('CSI escaping', function()
      local function on_setup()
        -- notice the special char(…) \xe2\80\xa6
        nvim('feedkeys', ':let x1="…"\n', '', true)

        -- Both replace_termcodes and feedkeys escape \x80
        local inp = helpers.nvim('replace_termcodes', ':let x2="…"<CR>', true, true, true)
        nvim('feedkeys', inp, '', true)

        -- Disabling CSI escaping in feedkeys
        inp = helpers.nvim('replace_termcodes', ':let x3="…"<CR>', true, true, true)
        nvim('feedkeys', inp, '', false)

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

  describe('err_write', function()
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

  it('can throw exceptions', function()
    local status, err = pcall(nvim, 'get_option', 'invalid-option')
    eq(false, status)
    ok(err:match('Invalid option name') ~= nil)
  end)

  it("doesn't leak memory on incorrect argument types", function()
    local status, err = pcall(nvim, 'change_directory',{'not', 'a', 'dir'})
    eq(false, status)
    ok(err:match(': Wrong type for argument 1, expecting String') ~= nil)
  end)

end)
