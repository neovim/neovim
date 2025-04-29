local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local eq = t.eq
local clear = n.clear
local command = n.command
local pathsep = n.get_pathsep()
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
  describe('read()', function()
    local xstate = 'Xstate'

    setup(function()
      clear { env = { XDG_STATE_HOME = xstate } }
      n.mkdir_p(xstate .. pathsep .. (is_os('win') and 'nvim-data' or 'nvim'))
      t.write_file(
        'Xfile',
        [[
        let g:foobar = 42
      ]]
      )
    end)

    teardown(function()
      os.remove('Xfile')
      n.rmdir(xstate)
    end)

    it('works', function()
      local screen = Screen.new(500, 8)
      screen:set_default_attr_ids({
        [1] = { bold = true, foreground = Screen.colors.Blue1 },
        [2] = { bold = true, reverse = true },
        [3] = { bold = true, foreground = Screen.colors.SeaGreen },
        [4] = { reverse = true },
      })

      local cwd = fn.getcwd()
      local msg = cwd .. pathsep .. 'Xfile is not trusted.'
      if #msg >= screen._width then
        pending('path too long')
        return
      end

      -- Need to use feed_command instead of exec_lua because of the confirmation prompt
      feed_command([[lua vim.secure.read('Xfile')]])
      screen:expect([[
        {MATCH: +}|
        {1:~{MATCH: +}}|*3
        {2:{MATCH: +}}|
        :lua vim.secure.read('Xfile'){MATCH: +}|
        {3:]] .. msg .. [[}{MATCH: +}|
        {3:[i]gnore, (v)iew, (d)eny, (a)llow: }^{MATCH: +}|
      ]])
      feed('d')
      screen:expect([[
        ^{MATCH: +}|
        {1:~{MATCH: +}}|*6
        {MATCH: +}|
      ]])

      local trust = assert(read_file(stdpath('state') .. pathsep .. 'trust'))
      eq(string.format('! %s', cwd .. pathsep .. 'Xfile'), vim.trim(trust))
      eq(vim.NIL, exec_lua([[return vim.secure.read('Xfile')]]))

      os.remove(stdpath('state') .. pathsep .. 'trust')

      feed_command([[lua vim.secure.read('Xfile')]])
      screen:expect([[
        {MATCH: +}|
        {1:~{MATCH: +}}|*3
        {2:{MATCH: +}}|
        :lua vim.secure.read('Xfile'){MATCH: +}|
        {3:]] .. msg .. [[}{MATCH: +}|
        {3:[i]gnore, (v)iew, (d)eny, (a)llow: }^{MATCH: +}|
      ]])
      feed('a')
      screen:expect([[
        ^{MATCH: +}|
        {1:~{MATCH: +}}|*6
        {MATCH: +}|
      ]])

      local hash = fn.sha256(assert(read_file('Xfile')))
      trust = assert(read_file(stdpath('state') .. pathsep .. 'trust'))
      eq(string.format('%s %s', hash, cwd .. pathsep .. 'Xfile'), vim.trim(trust))
      eq(vim.NIL, exec_lua([[vim.secure.read('Xfile')]]))

      os.remove(stdpath('state') .. pathsep .. 'trust')

      feed_command([[lua vim.secure.read('Xfile')]])
      screen:expect([[
        {MATCH: +}|
        {1:~{MATCH: +}}|*3
        {2:{MATCH: +}}|
        :lua vim.secure.read('Xfile'){MATCH: +}|
        {3:]] .. msg .. [[}{MATCH: +}|
        {3:[i]gnore, (v)iew, (d)eny, (a)llow: }^{MATCH: +}|
      ]])
      feed('i')
      screen:expect([[
        ^{MATCH: +}|
        {1:~{MATCH: +}}|*6
        {MATCH: +}|
      ]])

      -- Trust database is not updated
      eq(nil, read_file(stdpath('state') .. pathsep .. 'trust'))

      feed_command([[lua vim.secure.read('Xfile')]])
      screen:expect([[
        {MATCH: +}|
        {1:~{MATCH: +}}|*3
        {2:{MATCH: +}}|
        :lua vim.secure.read('Xfile'){MATCH: +}|
        {3:]] .. msg .. [[}{MATCH: +}|
        {3:[i]gnore, (v)iew, (d)eny, (a)llow: }^{MATCH: +}|
      ]])
      feed('v')
      screen:expect([[
        ^let g:foobar = 42{MATCH: +}|
        {1:~{MATCH: +}}|*2
        {2:]] .. fn.fnamemodify(cwd, ':~') .. pathsep .. [[Xfile [RO]{MATCH: +}}|
        {MATCH: +}|
        {1:~{MATCH: +}}|
        {4:[No Name]{MATCH: +}}|
        {MATCH: +}|
      ]])

      -- Trust database is not updated
      eq(nil, read_file(stdpath('state') .. pathsep .. 'trust'))

      -- Cannot write file
      pcall_err(command, 'write')
      eq(true, api.nvim_get_option_value('readonly', {}))
    end)
  end)

  describe('trust()', function()
    local xstate = 'Xstate'

    setup(function()
      clear { env = { XDG_STATE_HOME = xstate } }
      n.mkdir_p(xstate .. pathsep .. (is_os('win') and 'nvim-data' or 'nvim'))
    end)

    teardown(function()
      n.rmdir(xstate)
    end)

    before_each(function()
      t.write_file('test_file', 'test')
    end)

    after_each(function()
      os.remove('test_file')
    end)

    it('returns error when passing both path and bufnr', function()
      matches(
        '"path" and "bufnr" are mutually exclusive',
        pcall_err(exec_lua, [[vim.secure.trust({action='deny', bufnr=0, path='test_file'})]])
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
      local hash = fn.sha256(read_file('test_file'))
      local full_path = cwd .. pathsep .. 'test_file'

      command('edit test_file')
      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='allow', bufnr=0})}]]))
      local trust = read_file(stdpath('state') .. pathsep .. 'trust')
      eq(string.format('%s %s', hash, full_path), vim.trim(trust))

      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='deny', bufnr=0})}]]))
      trust = read_file(stdpath('state') .. pathsep .. 'trust')
      eq(string.format('! %s', full_path), vim.trim(trust))

      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='remove', bufnr=0})}]]))
      trust = read_file(stdpath('state') .. pathsep .. 'trust')
      eq('', vim.trim(trust))
    end)

    it('deny then trust then remove a file using bufnr', function()
      local cwd = fn.getcwd()
      local hash = fn.sha256(read_file('test_file'))
      local full_path = cwd .. pathsep .. 'test_file'

      command('edit test_file')
      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='deny', bufnr=0})}]]))
      local trust = read_file(stdpath('state') .. pathsep .. 'trust')
      eq(string.format('! %s', full_path), vim.trim(trust))

      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='allow', bufnr=0})}]]))
      trust = read_file(stdpath('state') .. pathsep .. 'trust')
      eq(string.format('%s %s', hash, full_path), vim.trim(trust))

      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='remove', bufnr=0})}]]))
      trust = read_file(stdpath('state') .. pathsep .. 'trust')
      eq('', vim.trim(trust))
    end)

    it('trust using bufnr then deny then remove a file using path', function()
      local cwd = fn.getcwd()
      local hash = fn.sha256(read_file('test_file'))
      local full_path = cwd .. pathsep .. 'test_file'

      command('edit test_file')
      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='allow', bufnr=0})}]]))
      local trust = read_file(stdpath('state') .. pathsep .. 'trust')
      eq(string.format('%s %s', hash, full_path), vim.trim(trust))

      eq(
        { true, full_path },
        exec_lua([[return {vim.secure.trust({action='deny', path='test_file'})}]])
      )
      trust = read_file(stdpath('state') .. pathsep .. 'trust')
      eq(string.format('! %s', full_path), vim.trim(trust))

      eq(
        { true, full_path },
        exec_lua([[return {vim.secure.trust({action='remove', path='test_file'})}]])
      )
      trust = read_file(stdpath('state') .. pathsep .. 'trust')
      eq('', vim.trim(trust))
    end)

    it('deny then trust then remove a file using bufnr', function()
      local cwd = fn.getcwd()
      local hash = fn.sha256(read_file('test_file'))
      local full_path = cwd .. pathsep .. 'test_file'

      command('edit test_file')
      eq(
        { true, full_path },
        exec_lua([[return {vim.secure.trust({action='deny', path='test_file'})}]])
      )
      local trust = read_file(stdpath('state') .. pathsep .. 'trust')
      eq(string.format('! %s', full_path), vim.trim(trust))

      eq({ true, full_path }, exec_lua([[return {vim.secure.trust({action='allow', bufnr=0})}]]))
      trust = read_file(stdpath('state') .. pathsep .. 'trust')
      eq(string.format('%s %s', hash, full_path), vim.trim(trust))

      eq(
        { true, full_path },
        exec_lua([[return {vim.secure.trust({action='remove', path='test_file'})}]])
      )
      trust = read_file(stdpath('state') .. pathsep .. 'trust')
      eq('', vim.trim(trust))
    end)

    it('trust returns error when buffer not associated to file', function()
      command('new')
      eq(
        { false, 'buffer is not associated with a file' },
        exec_lua([[return {vim.secure.trust({action='allow', bufnr=0})}]])
      )
    end)
  end)
end)
