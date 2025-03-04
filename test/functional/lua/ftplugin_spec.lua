local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local exec_lua = n.exec_lua
local eq = t.eq
local root = n.exec_lua('return vim.fs.normalize(vim.fn.getcwd())')

before_each(function()
  n.command [[e `=stdpath('config') .. '/lua/user-foo/init.lua'`]]
  n.command('w ++p')
  n.command [[e `=stdpath('config') .. '/lua/user-foo/module-bar.lua'`]]
  n.command('w ++p')

  n.command [[e `=stdpath('data') .. '/site/pack/plugin/start/test-plugin/lua/pack-foo/init.lua'`]]
  n.command('w ++p')
  n.command [[e `=stdpath('data') .. '/site/pack/plugin/start/test-plugin/lua/pack-foo/module-bar.lua'`]]
  n.command('w ++p')
  n.clear()
end)

local function stdpath(type)
  return exec_lua(string.format([[ return vim.fs.normalize(vim.fn.stdpath('%s')) ]], type))
end

local function vimruntime()
  return exec_lua [[return vim.fs.normalize(vim.env.VIMRUNTIME)]]
end

describe('lua.includeexpr', function()
  it('must returns path to module in the project', function()
    n.command('e ' .. '/runtime/lua/_ftplugin/lua.lua')
    eq(
      root .. '/runtime/lua/_ftplugin/lua.lua',
      exec_lua [[return require("_ftplugin.lua").includeexpr("_ftplugin.lua")]]
    )
    eq(
      root .. '/runtime/lua/editorconfig.lua',
      exec_lua [[return require("_ftplugin.lua").includeexpr("editorconfig")]]
    )

    n.command('e ' .. root .. '/runtime/lua/foo/init.lua')
    n.command('w ++p')
    n.command('e ' .. root .. '/runtime/lua/foo/bar/init.lua')
    n.command('w ++p')
    eq(
      root .. '/runtime/lua/foo/init.lua',
      exec_lua [[return require("_ftplugin.lua").includeexpr("foo")]]
    )
    eq(
      root .. '/runtime/lua/foo/bar/init.lua',
      exec_lua [[return require("_ftplugin.lua").includeexpr("foo.bar")]]
    )
  end)

  it('must returns path to module in VIMRUNTIME', function()
    n.command('e .')
    eq(
      vimruntime() .. '/lua/_ftplugin/lua.lua',
      exec_lua [[return require("_ftplugin.lua").includeexpr("_ftplugin.lua")]]
    )
    eq(
      vimruntime() .. '/lua/editorconfig.lua',
      exec_lua [[return require("_ftplugin.lua").includeexpr("editorconfig")]]
    )
  end)

  it('must returns path to module in packpath/start', function()
    n.command('e $HOME')
    eq(
      stdpath('data') .. '/site/pack/plugin/start/test-plugin/lua/pack-foo/init.lua',
      exec_lua [[return require("_ftplugin.lua").includeexpr("pack-foo")]]
    )
    eq(
      stdpath('data') .. '/site/pack/plugin/start/test-plugin/lua/pack-foo/module-bar.lua',
      exec_lua [[return require("_ftplugin.lua").includeexpr("pack-foo.module-bar")]]
    )
  end)

  it('must returns path to module in runtimepath', function()
    n.command('e $HOME')
    eq(
      stdpath('config') .. '/lua/user-foo/init.lua',
      exec_lua [[return require("_ftplugin.lua").includeexpr("user-foo")]]
    )
    eq(
      stdpath('config') .. '/lua/user-foo/module-bar.lua',
      exec_lua [[return require("_ftplugin.lua").includeexpr("user-foo.module-bar")]]
    )

    n.command [[e `=$HOME . '/.nvim/lua/runtime-foo/init.lua'`]]
    n.command('w ++p')
    n.command [[e `=$HOME . '/.nvim/lua/runtime-foo/module-bar.lua'`]]
    n.command('w ++p')
    n.command [[exe 'set rtp+=' . $HOME . '/.nvim']]
    n.command('e $HOME')
    eq(
      exec_lua [[return vim.fs.normalize(vim.env.HOME)]] .. '/.nvim/lua/runtime-foo/init.lua',
      exec_lua [[return require("_ftplugin.lua").includeexpr("runtime-foo")]]
    )
  end)

  it('must returns a string even if no module is found', function()
    eq('string', exec_lua [[return type(require("_ftplugin.lua").includeexpr("nonsense"))]])
  end)
end)
