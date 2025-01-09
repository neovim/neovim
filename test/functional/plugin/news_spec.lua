local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local api = n.api
local clear = n.clear
local eq = t.eq
local fn = n.fn
local matches = t.matches

describe('news_plugin:', function()
  it('loads', function()
    -- `-u` would stop the news plugin from loading at all
    -- `-i NONE` turns off shada, which this plugin requires to load
    clear({ args_rm = { '-u', '-i' } })
    eq(1, fn.exists('news_check'))
  end)

  describe('is skipped when', function()
    it('user disables via global variable', function()
      clear({ args_rm = { '-u', '-i' } })
      api.nvim_set_var('news_check', false)
      eq(false, api.nvim_get_var('news_check'))
    end)

    it('nvim was started by firenvim', function()
      clear({
        args = { '--cmd', 'let g:started_by_firenvim = v:true' },
        args_rm = { '-u', '-i' }
      })
      eq(0, fn.exists('news_check'))
    end)

    it('nvim was started by vscode-neovim', function()
      clear({
        args = { '--cmd', 'let g:vscode = v:true' },
        args_rm = { '-u', '-i' }
      })
      eq(0, fn.exists('news_check'))
    end)

    -- Q: Does this need to be tested? hacky workaround to get it to work
    -- running in the test instance because --embed conflicts with -l
    it('nvim was started as Lua interpreter with -l', function()
      local p = n.spawn_wait({
        args_rm = {
          '--embed',
          '-u',
        },
        args = {
          '-l',
          'test/functional/fixtures/startup-plugin-news.lua',
        }
      })
      matches('nil', p:output())
    end)

    it('shada is turned off', function()
      clear({
        args = { '-i', 'NONE' },
        args_rm = { '-u' }
      })
      eq(0, fn.exists('news_check'))
    end)

    it('shada is missing ability to store/read global vars', function()
      clear({
        args = { '--cmd', "set shada='100" },
        args_rm = { '-u', '-i' },
      })
      eq(0, fn.exists('news_check'))
    end)
  end)
end)
