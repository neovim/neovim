local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local eval = n.eval
local exec = n.exec
local fn = n.fn
local mkdir_p = n.mkdir_p
local rmdir = n.rmdir
local write_file = t.write_file

describe('runtime:', function()
  local plug_dir = 'Test_Plugin'
  local sep = n.get_pathsep()
  local init = 'dummy_init.lua'

  setup(function()
    io.open(init, 'w'):close() --  touch init file
    clear { args = { '-u', init } }
    exec('set rtp+=' .. plug_dir)
    exec([[
      set shell=doesnotexist
      set completeslash=slash
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
  end)

  describe('colors', function()
    local colorscheme_folder = plug_dir .. sep .. 'colors'
    before_each(function()
      mkdir_p(colorscheme_folder)
    end)

    it('lua colorschemes work and are included in cmdline completion', function()
      local colorscheme_file = table.concat({ colorscheme_folder, 'new_colorscheme.lua' }, sep)
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

      local pack_opt_dir = table.concat({ pack_dir, 'pack', 'some_name', 'opt' }, sep)
      local colors_opt_dir = table.concat({ pack_opt_dir, 'some_pack', 'colors' }, sep)
      mkdir_p(colors_opt_dir)

      local after_colorscheme_folder = table.concat({ plug_dir, 'after', 'colors' }, sep)
      mkdir_p(after_colorscheme_folder)
      exec('set rtp+=' .. plug_dir .. '/after')

      write_file(
        table.concat({ colors_opt_dir, 'new_colorscheme.lua' }, sep),
        [[vim.g.colorscheme = 'lua_pp']]
      )
      exec('colorscheme new_colorscheme')
      eq('lua_pp', eval('g:colorscheme'))

      write_file(
        table.concat({ colors_opt_dir, 'new_colorscheme.vim' }, sep),
        [[let g:colorscheme = 'vim_pp']]
      )
      exec('colorscheme new_colorscheme')
      eq('vim_pp', eval('g:colorscheme'))

      write_file(
        table.concat({ after_colorscheme_folder, 'new_colorscheme.lua' }, sep),
        [[vim.g.colorscheme = 'lua_rtp_after']]
      )
      exec('colorscheme new_colorscheme')
      eq('lua_rtp_after', eval('g:colorscheme'))

      write_file(
        table.concat({ after_colorscheme_folder, 'new_colorscheme.vim' }, sep),
        [[let g:colorscheme = 'vim_rtp_after']]
      )
      exec('colorscheme new_colorscheme')
      eq('vim_rtp_after', eval('g:colorscheme'))

      write_file(
        table.concat({ colorscheme_folder, 'new_colorscheme.lua' }, sep),
        [[vim.g.colorscheme = 'lua_rtp']]
      )
      exec('colorscheme new_colorscheme')
      eq('lua_rtp', eval('g:colorscheme'))

      write_file(
        table.concat({ colorscheme_folder, 'new_colorscheme.vim' }, sep),
        [[let g:colorscheme = 'vim_rtp']]
      )
      exec('colorscheme new_colorscheme')
      eq('vim_rtp', eval('g:colorscheme'))
    end)
  end)

  describe('compiler', function()
    local compiler_folder = table.concat({ plug_dir, 'compiler' }, sep)
    before_each(function()
      mkdir_p(compiler_folder)
    end)

    it('lua compilers work and are included in cmdline completion', function()
      local compiler_file = compiler_folder .. sep .. 'new_compiler.lua'
      write_file(compiler_file, [[vim.b.lua_compiler = 1]])

      eq({ 'new_compiler' }, fn.getcompletion('new_c', 'compiler'))
      eq({ 'compiler/new_compiler.lua' }, fn.getcompletion('compiler/new_c', 'runtime'))

      exec('compiler new_compiler')

      eq(1, eval('b:lua_compiler'))
    end)

    it("'rtp' order is respected", function()
      local after_compiler_folder = table.concat({ plug_dir, 'after', 'compiler' }, sep)
      mkdir_p(table.concat({ compiler_folder, 'new_compiler' }, sep))
      mkdir_p(table.concat({ after_compiler_folder, 'new_compiler' }, sep))
      exec('set rtp+=' .. plug_dir .. '/after')
      exec('let g:seq = ""')
      -- A .lua file is loaded after a .vim file if they only differ in extension.
      -- All files in after/compiler/ are loaded after all files in compiler/.
      write_file(table.concat({ compiler_folder, 'new_compiler.vim' }, sep), [[let g:seq ..= 'A']])
      write_file(
        table.concat({ compiler_folder, 'new_compiler.lua' }, sep),
        [[vim.g.seq = vim.g.seq .. 'B']]
      )
      write_file(
        table.concat({ after_compiler_folder, 'new_compiler.vim' }, sep),
        [[let g:seq ..= 'a']]
      )
      write_file(
        table.concat({ after_compiler_folder, 'new_compiler.lua' }, sep),
        [[vim.g.seq = vim.g.seq .. 'b']]
      )
      exec('compiler new_compiler')
      eq('ABab', eval('g:seq'))
    end)
  end)

  describe('ftplugin', function()
    local ftplugin_folder = table.concat({ plug_dir, 'ftplugin' }, sep)

    it('lua ftplugins work and are included in cmdline completion', function()
      mkdir_p(ftplugin_folder)
      local ftplugin_file = table.concat({ ftplugin_folder, 'new-ft.lua' }, sep)
      write_file(ftplugin_file, [[vim.b.lua_ftplugin = 1]])

      eq({ 'new-ft' }, fn.getcompletion('new-f', 'filetype'))
      eq({ 'ftplugin/new-ft.lua' }, fn.getcompletion('ftplugin/new-f', 'runtime'))

      exec [[set filetype=new-ft]]
      eq(1, eval('b:lua_ftplugin'))
    end)

    it("'rtp' order is respected", function()
      local after_ftplugin_folder = table.concat({ plug_dir, 'after', 'ftplugin' }, sep)
      mkdir_p(table.concat({ ftplugin_folder, 'new-ft' }, sep))
      mkdir_p(table.concat({ after_ftplugin_folder, 'new-ft' }, sep))
      exec('set rtp+=' .. plug_dir .. '/after')
      exec('let g:seq = ""')
      -- A .lua file is loaded after a .vim file if they only differ in extension.
      -- All files in after/ftplugin/ are loaded after all files in ftplugin/.
      write_file(table.concat({ ftplugin_folder, 'new-ft.vim' }, sep), [[let g:seq ..= 'A']])
      write_file(
        table.concat({ ftplugin_folder, 'new-ft.lua' }, sep),
        [[vim.g.seq = vim.g.seq .. 'B']]
      )
      write_file(table.concat({ ftplugin_folder, 'new-ft_a.vim' }, sep), [[let g:seq ..= 'C']])
      write_file(
        table.concat({ ftplugin_folder, 'new-ft_a.lua' }, sep),
        [[vim.g.seq = vim.g.seq .. 'D']]
      )
      write_file(table.concat({ ftplugin_folder, 'new-ft', 'a.vim' }, sep), [[let g:seq ..= 'E']])
      write_file(
        table.concat({ ftplugin_folder, 'new-ft', 'a.lua' }, sep),
        [[vim.g.seq = vim.g.seq .. 'F']]
      )
      write_file(table.concat({ after_ftplugin_folder, 'new-ft.vim' }, sep), [[let g:seq ..= 'a']])
      write_file(
        table.concat({ after_ftplugin_folder, 'new-ft.lua' }, sep),
        [[vim.g.seq = vim.g.seq .. 'b']]
      )
      write_file(
        table.concat({ after_ftplugin_folder, 'new-ft_a.vim' }, sep),
        [[let g:seq ..= 'c']]
      )
      write_file(
        table.concat({ after_ftplugin_folder, 'new-ft_a.lua' }, sep),
        [[vim.g.seq = vim.g.seq .. 'd']]
      )
      write_file(
        table.concat({ after_ftplugin_folder, 'new-ft', 'a.vim' }, sep),
        [[let g:seq ..= 'e']]
      )
      write_file(
        table.concat({ after_ftplugin_folder, 'new-ft', 'a.lua' }, sep),
        [[vim.g.seq = vim.g.seq .. 'f']]
      )
      exec('setfiletype new-ft')
      eq('ABCDEFabcdef', eval('g:seq'))
    end)

    it("'rtp' order is respected with 'fileignorecase'", function()
      exec('set fileignorecase')
      local after_ftplugin_folder = table.concat({ plug_dir, 'after', 'ftplugin' }, sep)
      mkdir_p(table.concat({ ftplugin_folder, 'new-ft' }, sep))
      mkdir_p(table.concat({ after_ftplugin_folder, 'new-ft' }, sep))
      exec('set rtp+=' .. plug_dir .. '/after')
      exec('let g:seq = ""')
      -- A .lua file is loaded after a .vim file if they only differ in extension.
      -- All files in after/ftplugin/ are loaded after all files in ftplugin/.
      write_file(table.concat({ ftplugin_folder, 'new-ft.VIM' }, sep), [[let g:seq ..= 'A']])
      write_file(
        table.concat({ ftplugin_folder, 'new-ft.LUA' }, sep),
        [[vim.g.seq = vim.g.seq .. 'B']]
      )
      write_file(table.concat({ ftplugin_folder, 'new-ft_a.vim' }, sep), [[let g:seq ..= 'C']])
      write_file(
        table.concat({ ftplugin_folder, 'new-ft_a.lua' }, sep),
        [[vim.g.seq = vim.g.seq .. 'D']]
      )
      write_file(table.concat({ ftplugin_folder, 'new-ft', 'a.VIM' }, sep), [[let g:seq ..= 'E']])
      write_file(
        table.concat({ ftplugin_folder, 'new-ft', 'a.LUA' }, sep),
        [[vim.g.seq = vim.g.seq .. 'F']]
      )
      write_file(table.concat({ after_ftplugin_folder, 'new-ft.vim' }, sep), [[let g:seq ..= 'a']])
      write_file(
        table.concat({ after_ftplugin_folder, 'new-ft.lua' }, sep),
        [[vim.g.seq = vim.g.seq .. 'b']]
      )
      write_file(
        table.concat({ after_ftplugin_folder, 'new-ft_a.VIM' }, sep),
        [[let g:seq ..= 'c']]
      )
      write_file(
        table.concat({ after_ftplugin_folder, 'new-ft_a.LUA' }, sep),
        [[vim.g.seq = vim.g.seq .. 'd']]
      )
      write_file(
        table.concat({ after_ftplugin_folder, 'new-ft', 'a.vim' }, sep),
        [[let g:seq ..= 'e']]
      )
      write_file(
        table.concat({ after_ftplugin_folder, 'new-ft', 'a.lua' }, sep),
        [[vim.g.seq = vim.g.seq .. 'f']]
      )
      exec('setfiletype new-ft')
      eq('ABCDEFabcdef', eval('g:seq'))
    end)
  end)

  describe('indent', function()
    local indent_folder = table.concat({ plug_dir, 'indent' }, sep)

    it('lua indents work and are included in cmdline completion', function()
      mkdir_p(indent_folder)
      local indent_file = table.concat({ indent_folder, 'new-ft.lua' }, sep)
      write_file(indent_file, [[vim.b.lua_indent = 1]])

      eq({ 'new-ft' }, fn.getcompletion('new-f', 'filetype'))
      eq({ 'indent/new-ft.lua' }, fn.getcompletion('indent/new-f', 'runtime'))

      exec [[set filetype=new-ft]]
      eq(1, eval('b:lua_indent'))
    end)

    it("'rtp' order is respected", function()
      local after_indent_folder = table.concat({ plug_dir, 'after', 'indent' }, sep)
      mkdir_p(table.concat({ indent_folder, 'new-ft' }, sep))
      mkdir_p(table.concat({ after_indent_folder, 'new-ft' }, sep))
      exec('set rtp+=' .. plug_dir .. '/after')
      exec('let g:seq = ""')
      -- A .lua file is loaded after a .vim file if they only differ in extension.
      -- All files in after/indent/ are loaded after all files in indent/.
      write_file(table.concat({ indent_folder, 'new-ft.vim' }, sep), [[let g:seq ..= 'A']])
      write_file(
        table.concat({ indent_folder, 'new-ft.lua' }, sep),
        [[vim.g.seq = vim.g.seq .. 'B']]
      )
      write_file(table.concat({ after_indent_folder, 'new-ft.vim' }, sep), [[let g:seq ..= 'a']])
      write_file(
        table.concat({ after_indent_folder, 'new-ft.lua' }, sep),
        [[vim.g.seq = vim.g.seq .. 'b']]
      )
      exec('setfiletype new-ft')
      eq('ABab', eval('g:seq'))
    end)
  end)

  describe('syntax', function()
    local syntax_folder = table.concat({ plug_dir, 'syntax' }, sep)

    before_each(function()
      mkdir_p(syntax_folder)
      local syntax_file = table.concat({ syntax_folder, 'my-lang.lua' }, sep)
      write_file(syntax_file, [[vim.b.current_syntax = 'my-lang']])
      exec([[let b:current_syntax = '']])
    end)

    it('loads lua syntaxes on filetype change', function()
      exec('set filetype=my-lang')
      eq('my-lang', eval('b:current_syntax'))
    end)

    it('loads lua syntaxes on syntax change', function()
      exec('set syntax=my-lang')
      eq('my-lang', eval('b:current_syntax'))
    end)

    it('loads lua syntaxes for :ownsyntax', function()
      exec('ownsyntax my-lang')
      eq('my-lang', eval('w:current_syntax'))
      eq('', eval('b:current_syntax'))
    end)

    it('lua syntaxes are included in cmdline completion', function()
      eq({ 'my-lang' }, fn.getcompletion('my-l', 'filetype'))
      eq({ 'my-lang' }, fn.getcompletion('my-l', 'syntax'))
      eq({ 'syntax/my-lang.lua' }, fn.getcompletion('syntax/my-l', 'runtime'))
    end)

    it("'rtp' order is respected", function()
      local after_syntax_folder = table.concat({ plug_dir, 'after', 'syntax' }, sep)
      mkdir_p(table.concat({ syntax_folder, 'my-lang' }, sep))
      mkdir_p(table.concat({ after_syntax_folder, 'my-lang' }, sep))
      exec('set rtp+=' .. plug_dir .. '/after')
      exec('let g:seq = ""')
      -- A .lua file is loaded after a .vim file if they only differ in extension.
      -- All files in after/syntax/ are loaded after all files in syntax/.
      write_file(table.concat({ syntax_folder, 'my-lang.vim' }, sep), [[let g:seq ..= 'A']])
      write_file(
        table.concat({ syntax_folder, 'my-lang.lua' }, sep),
        [[vim.g.seq = vim.g.seq .. 'B']]
      )
      write_file(table.concat({ syntax_folder, 'my-lang', 'a.vim' }, sep), [[let g:seq ..= 'C']])
      write_file(
        table.concat({ syntax_folder, 'my-lang', 'a.lua' }, sep),
        [[vim.g.seq = vim.g.seq .. 'D']]
      )
      write_file(table.concat({ after_syntax_folder, 'my-lang.vim' }, sep), [[let g:seq ..= 'a']])
      write_file(
        table.concat({ after_syntax_folder, 'my-lang.lua' }, sep),
        [[vim.g.seq = vim.g.seq .. 'b']]
      )
      write_file(
        table.concat({ after_syntax_folder, 'my-lang', 'a.vim' }, sep),
        [[let g:seq ..= 'c']]
      )
      write_file(
        table.concat({ after_syntax_folder, 'my-lang', 'a.lua' }, sep),
        [[vim.g.seq = vim.g.seq .. 'd']]
      )
      exec('setfiletype my-lang')
      eq('ABCDabcd', eval('g:seq'))
    end)
  end)

  describe('spell', function()
    it("loads spell/LANG.{vim,lua} respecting 'rtp' order", function()
      local spell_folder = table.concat({ plug_dir, 'spell' }, sep)
      local after_spell_folder = table.concat({ plug_dir, 'after', 'spell' }, sep)
      mkdir_p(table.concat({ spell_folder, 'Xtest' }, sep))
      mkdir_p(table.concat({ after_spell_folder, 'Xtest' }, sep))
      exec('set rtp+=' .. plug_dir .. '/after')
      exec('let g:seq = ""')
      -- A .lua file is loaded after a .vim file if they only differ in extension.
      -- All files in after/spell/ are loaded after all files in spell/.
      write_file(table.concat({ spell_folder, 'Xtest.vim' }, sep), [[let g:seq ..= 'A']])
      write_file(table.concat({ spell_folder, 'Xtest.lua' }, sep), [[vim.g.seq = vim.g.seq .. 'B']])
      write_file(table.concat({ after_spell_folder, 'Xtest.vim' }, sep), [[let g:seq ..= 'a']])
      write_file(
        table.concat({ after_spell_folder, 'Xtest.lua' }, sep),
        [[vim.g.seq = vim.g.seq .. 'b']]
      )
      exec('set spelllang=Xtest')
      eq('ABab', eval('g:seq'))
    end)
  end)

  it('cpp ftplugin loads c ftplugin #29053', function()
    eq('', eval('&commentstring'))
    eq('', eval('&omnifunc'))
    exec('edit file.cpp')
    eq('/*%s*/', eval('&commentstring'))
    eq('ccomplete#Complete', eval('&omnifunc'))
  end)
end)
