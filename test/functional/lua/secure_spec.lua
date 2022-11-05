local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local eq = helpers.eq
local clear = helpers.clear
local command = helpers.command
local pathsep = helpers.get_pathsep()
local iswin = helpers.iswin()
local curbufmeths = helpers.curbufmeths
local exec_lua = helpers.exec_lua
local feed_command = helpers.feed_command
local feed = helpers.feed
local funcs = helpers.funcs
local pcall_err = helpers.pcall_err

describe('vim.secure', function()
  describe('read()', function()
    local xstate = 'Xstate'

    setup(function()
      helpers.mkdir_p(xstate .. pathsep .. (iswin and 'nvim-data' or 'nvim'))
    end)

    teardown(function()
      helpers.rmdir(xstate)
    end)

    before_each(function()
      helpers.write_file('Xfile', [[
        let g:foobar = 42
      ]])
      clear{env={XDG_STATE_HOME=xstate}}
    end)

    after_each(function()
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
        {3:]] .. cwd .. pathsep .. [[Xfile is untrusted}{MATCH:%s+}|
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
        {3:]] .. cwd .. pathsep .. [[Xfile is untrusted}{MATCH:%s+}|
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
        {3:]] .. cwd .. pathsep .. [[Xfile is untrusted}{MATCH:%s+}|
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
        {3:]] .. cwd .. pathsep .. [[Xfile is untrusted}{MATCH:%s+}|
        {3:[i]gnore, (v)iew, (d)eny, (a)llow: }^                                             |
      ]]}
      feed('v')
      screen:expect{grid=[[
        ^  let g:foobar = 42                                                             |
        {1:~                                                                               }|
        {1:~                                                                               }|
        {2:]] .. cwd .. pathsep .. [[Xfile [RO]{MATCH:%s+}|
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
      eq(false, curbufmeths.get_option('modifiable'))
    end)
  end)
end)
