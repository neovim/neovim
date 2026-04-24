local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local eq = t.eq
local clear = n.clear
local command = n.command
local is_os = t.is_os
local api = n.api
local exec_lua = n.exec_lua
local feed_command = n.feed_command
local feed = n.feed
local fn = n.fn
local stdpath = fn.stdpath
local pcall_err = t.pcall_err
local matches = t.matches
local read_file = t.read_file

describe('vim.secure', function()
  local function assert_trust_entry(expected)
    local trust = assert(read_file(vim.fs.joinpath(stdpath('state'), 'trust')))
    eq(expected, vim.trim(trust))
  end

  describe('read()', function()
    local xstate = 'Xstate_lua_secure'
    local screen ---@type test.functional.ui.screen

    before_each(function()
      clear { env = { XDG_STATE_HOME = xstate } }
      n.mkdir_p(vim.fs.joinpath(xstate, is_os('win') and 'nvim-data' or 'nvim'))

      t.mkdir('Xdir')
      t.mkdir('Xdir/Xsubdir')
      t.write_file('Xdir/Xfile.txt', [[hello, world]])

      t.write_file(
        'Xfile',
        [[
        let g:foobar = 42
      ]]
      )
      screen = Screen.new(500, 8)
    end)

    after_each(function()
      screen:detach()
      os.remove('Xfile')
      n.rmdir('Xdir')
      n.rmdir(xstate)
    end)

    it('regular file', function()
      screen:set_default_attr_ids({
        [1] = { bold = true, foreground = Screen.colors.Blue1 },
        [2] = { bold = true, reverse = true },
        [3] = { bold = true, foreground = Screen.colors.SeaGreen },
        [4] = { reverse = true },
      })

      local cwd = fn.getcwd()
      local msg = 'exrc: Found untrusted code. To enable it, choose (v)iew then run `:trust`:'
      local path = vim.fs.joinpath(cwd, 'Xfile')

      -- Need to use feed_command instead of exec_lua because of the confirmation prompt
      feed_command([[lua vim.secure.read('Xfile')]])
      screen:expect([[
        {MATCH: +}|
        {1:~{MATCH: +}}|*2
        {2:{MATCH: +}}|
        :lua vim.secure.read('Xfile'){MATCH: +}|
        {3:]] .. msg .. [[}{MATCH: *}|
        {3:]] .. path .. [[}{MATCH: *}|
        {3:[i]gnore, (v)iew, (d)eny: }^{MATCH: +}|
      ]])
      feed('d')
      screen:expect([[
        ^{MATCH: +}|
        {1:~{MATCH: +}}|*6
        {MATCH: +}|
      ]])

      assert_trust_entry(('! %s'):format(vim.fs.joinpath(cwd, 'Xfile')))
      eq(vim.NIL, exec_lua([[return vim.secure.read('Xfile')]]))

      os.remove(vim.fs.joinpath(stdpath('state'), 'trust'))

      feed_command([[lua vim.secure.read('Xfile')]])
      screen:expect([[
        {MATCH: +}|
        {1:~{MATCH: +}}|*2
        {2:{MATCH: +}}|
        :lua vim.secure.read('Xfile'){MATCH: +}|
        {3:]] .. msg .. [[}{MATCH: *}|
        {3:]] .. path .. [[}{MATCH: *}|
        {3:[i]gnore, (v)iew, (d)eny: }^{MATCH: +}|
      ]])
      feed('v')
      feed(':trust<CR>')
      screen:expect([[
        ^let g:foobar = 42{MATCH: +}|
        {1:~{MATCH: +}}|*2
        {2:]] .. vim.fs.joinpath(fn.fnamemodify(cwd, ':~'), 'Xfile') .. [[ [RO]{MATCH: +}}|
        {MATCH: +}|
        {1:~{MATCH: +}}|
        {4:[No Name]{MATCH: +}}|
        Allowed in trust database: "]] .. vim.fs.joinpath(cwd, 'Xfile') .. [["{MATCH: +}|
      ]])
      -- close the split for the next test below.
      feed(':q<CR>')

      local hash = fn.sha256(assert(read_file('Xfile')))
      assert_trust_entry(('%s %s'):format(hash, vim.fs.joinpath(cwd, 'Xfile')))
      eq('let g:foobar = 42\n', exec_lua([[return vim.secure.read('Xfile')]]))

      os.remove(vim.fs.joinpath(stdpath('state'), 'trust'))

      feed_command([[lua vim.secure.read('Xfile')]])
      screen:expect([[
        {MATCH: +}|
        {1:~{MATCH: +}}|*2
        {2:{MATCH: +}}|
        :lua vim.secure.read('Xfile'){MATCH: +}|
        {3:]] .. msg .. [[}{MATCH: *}|
        {3:]] .. path .. [[}{MATCH: *}|
        {3:[i]gnore, (v)iew, (d)eny: }^{MATCH: +}|
      ]])
      feed('i')
      screen:expect([[
        ^{MATCH: +}|
        {1:~{MATCH: +}}|*6
        {MATCH: +}|
      ]])

      -- Trust database is not updated
      eq(nil, read_file(vim.fs.joinpath(stdpath('state'), 'trust')))

      feed_command([[lua vim.secure.read('Xfile')]])
      screen:expect([[
        {MATCH: +}|
        {1:~{MATCH: +}}|*2
        {2:{MATCH: +}}|
        :lua vim.secure.read('Xfile'){MATCH: +}|
        {3:]] .. msg .. [[}{MATCH: +}|
        {3:]] .. path .. [[}{MATCH: *}|
        {3:[i]gnore, (v)iew, (d)eny: }^{MATCH: +}|
      ]])
      feed('v')
      screen:expect([[
        ^let g:foobar = 42{MATCH: +}|
        {1:~{MATCH: +}}|*2
        {2:]] .. vim.fs.joinpath(fn.fnamemodify(cwd, ':~'), 'Xfile') .. [[ [RO]{MATCH: +}}|
        {MATCH: +}|
        {1:~{MATCH: +}}|
        {4:[No Name]{MATCH: +}}|
        {MATCH: +}|
      ]])

      -- Trust database is not updated
      eq(nil, read_file(vim.fs.joinpath(stdpath('state'), 'trust')))

      -- Cannot write file
      pcall_err(command, 'write')
      eq(true, api.nvim_get_option_value('readonly', {}))
    end)

    it('directory', function()
      screen:set_default_attr_ids({
        [1] = { bold = true, foreground = Screen.colors.Blue1 },
        [2] = { bold = true, reverse = true },
        [3] = { bold = true, foreground = Screen.colors.SeaGreen },
        [4] = { reverse = true },
      })

      local cwd = fn.getcwd()
      local msg =
        'exrc: Found untrusted code. DIRECTORY trust is decided only by name, not contents:'
      local path = vim.fs.joinpath(cwd, 'Xdir')

      -- Need to use feed_command instead of exec_lua because of the confirmation prompt
      feed_command([[lua vim.secure.read('Xdir')]])
      screen:expect([[
        {MATCH: +}|
        {1:~{MATCH: +}}|*2
        {2:{MATCH: +}}|
        :lua vim.secure.read('Xdir'){MATCH: +}|
        {3:]] .. msg .. [[}{MATCH: +}|
        {3:]] .. path .. [[}{MATCH: +}|
        {3:[i]gnore, (v)iew, (d)eny, (a)llow: }^{MATCH: +}|
      ]])
      feed('d')
      screen:expect([[
        ^{MATCH: +}|
        {1:~{MATCH: +}}|*6
        {MATCH: +}|
      ]])

      assert_trust_entry(('! %s'):format(vim.fs.joinpath(cwd, 'Xdir')))
      eq(vim.NIL, exec_lua([[return vim.secure.read('Xdir')]]))

      os.remove(vim.fs.joinpath(stdpath('state'), 'trust'))

      feed_command([[lua vim.secure.read('Xdir')]])
      screen:expect([[
        {MATCH: +}|
        {1:~{MATCH: +}}|*2
        {2:{MATCH: +}}|
        :lua vim.secure.read('Xdir'){MATCH: +}|
        {3:]] .. msg .. [[}{MATCH: +}|
        {3:]] .. path .. [[}{MATCH: +}|
        {3:[i]gnore, (v)iew, (d)eny, (a)llow: }^{MATCH: +}|
      ]])
      feed('a')
      screen:expect([[
        ^{MATCH: +}|
        {1:~{MATCH: +}}|*6
        {MATCH: +}|
      ]])

      -- Directories aren't hashed in the trust database, instead a slug ("directory") is stored
      -- instead.
      assert_trust_entry(('directory %s'):format(vim.fs.joinpath(cwd, 'Xdir')))
      eq(true, exec_lua([[return vim.secure.read('Xdir')]]))

      os.remove(vim.fs.joinpath(stdpath('state'), 'trust'))

      feed_command([[lua vim.secure.read('Xdir')]])
      screen:expect([[
        {MATCH: +}|
        {1:~{MATCH: +}}|*2
        {2:{MATCH: +}}|
        :lua vim.secure.read('Xdir'){MATCH: +}|
        {3:]] .. msg .. [[}{MATCH: +}|
        {3:]] .. path .. [[}{MATCH: +}|
        {3:[i]gnore, (v)iew, (d)eny, (a)llow: }^{MATCH: +}|
      ]])
      feed('i')
      screen:expect([[
        ^{MATCH: +}|
        {1:~{MATCH: +}}|*6
        {MATCH: +}|
      ]])

      -- Trust database is not updated
      eq(nil, read_file(vim.fs.joinpath(stdpath('state'), 'trust')))

      feed_command([[lua vim.secure.read('Xdir')]])
      screen:expect([[
        {MATCH: +}|
        {1:~{MATCH: +}}|*2
        {2:{MATCH: +}}|
        :lua vim.secure.read('Xdir'){MATCH: +}|
        {3:]] .. msg .. [[}{MATCH: +}|
        {3:]] .. path .. [[}{MATCH: +}|
        {3:[i]gnore, (v)iew, (d)eny, (a)llow: }^{MATCH: +}|
      ]])
      feed('v')
      screen:expect([[
        ^{MATCH: +}|
        {1:~{MATCH: +}}|*2
        {2:]] .. vim.fs.joinpath(fn.fnamemodify(cwd, ':~'), 'Xdir') .. [[ [RO]{MATCH: +}}|
        {MATCH: +}|
        {1:~{MATCH: +}}|
        {4:[No Name]{MATCH: +}}|
        {MATCH: +}|
      ]])

      -- Trust database is not updated
      eq(nil, read_file(vim.fs.joinpath(stdpath('state'), 'trust')))
    end)
  end)

  describe('trust()', function()
    local xstate = 'Xstate_lua_secure'
    local test_file = 'Xtest_functional_lua_secure'
    local empty_file = 'Xtest_functional_lua_secure_empty'
    local test_dir = 'Xtest_functional_lua_secure_dir'

    setup(function()
      clear { env = { XDG_STATE_HOME = xstate } }
    end)

    before_each(function()
      n.mkdir_p(vim.fs.joinpath(xstate, is_os('win') and 'nvim-data' or 'nvim'))
      t.write_file(test_file, 'test')
      t.write_file(empty_file, '')
      t.mkdir(test_dir)
    end)

    after_each(function()
      os.remove(test_file)
      os.remove(empty_file)
      n.rmdir(test_dir)
      n.rmdir(xstate)
    end)

    it('returns error when passing both path and bufnr', function()
      matches(
        '"path" and "bufnr" are mutually exclusive',
        pcall_err(exec_lua, [[vim.secure.trust({action='deny', bufnr=0, path=...})]], test_file)
      )
    end)

    it('returns error when passing neither path or bufnr', function()
      matches(
        'one of "path" or "bufnr" is required',
        pcall_err(exec_lua, [[vim.secure.trust({action='deny'})]])
      )
    end)

    it('trust then deny then remove a file using bufnr', function()
      local cwd = fn.getcwd()
      local hash = fn.sha256(assert(read_file(test_file)))
      local full_path = vim.fs.joinpath(cwd, test_file)

      command('edit ' .. test_file)
      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='allow', bufnr=0})}]]))
      assert_trust_entry(('%s %s'):format(hash, full_path))

      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='deny', bufnr=0})}]]))
      assert_trust_entry(('! %s'):format(full_path))

      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='remove', bufnr=0})}]]))
      assert_trust_entry('')
    end)

    it('trust an empty file using bufnr', function()
      local cwd = fn.getcwd()
      local hash = fn.sha256(assert(read_file(empty_file)))
      local full_path = vim.fs.joinpath(cwd, empty_file)

      command('edit ' .. empty_file)
      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='allow', bufnr=0})}]]))
      assert_trust_entry(('%s %s'):format(hash, full_path))
    end)

    it('deny then trust then remove a file using bufnr', function()
      local cwd = fn.getcwd()
      local hash = fn.sha256(assert(read_file(test_file)))
      local full_path = vim.fs.joinpath(cwd, test_file)

      command('edit ' .. test_file)
      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='deny', bufnr=0})}]]))
      assert_trust_entry(('! %s'):format(full_path))

      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='allow', bufnr=0})}]]))
      assert_trust_entry(('%s %s'):format(hash, full_path))

      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='remove', bufnr=0})}]]))
      assert_trust_entry('')
    end)

    it('trust using bufnr then deny then remove a file using path', function()
      local cwd = fn.getcwd()
      local hash = fn.sha256(assert(read_file(test_file)))
      local full_path = vim.fs.joinpath(cwd, test_file)

      command('edit ' .. test_file)
      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='allow', bufnr=0})}]]))
      assert_trust_entry(('%s %s'):format(hash, full_path))

      eq(
        { true, full_path },
        exec_lua([[return {vim.secure.trust({action='deny', path=...})}]], test_file)
      )
      assert_trust_entry(('! %s'):format(full_path))

      eq(
        { true, full_path },
        exec_lua([[return {vim.secure.trust({action='remove', path=...})}]], test_file)
      )
      assert_trust_entry('')
    end)

    it('trust then deny then remove a file using path', function()
      local cwd = fn.getcwd()
      local hash = fn.sha256(assert(read_file(test_file)))
      local full_path = vim.fs.joinpath(cwd, test_file)

      eq(
        { true, full_path },
        exec_lua([[return {vim.secure.trust({action='allow', path=...})}]], test_file)
      )
      assert_trust_entry(('%s %s'):format(hash, full_path))

      eq(
        { true, full_path },
        exec_lua([[return {vim.secure.trust({action='deny', path=...})}]], test_file)
      )
      assert_trust_entry(('! %s'):format(full_path))

      eq(
        { true, full_path },
        exec_lua([[return {vim.secure.trust({action='remove', path=...})}]], test_file)
      )
      assert_trust_entry('')
    end)

    it('deny then trust then remove a file using bufnr', function()
      local cwd = fn.getcwd()
      local hash = fn.sha256(assert(read_file(test_file)))
      local full_path = vim.fs.joinpath(cwd, test_file)

      command('edit ' .. test_file)
      eq(
        { true, full_path },
        exec_lua([[return {vim.secure.trust({action='deny', path=...})}]], test_file)
      )
      assert_trust_entry(('! %s'):format(full_path))

      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='allow', bufnr=0})}]]))
      assert_trust_entry(('%s %s'):format(hash, full_path))

      eq(
        { true, full_path },
        exec_lua([[return {vim.secure.trust({action='remove', path=...})}]], test_file)
      )
      assert_trust_entry('')
    end)

    it('trust returns error when buffer not associated to file', function()
      command('new')
      eq(
        { false, 'buffer is not associated with a file' },
        exec_lua([[return {vim.secure.trust({action='allow', bufnr=0})}]])
      )
    end)

    it('trust then deny then remove a directory using bufnr', function()
      local cwd = fn.getcwd()
      local full_path = vim.fs.joinpath(cwd, test_dir)
      command('edit ' .. test_dir)

      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='allow', bufnr=0})}]]))
      assert_trust_entry(('directory %s'):format(full_path))

      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='deny', bufnr=0})}]]))
      assert_trust_entry(('! %s'):format(full_path))

      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='remove', bufnr=0})}]]))
      assert_trust_entry('')
    end)
  end)
end)
