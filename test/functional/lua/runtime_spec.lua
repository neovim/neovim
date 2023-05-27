local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local exec = helpers.exec
local funcs = helpers.funcs
local mkdir_p = helpers.mkdir_p
local rmdir = helpers.rmdir
local write_file = helpers.write_file

describe('runtime:', function()
  local plug_dir = 'Test_Plugin'
  local sep = helpers.get_pathsep()
  local init = 'dummy_init.lua'

  setup(function()
    io.open(init, 'w'):close()  --  touch init file
    clear{args = {'-u', init}}
    exec('set rtp+=' .. plug_dir)
    exec('set completeslash=slash')
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

    it('loads lua colorscheme', function()
      local colorscheme_file = colorscheme_folder .. sep .. 'new_colorscheme.lua'
      write_file(colorscheme_file, [[vim.g.lua_colorscheme = 1]])

      eq({'new_colorscheme'}, funcs.getcompletion('new_c', 'color'))
      eq({'colors/new_colorscheme.lua'}, funcs.getcompletion('colors/new_c', 'runtime'))

      exec('colorscheme new_colorscheme')

      eq(1, eval('g:lua_colorscheme'))
    end)

    it('loads vim colorscheme when both lua and vim version exist', function()
      local colorscheme_file = colorscheme_folder .. sep .. 'new_colorscheme'
      write_file(colorscheme_file..'.vim', [[let g:colorscheme = 'vim']])
      write_file(colorscheme_file..'.lua', [[vim.g.colorscheme = 'lua']])

      exec('colorscheme new_colorscheme')

      eq('vim', eval('g:colorscheme'))
    end)

    it("loads lua colorscheme in 'rtp' if vim version only exists in 'pp' #23724", function()
      local pack_dir = 'Test_Pack'
      mkdir_p(pack_dir)
      finally(function()
        rmdir(pack_dir)
      end)
      exec('set pp+=' .. pack_dir)

      local pack_opt_dir = pack_dir .. sep .. 'pack' .. sep .. 'some_name' .. sep .. 'opt'
      local colors_opt_dir = pack_opt_dir .. sep .. 'some_pack' .. sep .. 'colors'
      mkdir_p(colors_opt_dir)

      local rtp_colorscheme_file = colorscheme_folder .. sep .. 'new_colorscheme'
      local pp_opt_colorscheme_file = colors_opt_dir .. sep .. 'new_colorscheme'

      write_file(pp_opt_colorscheme_file .. '.lua', [[vim.g.colorscheme = 'lua_pp']])
      exec('colorscheme new_colorscheme')
      eq('lua_pp', eval('g:colorscheme'))

      write_file(pp_opt_colorscheme_file .. '.vim', [[let g:colorscheme = 'vim_pp']])
      exec('colorscheme new_colorscheme')
      eq('vim_pp', eval('g:colorscheme'))

      write_file(rtp_colorscheme_file .. '.lua', [[vim.g.colorscheme = 'lua_rtp']])
      exec('colorscheme new_colorscheme')
      eq('lua_rtp', eval('g:colorscheme'))

      write_file(rtp_colorscheme_file .. '.vim', [[let g:colorscheme = 'vim_rtp']])
      exec('colorscheme new_colorscheme')
      eq('vim_rtp', eval('g:colorscheme'))
    end)
  end)

  describe('compiler', function()
    local compiler_folder = plug_dir .. sep .. 'compiler'
    before_each(function()
      mkdir_p(compiler_folder)
    end)

    it('loads lua compilers', function()
      local compiler_file = compiler_folder .. sep .. 'new_compiler.lua'
      write_file(compiler_file, [[vim.b.lua_compiler = 1]])

      eq({'new_compiler'}, funcs.getcompletion('new_c', 'compiler'))
      eq({'compiler/new_compiler.lua'}, funcs.getcompletion('compiler/new_c', 'runtime'))

      exec('compiler new_compiler')

      eq(1, eval('b:lua_compiler'))
    end)

    it('loads vim compilers when both lua and vim version exist', function()
      local compiler_file = compiler_folder .. sep .. 'new_compiler'
      write_file(compiler_file..'.vim', [[let b:compiler = 'vim']])
      write_file(compiler_file..'.lua', [[vim.b.compiler = 'lua']])

      exec('compiler new_compiler')

      eq('vim', eval('b:compiler'))
    end)
  end)

  describe('ftplugin', function()
    local ftplugin_folder = table.concat({plug_dir, 'ftplugin'}, sep)

    it('loads lua ftplugins', function()
      mkdir_p(ftplugin_folder)
      local ftplugin_file = table.concat({ftplugin_folder , 'new-ft.lua'}, sep)
      write_file(ftplugin_file , [[vim.b.lua_ftplugin = 1]])

      eq({'new-ft'}, funcs.getcompletion('new-f', 'filetype'))
      eq({'ftplugin/new-ft.lua'}, funcs.getcompletion('ftplugin/new-f', 'runtime'))

      exec [[set filetype=new-ft]]
      eq(1, eval('b:lua_ftplugin'))
    end)
  end)

  describe('indent', function()
    local indent_folder = table.concat({plug_dir, 'indent'}, sep)

    it('loads lua indents', function()
      mkdir_p(indent_folder)
      local indent_file = table.concat({indent_folder , 'new-ft.lua'}, sep)
      write_file(indent_file , [[vim.b.lua_indent = 1]])

      eq({'new-ft'}, funcs.getcompletion('new-f', 'filetype'))
      eq({'indent/new-ft.lua'}, funcs.getcompletion('indent/new-f', 'runtime'))

      exec [[set filetype=new-ft]]
      eq(1, eval('b:lua_indent'))
    end)
  end)

  describe('syntax', function()
    local syntax_folder = table.concat({plug_dir, 'syntax'}, sep)

    before_each(function()
      mkdir_p(syntax_folder)
      local syntax_file = table.concat({syntax_folder , 'my-lang.lua'}, sep)
      write_file(syntax_file , [[vim.b.current_syntax = 'my-lang']])
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
      eq({'my-lang'}, funcs.getcompletion('my-l', 'filetype'))
      eq({'my-lang'}, funcs.getcompletion('my-l', 'syntax'))
      eq({'syntax/my-lang.lua'}, funcs.getcompletion('syntax/my-l', 'runtime'))
    end)
  end)

  describe('spell', function()
    local spell_folder = table.concat({plug_dir, 'spell'}, sep)

    it('loads spell/LANG.{vim,lua}', function()
      mkdir_p(spell_folder)
      local spell_vim = table.concat({spell_folder , 'Xtest.vim'}, sep)
      write_file(spell_vim , [[let b:spell_vim = 1]])
      local spell_lua = table.concat({spell_folder , 'Xtest.lua'}, sep)
      write_file(spell_lua , [[vim.b.spell_lua = 1]])
      exec('set spelllang=Xtest')
      eq(1, eval('b:spell_vim'))
      eq(1, eval('b:spell_lua'))
    end)
  end)

end)

