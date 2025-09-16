-- Tests for filetype-plugin behavior (files in runtime/ftplugin/*).

local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local exec_lua = n.exec_lua
local command = n.command
local eq = t.eq

---@param type string
---@return string
local function stdpath(type)
  return exec_lua([[return vim.fs.abspath(vim.fn.stdpath(...))]], type)
end

---@return string
local function vimruntime()
  return exec_lua [[ return vim.fs.abspath(vim.env.VIMRUNTIME) ]]
end

---@param module string
---@return string
local function lua_includeexpr(module)
  return exec_lua([[return vim.fs.abspath(require 'vim._ftplugin.lua'.includeexpr(...))]], module)
end

describe("ftplugin: Lua 'includeexpr'", function()
  local repo_root = ''
  local temp_dir = ''

  setup(function()
    repo_root = vim.fs.normalize(assert(vim.uv.cwd()))
    temp_dir = t.tmpname(false)
    n.clear()
  end)

  teardown(function()
    n.expect_exit(n.command, 'qall!')
    n.rmdir('runtime/lua/foo/')
  end)

  before_each(function()
    command(([[
      edit `=stdpath('config') .. '/lua/user-foo/init.lua'`
      write ++p
      edit `=stdpath('config') .. '/lua/user-foo/bar.lua'`
      write ++p
      edit `=stdpath('data') .. '/site/pack/packer/start/plugin-foo/lua/plugin-foo/init.lua'`
      write ++p
      edit `=stdpath('data') .. '/site/pack/packer/start/plugin-foo/lua/plugin-foo/bar.lua'`
      write ++p

      edit runtime/lua/foo/init.lua
      write ++p
      edit runtime/lua/foo/bar/init.lua
      write ++p

      edit %s/lua/runtime-foo/init.lua
      write ++p
      edit %s/lua/runtime-foo/bar.lua
      write ++p

      edit %s/general-foo/bar/init.lua
      write ++p
      edit %s/general-foo/bar/baz.lua
      write ++p
    ]]):format(temp_dir, temp_dir, temp_dir, temp_dir))
  end)

  it('finds module in current repo', function()
    command [[ edit runtime/lua/vim/_ftplugin/lua.lua ]]
    eq(repo_root .. '/runtime/lua/vim/_ftplugin/lua.lua', lua_includeexpr('vim._ftplugin.lua'))
    eq(repo_root .. '/runtime/lua/editorconfig.lua', lua_includeexpr('editorconfig'))
    eq(repo_root .. '/runtime/lua/foo/init.lua', lua_includeexpr('foo'))
    eq(repo_root .. '/runtime/lua/foo/bar/init.lua', lua_includeexpr('foo.bar'))
  end)

  it('finds module in packpath/start', function()
    eq(
      stdpath('data') .. '/site/pack/packer/start/plugin-foo/lua/plugin-foo/init.lua',
      lua_includeexpr('plugin-foo')
    )
    eq(
      stdpath('data') .. '/site/pack/packer/start/plugin-foo/lua/plugin-foo/bar.lua',
      lua_includeexpr('plugin-foo.bar')
    )
  end)

  it('finds module in $VIMRUNTIME', function()
    command('edit ' .. repo_root)
    eq(vimruntime() .. '/lua/vim/_ftplugin/lua.lua', lua_includeexpr('vim._ftplugin.lua'))
    eq(vimruntime() .. '/lua/editorconfig.lua', lua_includeexpr('editorconfig'))
  end)

  it('finds module in runtimepath', function()
    eq(stdpath('config') .. '/lua/user-foo/init.lua', lua_includeexpr('user-foo'))
    eq(stdpath('config') .. '/lua/user-foo/bar.lua', lua_includeexpr('user-foo.bar'))
    command('set rtp+=' .. temp_dir)
    eq(temp_dir .. '/lua/runtime-foo/init.lua', lua_includeexpr('runtime-foo'))
    eq(temp_dir .. '/lua/runtime-foo/bar.lua', lua_includeexpr('runtime-foo.bar'))
  end)

  it('non-Nvim-style Lua modules', function()
    command('cd ' .. temp_dir)
    eq(temp_dir .. '/general-foo/bar/init.lua', lua_includeexpr('general-foo.bar'))
    eq(temp_dir .. '/general-foo/bar/baz.lua', lua_includeexpr('general-foo.bar.baz'))
    command('cd -')
  end)
end)
