local helpers = require('test.functional.helpers')
local clear, nvim, source = helpers.clear, helpers.nvim, helpers.source
local eq, next_msg = helpers.eq, helpers.next_message
local exc_exec = helpers.exc_exec


describe('dictionary change notifications', function()
  local channel

  setup(function()
    clear()
    channel = nvim('get_api_info')[1]
    nvim('set_var', 'channel', channel)
  end)

  -- the same set of tests are applied to top-level dictionaries(g:, b:, w: and
  -- t:) and a dictionary variable, so we generate them in the following
  -- function.
  local function gentests(dict_expr, dict_expr_suffix, dict_init)
    if not dict_expr_suffix then
      dict_expr_suffix = ''
    end

    local function update(opval, key)
      if not key then
        key = 'watched'
      end
      if opval == '' then
        nvim('command', "unlet "..dict_expr..dict_expr_suffix..key)
      else
        nvim('command', "let "..dict_expr..dict_expr_suffix..key.." "..opval)
      end
    end

    local function verify_echo()
      -- helper to verify that no notifications are sent after certain change
      -- to a dict
      nvim('command', "call rpcnotify(g:channel, 'echo')")
      eq({'notification', 'echo', {}}, next_msg())
    end

    local function verify_value(vals, key)
      if not key then
        key = 'watched'
      end
      eq({'notification', 'values', {key, vals}}, next_msg())
    end

    describe('watcher', function()
      if dict_init then
        setup(function()
          source(dict_init)
        end)
      end

      before_each(function()
        source([[
        function! g:Changed(dict, key, value)
          if a:dict != ]]..dict_expr..[[ |
            throw 'invalid dict'
          endif
          call rpcnotify(g:channel, 'values', a:key, a:value)
        endfunction
        call dictwatcheradd(]]..dict_expr..[[, "watched", "g:Changed")
        call dictwatcheradd(]]..dict_expr..[[, "watched2", "g:Changed")
        ]])
      end)

      after_each(function()
        source([[
        call dictwatcherdel(]]..dict_expr..[[, "watched", "g:Changed")
        call dictwatcherdel(]]..dict_expr..[[, "watched2", "g:Changed")
        ]])
        update('= "test"')
        update('= "test2"', 'watched2')
        update('', 'watched2')
        update('')
        verify_echo()
      end)

      it('is not triggered when unwatched keys are updated', function()
        update('= "noop"', 'unwatched')
        update('.= "noop2"', 'unwatched')
        update('', 'unwatched')
        verify_echo()
      end)

      it('is triggered by remove()', function()
        update('= "test"')
        verify_value({new = 'test'})
        nvim('command', 'call remove('..dict_expr..', "watched")')
        verify_value({old = 'test'})
      end)

      it('is triggered by extend()', function()
        update('= "xtend"')
        verify_value({new = 'xtend'})
        nvim('command', [[
          call extend(]]..dict_expr..[[, {'watched': 'xtend2', 'watched2': 5, 'watched3': 'a'})
        ]])
        verify_value({old = 'xtend', new = 'xtend2'})
        verify_value({new = 5}, 'watched2')
        update('')
        verify_value({old = 'xtend2'})
        update('', 'watched2')
        verify_value({old = 5}, 'watched2')
        update('', 'watched3')
        verify_echo()
      end)

      it('is triggered with key patterns', function()
        source([[
        call dictwatcheradd(]]..dict_expr..[[, "wat*", "g:Changed")
        ]])
        update('= 1')
        verify_value({new = 1})
        verify_value({new = 1})
        update('= 3', 'watched2')
        verify_value({new = 3}, 'watched2')
        verify_value({new = 3}, 'watched2')
        verify_echo()
        source([[
        call dictwatcherdel(]]..dict_expr..[[, "wat*", "g:Changed")
        ]])
        -- watch every key pattern
        source([[
        call dictwatcheradd(]]..dict_expr..[[, "*", "g:Changed")
        ]])
        update('= 3', 'another_key')
        update('= 4', 'another_key')
        update('', 'another_key')
        update('= 2')
        verify_value({new = 3}, 'another_key')
        verify_value({old = 3, new = 4}, 'another_key')
        verify_value({old = 4}, 'another_key')
        verify_value({old = 1, new = 2})
        verify_value({old = 1, new = 2})
        verify_echo()
        source([[
        call dictwatcherdel(]]..dict_expr..[[, "*", "g:Changed")
        ]])
      end)

      -- test a sequence of updates of different types to ensure proper memory
      -- management(with ASAN)
      local function test_updates(tests)
        it('test change sequence', function()
          local input, output
          for i = 1, #tests do
            input, output = unpack(tests[i])
            update(input)
            verify_value(output)
          end
        end)
      end

      test_updates({
        {'= 3', {new = 3}},
        {'= 6', {old = 3, new = 6}},
        {'+= 3', {old = 6, new = 9}},
        {'', {old = 9}}
      })

      test_updates({
        {'= "str"', {new = 'str'}},
        {'= "str2"', {old = 'str', new = 'str2'}},
        {'.= "2str"', {old = 'str2', new = 'str22str'}},
        {'', {old = 'str22str'}}
      })

      test_updates({
        {'= [1, 2]', {new = {1, 2}}},
        {'= [1, 2, 3]', {old = {1, 2}, new = {1, 2, 3}}},
        -- the += will update the list in place, so old and new are the same
        {'+= [4, 5]', {old = {1, 2, 3, 4, 5}, new = {1, 2, 3, 4, 5}}},
        {'', {old = {1, 2, 3, 4 ,5}}}
      })

      test_updates({
        {'= {"k": "v"}', {new = {k = 'v'}}},
        {'= {"k1": 2}', {old = {k = 'v'}, new = {k1 = 2}}},
        {'', {old = {k1 = 2}}},
      })
    end)
  end

  gentests('g:')
  gentests('b:')
  gentests('w:')
  gentests('t:')
  gentests('g:dict_var', '.', 'let g:dict_var = {}')

  describe('multiple watchers on the same dict/key', function()
    setup(function()
      source([[
      function! g:Watcher1(dict, key, value)
        call rpcnotify(g:channel, '1', a:key, a:value)
      endfunction
      function! g:Watcher2(dict, key, value)
        call rpcnotify(g:channel, '2', a:key, a:value)
      endfunction
      call dictwatcheradd(g:, "key", "g:Watcher1")
      call dictwatcheradd(g:, "key", "g:Watcher2")
      ]])
    end)

    it('invokes all callbacks when the key is changed', function()
      nvim('command', 'let g:key = "value"')
      eq({'notification', '1', {'key', {new = 'value'}}}, next_msg())
      eq({'notification', '2', {'key', {new = 'value'}}}, next_msg())
    end)

    it('only removes watchers that fully match dict, key and callback', function()
      nvim('command', 'call dictwatcherdel(g:, "key", "g:Watcher1")')
      nvim('command', 'let g:key = "v2"')
      eq({'notification', '2', {'key', {old = 'value', new = 'v2'}}}, next_msg())
    end)
  end)

  describe('errors', function()
    -- WARNING: This suite depends on the above tests
    it('fails to remove if no watcher with matching callback is found', function()
      eq("Vim(call):Couldn't find a watcher matching key and callback",
        exc_exec('call dictwatcherdel(g:, "key", "g:Watcher1")'))
    end)

    it('fails to remove if no watcher with matching key is found', function()
      eq("Vim(call):Couldn't find a watcher matching key and callback",
        exc_exec('call dictwatcherdel(g:, "invalid_key", "g:Watcher2")'))
    end)

    it("fails to add/remove if the callback doesn't exist", function()
      eq("Vim(call):Function g:InvalidCb doesn't exist",
        exc_exec('call dictwatcheradd(g:, "key", "g:InvalidCb")'))
      eq("Vim(call):Function g:InvalidCb doesn't exist",
        exc_exec('call dictwatcherdel(g:, "key", "g:InvalidCb")'))
    end)

    it('fails with empty keys', function()
      eq("Vim(call):E713: Cannot use empty key for Dictionary",
        exc_exec('call dictwatcheradd(g:, "", "g:Watcher1")'))
      eq("Vim(call):E713: Cannot use empty key for Dictionary",
        exc_exec('call dictwatcherdel(g:, "", "g:Watcher1")'))
    end)

    it('fails to replace a watcher function', function()
      source([[
      function! g:ReplaceWatcher2()
        function! g:Watcher2()
        endfunction
      endfunction
      ]])
      eq("Vim(function):E127: Cannot redefine function Watcher2: It is in use",
        exc_exec('call g:ReplaceWatcher2()'))
    end)
  end)
end)
