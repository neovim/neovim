local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local eq = helpers.eq
local clear = helpers.clear
local command = helpers.command
local pathsep = helpers.get_pathsep()
local is_os = helpers.is_os
local meths = helpers.meths
local exec_lua = helpers.exec_lua
local feed_command = helpers.feed_command
local feed = helpers.feed
local funcs = helpers.funcs
local pcall_err = helpers.pcall_err
local matches = helpers.matches

describe('vim.secure', function()
  describe('read()', function()
    local xstate = 'Xstate'

    setup(function()
      clear{env={XDG_STATE_HOME=xstate}}
      helpers.mkdir_p(xstate .. pathsep .. (is_os('win') and 'nvim-data' or 'nvim'))
      helpers.write_file('Xfile', [[
        let g:foobar = 42
      ]])
    end)

    teardown(function()
      os.remove('Xfile')
      helpers.rmdir(xstate)
    end)

    it('works', function()
      local screen = Screen.new(80, 8)
      screen:attach()
      screen:set_default_attr_ids({
        [1] = {bold = true, foreground = Screen.colors.Blue1},
        [2] = {bold = true, reverse = true},
        [3] = {bold = true, foreground = Screen.colors.SeaGreen},
        [4] = {reverse = true},
      })

      --- XXX: screen:expect() may fail if this path is too long.
      local cwd = funcs.getcwd()

      -- Need to use feed_command instead of exec_lua because of the confirmation prompt
      feed_command([[lua vim.secure.read('Xfile')]])
      screen:expect{grid=[[
                                                                                        |
        {1:~                                                                               }|
        {1:~                                                                               }|
        {1:~                                                                               }|
        {2:                                                                                }|
        :lua vim.secure.read('Xfile')                                                   |
        {3:]] .. cwd .. pathsep .. [[Xfile is not trusted.}{MATCH:%s+}|
        {3:[i]gnore, (v)iew, (d)eny, (a)llow: }^                                             |
      ]]}
      feed('d')
      screen:expect{grid=[[
        ^                                                                                |
        {1:~                                                                               }|
        {1:~                                                                               }|
        {1:~                                                                               }|
        {1:~                                                                               }|
        {1:~                                                                               }|
        {1:~                                                                               }|
                                                                                        |
      ]]}

      local trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
      eq(string.format('! %s', cwd .. pathsep .. 'Xfile'), vim.trim(trust))
      eq(helpers.NIL, exec_lua([[return vim.secure.read('Xfile')]]))

      os.remove(funcs.stdpath('state') .. pathsep .. 'trust')

      feed_command([[lua vim.secure.read('Xfile')]])
      screen:expect{grid=[[
                                                                                        |
        {1:~                                                                               }|
        {1:~                                                                               }|
        {1:~                                                                               }|
        {2:                                                                                }|
        :lua vim.secure.read('Xfile')                                                   |
        {3:]] .. cwd .. pathsep .. [[Xfile is not trusted.}{MATCH:%s+}|
        {3:[i]gnore, (v)iew, (d)eny, (a)llow: }^                                             |
      ]]}
      feed('a')
      screen:expect{grid=[[
        ^                                                                                |
        {1:~                                                                               }|
        {1:~                                                                               }|
        {1:~                                                                               }|
        {1:~                                                                               }|
        {1:~                                                                               }|
        {1:~                                                                               }|
                                                                                        |
      ]]}

      local hash = funcs.sha256(helpers.read_file('Xfile'))
      trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
      eq(string.format('%s %s', hash, cwd .. pathsep .. 'Xfile'), vim.trim(trust))
      eq(helpers.NIL, exec_lua([[vim.secure.read('Xfile')]]))

      os.remove(funcs.stdpath('state') .. pathsep .. 'trust')

      feed_command([[lua vim.secure.read('Xfile')]])
      screen:expect{grid=[[
                                                                                        |
        {1:~                                                                               }|
        {1:~                                                                               }|
        {1:~                                                                               }|
        {2:                                                                                }|
        :lua vim.secure.read('Xfile')                                                   |
        {3:]] .. cwd .. pathsep .. [[Xfile is not trusted.}{MATCH:%s+}|
        {3:[i]gnore, (v)iew, (d)eny, (a)llow: }^                                             |
      ]]}
      feed('i')
      screen:expect{grid=[[
        ^                                                                                |
        {1:~                                                                               }|
        {1:~                                                                               }|
        {1:~                                                                               }|
        {1:~                                                                               }|
        {1:~                                                                               }|
        {1:~                                                                               }|
                                                                                        |
      ]]}

      -- Trust database is not updated
      trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
      eq(nil, trust)

      feed_command([[lua vim.secure.read('Xfile')]])
      screen:expect{grid=[[
                                                                                        |
        {1:~                                                                               }|
        {1:~                                                                               }|
        {1:~                                                                               }|
        {2:                                                                                }|
        :lua vim.secure.read('Xfile')                                                   |
        {3:]] .. cwd .. pathsep .. [[Xfile is not trusted.}{MATCH:%s+}|
        {3:[i]gnore, (v)iew, (d)eny, (a)llow: }^                                             |
      ]]}
      feed('v')
      screen:expect{grid=[[
          ^let g:foobar = 42                                                             |
        {1:~                                                                               }|
        {1:~                                                                               }|
        {2:]] .. funcs.fnamemodify(cwd, ':~') .. pathsep .. [[Xfile [RO]{MATCH:%s+}}|
                                                                                        |
        {1:~                                                                               }|
        {4:[No Name]                                                                       }|
                                                                                        |
      ]]}

      -- Trust database is not updated
      trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
      eq(nil, trust)

      -- Cannot write file
      pcall_err(command, 'write')
      eq(true, meths.get_option_value('readonly', {}))
    end)
  end)

  describe('trust()', function()
    local xstate = 'Xstate'

    setup(function()
      clear{env={XDG_STATE_HOME=xstate}}
      helpers.mkdir_p(xstate .. pathsep .. (is_os('win') and 'nvim-data' or 'nvim'))
    end)

    teardown(function()
      helpers.rmdir(xstate)
    end)

    before_each(function()
      helpers.write_file('test_file', 'test')
    end)

    after_each(function()
      os.remove('test_file')
    end)

    it('returns error when passing both path and bufnr', function()
      matches('"path" and "bufnr" are mutually exclusive',
        pcall_err(exec_lua, [[vim.secure.trust({action='deny', bufnr=0, path='test_file'})]]))
    end)

    it('returns error when passing neither path or bufnr', function()
      matches('one of "path" or "bufnr" is required',
        pcall_err(exec_lua, [[vim.secure.trust({action='deny'})]]))
    end)

    it('trust then deny then remove a file using bufnr', function()
      local cwd = funcs.getcwd()
      local hash = funcs.sha256(helpers.read_file('test_file'))
      local full_path = cwd .. pathsep .. 'test_file'

      command('edit test_file')
      eq({true, full_path}, exec_lua([[return {vim.secure.trust({action='allow', bufnr=0})}]]))
      local trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
      eq(string.format('%s %s', hash, full_path), vim.trim(trust))

      eq({true, full_path}, exec_lua([[return {vim.secure.trust({action='deny', bufnr=0})}]]))
      trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
      eq(string.format('! %s', full_path), vim.trim(trust))

      eq({true, full_path}, exec_lua([[return {vim.secure.trust({action='remove', bufnr=0})}]]))
      trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
      eq('', vim.trim(trust))
    end)

    it('deny then trust then remove a file using bufnr', function()
      local cwd = funcs.getcwd()
      local hash = funcs.sha256(helpers.read_file('test_file'))
      local full_path = cwd .. pathsep .. 'test_file'

      command('edit test_file')
      eq({true, full_path}, exec_lua([[return {vim.secure.trust({action='deny', bufnr=0})}]]))
      local trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
      eq(string.format('! %s', full_path), vim.trim(trust))

      eq({true, full_path}, exec_lua([[return {vim.secure.trust({action='allow', bufnr=0})}]]))
      trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
      eq(string.format('%s %s', hash, full_path), vim.trim(trust))

      eq({true, full_path}, exec_lua([[return {vim.secure.trust({action='remove', bufnr=0})}]]))
      trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
      eq('', vim.trim(trust))
    end)

    it('trust using bufnr then deny then remove a file using path', function()
      local cwd = funcs.getcwd()
      local hash = funcs.sha256(helpers.read_file('test_file'))
      local full_path = cwd .. pathsep .. 'test_file'

      command('edit test_file')
      eq({true, full_path}, exec_lua([[return {vim.secure.trust({action='allow', bufnr=0})}]]))
      local trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
      eq(string.format('%s %s', hash, full_path), vim.trim(trust))

      eq({true, full_path}, exec_lua([[return {vim.secure.trust({action='deny', path='test_file'})}]]))
      trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
      eq(string.format('! %s', full_path), vim.trim(trust))

      eq({true, full_path}, exec_lua([[return {vim.secure.trust({action='remove', path='test_file'})}]]))
      trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
      eq('', vim.trim(trust))
    end)

    it('deny then trust then remove a file using bufnr', function()
      local cwd = funcs.getcwd()
      local hash = funcs.sha256(helpers.read_file('test_file'))
      local full_path = cwd .. pathsep .. 'test_file'

      command('edit test_file')
      eq({true, full_path}, exec_lua([[return {vim.secure.trust({action='deny', path='test_file'})}]]))
      local trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
      eq(string.format('! %s', full_path), vim.trim(trust))

      eq({true, full_path}, exec_lua([[return {vim.secure.trust({action='allow', bufnr=0})}]]))
      trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
      eq(string.format('%s %s', hash, full_path), vim.trim(trust))

      eq({true, full_path}, exec_lua([[return {vim.secure.trust({action='remove', path='test_file'})}]]))
      trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
      eq('', vim.trim(trust))
    end)

    it('trust returns error when buffer not associated to file', function()
      command('new')
      eq({false, 'buffer is not associated with a file'},
        exec_lua([[return {vim.secure.trust({action='allow', bufnr=0})}]]))
    end)
  end)
end)
