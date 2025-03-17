local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local exec_lua = n.exec_lua
local command = n.command
local eq = t.eq

---@param type string
---@return string
local function stdpath(type)
  return exec_lua(([[return vim.fs.normalize(vim.fn.stdpath("%s"))]]):format(type))
end

---@return string
local function vimruntime()
  return exec_lua [[ return vim.fs.normalize(vim.env.VIMRUNTIME) ]]
end

---@param module string
---@return string
local function lua_includeexpr(module)
  return exec_lua(([[return require('vim._ftplugin.lua').includeexpr("%s")]]):format(module))
end

local root = exec_lua [[ return vim.fs.normalize(vim.fn.getcwd()) ]]

describe("Lua 'includeexpr'", function()
  setup(n.clear)
  local temp_dir = t.tmpname(false)
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
    ]]):format(temp_dir, temp_dir))
  end)

  it('finds module in current repo', function()
    command [[ edit runtime/lua/vim/_ftplugin/lua.lua ]]
    eq(root .. '/runtime/lua/vim/_ftplugin/lua.lua', lua_includeexpr('vim._ftplugin.lua'))
    eq(root .. '/runtime/lua/editorconfig.lua', lua_includeexpr('editorconfig'))
    eq(root .. '/runtime/lua/foo/init.lua', lua_includeexpr('foo'))
    eq(root .. '/runtime/lua/foo/bar/init.lua', lua_includeexpr('foo.bar'))
  end)

  it('find module in packpath/start', function()
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
    command('edit ' .. root)
    eq(vimruntime() .. '/lua/vim/_ftplugin/lua.lua', lua_includeexpr('vim._ftplugin.lua'))
    eq(vimruntime() .. '/lua/editorconfig.lua', lua_includeexpr('editorconfig'))
  end)

  it('find module in runtimepath', function()
    eq(stdpath('config') .. '/lua/user-foo/init.lua', lua_includeexpr('user-foo'))
    eq(stdpath('config') .. '/lua/user-foo/bar.lua', lua_includeexpr('user-foo.bar'))
    command('set rtp+=' .. temp_dir)
    eq(temp_dir .. '/lua/runtime-foo/init.lua', lua_includeexpr('runtime-foo'))
    eq(temp_dir .. '/lua/runtime-foo/bar.lua', lua_includeexpr('runtime-foo.bar'))
  end)
end)
