local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local NIL = helpers.NIL
local clear, nvim, eq, neq = helpers.clear, helpers.nvim, helpers.eq, helpers.neq
local command = helpers.command
local eval = helpers.eval
local expect = helpers.expect
local funcs = helpers.funcs
local iswin = helpers.iswin
local meths = helpers.meths
local matches = helpers.matches
local ok, nvim_async, feed = helpers.ok, helpers.nvim_async, helpers.feed
local is_os = helpers.is_os
local parse_context = helpers.parse_context
local request = helpers.request
local source = helpers.source
local next_msg = helpers.next_msg
local tmpname = helpers.tmpname
local write_file = helpers.write_file

local pcall_err = helpers.pcall_err
local format_string = helpers.format_string
local intchar2lua = helpers.intchar2lua
local mergedicts_copy = helpers.mergedicts_copy
local endswith = helpers.endswith

describe('API', function()
  before_each(clear)

  it('validates requests', function()
    -- RPC
    matches('Invalid method: bogus$',
      pcall_err(request, 'bogus'))
    matches('Invalid method: … の り 。…$',
      pcall_err(request, '… の り 。…'))
    matches('Invalid method: <empty>$',
      pcall_err(request, ''))

    -- Non-RPC: rpcrequest(v:servername) uses internal channel.
    matches('Invalid method: … の り 。…$',
      pcall_err(request, 'nvim_eval',
        [=[rpcrequest(sockconnect('pipe', v:servername, {'rpc':1}), '… の り 。…')]=]))
    matches('Invalid method: bogus$',
      pcall_err(request, 'nvim_eval',
        [=[rpcrequest(sockconnect('pipe', v:servername, {'rpc':1}), 'bogus')]=]))

    -- XXX: This must be the last one, else next one will fail:
    --      "Packer instance already working. Use another Packer ..."
    matches("can't serialize object$",
      pcall_err(request, nil))
  end)

  it('handles errors in async requests', function()
    local error_types = meths.get_api_info()[2].error_types
    nvim_async('bogus')
    eq({'notification', 'nvim_error_event',
        {error_types.Exception.id, 'Invalid method: nvim_bogus'}}, next_msg())
    -- error didn't close channel.
    eq(2, eval('1+1'))
  end)

  it('failed async request emits nvim_error_event', function()
    local error_types = meths.get_api_info()[2].error_types
    nvim_async('command', 'bogus')
    eq({'notification', 'nvim_error_event',
        {error_types.Exception.id, 'Vim:E492: Not an editor command: bogus'}},
        next_msg())
    -- error didn't close channel.
    eq(2, eval('1+1'))
  end)

  it('does not set CA_COMMAND_BUSY #7254', function()
    nvim('command', 'split')
    nvim('command', 'autocmd WinEnter * startinsert')
    nvim('command', 'wincmd w')
    eq({mode='i', blocking=false}, nvim("get_mode"))
  end)

  describe('nvim_exec', function()
    it('one-line input', function()
      nvim('exec', "let x1 = 'a'", false)
      eq('a', nvim('get_var', 'x1'))
    end)

    it(':verbose set {option}?', function()
      nvim('exec', 'set nowrap', false)
      eq('nowrap\n\tLast set from anonymous :source',
        nvim('exec', 'verbose set wrap?', true))
    end)

    it('multiline input', function()
      -- Heredoc + empty lines.
      nvim('exec', "let x2 = 'a'\n", false)
      eq('a', nvim('get_var', 'x2'))
      nvim('exec','lua <<EOF\n\n\n\ny=3\n\n\nEOF', false)
      eq(3, nvim('eval', "luaeval('y')"))

      eq('', nvim('exec', 'lua <<EOF\ny=3\nEOF', false))
      eq(3, nvim('eval', "luaeval('y')"))

      -- Multiple statements
      nvim('exec', 'let x1=1\nlet x2=2\nlet x3=3\n', false)
      eq(1, nvim('eval', 'x1'))
      eq(2, nvim('eval', 'x2'))
      eq(3, nvim('eval', 'x3'))

      -- Functions
      nvim('exec', 'function Foo()\ncall setline(1,["xxx"])\nendfunction', false)
      eq(nvim('get_current_line'), '')
      nvim('exec', 'call Foo()', false)
      eq(nvim('get_current_line'), 'xxx')

      -- Autocmds
      nvim('exec','autocmd BufAdd * :let x1 = "Hello"', false)
      nvim('command', 'new foo')
      eq('Hello', request('nvim_eval', 'g:x1'))
    end)

    it('non-ASCII input', function()
      nvim('exec', [=[
        new
        exe "normal! i ax \n Ax "
        :%s/ax/--a1234--/g | :%s/Ax/--A1234--/g
      ]=], false)
      nvim('command', '1')
      eq(' --a1234-- ', nvim('get_current_line'))
      nvim('command', '2')
      eq(' --A1234-- ', nvim('get_current_line'))

      nvim('exec', [[
        new
        call setline(1,['xxx'])
        call feedkeys('r')
        call feedkeys('ñ', 'xt')
      ]], false)
      eq('ñxx', nvim('get_current_line'))
    end)

    it('execution error', function()
      eq('Vim:E492: Not an editor command: bogus_command',
        pcall_err(request, 'nvim_exec', 'bogus_command', false))
      eq('', nvim('eval', 'v:errmsg'))  -- v:errmsg was not updated.
      eq('', eval('v:exception'))

      eq('Vim(buffer):E86: Buffer 23487 does not exist',
        pcall_err(request, 'nvim_exec', 'buffer 23487', false))
      eq('', eval('v:errmsg'))  -- v:errmsg was not updated.
      eq('', eval('v:exception'))
    end)

    it('recursion', function()
      local fname = tmpname()
      write_file(fname, 'let x1 = "set from :source file"\n')
      -- nvim_exec
      --   :source
      --     nvim_exec
      request('nvim_exec', [[
        let x2 = substitute('foo','o','X','g')
        let x4 = 'should be overwritten'
        call nvim_exec("source ]]..fname..[[\nlet x3 = substitute('foo','foo','set by recursive nvim_exec','g')\nlet x5='overwritten'\nlet x4=x5\n", v:false)
      ]], false)
      eq('set from :source file', request('nvim_get_var', 'x1'))
      eq('fXX', request('nvim_get_var', 'x2'))
      eq('set by recursive nvim_exec', request('nvim_get_var', 'x3'))
      eq('overwritten', request('nvim_get_var', 'x4'))
      eq('overwritten', request('nvim_get_var', 'x5'))
      os.remove(fname)
    end)

    it('traceback', function()
      local fname = tmpname()
      write_file(fname, 'echo "hello"\n')
      local sourcing_fname = tmpname()
      write_file(sourcing_fname, 'call nvim_exec("source '..fname..'", v:false)\n')
      meths.exec('set verbose=2', false)
      local traceback_output = 'line 0: sourcing "'..sourcing_fname..'"\n'..
        'line 0: sourcing "'..fname..'"\n'..
        'hello\n'..
        'finished sourcing '..fname..'\n'..
        'continuing in nvim_exec() called at '..sourcing_fname..':1\n'..
        'finished sourcing '..sourcing_fname..'\n'..
        'continuing in nvim_exec() called at nvim_exec():0'
      eq(traceback_output,
        meths.exec('call nvim_exec("source '..sourcing_fname..'", v:false)', true))
      os.remove(fname)
      os.remove(sourcing_fname)
    end)

    it('returns output', function()
      eq('this is spinal tap',
         nvim('exec', 'lua <<EOF\n\n\nprint("this is spinal tap")\n\n\nEOF', true))
      eq('', nvim('exec', 'echo', true))
      eq('foo 42', nvim('exec', 'echo "foo" 42', true))
    end)

    it('displays messages when output=false', function()
      local screen = Screen.new(40, 8)
      screen:attach()
      screen:set_default_attr_ids({
        [0] = {bold=true, foreground=Screen.colors.Blue},
      })
      meths.exec("echo 'hello'", false)
      screen:expect{grid=[[
        ^                                        |
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        hello                                   |
      ]]}
    end)

    it('does\'t display messages when output=true', function()
      local screen = Screen.new(40, 8)
      screen:attach()
      screen:set_default_attr_ids({
        [0] = {bold=true, foreground=Screen.colors.Blue},
      })
      meths.exec("echo 'hello'", true)
      screen:expect{grid=[[
        ^                                        |
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
                                                |
      ]]}
    end)
  end)

  describe('nvim_command', function()
    it('works', function()
      local fname = tmpname()
      nvim('command', 'new')
      nvim('command', 'edit '..fname)
      nvim('command', 'normal itesting\napi')
      nvim('command', 'w')
      local f = io.open(fname)
      ok(f ~= nil)
      if is_os('win') then
        eq('testing\r\napi\r\n', f:read('*a'))
      else
        eq('testing\napi\n', f:read('*a'))
      end
      f:close()
      os.remove(fname)
    end)

    it('VimL validation error: fails with specific error', function()
      local status, rv = pcall(nvim, "command", "bogus_command")
      eq(false, status)                       -- nvim_command() failed.
      eq("E492:", string.match(rv, "E%d*:"))  -- VimL error was returned.
      eq('', nvim('eval', 'v:errmsg'))        -- v:errmsg was not updated.
      eq('', eval('v:exception'))
    end)

    it('VimL execution error: fails with specific error', function()
      local status, rv = pcall(nvim, "command", "buffer 23487")
      eq(false, status)                 -- nvim_command() failed.
      eq("E86: Buffer 23487 does not exist", string.match(rv, "E%d*:.*"))
      eq('', eval('v:errmsg'))  -- v:errmsg was not updated.
      eq('', eval('v:exception'))
    end)
  end)

  describe('nvim_command_output', function()
    it('does not induce hit-enter prompt', function()
      -- Induce a hit-enter prompt use nvim_input (non-blocking).
      nvim('command', 'set cmdheight=1')
      nvim('input', [[:echo "hi\nhi2"<CR>]])

      -- Verify hit-enter prompt.
      eq({mode='r', blocking=true}, nvim("get_mode"))
      nvim('input', [[<C-c>]])

      -- Verify NO hit-enter prompt.
      nvim('command_output', [[echo "hi\nhi2"]])
      eq({mode='n', blocking=false}, nvim("get_mode"))
    end)

    it('captures command output', function()
      eq('this is\nspinal tap',
         nvim('command_output', [[echo "this is\nspinal tap"]]))
      eq('no line ending!',
         nvim('command_output', [[echon "no line ending!"]]))
    end)

    it('captures empty command output', function()
      eq('', nvim('command_output', 'echo'))
    end)

    it('captures single-char command output', function()
      eq('x', nvim('command_output', 'echo "x"'))
    end)

    it('captures multiple commands', function()
      eq('foo\n  1 %a   "[No Name]"                    line 1',
        nvim('command_output', 'echo "foo" | ls'))
    end)

    it('captures nested execute()', function()
      eq('\nnested1\nnested2\n  1 %a   "[No Name]"                    line 1',
        nvim('command_output',
          [[echo execute('echo "nested1\nnested2"') | ls]]))
    end)

    it('captures nested nvim_command_output()', function()
      eq('nested1\nnested2\n  1 %a   "[No Name]"                    line 1',
        nvim('command_output',
          [[echo nvim_command_output('echo "nested1\nnested2"') | ls]]))
    end)

    it('returns shell |:!| output', function()
      local win_lf = iswin() and '\r' or ''
      eq(':!echo foo\r\n\nfoo'..win_lf..'\n', nvim('command_output', [[!echo foo]]))
    end)

    it('VimL validation error: fails with specific error', function()
      local status, rv = pcall(nvim, "command_output", "bogus commannnd")
      eq(false, status)                 -- nvim_command_output() failed.
      eq("E492: Not an editor command: bogus commannnd",
         string.match(rv, "E%d*:.*"))
      eq('', eval('v:errmsg'))  -- v:errmsg was not updated.
      -- Verify NO hit-enter prompt.
      eq({mode='n', blocking=false}, nvim("get_mode"))
    end)

    it('VimL execution error: fails with specific error', function()
      local status, rv = pcall(nvim, "command_output", "buffer 42")
      eq(false, status)                 -- nvim_command_output() failed.
      eq("E86: Buffer 42 does not exist", string.match(rv, "E%d*:.*"))
      eq('', eval('v:errmsg'))  -- v:errmsg was not updated.
      -- Verify NO hit-enter prompt.
      eq({mode='n', blocking=false}, nvim("get_mode"))
    end)

    it('Does not cause heap buffer overflow with large output', function()
      eq(eval('string(range(1000000))'),
         nvim('command_output', 'echo range(1000000)'))
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

    it("VimL error: returns error details, does NOT update v:errmsg", function()
      eq('Vim:E121: Undefined variable: bogus',
        pcall_err(request, 'nvim_eval', 'bogus expression'))
      eq('', eval('v:errmsg'))  -- v:errmsg was not updated.
    end)
  end)

  describe('nvim_call_function', function()
    it('works', function()
      nvim('call_function', 'setqflist', { { { filename = 'something', lnum = 17 } }, 'r' })
      eq(17, nvim('call_function', 'getqflist', {})[1].lnum)
      eq(17, nvim('call_function', 'eval', {17}))
      eq('foo', nvim('call_function', 'simplify', {'this/./is//redundant/../../../foo'}))
    end)

    it("VimL validation error: returns specific error, does NOT update v:errmsg", function()
      eq('Vim:E117: Unknown function: bogus function',
        pcall_err(request, 'nvim_call_function', 'bogus function', {'arg1'}))
      eq('Vim:E119: Not enough arguments for function: atan',
        pcall_err(request, 'nvim_call_function', 'atan', {}))
      eq('', eval('v:exception'))
      eq('', eval('v:errmsg'))  -- v:errmsg was not updated.
    end)

    it("VimL error: returns error details, does NOT update v:errmsg", function()
      eq('Vim:E808: Number or Float required',
        pcall_err(request, 'nvim_call_function', 'atan', {'foo'}))
      eq('Vim:Invalid channel stream "xxx"',
        pcall_err(request, 'nvim_call_function', 'chanclose', {999, 'xxx'}))
      eq('Vim:E900: Invalid channel id',
        pcall_err(request, 'nvim_call_function', 'chansend', {999, 'foo'}))
      eq('', eval('v:exception'))
      eq('', eval('v:errmsg'))  -- v:errmsg was not updated.
    end)

    it("VimL exception: returns exception details, does NOT update v:errmsg", function()
      source([[
        function! Foo() abort
          throw 'wtf'
        endfunction
      ]])
      eq('wtf', pcall_err(request, 'nvim_call_function', 'Foo', {}))
      eq('', eval('v:exception'))
      eq('', eval('v:errmsg'))  -- v:errmsg was not updated.
    end)

    it('validates args', function()
      local too_many_args = { 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x' }
      source([[
        function! Foo(...) abort
          echo a:000
        endfunction
      ]])
      -- E740
      eq('Function called with too many arguments',
        pcall_err(request, 'nvim_call_function', 'Foo', too_many_args))
    end)
  end)

  describe('nvim_call_dict_function', function()
    it('invokes VimL dict function', function()
      source([[
        function! F(name) dict
          return self.greeting.', '.a:name.'!'
        endfunction
        let g:test_dict_fn = { 'greeting':'Hello', 'F':function('F') }

        let g:test_dict_fn2 = { 'greeting':'Hi' }
        function g:test_dict_fn2.F2(name)
          return self.greeting.', '.a:name.' ...'
        endfunction
      ]])

      -- :help Dictionary-function
      eq('Hello, World!', nvim('call_dict_function', 'g:test_dict_fn', 'F', {'World'}))
      -- Funcref is sent as NIL over RPC.
      eq({ greeting = 'Hello', F = NIL }, nvim('get_var', 'test_dict_fn'))

      -- :help numbered-function
      eq('Hi, Moon ...', nvim('call_dict_function', 'g:test_dict_fn2', 'F2', {'Moon'}))
      -- Funcref is sent as NIL over RPC.
      eq({ greeting = 'Hi', F2 = NIL }, nvim('get_var', 'test_dict_fn2'))

      -- Function specified via RPC dict.
      source('function! G() dict\n  return "@".(self.result)."@"\nendfunction')
      eq('@it works@', nvim('call_dict_function', { result = 'it works', G = 'G'}, 'G', {}))
    end)

    it('validates args', function()
      command('let g:d={"baz":"zub","meep":[]}')
      eq('Not found: bogus',
        pcall_err(request, 'nvim_call_dict_function', 'g:d', 'bogus', {1,2}))
      eq('Not a function: baz',
        pcall_err(request, 'nvim_call_dict_function', 'g:d', 'baz', {1,2}))
      eq('Not a function: meep',
        pcall_err(request, 'nvim_call_dict_function', 'g:d', 'meep', {1,2}))
      eq('Vim:E117: Unknown function: f',
        pcall_err(request, 'nvim_call_dict_function', { f = '' }, 'f', {1,2}))
      eq('Not a function: f',
        pcall_err(request, 'nvim_call_dict_function', "{ 'f': '' }", 'f', {1,2}))
      eq('dict argument type must be String or Dictionary',
        pcall_err(request, 'nvim_call_dict_function', 42, 'f', {1,2}))
      eq('Failed to evaluate dict expression',
        pcall_err(request, 'nvim_call_dict_function', 'foo', 'f', {1,2}))
      eq('dict not found',
        pcall_err(request, 'nvim_call_dict_function', '42', 'f', {1,2}))
      eq('Invalid (empty) function name',
        pcall_err(request, 'nvim_call_dict_function', "{ 'f': '' }", '', {1,2}))
    end)
  end)

  describe('nvim_exec_lua', function()
    it('works', function()
      meths.exec_lua('vim.api.nvim_set_var("test", 3)', {})
      eq(3, meths.get_var('test'))

      eq(17, meths.exec_lua('a, b = ...\nreturn a + b', {10,7}))

      eq(NIL, meths.exec_lua('function xx(a,b)\nreturn a..b\nend',{}))
      eq("xy", meths.exec_lua('return xx(...)', {'x','y'}))

      -- Deprecated name: nvim_execute_lua.
      eq("xy", meths.execute_lua('return xx(...)', {'x','y'}))
    end)

    it('reports errors', function()
      eq([[Error loading lua: [string "<nvim>"]:0: '=' expected near '+']],
        pcall_err(meths.exec_lua, 'a+*b', {}))

      eq([[Error loading lua: [string "<nvim>"]:0: unexpected symbol near '1']],
        pcall_err(meths.exec_lua, '1+2', {}))

      eq([[Error loading lua: [string "<nvim>"]:0: unexpected symbol]],
        pcall_err(meths.exec_lua, 'aa=bb\0', {}))

      eq([[Error executing lua: [string "<nvim>"]:0: attempt to call global 'bork' (a nil value)]],
        pcall_err(meths.exec_lua, 'bork()', {}))

      eq('Error executing lua: [string "<nvim>"]:0: did\nthe\nfail',
        pcall_err(meths.exec_lua, 'error("did\\nthe\\nfail")', {}))
    end)

    it('uses native float values', function()
      eq(2.5, meths.exec_lua("return select(1, ...)", {2.5}))
      eq("2.5", meths.exec_lua("return vim.inspect(...)", {2.5}))

      -- "special" float values are still accepted as return values.
      eq(2.5, meths.exec_lua("return vim.api.nvim_eval('2.5')", {}))
      eq("{\n  [false] = 2.5,\n  [true] = 3\n}", meths.exec_lua("return vim.inspect(vim.api.nvim_eval('2.5'))", {}))
    end)
  end)

  describe('nvim_notify', function()
    it('can notify a info message', function()
      nvim("notify", "hello world", 2, {})
    end)

    it('can be overriden', function()
      command("lua vim.notify = function(...) return 42 end")
      eq(42, meths.exec_lua("return vim.notify('Hello world')", {}))
      nvim("notify", "hello world", 4, {})
    end)
  end)

  describe('nvim_input', function()
    it("VimL error: does NOT fail, updates v:errmsg", function()
      local status, _ = pcall(nvim, "input", ":call bogus_fn()<CR>")
      local v_errnum = string.match(nvim("eval", "v:errmsg"), "E%d*:")
      eq(true, status)        -- nvim_input() did not fail.
      eq("E117:", v_errnum)   -- v:errmsg was updated.
    end)

    it('does not crash even if trans_special result is largest #11788, #12287', function()
      command("call nvim_input('<M-'.nr2char(0x40000000).'>')")
      eq(1, eval('1'))
    end)
  end)

  describe('nvim_paste', function()
    it('validates args', function()
      eq('Invalid phase: -2',
        pcall_err(request, 'nvim_paste', 'foo', true, -2))
      eq('Invalid phase: 4',
        pcall_err(request, 'nvim_paste', 'foo', true, 4))
    end)
    it('stream: multiple chunks form one undo-block', function()
      nvim('paste', '1/chunk 1 (start)\n', true, 1)
      nvim('paste', '1/chunk 2 (end)\n', true, 3)
      local expected1 = [[
        1/chunk 1 (start)
        1/chunk 2 (end)
        ]]
      expect(expected1)
      nvim('paste', '2/chunk 1 (start)\n', true, 1)
      nvim('paste', '2/chunk 2\n', true, 2)
      expect([[
        1/chunk 1 (start)
        1/chunk 2 (end)
        2/chunk 1 (start)
        2/chunk 2
        ]])
      nvim('paste', '2/chunk 3\n', true, 2)
      nvim('paste', '2/chunk 4 (end)\n', true, 3)
      expect([[
        1/chunk 1 (start)
        1/chunk 2 (end)
        2/chunk 1 (start)
        2/chunk 2
        2/chunk 3
        2/chunk 4 (end)
        ]])
      feed('u')  -- Undo.
      expect(expected1)
    end)
    it('non-streaming', function()
      -- With final "\n".
      nvim('paste', 'line 1\nline 2\nline 3\n', true, -1)
      expect([[
        line 1
        line 2
        line 3
        ]])
      eq({0,4,1,0}, funcs.getpos('.'))  -- Cursor follows the paste.
      eq(false, nvim('get_option', 'paste'))
      command('%delete _')
      -- Without final "\n".
      nvim('paste', 'line 1\nline 2\nline 3', true, -1)
      expect([[
        line 1
        line 2
        line 3]])
      eq({0,3,6,0}, funcs.getpos('.'))
      command('%delete _')
      -- CRLF #10872
      nvim('paste', 'line 1\r\nline 2\r\nline 3\r\n', true, -1)
      expect([[
        line 1
        line 2
        line 3
        ]])
      eq({0,4,1,0}, funcs.getpos('.'))
      command('%delete _')
      -- CRLF without final "\n".
      nvim('paste', 'line 1\r\nline 2\r\nline 3\r', true, -1)
      expect([[
        line 1
        line 2
        line 3
        ]])
      eq({0,4,1,0}, funcs.getpos('.'))
      command('%delete _')
      -- CRLF without final "\r\n".
      nvim('paste', 'line 1\r\nline 2\r\nline 3', true, -1)
      expect([[
        line 1
        line 2
        line 3]])
      eq({0,3,6,0}, funcs.getpos('.'))
      command('%delete _')
      -- Various other junk.
      nvim('paste', 'line 1\r\n\r\rline 2\nline 3\rline 4\r', true, -1)
      expect('line 1\n\n\nline 2\nline 3\nline 4\n')
      eq({0,7,1,0}, funcs.getpos('.'))
      eq(false, nvim('get_option', 'paste'))
    end)
    it('Replace-mode', function()
      -- Within single line
      nvim('put', {'aabbccdd', 'eeffgghh', 'iijjkkll'}, "c", true, false)
      command('normal l')
      command('startreplace')
      nvim('paste', '123456', true, -1)
      expect([[
      a123456d
      eeffgghh
      iijjkkll]])
      command('%delete _')
      -- Across lines
      nvim('put', {'aabbccdd', 'eeffgghh', 'iijjkkll'}, "c", true, false)
      command('normal l')
      command('startreplace')
      nvim('paste', '123\n456', true, -1)
      expect([[
      a123
      456d
      eeffgghh
      iijjkkll]])
    end)
    it('crlf=false does not break lines at CR, CRLF', function()
      nvim('paste', 'line 1\r\n\r\rline 2\nline 3\rline 4\r', false, -1)
      expect('line 1\r\n\r\rline 2\nline 3\rline 4\r')
      eq({0,3,14,0}, funcs.getpos('.'))
    end)
    it('vim.paste() failure', function()
      nvim('exec_lua', 'vim.paste = (function(lines, phase) error("fake fail") end)', {})
      eq([[Error executing lua: [string "<nvim>"]:0: fake fail]],
        pcall_err(request, 'nvim_paste', 'line 1\nline 2\nline 3', false, 1))
    end)
  end)

  describe('nvim_put', function()
    it('validates args', function()
      eq('Invalid lines (expected array of strings)',
        pcall_err(request, 'nvim_put', {42}, 'l', false, false))
      eq("Invalid type: 'x'",
        pcall_err(request, 'nvim_put', {'foo'}, 'x', false, false))
    end)
    it("fails if 'nomodifiable'", function()
      command('set nomodifiable')
      eq([[Vim:E21: Cannot make changes, 'modifiable' is off]],
        pcall_err(request, 'nvim_put', {'a','b'}, 'l', true, true))
    end)
    it('inserts text', function()
      -- linewise
      nvim('put', {'line 1','line 2','line 3'}, 'l', true, true)
      expect([[

        line 1
        line 2
        line 3]])
      eq({0,4,1,0}, funcs.getpos('.'))
      command('%delete _')
      -- charwise
      nvim('put', {'line 1','line 2','line 3'}, 'c', true, false)
      expect([[
        line 1
        line 2
        line 3]])
      eq({0,1,1,0}, funcs.getpos('.'))  -- follow=false
      -- blockwise
      nvim('put', {'AA','BB'}, 'b', true, true)
      expect([[
        lAAine 1
        lBBine 2
        line 3]])
      eq({0,2,4,0}, funcs.getpos('.'))
      command('%delete _')
      -- Empty lines list.
      nvim('put', {}, 'c', true, true)
      eq({0,1,1,0}, funcs.getpos('.'))
      expect([[]])
      -- Single empty line.
      nvim('put', {''}, 'c', true, true)
      eq({0,1,1,0}, funcs.getpos('.'))
      expect([[
      ]])
      nvim('put', {'AB'}, 'c', true, true)
      -- after=false, follow=true
      nvim('put', {'line 1','line 2'}, 'c', false, true)
      expect([[
        Aline 1
        line 2B]])
      eq({0,2,7,0}, funcs.getpos('.'))
      command('%delete _')
      nvim('put', {'AB'}, 'c', true, true)
      -- after=false, follow=false
      nvim('put', {'line 1','line 2'}, 'c', false, false)
      expect([[
        Aline 1
        line 2B]])
      eq({0,1,2,0}, funcs.getpos('.'))
      eq('', nvim('eval', 'v:errmsg'))
    end)

    it('detects charwise/linewise text (empty {type})', function()
      -- linewise (final item is empty string)
      nvim('put', {'line 1','line 2','line 3',''}, '', true, true)
      expect([[

        line 1
        line 2
        line 3]])
      eq({0,4,1,0}, funcs.getpos('.'))
      command('%delete _')
      -- charwise (final item is non-empty)
      nvim('put', {'line 1','line 2','line 3'}, '', true, true)
      expect([[
        line 1
        line 2
        line 3]])
      eq({0,3,6,0}, funcs.getpos('.'))
    end)

    it('allows block width', function()
      -- behave consistently with setreg(); support "\022{NUM}" return by getregtype()
      meths.put({'line 1','line 2','line 3'}, 'l', false, false)
      expect([[
        line 1
        line 2
        line 3
        ]])

      -- larger width create spaces
      meths.put({'a', 'bc'}, 'b3', false, false)
      expect([[
        a  line 1
        bc line 2
        line 3
        ]])
      -- smaller width is ignored
      meths.put({'xxx', 'yyy'}, '\0221', false, true)
      expect([[
        xxxa  line 1
        yyybc line 2
        line 3
        ]])
      eq("Invalid type: 'bx'",
         pcall_err(meths.put, {'xxx', 'yyy'}, 'bx', false, true))
      eq("Invalid type: 'b3x'",
         pcall_err(meths.put, {'xxx', 'yyy'}, 'b3x', false, true))
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

  describe('set/get/del variables', function()
    it('nvim_get_var, nvim_set_var, nvim_del_var', function()
      nvim('set_var', 'lua', {1, 2, {['3'] = 1}})
      eq({1, 2, {['3'] = 1}}, nvim('get_var', 'lua'))
      eq({1, 2, {['3'] = 1}}, nvim('eval', 'g:lua'))
      eq(1, funcs.exists('g:lua'))
      meths.del_var('lua')
      eq(0, funcs.exists('g:lua'))
      eq("Key not found: lua", pcall_err(meths.del_var, 'lua'))
      meths.set_var('lua', 1)

      -- Set locked g: var.
      command('lockvar lua')
      eq('Key is locked: lua', pcall_err(meths.del_var, 'lua'))
      eq('Key is locked: lua', pcall_err(meths.set_var, 'lua', 1))
    end)

    it('nvim_get_vvar, nvim_set_vvar', function()
      -- Set readonly v: var.
      eq('Key is read-only: count',
        pcall_err(request, 'nvim_set_vvar', 'count', 42))
      -- Set writable v: var.
      meths.set_vvar('errmsg', 'set by API')
      eq('set by API', meths.get_vvar('errmsg'))
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

    it('updates where the option was last set from', function()
      nvim('set_option', 'equalalways', false)
      local status, rv = pcall(nvim, 'command_output',
        'verbose set equalalways?')
      eq(true, status)
      ok(nil ~= string.find(rv, 'noequalalways\n'..
        '\tLast set from API client %(channel id %d+%)'))

      nvim('exec_lua', 'vim.api.nvim_set_option("equalalways", true)', {})
      status, rv = pcall(nvim, 'command_output',
        'verbose set equalalways?')
      eq(true, status)
      eq('  equalalways\n\tLast set from Lua', rv)
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

    it("at '-- More --' prompt returns blocking=true #11899", function()
      command('set more')
      feed(':digraphs<cr>')
      eq({mode='rm', blocking=true}, nvim("get_mode"))
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
      expect([[
        FIRST LINE
        SECOND LINE]])
      -- Now send input to complete the operator.
      nvim('input', 'j')
      expect([[
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
      expect([[
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
      expect([[
        FIRST LINE
        SECOND LINfooE]])
    end)
  end)

  describe('nvim_get_context', function()
    it('validates args', function()
      eq('unexpected key: blah',
        pcall_err(nvim, 'get_context', {blah={}}))
      eq('invalid value for key: types',
        pcall_err(nvim, 'get_context', {types=42}))
      eq('unexpected type: zub',
        pcall_err(nvim, 'get_context', {types={'jumps', 'zub', 'zam',}}))
    end)
    it('returns map of current editor state', function()
      local opts = {types={'regs', 'jumps', 'bufs', 'gvars'}}
      eq({}, parse_context(nvim('get_context', {})))

      feed('i1<cr>2<cr>3<c-[>ddddddqahjklquuu')
      feed('gg')
      feed('G')
      command('edit! BUF1')
      command('edit BUF2')
      nvim('set_var', 'one', 1)
      nvim('set_var', 'Two', 2)
      nvim('set_var', 'THREE', 3)

      local expected_ctx = {
        ['regs'] = {
          {['rt'] = 1, ['rc'] = {'1'}, ['n'] = 49, ['ru'] = true},
          {['rt'] = 1, ['rc'] = {'2'}, ['n'] = 50},
          {['rt'] = 1, ['rc'] = {'3'}, ['n'] = 51},
          {['rc'] = {'hjkl'}, ['n'] = 97},
        },

        ['jumps'] = eval(([[
        filter(map(getjumplist()[0], 'filter(
          { "f": expand("#".v:val.bufnr.":p"), "l": v:val.lnum },
          { k, v -> k != "l" || v != 1 })'), '!empty(v:val.f)')
        ]]):gsub('\n', '')),

        ['bufs'] = eval([[
        filter(map(getbufinfo(), '{ "f": v:val.name }'), '!empty(v:val.f)')
        ]]),

        ['gvars'] = {{'one', 1}, {'Two', 2}, {'THREE', 3}},
      }

      eq(expected_ctx, parse_context(nvim('get_context', opts)))
      eq(expected_ctx, parse_context(nvim('get_context', {})))
      eq(expected_ctx, parse_context(nvim('get_context', {types={}})))
    end)
  end)

  describe('nvim_load_context', function()
    it('sets current editor state to given context dictionary', function()
      local opts = {types={'regs', 'jumps', 'bufs', 'gvars'}}
      eq({}, parse_context(nvim('get_context', opts)))

      nvim('set_var', 'one', 1)
      nvim('set_var', 'Two', 2)
      nvim('set_var', 'THREE', 3)
      local ctx = nvim('get_context', opts)
      nvim('set_var', 'one', 'a')
      nvim('set_var', 'Two', 'b')
      nvim('set_var', 'THREE', 'c')
      eq({'a', 'b' ,'c'}, eval('[g:one, g:Two, g:THREE]'))
      nvim('load_context', ctx)
      eq({1, 2 ,3}, eval('[g:one, g:Two, g:THREE]'))
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
        [2] = {bold = true, foreground = Screen.colors.SeaGreen},
        [3] = {bold = true, reverse = true},
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
                                                |
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {3:                                        }|
        {1:something happened}                      |
        {1:very bad}                                |
        {2:Press ENTER or type command to continue}^ |
      ]])
    end)

    it('shows return prompt after all lines are shown', function()
      nvim_async('err_write', 'FAILURE\nERROR\nEXCEPTION\nTRACEBACK\n')
      screen:expect([[
                                                |
        {0:~                                       }|
        {3:                                        }|
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
      helpers.poke_eventloop()

      -- shows up to &cmdheight lines
      nvim_async('err_write', 'more fail\ntoo fail\n')
      screen:expect([[
                                                |
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {3:                                        }|
        {1:more fail}                               |
        {1:too fail}                                |
        {2:Press ENTER or type command to continue}^ |
      ]])
      feed('<cr>')  -- exit the press ENTER screen
    end)
  end)

  describe('nvim_list_chans and nvim_get_chan_info', function()
    before_each(function()
      command('autocmd ChanOpen * let g:opened_event = copy(v:event)')
      command('autocmd ChanInfo * let g:info_event = copy(v:event)')
    end)
    local testinfo = {
      stream = 'stdio',
      id = 1,
      mode = 'rpc',
      client = {},
    }
    local stderr = {
      stream = 'stderr',
      id = 2,
      mode = 'bytes',
    }

    it('returns {} for invalid channel', function()
      eq({}, meths.get_chan_info(0))
      eq({}, meths.get_chan_info(-1))
      -- more preallocated numbers might be added, try something high
      eq({}, meths.get_chan_info(10))
    end)

    it('works for stdio channel', function()
      eq({[1]=testinfo,[2]=stderr}, meths.list_chans())
      eq(testinfo, meths.get_chan_info(1))
      eq(stderr, meths.get_chan_info(2))

      meths.set_client_info("functionaltests",
                            {major=0, minor=3, patch=17},
                            'ui',
                            {do_stuff={n_args={2,3}}},
                            {license= 'Apache2'})
      local info = {
        stream = 'stdio',
        id = 1,
        mode = 'rpc',
        client = {
          name='functionaltests',
          version={major=0, minor=3, patch=17},
          type='ui',
          methods={do_stuff={n_args={2,3}}},
          attributes={license='Apache2'},
        },
      }
      eq({info=info}, meths.get_var("info_event"))
      eq({[1]=info, [2]=stderr}, meths.list_chans())
      eq(info, meths.get_chan_info(1))
    end)

    it('works for job channel', function()
      eq(3, eval("jobstart(['cat'], {'rpc': v:true})"))
      local info = {
        stream='job',
        id=3,
        mode='rpc',
        client={},
      }
      eq({info=info}, meths.get_var("opened_event"))
      eq({[1]=testinfo,[2]=stderr,[3]=info}, meths.list_chans())
      eq(info, meths.get_chan_info(3))
      eval('rpcrequest(3, "nvim_set_client_info", "amazing-cat", {}, "remote",'..
                       '{"nvim_command":{"n_args":1}},'.. -- and so on
                       '{"description":"The Amazing Cat"})')
      info = {
        stream='job',
        id=3,
        mode='rpc',
        client = {
          name='amazing-cat',
          version={major=0},
          type='remote',
          methods={nvim_command={n_args=1}},
          attributes={description="The Amazing Cat"},
        },
      }
      eq({info=info}, meths.get_var("info_event"))
      eq({[1]=testinfo,[2]=stderr,[3]=info}, meths.list_chans())

      eq("Vim:Error invoking 'nvim_set_current_buf' on channel 3 (amazing-cat):\nWrong type for argument 1 when calling nvim_set_current_buf, expecting Buffer",
         pcall_err(eval, 'rpcrequest(3, "nvim_set_current_buf", -1)'))
    end)

    it('works for :terminal channel', function()
      command(":terminal")
      eq({id=1}, meths.get_current_buf())
      eq(3, meths.buf_get_option(1, "channel"))

      local info = {
        stream='job',
        id=3,
        mode='terminal',
        buffer = 1,
        pty='?',
      }
      local event = meths.get_var("opened_event")
      if not iswin() then
        info.pty = event.info.pty
        neq(nil, string.match(info.pty, "^/dev/"))
      end
      eq({info=info}, event)
      info.buffer = {id=1}
      eq({[1]=testinfo,[2]=stderr,[3]=info}, meths.list_chans())
      eq(info, meths.get_chan_info(3))
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
      eq({{}, {0, error_types.Exception.id, 'Invalid method: i_am_not_a_method'}},
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
      ok(err:match('Items in calls array must be arrays of size 2') ~= nil)
      -- call before was done, but not after
      eq(1, meths.get_var('avar'))

      req = {
        { 'nvim_set_var', { 'bvar', { 2, 3 } } },
        12,
      }
      status, err = pcall(meths.call_atomic, req)
      eq(false, status)
      ok(err:match('Items in calls array must be arrays') ~= nil)
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

  describe('nvim_list_runtime_paths', function()
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
    ok(err:match(': Wrong type for argument 1 when calling nvim_set_current_dir, expecting String') ~= nil)
  end)

  describe('nvim_parse_expression', function()
    before_each(function()
      meths.set_option('isident', '')
    end)

    local it_maybe_pending = it
    if (helpers.isCI('appveyor') and os.getenv('CONFIGURATION') == 'MSVC_32') then
      -- For "works with &opt" (flaky on MSVC_32), but not easy to skip alone.  #10241
      it_maybe_pending = pending
    end

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
        typ = typ .. format_string('(val=%e)', east_api_node.fvalue)
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
      elseif typ == 'Assignment' then
        local aug = east_api_node.augmentation
        if aug == '' then aug = 'Plain' end
        typ = ('%s(%s)'):format(typ, aug)
        east_api_node.augmentation = nil
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
        if #east_api.ast == 0 then
          east_api.ast = nil
        end
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
      [4] = "l",
      [5] = "lm",
      [6] = "lE",
      [7] = "lmE",
    }
    local function _check_parsing(opts, str, exp_ast, exp_highlighting_fs,
                                  nz_flags_exps)
      if type(str) ~= 'string' then
        return
      end
      local zflags = opts.flags[1]
      nz_flags_exps = nz_flags_exps or {}
      for _, flags in ipairs(opts.flags) do
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
          if not add_exps and flags == 3 + zflags then
            add_exps = nz_flags_exps[1 + zflags] or nz_flags_exps[2 + zflags]
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
          if type(msg) == 'table' then
            local merr, new_msg = pcall(
              format_string, 'table error:\n%s\n\n(%r)', msg.message, msg)
            if merr then
              msg = new_msg
            else
              msg = format_string('table error without .message:\n(%r)',
                                  msg)
            end
          elseif type(msg) ~= 'string' then
            msg = format_string('non-string non-table error:\n%r', msg)
          end
          error(format_string('Error while processing test (%r, %s):\n%s',
                              str, FLAGS_TO_STR[flags], msg))
        end
      end
    end
    local function hl(group, str, shift)
      return function(next_col)
        local col = next_col + (shift or 0)
        return (('%s:%u:%u:%s'):format(
          'Nvim' .. group,
          0,
          col,
          str)), (col + #str)
      end
    end
    local function fmtn(typ, args, rest)
      if (typ == 'UnknownFigure'
          or typ == 'DictLiteral'
          or typ == 'CurlyBracesIdentifier'
          or typ == 'Lambda') then
        return ('%s%s'):format(typ, rest)
      elseif typ == 'DoubleQuotedString' or typ == 'SingleQuotedString' then
        if args:sub(-4) == 'NULL' then
          args = args:sub(1, -5) .. '""'
        end
        return ('%s(%s)%s'):format(typ, args, rest)
      end
    end
    require('test.unit.viml.expressions.parser_tests')(
        it_maybe_pending, _check_parsing, hl, fmtn)
  end)

  describe('nvim_list_uis', function()
    it('returns empty if --headless', function()
      -- Test runner defaults to --headless.
      eq({}, nvim("list_uis"))
    end)
    it('returns attached UIs', function()
      local screen = Screen.new(20, 4)
      screen:attach({override=true})
      local expected = {
        {
          chan = 1,
          ext_cmdline = false,
          ext_popupmenu = false,
          ext_tabline = false,
          ext_wildmenu = false,
          ext_linegrid = screen._options.ext_linegrid or false,
          ext_multigrid = false,
          ext_hlstate = false,
          ext_termcolors = false,
          ext_messages = false,
          height = 4,
          rgb = true,
          override = true,
          width = 20,
        }
      }
      eq(expected, nvim("list_uis"))

      screen:detach()
      screen = Screen.new(44, 99)
      screen:attach({ rgb = false })
      expected[1].rgb = false
      expected[1].override = false
      expected[1].width = 44
      expected[1].height = 99
      eq(expected, nvim("list_uis"))
    end)
  end)

  describe('nvim_create_namespace', function()
    it('works', function()
      eq({}, meths.get_namespaces())
      eq(1, meths.create_namespace("ns-1"))
      eq(2, meths.create_namespace("ns-2"))
      eq(1, meths.create_namespace("ns-1"))
      eq({["ns-1"]=1, ["ns-2"]=2}, meths.get_namespaces())
      eq(3, meths.create_namespace(""))
      eq(4, meths.create_namespace(""))
      eq({["ns-1"]=1, ["ns-2"]=2}, meths.get_namespaces())
    end)
  end)

  describe('nvim_create_buf', function()
    it('works', function()
      eq({id=2}, meths.create_buf(true, false))
      eq({id=3}, meths.create_buf(false, false))
      eq('  1 %a   "[No Name]"                    line 1\n'..
         '  2  h   "[No Name]"                    line 0',
         meths.command_output("ls"))
      -- current buffer didn't change
      eq({id=1}, meths.get_current_buf())

      local screen = Screen.new(20, 4)
      screen:attach()
      meths.buf_set_lines(2, 0, -1, true, {"some text"})
      meths.set_current_buf(2)
      screen:expect([[
        ^some text           |
        {1:~                   }|
        {1:~                   }|
                            |
      ]], {
        [1] = {bold = true, foreground = Screen.colors.Blue1},
      })
    end)

    it('can change buftype before visiting', function()
      meths.set_option("hidden", false)
      eq({id=2}, meths.create_buf(true, false))
      meths.buf_set_option(2, "buftype", "nofile")
      meths.buf_set_lines(2, 0, -1, true, {"test text"})
      command("split | buffer 2")
      eq({id=2}, meths.get_current_buf())
      -- if the buf_set_option("buftype") didn't work, this would error out.
      command("close")
      eq({id=1}, meths.get_current_buf())
    end)

    it("does not trigger BufEnter, BufWinEnter", function()
      command("let g:fired = v:false")
      command("au BufEnter,BufWinEnter * let g:fired = v:true")

      eq({id=2}, meths.create_buf(true, false))
      meths.buf_set_lines(2, 0, -1, true, {"test", "text"})

      eq(false, eval('g:fired'))
    end)

    it('scratch-buffer', function()
      eq({id=2}, meths.create_buf(false, true))
      eq({id=3}, meths.create_buf(true, true))
      eq({id=4}, meths.create_buf(true, true))
      local scratch_bufs = { 2, 3, 4 }
      eq('  1 %a   "[No Name]"                    line 1\n'..
         '  3  h   "[Scratch]"                    line 0\n'..
         '  4  h   "[Scratch]"                    line 0',
         meths.exec('ls', true))
      -- current buffer didn't change
      eq({id=1}, meths.get_current_buf())

      local screen = Screen.new(20, 4)
      screen:set_default_attr_ids({
        [1] = {bold = true, foreground = Screen.colors.Blue1},
      })
      screen:attach()

      --
      -- Editing a scratch-buffer does NOT change its properties.
      --
      local edited_buf = 2
      meths.buf_set_lines(edited_buf, 0, -1, true, {"some text"})
      for _,b in ipairs(scratch_bufs) do
        eq('nofile', meths.buf_get_option(b, 'buftype'))
        eq('hide', meths.buf_get_option(b, 'bufhidden'))
        eq(false, meths.buf_get_option(b, 'swapfile'))
        eq(false, meths.buf_get_option(b, 'modeline'))
      end

      --
      -- Visiting a scratch-buffer DOES NOT change its properties.
      --
      meths.set_current_buf(edited_buf)
      screen:expect([[
        ^some text           |
        {1:~                   }|
        {1:~                   }|
                            |
      ]])
      eq('nofile', meths.buf_get_option(edited_buf, 'buftype'))
      eq('hide', meths.buf_get_option(edited_buf, 'bufhidden'))
      eq(false, meths.buf_get_option(edited_buf, 'swapfile'))
      eq(false, meths.buf_get_option(edited_buf, 'modeline'))

      -- Scratch buffer can be wiped without error.
      command('bwipe')
      screen:expect([[
        ^                    |
        {1:~                   }|
        {1:~                   }|
                            |
      ]])
    end)

    it('does not cause heap-use-after-free on exit while setting options', function()
      command('au OptionSet * q')
      command('silent! call nvim_create_buf(0, 1)')
    end)
  end)

  describe('nvim_get_runtime_file', function()
    local p = helpers.alter_slashes
    it('can find files', function()
      eq({}, meths.get_runtime_file("bork.borkbork", false))
      eq({}, meths.get_runtime_file("bork.borkbork", true))
      eq(1, #meths.get_runtime_file("autoload/msgpack.vim", false))
      eq(1, #meths.get_runtime_file("autoload/msgpack.vim", true))
      local val = meths.get_runtime_file("autoload/remote/*.vim", true)
      eq(2, #val)
      if endswith(val[1], "define.vim") then
        ok(endswith(val[1], p"autoload/remote/define.vim"))
        ok(endswith(val[2], p"autoload/remote/host.vim"))
      else
        ok(endswith(val[1], p"autoload/remote/host.vim"))
        ok(endswith(val[2], p"autoload/remote/define.vim"))
      end
      val = meths.get_runtime_file("autoload/remote/*.vim", false)
      eq(1, #val)
      ok(endswith(val[1], p"autoload/remote/define.vim")
         or endswith(val[1], p"autoload/remote/host.vim"))

      eq({}, meths.get_runtime_file("lua", true))
      eq({}, meths.get_runtime_file("lua/vim", true))
    end)

    it('can find directories', function()
      local val = meths.get_runtime_file("lua/", true)
      eq(1, #val)
      ok(endswith(val[1], p"lua/"))

      val = meths.get_runtime_file("lua/vim/", true)
      eq(1, #val)
      ok(endswith(val[1], p"lua/vim/"))

      eq({}, meths.get_runtime_file("foobarlang/", true))
    end)
  end)

  describe('nvim_get_all_options_info', function()
    it('should have key value pairs of option names', function()
      local options_info = meths.get_all_options_info()
      neq(nil, options_info.listchars)
      neq(nil, options_info.tabstop)

      eq(meths.get_option_info'winhighlight', options_info.winhighlight)
    end)

    it('should not crash when echoed', function()
      meths.exec("echo nvim_get_all_options_info()", true)
    end)
  end)

  describe('nvim_get_option_info', function()
    it('should error for unknown options', function()
      eq("no such option: 'bogus'", pcall_err(meths.get_option_info, 'bogus'))
    end)

    it('should return the same options for short and long name', function()
      eq(meths.get_option_info'winhl', meths.get_option_info'winhighlight')
    end)

    it('should have information about window options', function()
      eq({
        allows_duplicates = true,
        commalist = false;
        default = "";
        flaglist = false;
        global_local = false;
        last_set_chan = 0;
        last_set_linenr = 0;
        last_set_sid = 0;
        name = "winhighlight";
        scope = "win";
        shortname = "winhl";
        type = "string";
        was_set = false;
      }, meths.get_option_info'winhl')
    end)

    it('should have information about buffer options', function()
      eq({
        allows_duplicates = true,
        commalist = false,
        default = "",
        flaglist = false,
        global_local = false,
        last_set_chan = 0,
        last_set_linenr = 0,
        last_set_sid = 0,
        name = "filetype",
        scope = "buf",
        shortname = "ft",
        type = "string",
        was_set = false
      }, meths.get_option_info'filetype')
    end)

    it('should have information about global options', function()
      -- precondition: the option was changed from its default
      -- in test setup.
      eq(false, meths.get_option'showcmd')

      eq({
        allows_duplicates = true,
        commalist = false,
        default = true,
        flaglist = false,
        global_local = false,
        last_set_chan = 0,
        last_set_linenr = 0,
        last_set_sid = -2,
        name = "showcmd",
        scope = "global",
        shortname = "sc",
        type = "boolean",
        was_set = true
      }, meths.get_option_info'showcmd')
    end)
  end)

  describe('nvim_echo', function()
    local screen

    before_each(function()
      clear()
      screen = Screen.new(40, 8)
      screen:attach()
      screen:set_default_attr_ids({
        [0] = {bold=true, foreground=Screen.colors.Blue},
        [1] = {bold = true, foreground = Screen.colors.SeaGreen},
        [2] = {bold = true, reverse = true},
        [3] = {foreground = Screen.colors.Brown, bold = true}, -- Statement
        [4] = {foreground = Screen.colors.SlateBlue}, -- Special
      })
      command('highlight Statement gui=bold guifg=Brown')
      command('highlight Special guifg=SlateBlue')
    end)

    it('should clear cmdline message before echo', function()
      feed(':call nvim_echo([["msg"]], v:false, {})<CR>')
      screen:expect{grid=[[
        ^                                        |
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        msg                                     |
      ]]}
    end)

    it('can show highlighted line', function()
      nvim_async("echo", {{"msg_a"}, {"msg_b", "Statement"}, {"msg_c", "Special"}}, true, {})
      screen:expect{grid=[[
        ^                                        |
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        msg_a{3:msg_b}{4:msg_c}                         |
      ]]}
    end)

    it('can show highlighted multiline', function()
      nvim_async("echo", {{"msg_a\nmsg_a", "Statement"}, {"msg_b", "Special"}}, true, {})
      screen:expect{grid=[[
                                                |
        {0:~                                       }|
        {0:~                                       }|
        {0:~                                       }|
        {2:                                        }|
        {3:msg_a}                                   |
        {3:msg_a}{4:msg_b}                              |
        {1:Press ENTER or type command to continue}^ |
      ]]}
    end)

    it('can save message history', function()
      nvim('command', 'set cmdheight=2') -- suppress Press ENTER
      nvim("echo", {{"msg\nmsg"}, {"msg"}}, true, {})
      eq("msg\nmsgmsg", meths.exec('messages', true))
    end)

    it('can disable saving message history', function()
      nvim('command', 'set cmdheight=2') -- suppress Press ENTER
      nvim_async("echo", {{"msg\nmsg"}, {"msg"}}, false, {})
      eq("", meths.exec("messages", true))
    end)
  end)


  describe('nvim_open_term', function()
    local screen

    before_each(function()
      clear()
      screen = Screen.new(100, 35)
      screen:attach()
      screen:set_default_attr_ids({
        [0] = {bold=true, foreground=Screen.colors.Blue},
        [1] = {background = Screen.colors.Plum1};
        [2] = {background = tonumber('0xffff40'), bg_indexed = true};
        [3] = {background = Screen.colors.Plum1, fg_indexed = true, foreground = tonumber('0x00e000')};
        [4] = {bold = true, reverse = true, background = Screen.colors.Plum1};
      })
    end)

    it('can batch process sequences', function()
      local b = meths.create_buf(true,true)
      meths.open_win(b, false, {width=79, height=31, row=1, col=1, relative='editor'})
      local t = meths.open_term(b, {})

      meths.chan_send(t, io.open("test/functional/fixtures/smile2.cat", "r"):read("*a"))
      screen:expect{grid=[[
        ^                                                                                                    |
        {0:~}{1::smile                                                                         }{0:                    }|
        {0:~}{1:                            }{2:oooo$$$$$$$$$$$$oooo}{1:                               }{0:                    }|
        {0:~}{1:                        }{2:oo$$$$$$$$$$$$$$$$$$$$$$$$o}{1:                            }{0:                    }|
        {0:~}{1:                     }{2:oo$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$o}{1:         }{2:o$}{1:   }{2:$$}{1: }{2:o$}{1:      }{0:                    }|
        {0:~}{1:     }{2:o}{1: }{2:$}{1: }{2:oo}{1:        }{2:o$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$o}{1:       }{2:$$}{1: }{2:$$}{1: }{2:$$o$}{1:     }{0:                    }|
        {0:~}{1:  }{2:oo}{1: }{2:$}{1: }{2:$}{1: "}{2:$}{1:      }{2:o$$$$$$$$$}{1:    }{2:$$$$$$$$$$$$$}{1:    }{2:$$$$$$$$$o}{1:       }{2:$$$o$$o$}{1:      }{0:                    }|
        {0:~}{1:  "}{2:$$$$$$o$}{1:     }{2:o$$$$$$$$$}{1:      }{2:$$$$$$$$$$$}{1:      }{2:$$$$$$$$$$o}{1:    }{2:$$$$$$$$}{1:       }{0:                    }|
        {0:~}{1:    }{2:$$$$$$$}{1:    }{2:$$$$$$$$$$$}{1:      }{2:$$$$$$$$$$$}{1:      }{2:$$$$$$$$$$$$$$$$$$$$$$$}{1:       }{0:                    }|
        {0:~}{1:    }{2:$$$$$$$$$$$$$$$$$$$$$$$}{1:    }{2:$$$$$$$$$$$$$}{1:    }{2:$$$$$$$$$$$$$$}{1:  """}{2:$$$}{1:         }{0:                    }|
        {0:~}{1:     "}{2:$$$}{1:""""}{2:$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{1:     "}{2:$$$}{1:        }{0:                    }|
        {0:~}{1:      }{2:$$$}{1:   }{2:o$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{1:     "}{2:$$$o}{1:      }{0:                    }|
        {0:~}{1:     }{2:o$$}{1:"   }{2:$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{1:       }{2:$$$o}{1:     }{0:                    }|
        {0:~}{1:     }{2:$$$}{1:    }{2:$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{1:" "}{2:$$$$$$ooooo$$$$o}{1:   }{0:                    }|
        {0:~}{1:    }{2:o$$$oooo$$$$$}{1:  }{2:$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{1:   }{2:o$$$$$$$$$$$$$$$$$}{1:  }{0:                    }|
        {0:~}{1:    }{2:$$$$$$$$}{1:"}{2:$$$$}{1:   }{2:$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{1:     }{2:$$$$}{1:""""""""        }{0:                    }|
        {0:~}{1:   """"       }{2:$$$$}{1:    "}{2:$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{1:"      }{2:o$$$}{1:                 }{0:                    }|
        {0:~}{1:              "}{2:$$$o}{1:     """}{2:$$$$$$$$$$$$$$$$$$}{1:"}{2:$$}{1:"         }{2:$$$}{1:                  }{0:                    }|
        {0:~}{1:                }{2:$$$o}{1:          "}{2:$$}{1:""}{2:$$$$$$}{1:""""           }{2:o$$$}{1:                   }{0:                    }|
        {0:~}{1:                 }{2:$$$$o}{1:                                }{2:o$$$}{1:"                    }{0:                    }|
        {0:~}{1:                  "}{2:$$$$o}{1:      }{2:o$$$$$$o}{1:"}{2:$$$$o}{1:        }{2:o$$$$}{1:                      }{0:                    }|
        {0:~}{1:                    "}{2:$$$$$oo}{1:     ""}{2:$$$$o$$$$$o}{1:   }{2:o$$$$}{1:""                       }{0:                    }|
        {0:~}{1:                       ""}{2:$$$$$oooo}{1:  "}{2:$$$o$$$$$$$$$}{1:"""                          }{0:                    }|
        {0:~}{1:                          ""}{2:$$$$$$$oo}{1: }{2:$$$$$$$$$$}{1:                               }{0:                    }|
        {0:~}{1:                                  """"}{2:$$$$$$$$$$$}{1:                              }{0:                    }|
        {0:~}{1:                                      }{2:$$$$$$$$$$$$}{1:                             }{0:                    }|
        {0:~}{1:                                       }{2:$$$$$$$$$$}{1:"                             }{0:                    }|
        {0:~}{1:                                        "}{2:$$$}{1:""""                               }{0:                    }|
        {0:~}{1:                                                                               }{0:                    }|
        {0:~}{3:Press ENTER or type command to continue}{1:                                        }{0:                    }|
        {0:~}{4:term://~/config2/docs/pres//32693:vim --clean +smile         29,39          All}{0:                    }|
        {0:~}{1::call nvim__screenshot("smile2.cat")                                           }{0:                    }|
        {0:~                                                                                                   }|
        {0:~                                                                                                   }|
                                                                                                            |
      ]]}
    end)
  end)
end)
