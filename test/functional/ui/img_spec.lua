local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local retry = t.retry

local clear = n.clear
local fn = n.fn
local testprg = n.testprg
local exec_lua = n.exec_lua
local eval = n.eval

describe('ui/img', function()
  before_each(function()
    clear()

    exec_lua([[
      vim.ui.img.providers['test'] = vim.ui.img.providers.new({
        show = function(_self, opts)
        end,
        hide = function(_self, ids)
        end,
      })

      vim.o.imgprovider = 'test'
    ]])
  end)

  describe('providers', function()
    describe('iterm2', function()
      it('can display an image in neovim', function()
        local provider = vim.ui.img.providers.load('iterm2')
        error('todo: implement')
      end)

      it('can hide an image in neovim', function()
        local provider = vim.ui.img.providers.load('iterm2')
        error('todo: implement')
      end)

      it('can update an image in neovim', function()
        local provider = vim.ui.img.providers.load('iterm2')
        error('todo: implement')
      end)
    end)

    describe('kitty', function()
      it('can display an image in neovim', function()
        local provider = vim.ui.img.providers.load('kitty')
        error('todo: implement')
      end)

      it('can hide an image in neovim', function()
        local provider = vim.ui.img.providers.load('kitty')
        error('todo: implement')
      end)

      it('can update an image in neovim', function()
        local provider = vim.ui.img.providers.load('kitty')
        error('todo: implement')
      end)
    end)

    describe('sixel', function()
      it('can display an image in neovim', function()
        local provider = vim.ui.img.providers.load('sixel')
        error('todo: implement')
      end)

      it('can hide an image in neovim', function()
        local provider = vim.ui.img.providers.load('sixel')
        error('todo: implement')
      end)

      it('can update an image in neovim', function()
        local provider = vim.ui.img.providers.load('sixel')
        error('todo: implement')
      end)
    end)
  end)
end)
