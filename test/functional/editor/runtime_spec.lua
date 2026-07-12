local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local eval = n.eval
local exec = n.exec
local api = n.api
local fn = n.fn
local mkdir_p = n.mkdir_p
local rmdir = n.rmdir
local write_file = t.write_file

describe('runtime:', function()
  local plug_dir = 'Test_Plugin'
  local init = 'dummy_init.lua'

  -- All test cases below use the same Nvim instance.
  setup(function()
    io.open(init, 'w'):close() --  touch init file
    clear({ args = { '-u', init } })
    exec('set rtp+=' .. plug_dir)
    exec([[
      set shell=doesnotexist
      if exists('+completeslash')
        set completeslash=slash
      endif
      set isfname+=(,)
    ]])
  end)

  teardown(function()
    os.remove(init)
  end)

  before_each(function()
    mkdir_p(plug_dir)
  end)

  after_each(function()
    rmdir(plug_dir)
    exec('bwipe!')
    exec('set rtp& pp&')
    exec('set rtp+=' .. plug_dir)
  end)

  describe('colors', function()
    local colorscheme_folder = ('%s/colors'):format(plug_dir)
    before_each(function()
      mkdir_p(colorscheme_folder)
    end)

    it('Lua colorschemes work and are included in cmdline completion', function()
      local colorscheme_file = ('%s/new_colorscheme.lua'):format(colorscheme_folder)
      write_file(colorscheme_file, [[vim.g.lua_colorscheme = 1]])

      eq({ 'new_colorscheme' }, fn.getcompletion('new_c', 'color'))
      eq({ 'colors/new_colorscheme.lua' }, fn.getcompletion('colors/new_c', 'runtime'))

      exec('colorscheme new_colorscheme')

      eq(1, eval('g:lua_colorscheme'))
    end)

    it("'rtp'/'pp' order is respected", function()
      local pack_dir = 'Test_Pack'
      mkdir_p(pack_dir)
      finally(function()
        rmdir(pack_dir)
      end)
      exec('set pp+=' .. pack_dir)

      local pack_opt_dir = ('%s/pack/some_name/opt'):format(pack_dir)
      local colors_opt_dir = ('%s/some_pack/colors'):format(pack_opt_dir)
      mkdir_p(colors_opt_dir)

      local after_colorscheme_folder = ('%s/after/colors'):format(plug_dir)
      mkdir_p(after_colorscheme_folder)
      exec('set rtp+=' .. plug_dir .. '/after')

      write_file(
        ('%s/new_colorscheme.lua'):format(colors_opt_dir),
        [[vim.g.colorscheme = 'lua_pp']]
      )
      exec('colorscheme new_colorscheme')
      eq('lua_pp', eval('g:colorscheme'))

      write_file(
        ('%s/new_colorscheme.vim'):format(colors_opt_dir),
        [[let g:colorscheme = 'vim_pp']]
      )
      exec('colorscheme new_colorscheme')
      eq('vim_pp', eval('g:colorscheme'))

      write_file(
        ('%s/new_colorscheme.lua'):format(after_colorscheme_folder),
        [[vim.g.colorscheme = 'lua_rtp_after']]
      )
      exec('colorscheme new_colorscheme')
      eq('lua_rtp_after', eval('g:colorscheme'))

      write_file(
        ('%s/new_colorscheme.vim'):format(after_colorscheme_folder),
        [[let g:colorscheme = 'vim_rtp_after']]
      )
      exec('colorscheme new_colorscheme')
      eq('vim_rtp_after', eval('g:colorscheme'))

      write_file(
        ('%s/new_colorscheme.lua'):format(colorscheme_folder),
        [[vim.g.colorscheme = 'lua_rtp']]
      )
      exec('colorscheme new_colorscheme')
      eq('lua_rtp', eval('g:colorscheme'))

      write_file(
        ('%s/new_colorscheme.vim'):format(colorscheme_folder),
        [[let g:colorscheme = 'vim_rtp']]
      )
      exec('colorscheme new_colorscheme')
      eq('vim_rtp', eval('g:colorscheme'))
    end)
  end)

  describe('compiler', function()
    local compiler_folder = ('%s/compiler'):format(plug_dir)
    before_each(function()
      mkdir_p(compiler_folder)
    end)

    it('Lua compilers work and are included in cmdline completion', function()
      local compiler_file = ('%s/new_compiler.lua'):format(compiler_folder)
      write_file(compiler_file, [[vim.b.lua_compiler = 1]])

      eq({ 'new_compiler' }, fn.getcompletion('new_c', 'compiler'))
      eq({ 'compiler/new_compiler.lua' }, fn.getcompletion('compiler/new_c', 'runtime'))

      exec('compiler new_compiler')

      eq(1, eval('b:lua_compiler'))
    end)

    it("'rtp' order is respected", function()
      local after_compiler_folder = ('%s/after/compiler'):format(plug_dir)
      mkdir_p(('%s/new_compiler'):format(compiler_folder))
      mkdir_p(('%s/new_compiler'):format(after_compiler_folder))
      exec('set rtp+=' .. plug_dir .. '/after')
      exec('let g:seq = ""')
      -- A .lua file is loaded after a .vim file if they only differ in extension.
      -- All files in after/compiler/ are loaded after all files in compiler/.
      write_file(('%s/new_compiler.vim'):format(compiler_folder), [[let g:seq ..= 'A']])
      write_file(('%s/new_compiler.lua'):format(compiler_folder), [[vim.g.seq = vim.g.seq .. 'B']])
      write_file(('%s/new_compiler.vim'):format(after_compiler_folder), [[let g:seq ..= 'a']])
      write_file(
        ('%s/new_compiler.lua'):format(after_compiler_folder),
        [[vim.g.seq = vim.g.seq .. 'b']]
      )
      exec('compiler new_compiler')
      eq('ABab', eval('g:seq'))
    end)
  end)

  describe('ftplugin', function()
    local ftplugin_folder = ('%s/ftplugin'):format(plug_dir)

    it('Lua ftplugins work and are included in cmdline completion', function()
      mkdir_p(ftplugin_folder)
      local ftplugin_file = ('%s/new-ft.lua'):format(ftplugin_folder)
      write_file(ftplugin_file, [[vim.b.lua_ftplugin = 1]])

      eq({ 'new-ft' }, fn.getcompletion('new-f', 'filetype'))
      eq({ 'ftplugin/new-ft.lua' }, fn.getcompletion('ftplugin/new-f', 'runtime'))

      exec [[set filetype=new-ft]]
      eq(1, eval('b:lua_ftplugin'))
    end)

    it("'rtp' order is respected", function()
      local after_ftplugin_folder = ('%s/after/ftplugin'):format(plug_dir)
      mkdir_p(('%s/new-ft'):format(ftplugin_folder))
      mkdir_p(('%s/new-ft'):format(after_ftplugin_folder))
      exec('set rtp+=' .. plug_dir .. '/after')
      exec('let g:seq = ""')
      -- A .lua file is loaded after a .vim file if they only differ in extension.
      -- All files in after/ftplugin/ are loaded after all files in ftplugin/.
      write_file(('%s/new-ft.vim'):format(ftplugin_folder), [[let g:seq ..= 'A']])
      write_file(('%s/new-ft.lua'):format(ftplugin_folder), [[vim.g.seq = vim.g.seq .. 'B']])
      write_file(('%s/new-ft_a.vim'):format(ftplugin_folder), [[let g:seq ..= 'C']])
      write_file(('%s/new-ft_a.lua'):format(ftplugin_folder), [[vim.g.seq = vim.g.seq .. 'D']])
      write_file(('%s/new-ft/a.vim'):format(ftplugin_folder), [[let g:seq ..= 'E']])
      write_file(('%s/new-ft/a.lua'):format(ftplugin_folder), [[vim.g.seq = vim.g.seq .. 'F']])
      write_file(('%s/new-ft.vim'):format(after_ftplugin_folder), [[let g:seq ..= 'a']])
      write_file(('%s/new-ft.lua'):format(after_ftplugin_folder), [[vim.g.seq = vim.g.seq .. 'b']])
      write_file(('%s/new-ft_a.vim'):format(after_ftplugin_folder), [[let g:seq ..= 'c']])
      write_file(
        ('%s/new-ft_a.lua'):format(after_ftplugin_folder),
        [[vim.g.seq = vim.g.seq .. 'd']]
      )
      write_file(('%s/new-ft/a.vim'):format(after_ftplugin_folder), [[let g:seq ..= 'e']])
      write_file(
        ('%s/new-ft/a.lua'):format(after_ftplugin_folder),
        [[vim.g.seq = vim.g.seq .. 'f']]
      )
      exec('setfiletype new-ft')
      eq('ABCDEFabcdef', eval('g:seq'))
    end)

    it("'rtp' order is respected with 'fileignorecase'", function()
      exec('set fileignorecase')
      local after_ftplugin_folder = ('%s/after/ftplugin'):format(plug_dir)
      mkdir_p(('%s/new-ft'):format(ftplugin_folder))
      mkdir_p(('%s/new-ft'):format(after_ftplugin_folder))
      exec('set rtp+=' .. plug_dir .. '/after')
      exec('let g:seq = ""')
      -- A .lua file is loaded after a .vim file if they only differ in extension.
      -- All files in after/ftplugin/ are loaded after all files in ftplugin/.
      write_file(('%s/new-ft.VIM'):format(ftplugin_folder), [[let g:seq ..= 'A']])
      write_file(('%s/new-ft.LUA'):format(ftplugin_folder), [[vim.g.seq = vim.g.seq .. 'B']])
      write_file(('%s/new-ft_a.vim'):format(ftplugin_folder), [[let g:seq ..= 'C']])
      write_file(('%s/new-ft_a.lua'):format(ftplugin_folder), [[vim.g.seq = vim.g.seq .. 'D']])
      write_file(('%s/new-ft/a.VIM'):format(ftplugin_folder), [[let g:seq ..= 'E']])
      write_file(('%s/new-ft/a.LUA'):format(ftplugin_folder), [[vim.g.seq = vim.g.seq .. 'F']])
      write_file(('%s/new-ft.vim'):format(after_ftplugin_folder), [[let g:seq ..= 'a']])
      write_file(('%s/new-ft.lua'):format(after_ftplugin_folder), [[vim.g.seq = vim.g.seq .. 'b']])
      write_file(('%s/new-ft_a.VIM'):format(after_ftplugin_folder), [[let g:seq ..= 'c']])
      write_file(
        ('%s/new-ft_a.LUA'):format(after_ftplugin_folder),
        [[vim.g.seq = vim.g.seq .. 'd']]
      )
      write_file(('%s/new-ft/a.vim'):format(after_ftplugin_folder), [[let g:seq ..= 'e']])
      write_file(
        ('%s/new-ft/a.lua'):format(after_ftplugin_folder),
        [[vim.g.seq = vim.g.seq .. 'f']]
      )
      exec('setfiletype new-ft')
      eq('ABCDEFabcdef', eval('g:seq'))
    end)
  end)

  describe('indent', function()
    local indent_folder = ('%s/indent'):format(plug_dir)

    it('Lua indents work and are included in cmdline completion', function()
      mkdir_p(indent_folder)
      local indent_file = ('%s/new-ft.lua'):format(indent_folder)
      write_file(indent_file, [[vim.b.lua_indent = 1]])

      eq({ 'new-ft' }, fn.getcompletion('new-f', 'filetype'))
      eq({ 'indent/new-ft.lua' }, fn.getcompletion('indent/new-f', 'runtime'))

      exec [[set filetype=new-ft]]
      eq(1, eval('b:lua_indent'))
    end)

    it("'rtp' order is respected", function()
      local after_indent_folder = ('%s/after/indent'):format(plug_dir)
      mkdir_p(('%s/new-ft'):format(indent_folder))
      mkdir_p(('%s/new-ft'):format(after_indent_folder))
      exec('set rtp+=' .. plug_dir .. '/after')
      exec('let g:seq = ""')
      -- A .lua file is loaded after a .vim file if they only differ in extension.
      -- All files in after/indent/ are loaded after all files in indent/.
      write_file(('%s/new-ft.vim'):format(indent_folder), [[let g:seq ..= 'A']])
      write_file(('%s/new-ft.lua'):format(indent_folder), [[vim.g.seq = vim.g.seq .. 'B']])
      write_file(('%s/new-ft.vim'):format(after_indent_folder), [[let g:seq ..= 'a']])
      write_file(('%s/new-ft.lua'):format(after_indent_folder), [[vim.g.seq = vim.g.seq .. 'b']])
      exec('setfiletype new-ft')
      eq('ABab', eval('g:seq'))
    end)
  end)

  describe('syntax', function()
    local syntax_folder = ('%s/syntax'):format(plug_dir)

    before_each(function()
      mkdir_p(syntax_folder)
      local syntax_file = ('%s/my-lang.lua'):format(syntax_folder)
      write_file(syntax_file, [[vim.b.current_syntax = 'my-lang']])
      exec([[let b:current_syntax = '']])
    end)

    it('loads Lua syntaxes on filetype change', function()
      exec('set filetype=my-lang')
      eq('my-lang', eval('b:current_syntax'))
    end)

    it('loads Lua syntaxes on syntax change', function()
      exec('set syntax=my-lang')
      eq('my-lang', eval('b:current_syntax'))
    end)

    it('loads Lua syntaxes for :ownsyntax', function()
      exec('ownsyntax my-lang')
      eq('my-lang', eval('w:current_syntax'))
      eq('', eval('b:current_syntax'))
    end)

    it('Lua syntaxes are included in cmdline completion', function()
      eq({ 'my-lang' }, fn.getcompletion('my-l', 'filetype'))
      eq({ 'my-lang' }, fn.getcompletion('my-l', 'syntax'))
      eq({ 'syntax/my-lang.lua' }, fn.getcompletion('syntax/my-l', 'runtime'))
    end)

    it("'rtp' order is respected", function()
      local after_syntax_folder = ('%s/after/syntax'):format(plug_dir)
      mkdir_p(('%s/my-lang'):format(syntax_folder))
      mkdir_p(('%s/my-lang'):format(after_syntax_folder))
      exec('set rtp+=' .. plug_dir .. '/after')
      exec('let g:seq = ""')
      -- A .lua file is loaded after a .vim file if they only differ in extension.
      -- All files in after/syntax/ are loaded after all files in syntax/.
      write_file(('%s/my-lang.vim'):format(syntax_folder), [[let g:seq ..= 'A']])
      write_file(('%s/my-lang.lua'):format(syntax_folder), [[vim.g.seq = vim.g.seq .. 'B']])
      write_file(('%s/my-lang/a.vim'):format(syntax_folder), [[let g:seq ..= 'C']])
      write_file(('%s/my-lang/a.lua'):format(syntax_folder), [[vim.g.seq = vim.g.seq .. 'D']])
      write_file(('%s/my-lang.vim'):format(after_syntax_folder), [[let g:seq ..= 'a']])
      write_file(('%s/my-lang.lua'):format(after_syntax_folder), [[vim.g.seq = vim.g.seq .. 'b']])
      write_file(('%s/my-lang/a.vim'):format(after_syntax_folder), [[let g:seq ..= 'c']])
      write_file(('%s/my-lang/a.lua'):format(after_syntax_folder), [[vim.g.seq = vim.g.seq .. 'd']])
      exec('setfiletype my-lang')
      eq('ABCDabcd', eval('g:seq'))
    end)
  end)

  describe('spell', function()
    it("loads spell/LANG.{vim,lua} respecting 'rtp' order", function()
      local spell_folder = ('%s/spell'):format(plug_dir)
      local after_spell_folder = ('%s/after/spell'):format(plug_dir)
      mkdir_p(('%s/Xtest'):format(spell_folder))
      mkdir_p(('%s/Xtest'):format(after_spell_folder))
      exec('set rtp+=' .. plug_dir .. '/after')
      exec('let g:seq = ""')
      -- A .lua file is loaded after a .vim file if they only differ in extension.
      -- All files in after/spell/ are loaded after all files in spell/.
      write_file(('%s/Xtest.vim'):format(spell_folder), [[let g:seq ..= 'A']])
      write_file(('%s/Xtest.lua'):format(spell_folder), [[vim.g.seq = vim.g.seq .. 'B']])
      write_file(('%s/Xtest.vim'):format(after_spell_folder), [[let g:seq ..= 'a']])
      write_file(('%s/Xtest.lua'):format(after_spell_folder), [[vim.g.seq = vim.g.seq .. 'b']])
      exec('set spelllang=Xtest')
      eq('ABab', eval('g:seq'))
    end)
  end)

  it('Lua file loaded by :runtime has proper script ID #32598', function()
    local test_file = 'Xtest_runtime_cmd.lua'
    write_file(
      ('%s/%s'):format(plug_dir, test_file),
      [[
      vim.g.script_id = tonumber(vim.fn.expand('<SID>'):match('<SNR>(%d+)_'))
      vim.o.mouse = 'nv'
    ]]
    )
    exec('runtime ' .. test_file)
    local expected_sid = fn.getscriptinfo({ name = test_file })[1].sid
    local sid = api.nvim_get_var('script_id')
    eq(expected_sid, sid)
    eq(sid, api.nvim_get_option_info2('mouse', {}).last_set_sid)
  end)

  it('cpp ftplugin loads c ftplugin #29053', function()
    eq('', eval('&commentstring'))
    eq('', eval('&omnifunc'))
    exec('edit file.cpp')
    eq('// %s', eval('&commentstring'))
    eq('ccomplete#Complete', eval('&omnifunc'))
  end)
end)
