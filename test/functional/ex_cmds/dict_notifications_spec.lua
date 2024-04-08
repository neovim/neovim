local t = require('test.functional.testutil')(after_each)
local assert_alive = t.assert_alive
local clear, source = t.clear, t.source
local api = t.api
local insert = t.insert
local eq, next_msg = t.eq, t.next_msg
local exc_exec = t.exc_exec
local exec_lua = t.exec_lua
local command = t.command
local eval = t.eval

describe('Vimscript dictionary notifications', function()
  local channel

  before_each(function()
    clear()
    channel = api.nvim_get_chan_info(0).id
    api.nvim_set_var('channel', channel)
  end)

  -- the same set of tests are applied to top-level dictionaries(g:, b:, w: and
  -- t:) and a dictionary variable, so we generate them in the following
  -- function.
  local function gentests(dict_expr, dict_init)
    local is_g = dict_expr == 'g:'

    local function update(opval, key)
      if not key then
        key = 'watched'
      end
      if opval == '' then
        command(("unlet %s['%s']"):format(dict_expr, key))
      else
        command(("let %s['%s'] %s"):format(dict_expr, key, opval))
      end
    end

    local function update_with_api(opval, key)
      if not key then
        key = 'watched'
      end
      if opval == '' then
        exec_lua(("vim.api.nvim_del_var('%s')"):format(key))
      else
        exec_lua(("vim.api.nvim_set_var('%s', %s)"):format(key, opval))
      end
    end

    local function update_with_vim_g(opval, key)
      if not key then
        key = 'watched'
      end
      if opval == '' then
        exec_lua(('vim.g.%s = nil'):format(key))
      else
        exec_lua(('vim.g.%s %s'):format(key, opval))
      end
    end

    local function verify_echo()
      -- helper to verify that no notifications are sent after certain change
      -- to a dict
      command("call rpcnotify(g:channel, 'echo')")
      eq({ 'notification', 'echo', {} }, next_msg())
    end

    local function verify_value(vals, key)
      if not key then
        key = 'watched'
      end
      eq({ 'notification', 'values', { key, vals } }, next_msg())
    end

    describe(dict_expr .. ' watcher', function()
      if dict_init then
        before_each(function()
          source(dict_init)
        end)
      end

      before_each(function()
        source([[
        function! g:Changed(dict, key, value)
          if a:dict isnot ]] .. dict_expr .. [[ |
            throw 'invalid dict'
          endif
          call rpcnotify(g:channel, 'values', a:key, a:value)
        endfunction
        call dictwatcheradd(]] .. dict_expr .. [[, "watched", "g:Changed")
        call dictwatcheradd(]] .. dict_expr .. [[, "watched2", "g:Changed")
        ]])
      end)

      after_each(function()
        source([[
        call dictwatcherdel(]] .. dict_expr .. [[, "watched", "g:Changed")
        call dictwatcherdel(]] .. dict_expr .. [[, "watched2", "g:Changed")
        ]])
        update('= "test"')
        update('= "test2"', 'watched2')
        update('', 'watched2')
        update('')
        verify_echo()
        if is_g then
          update_with_api('"test"')
          update_with_api('"test2"', 'watched2')
          update_with_api('', 'watched2')
          update_with_api('')
          verify_echo()
          update_with_vim_g('= "test"')
          update_with_vim_g('= "test2"', 'watched2')
          update_with_vim_g('', 'watched2')
          update_with_vim_g('')
          verify_echo()
        end
      end)

      it('is not triggered when unwatched keys are updated', function()
        update('= "noop"', 'unwatched')
        update('.= "noop2"', 'unwatched')
        update('', 'unwatched')
        verify_echo()
        if is_g then
          update_with_api('"noop"', 'unwatched')
          update_with_api('vim.g.unwatched .. "noop2"', 'unwatched')
          update_with_api('', 'unwatched')
          verify_echo()
          update_with_vim_g('= "noop"', 'unwatched')
          update_with_vim_g('= vim.g.unwatched .. "noop2"', 'unwatched')
          update_with_vim_g('', 'unwatched')
          verify_echo()
        end
      end)

      it('is triggered by remove()', function()
        update('= "test"')
        verify_value({ new = 'test' })
        command('call remove(' .. dict_expr .. ', "watched")')
        verify_value({ old = 'test' })
      end)

      if is_g then
        it('is triggered by remove() when updated with nvim_*_var', function()
          update_with_api('"test"')
          verify_value({ new = 'test' })
          command('call remove(' .. dict_expr .. ', "watched")')
          verify_value({ old = 'test' })
        end)

        it('is triggered by remove() when updated with vim.g', function()
          update_with_vim_g('= "test"')
          verify_value({ new = 'test' })
          command('call remove(' .. dict_expr .. ', "watched")')
          verify_value({ old = 'test' })
        end)
      end

      it('is triggered by extend()', function()
        update('= "xtend"')
        verify_value({ new = 'xtend' })
        command([[
          call extend(]] .. dict_expr .. [[, {'watched': 'xtend2', 'watched2': 5, 'watched3': 'a'})
        ]])
        verify_value({ old = 'xtend', new = 'xtend2' })
        verify_value({ new = 5 }, 'watched2')
        update('')
        verify_value({ old = 'xtend2' })
        update('', 'watched2')
        verify_value({ old = 5 }, 'watched2')
        update('', 'watched3')
        verify_echo()
      end)

      it('is triggered with key patterns', function()
        source([[
        call dictwatcheradd(]] .. dict_expr .. [[, "wat*", "g:Changed")
        ]])
        update('= 1')
        verify_value({ new = 1 })
        verify_value({ new = 1 })
        update('= 3', 'watched2')
        verify_value({ new = 3 }, 'watched2')
        verify_value({ new = 3 }, 'watched2')
        verify_echo()
        source([[
        call dictwatcherdel(]] .. dict_expr .. [[, "wat*", "g:Changed")
        ]])
        -- watch every key pattern
        source([[
        call dictwatcheradd(]] .. dict_expr .. [[, "*", "g:Changed")
        ]])
        update('= 3', 'another_key')
        update('= 4', 'another_key')
        update('', 'another_key')
        update('= 2')
        verify_value({ new = 3 }, 'another_key')
        verify_value({ old = 3, new = 4 }, 'another_key')
        verify_value({ old = 4 }, 'another_key')
        verify_value({ old = 1, new = 2 })
        verify_value({ old = 1, new = 2 })
        verify_echo()
        source([[
        call dictwatcherdel(]] .. dict_expr .. [[, "*", "g:Changed")
        ]])
      end)

      it('is triggered for empty keys', function()
        command([[
        call dictwatcheradd(]] .. dict_expr .. [[, "", "g:Changed")
        ]])
        update('= 1', '')
        verify_value({ new = 1 }, '')
        update('= 2', '')
        verify_value({ old = 1, new = 2 }, '')
        command([[
        call dictwatcherdel(]] .. dict_expr .. [[, "", "g:Changed")
        ]])
      end)

      it('is triggered for empty keys when using catch-all *', function()
        command([[
        call dictwatcheradd(]] .. dict_expr .. [[, "*", "g:Changed")
        ]])
        update('= 1', '')
        verify_value({ new = 1 }, '')
        update('= 2', '')
        verify_value({ old = 1, new = 2 }, '')
        command([[
        call dictwatcherdel(]] .. dict_expr .. [[, "*", "g:Changed")
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
        { '= 3', { new = 3 } },
        { '= 6', { old = 3, new = 6 } },
        { '+= 3', { old = 6, new = 9 } },
        { '', { old = 9 } },
      })

      test_updates({
        { '= "str"', { new = 'str' } },
        { '= "str2"', { old = 'str', new = 'str2' } },
        { '.= "2str"', { old = 'str2', new = 'str22str' } },
        { '', { old = 'str22str' } },
      })

      test_updates({
        { '= [1, 2]', { new = { 1, 2 } } },
        { '= [1, 2, 3]', { old = { 1, 2 }, new = { 1, 2, 3 } } },
        -- the += will update the list in place, so old and new are the same
        { '+= [4, 5]', { old = { 1, 2, 3, 4, 5 }, new = { 1, 2, 3, 4, 5 } } },
        { '', { old = { 1, 2, 3, 4, 5 } } },
      })

      test_updates({
        { '= {"k": "v"}', { new = { k = 'v' } } },
        { '= {"k1": 2}', { old = { k = 'v' }, new = { k1 = 2 } } },
        { '', { old = { k1 = 2 } } },
      })
    end)
  end

  gentests('g:')
  gentests('b:')
  gentests('w:')
  gentests('t:')
  gentests('g:dict_var', 'let g:dict_var = {}')

  describe('multiple watchers on the same dict/key', function()
    before_each(function()
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
      command('let g:key = "value"')
      eq({ 'notification', '1', { 'key', { new = 'value' } } }, next_msg())
      eq({ 'notification', '2', { 'key', { new = 'value' } } }, next_msg())
    end)

    it('only removes watchers that fully match dict, key and callback', function()
      command('let g:key = "value"')
      eq({ 'notification', '1', { 'key', { new = 'value' } } }, next_msg())
      eq({ 'notification', '2', { 'key', { new = 'value' } } }, next_msg())
      command('call dictwatcherdel(g:, "key", "g:Watcher1")')
      command('let g:key = "v2"')
      eq({ 'notification', '2', { 'key', { old = 'value', new = 'v2' } } }, next_msg())
    end)
  end)

  it('errors out when adding to v:_null_dict', function()
    command([[
    function! g:Watcher1(dict, key, value)
      call rpcnotify(g:channel, '1', a:key, a:value)
    endfunction
    ]])
    eq(
      'Vim(call):E46: Cannot change read-only variable "dictwatcheradd() argument"',
      exc_exec('call dictwatcheradd(v:_null_dict, "x", "g:Watcher1")')
    )
  end)

  describe('errors', function()
    before_each(function()
      source([[
      function! g:Watcher1(dict, key, value)
        call rpcnotify(g:channel, '1', a:key, a:value)
      endfunction
      function! g:Watcher2(dict, key, value)
        call rpcnotify(g:channel, '2', a:key, a:value)
      endfunction
      ]])
    end)

    -- WARNING: This suite depends on the above tests
    it('fails to remove if no watcher with matching callback is found', function()
      eq(
        "Vim(call):Couldn't find a watcher matching key and callback",
        exc_exec('call dictwatcherdel(g:, "key", "g:Watcher1")')
      )
    end)

    it('fails to remove if no watcher with matching key is found', function()
      eq(
        "Vim(call):Couldn't find a watcher matching key and callback",
        exc_exec('call dictwatcherdel(g:, "invalid_key", "g:Watcher2")')
      )
    end)

    it("does not fail to add/remove if the callback doesn't exist", function()
      command('call dictwatcheradd(g:, "key", "g:InvalidCb")')
      command('call dictwatcherdel(g:, "key", "g:InvalidCb")')
    end)

    it('fails to remove watcher from v:_null_dict', function()
      eq(
        "Vim(call):Couldn't find a watcher matching key and callback",
        exc_exec('call dictwatcherdel(v:_null_dict, "x", "g:Watcher2")')
      )
    end)

    --[[
       [ it("fails to add/remove if the callback doesn't exist", function()
       [   eq("Vim(call):Function g:InvalidCb doesn't exist",
       [     exc_exec('call dictwatcheradd(g:, "key", "g:InvalidCb")'))
       [   eq("Vim(call):Function g:InvalidCb doesn't exist",
       [     exc_exec('call dictwatcherdel(g:, "key", "g:InvalidCb")'))
       [ end)
       ]]

    it('does not fail to replace a watcher function', function()
      source([[
      let g:key = 'v2'
      call dictwatcheradd(g:, "key", "g:Watcher2")
      function! g:ReplaceWatcher2()
        function! g:Watcher2(dict, key, value)
          call rpcnotify(g:channel, '2b', a:key, a:value)
        endfunction
      endfunction
      ]])
      command('call g:ReplaceWatcher2()')
      command('let g:key = "value"')
      eq({ 'notification', '2b', { 'key', { old = 'v2', new = 'value' } } }, next_msg())
    end)

    it('does not crash when freeing a watched dictionary', function()
      source([[
      function! Watcher(dict, key, value)
        echo a:key string(a:value)
      endfunction

      function! MakeWatch()
        let d = {'foo': 'bar'}
        call dictwatcheradd(d, 'foo', function('Watcher'))
      endfunction
      ]])

      command('call MakeWatch()')
      assert_alive()
    end)
  end)

  describe('with lambdas', function()
    it('works correctly', function()
      source([[
      let d = {'foo': 'baz'}
      call dictwatcheradd(d, 'foo', {dict, key, value -> rpcnotify(g:channel, '2', key, value)})
      let d.foo = 'bar'
      ]])
      eq({ 'notification', '2', { 'foo', { old = 'baz', new = 'bar' } } }, next_msg())
    end)
  end)

  it('for b:changedtick', function()
    source([[
      function! OnTickChanged(dict, key, value)
        call rpcnotify(g:channel, 'SendChangeTick', a:key, a:value)
      endfunction
      call dictwatcheradd(b:, 'changedtick', 'OnTickChanged')
    ]])

    insert('t')
    eq({ 'notification', 'SendChangeTick', { 'changedtick', { old = 2, new = 3 } } }, next_msg())

    command([[call dictwatcherdel(b:, 'changedtick', 'OnTickChanged')]])
    insert('t')
    assert_alive()
  end)

  it('does not cause use-after-free when unletting from callback', function()
    source([[
      let g:called = 0
      function W(...) abort
        unlet g:d
        let g:called = 1
      endfunction
      let g:d = {}
      call dictwatcheradd(g:d, '*', function('W'))
      let g:d.foo = 123
    ]])
    eq(1, eval('g:called'))
  end)

  it('does not crash when using dictwatcherdel in callback', function()
    source([[
      let g:d = {}

      function! W1(...)
        " Delete current and following watcher.
        call dictwatcherdel(g:d, '*', function('W1'))
        call dictwatcherdel(g:d, '*', function('W2'))
        try
          call dictwatcherdel({}, 'meh', function('tr'))
        catch
          let g:exc = v:exception
        endtry
      endfunction
      call dictwatcheradd(g:d, '*', function('W1'))

      function! W2(...)
      endfunction
      call dictwatcheradd(g:d, '*', function('W2'))

      let g:d.foo = 23
    ]])
    eq(23, eval('g:d.foo'))
    eq("Vim(call):Couldn't find a watcher matching key and callback", eval('g:exc'))
  end)

  it('does not call watcher added in callback', function()
    source([[
      let g:d = {}
      let g:calls = []

      function! W1(...) abort
        call add(g:calls, 'W1')
        call dictwatcheradd(g:d, '*', function('W2'))
      endfunction

      function! W2(...) abort
        call add(g:calls, 'W2')
      endfunction

      call dictwatcheradd(g:d, '*', function('W1'))
      let g:d.foo = 23
    ]])
    eq(23, eval('g:d.foo'))
    eq({ 'W1' }, eval('g:calls'))
  end)

  it('calls watcher deleted in callback', function()
    source([[
      let g:d = {}
      let g:calls = []

      function! W1(...) abort
        call add(g:calls, "W1")
        call dictwatcherdel(g:d, '*', function('W2'))
      endfunction

      function! W2(...) abort
        call add(g:calls, "W2")
      endfunction

      call dictwatcheradd(g:d, '*', function('W1'))
      call dictwatcheradd(g:d, '*', function('W2'))
      let g:d.foo = 123

      unlet g:d
      let g:d = {}
      call dictwatcheradd(g:d, '*', function('W2'))
      call dictwatcheradd(g:d, '*', function('W1'))
      let g:d.foo = 123
    ]])
    eq(123, eval('g:d.foo'))
    eq({ 'W1', 'W2', 'W2', 'W1' }, eval('g:calls'))
  end)
end)
