local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local uv = vim.uv

local fmt = string.format
local dedent = t.dedent
local assert_alive = n.assert_alive
local NIL = vim.NIL
local clear, eq, neq = n.clear, t.eq, t.neq
local command = n.command
local command_output = n.api.nvim_command_output
local exec = n.exec
local exec_capture = n.exec_capture
local eval = n.eval
local expect = n.expect
local fn = n.fn
local api = n.api
local matches = t.matches
local pesc = vim.pesc
local mkdir_p = n.mkdir_p
local ok, nvim_async, feed = t.ok, n.nvim_async, n.feed
local async_meths = n.async_meths
local is_os = t.is_os
local parse_context = n.parse_context
local request = n.request
local rmdir = n.rmdir
local source = n.source
local next_msg = n.next_msg
local tmpname = t.tmpname
local write_file = t.write_file
local exec_lua = n.exec_lua
local exc_exec = n.exc_exec
local insert = n.insert
local skip = t.skip

local pcall_err = t.pcall_err
local format_string = require('test.format_string').format_string
local intchar2lua = t.intchar2lua
local mergedicts_copy = t.mergedicts_copy
local endswith = vim.endswith

describe('API', function()
  before_each(clear)

  it('validates requests', function()
    -- RPC
    matches('Invalid method: bogus$', pcall_err(request, 'bogus'))
    matches('Invalid method: … の り 。…$', pcall_err(request, '… の り 。…'))
    matches('Invalid method: <empty>$', pcall_err(request, ''))

    -- Non-RPC: rpcrequest(v:servername) uses internal channel.
    matches(
      'Invalid method: … の り 。…$',
      pcall_err(
        request,
        'nvim_eval',
        [=[rpcrequest(sockconnect('pipe', v:servername, {'rpc':1}), '… の り 。…')]=]
      )
    )
    matches(
      'Invalid method: bogus$',
      pcall_err(
        request,
        'nvim_eval',
        [=[rpcrequest(sockconnect('pipe', v:servername, {'rpc':1}), 'bogus')]=]
      )
    )

    -- XXX: This must be the last one, else next one will fail:
    --      "Packer instance already working. Use another Packer ..."
    matches("can't serialize object of type .$", pcall_err(request, nil))
  end)

  it('handles errors in async requests', function()
    local error_types = api.nvim_get_api_info()[2].error_types
    nvim_async('bogus')
    eq({
      'notification',
      'nvim_error_event',
      { error_types.Exception.id, 'Invalid method: bogus' },
    }, next_msg())
    -- error didn't close channel.
    assert_alive()
  end)

  it('failed async request emits nvim_error_event', function()
    local error_types = api.nvim_get_api_info()[2].error_types
    async_meths.nvim_command('bogus')
    eq({
      'notification',
      'nvim_error_event',
      { error_types.Exception.id, 'Vim:E492: Not an editor command: bogus' },
    }, next_msg())
    -- error didn't close channel.
    assert_alive()
  end)

  it('input is processed first when followed immediately by non-fast events', function()
    api.nvim_set_current_line('ab')
    async_meths.nvim_input('x')
    async_meths.nvim_exec_lua('_G.res1 = vim.api.nvim_get_current_line()', {})
    async_meths.nvim_exec_lua('_G.res2 = vim.api.nvim_get_current_line()', {})
    eq({ 'b', 'b' }, exec_lua('return { _G.res1, _G.res2 }'))
  end)

  it('does not set CA_COMMAND_BUSY #7254', function()
    command('split')
    command('autocmd WinEnter * startinsert')
    command('wincmd w')
    eq({ mode = 'i', blocking = false }, api.nvim_get_mode())
  end)

  describe('nvim_exec2', function()
    it('always returns table', function()
      -- In built version this results into `vim.empty_dict()`
      eq({}, api.nvim_exec2('echo "Hello"', {}))
      eq({}, api.nvim_exec2('echo "Hello"', { output = false }))
      eq({ output = 'Hello' }, api.nvim_exec2('echo "Hello"', { output = true }))
    end)

    it('default options', function()
      -- Should be equivalent to { output = false }
      api.nvim_exec2("let x0 = 'a'", {})
      eq('a', api.nvim_get_var('x0'))
    end)

    it('one-line input', function()
      api.nvim_exec2("let x1 = 'a'", { output = false })
      eq('a', api.nvim_get_var('x1'))
    end)

    it(':verbose set {option}?', function()
      api.nvim_exec2('set nowrap', { output = false })
      eq(
        { output = 'nowrap\n\tLast set from anonymous :source' },
        api.nvim_exec2('verbose set wrap?', { output = true })
      )

      -- Using script var to force creation of a script item
      api.nvim_exec2(
        [[
        let s:a = 1
        set nowrap
      ]],
        { output = false }
      )
      eq(
        { output = 'nowrap\n\tLast set from anonymous :source (script id 1)' },
        api.nvim_exec2('verbose set wrap?', { output = true })
      )
    end)

    it('multiline input', function()
      -- Heredoc + empty lines.
      api.nvim_exec2("let x2 = 'a'\n", { output = false })
      eq('a', api.nvim_get_var('x2'))
      api.nvim_exec2('lua <<EOF\n\n\n\ny=3\n\n\nEOF', { output = false })
      eq(3, api.nvim_eval("luaeval('y')"))

      eq({}, api.nvim_exec2('lua <<EOF\ny=3\nEOF', { output = false }))
      eq(3, api.nvim_eval("luaeval('y')"))

      -- Multiple statements
      api.nvim_exec2('let x1=1\nlet x2=2\nlet x3=3\n', { output = false })
      eq(1, api.nvim_eval('x1'))
      eq(2, api.nvim_eval('x2'))
      eq(3, api.nvim_eval('x3'))

      -- Functions
      api.nvim_exec2('function Foo()\ncall setline(1,["xxx"])\nendfunction', { output = false })
      eq('', api.nvim_get_current_line())
      api.nvim_exec2('call Foo()', { output = false })
      eq('xxx', api.nvim_get_current_line())

      -- Autocmds
      api.nvim_exec2('autocmd BufAdd * :let x1 = "Hello"', { output = false })
      command('new foo')
      eq('Hello', request('nvim_eval', 'g:x1'))

      -- Line continuations
      api.nvim_exec2(
        [[
        let abc = #{
          \ a: 1,
         "\ b: 2,
          \ c: 3
          \ }]],
        { output = false }
      )
      eq({ a = 1, c = 3 }, request('nvim_eval', 'g:abc'))

      -- try no spaces before continuations to catch off-by-one error
      api.nvim_exec2('let ab = #{\n\\a: 98,\n"\\ b: 2\n\\}', { output = false })
      eq({ a = 98 }, request('nvim_eval', 'g:ab'))

      -- Script scope (s:)
      eq(
        { output = 'ahoy! script-scoped varrrrr' },
        api.nvim_exec2(
          [[
          let s:pirate = 'script-scoped varrrrr'
          function! s:avast_ye_hades(s) abort
            return a:s .. ' ' .. s:pirate
          endfunction
          echo <sid>avast_ye_hades('ahoy!')
        ]],
          { output = true }
        )
      )

      eq(
        { output = "{'output': 'ahoy! script-scoped varrrrr'}" },
        api.nvim_exec2(
          [[
          let s:pirate = 'script-scoped varrrrr'
          function! Avast_ye_hades(s) abort
            return a:s .. ' ' .. s:pirate
          endfunction
          echo nvim_exec2('echo Avast_ye_hades(''ahoy!'')', {'output': v:true})
        ]],
          { output = true }
        )
      )

      matches(
        'Vim%(echo%):E121: Undefined variable: s:pirate$',
        pcall_err(
          request,
          'nvim_exec2',
          [[
          let s:pirate = 'script-scoped varrrrr'
          call nvim_exec2('echo s:pirate', {'output': v:true})
        ]],
          { output = false }
        )
      )

      -- Script items are created only on script var access
      eq(
        { output = '1\n0' },
        api.nvim_exec2(
          [[
          echo expand("<SID>")->empty()
          let s:a = 123
          echo expand("<SID>")->empty()
        ]],
          { output = true }
        )
      )

      eq(
        { output = '1\n0' },
        api.nvim_exec2(
          [[
          echo expand("<SID>")->empty()
          function s:a() abort
          endfunction
          echo expand("<SID>")->empty()
        ]],
          { output = true }
        )
      )
    end)

    it('non-ASCII input', function()
      api.nvim_exec2(
        [=[
        new
        exe "normal! i ax \n Ax "
        :%s/ax/--a1234--/g | :%s/Ax/--A1234--/g
      ]=],
        { output = false }
      )
      command('1')
      eq(' --a1234-- ', api.nvim_get_current_line())
      command('2')
      eq(' --A1234-- ', api.nvim_get_current_line())

      api.nvim_exec2(
        [[
        new
        call setline(1,['xxx'])
        call feedkeys('r')
        call feedkeys('ñ', 'xt')
      ]],
        { output = false }
      )
      eq('ñxx', api.nvim_get_current_line())
    end)

    it('execution error', function()
      eq(
        'nvim_exec2(): Vim:E492: Not an editor command: bogus_command',
        pcall_err(request, 'nvim_exec2', 'bogus_command', {})
      )
      eq('', api.nvim_eval('v:errmsg')) -- v:errmsg was not updated.
      eq('', eval('v:exception'))

      eq(
        'nvim_exec2(): Vim(buffer):E86: Buffer 23487 does not exist',
        pcall_err(request, 'nvim_exec2', 'buffer 23487', {})
      )
      eq('', eval('v:errmsg')) -- v:errmsg was not updated.
      eq('', eval('v:exception'))
    end)

    it('recursion', function()
      local fname = tmpname()
      write_file(fname, 'let x1 = "set from :source file"\n')
      -- nvim_exec2
      --   :source
      --     nvim_exec2
      request('nvim_exec2', [[
        let x2 = substitute('foo','o','X','g')
        let x4 = 'should be overwritten'
        call nvim_exec2("source ]] .. fname .. [[\nlet x3 = substitute('foo','foo','set by recursive nvim_exec2','g')\nlet x5='overwritten'\nlet x4=x5\n", {'output': v:false})
      ]], { output = false })
      eq('set from :source file', request('nvim_get_var', 'x1'))
      eq('fXX', request('nvim_get_var', 'x2'))
      eq('set by recursive nvim_exec2', request('nvim_get_var', 'x3'))
      eq('overwritten', request('nvim_get_var', 'x4'))
      eq('overwritten', request('nvim_get_var', 'x5'))
      os.remove(fname)
    end)

    it('traceback', function()
      local fname = tmpname()
      write_file(fname, 'echo "hello"\n')
      local sourcing_fname = tmpname()
      write_file(sourcing_fname, 'call nvim_exec2("source ' .. fname .. '", {"output": v:false})\n')
      api.nvim_exec2('set verbose=2', { output = false })
      local traceback_output = dedent([[
        line 0: sourcing "%s"
        line 0: sourcing "%s"
        hello
        finished sourcing %s
        continuing in nvim_exec2() called at %s:1
        finished sourcing %s
        continuing in nvim_exec2() called at nvim_exec2():0]]):format(
        sourcing_fname,
        fname,
        fname,
        sourcing_fname,
        sourcing_fname
      )
      eq(
        { output = traceback_output },
        api.nvim_exec2(
          'call nvim_exec2("source ' .. sourcing_fname .. '", {"output": v:false})',
          { output = true }
        )
      )
      os.remove(fname)
      os.remove(sourcing_fname)
    end)

    it('returns output', function()
      eq(
        { output = 'this is spinal tap' },
        api.nvim_exec2('lua <<EOF\n\n\nprint("this is spinal tap")\n\n\nEOF', { output = true })
      )
      eq({ output = '' }, api.nvim_exec2('echo', { output = true }))
      eq({ output = 'foo 42' }, api.nvim_exec2('echo "foo" 42', { output = true }))
    end)

    it('displays messages when opts.output=false', function()
      local screen = Screen.new(40, 8)
      screen:attach()
      api.nvim_exec2("echo 'hello'", { output = false })
      screen:expect {
        grid = [[
        ^                                        |
        {1:~                                       }|*6
        hello                                   |
      ]],
      }
    end)

    it("doesn't display messages when output=true", function()
      local screen = Screen.new(40, 6)
      screen:attach()
      api.nvim_exec2("echo 'hello'", { output = true })
      screen:expect {
        grid = [[
        ^                                        |
        {1:~                                       }|*4
                                                |
      ]],
      }
      exec([[
        func Print()
          call nvim_exec2('echo "hello"', { 'output': v:true })
        endfunc
      ]])
      feed([[:echon 1 | call Print() | echon 5<CR>]])
      screen:expect {
        grid = [[
        ^                                        |
        {1:~                                       }|*4
        15                                      |
      ]],
      }
    end)

    it('errors properly when command too recursive', function()
      exec_lua([[
        _G.success = false
        vim.api.nvim_create_user_command('Test', function()
          vim.api.nvim_exec2('Test', {})
          _G.success = true
        end, {})
      ]])
      pcall_err(command, 'Test')
      assert_alive()
      eq(false, exec_lua('return _G.success'))
    end)
  end)

  describe('nvim_command', function()
    it('works', function()
      local fname = tmpname()
      command('new')
      command('edit ' .. fname)
      command('normal itesting\napi')
      command('w')
      local f = assert(io.open(fname))
      if is_os('win') then
        eq('testing\r\napi\r\n', f:read('*a'))
      else
        eq('testing\napi\n', f:read('*a'))
      end
      f:close()
      os.remove(fname)
    end)

    it('Vimscript validation error: fails with specific error', function()
      local status, rv = pcall(command, 'bogus_command')
      eq(false, status) -- nvim_command() failed.
      eq('E492:', string.match(rv, 'E%d*:')) -- Vimscript error was returned.
      eq('', api.nvim_eval('v:errmsg')) -- v:errmsg was not updated.
      eq('', eval('v:exception'))
    end)

    it('Vimscript execution error: fails with specific error', function()
      local status, rv = pcall(command, 'buffer 23487')
      eq(false, status) -- nvim_command() failed.
      eq('E86: Buffer 23487 does not exist', string.match(rv, 'E%d*:.*'))
      eq('', eval('v:errmsg')) -- v:errmsg was not updated.
      eq('', eval('v:exception'))
    end)

    it('gives E493 instead of prompting on backwards range', function()
      command('split')
      eq(
        'Vim(windo):E493: Backwards range given: 2,1windo echo',
        pcall_err(command, '2,1windo echo')
      )
    end)
  end)

  describe('nvim_command_output', function()
    it('does not induce hit-enter prompt', function()
      api.nvim_ui_attach(80, 20, {})
      -- Induce a hit-enter prompt use nvim_input (non-blocking).
      command('set cmdheight=1')
      api.nvim_input([[:echo "hi\nhi2"<CR>]])

      -- Verify hit-enter prompt.
      eq({ mode = 'r', blocking = true }, api.nvim_get_mode())
      api.nvim_input([[<C-c>]])

      -- Verify NO hit-enter prompt.
      command_output([[echo "hi\nhi2"]])
      eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
    end)

    it('captures command output', function()
      eq('this is\nspinal tap', command_output([[echo "this is\nspinal tap"]]))
      eq('no line ending!', command_output([[echon "no line ending!"]]))
    end)

    it('captures empty command output', function()
      eq('', command_output('echo'))
    end)

    it('captures single-char command output', function()
      eq('x', command_output('echo "x"'))
    end)

    it('captures multiple commands', function()
      eq('foo\n  1 %a   "[No Name]"                    line 1', command_output('echo "foo" | ls'))
    end)

    it('captures nested execute()', function()
      eq(
        '\nnested1\nnested2\n  1 %a   "[No Name]"                    line 1',
        command_output([[echo execute('echo "nested1\nnested2"') | ls]])
      )
    end)

    it('captures nested nvim_command_output()', function()
      eq(
        'nested1\nnested2\n  1 %a   "[No Name]"                    line 1',
        command_output([[echo nvim_command_output('echo "nested1\nnested2"') | ls]])
      )
    end)

    it('returns shell |:!| output', function()
      local win_lf = is_os('win') and '\r' or ''
      eq(':!echo foo\r\n\nfoo' .. win_lf .. '\n', command_output([[!echo foo]]))
    end)

    it('Vimscript validation error: fails with specific error', function()
      local status, rv = pcall(command_output, 'bogus commannnd')
      eq(false, status) -- nvim_command_output() failed.
      eq('E492: Not an editor command: bogus commannnd', string.match(rv, 'E%d*:.*'))
      eq('', eval('v:errmsg')) -- v:errmsg was not updated.
      -- Verify NO hit-enter prompt.
      eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
    end)

    it('Vimscript execution error: fails with specific error', function()
      local status, rv = pcall(command_output, 'buffer 42')
      eq(false, status) -- nvim_command_output() failed.
      eq('E86: Buffer 42 does not exist', string.match(rv, 'E%d*:.*'))
      eq('', eval('v:errmsg')) -- v:errmsg was not updated.
      -- Verify NO hit-enter prompt.
      eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
    end)

    it('does not cause heap buffer overflow with large output', function()
      eq(eval('string(range(1000000))'), command_output('echo range(1000000)'))
    end)
  end)

  describe('nvim_eval', function()
    it('works', function()
      command('let g:v1 = "a"')
      command('let g:v2 = [1, 2, {"v3": 3}]')
      eq({ v1 = 'a', v2 = { 1, 2, { v3 = 3 } } }, api.nvim_eval('g:'))
    end)

    it('handles NULL-initialized strings correctly', function()
      eq(1, api.nvim_eval("matcharg(1) == ['', '']"))
      eq({ '', '' }, api.nvim_eval('matcharg(1)'))
    end)

    it('works under deprecated name', function()
      eq(2, request('vim_eval', '1+1'))
    end)

    it('Vimscript error: returns error details, does NOT update v:errmsg', function()
      eq('Vim:E121: Undefined variable: bogus', pcall_err(request, 'nvim_eval', 'bogus expression'))
      eq('', eval('v:errmsg')) -- v:errmsg was not updated.
    end)

    it('can return Lua function to Lua code', function()
      eq(
        [["a string with \"double quotes\" and 'single quotes'"]],
        exec_lua([=[
          local fun = vim.api.nvim_eval([[luaeval('string.format')]])
          return fun('%q', [[a string with "double quotes" and 'single quotes']])
        ]=])
      )
    end)
  end)

  describe('nvim_call_function', function()
    it('works', function()
      api.nvim_call_function('setqflist', { { { filename = 'something', lnum = 17 } }, 'r' })
      eq(17, api.nvim_call_function('getqflist', {})[1].lnum)
      eq(17, api.nvim_call_function('eval', { 17 }))
      eq('foo', api.nvim_call_function('simplify', { 'this/./is//redundant/../../../foo' }))
    end)

    it('Vimscript validation error: returns specific error, does NOT update v:errmsg', function()
      eq(
        'Vim:E117: Unknown function: bogus function',
        pcall_err(request, 'nvim_call_function', 'bogus function', { 'arg1' })
      )
      eq(
        'Vim:E119: Not enough arguments for function: atan',
        pcall_err(request, 'nvim_call_function', 'atan', {})
      )
      eq('', eval('v:exception'))
      eq('', eval('v:errmsg')) -- v:errmsg was not updated.
    end)

    it('Vimscript error: returns error details, does NOT update v:errmsg', function()
      eq(
        'Vim:E808: Number or Float required',
        pcall_err(request, 'nvim_call_function', 'atan', { 'foo' })
      )
      eq(
        'Vim:Invalid channel stream "xxx"',
        pcall_err(request, 'nvim_call_function', 'chanclose', { 999, 'xxx' })
      )
      eq(
        'Vim:E900: Invalid channel id',
        pcall_err(request, 'nvim_call_function', 'chansend', { 999, 'foo' })
      )
      eq('', eval('v:exception'))
      eq('', eval('v:errmsg')) -- v:errmsg was not updated.
    end)

    it('Vimscript exception: returns exception details, does NOT update v:errmsg', function()
      source([[
        function! Foo() abort
          throw 'wtf'
        endfunction
      ]])
      eq('function Foo, line 1: wtf', pcall_err(request, 'nvim_call_function', 'Foo', {}))
      eq('', eval('v:exception'))
      eq('', eval('v:errmsg')) -- v:errmsg was not updated.
    end)

    it('validation', function()
      -- stylua: ignore
      local too_many_args = { 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x', 'x' }
      source([[
        function! Foo(...) abort
          echo a:000
        endfunction
      ]])
      -- E740
      eq(
        'Function called with too many arguments',
        pcall_err(request, 'nvim_call_function', 'Foo', too_many_args)
      )
    end)

    it('can return Lua function to Lua code', function()
      eq(
        [["a string with \"double quotes\" and 'single quotes'"]],
        exec_lua([=[
          local fun = vim.api.nvim_call_function('luaeval', { 'string.format' })
          return fun('%q', [[a string with "double quotes" and 'single quotes']])
        ]=])
      )
    end)
  end)

  describe('nvim_call_dict_function', function()
    it('invokes Vimscript dict function', function()
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
      eq('Hello, World!', api.nvim_call_dict_function('g:test_dict_fn', 'F', { 'World' }))
      -- Funcref is sent as NIL over RPC.
      eq({ greeting = 'Hello', F = NIL }, api.nvim_get_var('test_dict_fn'))

      -- :help numbered-function
      eq('Hi, Moon ...', api.nvim_call_dict_function('g:test_dict_fn2', 'F2', { 'Moon' }))
      -- Funcref is sent as NIL over RPC.
      eq({ greeting = 'Hi', F2 = NIL }, api.nvim_get_var('test_dict_fn2'))

      -- Function specified via RPC dict.
      source('function! G() dict\n  return "@".(self.result)."@"\nendfunction')
      eq('@it works@', api.nvim_call_dict_function({ result = 'it works', G = 'G' }, 'G', {}))
    end)

    it('validation', function()
      command('let g:d={"baz":"zub","meep":[]}')
      eq(
        'Not found: bogus',
        pcall_err(request, 'nvim_call_dict_function', 'g:d', 'bogus', { 1, 2 })
      )
      eq(
        'Not a function: baz',
        pcall_err(request, 'nvim_call_dict_function', 'g:d', 'baz', { 1, 2 })
      )
      eq(
        'Not a function: meep',
        pcall_err(request, 'nvim_call_dict_function', 'g:d', 'meep', { 1, 2 })
      )
      eq(
        'Vim:E117: Unknown function: f',
        pcall_err(request, 'nvim_call_dict_function', { f = '' }, 'f', { 1, 2 })
      )
      eq(
        'Not a function: f',
        pcall_err(request, 'nvim_call_dict_function', "{ 'f': '' }", 'f', { 1, 2 })
      )
      eq(
        'dict argument type must be String or Dictionary',
        pcall_err(request, 'nvim_call_dict_function', 42, 'f', { 1, 2 })
      )
      eq(
        'Failed to evaluate dict expression',
        pcall_err(request, 'nvim_call_dict_function', 'foo', 'f', { 1, 2 })
      )
      eq('dict not found', pcall_err(request, 'nvim_call_dict_function', '42', 'f', { 1, 2 }))
      eq(
        'Invalid (empty) function name',
        pcall_err(request, 'nvim_call_dict_function', "{ 'f': '' }", '', { 1, 2 })
      )
    end)
  end)

  describe('nvim_set_current_dir', function()
    local start_dir

    before_each(function()
      fn.mkdir('Xtestdir')
      start_dir = fn.getcwd()
    end)

    after_each(function()
      n.rmdir('Xtestdir')
    end)

    it('works', function()
      api.nvim_set_current_dir('Xtestdir')
      eq(start_dir .. n.get_pathsep() .. 'Xtestdir', fn.getcwd())
    end)

    it('sets previous directory', function()
      api.nvim_set_current_dir('Xtestdir')
      command('cd -')
      eq(start_dir, fn.getcwd())
    end)
  end)

  describe('nvim_exec_lua', function()
    it('works', function()
      api.nvim_exec_lua('vim.api.nvim_set_var("test", 3)', {})
      eq(3, api.nvim_get_var('test'))

      eq(17, api.nvim_exec_lua('a, b = ...\nreturn a + b', { 10, 7 }))

      eq(NIL, api.nvim_exec_lua('function xx(a,b)\nreturn a..b\nend', {}))
      eq('xy', api.nvim_exec_lua('return xx(...)', { 'x', 'y' }))

      -- Deprecated name: nvim_execute_lua.
      eq('xy', api.nvim_execute_lua('return xx(...)', { 'x', 'y' }))
    end)

    it('reports errors', function()
      eq(
        [[Error loading lua: [string "<nvim>"]:0: '=' expected near '+']],
        pcall_err(api.nvim_exec_lua, 'a+*b', {})
      )

      eq(
        [[Error loading lua: [string "<nvim>"]:0: unexpected symbol near '1']],
        pcall_err(api.nvim_exec_lua, '1+2', {})
      )

      eq(
        [[Error loading lua: [string "<nvim>"]:0: unexpected symbol]],
        pcall_err(api.nvim_exec_lua, 'aa=bb\0', {})
      )

      eq(
        [[attempt to call global 'bork' (a nil value)]],
        pcall_err(api.nvim_exec_lua, 'bork()', {})
      )

      eq('did\nthe\nfail', pcall_err(api.nvim_exec_lua, 'error("did\\nthe\\nfail")', {}))
    end)

    it('uses native float values', function()
      eq(2.5, api.nvim_exec_lua('return select(1, ...)', { 2.5 }))
      eq('2.5', api.nvim_exec_lua('return vim.inspect(...)', { 2.5 }))

      -- "special" float values are still accepted as return values.
      eq(2.5, api.nvim_exec_lua("return vim.api.nvim_eval('2.5')", {}))
      eq(
        '{\n  [false] = 2.5,\n  [true] = 3\n}',
        api.nvim_exec_lua("return vim.inspect(vim.api.nvim_eval('2.5'))", {})
      )
    end)
  end)

  describe('nvim_notify', function()
    it('can notify a info message', function()
      api.nvim_notify('hello world', 2, {})
    end)

    it('can be overridden', function()
      command('lua vim.notify = function(...) return 42 end')
      eq(42, api.nvim_exec_lua("return vim.notify('Hello world')", {}))
      api.nvim_notify('hello world', 4, {})
    end)
  end)

  describe('nvim_input', function()
    it('Vimscript error: does NOT fail, updates v:errmsg', function()
      local status, _ = pcall(api.nvim_input, ':call bogus_fn()<CR>')
      local v_errnum = string.match(api.nvim_eval('v:errmsg'), 'E%d*:')
      eq(true, status) -- nvim_input() did not fail.
      eq('E117:', v_errnum) -- v:errmsg was updated.
    end)

    it('does not crash even if trans_special result is largest #11788, #12287', function()
      command("call nvim_input('<M-'.nr2char(0x40000000).'>')")
      eq(1, eval('1'))
    end)
  end)

  describe('nvim_paste', function()
    it('validation', function()
      eq("Invalid 'phase': -2", pcall_err(request, 'nvim_paste', 'foo', true, -2))
      eq("Invalid 'phase': 4", pcall_err(request, 'nvim_paste', 'foo', true, 4))
    end)
    local function run_streamed_paste_tests()
      it('stream: multiple chunks form one undo-block', function()
        api.nvim_paste('1/chunk 1 (start)\n', true, 1)
        api.nvim_paste('1/chunk 2 (end)\n', true, 3)
        local expected1 = [[
          1/chunk 1 (start)
          1/chunk 2 (end)
          ]]
        expect(expected1)
        api.nvim_paste('2/chunk 1 (start)\n', true, 1)
        api.nvim_paste('2/chunk 2\n', true, 2)
        expect([[
          1/chunk 1 (start)
          1/chunk 2 (end)
          2/chunk 1 (start)
          2/chunk 2
          ]])
        api.nvim_paste('2/chunk 3\n', true, 2)
        api.nvim_paste('2/chunk 4 (end)\n', true, 3)
        expect([[
          1/chunk 1 (start)
          1/chunk 2 (end)
          2/chunk 1 (start)
          2/chunk 2
          2/chunk 3
          2/chunk 4 (end)
          ]])
        feed('u') -- Undo.
        expect(expected1)
      end)
      it('stream: Insert mode', function()
        -- If nvim_paste() calls :undojoin without making any changes, this makes it an error.
        feed('afoo<Esc>u')
        feed('i')
        api.nvim_paste('aaaaaa', false, 1)
        api.nvim_paste('bbbbbb', false, 2)
        api.nvim_paste('cccccc', false, 2)
        api.nvim_paste('dddddd', false, 3)
        expect('aaaaaabbbbbbccccccdddddd')
        feed('<Esc>u')
        expect('')
      end)
      describe('stream: Normal mode', function()
        describe('on empty line', function()
          before_each(function()
            -- If nvim_paste() calls :undojoin without making any changes, this makes it an error.
            feed('afoo<Esc>u')
          end)
          after_each(function()
            feed('u')
            expect('')
          end)
          it('pasting one line', function()
            api.nvim_paste('aaaaaa', false, 1)
            api.nvim_paste('bbbbbb', false, 2)
            api.nvim_paste('cccccc', false, 2)
            api.nvim_paste('dddddd', false, 3)
            expect('aaaaaabbbbbbccccccdddddd')
          end)
          it('pasting multiple lines', function()
            api.nvim_paste('aaaaaa\n', false, 1)
            api.nvim_paste('bbbbbb\n', false, 2)
            api.nvim_paste('cccccc\n', false, 2)
            api.nvim_paste('dddddd', false, 3)
            expect([[
            aaaaaa
            bbbbbb
            cccccc
            dddddd]])
          end)
        end)
        describe('not at the end of a line', function()
          before_each(function()
            feed('i||<Esc>')
            -- If nvim_paste() calls :undojoin without making any changes, this makes it an error.
            feed('afoo<Esc>u')
            feed('0')
          end)
          after_each(function()
            feed('u')
            expect('||')
          end)
          it('pasting one line', function()
            api.nvim_paste('aaaaaa', false, 1)
            api.nvim_paste('bbbbbb', false, 2)
            api.nvim_paste('cccccc', false, 2)
            api.nvim_paste('dddddd', false, 3)
            expect('|aaaaaabbbbbbccccccdddddd|')
          end)
          it('pasting multiple lines', function()
            api.nvim_paste('aaaaaa\n', false, 1)
            api.nvim_paste('bbbbbb\n', false, 2)
            api.nvim_paste('cccccc\n', false, 2)
            api.nvim_paste('dddddd', false, 3)
            expect([[
            |aaaaaa
            bbbbbb
            cccccc
            dddddd|]])
          end)
        end)
        describe('at the end of a line', function()
          before_each(function()
            feed('i||<Esc>')
            -- If nvim_paste() calls :undojoin without making any changes, this makes it an error.
            feed('afoo<Esc>u')
            feed('2|')
          end)
          after_each(function()
            feed('u')
            expect('||')
          end)
          it('pasting one line', function()
            api.nvim_paste('aaaaaa', false, 1)
            api.nvim_paste('bbbbbb', false, 2)
            api.nvim_paste('cccccc', false, 2)
            api.nvim_paste('dddddd', false, 3)
            expect('||aaaaaabbbbbbccccccdddddd')
          end)
          it('pasting multiple lines', function()
            api.nvim_paste('aaaaaa\n', false, 1)
            api.nvim_paste('bbbbbb\n', false, 2)
            api.nvim_paste('cccccc\n', false, 2)
            api.nvim_paste('dddddd', false, 3)
            expect([[
              ||aaaaaa
              bbbbbb
              cccccc
              dddddd]])
          end)
        end)
      end)
      describe('stream: Visual mode', function()
        describe('neither end at the end of a line', function()
          before_each(function()
            feed('i|xxx<CR>xxx|<Esc>')
            -- If nvim_paste() calls :undojoin without making any changes, this makes it an error.
            feed('afoo<Esc>u')
            feed('3|vhk')
          end)
          after_each(function()
            feed('u')
            expect([[
            |xxx
            xxx|]])
          end)
          it('with non-empty chunks', function()
            api.nvim_paste('aaaaaa', false, 1)
            api.nvim_paste('bbbbbb', false, 2)
            api.nvim_paste('cccccc', false, 2)
            api.nvim_paste('dddddd', false, 3)
            expect('|aaaaaabbbbbbccccccdddddd|')
          end)
          it('with empty first chunk', function()
            api.nvim_paste('', false, 1)
            api.nvim_paste('bbbbbb', false, 2)
            api.nvim_paste('cccccc', false, 2)
            api.nvim_paste('dddddd', false, 3)
            expect('|bbbbbbccccccdddddd|')
          end)
          it('with all chunks empty', function()
            api.nvim_paste('', false, 1)
            api.nvim_paste('', false, 2)
            api.nvim_paste('', false, 2)
            api.nvim_paste('', false, 3)
            expect('||')
          end)
        end)
        describe('cursor at the end of a line', function()
          before_each(function()
            feed('i||xxx<CR>xxx<Esc>')
            -- If nvim_paste() calls :undojoin without making any changes, this makes it an error.
            feed('afoo<Esc>u')
            feed('3|vko')
          end)
          after_each(function()
            feed('u')
            expect([[
              ||xxx
              xxx]])
          end)
          it('with non-empty chunks', function()
            api.nvim_paste('aaaaaa', false, 1)
            api.nvim_paste('bbbbbb', false, 2)
            api.nvim_paste('cccccc', false, 2)
            api.nvim_paste('dddddd', false, 3)
            expect('||aaaaaabbbbbbccccccdddddd')
          end)
          it('with empty first chunk', function()
            api.nvim_paste('', false, 1)
            api.nvim_paste('bbbbbb', false, 2)
            api.nvim_paste('cccccc', false, 2)
            api.nvim_paste('dddddd', false, 3)
            expect('||bbbbbbccccccdddddd')
          end)
        end)
        describe('other end at the end of a line', function()
          before_each(function()
            feed('i||xxx<CR>xxx<Esc>')
            -- If nvim_paste() calls :undojoin without making any changes, this makes it an error.
            feed('afoo<Esc>u')
            feed('3|vk')
          end)
          after_each(function()
            feed('u')
            expect([[
              ||xxx
              xxx]])
          end)
          it('with non-empty chunks', function()
            api.nvim_paste('aaaaaa', false, 1)
            api.nvim_paste('bbbbbb', false, 2)
            api.nvim_paste('cccccc', false, 2)
            api.nvim_paste('dddddd', false, 3)
            expect('||aaaaaabbbbbbccccccdddddd')
          end)
          it('with empty first chunk', function()
            api.nvim_paste('', false, 1)
            api.nvim_paste('bbbbbb', false, 2)
            api.nvim_paste('cccccc', false, 2)
            api.nvim_paste('dddddd', false, 3)
            expect('||bbbbbbccccccdddddd')
          end)
        end)
      end)
      describe('stream: linewise Visual mode', function()
        before_each(function()
          feed('i123456789<CR>987654321<CR>123456789<Esc>')
          -- If nvim_paste() calls :undojoin without making any changes, this makes it an error.
          feed('afoo<Esc>u')
        end)
        after_each(function()
          feed('u')
          expect([[
            123456789
            987654321
            123456789]])
        end)
        describe('selecting the start of a file', function()
          before_each(function()
            feed('ggV')
          end)
          it('pasting text without final new line', function()
            api.nvim_paste('aaaaaa\n', false, 1)
            api.nvim_paste('bbbbbb\n', false, 2)
            api.nvim_paste('cccccc\n', false, 2)
            api.nvim_paste('dddddd', false, 3)
            expect([[
              aaaaaa
              bbbbbb
              cccccc
              dddddd987654321
              123456789]])
          end)
          it('pasting text with final new line', function()
            api.nvim_paste('aaaaaa\n', false, 1)
            api.nvim_paste('bbbbbb\n', false, 2)
            api.nvim_paste('cccccc\n', false, 2)
            api.nvim_paste('dddddd\n', false, 3)
            expect([[
              aaaaaa
              bbbbbb
              cccccc
              dddddd
              987654321
              123456789]])
          end)
        end)
        describe('selecting the middle of a file', function()
          before_each(function()
            feed('2ggV')
          end)
          it('pasting text without final new line', function()
            api.nvim_paste('aaaaaa\n', false, 1)
            api.nvim_paste('bbbbbb\n', false, 2)
            api.nvim_paste('cccccc\n', false, 2)
            api.nvim_paste('dddddd', false, 3)
            expect([[
              123456789
              aaaaaa
              bbbbbb
              cccccc
              dddddd123456789]])
          end)
          it('pasting text with final new line', function()
            api.nvim_paste('aaaaaa\n', false, 1)
            api.nvim_paste('bbbbbb\n', false, 2)
            api.nvim_paste('cccccc\n', false, 2)
            api.nvim_paste('dddddd\n', false, 3)
            expect([[
              123456789
              aaaaaa
              bbbbbb
              cccccc
              dddddd
              123456789]])
          end)
        end)
        describe('selecting the end of a file', function()
          before_each(function()
            feed('3ggV')
          end)
          it('pasting text without final new line', function()
            api.nvim_paste('aaaaaa\n', false, 1)
            api.nvim_paste('bbbbbb\n', false, 2)
            api.nvim_paste('cccccc\n', false, 2)
            api.nvim_paste('dddddd', false, 3)
            expect([[
              123456789
              987654321
              aaaaaa
              bbbbbb
              cccccc
              dddddd]])
          end)
          it('pasting text with final new line', function()
            api.nvim_paste('aaaaaa\n', false, 1)
            api.nvim_paste('bbbbbb\n', false, 2)
            api.nvim_paste('cccccc\n', false, 2)
            api.nvim_paste('dddddd\n', false, 3)
            expect([[
              123456789
              987654321
              aaaaaa
              bbbbbb
              cccccc
              dddddd
              ]])
          end)
        end)
        describe('selecting the whole file', function()
          before_each(function()
            feed('ggVG')
          end)
          it('pasting text without final new line', function()
            api.nvim_paste('aaaaaa\n', false, 1)
            api.nvim_paste('bbbbbb\n', false, 2)
            api.nvim_paste('cccccc\n', false, 2)
            api.nvim_paste('dddddd', false, 3)
            expect([[
              aaaaaa
              bbbbbb
              cccccc
              dddddd]])
          end)
          it('pasting text with final new line', function()
            api.nvim_paste('aaaaaa\n', false, 1)
            api.nvim_paste('bbbbbb\n', false, 2)
            api.nvim_paste('cccccc\n', false, 2)
            api.nvim_paste('dddddd\n', false, 3)
            expect([[
              aaaaaa
              bbbbbb
              cccccc
              dddddd
              ]])
          end)
        end)
      end)
    end
    describe('without virtualedit,', function()
      run_streamed_paste_tests()
    end)
    describe('with virtualedit=onemore,', function()
      before_each(function()
        command('set virtualedit=onemore')
      end)
      run_streamed_paste_tests()
    end)
    it('non-streaming', function()
      -- With final "\n".
      api.nvim_paste('line 1\nline 2\nline 3\n', true, -1)
      expect([[
        line 1
        line 2
        line 3
        ]])
      eq({ 0, 4, 1, 0 }, fn.getpos('.')) -- Cursor follows the paste.
      eq(false, api.nvim_get_option_value('paste', {}))
      command('%delete _')
      -- Without final "\n".
      api.nvim_paste('line 1\nline 2\nline 3', true, -1)
      expect([[
        line 1
        line 2
        line 3]])
      eq({ 0, 3, 6, 0 }, fn.getpos('.'))
      command('%delete _')
      -- CRLF #10872
      api.nvim_paste('line 1\r\nline 2\r\nline 3\r\n', true, -1)
      expect([[
        line 1
        line 2
        line 3
        ]])
      eq({ 0, 4, 1, 0 }, fn.getpos('.'))
      command('%delete _')
      -- CRLF without final "\n".
      api.nvim_paste('line 1\r\nline 2\r\nline 3\r', true, -1)
      expect([[
        line 1
        line 2
        line 3
        ]])
      eq({ 0, 4, 1, 0 }, fn.getpos('.'))
      command('%delete _')
      -- CRLF without final "\r\n".
      api.nvim_paste('line 1\r\nline 2\r\nline 3', true, -1)
      expect([[
        line 1
        line 2
        line 3]])
      eq({ 0, 3, 6, 0 }, fn.getpos('.'))
      command('%delete _')
      -- Various other junk.
      api.nvim_paste('line 1\r\n\r\rline 2\nline 3\rline 4\r', true, -1)
      expect('line 1\n\n\nline 2\nline 3\nline 4\n')
      eq({ 0, 7, 1, 0 }, fn.getpos('.'))
      eq(false, api.nvim_get_option_value('paste', {}))
    end)
    it('Replace-mode', function()
      -- Within single line
      api.nvim_put({ 'aabbccdd', 'eeffgghh', 'iijjkkll' }, 'c', true, false)
      command('normal l')
      command('startreplace')
      api.nvim_paste('123456', true, -1)
      expect([[
      a123456d
      eeffgghh
      iijjkkll]])
      command('%delete _')
      -- Across lines
      api.nvim_put({ 'aabbccdd', 'eeffgghh', 'iijjkkll' }, 'c', true, false)
      command('normal l')
      command('startreplace')
      api.nvim_paste('123\n456', true, -1)
      expect([[
      a123
      456d
      eeffgghh
      iijjkkll]])
    end)
    it('when searching in Visual mode', function()
      feed('v/')
      api.nvim_paste('aabbccdd', true, -1)
      eq('aabbccdd', fn.getcmdline())
      expect('')
    end)
    it('mappings are disabled in Cmdline mode', function()
      command('cnoremap a b')
      feed(':')
      api.nvim_paste('a', true, -1)
      eq('a', fn.getcmdline())
    end)
    it('pasted text is saved in cmdline history when <CR> comes from mapping #20957', function()
      command('cnoremap <CR> <CR>')
      feed(':')
      api.nvim_paste('echo', true, -1)
      eq('', fn.histget(':'))
      feed('<CR>')
      eq('echo', fn.histget(':'))
    end)
    it('pasting with empty last chunk in Cmdline mode', function()
      local screen = Screen.new(20, 4)
      screen:attach()
      feed(':')
      api.nvim_paste('Foo', true, 1)
      api.nvim_paste('', true, 3)
      screen:expect([[
                            |
        {1:~                   }|*2
        :Foo^                |
      ]])
    end)
    it('pasting text with control characters in Cmdline mode', function()
      local screen = Screen.new(20, 4)
      screen:attach()
      feed(':')
      api.nvim_paste('normal! \023\022\006\027', true, -1)
      screen:expect([[
                            |
        {1:~                   }|*2
        :normal! {18:^W^V^F^[}^   |
      ]])
    end)
    it('crlf=false does not break lines at CR, CRLF', function()
      api.nvim_paste('line 1\r\n\r\rline 2\nline 3\rline 4\r', false, -1)
      expect('line 1\r\n\r\rline 2\nline 3\rline 4\r')
      eq({ 0, 3, 14, 0 }, fn.getpos('.'))
    end)
    it('vim.paste() failure', function()
      api.nvim_exec_lua('vim.paste = (function(lines, phase) error("fake fail") end)', {})
      eq('fake fail', pcall_err(request, 'nvim_paste', 'line 1\nline 2\nline 3', false, 1))
    end)
  end)

  describe('nvim_put', function()
    it('validation', function()
      eq(
        "Invalid 'line': expected String, got Integer",
        pcall_err(request, 'nvim_put', { 42 }, 'l', false, false)
      )
      eq("Invalid 'type': 'x'", pcall_err(request, 'nvim_put', { 'foo' }, 'x', false, false))
    end)
    it("fails if 'nomodifiable'", function()
      command('set nomodifiable')
      eq(
        [[Vim:E21: Cannot make changes, 'modifiable' is off]],
        pcall_err(request, 'nvim_put', { 'a', 'b' }, 'l', true, true)
      )
    end)
    it('inserts text', function()
      -- linewise
      api.nvim_put({ 'line 1', 'line 2', 'line 3' }, 'l', true, true)
      expect([[

        line 1
        line 2
        line 3]])
      eq({ 0, 4, 1, 0 }, fn.getpos('.'))
      command('%delete _')
      -- charwise
      api.nvim_put({ 'line 1', 'line 2', 'line 3' }, 'c', true, false)
      expect([[
        line 1
        line 2
        line 3]])
      eq({ 0, 1, 1, 0 }, fn.getpos('.')) -- follow=false
      -- blockwise
      api.nvim_put({ 'AA', 'BB' }, 'b', true, true)
      expect([[
        lAAine 1
        lBBine 2
        line 3]])
      eq({ 0, 2, 4, 0 }, fn.getpos('.'))
      command('%delete _')
      -- Empty lines list.
      api.nvim_put({}, 'c', true, true)
      eq({ 0, 1, 1, 0 }, fn.getpos('.'))
      expect([[]])
      -- Single empty line.
      api.nvim_put({ '' }, 'c', true, true)
      eq({ 0, 1, 1, 0 }, fn.getpos('.'))
      expect([[
      ]])
      api.nvim_put({ 'AB' }, 'c', true, true)
      -- after=false, follow=true
      api.nvim_put({ 'line 1', 'line 2' }, 'c', false, true)
      expect([[
        Aline 1
        line 2B]])
      eq({ 0, 2, 7, 0 }, fn.getpos('.'))
      command('%delete _')
      api.nvim_put({ 'AB' }, 'c', true, true)
      -- after=false, follow=false
      api.nvim_put({ 'line 1', 'line 2' }, 'c', false, false)
      expect([[
        Aline 1
        line 2B]])
      eq({ 0, 1, 2, 0 }, fn.getpos('.'))
      eq('', api.nvim_eval('v:errmsg'))
    end)

    it('detects charwise/linewise text (empty {type})', function()
      -- linewise (final item is empty string)
      api.nvim_put({ 'line 1', 'line 2', 'line 3', '' }, '', true, true)
      expect([[

        line 1
        line 2
        line 3]])
      eq({ 0, 4, 1, 0 }, fn.getpos('.'))
      command('%delete _')
      -- charwise (final item is non-empty)
      api.nvim_put({ 'line 1', 'line 2', 'line 3' }, '', true, true)
      expect([[
        line 1
        line 2
        line 3]])
      eq({ 0, 3, 6, 0 }, fn.getpos('.'))
    end)

    it('allows block width', function()
      -- behave consistently with setreg(); support "\022{NUM}" return by getregtype()
      api.nvim_put({ 'line 1', 'line 2', 'line 3' }, 'l', false, false)
      expect([[
        line 1
        line 2
        line 3
        ]])

      -- larger width create spaces
      api.nvim_put({ 'a', 'bc' }, 'b3', false, false)
      expect([[
        a  line 1
        bc line 2
        line 3
        ]])
      -- smaller width is ignored
      api.nvim_put({ 'xxx', 'yyy' }, '\0221', false, true)
      expect([[
        xxxa  line 1
        yyybc line 2
        line 3
        ]])
      eq("Invalid 'type': 'bx'", pcall_err(api.nvim_put, { 'xxx', 'yyy' }, 'bx', false, true))
      eq("Invalid 'type': 'b3x'", pcall_err(api.nvim_put, { 'xxx', 'yyy' }, 'b3x', false, true))
    end)
  end)

  describe('nvim_strwidth', function()
    it('works', function()
      eq(3, api.nvim_strwidth('abc'))
      -- 6 + (neovim)
      -- 19 * 2 (each japanese character occupies two cells)
      eq(44, api.nvim_strwidth('neovimのデザインかなりまともなのになってる。'))
    end)

    it('cannot handle NULs', function()
      eq(0, api.nvim_strwidth('\0abc'))
    end)
  end)

  describe('nvim_get_current_line, nvim_set_current_line', function()
    it('works', function()
      eq('', api.nvim_get_current_line())
      api.nvim_set_current_line('abc')
      eq('abc', api.nvim_get_current_line())
    end)
  end)

  describe('set/get/del variables', function()
    it('validation', function()
      eq('Key not found: bogus', pcall_err(api.nvim_get_var, 'bogus'))
      eq('Key not found: bogus', pcall_err(api.nvim_del_var, 'bogus'))
    end)

    it('nvim_get_var, nvim_set_var, nvim_del_var', function()
      api.nvim_set_var('lua', { 1, 2, { ['3'] = 1 } })
      eq({ 1, 2, { ['3'] = 1 } }, api.nvim_get_var('lua'))
      eq({ 1, 2, { ['3'] = 1 } }, api.nvim_eval('g:lua'))
      eq(1, fn.exists('g:lua'))
      api.nvim_del_var('lua')
      eq(0, fn.exists('g:lua'))
      eq('Key not found: lua', pcall_err(api.nvim_del_var, 'lua'))
      api.nvim_set_var('lua', 1)

      -- Empty keys are allowed in Vim dicts (and msgpack).
      api.nvim_set_var('dict_empty_key', { [''] = 'empty key' })
      eq({ [''] = 'empty key' }, api.nvim_get_var('dict_empty_key'))

      -- Set locked g: var.
      command('lockvar lua')
      eq('Key is locked: lua', pcall_err(api.nvim_del_var, 'lua'))
      eq('Key is locked: lua', pcall_err(api.nvim_set_var, 'lua', 1))

      exec([[
        function Test()
        endfunction
        function s:Test()
        endfunction
        let g:Unknown_func = function('Test')
        let g:Unknown_script_func = function('s:Test')
      ]])
      eq(NIL, api.nvim_get_var('Unknown_func'))
      eq(NIL, api.nvim_get_var('Unknown_script_func'))

      -- Check if autoload works properly
      local pathsep = n.get_pathsep()
      local xconfig = 'Xhome' .. pathsep .. 'Xconfig'
      local xdata = 'Xhome' .. pathsep .. 'Xdata'
      local autoload_folder = table.concat({ xconfig, 'nvim', 'autoload' }, pathsep)
      local autoload_file = table.concat({ autoload_folder, 'testload.vim' }, pathsep)
      mkdir_p(autoload_folder)
      write_file(autoload_file, [[let testload#value = 2]])

      clear { args_rm = { '-u' }, env = { XDG_CONFIG_HOME = xconfig, XDG_DATA_HOME = xdata } }
      eq(2, api.nvim_get_var('testload#value'))
      rmdir('Xhome')
    end)

    it('nvim_get_vvar, nvim_set_vvar', function()
      eq('Key is read-only: count', pcall_err(request, 'nvim_set_vvar', 'count', 42))
      eq('Dictionary is locked', pcall_err(request, 'nvim_set_vvar', 'nosuchvar', 42))
      api.nvim_set_vvar('errmsg', 'set by API')
      eq('set by API', api.nvim_get_vvar('errmsg'))
      api.nvim_set_vvar('errmsg', 42)
      eq('42', eval('v:errmsg'))
      api.nvim_set_vvar('oldfiles', { 'one', 'two' })
      eq({ 'one', 'two' }, eval('v:oldfiles'))
      api.nvim_set_vvar('oldfiles', {})
      eq({}, eval('v:oldfiles'))
      eq(
        'Setting v:oldfiles to value with wrong type',
        pcall_err(api.nvim_set_vvar, 'oldfiles', 'a')
      )
      eq({}, eval('v:oldfiles'))

      feed('i foo foo foo<Esc>0/foo<CR>')
      eq({ 1, 1 }, api.nvim_win_get_cursor(0))
      eq(1, eval('v:searchforward'))
      feed('n')
      eq({ 1, 5 }, api.nvim_win_get_cursor(0))
      api.nvim_set_vvar('searchforward', 0)
      eq(0, eval('v:searchforward'))
      feed('n')
      eq({ 1, 1 }, api.nvim_win_get_cursor(0))
      api.nvim_set_vvar('searchforward', 1)
      eq(1, eval('v:searchforward'))
      feed('n')
      eq({ 1, 5 }, api.nvim_win_get_cursor(0))

      local screen = Screen.new(60, 3)
      screen:attach()
      eq(1, eval('v:hlsearch'))
      screen:expect {
        grid = [[
         {10:foo} {10:^foo} {10:foo}                                                |
        {1:~                                                           }|
                                                                    |
      ]],
      }
      api.nvim_set_vvar('hlsearch', 0)
      eq(0, eval('v:hlsearch'))
      screen:expect {
        grid = [[
         foo ^foo foo                                                |
        {1:~                                                           }|
                                                                    |
      ]],
      }
      api.nvim_set_vvar('hlsearch', 1)
      eq(1, eval('v:hlsearch'))
      screen:expect {
        grid = [[
         {10:foo} {10:^foo} {10:foo}                                                |
        {1:~                                                           }|
                                                                    |
      ]],
      }
    end)

    it('vim_set_var returns the old value', function()
      local val1 = { 1, 2, { ['3'] = 1 } }
      local val2 = { 4, 7 }
      eq(NIL, request('vim_set_var', 'lua', val1))
      eq(val1, request('vim_set_var', 'lua', val2))
    end)

    it('vim_del_var returns the old value', function()
      local val1 = { 1, 2, { ['3'] = 1 } }
      local val2 = { 4, 7 }
      eq(NIL, request('vim_set_var', 'lua', val1))
      eq(val1, request('vim_set_var', 'lua', val2))
      eq(val2, request('vim_del_var', 'lua'))
    end)

    it('truncates values with NULs in them', function()
      api.nvim_set_var('xxx', 'ab\0cd')
      eq('ab', api.nvim_get_var('xxx'))
    end)
  end)

  describe('nvim_get_option_value, nvim_set_option_value', function()
    it('works', function()
      ok(api.nvim_get_option_value('equalalways', {}))
      api.nvim_set_option_value('equalalways', false, {})
      ok(not api.nvim_get_option_value('equalalways', {}))
    end)

    it('works to get global value of local options', function()
      eq(false, api.nvim_get_option_value('lisp', {}))
      eq(8, api.nvim_get_option_value('shiftwidth', {}))
    end)

    it('works to set global value of local options', function()
      api.nvim_set_option_value('lisp', true, { scope = 'global' })
      eq(true, api.nvim_get_option_value('lisp', { scope = 'global' }))
      eq(false, api.nvim_get_option_value('lisp', {}))
      eq(nil, command_output('setglobal lisp?'):match('nolisp'))
      eq('nolisp', command_output('setlocal lisp?'):match('nolisp'))
      api.nvim_set_option_value('shiftwidth', 20, { scope = 'global' })
      eq('20', command_output('setglobal shiftwidth?'):match('%d+'))
      eq('8', command_output('setlocal shiftwidth?'):match('%d+'))
    end)

    it('updates where the option was last set from', function()
      api.nvim_set_option_value('equalalways', false, {})
      local status, rv = pcall(command_output, 'verbose set equalalways?')
      eq(true, status)
      matches('noequalalways\n' .. '\tLast set from API client %(channel id %d+%)', rv)

      api.nvim_exec_lua('vim.api.nvim_set_option_value("equalalways", true, {})', {})
      status, rv = pcall(command_output, 'verbose set equalalways?')
      eq(true, status)
      eq('  equalalways\n\tLast set from Lua (run Nvim with -V1 for more details)', rv)
    end)

    it('updates whether the option has ever been set #25025', function()
      eq(false, api.nvim_get_option_info2('autochdir', {}).was_set)
      api.nvim_set_option_value('autochdir', true, {})
      eq(true, api.nvim_get_option_info2('autochdir', {}).was_set)

      eq(false, api.nvim_get_option_info2('cmdwinheight', {}).was_set)
      api.nvim_set_option_value('cmdwinheight', 10, {})
      eq(true, api.nvim_get_option_info2('cmdwinheight', {}).was_set)

      eq(false, api.nvim_get_option_info2('debug', {}).was_set)
      api.nvim_set_option_value('debug', 'beep', {})
      eq(true, api.nvim_get_option_info2('debug', {}).was_set)
    end)

    it('validation', function()
      eq(
        "Invalid 'scope': expected 'local' or 'global'",
        pcall_err(api.nvim_get_option_value, 'scrolloff', { scope = 'bogus' })
      )
      eq(
        "Invalid 'scope': expected 'local' or 'global'",
        pcall_err(api.nvim_set_option_value, 'scrolloff', 1, { scope = 'bogus' })
      )
      eq(
        "Invalid 'scope': expected String, got Integer",
        pcall_err(api.nvim_get_option_value, 'scrolloff', { scope = 42 })
      )
      eq(
        "Invalid 'value': expected valid option type, got Array",
        pcall_err(api.nvim_set_option_value, 'scrolloff', {}, {})
      )
      eq(
        "Invalid value for option 'scrolloff': expected number, got boolean true",
        pcall_err(api.nvim_set_option_value, 'scrolloff', true, {})
      )
      eq(
        'Invalid value for option \'scrolloff\': expected number, got string "wrong"',
        pcall_err(api.nvim_set_option_value, 'scrolloff', 'wrong', {})
      )
    end)

    it('can get local values when global value is set', function()
      eq(0, api.nvim_get_option_value('scrolloff', {}))
      eq(-1, api.nvim_get_option_value('scrolloff', { scope = 'local' }))
    end)

    it('can set global and local values', function()
      api.nvim_set_option_value('makeprg', 'hello', {})
      eq('hello', api.nvim_get_option_value('makeprg', {}))
      eq('', api.nvim_get_option_value('makeprg', { scope = 'local' }))
      api.nvim_set_option_value('makeprg', 'world', { scope = 'local' })
      eq('world', api.nvim_get_option_value('makeprg', { scope = 'local' }))
      api.nvim_set_option_value('makeprg', 'goodbye', { scope = 'global' })
      eq('goodbye', api.nvim_get_option_value('makeprg', { scope = 'global' }))
      api.nvim_set_option_value('makeprg', 'hello', {})
      eq('hello', api.nvim_get_option_value('makeprg', { scope = 'global' }))
      eq('hello', api.nvim_get_option_value('makeprg', {}))
      eq('', api.nvim_get_option_value('makeprg', { scope = 'local' }))
    end)

    it('clears the local value of an option with nil', function()
      -- Set global value
      api.nvim_set_option_value('shiftwidth', 42, {})
      eq(42, api.nvim_get_option_value('shiftwidth', {}))

      -- Set local value
      api.nvim_set_option_value('shiftwidth', 8, { scope = 'local' })
      eq(8, api.nvim_get_option_value('shiftwidth', {}))
      eq(8, api.nvim_get_option_value('shiftwidth', { scope = 'local' }))
      eq(42, api.nvim_get_option_value('shiftwidth', { scope = 'global' }))

      -- Clear value without scope
      api.nvim_set_option_value('shiftwidth', NIL, {})
      eq(42, api.nvim_get_option_value('shiftwidth', {}))
      eq(42, api.nvim_get_option_value('shiftwidth', { scope = 'local' }))

      -- Clear value with explicit scope
      api.nvim_set_option_value('shiftwidth', 8, { scope = 'local' })
      api.nvim_set_option_value('shiftwidth', NIL, { scope = 'local' })
      eq(42, api.nvim_get_option_value('shiftwidth', {}))
      eq(42, api.nvim_get_option_value('shiftwidth', { scope = 'local' }))

      -- Now try with options with a special "local is unset" value (e.g. 'undolevels')
      api.nvim_set_option_value('undolevels', 1000, {})
      api.nvim_set_option_value('undolevels', 1200, { scope = 'local' })
      eq(1200, api.nvim_get_option_value('undolevels', { scope = 'local' }))
      api.nvim_set_option_value('undolevels', NIL, { scope = 'local' })
      eq(-123456, api.nvim_get_option_value('undolevels', { scope = 'local' }))
      eq(1000, api.nvim_get_option_value('undolevels', {}))

      api.nvim_set_option_value('autoread', true, {})
      api.nvim_set_option_value('autoread', false, { scope = 'local' })
      eq(false, api.nvim_get_option_value('autoread', { scope = 'local' }))
      api.nvim_set_option_value('autoread', NIL, { scope = 'local' })
      eq(NIL, api.nvim_get_option_value('autoread', { scope = 'local' }))
      eq(true, api.nvim_get_option_value('autoread', {}))
    end)

    it('set window options', function()
      api.nvim_set_option_value('colorcolumn', '4,3', {})
      eq('4,3', api.nvim_get_option_value('colorcolumn', { scope = 'local' }))
      command('set modified hidden')
      command('enew') -- edit new buffer, window option is preserved
      eq('4,3', api.nvim_get_option_value('colorcolumn', { scope = 'local' }))
    end)

    it('set local window options', function()
      api.nvim_set_option_value('colorcolumn', '4,3', { win = 0, scope = 'local' })
      eq('4,3', api.nvim_get_option_value('colorcolumn', { win = 0, scope = 'local' }))
      command('set modified hidden')
      command('enew') -- edit new buffer, window option is reset
      eq('', api.nvim_get_option_value('colorcolumn', { win = 0, scope = 'local' }))
    end)

    it('get buffer or window-local options', function()
      command('new')
      local buf = api.nvim_get_current_buf()
      api.nvim_set_option_value('tagfunc', 'foobar', { buf = buf })
      eq('foobar', api.nvim_get_option_value('tagfunc', { buf = buf }))

      local win = api.nvim_get_current_win()
      api.nvim_set_option_value('number', true, { win = win })
      eq(true, api.nvim_get_option_value('number', { win = win }))
    end)

    it('getting current buffer option does not adjust cursor #19381', function()
      command('new')
      local buf = api.nvim_get_current_buf()
      print(vim.inspect(api.nvim_get_current_buf()))
      local win = api.nvim_get_current_win()
      insert('some text')
      feed('0v$')
      eq({ 1, 9 }, api.nvim_win_get_cursor(win))
      api.nvim_get_option_value('filetype', { buf = buf })
      eq({ 1, 9 }, api.nvim_win_get_cursor(win))
    end)

    it('can get default option values for filetypes', function()
      command('filetype plugin on')
      for ft, opts in pairs {
        lua = { commentstring = '-- %s' },
        vim = { commentstring = '"%s' },
        man = { tagfunc = "v:lua.require'man'.goto_tag" },
        xml = { formatexpr = 'xmlformat#Format()' },
      } do
        for option, value in pairs(opts) do
          eq(value, api.nvim_get_option_value(option, { filetype = ft }))
        end
      end

      command 'au FileType lua setlocal commentstring=NEW\\ %s'

      eq('NEW %s', api.nvim_get_option_value('commentstring', { filetype = 'lua' }))
    end)

    it('errors for bad FileType autocmds', function()
      command 'au FileType lua setlocal commentstring=BAD'
      eq(
        [[FileType Autocommands for "lua": Vim(setlocal):E537: 'commentstring' must be empty or contain %s: commentstring=BAD]],
        pcall_err(api.nvim_get_option_value, 'commentstring', { filetype = 'lua' })
      )
    end)

    it("value of 'modified' is always false for scratch buffers", function()
      api.nvim_set_current_buf(api.nvim_create_buf(true, true))
      insert([[
        foo
        bar
        baz
      ]])
      eq(false, api.nvim_get_option_value('modified', {}))
    end)
  end)

  describe('nvim_{get,set}_current_buf, nvim_list_bufs', function()
    it('works', function()
      eq(1, #api.nvim_list_bufs())
      eq(api.nvim_list_bufs()[1], api.nvim_get_current_buf())
      command('new')
      eq(2, #api.nvim_list_bufs())
      eq(api.nvim_list_bufs()[2], api.nvim_get_current_buf())
      api.nvim_set_current_buf(api.nvim_list_bufs()[1])
      eq(api.nvim_list_bufs()[1], api.nvim_get_current_buf())
    end)
  end)

  describe('nvim_{get,set}_current_win, nvim_list_wins', function()
    it('works', function()
      eq(1, #api.nvim_list_wins())
      eq(api.nvim_list_wins()[1], api.nvim_get_current_win())
      command('vsplit')
      command('split')
      eq(3, #api.nvim_list_wins())
      eq(api.nvim_list_wins()[1], api.nvim_get_current_win())
      api.nvim_set_current_win(api.nvim_list_wins()[2])
      eq(api.nvim_list_wins()[2], api.nvim_get_current_win())
    end)
  end)

  describe('nvim_{get,set}_current_tabpage, nvim_list_tabpages', function()
    it('works', function()
      eq(1, #api.nvim_list_tabpages())
      eq(api.nvim_list_tabpages()[1], api.nvim_get_current_tabpage())
      command('tabnew')
      eq(2, #api.nvim_list_tabpages())
      eq(2, #api.nvim_list_wins())
      eq(api.nvim_list_wins()[2], api.nvim_get_current_win())
      eq(api.nvim_list_tabpages()[2], api.nvim_get_current_tabpage())
      api.nvim_set_current_win(api.nvim_list_wins()[1])
      -- Switching window also switches tabpages if necessary
      eq(api.nvim_list_tabpages()[1], api.nvim_get_current_tabpage())
      eq(api.nvim_list_wins()[1], api.nvim_get_current_win())
      api.nvim_set_current_tabpage(api.nvim_list_tabpages()[2])
      eq(api.nvim_list_tabpages()[2], api.nvim_get_current_tabpage())
      eq(api.nvim_list_wins()[2], api.nvim_get_current_win())
    end)
  end)

  describe('nvim_get_mode', function()
    it('during normal-mode `g` returns blocking=true', function()
      api.nvim_input('o') -- add a line
      eq({ mode = 'i', blocking = false }, api.nvim_get_mode())
      api.nvim_input([[<C-\><C-N>]])
      eq(2, api.nvim_eval("line('.')"))
      eq({ mode = 'n', blocking = false }, api.nvim_get_mode())

      api.nvim_input('g')
      eq({ mode = 'n', blocking = true }, api.nvim_get_mode())

      api.nvim_input('k') -- complete the operator
      eq(1, api.nvim_eval("line('.')")) -- verify the completed operator
      eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
    end)

    it('returns the correct result multiple consecutive times', function()
      for _ = 1, 5 do
        eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
      end
      api.nvim_input('g')
      for _ = 1, 4 do
        eq({ mode = 'n', blocking = true }, api.nvim_get_mode())
      end
      api.nvim_input('g')
      for _ = 1, 7 do
        eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
      end
    end)

    it('during normal-mode CTRL-W, returns blocking=true', function()
      api.nvim_input('<C-W>')
      eq({ mode = 'n', blocking = true }, api.nvim_get_mode())

      api.nvim_input('s') -- complete the operator
      eq(2, api.nvim_eval("winnr('$')")) -- verify the completed operator
      eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
    end)

    it('during press-enter prompt without UI returns blocking=false', function()
      eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
      command("echom 'msg1'")
      command("echom 'msg2'")
      command("echom 'msg3'")
      command("echom 'msg4'")
      command("echom 'msg5'")
      eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
      api.nvim_input(':messages<CR>')
      eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
    end)

    it('during press-enter prompt returns blocking=true', function()
      api.nvim_ui_attach(80, 20, {})
      eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
      command("echom 'msg1'")
      command("echom 'msg2'")
      command("echom 'msg3'")
      command("echom 'msg4'")
      command("echom 'msg5'")
      eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
      api.nvim_input(':messages<CR>')
      eq({ mode = 'r', blocking = true }, api.nvim_get_mode())
    end)

    it('during getchar() returns blocking=false', function()
      api.nvim_input(':let g:test_input = nr2char(getchar())<CR>')
      -- Events are enabled during getchar(), RPC calls are *not* blocked. #5384
      eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
      eq(0, api.nvim_eval("exists('g:test_input')"))
      api.nvim_input('J')
      eq('J', api.nvim_eval('g:test_input'))
      eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
    end)

    -- TODO: bug #6247#issuecomment-286403810
    it('batched with input', function()
      api.nvim_ui_attach(80, 20, {})
      eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
      command("echom 'msg1'")
      command("echom 'msg2'")
      command("echom 'msg3'")
      command("echom 'msg4'")
      command("echom 'msg5'")

      local req = {
        { 'nvim_get_mode', {} },
        { 'nvim_input', { ':messages<CR>' } },
        { 'nvim_get_mode', {} },
        { 'nvim_eval', { '1' } },
      }
      eq({
        {
          { mode = 'n', blocking = false },
          13,
          { mode = 'n', blocking = false }, -- TODO: should be blocked=true ?
          1,
        },
        NIL,
      }, api.nvim_call_atomic(req))
      eq({ mode = 'r', blocking = true }, api.nvim_get_mode())
    end)
    it('during insert-mode map-pending, returns blocking=true #6166', function()
      command('inoremap xx foo')
      api.nvim_input('ix')
      eq({ mode = 'i', blocking = true }, api.nvim_get_mode())
    end)
    it('during normal-mode gU, returns blocking=false #6166', function()
      api.nvim_input('gu')
      eq({ mode = 'no', blocking = false }, api.nvim_get_mode())
    end)

    it("at '-- More --' prompt returns blocking=true #11899", function()
      command('set more')
      feed(':digraphs<cr>')
      eq({ mode = 'rm', blocking = true }, api.nvim_get_mode())
    end)

    it('after <Nop> mapping returns blocking=false #17257', function()
      command('nnoremap <F2> <Nop>')
      feed('<F2>')
      eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
    end)

    it('after empty string <expr> mapping returns blocking=false #17257', function()
      command('nnoremap <expr> <F2> ""')
      feed('<F2>')
      eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
    end)
  end)

  describe('RPC (K_EVENT)', function()
    it('does not complete ("interrupt") normal-mode operator-pending #6166', function()
      n.insert([[
        FIRST LINE
        SECOND LINE]])
      api.nvim_input('gg')
      api.nvim_input('gu')
      -- Make any RPC request (can be non-async: op-pending does not block).
      api.nvim_get_current_buf()
      -- Buffer should not change.
      expect([[
        FIRST LINE
        SECOND LINE]])
      -- Now send input to complete the operator.
      api.nvim_input('j')
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
      api.nvim_get_current_buf()
      screen:expect([[
       ^a{1:$}                  |
       b{1:$}                  |
       c{1:$}                  |
                           |
      ]])
    end)

    it('does not complete ("interrupt") normal-mode map-pending #6166', function()
      command("nnoremap dd :let g:foo='it worked...'<CR>")
      n.insert([[
        FIRST LINE
        SECOND LINE]])
      api.nvim_input('gg')
      api.nvim_input('d')
      -- Make any RPC request (must be async, because map-pending blocks).
      api.nvim_get_api_info()
      -- Send input to complete the mapping.
      api.nvim_input('d')
      expect([[
        FIRST LINE
        SECOND LINE]])
      eq('it worked...', n.eval('g:foo'))
    end)

    it('does not complete ("interrupt") insert-mode map-pending #6166', function()
      command('inoremap xx foo')
      command('set timeoutlen=9999')
      n.insert([[
        FIRST LINE
        SECOND LINE]])
      api.nvim_input('ix')
      -- Make any RPC request (must be async, because map-pending blocks).
      api.nvim_get_api_info()
      -- Send input to complete the mapping.
      api.nvim_input('x')
      expect([[
        FIRST LINE
        SECOND LINfooE]])
    end)

    it('does not interrupt Insert mode i_CTRL-O #10035', function()
      feed('iHello World<c-o>')
      eq({ mode = 'niI', blocking = false }, api.nvim_get_mode()) -- fast event
      eq(2, eval('1+1')) -- causes K_EVENT key
      eq({ mode = 'niI', blocking = false }, api.nvim_get_mode()) -- still in ctrl-o mode
      feed('dd')
      eq({ mode = 'i', blocking = false }, api.nvim_get_mode()) -- left ctrl-o mode
      expect('') -- executed the command
    end)

    it('does not interrupt Select mode v_CTRL-O #15688', function()
      feed('iHello World<esc>gh<c-o>')
      eq({ mode = 'vs', blocking = false }, api.nvim_get_mode()) -- fast event
      eq({ mode = 'vs', blocking = false }, api.nvim_get_mode()) -- again #15288
      eq(2, eval('1+1')) -- causes K_EVENT key
      eq({ mode = 'vs', blocking = false }, api.nvim_get_mode()) -- still in ctrl-o mode
      feed('^')
      eq({ mode = 's', blocking = false }, api.nvim_get_mode()) -- left ctrl-o mode
      feed('h')
      eq({ mode = 'i', blocking = false }, api.nvim_get_mode()) -- entered insert mode
      expect('h') -- selection is the whole line and is replaced
    end)

    it('does not interrupt Insert mode i_0_CTRL-D #13997', function()
      command('set timeoutlen=9999')
      feed('i<Tab><Tab>a0')
      eq(2, eval('1+1')) -- causes K_EVENT key
      feed('<C-D>')
      expect('a') -- recognized i_0_CTRL-D
    end)

    it("does not interrupt with 'digraph'", function()
      command('set digraph')
      feed('i,')
      eq(2, eval('1+1')) -- causes K_EVENT key
      feed('<BS>')
      eq(2, eval('1+1')) -- causes K_EVENT key
      feed('.')
      expect('…') -- digraph ",." worked
      feed('<Esc>')
      feed(':,')
      eq(2, eval('1+1')) -- causes K_EVENT key
      feed('<BS>')
      eq(2, eval('1+1')) -- causes K_EVENT key
      feed('.')
      eq('…', fn.getcmdline()) -- digraph ",." worked
    end)
  end)

  describe('nvim_get_context', function()
    it('validation', function()
      eq("Invalid key: 'blah'", pcall_err(api.nvim_get_context, { blah = {} }))
      eq(
        "Invalid 'types': expected Array, got Integer",
        pcall_err(api.nvim_get_context, { types = 42 })
      )
      eq(
        "Invalid 'type': 'zub'",
        pcall_err(api.nvim_get_context, { types = { 'jumps', 'zub', 'zam' } })
      )
    end)
    it('returns map of current editor state', function()
      local opts = { types = { 'regs', 'jumps', 'bufs', 'gvars' } }
      eq({}, parse_context(api.nvim_get_context({})))

      feed('i1<cr>2<cr>3<c-[>ddddddqahjklquuu')
      feed('gg')
      feed('G')
      command('edit! BUF1')
      command('edit BUF2')
      api.nvim_set_var('one', 1)
      api.nvim_set_var('Two', 2)
      api.nvim_set_var('THREE', 3)

      local expected_ctx = {
        ['regs'] = {
          { ['rt'] = 1, ['rc'] = { '1' }, ['n'] = 49, ['ru'] = true },
          { ['rt'] = 1, ['rc'] = { '2' }, ['n'] = 50 },
          { ['rt'] = 1, ['rc'] = { '3' }, ['n'] = 51 },
          { ['rc'] = { 'hjkl' }, ['n'] = 97 },
        },

        ['jumps'] = eval((([[
        filter(map(add(
        getjumplist()[0], { 'bufnr': bufnr('%'), 'lnum': getcurpos()[1] }),
        'filter(
        { "f": expand("#".v:val.bufnr.":p"), "l": v:val.lnum },
        { k, v -> k != "l" || v != 1 })'), '!empty(v:val.f)')
        ]]):gsub('\n', ''))),

        ['bufs'] = eval([[
        filter(map(getbufinfo(), '{ "f": v:val.name }'), '!empty(v:val.f)')
        ]]),

        ['gvars'] = { { 'one', 1 }, { 'Two', 2 }, { 'THREE', 3 } },
      }

      eq(expected_ctx, parse_context(api.nvim_get_context(opts)))
      eq(expected_ctx, parse_context(api.nvim_get_context({})))
      eq(expected_ctx, parse_context(api.nvim_get_context({ types = {} })))
    end)
  end)

  describe('nvim_load_context', function()
    it('sets current editor state to given context dictionary', function()
      local opts = { types = { 'regs', 'jumps', 'bufs', 'gvars' } }
      eq({}, parse_context(api.nvim_get_context(opts)))

      api.nvim_set_var('one', 1)
      api.nvim_set_var('Two', 2)
      api.nvim_set_var('THREE', 3)
      local ctx = api.nvim_get_context(opts)
      api.nvim_set_var('one', 'a')
      api.nvim_set_var('Two', 'b')
      api.nvim_set_var('THREE', 'c')
      eq({ 'a', 'b', 'c' }, eval('[g:one, g:Two, g:THREE]'))
      api.nvim_load_context(ctx)
      eq({ 1, 2, 3 }, eval('[g:one, g:Two, g:THREE]'))
    end)

    it('errors when context dictionary is invalid', function()
      eq(
        'E474: Failed to convert list to msgpack string buffer',
        pcall_err(api.nvim_load_context, { regs = { {} }, jumps = { {} } })
      )
      eq(
        'E474: Failed to convert list to msgpack string buffer',
        pcall_err(api.nvim_load_context, { regs = { { [''] = '' } } })
      )
    end)
  end)

  describe('nvim_replace_termcodes', function()
    it('escapes K_SPECIAL as K_SPECIAL KS_SPECIAL KE_FILLER', function()
      eq('\128\254X', n.api.nvim_replace_termcodes('\128', true, true, true))
    end)

    it('leaves non-K_SPECIAL string unchanged', function()
      eq('abc', n.api.nvim_replace_termcodes('abc', true, true, true))
    end)

    it('converts <expressions>', function()
      eq('\\', n.api.nvim_replace_termcodes('<Leader>', true, true, true))
    end)

    it('converts <LeftMouse> to K_SPECIAL KS_EXTRA KE_LEFTMOUSE', function()
      -- K_SPECIAL KS_EXTRA KE_LEFTMOUSE
      -- 0x80      0xfd     0x2c
      -- 128       253      44
      eq('\128\253\44', n.api.nvim_replace_termcodes('<LeftMouse>', true, true, true))
    end)

    it('converts keycodes', function()
      eq('\nx\27x\rx<x', n.api.nvim_replace_termcodes('<NL>x<Esc>x<CR>x<lt>x', true, true, true))
    end)

    it('does not convert keycodes if special=false', function()
      eq(
        '<NL>x<Esc>x<CR>x<lt>x',
        n.api.nvim_replace_termcodes('<NL>x<Esc>x<CR>x<lt>x', true, true, false)
      )
    end)

    it('does not crash when transforming an empty string', function()
      -- Actually does not test anything, because current code will use NULL for
      -- an empty string.
      --
      -- Problem here is that if String argument has .data in allocated memory
      -- then `return str` in vim_replace_termcodes body will make Neovim free
      -- `str.data` twice: once when freeing arguments, then when freeing return
      -- value.
      eq('', api.nvim_replace_termcodes('', true, true, true))
    end)

    -- Not exactly the case, as nvim_replace_termcodes() escapes K_SPECIAL in Unicode
    it('translates the result of keytrans() on string with 0x80 byte back', function()
      local s = 'ff\128\253\097tt'
      eq(s, api.nvim_replace_termcodes(fn.keytrans(s), true, true, true))
    end)
  end)

  describe('nvim_feedkeys', function()
    it('K_SPECIAL escaping', function()
      local function on_setup()
        -- notice the special char(…) \xe2\80\xa6
        api.nvim_feedkeys(':let x1="…"\n', '', true)

        -- Both nvim_replace_termcodes and nvim_feedkeys escape \x80
        local inp = n.api.nvim_replace_termcodes(':let x2="…"<CR>', true, true, true)
        api.nvim_feedkeys(inp, '', true) -- escape_ks=true

        -- nvim_feedkeys with K_SPECIAL escaping disabled
        inp = n.api.nvim_replace_termcodes(':let x3="…"<CR>', true, true, true)
        api.nvim_feedkeys(inp, '', false) -- escape_ks=false

        n.stop()
      end

      -- spin the loop a bit
      n.run(nil, nil, on_setup)

      eq('…', api.nvim_get_var('x1'))
      -- Because of the double escaping this is neq
      neq('…', api.nvim_get_var('x2'))
      eq('…', api.nvim_get_var('x3'))
    end)
  end)

  describe('nvim_out_write', function()
    local screen

    before_each(function()
      screen = Screen.new(40, 8)
      screen:attach()
    end)

    it('prints long messages correctly #20534', function()
      exec([[
        set more
        redir => g:out
          silent! call nvim_out_write('a')
          silent! call nvim_out_write('a')
          silent! call nvim_out_write('a')
          silent! call nvim_out_write("\n")
          silent! call nvim_out_write('a')
          silent! call nvim_out_write('a')
          silent! call nvim_out_write(repeat('a', 5000) .. "\n")
          silent! call nvim_out_write('a')
          silent! call nvim_out_write('a')
          silent! call nvim_out_write('a')
          silent! call nvim_out_write("\n")
        redir END
      ]])
      eq('\naaa\n' .. ('a'):rep(5002) .. '\naaa', api.nvim_get_var('out'))
    end)

    it('blank line in message', function()
      feed([[:call nvim_out_write("\na\n")<CR>]])
      screen:expect {
        grid = [[
                                                |
        {1:~                                       }|*3
        {3:                                        }|
                                                |
        a                                       |
        {6:Press ENTER or type command to continue}^ |
      ]],
      }
      feed('<CR>')
      feed([[:call nvim_out_write("b\n\nc\n")<CR>]])
      screen:expect {
        grid = [[
                                                |
        {1:~                                       }|*2
        {3:                                        }|
        b                                       |
                                                |
        c                                       |
        {6:Press ENTER or type command to continue}^ |
      ]],
      }
    end)

    it('NUL bytes in message', function()
      feed([[:lua vim.api.nvim_out_write('aaa\0bbb\0\0ccc\nddd\0\0\0eee\n')<CR>]])
      screen:expect {
        grid = [[
                                                |
        {1:~                                       }|*3
        {3:                                        }|
        aaa{18:^@}bbb{18:^@^@}ccc                         |
        ddd{18:^@^@^@}eee                            |
        {6:Press ENTER or type command to continue}^ |
      ]],
      }
    end)
  end)

  describe('nvim_err_write', function()
    local screen

    before_each(function()
      screen = Screen.new(40, 8)
      screen:attach()
    end)

    it('can show one line', function()
      async_meths.nvim_err_write('has bork\n')
      screen:expect([[
        ^                                        |
        {1:~                                       }|*6
        {9:has bork}                                |
      ]])
    end)

    it('shows return prompt when more than &cmdheight lines', function()
      async_meths.nvim_err_write('something happened\nvery bad\n')
      screen:expect([[
                                                |
        {1:~                                       }|*3
        {3:                                        }|
        {9:something happened}                      |
        {9:very bad}                                |
        {6:Press ENTER or type command to continue}^ |
      ]])
    end)

    it('shows return prompt after all lines are shown', function()
      async_meths.nvim_err_write('FAILURE\nERROR\nEXCEPTION\nTRACEBACK\n')
      screen:expect([[
                                                |
        {1:~                                       }|
        {3:                                        }|
        {9:FAILURE}                                 |
        {9:ERROR}                                   |
        {9:EXCEPTION}                               |
        {9:TRACEBACK}                               |
        {6:Press ENTER or type command to continue}^ |
      ]])
    end)

    it('handles multiple calls', function()
      -- without linebreak text is joined to one line
      async_meths.nvim_err_write('very ')
      async_meths.nvim_err_write('fail\n')
      screen:expect([[
        ^                                        |
        {1:~                                       }|*6
        {9:very fail}                               |
      ]])
      n.poke_eventloop()

      -- shows up to &cmdheight lines
      async_meths.nvim_err_write('more fail\ntoo fail\n')
      screen:expect([[
                                                |
        {1:~                                       }|*3
        {3:                                        }|
        {9:more fail}                               |
        {9:too fail}                                |
        {6:Press ENTER or type command to continue}^ |
      ]])
      feed('<cr>') -- exit the press ENTER screen
    end)

    it('NUL bytes in message', function()
      async_meths.nvim_err_write('aaa\0bbb\0\0ccc\nddd\0\0\0eee\n')
      screen:expect {
        grid = [[
                                                |
        {1:~                                       }|*3
        {3:                                        }|
        {9:aaa^@bbb^@^@ccc}                         |
        {9:ddd^@^@^@eee}                            |
        {6:Press ENTER or type command to continue}^ |
      ]],
      }
    end)
  end)

  describe('nvim_err_writeln', function()
    local screen

    before_each(function()
      screen = Screen.new(40, 8)
      screen:attach()
    end)

    it('shows only one return prompt after all lines are shown', function()
      async_meths.nvim_err_writeln('FAILURE\nERROR\nEXCEPTION\nTRACEBACK')
      screen:expect([[
                                                |
        {1:~                                       }|
        {3:                                        }|
        {9:FAILURE}                                 |
        {9:ERROR}                                   |
        {9:EXCEPTION}                               |
        {9:TRACEBACK}                               |
        {6:Press ENTER or type command to continue}^ |
      ]])
      feed('<CR>')
      screen:expect([[
        ^                                        |
        {1:~                                       }|*6
                                                |
      ]])
    end)
  end)

  describe('nvim_list_chans, nvim_get_chan_info', function()
    before_each(function()
      command('autocmd ChanOpen * let g:opened_event = deepcopy(v:event)')
      command('autocmd ChanInfo * let g:info_event = deepcopy(v:event)')
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
      eq({}, api.nvim_get_chan_info(-1))
      -- more preallocated numbers might be added, try something high
      eq({}, api.nvim_get_chan_info(10))
    end)

    it('stream=stdio channel', function()
      eq({ [1] = testinfo, [2] = stderr }, api.nvim_list_chans())
      -- 0 should return current channel
      eq(testinfo, api.nvim_get_chan_info(0))
      eq(testinfo, api.nvim_get_chan_info(1))
      eq(stderr, api.nvim_get_chan_info(2))

      api.nvim_set_client_info(
        'functionaltests',
        { major = 0, minor = 3, patch = 17 },
        'ui',
        { do_stuff = { n_args = { 2, 3 } } },
        { license = 'Apache2' }
      )
      local info = {
        stream = 'stdio',
        id = 1,
        mode = 'rpc',
        client = {
          name = 'functionaltests',
          version = { major = 0, minor = 3, patch = 17 },
          type = 'ui',
          methods = { do_stuff = { n_args = { 2, 3 } } },
          attributes = { license = 'Apache2' },
        },
      }
      eq({ info = info }, api.nvim_get_var('info_event'))
      eq({ [1] = info, [2] = stderr }, api.nvim_list_chans())
      eq(info, api.nvim_get_chan_info(1))
    end)

    it('stream=job channel', function()
      eq(3, eval("jobstart(['cat'], {'rpc': v:true})"))
      local catpath = eval('exepath("cat")')
      local info = {
        stream = 'job',
        id = 3,
        argv = { catpath },
        mode = 'rpc',
        client = {},
      }
      eq({ info = info }, api.nvim_get_var('opened_event'))
      eq({ [1] = testinfo, [2] = stderr, [3] = info }, api.nvim_list_chans())
      eq(info, api.nvim_get_chan_info(3))
      eval(
        'rpcrequest(3, "nvim_set_client_info", "amazing-cat", {}, "remote",'
          .. '{"nvim_command":{"n_args":1}},' -- and so on
          .. '{"description":"The Amazing Cat"})'
      )
      info = {
        stream = 'job',
        id = 3,
        argv = { catpath },
        mode = 'rpc',
        client = {
          name = 'amazing-cat',
          version = { major = 0 },
          type = 'remote',
          methods = { nvim_command = { n_args = 1 } },
          attributes = { description = 'The Amazing Cat' },
        },
      }
      eq({ info = info }, api.nvim_get_var('info_event'))
      eq({ [1] = testinfo, [2] = stderr, [3] = info }, api.nvim_list_chans())

      eq(
        "Vim:Error invoking 'nvim_set_current_buf' on channel 3 (amazing-cat):\nWrong type for argument 1 when calling nvim_set_current_buf, expecting Buffer",
        pcall_err(eval, 'rpcrequest(3, "nvim_set_current_buf", -1)')
      )
      eq(info, eval('rpcrequest(3, "nvim_get_chan_info", 0)'))
    end)

    it('stream=job :terminal channel', function()
      command(':terminal')
      eq(1, api.nvim_get_current_buf())
      eq(3, api.nvim_get_option_value('channel', { buf = 1 }))

      local info = {
        stream = 'job',
        id = 3,
        argv = { eval('exepath(&shell)') },
        mode = 'terminal',
        buffer = 1,
        pty = '?',
      }
      local event = api.nvim_get_var('opened_event')
      if not is_os('win') then
        info.pty = event.info.pty
        neq(nil, string.match(info.pty, '^/dev/'))
      end
      eq({ info = info }, event)
      info.buffer = 1
      eq({ [1] = testinfo, [2] = stderr, [3] = info }, api.nvim_list_chans())
      eq(info, api.nvim_get_chan_info(3))

      -- :terminal with args + running process.
      command('enew')
      local progpath_esc = eval('shellescape(v:progpath)')
      fn.termopen(('%s -u NONE -i NONE'):format(progpath_esc), {
        env = { VIMRUNTIME = os.getenv('VIMRUNTIME') },
      })
      eq(-1, eval('jobwait([&channel], 0)[0]')) -- Running?
      local expected2 = {
        stream = 'job',
        id = 4,
        argv = (is_os('win') and {
          eval('&shell'),
          '/s',
          '/c',
          fmt('"%s -u NONE -i NONE"', progpath_esc),
        } or {
          eval('&shell'),
          eval('&shellcmdflag'),
          fmt('%s -u NONE -i NONE', progpath_esc),
        }),
        mode = 'terminal',
        buffer = 2,
        pty = '?',
      }
      local actual2 = eval('nvim_get_chan_info(&channel)')
      expected2.pty = actual2.pty
      eq(expected2, actual2)

      -- :terminal with args + stopped process.
      eq(1, eval('jobstop(&channel)'))
      eval('jobwait([&channel], 1000)') -- Wait.
      expected2.pty = (is_os('win') and '?' or '') -- pty stream was closed.
      eq(expected2, eval('nvim_get_chan_info(&channel)'))
    end)
  end)

  describe('nvim_call_atomic', function()
    it('works', function()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'first' })
      local req = {
        { 'nvim_get_current_line', {} },
        { 'nvim_set_current_line', { 'second' } },
      }
      eq({ { 'first', NIL }, NIL }, api.nvim_call_atomic(req))
      eq({ 'second' }, api.nvim_buf_get_lines(0, 0, -1, true))
    end)

    it('allows multiple return values', function()
      local req = {
        { 'nvim_set_var', { 'avar', true } },
        { 'nvim_set_var', { 'bvar', 'string' } },
        { 'nvim_get_var', { 'avar' } },
        { 'nvim_get_var', { 'bvar' } },
      }
      eq({ { NIL, NIL, true, 'string' }, NIL }, api.nvim_call_atomic(req))
    end)

    it('is aborted by errors in call', function()
      local error_types = api.nvim_get_api_info()[2].error_types
      local req = {
        { 'nvim_set_var', { 'one', 1 } },
        { 'nvim_buf_set_lines', {} },
        { 'nvim_set_var', { 'two', 2 } },
      }
      eq({
        { NIL },
        {
          1,
          error_types.Exception.id,
          'Wrong number of arguments: expecting 5 but got 0',
        },
      }, api.nvim_call_atomic(req))
      eq(1, api.nvim_get_var('one'))
      eq(false, pcall(api.nvim_get_var, 'two'))

      -- still returns all previous successful calls
      req = {
        { 'nvim_set_var', { 'avar', 5 } },
        { 'nvim_set_var', { 'bvar', 'string' } },
        { 'nvim_get_var', { 'avar' } },
        { 'nvim_buf_get_lines', { 0, 10, 20, true } },
        { 'nvim_get_var', { 'bvar' } },
      }
      eq(
        { { NIL, NIL, 5 }, { 3, error_types.Validation.id, 'Index out of bounds' } },
        api.nvim_call_atomic(req)
      )

      req = {
        { 'i_am_not_a_method', { 'xx' } },
        { 'nvim_set_var', { 'avar', 10 } },
      }
      eq(
        { {}, { 0, error_types.Exception.id, 'Invalid method: i_am_not_a_method' } },
        api.nvim_call_atomic(req)
      )
      eq(5, api.nvim_get_var('avar'))
    end)

    it('validation', function()
      local req = {
        { 'nvim_set_var', { 'avar', 1 } },
        { 'nvim_set_var' },
        { 'nvim_set_var', { 'avar', 2 } },
      }
      eq("Invalid 'calls' item: expected 2-item Array", pcall_err(api.nvim_call_atomic, req))
      -- call before was done, but not after
      eq(1, api.nvim_get_var('avar'))

      req = {
        { 'nvim_set_var', { 'bvar', { 2, 3 } } },
        12,
      }
      eq("Invalid 'calls' item: expected Array, got Integer", pcall_err(api.nvim_call_atomic, req))
      eq({ 2, 3 }, api.nvim_get_var('bvar'))

      req = {
        { 'nvim_set_current_line', 'little line' },
        { 'nvim_set_var', { 'avar', 3 } },
      }
      eq('Invalid call args: expected Array, got String', pcall_err(api.nvim_call_atomic, req))
      -- call before was done, but not after
      eq(1, api.nvim_get_var('avar'))
      eq({ '' }, api.nvim_buf_get_lines(0, 0, -1, true))
    end)
  end)

  describe('nvim_list_runtime_paths', function()
    setup(function()
      local pathsep = n.get_pathsep()
      mkdir_p('Xtest' .. pathsep .. 'a')
      mkdir_p('Xtest' .. pathsep .. 'b')
    end)
    teardown(function()
      rmdir 'Xtest'
    end)
    before_each(function()
      api.nvim_set_current_dir 'Xtest'
    end)

    it('returns nothing with empty &runtimepath', function()
      api.nvim_set_option_value('runtimepath', '', {})
      eq({}, api.nvim_list_runtime_paths())
    end)
    it('returns single runtimepath', function()
      api.nvim_set_option_value('runtimepath', 'a', {})
      eq({ 'a' }, api.nvim_list_runtime_paths())
    end)
    it('returns two runtimepaths', function()
      api.nvim_set_option_value('runtimepath', 'a,b', {})
      eq({ 'a', 'b' }, api.nvim_list_runtime_paths())
    end)
    it('returns empty strings when appropriate', function()
      api.nvim_set_option_value('runtimepath', 'a,,b', {})
      eq({ 'a', '', 'b' }, api.nvim_list_runtime_paths())
      api.nvim_set_option_value('runtimepath', ',a,b', {})
      eq({ '', 'a', 'b' }, api.nvim_list_runtime_paths())
      -- Trailing "," is ignored. Use ",," if you really really want CWD.
      api.nvim_set_option_value('runtimepath', 'a,b,', {})
      eq({ 'a', 'b' }, api.nvim_list_runtime_paths())
      api.nvim_set_option_value('runtimepath', 'a,b,,', {})
      eq({ 'a', 'b', '' }, api.nvim_list_runtime_paths())
    end)
    it('truncates too long paths', function()
      local long_path = ('/a'):rep(8192)
      api.nvim_set_option_value('runtimepath', long_path, {})
      local paths_list = api.nvim_list_runtime_paths()
      eq({}, paths_list)
    end)
  end)

  it('can throw exceptions', function()
    local status, err = pcall(api.nvim_get_option_value, 'invalid-option', {})
    eq(false, status)
    matches("Unknown option 'invalid%-option'", err)
  end)

  it('does not truncate error message <1 MB #5984', function()
    local very_long_name = 'A' .. ('x'):rep(10000) .. 'Z'
    local status, err = pcall(api.nvim_get_option_value, very_long_name, {})
    eq(false, status)
    eq(very_long_name, err:match('Ax+Z?'))
  end)

  it('does not leak memory on incorrect argument types', function()
    local status, err = pcall(api.nvim_set_current_dir, { 'not', 'a', 'dir' })
    eq(false, status)
    matches(': Wrong type for argument 1 when calling nvim_set_current_dir, expecting String', err)
  end)

  describe('nvim_parse_expression', function()
    before_each(function()
      api.nvim_set_option_value('isident', '', {})
    end)

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
        typ = typ .. ('(name=%s)'):format(tostring(intchar2lua(east_api_node.name)))
        east_api_node.name = nil
      elseif typ == 'PlainIdentifier' then
        typ = typ
          .. ('(scope=%s,ident=%s)'):format(
            tostring(intchar2lua(east_api_node.scope)),
            east_api_node.ident
          )
        east_api_node.scope = nil
        east_api_node.ident = nil
      elseif typ == 'PlainKey' then
        typ = typ .. ('(key=%s)'):format(east_api_node.ident)
        east_api_node.ident = nil
      elseif typ == 'Comparison' then
        typ = typ
          .. ('(type=%s,inv=%u,ccs=%s)'):format(
            east_api_node.cmp_type,
            east_api_node.invert and 1 or 0,
            east_api_node.ccs_strategy
          )
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
          east_api_node.ident
        )
        east_api_node.ident = nil
        east_api_node.scope = nil
      elseif typ == 'Environment' then
        typ = ('%s(ident=%s)'):format(typ, east_api_node.ident)
        east_api_node.ident = nil
      elseif typ == 'Assignment' then
        local aug = east_api_node.augmentation
        if aug == '' then
          aug = 'Plain'
        end
        typ = ('%s(%s)'):format(typ, aug)
        east_api_node.augmentation = nil
      end
      typ = ('%s:%u:%u:%s'):format(
        typ,
        east_api_node.start[1],
        east_api_node.start[2],
        line:sub(east_api_node.start[2] + 1, east_api_node.start[2] + 1 + east_api_node.len - 1)
      )
      assert(east_api_node.start[2] + east_api_node.len - 1 <= #line)
      for k, _ in pairs(east_api_node.start) do
        assert(({ true, true })[k])
      end
      east_api_node.start = nil
      east_api_node.type = nil
      east_api_node.len = nil
      local can_simplify = true
      for _, _ in pairs(east_api_node) do
        if can_simplify then
          can_simplify = false
        end
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
        east_api.ast = { simplify_east_api_node(line, east_api.ast) }
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
        east_hl[i] = ('%s:%u:%u:%s'):format(v[4], v[1], v[2], line:sub(v[2] + 1, v[3]))
      end
      return east_hl
    end
    local FLAGS_TO_STR = {
      [0] = '',
      [1] = 'm',
      [2] = 'E',
      [3] = 'mE',
      [4] = 'l',
      [5] = 'lm',
      [6] = 'lE',
      [7] = 'lmE',
    }
    local function _check_parsing(opts, str, exp_ast, exp_highlighting_fs, nz_flags_exps)
      if type(str) ~= 'string' then
        return
      end
      local zflags = opts.flags[1]
      nz_flags_exps = nz_flags_exps or {}
      for _, flags in ipairs(opts.flags) do
        local err, msg = pcall(function()
          local east_api = api.nvim_parse_expression(str, FLAGS_TO_STR[flags], true)
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
            local merr, new_msg = pcall(format_string, 'table error:\n%s\n\n(%r)', msg.message, msg)
            if merr then
              msg = new_msg
            else
              msg = format_string('table error without .message:\n(%r)', msg)
            end
          elseif type(msg) ~= 'string' then
            msg = format_string('non-string non-table error:\n%r', msg)
          end
          error(
            format_string(
              'Error while processing test (%r, %s):\n%s',
              str,
              FLAGS_TO_STR[flags],
              msg
            )
          )
        end
      end
    end
    local function hl(group, str, shift)
      return function(next_col)
        local col = next_col + (shift or 0)
        return (('%s:%u:%u:%s'):format('Nvim' .. group, 0, col, str)), (col + #str)
      end
    end
    local function fmtn(typ, args, rest)
      if
        typ == 'UnknownFigure'
        or typ == 'DictLiteral'
        or typ == 'CurlyBracesIdentifier'
        or typ == 'Lambda'
      then
        return ('%s%s'):format(typ, rest)
      elseif typ == 'DoubleQuotedString' or typ == 'SingleQuotedString' then
        if args:sub(-4) == 'NULL' then
          args = args:sub(1, -5) .. '""'
        end
        return ('%s(%s)%s'):format(typ, args, rest)
      end
    end
    require('test.unit.viml.expressions.parser_tests')(it, _check_parsing, hl, fmtn)
  end)

  describe('nvim_list_uis', function()
    it('returns empty if --headless', function()
      -- Test runner defaults to --headless.
      eq({}, api.nvim_list_uis())
    end)
    it('returns attached UIs', function()
      local screen = Screen.new(20, 4)
      screen:attach({ override = true })
      local expected = {
        {
          chan = 1,
          ext_cmdline = false,
          ext_hlstate = false,
          ext_linegrid = screen._options.ext_linegrid or false,
          ext_messages = false,
          ext_multigrid = false,
          ext_popupmenu = false,
          ext_tabline = false,
          ext_termcolors = false,
          ext_wildmenu = false,
          height = 4,
          override = true,
          rgb = true,
          stdin_tty = false,
          stdout_tty = false,
          term_background = '',
          term_colors = 0,
          term_name = '',
          width = 20,
        },
      }

      eq(expected, api.nvim_list_uis())

      screen:detach()
      screen = Screen.new(44, 99)
      screen:attach({ rgb = false })
      expected[1].rgb = false
      expected[1].override = false
      expected[1].width = 44
      expected[1].height = 99
      eq(expected, api.nvim_list_uis())
    end)
  end)

  describe('nvim_create_namespace', function()
    it('works', function()
      eq({}, api.nvim_get_namespaces())
      eq(1, api.nvim_create_namespace('ns-1'))
      eq(2, api.nvim_create_namespace('ns-2'))
      eq(1, api.nvim_create_namespace('ns-1'))
      eq({ ['ns-1'] = 1, ['ns-2'] = 2 }, api.nvim_get_namespaces())
      eq(3, api.nvim_create_namespace(''))
      eq(4, api.nvim_create_namespace(''))
      eq({ ['ns-1'] = 1, ['ns-2'] = 2 }, api.nvim_get_namespaces())
    end)
  end)

  describe('nvim_create_buf', function()
    it('works', function()
      eq(2, api.nvim_create_buf(true, false))
      eq(3, api.nvim_create_buf(false, false))
      eq(
        '  1 %a   "[No Name]"                    line 1\n'
          .. '  2  h   "[No Name]"                    line 0',
        command_output('ls')
      )
      -- current buffer didn't change
      eq(1, api.nvim_get_current_buf())

      local screen = Screen.new(20, 4)
      screen:attach()
      api.nvim_buf_set_lines(2, 0, -1, true, { 'some text' })
      api.nvim_set_current_buf(2)
      screen:expect(
        [[
        ^some text           |
        {1:~                   }|*2
                            |
      ]],
        {
          [1] = { bold = true, foreground = Screen.colors.Blue1 },
        }
      )
    end)

    it('can change buftype before visiting', function()
      api.nvim_set_option_value('hidden', false, {})
      eq(2, api.nvim_create_buf(true, false))
      api.nvim_set_option_value('buftype', 'nofile', { buf = 2 })
      api.nvim_buf_set_lines(2, 0, -1, true, { 'test text' })
      command('split | buffer 2')
      eq(2, api.nvim_get_current_buf())
      -- if the buf_set_option("buftype") didn't work, this would error out.
      command('close')
      eq(1, api.nvim_get_current_buf())
    end)

    it('does not trigger BufEnter, BufWinEnter', function()
      command('let g:fired = v:false')
      command('au BufEnter,BufWinEnter * let g:fired = v:true')

      eq(2, api.nvim_create_buf(true, false))
      api.nvim_buf_set_lines(2, 0, -1, true, { 'test', 'text' })

      eq(false, eval('g:fired'))
    end)

    it('TextChanged and TextChangedI do not trigger without changes', function()
      local buf = api.nvim_create_buf(true, false)
      command([[let g:changed = '']])
      api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
        buffer = buf,
        command = 'let g:changed ..= mode()',
      })
      api.nvim_set_current_buf(buf)
      feed('i')
      eq('', api.nvim_get_var('changed'))
    end)

    it('scratch-buffer', function()
      eq(2, api.nvim_create_buf(false, true))
      eq(3, api.nvim_create_buf(true, true))
      eq(4, api.nvim_create_buf(true, true))
      local scratch_bufs = { 2, 3, 4 }
      eq(
        '  1 %a   "[No Name]"                    line 1\n'
          .. '  3  h   "[Scratch]"                    line 0\n'
          .. '  4  h   "[Scratch]"                    line 0',
        exec_capture('ls')
      )
      -- current buffer didn't change
      eq(1, api.nvim_get_current_buf())

      local screen = Screen.new(20, 4)
      screen:attach()

      --
      -- Editing a scratch-buffer does NOT change its properties.
      --
      local edited_buf = 2
      api.nvim_buf_set_lines(edited_buf, 0, -1, true, { 'some text' })
      for _, b in ipairs(scratch_bufs) do
        eq('nofile', api.nvim_get_option_value('buftype', { buf = b }))
        eq('hide', api.nvim_get_option_value('bufhidden', { buf = b }))
        eq(false, api.nvim_get_option_value('swapfile', { buf = b }))
        eq(false, api.nvim_get_option_value('modeline', { buf = b }))
      end

      --
      -- Visiting a scratch-buffer DOES NOT change its properties.
      --
      api.nvim_set_current_buf(edited_buf)
      screen:expect([[
        ^some text           |
        {1:~                   }|*2
                            |
      ]])
      eq('nofile', api.nvim_get_option_value('buftype', { buf = edited_buf }))
      eq('hide', api.nvim_get_option_value('bufhidden', { buf = edited_buf }))
      eq(false, api.nvim_get_option_value('swapfile', { buf = edited_buf }))
      eq(false, api.nvim_get_option_value('modeline', { buf = edited_buf }))

      -- Scratch buffer can be wiped without error.
      command('bwipe')
      screen:expect([[
        ^                    |
        {1:~                   }|*2
                            |
      ]])
    end)

    it('does not cause heap-use-after-free on exit while setting options', function()
      command('au OptionSet * q')
      command('silent! call nvim_create_buf(0, 1)')
      -- nowadays this works because we don't execute any spurious autocmds at all #24824
      assert_alive()
    end)

    it('no memory leak when autocommands load the buffer immediately', function()
      exec([[
        autocmd BufNew * ++once call bufload(expand("<abuf>")->str2nr())
                             \| let loaded = bufloaded(expand("<abuf>")->str2nr())
      ]])
      api.nvim_create_buf(false, true)
      eq(1, eval('g:loaded'))
    end)

    it('creating scratch buffer where autocommands set &swapfile works', function()
      exec([[
        autocmd BufNew * ++once execute expand("<abuf>") "buffer"
                             \| file foobar
                             \| setlocal swapfile
      ]])
      local new_buf = api.nvim_create_buf(false, true)
      neq('', fn.swapname(new_buf))
    end)

    it('fires expected autocommands', function()
      exec([=[
        " Append the &buftype to check autocommands trigger *after* the buffer was configured to be
        " scratch, if applicable.
        autocmd BufNew * let fired += [["BufNew", expand("<abuf>")->str2nr(),
                                      \ getbufvar(expand("<abuf>")->str2nr(), "&buftype")]]
        autocmd BufAdd * let fired += [["BufAdd", expand("<abuf>")->str2nr(),
                                      \ getbufvar(expand("<abuf>")->str2nr(), "&buftype")]]

        " Don't want to see OptionSet; buffer options set from passing true for "scratch", etc.
        " should be configured invisibly, and before autocommands.
        autocmd OptionSet * let fired += [["OptionSet", expand("<amatch>")]]

        let fired = []
      ]=])
      local new_buf = api.nvim_create_buf(false, false)
      eq({ { 'BufNew', new_buf, '' } }, eval('g:fired'))

      command('let fired = []')
      new_buf = api.nvim_create_buf(false, true)
      eq({ { 'BufNew', new_buf, 'nofile' } }, eval('g:fired'))

      command('let fired = []')
      new_buf = api.nvim_create_buf(true, false)
      eq({ { 'BufNew', new_buf, '' }, { 'BufAdd', new_buf, '' } }, eval('g:fired'))

      command('let fired = []')
      new_buf = api.nvim_create_buf(true, true)
      eq({ { 'BufNew', new_buf, 'nofile' }, { 'BufAdd', new_buf, 'nofile' } }, eval('g:fired'))
    end)
  end)

  describe('nvim_get_runtime_file', function()
    local p = n.alter_slashes
    it('can find files', function()
      eq({}, api.nvim_get_runtime_file('bork.borkbork', false))
      eq({}, api.nvim_get_runtime_file('bork.borkbork', true))
      eq(1, #api.nvim_get_runtime_file('autoload/msgpack.vim', false))
      eq(1, #api.nvim_get_runtime_file('autoload/msgpack.vim', true))
      local val = api.nvim_get_runtime_file('autoload/remote/*.vim', true)
      eq(2, #val)
      if endswith(val[1], 'define.vim') then
        ok(endswith(val[1], p 'autoload/remote/define.vim'))
        ok(endswith(val[2], p 'autoload/remote/host.vim'))
      else
        ok(endswith(val[1], p 'autoload/remote/host.vim'))
        ok(endswith(val[2], p 'autoload/remote/define.vim'))
      end
      val = api.nvim_get_runtime_file('autoload/remote/*.vim', false)
      eq(1, #val)
      ok(
        endswith(val[1], p 'autoload/remote/define.vim')
          or endswith(val[1], p 'autoload/remote/host.vim')
      )

      val = api.nvim_get_runtime_file('lua', true)
      eq(1, #val)
      ok(endswith(val[1], p 'lua'))

      val = api.nvim_get_runtime_file('lua/vim', true)
      eq(1, #val)
      ok(endswith(val[1], p 'lua/vim'))
    end)

    it('can find directories', function()
      local val = api.nvim_get_runtime_file('lua/', true)
      eq(1, #val)
      ok(endswith(val[1], p 'lua/'))

      val = api.nvim_get_runtime_file('lua/vim/', true)
      eq(1, #val)
      ok(endswith(val[1], p 'lua/vim/'))

      eq({}, api.nvim_get_runtime_file('foobarlang/', true))
    end)
    it('can handle bad patterns', function()
      skip(is_os('win'))

      eq('Vim:E220: Missing }.', pcall_err(api.nvim_get_runtime_file, '{', false))

      eq(
        'Vim(echo):E5555: API call: Vim:E220: Missing }.',
        exc_exec("echo nvim_get_runtime_file('{', v:false)")
      )
    end)
  end)

  describe('nvim_get_all_options_info', function()
    it('should have key value pairs of option names', function()
      local options_info = api.nvim_get_all_options_info()
      neq(nil, options_info.listchars)
      neq(nil, options_info.tabstop)

      eq(api.nvim_get_option_info 'winhighlight', options_info.winhighlight)
    end)

    it('should not crash when echoed', function()
      api.nvim_exec2('echo nvim_get_all_options_info()', { output = true })
    end)
  end)

  describe('nvim_get_option_info', function()
    it('should error for unknown options', function()
      eq("Invalid option (not found): 'bogus'", pcall_err(api.nvim_get_option_info, 'bogus'))
    end)

    it('should return the same options for short and long name', function()
      eq(api.nvim_get_option_info 'winhl', api.nvim_get_option_info 'winhighlight')
    end)

    it('should have information about window options', function()
      eq({
        allows_duplicates = false,
        commalist = true,
        default = '',
        flaglist = false,
        global_local = false,
        last_set_chan = 0,
        last_set_linenr = 0,
        last_set_sid = 0,
        name = 'winhighlight',
        scope = 'win',
        shortname = 'winhl',
        type = 'string',
        was_set = false,
      }, api.nvim_get_option_info 'winhl')
    end)

    it('should have information about buffer options', function()
      eq({
        allows_duplicates = true,
        commalist = false,
        default = '',
        flaglist = false,
        global_local = false,
        last_set_chan = 0,
        last_set_linenr = 0,
        last_set_sid = 0,
        name = 'filetype',
        scope = 'buf',
        shortname = 'ft',
        type = 'string',
        was_set = false,
      }, api.nvim_get_option_info 'filetype')
    end)

    it('should have information about global options', function()
      -- precondition: the option was changed from its default
      -- in test setup.
      eq(false, api.nvim_get_option_value('showcmd', {}))

      eq({
        allows_duplicates = true,
        commalist = false,
        default = true,
        flaglist = false,
        global_local = false,
        last_set_chan = 0,
        last_set_linenr = 0,
        last_set_sid = -2,
        name = 'showcmd',
        scope = 'global',
        shortname = 'sc',
        type = 'boolean',
        was_set = true,
      }, api.nvim_get_option_info 'showcmd')

      api.nvim_set_option_value('showcmd', true, {})

      eq({
        allows_duplicates = true,
        commalist = false,
        default = true,
        flaglist = false,
        global_local = false,
        last_set_chan = 1,
        last_set_linenr = 0,
        last_set_sid = -9,
        name = 'showcmd',
        scope = 'global',
        shortname = 'sc',
        type = 'boolean',
        was_set = true,
      }, api.nvim_get_option_info 'showcmd')
    end)
  end)

  describe('nvim_get_option_info2', function()
    local fname
    local bufs
    local wins

    before_each(function()
      fname = tmpname()
      write_file(
        fname,
        [[
        setglobal dictionary=mydict " 1, global-local (buffer)
        setlocal  formatprg=myprg   " 2, global-local (buffer)
        setglobal equalprg=prg1     " 3, global-local (buffer)
        setlocal  equalprg=prg2     " 4, global-local (buffer)
        setglobal fillchars=stl:x   " 5, global-local (window)
        setlocal  listchars=eol:c   " 6, global-local (window)
        setglobal showbreak=aaa     " 7, global-local (window)
        setlocal  showbreak=bbb     " 8, global-local (window)
        setglobal completeopt=menu  " 9, global
      ]]
      )

      exec_lua 'vim.cmd.vsplit()'
      api.nvim_create_buf(false, false)

      bufs = api.nvim_list_bufs()
      wins = api.nvim_list_wins()

      api.nvim_win_set_buf(wins[1], bufs[1])
      api.nvim_win_set_buf(wins[2], bufs[2])

      api.nvim_set_current_win(wins[2])
      api.nvim_exec('source ' .. fname, false)

      api.nvim_set_current_win(wins[1])
    end)

    after_each(function()
      os.remove(fname)
    end)

    it('should return option information', function()
      eq(api.nvim_get_option_info('dictionary'), api.nvim_get_option_info2('dictionary', {})) -- buffer
      eq(api.nvim_get_option_info('fillchars'), api.nvim_get_option_info2('fillchars', {})) -- window
      eq(api.nvim_get_option_info('completeopt'), api.nvim_get_option_info2('completeopt', {})) -- global
    end)

    describe('last set', function()
      -- stylua: ignore
      local tests = {
        {desc="(buf option, global requested, global set) points to global",   linenr=1, sid=1, args={'dictionary', {scope='global'}}},
        {desc="(buf option, global requested, local set) is not set",          linenr=0, sid=0, args={'formatprg',  {scope='global'}}},
        {desc="(buf option, global requested, both set) points to global",     linenr=3, sid=1, args={'equalprg',   {scope='global'}}},
        {desc="(buf option, local requested, global set) is not set",          linenr=0, sid=0, args={'dictionary', {scope='local'}}},
        {desc="(buf option, local requested, local set) points to local",      linenr=2, sid=1, args={'formatprg',  {scope='local'}}},
        {desc="(buf option, local requested, both set) points to local",       linenr=4, sid=1, args={'equalprg',   {scope='local'}}},
        {desc="(buf option, fallback requested, global set) points to global", linenr=1, sid=1, args={'dictionary', {}}},
        {desc="(buf option, fallback requested, local set) points to local",   linenr=2, sid=1, args={'formatprg',  {}}},
        {desc="(buf option, fallback requested, both set) points to local",    linenr=4, sid=1, args={'equalprg',   {}}},
        {desc="(win option, global requested, global set) points to global",   linenr=5, sid=1, args={'fillchars', {scope='global'}}},
        {desc="(win option, global requested, local set) is not set",          linenr=0, sid=0, args={'listchars', {scope='global'}}},
        {desc="(win option, global requested, both set) points to global",     linenr=7, sid=1, args={'showbreak', {scope='global'}}},
        {desc="(win option, local requested, global set) is not set",          linenr=0, sid=0, args={'fillchars', {scope='local'}}},
        {desc="(win option, local requested, local set) points to local",      linenr=6, sid=1, args={'listchars', {scope='local'}}},
        {desc="(win option, local requested, both set) points to local",       linenr=8, sid=1, args={'showbreak', {scope='local'}}},
        {desc="(win option, fallback requested, global set) points to global", linenr=5, sid=1, args={'fillchars', {}}},
        {desc="(win option, fallback requested, local set) points to local",   linenr=6, sid=1, args={'listchars', {}}},
        {desc="(win option, fallback requested, both set) points to local",    linenr=8, sid=1, args={'showbreak', {}}},
        {desc="(global option, global requested) points to global",            linenr=9, sid=1, args={'completeopt', {scope='global'}}},
        {desc="(global option, local requested) is not set",                   linenr=0, sid=0, args={'completeopt', {scope='local'}}},
        {desc="(global option, fallback requested) points to global",          linenr=9, sid=1, args={'completeopt', {}}},
      }

      for _, test in pairs(tests) do
        it(test.desc, function()
          -- Switch to the target buffer/window so that curbuf/curwin are used.
          api.nvim_set_current_win(wins[2])
          local info = api.nvim_get_option_info2(unpack(test.args))
          eq(test.linenr, info.last_set_linenr)
          eq(test.sid, info.last_set_sid)
        end)
      end

      it('is provided for cross-buffer requests', function()
        local info = api.nvim_get_option_info2('formatprg', { buf = bufs[2] })
        eq(2, info.last_set_linenr)
        eq(1, info.last_set_sid)
      end)

      it('is provided for cross-window requests', function()
        local info = api.nvim_get_option_info2('listchars', { win = wins[2] })
        eq(6, info.last_set_linenr)
        eq(1, info.last_set_sid)
      end)
    end)
  end)

  describe('nvim_echo', function()
    local screen

    before_each(function()
      screen = Screen.new(40, 8)
      screen:attach()
      command('highlight Statement gui=bold guifg=Brown')
      command('highlight Special guifg=SlateBlue')
    end)

    it('should clear cmdline message before echo', function()
      feed(':call nvim_echo([["msg"]], v:false, {})<CR>')
      screen:expect {
        grid = [[
        ^                                        |
        {1:~                                       }|*6
        msg                                     |
      ]],
      }
    end)

    it('can show highlighted line', function()
      async_meths.nvim_echo(
        { { 'msg_a' }, { 'msg_b', 'Statement' }, { 'msg_c', 'Special' } },
        true,
        {}
      )
      screen:expect {
        grid = [[
        ^                                        |
        {1:~                                       }|*6
        msg_a{15:msg_b}{16:msg_c}                         |
      ]],
      }
    end)

    it('can show highlighted multiline', function()
      async_meths.nvim_echo({ { 'msg_a\nmsg_a', 'Statement' }, { 'msg_b', 'Special' } }, true, {})
      screen:expect {
        grid = [[
                                                |
        {1:~                                       }|*3
        {3:                                        }|
        {15:msg_a}                                   |
        {15:msg_a}{16:msg_b}                              |
        {6:Press ENTER or type command to continue}^ |
      ]],
      }
    end)

    it('can save message history', function()
      command('set cmdheight=2') -- suppress Press ENTER
      api.nvim_echo({ { 'msg\nmsg' }, { 'msg' } }, true, {})
      eq('msg\nmsgmsg', exec_capture('messages'))
    end)

    it('can disable saving message history', function()
      command('set cmdheight=2') -- suppress Press ENTER
      async_meths.nvim_echo({ { 'msg\nmsg' }, { 'msg' } }, false, {})
      eq('', exec_capture('messages'))
    end)
  end)

  describe('nvim_open_term', function()
    local screen

    before_each(function()
      screen = Screen.new(100, 35)
      screen:attach()
      screen:add_extra_attr_ids {
        [100] = { background = tonumber('0xffff40'), bg_indexed = true },
        [101] = {
          background = Screen.colors.LightMagenta,
          foreground = tonumber('0x00e000'),
          fg_indexed = true,
        },
        [102] = { background = Screen.colors.LightMagenta, reverse = true },
        [103] = { background = Screen.colors.LightMagenta, bold = true, reverse = true },
      }
    end)

    it('can batch process sequences', function()
      local b = api.nvim_create_buf(true, true)
      api.nvim_open_win(
        b,
        false,
        { width = 79, height = 31, row = 1, col = 1, relative = 'editor' }
      )
      local term = api.nvim_open_term(b, {})

      api.nvim_chan_send(term, io.open('test/functional/fixtures/smile2.cat', 'r'):read('*a'))
      screen:expect {
        grid = [[
        ^                                                                                                    |
        {1:~}{4::smile                                                                         }{1:                    }|
        {1:~}{4:                            }{100:oooo$$$$$$$$$$$$oooo}{4:                               }{1:                    }|
        {1:~}{4:                        }{100:oo$$$$$$$$$$$$$$$$$$$$$$$$o}{4:                            }{1:                    }|
        {1:~}{4:                     }{100:oo$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$o}{4:         }{100:o$}{4:   }{100:$$}{4: }{100:o$}{4:      }{1:                    }|
        {1:~}{4:     }{100:o}{4: }{100:$}{4: }{100:oo}{4:        }{100:o$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$o}{4:       }{100:$$}{4: }{100:$$}{4: }{100:$$o$}{4:     }{1:                    }|
        {1:~}{4:  }{100:oo}{4: }{100:$}{4: }{100:$}{4: "}{100:$}{4:      }{100:o$$$$$$$$$}{4:    }{100:$$$$$$$$$$$$$}{4:    }{100:$$$$$$$$$o}{4:       }{100:$$$o$$o$}{4:      }{1:                    }|
        {1:~}{4:  "}{100:$$$$$$o$}{4:     }{100:o$$$$$$$$$}{4:      }{100:$$$$$$$$$$$}{4:      }{100:$$$$$$$$$$o}{4:    }{100:$$$$$$$$}{4:       }{1:                    }|
        {1:~}{4:    }{100:$$$$$$$}{4:    }{100:$$$$$$$$$$$}{4:      }{100:$$$$$$$$$$$}{4:      }{100:$$$$$$$$$$$$$$$$$$$$$$$}{4:       }{1:                    }|
        {1:~}{4:    }{100:$$$$$$$$$$$$$$$$$$$$$$$}{4:    }{100:$$$$$$$$$$$$$}{4:    }{100:$$$$$$$$$$$$$$}{4:  """}{100:$$$}{4:         }{1:                    }|
        {1:~}{4:     "}{100:$$$}{4:""""}{100:$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{4:     "}{100:$$$}{4:        }{1:                    }|
        {1:~}{4:      }{100:$$$}{4:   }{100:o$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{4:     "}{100:$$$o}{4:      }{1:                    }|
        {1:~}{4:     }{100:o$$}{4:"   }{100:$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{4:       }{100:$$$o}{4:     }{1:                    }|
        {1:~}{4:     }{100:$$$}{4:    }{100:$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{4:" "}{100:$$$$$$ooooo$$$$o}{4:   }{1:                    }|
        {1:~}{4:    }{100:o$$$oooo$$$$$}{4:  }{100:$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{4:   }{100:o$$$$$$$$$$$$$$$$$}{4:  }{1:                    }|
        {1:~}{4:    }{100:$$$$$$$$}{4:"}{100:$$$$}{4:   }{100:$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{4:     }{100:$$$$}{4:""""""""        }{1:                    }|
        {1:~}{4:   """"       }{100:$$$$}{4:    "}{100:$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{4:"      }{100:o$$$}{4:                 }{1:                    }|
        {1:~}{4:              "}{100:$$$o}{4:     """}{100:$$$$$$$$$$$$$$$$$$}{4:"}{100:$$}{4:"         }{100:$$$}{4:                  }{1:                    }|
        {1:~}{4:                }{100:$$$o}{4:          "}{100:$$}{4:""}{100:$$$$$$}{4:""""           }{100:o$$$}{4:                   }{1:                    }|
        {1:~}{4:                 }{100:$$$$o}{4:                                }{100:o$$$}{4:"                    }{1:                    }|
        {1:~}{4:                  "}{100:$$$$o}{4:      }{100:o$$$$$$o}{4:"}{100:$$$$o}{4:        }{100:o$$$$}{4:                      }{1:                    }|
        {1:~}{4:                    "}{100:$$$$$oo}{4:     ""}{100:$$$$o$$$$$o}{4:   }{100:o$$$$}{4:""                       }{1:                    }|
        {1:~}{4:                       ""}{100:$$$$$oooo}{4:  "}{100:$$$o$$$$$$$$$}{4:"""                          }{1:                    }|
        {1:~}{4:                          ""}{100:$$$$$$$oo}{4: }{100:$$$$$$$$$$}{4:                               }{1:                    }|
        {1:~}{4:                                  """"}{100:$$$$$$$$$$$}{4:                              }{1:                    }|
        {1:~}{4:                                      }{100:$$$$$$$$$$$$}{4:                             }{1:                    }|
        {1:~}{4:                                       }{100:$$$$$$$$$$}{4:"                             }{1:                    }|
        {1:~}{4:                                        "}{100:$$$}{4:""""                               }{1:                    }|
        {1:~}{4:                                                                               }{1:                    }|
        {1:~}{101:Press ENTER or type command to continue}{4:                                        }{1:                    }|
        {1:~}{103:term://~/config2/docs/pres//32693:vim --clean +smile         29,39          All}{1:                    }|
        {1:~}{4::call nvim__screenshot("smile2.cat")                                           }{1:                    }|
        {1:~                                                                                                   }|*2
                                                                                                            |
      ]],
      }
    end)

    it('can handle input', function()
      screen:try_resize(50, 10)
      eq(
        { 3, 2 },
        exec_lua [[
        buf = vim.api.nvim_create_buf(1,1)

        stream = ''
        do_the_echo = false
        function input(_,t1,b1,data)
          stream = stream .. data
          _G.vals = {t1, b1}
          if do_the_echo then
            vim.api.nvim_chan_send(t1, data)
          end
        end

        term = vim.api.nvim_open_term(buf, {on_input=input})
        vim.api.nvim_open_win(buf, true, {width=40, height=5, row=1, col=1, relative='editor'})
        return {term, buf}
      ]]
      )

      screen:expect {
        grid = [[
                                                          |
        {1:~}{4:^                                        }{1:         }|
        {1:~}{4:                                        }{1:         }|*4
        {1:~                                                 }|*3
                                                          |
      ]],
      }

      feed 'iba<c-x>bla'
      screen:expect {
        grid = [[
                                                          |
        {1:~}{102: }{4:                                       }{1:         }|
        {1:~}{4:                                        }{1:         }|*4
        {1:~                                                 }|*3
        {5:-- TERMINAL --}                                    |
      ]],
      }

      eq('ba\024bla', exec_lua [[ return stream ]])
      eq({ 3, 2 }, exec_lua [[ return vals ]])

      exec_lua [[ do_the_echo = true ]]
      feed 'herrejösses!'

      screen:expect {
        grid = [[
                                                          |
        {1:~}{4:herrejösses!}{102: }{4:                           }{1:         }|
        {1:~}{4:                                        }{1:         }|*4
        {1:~                                                 }|*3
        {5:-- TERMINAL --}                                    |
      ]],
      }
      eq('ba\024blaherrejösses!', exec_lua [[ return stream ]])
    end)
  end)

  describe('nvim_del_mark', function()
    it('works', function()
      local buf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_lines(buf, -1, -1, true, { 'a', 'bit of', 'text' })
      eq(true, api.nvim_buf_set_mark(buf, 'F', 2, 2, {}))
      eq(true, api.nvim_del_mark('F'))
      eq({ 0, 0 }, api.nvim_buf_get_mark(buf, 'F'))
    end)
    it('validation', function()
      eq("Invalid mark name (must be file/uppercase): 'f'", pcall_err(api.nvim_del_mark, 'f'))
      eq("Invalid mark name (must be file/uppercase): '!'", pcall_err(api.nvim_del_mark, '!'))
      eq("Invalid mark name (must be a single char): 'fail'", pcall_err(api.nvim_del_mark, 'fail'))
    end)
  end)
  describe('nvim_get_mark', function()
    it('works', function()
      local buf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_lines(buf, -1, -1, true, { 'a', 'bit of', 'text' })
      api.nvim_buf_set_mark(buf, 'F', 2, 2, {})
      api.nvim_buf_set_name(buf, 'mybuf')
      local mark = api.nvim_get_mark('F', {})
      -- Compare the path tail only
      matches('mybuf$', mark[4])
      eq({ 2, 2, buf, mark[4] }, mark)
    end)
    it('validation', function()
      eq("Invalid mark name (must be file/uppercase): 'f'", pcall_err(api.nvim_get_mark, 'f', {}))
      eq("Invalid mark name (must be file/uppercase): '!'", pcall_err(api.nvim_get_mark, '!', {}))
      eq(
        "Invalid mark name (must be a single char): 'fail'",
        pcall_err(api.nvim_get_mark, 'fail', {})
      )
    end)
    it('returns the expected when mark is not set', function()
      eq(true, api.nvim_del_mark('A'))
      eq({ 0, 0, 0, '' }, api.nvim_get_mark('A', {}))
    end)
    it('works with deleted buffers', function()
      local fname = tmpname()
      write_file(fname, 'a\nbit of\text')
      command('edit ' .. fname)
      local buf = api.nvim_get_current_buf()

      api.nvim_buf_set_mark(buf, 'F', 2, 2, {})
      command('new') -- Create new buf to avoid :bd failing
      command('bd! ' .. buf)
      os.remove(fname)

      local mark = api.nvim_get_mark('F', {})
      -- To avoid comparing relative vs absolute path
      local mfname = mark[4]
      local tail_patt = [[[\/][^\/]*$]]
      -- tail of paths should be equals
      eq(fname:match(tail_patt), mfname:match(tail_patt))
      eq({ 2, 2, buf, mark[4] }, mark)
    end)
  end)

  describe('nvim_eval_statusline', function()
    it('works', function()
      eq({
        str = '%StatusLineStringWithHighlights',
        width = 31,
      }, api.nvim_eval_statusline('%%StatusLineString%#WarningMsg#WithHighlights', {}))
    end)

    it("doesn't exceed maxwidth", function()
      eq({
        str = 'Should be trun>',
        width = 15,
      }, api.nvim_eval_statusline('Should be truncated%<', { maxwidth = 15 }))
    end)

    it('has correct default fillchar', function()
      local oldwin = api.nvim_get_current_win()
      command('set fillchars=stl:#,stlnc:$,wbr:%')
      command('new')
      eq({ str = 'a###b', width = 5 }, api.nvim_eval_statusline('a%=b', { maxwidth = 5 }))
      eq(
        { str = 'a$$$b', width = 5 },
        api.nvim_eval_statusline('a%=b', { winid = oldwin, maxwidth = 5 })
      )
      eq(
        { str = 'a%%%b', width = 5 },
        api.nvim_eval_statusline('a%=b', { use_winbar = true, maxwidth = 5 })
      )
      eq(
        { str = 'a   b', width = 5 },
        api.nvim_eval_statusline('a%=b', { use_tabline = true, maxwidth = 5 })
      )
      eq(
        { str = 'a   b', width = 5 },
        api.nvim_eval_statusline('a%=b', { use_statuscol_lnum = 1, maxwidth = 5 })
      )
    end)

    for fc, desc in pairs({
      ['~'] = 'supports ASCII fillchar',
      ['━'] = 'supports single-width multibyte fillchar',
      ['c̳'] = 'supports single-width fillchar with composing',
      ['哦'] = 'treats double-width fillchar as single-width',
      ['\031'] = 'treats control character fillchar as single-width',
    }) do
      it(desc, function()
        eq(
          { str = 'a' .. fc:rep(3) .. 'b', width = 5 },
          api.nvim_eval_statusline('a%=b', { fillchar = fc, maxwidth = 5 })
        )
        eq(
          { str = 'a' .. fc:rep(3) .. 'b', width = 5 },
          api.nvim_eval_statusline('a%=b', { fillchar = fc, use_winbar = true, maxwidth = 5 })
        )
        eq(
          { str = 'a' .. fc:rep(3) .. 'b', width = 5 },
          api.nvim_eval_statusline('a%=b', { fillchar = fc, use_tabline = true, maxwidth = 5 })
        )
        eq(
          { str = 'a' .. fc:rep(3) .. 'b', width = 5 },
          api.nvim_eval_statusline('a%=b', { fillchar = fc, use_statuscol_lnum = 1, maxwidth = 5 })
        )
      end)
    end

    it('rejects multiple-character fillchar', function()
      eq(
        "Invalid 'fillchar': expected single character",
        pcall_err(api.nvim_eval_statusline, '', { fillchar = 'aa' })
      )
    end)

    it('rejects empty string fillchar', function()
      eq(
        "Invalid 'fillchar': expected single character",
        pcall_err(api.nvim_eval_statusline, '', { fillchar = '' })
      )
    end)

    it('rejects non-string fillchar', function()
      eq(
        "Invalid 'fillchar': expected String, got Integer",
        pcall_err(api.nvim_eval_statusline, '', { fillchar = 1 })
      )
    end)

    it('rejects invalid string', function()
      eq('E539: Illegal character <}>', pcall_err(api.nvim_eval_statusline, '%{%}', {}))
    end)

    it('supports various items', function()
      eq({ str = '0', width = 1 }, api.nvim_eval_statusline('%l', { maxwidth = 5 }))
      command('set readonly')
      eq({ str = '[RO]', width = 4 }, api.nvim_eval_statusline('%r', { maxwidth = 5 }))
      local screen = Screen.new(80, 24)
      screen:attach()
      command('set showcmd')
      feed('1234')
      screen:expect({ any = '1234' })
      eq({ str = '1234', width = 4 }, api.nvim_eval_statusline('%S', { maxwidth = 5 }))
      feed('56')
      screen:expect({ any = '123456' })
      eq({ str = '<3456', width = 5 }, api.nvim_eval_statusline('%S', { maxwidth = 5 }))
    end)

    describe('highlight parsing', function()
      it('works', function()
        eq(
          {
            str = 'TextWithWarningHighlightTextWithUserHighlight',
            width = 45,
            highlights = {
              { start = 0, group = 'WarningMsg' },
              { start = 24, group = 'User1' },
            },
          },
          api.nvim_eval_statusline(
            '%#WarningMsg#TextWithWarningHighlight%1*TextWithUserHighlight',
            { highlights = true }
          )
        )
      end)

      it('works with no highlight', function()
        eq({
          str = 'TextWithNoHighlight',
          width = 19,
          highlights = {
            { start = 0, group = 'StatusLine' },
          },
        }, api.nvim_eval_statusline('TextWithNoHighlight', { highlights = true }))
      end)

      it('works with inactive statusline', function()
        command('split')
        eq(
          {
            str = 'TextWithNoHighlightTextWithWarningHighlight',
            width = 43,
            highlights = {
              { start = 0, group = 'StatusLineNC' },
              { start = 19, group = 'WarningMsg' },
            },
          },
          api.nvim_eval_statusline(
            'TextWithNoHighlight%#WarningMsg#TextWithWarningHighlight',
            { winid = api.nvim_list_wins()[2], highlights = true }
          )
        )
      end)

      it('works with tabline', function()
        eq(
          {
            str = 'TextWithNoHighlightTextWithWarningHighlight',
            width = 43,
            highlights = {
              { start = 0, group = 'TabLineFill' },
              { start = 19, group = 'WarningMsg' },
            },
          },
          api.nvim_eval_statusline(
            'TextWithNoHighlight%#WarningMsg#TextWithWarningHighlight',
            { use_tabline = true, highlights = true }
          )
        )
      end)

      it('works with winbar', function()
        eq(
          {
            str = 'TextWithNoHighlightTextWithWarningHighlight',
            width = 43,
            highlights = {
              { start = 0, group = 'WinBar' },
              { start = 19, group = 'WarningMsg' },
            },
          },
          api.nvim_eval_statusline(
            'TextWithNoHighlight%#WarningMsg#TextWithWarningHighlight',
            { use_winbar = true, highlights = true }
          )
        )
      end)

      it('works with statuscolumn', function()
        exec([[
          let &stc='%C%s%=%l '
          " should not use "stl" from 'fillchars'
          set cul nu nuw=3 scl=yes:2 fdc=2 fillchars=stl:#
          call setline(1, repeat(['aaaaa'], 5))
          let g:ns = nvim_create_namespace('')
          call sign_define('a', {'text':'aa', 'texthl':'IncSearch', 'numhl':'Normal'})
          call sign_place(2, 1, 'a', bufnr(), {'lnum':4})
          call nvim_buf_set_extmark(0, g:ns, 3, 1, { 'sign_text':'bb', 'sign_hl_group':'ErrorMsg' })
          1,5fold | 1,5 fold | foldopen!
          norm 4G
        ]])
        eq({
          str = '││bbaa 4 ',
          width = 9,
          highlights = {
            { group = 'CursorLineFold', start = 0 },
            { group = 'Normal', start = 6 },
            { group = 'ErrorMsg', start = 6 },
            { group = 'IncSearch', start = 8 },
            { group = 'Normal', start = 10 },
          },
        }, api.nvim_eval_statusline(
          '%C%s%=%l ',
          { use_statuscol_lnum = 4, highlights = true }
        ))
        eq(
          {
            str = '3 ',
            width = 2,
            highlights = {
              { group = 'LineNr', start = 0 },
              { group = 'ErrorMsg', start = 1 },
            },
          },
          api.nvim_eval_statusline('%l%#ErrorMsg# ', { use_statuscol_lnum = 3, highlights = true })
        )
      end)

      it('no memory leak with click functions', function()
        api.nvim_eval_statusline('%@ClickFunc@StatusLineStringWithClickFunc%T', {})
        eq({
          str = 'StatusLineStringWithClickFunc',
          width = 29,
        }, api.nvim_eval_statusline('%@ClickFunc@StatusLineStringWithClickFunc%T', {}))
      end)
    end)
  end)

  describe('nvim_parse_cmd', function()
    it('works', function()
      eq({
        cmd = 'echo',
        args = { 'foo' },
        bang = false,
        addr = 'none',
        magic = {
          file = false,
          bar = false,
        },
        nargs = '*',
        nextcmd = '',
        mods = {
          browse = false,
          confirm = false,
          emsg_silent = false,
          filter = {
            pattern = '',
            force = false,
          },
          hide = false,
          horizontal = false,
          keepalt = false,
          keepjumps = false,
          keepmarks = false,
          keeppatterns = false,
          lockmarks = false,
          noautocmd = false,
          noswapfile = false,
          sandbox = false,
          silent = false,
          split = '',
          tab = -1,
          unsilent = false,
          verbose = -1,
          vertical = false,
        },
      }, api.nvim_parse_cmd('echo foo', {}))
    end)
    it('works with ranges', function()
      eq({
        cmd = 'substitute',
        args = { '/math.random/math.max/' },
        bang = false,
        range = { 4, 6 },
        addr = 'line',
        magic = {
          file = false,
          bar = false,
        },
        nargs = '*',
        nextcmd = '',
        mods = {
          browse = false,
          confirm = false,
          emsg_silent = false,
          filter = {
            pattern = '',
            force = false,
          },
          hide = false,
          horizontal = false,
          keepalt = false,
          keepjumps = false,
          keepmarks = false,
          keeppatterns = false,
          lockmarks = false,
          noautocmd = false,
          noswapfile = false,
          sandbox = false,
          silent = false,
          split = '',
          tab = -1,
          unsilent = false,
          verbose = -1,
          vertical = false,
        },
      }, api.nvim_parse_cmd('4,6s/math.random/math.max/', {}))
    end)
    it('works with count', function()
      eq({
        cmd = 'buffer',
        args = {},
        bang = false,
        range = { 1 },
        count = 1,
        addr = 'buf',
        magic = {
          file = false,
          bar = true,
        },
        nargs = '*',
        nextcmd = '',
        mods = {
          browse = false,
          confirm = false,
          emsg_silent = false,
          filter = {
            pattern = '',
            force = false,
          },
          hide = false,
          horizontal = false,
          keepalt = false,
          keepjumps = false,
          keepmarks = false,
          keeppatterns = false,
          lockmarks = false,
          noautocmd = false,
          noswapfile = false,
          sandbox = false,
          silent = false,
          split = '',
          tab = -1,
          unsilent = false,
          verbose = -1,
          vertical = false,
        },
      }, api.nvim_parse_cmd('buffer 1', {}))
    end)
    it('works with register', function()
      eq({
        cmd = 'put',
        args = {},
        bang = false,
        range = {},
        reg = '+',
        addr = 'line',
        magic = {
          file = false,
          bar = true,
        },
        nargs = '0',
        nextcmd = '',
        mods = {
          browse = false,
          confirm = false,
          emsg_silent = false,
          filter = {
            pattern = '',
            force = false,
          },
          hide = false,
          horizontal = false,
          keepalt = false,
          keepjumps = false,
          keepmarks = false,
          keeppatterns = false,
          lockmarks = false,
          noautocmd = false,
          noswapfile = false,
          sandbox = false,
          silent = false,
          split = '',
          tab = -1,
          unsilent = false,
          verbose = -1,
          vertical = false,
        },
      }, api.nvim_parse_cmd('put +', {}))
      eq({
        cmd = 'put',
        args = {},
        bang = false,
        range = {},
        reg = '',
        addr = 'line',
        magic = {
          file = false,
          bar = true,
        },
        nargs = '0',
        nextcmd = '',
        mods = {
          browse = false,
          confirm = false,
          emsg_silent = false,
          filter = {
            pattern = '',
            force = false,
          },
          hide = false,
          horizontal = false,
          keepalt = false,
          keepjumps = false,
          keepmarks = false,
          keeppatterns = false,
          lockmarks = false,
          noautocmd = false,
          noswapfile = false,
          sandbox = false,
          silent = false,
          split = '',
          tab = -1,
          unsilent = false,
          verbose = -1,
          vertical = false,
        },
      }, api.nvim_parse_cmd('put', {}))
    end)
    it('works with range, count and register', function()
      eq({
        cmd = 'delete',
        args = {},
        bang = false,
        range = { 3, 7 },
        count = 7,
        reg = '*',
        addr = 'line',
        magic = {
          file = false,
          bar = true,
        },
        nargs = '0',
        nextcmd = '',
        mods = {
          browse = false,
          confirm = false,
          emsg_silent = false,
          filter = {
            pattern = '',
            force = false,
          },
          hide = false,
          horizontal = false,
          keepalt = false,
          keepjumps = false,
          keepmarks = false,
          keeppatterns = false,
          lockmarks = false,
          noautocmd = false,
          noswapfile = false,
          sandbox = false,
          silent = false,
          split = '',
          tab = -1,
          unsilent = false,
          verbose = -1,
          vertical = false,
        },
      }, api.nvim_parse_cmd('1,3delete * 5', {}))
    end)
    it('works with bang', function()
      eq({
        cmd = 'write',
        args = {},
        bang = true,
        range = {},
        addr = 'line',
        magic = {
          file = true,
          bar = true,
        },
        nargs = '?',
        nextcmd = '',
        mods = {
          browse = false,
          confirm = false,
          emsg_silent = false,
          filter = {
            pattern = '',
            force = false,
          },
          hide = false,
          horizontal = false,
          keepalt = false,
          keepjumps = false,
          keepmarks = false,
          keeppatterns = false,
          lockmarks = false,
          noautocmd = false,
          noswapfile = false,
          sandbox = false,
          silent = false,
          split = '',
          tab = -1,
          unsilent = false,
          verbose = -1,
          vertical = false,
        },
      }, api.nvim_parse_cmd('w!', {}))
    end)
    it('works with modifiers', function()
      eq(
        {
          cmd = 'split',
          args = { 'foo.txt' },
          bang = false,
          range = {},
          addr = '?',
          magic = {
            file = true,
            bar = true,
          },
          nargs = '?',
          nextcmd = '',
          mods = {
            browse = false,
            confirm = false,
            emsg_silent = true,
            filter = {
              pattern = 'foo',
              force = false,
            },
            hide = false,
            horizontal = true,
            keepalt = false,
            keepjumps = false,
            keepmarks = false,
            keeppatterns = false,
            lockmarks = false,
            noautocmd = false,
            noswapfile = false,
            sandbox = false,
            silent = true,
            split = 'topleft',
            tab = 1,
            unsilent = false,
            verbose = 15,
            vertical = false,
          },
        },
        api.nvim_parse_cmd(
          '15verbose silent! horizontal topleft tab filter /foo/ split foo.txt',
          {}
        )
      )
      eq(
        {
          cmd = 'split',
          args = { 'foo.txt' },
          bang = false,
          range = {},
          addr = '?',
          magic = {
            file = true,
            bar = true,
          },
          nargs = '?',
          nextcmd = '',
          mods = {
            browse = false,
            confirm = true,
            emsg_silent = false,
            filter = {
              pattern = 'foo',
              force = true,
            },
            hide = false,
            horizontal = false,
            keepalt = false,
            keepjumps = false,
            keepmarks = false,
            keeppatterns = false,
            lockmarks = false,
            noautocmd = false,
            noswapfile = false,
            sandbox = false,
            silent = false,
            split = 'botright',
            tab = 0,
            unsilent = true,
            verbose = 0,
            vertical = false,
          },
        },
        api.nvim_parse_cmd(
          '0verbose unsilent botright 0tab confirm filter! /foo/ split foo.txt',
          {}
        )
      )
    end)
    it('works with user commands', function()
      command('command -bang -nargs=+ -range -addr=lines MyCommand echo foo')
      eq({
        cmd = 'MyCommand',
        args = { 'test', 'it' },
        bang = true,
        range = { 4, 6 },
        addr = 'line',
        magic = {
          file = false,
          bar = false,
        },
        nargs = '+',
        nextcmd = '',
        mods = {
          browse = false,
          confirm = false,
          emsg_silent = false,
          filter = {
            pattern = '',
            force = false,
          },
          hide = false,
          horizontal = false,
          keepalt = false,
          keepjumps = false,
          keepmarks = false,
          keeppatterns = false,
          lockmarks = false,
          noautocmd = false,
          noswapfile = false,
          sandbox = false,
          silent = false,
          split = '',
          tab = -1,
          unsilent = false,
          verbose = -1,
          vertical = false,
        },
      }, api.nvim_parse_cmd('4,6MyCommand! test it', {}))
    end)
    it('works for commands separated by bar', function()
      eq({
        cmd = 'argadd',
        args = { 'a.txt' },
        bang = false,
        range = {},
        addr = 'arg',
        magic = {
          file = true,
          bar = true,
        },
        nargs = '*',
        nextcmd = 'argadd b.txt',
        mods = {
          browse = false,
          confirm = false,
          emsg_silent = false,
          filter = {
            pattern = '',
            force = false,
          },
          hide = false,
          horizontal = false,
          keepalt = false,
          keepjumps = false,
          keepmarks = false,
          keeppatterns = false,
          lockmarks = false,
          noautocmd = false,
          noswapfile = false,
          sandbox = false,
          silent = false,
          split = '',
          tab = -1,
          unsilent = false,
          verbose = -1,
          vertical = false,
        },
      }, api.nvim_parse_cmd('argadd a.txt | argadd b.txt', {}))
    end)
    it('works for nargs=1', function()
      command('command -nargs=1 MyCommand echo <q-args>')
      eq({
        cmd = 'MyCommand',
        args = { 'test it' },
        bang = false,
        addr = 'none',
        magic = {
          file = false,
          bar = false,
        },
        nargs = '1',
        nextcmd = '',
        mods = {
          browse = false,
          confirm = false,
          emsg_silent = false,
          filter = {
            pattern = '',
            force = false,
          },
          hide = false,
          horizontal = false,
          keepalt = false,
          keepjumps = false,
          keepmarks = false,
          keeppatterns = false,
          lockmarks = false,
          noautocmd = false,
          noswapfile = false,
          sandbox = false,
          silent = false,
          split = '',
          tab = -1,
          unsilent = false,
          verbose = -1,
          vertical = false,
        },
      }, api.nvim_parse_cmd('MyCommand test it', {}))
    end)
    it('validates command', function()
      eq('Error while parsing command line', pcall_err(api.nvim_parse_cmd, '', {}))
      eq('Error while parsing command line', pcall_err(api.nvim_parse_cmd, '" foo', {}))
      eq(
        'Error while parsing command line: E492: Not an editor command: Fubar',
        pcall_err(api.nvim_parse_cmd, 'Fubar', {})
      )
      command('command! Fubar echo foo')
      eq(
        'Error while parsing command line: E477: No ! allowed',
        pcall_err(api.nvim_parse_cmd, 'Fubar!', {})
      )
      eq(
        'Error while parsing command line: E481: No range allowed',
        pcall_err(api.nvim_parse_cmd, '4,6Fubar', {})
      )
      command('command! Foobar echo foo')
      eq(
        'Error while parsing command line: E464: Ambiguous use of user-defined command',
        pcall_err(api.nvim_parse_cmd, 'F', {})
      )
    end)
    it('does not interfere with printing line in Ex mode #19400', function()
      local screen = Screen.new(60, 7)
      screen:attach()
      insert([[
        foo
        bar]])
      feed('gQ1')
      screen:expect([[
        foo                                                         |
        bar                                                         |
        {1:~                                                           }|*2
        {3:                                                            }|
        Entering Ex mode.  Type "visual" to go to Normal mode.      |
        :1^                                                          |
      ]])
      eq('Error while parsing command line', pcall_err(api.nvim_parse_cmd, '', {}))
      feed('<CR>')
      screen:expect([[
        foo                                                         |
        bar                                                         |
        {3:                                                            }|
        Entering Ex mode.  Type "visual" to go to Normal mode.      |
        :1                                                          |
        foo                                                         |
        :^                                                           |
      ]])
    end)
    it('does not move cursor or change search history/pattern #19878 #19890', function()
      api.nvim_buf_set_lines(0, 0, -1, true, { 'foo', 'bar', 'foo', 'bar' })
      eq({ 1, 0 }, api.nvim_win_get_cursor(0))
      eq('', fn.getreg('/'))
      eq('', fn.histget('search'))
      feed(':') -- call the API in cmdline mode to test whether it changes search history
      eq({
        cmd = 'normal',
        args = { 'x' },
        bang = true,
        range = { 3, 4 },
        addr = 'line',
        magic = {
          file = false,
          bar = false,
        },
        nargs = '+',
        nextcmd = '',
        mods = {
          browse = false,
          confirm = false,
          emsg_silent = false,
          filter = {
            pattern = '',
            force = false,
          },
          hide = false,
          horizontal = false,
          keepalt = false,
          keepjumps = false,
          keepmarks = false,
          keeppatterns = false,
          lockmarks = false,
          noautocmd = false,
          noswapfile = false,
          sandbox = false,
          silent = false,
          split = '',
          tab = -1,
          unsilent = false,
          verbose = -1,
          vertical = false,
        },
      }, api.nvim_parse_cmd('+2;/bar/normal! x', {}))
      eq({ 1, 0 }, api.nvim_win_get_cursor(0))
      eq('', fn.getreg('/'))
      eq('', fn.histget('search'))
    end)
    it('result can be used directly by nvim_cmd #20051', function()
      eq('foo', api.nvim_cmd(api.nvim_parse_cmd('echo "foo"', {}), { output = true }))
      api.nvim_cmd(api.nvim_parse_cmd('set cursorline', {}), {})
      eq(true, api.nvim_get_option_value('cursorline', {}))
    end)
    it('no side-effects (error messages) in pcall() #20339', function()
      eq(
        { false, 'Error while parsing command line: E16: Invalid range' },
        exec_lua([=[return {pcall(vim.api.nvim_parse_cmd, "'<,'>n", {})}]=])
      )
      eq('', eval('v:errmsg'))
    end)
  end)

  describe('nvim_cmd', function()
    it('works', function()
      api.nvim_cmd({ cmd = 'set', args = { 'cursorline' } }, {})
      eq(true, api.nvim_get_option_value('cursorline', {}))
    end)

    it('validation', function()
      eq("Invalid 'cmd': expected non-empty String", pcall_err(api.nvim_cmd, { cmd = '' }, {}))
      eq("Invalid 'cmd': expected String, got Array", pcall_err(api.nvim_cmd, { cmd = {} }, {}))
      eq(
        "Invalid 'args': expected Array, got Boolean",
        pcall_err(api.nvim_cmd, { cmd = 'set', args = true }, {})
      )
      eq(
        'Invalid command arg: expected non-whitespace',
        pcall_err(api.nvim_cmd, { cmd = 'set', args = { '  ' } }, {})
      )
      eq(
        'Invalid command arg: expected valid type, got Array',
        pcall_err(api.nvim_cmd, { cmd = 'set', args = { {} } }, {})
      )
      eq('Wrong number of arguments', pcall_err(api.nvim_cmd, { cmd = 'aboveleft', args = {} }, {}))
      eq(
        'Command cannot accept bang: print',
        pcall_err(api.nvim_cmd, { cmd = 'print', args = {}, bang = true }, {})
      )

      eq(
        'Command cannot accept range: set',
        pcall_err(api.nvim_cmd, { cmd = 'set', args = {}, range = { 1 } }, {})
      )
      eq(
        "Invalid 'range': expected Array, got Boolean",
        pcall_err(api.nvim_cmd, { cmd = 'print', args = {}, range = true }, {})
      )
      eq(
        "Invalid 'range': expected <=2 elements",
        pcall_err(api.nvim_cmd, { cmd = 'print', args = {}, range = { 1, 2, 3, 4 } }, {})
      )
      eq(
        'Invalid range element: expected non-negative Integer',
        pcall_err(api.nvim_cmd, { cmd = 'print', args = {}, range = { -1 } }, {})
      )

      eq(
        'Command cannot accept count: set',
        pcall_err(api.nvim_cmd, { cmd = 'set', args = {}, count = 1 }, {})
      )
      eq(
        "Invalid 'count': expected Integer, got Boolean",
        pcall_err(api.nvim_cmd, { cmd = 'print', args = {}, count = true }, {})
      )
      eq(
        "Invalid 'count': expected non-negative Integer",
        pcall_err(api.nvim_cmd, { cmd = 'print', args = {}, count = -1 }, {})
      )

      eq(
        'Command cannot accept register: set',
        pcall_err(api.nvim_cmd, { cmd = 'set', args = {}, reg = 'x' }, {})
      )
      eq(
        'Cannot use register "=',
        pcall_err(api.nvim_cmd, { cmd = 'put', args = {}, reg = '=' }, {})
      )
      eq(
        "Invalid 'reg': expected single character, got xx",
        pcall_err(api.nvim_cmd, { cmd = 'put', args = {}, reg = 'xx' }, {})
      )

      -- #20681
      eq('Invalid command: "win_getid"', pcall_err(api.nvim_cmd, { cmd = 'win_getid' }, {}))
      eq('Invalid command: "echo "hi""', pcall_err(api.nvim_cmd, { cmd = 'echo "hi"' }, {}))
      eq('Invalid command: "win_getid"', pcall_err(exec_lua, [[return vim.cmd.win_getid{}]]))

      -- Lua call allows empty {} for dict item.
      eq('', exec_lua([[return vim.cmd{ cmd = "set", args = {}, magic = {} }]]))
      eq('', exec_lua([[return vim.cmd{ cmd = "set", args = {}, mods = {} }]]))
      eq('', api.nvim_cmd({ cmd = 'set', args = {}, magic = {} }, {}))

      -- Lua call does not allow non-empty list-like {} for dict item.
      eq(
        "Invalid 'magic': Expected Dict-like Lua table",
        pcall_err(exec_lua, [[return vim.cmd{ cmd = "set", args = {}, magic = { 'a' } }]])
      )
      eq(
        "Invalid key: 'bogus'",
        pcall_err(exec_lua, [[return vim.cmd{ cmd = "set", args = {}, magic = { bogus = true } }]])
      )
      eq(
        "Invalid key: 'bogus'",
        pcall_err(exec_lua, [[return vim.cmd{ cmd = "set", args = {}, mods = { bogus = true } }]])
      )
    end)

    it('captures output', function()
      eq('foo', api.nvim_cmd({ cmd = 'echo', args = { '"foo"' } }, { output = true }))
    end)

    it('sets correct script context', function()
      api.nvim_cmd({ cmd = 'set', args = { 'cursorline' } }, {})
      local str = exec_capture([[verbose set cursorline?]])
      neq(nil, str:find('cursorline\n\tLast set from API client %(channel id %d+%)'))
    end)

    it('works with range', function()
      insert [[
        line1
        line2
        line3
        line4
        you didn't expect this
        line5
        line6
      ]]
      api.nvim_cmd({ cmd = 'del', range = { 2, 4 } }, {})
      expect [[
        line1
        you didn't expect this
        line5
        line6
      ]]
    end)

    it('works with count', function()
      insert [[
        line1
        line2
        line3
        line4
        you didn't expect this
        line5
        line6
      ]]
      api.nvim_cmd({ cmd = 'del', range = { 2 }, count = 4 }, {})
      expect [[
        line1
        line5
        line6
      ]]
    end)

    it('works with register', function()
      insert [[
        line1
        line2
        line3
        line4
        you didn't expect this
        line5
        line6
      ]]
      api.nvim_cmd({ cmd = 'del', range = { 2, 4 }, reg = 'a' }, {})
      command('1put a')
      expect [[
        line1
        line2
        line3
        line4
        you didn't expect this
        line5
        line6
      ]]
    end)

    it('works with bang', function()
      api.nvim_create_user_command('Foo', 'echo "<bang>"', { bang = true })
      eq('!', api.nvim_cmd({ cmd = 'Foo', bang = true }, { output = true }))
      eq('', api.nvim_cmd({ cmd = 'Foo', bang = false }, { output = true }))
    end)

    it('works with modifiers', function()
      -- with silent = true output is still captured
      eq(
        '1',
        api.nvim_cmd(
          { cmd = 'echomsg', args = { '1' }, mods = { silent = true } },
          { output = true }
        )
      )
      -- but message isn't added to message history
      eq('', api.nvim_cmd({ cmd = 'messages' }, { output = true }))

      api.nvim_create_user_command('Foo', 'set verbose', {})
      eq('  verbose=1', api.nvim_cmd({ cmd = 'Foo', mods = { verbose = 1 } }, { output = true }))

      api.nvim_create_user_command('Mods', "echo '<mods>'", {})
      eq(
        'keepmarks keeppatterns silent 3verbose aboveleft horizontal',
        api.nvim_cmd({
          cmd = 'Mods',
          mods = {
            horizontal = true,
            keepmarks = true,
            keeppatterns = true,
            silent = true,
            split = 'aboveleft',
            verbose = 3,
          },
        }, { output = true })
      )
      eq(0, api.nvim_get_option_value('verbose', {}))

      command('edit foo.txt | edit bar.txt')
      eq(
        '  1 #h   "foo.txt"                      line 1',
        api.nvim_cmd(
          { cmd = 'buffers', mods = { filter = { pattern = 'foo', force = false } } },
          { output = true }
        )
      )
      eq(
        '  2 %a   "bar.txt"                      line 1',
        api.nvim_cmd(
          { cmd = 'buffers', mods = { filter = { pattern = 'foo', force = true } } },
          { output = true }
        )
      )

      -- with emsg_silent = true error is suppressed
      feed([[:lua vim.api.nvim_cmd({ cmd = 'call', mods = { emsg_silent = true } }, {})<CR>]])
      eq('', api.nvim_cmd({ cmd = 'messages' }, { output = true }))
      -- error from the next command typed is not suppressed #21420
      feed(':call<CR><CR>')
      eq('E471: Argument required', api.nvim_cmd({ cmd = 'messages' }, { output = true }))
    end)

    it('works with magic.file', function()
      exec_lua([[
        vim.api.nvim_create_user_command("Foo", function(opts)
          vim.api.nvim_echo({{ opts.fargs[1] }}, false, {})
        end, { nargs = 1 })
      ]])
      eq(
        uv.cwd(),
        api.nvim_cmd(
          { cmd = 'Foo', args = { '%:p:h' }, magic = { file = true } },
          { output = true }
        )
      )
    end)

    it('splits arguments correctly', function()
      exec([[
        function! FooFunc(...)
          echo a:000
        endfunction
      ]])
      api.nvim_create_user_command('Foo', 'call FooFunc(<f-args>)', { nargs = '+' })
      eq(
        [=[['a quick', 'brown fox', 'jumps over the', 'lazy dog']]=],
        api.nvim_cmd(
          { cmd = 'Foo', args = { 'a quick', 'brown fox', 'jumps over the', 'lazy dog' } },
          { output = true }
        )
      )
      eq(
        [=[['test \ \\ \"""\', 'more\ tests\"  ']]=],
        api.nvim_cmd(
          { cmd = 'Foo', args = { [[test \ \\ \"""\]], [[more\ tests\"  ]] } },
          { output = true }
        )
      )
    end)

    it('splits arguments correctly for Lua callback', function()
      api.nvim_exec_lua(
        [[
        local function FooFunc(opts)
          vim.print(opts.fargs)
        end

        vim.api.nvim_create_user_command("Foo", FooFunc, { nargs = '+' })
      ]],
        {}
      )
      eq(
        [[{ "a quick", "brown fox", "jumps over the", "lazy dog" }]],
        api.nvim_cmd(
          { cmd = 'Foo', args = { 'a quick', 'brown fox', 'jumps over the', 'lazy dog' } },
          { output = true }
        )
      )
      eq(
        [[{ 'test \\ \\\\ \\"""\\', 'more\\ tests\\"  ' }]],
        api.nvim_cmd(
          { cmd = 'Foo', args = { [[test \ \\ \"""\]], [[more\ tests\"  ]] } },
          { output = true }
        )
      )
    end)

    it('works with buffer names', function()
      command('edit foo.txt | edit bar.txt')
      api.nvim_cmd({ cmd = 'buffer', args = { 'foo.txt' } }, {})
      eq('foo.txt', fn.fnamemodify(api.nvim_buf_get_name(0), ':t'))
      api.nvim_cmd({ cmd = 'buffer', args = { 'bar.txt' } }, {})
      eq('bar.txt', fn.fnamemodify(api.nvim_buf_get_name(0), ':t'))
    end)

    it('triggers CmdUndefined event if command is not found', function()
      api.nvim_exec_lua(
        [[
        vim.api.nvim_create_autocmd("CmdUndefined",
                                    { pattern = "Foo",
                                      callback = function()
                                        vim.api.nvim_create_user_command("Foo", "echo 'foo'", {})
                                      end
                                    })
      ]],
        {}
      )
      eq('foo', api.nvim_cmd({ cmd = 'Foo' }, { output = true }))
    end)

    it('errors if command is not implemented', function()
      eq('Command not implemented: winpos', pcall_err(api.nvim_cmd, { cmd = 'winpos' }, {}))
    end)

    it('works with empty arguments list', function()
      api.nvim_cmd({ cmd = 'update' }, {})
      api.nvim_cmd({ cmd = 'buffer', count = 0 }, {})
    end)

    it("doesn't suppress errors when used in keymapping", function()
      api.nvim_exec_lua(
        [[
        vim.keymap.set("n", "[l",
                       function() vim.api.nvim_cmd({ cmd = "echo", args = {"foo"} }, {}) end)
      ]],
        {}
      )
      feed('[l')
      neq(nil, string.find(eval('v:errmsg'), 'E5108:'))
    end)

    it('handles 0 range #19608', function()
      api.nvim_buf_set_lines(0, 0, -1, false, { 'aa' })
      api.nvim_cmd({ cmd = 'delete', range = { 0 } }, {})
      command('undo')
      eq({ 'aa' }, api.nvim_buf_get_lines(0, 0, 1, false))
      assert_alive()
    end)

    it('supports filename expansion', function()
      api.nvim_cmd({ cmd = 'argadd', args = { '%:p:h:t', '%:p:h:t' } }, {})
      local arg = fn.expand('%:p:h:t')
      eq({ arg, arg }, fn.argv())
    end)

    it(":make command works when argument count isn't 1 #19696", function()
      command('set makeprg=echo')
      command('set shellquote=')
      matches('^:!echo ', api.nvim_cmd({ cmd = 'make' }, { output = true }))
      assert_alive()
      matches(
        '^:!echo foo bar',
        api.nvim_cmd({ cmd = 'make', args = { 'foo', 'bar' } }, { output = true })
      )
      assert_alive()
      local arg_pesc = pesc(fn.expand('%:p:h:t'))
      matches(
        ('^:!echo %s %s'):format(arg_pesc, arg_pesc),
        api.nvim_cmd({ cmd = 'make', args = { '%:p:h:t', '%:p:h:t' } }, { output = true })
      )
      assert_alive()
    end)

    it("doesn't display messages when output=true", function()
      local screen = Screen.new(40, 6)
      screen:attach()
      api.nvim_cmd({ cmd = 'echo', args = { [['hello']] } }, { output = true })
      screen:expect {
        grid = [[
        ^                                        |
        {1:~                                       }|*4
                                                |
      ]],
      }
      exec([[
        func Print()
          call nvim_cmd(#{cmd: 'echo', args: ['"hello"']}, #{output: v:true})
        endfunc
      ]])
      feed([[:echon 1 | call Print() | echon 5<CR>]])
      screen:expect {
        grid = [[
        ^                                        |
        {1:~                                       }|*4
        15                                      |
      ]],
      }
    end)

    it('works with non-String args', function()
      eq('2', api.nvim_cmd({ cmd = 'echo', args = { 2 } }, { output = true }))
      eq('1', api.nvim_cmd({ cmd = 'echo', args = { true } }, { output = true }))
    end)

    describe('first argument as count', function()
      it('works', function()
        command('vsplit | enew')
        api.nvim_cmd({ cmd = 'bdelete', args = { api.nvim_get_current_buf() } }, {})
        eq(1, api.nvim_get_current_buf())
      end)

      it('works with :sleep using milliseconds', function()
        local start = uv.now()
        api.nvim_cmd({ cmd = 'sleep', args = { '100m' } }, {})
        ok(uv.now() - start <= 300)
      end)
    end)

    it(':call with unknown function does not crash #26289', function()
      eq(
        'Vim:E117: Unknown function: UnknownFunc',
        pcall_err(api.nvim_cmd, { cmd = 'call', args = { 'UnknownFunc()' } }, {})
      )
    end)

    it(':throw does not crash #24556', function()
      eq('42', pcall_err(api.nvim_cmd, { cmd = 'throw', args = { '42' } }, {}))
    end)

    it('can use :return #24556', function()
      exec([[
        func Foo()
          let g:pos = 'before'
          call nvim_cmd({'cmd': 'return', 'args': ['[1, 2, 3]']}, {})
          let g:pos = 'after'
        endfunc
        let g:result = Foo()
      ]])
      eq('before', api.nvim_get_var('pos'))
      eq({ 1, 2, 3 }, api.nvim_get_var('result'))
    end)

    it('errors properly when command too recursive #27210', function()
      exec_lua([[
        _G.success = false
        vim.api.nvim_create_user_command('Test', function()
          vim.api.nvim_cmd({ cmd = 'Test' }, {})
          _G.success = true
        end, {})
      ]])
      pcall_err(command, 'Test')
      assert_alive()
      eq(false, exec_lua('return _G.success'))
    end)
  end)

  it('nvim__redraw', function()
    local screen = Screen.new(60, 5)
    screen:attach()
    local win = api.nvim_get_current_win()
    eq('at least one action required', pcall_err(api.nvim__redraw, {}))
    eq('at least one action required', pcall_err(api.nvim__redraw, { buf = 0 }))
    eq('at least one action required', pcall_err(api.nvim__redraw, { win = 0 }))
    eq("cannot use both 'buf' and 'win'", pcall_err(api.nvim__redraw, { buf = 0, win = 0 }))
    feed(':echo getchar()<CR>')
    fn.setline(1, 'foobar')
    command('vnew')
    fn.setline(1, 'foobaz')
    -- Can flush pending screen updates
    api.nvim__redraw({ flush = true })
    screen:expect({
      grid = [[
        foobaz                        │foobar                       |
        {1:~                             }│{1:~                            }|*2
        {3:[No Name] [+]                  }{2:[No Name] [+]                }|
        ^:echo getchar()                                             |
      ]],
    })
    -- Can update the grid cursor position #20793
    api.nvim__redraw({ cursor = true })
    screen:expect({
      grid = [[
        ^foobaz                        │foobar                       |
        {1:~                             }│{1:~                            }|*2
        {3:[No Name] [+]                  }{2:[No Name] [+]                }|
        :echo getchar()                                             |
      ]],
    })
    -- Also in non-current window
    api.nvim__redraw({ cursor = true, win = win })
    screen:expect({
      grid = [[
        foobaz                        │^foobar                       |
        {1:~                             }│{1:~                            }|*2
        {3:[No Name] [+]                  }{2:[No Name] [+]                }|
        :echo getchar()                                             |
      ]],
    })
    -- Can update the 'statusline' in a single window
    api.nvim_set_option_value('statusline', 'statusline1', { win = 0 })
    api.nvim_set_option_value('statusline', 'statusline2', { win = win })
    api.nvim__redraw({ cursor = true, win = 0, statusline = true })
    screen:expect({
      grid = [[
        ^foobaz                        │foobar                       |
        {1:~                             }│{1:~                            }|*2
        {3:statusline1                    }{2:[No Name] [+]                }|
        :echo getchar()                                             |
      ]],
    })
    api.nvim__redraw({ win = win, statusline = true })
    screen:expect({
      grid = [[
        ^foobaz                        │foobar                       |
        {1:~                             }│{1:~                            }|*2
        {3:statusline1                    }{2:statusline2                  }|
        :echo getchar()                                             |
      ]],
    })
    -- Can update the 'statusline' in all windows
    api.nvim_set_option_value('statusline', '', { win = win })
    api.nvim_set_option_value('statusline', 'statusline3', {})
    api.nvim__redraw({ statusline = true })
    screen:expect({
      grid = [[
        ^foobaz                        │foobar                       |
        {1:~                             }│{1:~                            }|*2
        {3:statusline3                    }{2:statusline3                  }|
        :echo getchar()                                             |
      ]],
    })
    -- Can update the 'statuscolumn'
    api.nvim_set_option_value('statuscolumn', 'statuscolumn', { win = win })
    api.nvim__redraw({ statuscolumn = true })
    screen:expect({
      grid = [[
        ^foobaz                        │{8:statuscolumn}foobar           |
        {1:~                             }│{1:~                            }|*2
        {3:statusline3                    }{2:statusline3                  }|
        :echo getchar()                                             |
      ]],
    })
    -- Can update the 'winbar'
    api.nvim_set_option_value('winbar', 'winbar', { win = 0 })
    api.nvim__redraw({ win = 0, winbar = true })
    screen:expect({
      grid = [[
        {5:^winbar                        }│{8:statuscolumn}foobar           |
        foobaz                        │{1:~                            }|
        {1:~                             }│{1:~                            }|
        {3:statusline3                    }{2:statusline3                  }|
        :echo getchar()                                             |
      ]],
    })
    -- Can update the 'tabline'
    api.nvim_set_option_value('showtabline', 2, {})
    api.nvim_set_option_value('tabline', 'tabline', {})
    api.nvim__redraw({ tabline = true })
    screen:expect({
      grid = [[
        {2:^tabline                                                     }|
        {5:winbar                        }│{8:statuscolumn}foobar           |
        foobaz                        │{1:~                            }|
        {3:statusline3                    }{2:statusline3                  }|
        :echo getchar()                                             |
      ]],
    })
    -- Can update multiple status widgets
    api.nvim_set_option_value('tabline', 'tabline2', {})
    api.nvim_set_option_value('statusline', 'statusline4', {})
    api.nvim__redraw({ statusline = true, tabline = true })
    screen:expect({
      grid = [[
        {2:^tabline2                                                    }|
        {5:winbar                        }│{8:statuscolumn}foobar           |
        foobaz                        │{1:~                            }|
        {3:statusline4                    }{2:statusline4                  }|
        :echo getchar()                                             |
      ]],
    })
    -- Can update all status widgets
    api.nvim_set_option_value('tabline', 'tabline3', {})
    api.nvim_set_option_value('statusline', 'statusline5', {})
    api.nvim_set_option_value('statuscolumn', 'statuscolumn2', {})
    api.nvim_set_option_value('winbar', 'winbar2', {})
    api.nvim__redraw({ statuscolumn = true, statusline = true, tabline = true, winbar = true })
    screen:expect({
      grid = [[
        {2:^tabline3                                                    }|
        {5:winbar2                       }│{5:winbar2                      }|
        {8:statuscolumn2}foobaz           │{8:statuscolumn}foobar           |
        {3:statusline5                    }{2:statusline5                  }|
        :echo getchar()                                             |
      ]],
    })
    -- Can update status widget for a specific window
    feed('<CR><CR>')
    command('let g:status=0')
    api.nvim_set_option_value('statusline', '%{%g:status%}', { win = 0 })
    command('vsplit')
    screen:expect({
      grid = [[
        {2:tabline3                                                    }|
        {5:winbar2             }│{5:winbar2            }│{5:winbar2            }|
        {8:statuscolumn2}^foobaz │{8:statuscolumn2}foobaz│{8:statuscolumn}foobar |
        {3:0                    }{2:0                   statusline5        }|
        13                                                          |
      ]],
    })
    command('let g:status=1')
    api.nvim__redraw({ win = 0, statusline = true })
    screen:expect({
      grid = [[
        {2:tabline3                                                    }|
        {5:winbar2             }│{5:winbar2            }│{5:winbar2            }|
        {8:statuscolumn2}^foobaz │{8:statuscolumn2}foobaz│{8:statuscolumn}foobar |
        {3:1                    }{2:0                   statusline5        }|
        13                                                          |
      ]],
    })
    -- Can update status widget for a specific buffer
    command('let g:status=2')
    api.nvim__redraw({ buf = 0, statusline = true })
    screen:expect({
      grid = [[
        {2:tabline3                                                    }|
        {5:winbar2             }│{5:winbar2            }│{5:winbar2            }|
        {8:statuscolumn2}^foobaz │{8:statuscolumn2}foobaz│{8:statuscolumn}foobar |
        {3:2                    }{2:2                   statusline5        }|
        13                                                          |
      ]],
    })
    -- valid = true does not draw any lines on its own
    exec_lua([[
      _G.lines = 0
      ns = vim.api.nvim_create_namespace('')
      vim.api.nvim_set_decoration_provider(ns, {
        on_win = function()
          if _G.do_win then
            vim.api.nvim_buf_set_extmark(0, ns, 0, 0, { hl_group = 'IncSearch', end_col = 6 })
          end
        end,
        on_line = function()
          _G.lines = _G.lines + 1
        end,
      })
    ]])
    local lines = exec_lua('return lines')
    api.nvim__redraw({ buf = 0, valid = true, flush = true })
    eq(lines, exec_lua('return _G.lines'))
    -- valid = false does
    api.nvim__redraw({ buf = 0, valid = false, flush = true })
    neq(lines, exec_lua('return _G.lines'))
    -- valid = true does redraw lines if affected by on_win callback
    exec_lua('_G.do_win = true')
    api.nvim__redraw({ buf = 0, valid = true, flush = true })
    screen:expect({
      grid = [[
        {2:tabline3                                                    }|
        {5:winbar2             }│{5:winbar2            }│{5:winbar2            }|
        {8:statuscolumn2}{2:^foobaz} │{8:statuscolumn2}{2:foobaz}│{8:statuscolumn}foobar |
        {3:2                    }{2:2                   statusline5        }|
        13                                                          |
      ]],
    })
    -- takes buffer line count from correct buffer with "win" and {0, -1} "range"
    api.nvim__redraw({ win = 0, range = { 0, -1 } })
    n.assert_alive()
  end)
end)
