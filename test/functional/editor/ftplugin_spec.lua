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

describe('ftplugin: vimdoc/help', function()
  setup(function()
    n.clear{
      args = {
        '+helptags $VIMRUNTIME/doc'
      }
    }
    command('enew')
    command('set filetype=help')
    -- XXX: hacky way to load the `help.lua` module.
    exec_lua([[
      _G.test_help = dofile(vim.fs.joinpath(vim.env.VIMRUNTIME, 'ftplugin/help.lua'))
    ]])
  end)

  before_each(function()
    command('enew')
    command('set filetype=help')
  end)

  it('scrub_tag()', function()
    local function scrub_tag(tag)
      return exec_lua([[return _G.test_help.scrub_tag(...)]], tag)
    end

    eq('b.a.z', scrub_tag('foo|b.a.z|buz||||biz'))
    eq('b.a.z', scrub_tag('foo|b.a.z'))
    eq('b.a.z', scrub_tag('|b.a.z|'))
    eq('b.a.z', scrub_tag(' |b.a.z| '))
    eq('b.a.z', scrub_tag(' "|b.a.z|" '))
    eq('vim.lsp.ClientConfig', scrub_tag('(`vim.lsp.ClientConfig`)'))
    eq('vim.lsp.ClientConfig', scrub_tag('vim.lsp.ClientConfig)`)'))
    eq('vim.lsp.ClientConfig', scrub_tag('(`vim.lsp.ClientConfig'))
    eq('vim.lsp.linked_editing_range.enable', scrub_tag('vim.lsp.linked_editing_range.enable(true,'))
    eq('vim.lsp.log.get_filename', scrub_tag('vim.lsp.log.get_filename())'))
    eq('vim.lsp.foldtext()', scrub_tag('|("vim.lsp.foldtext()")|'))
    eq('vim.lsp.foldtext', scrub_tag(scrub_tag('|("vim.lsp.foldtext()")|')))
    -- TODO: this one needs cursor postion to make a decision.
    -- eq('xx', scrub_tag("require('vim.lsp.log').set_format_func(vim.inspect)"))
  end)

  it('open_helptag() guesses the best tag near cursor', function()
    local function set_lines(text)
      exec_lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, ...)]], text)
    end
    local cursor = n.api.nvim_win_set_cursor
    local function open_helptag()
      local word = exec_lua([[return _G.test_help.open_helptag()]])
      local bufname = n.fn.fnamemodify(n.fn.bufname('%'), ':t')
      if n.fn.winnr('$') > 1 then
        n.command('close')
      end
      return { word, bufname }
    end

    set_lines {'some plain text'}
    cursor(0, {1, 5}) -- on 'plain'
    eq({'plain', 'syntax.txt'}, open_helptag())

    set_lines {':help command'}
    cursor(0, {1, 4})
    eq({':help', 'helphelp.txt'}, open_helptag())

    set_lines {' :help command'}
    cursor(0, {1, 5})
    eq({':help', 'helphelp.txt'}, open_helptag())

    set_lines {'v:version name'}
    cursor(0, {1, 5})
    eq({'v:version', 'vvars.txt'}, open_helptag())
    cursor(0, {1, 2})
    eq({'v:version', 'vvars.txt'}, open_helptag())

    set_lines {"See 'option' for more."}
    cursor(0, {1, 6}) -- on 'option'
    eq({"'option'", 'intro.txt'}, open_helptag())

    set_lines {':command-nargs'}
    cursor(0, {1, 7}) -- on 'nargs'
    eq({':command-nargs', 'map.txt'}, open_helptag())

    set_lines {'|("vim.lsp.foldtext()")|'}
    cursor(0, {1, 10})
    eq({'vim.lsp.foldtext()', 'lsp.txt'}, open_helptag())
  end)
end)
