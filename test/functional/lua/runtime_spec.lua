local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local exec = helpers.exec
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
  end)

  teardown(function()
    os.remove(init)
  end)

  before_each(function()
    mkdir_p(plug_dir)
  end)

  after_each(function()
    rmdir(plug_dir)
  end)

  describe('colors', function()
    local colorscheme_folder = plug_dir .. sep .. 'colors'

    it('loads lua colorscheme', function()
      local colorscheme_file = colorscheme_folder .. sep .. 'new_colorscheme.lua'
      mkdir_p(colorscheme_folder)
      write_file(colorscheme_file, [[vim.g.lua_colorscheme = 1]])

      exec('colorscheme new_colorscheme')

      eq(1, eval('g:lua_colorscheme'))
      rmdir(colorscheme_folder)
    end)

    it('loads vim colorscheme when both lua and vim version exist', function()
      local colorscheme_file = colorscheme_folder .. sep .. 'new_colorscheme'
      mkdir_p(colorscheme_folder)
      write_file(colorscheme_file..'.vim', [[let g:colorscheme = 'vim']])
      write_file(colorscheme_file..'.lua', [[vim.g.colorscheme = 'lua']])

      exec('colorscheme new_colorscheme')

      eq('vim', eval('g:colorscheme'))
      rmdir(colorscheme_folder)
    end)
  end)

  describe('compiler', function()
    local compiler_folder = plug_dir .. sep .. 'compiler'

    it('loads lua compilers', function()
      local compiler_file = compiler_folder .. sep .. 'new_compiler.lua'
      mkdir_p(compiler_folder)
      write_file(compiler_file, [[vim.g.lua_compiler = 1]])

      exec('compiler new_compiler')

      eq(1, eval('g:lua_compiler'))
      rmdir(compiler_folder)
    end)

    it('loads vim compilers when both lua and vim version exist', function()
      local compiler_file = compiler_folder .. sep .. 'new_compiler'
      mkdir_p(compiler_folder)
      write_file(compiler_file..'.vim', [[let g:compiler = 'vim']])
      write_file(compiler_file..'.lua', [[vim.g.compiler = 'lua']])

      exec('compiler new_compiler')

      eq('vim', eval('g:compiler'))
      rmdir(compiler_folder)
    end)
  end)

  describe('ftplugin', function()
    local ftplugin_folder = table.concat({plug_dir, 'ftplugin'}, sep)

    it('loads lua ftplugins', function()
      local ftplugin_file = table.concat({ftplugin_folder , 'new-ft.lua'}, sep)
      mkdir_p(ftplugin_folder)
      write_file(ftplugin_file , [[vim.g.lua_ftplugin = 1]])

      exec [[set filetype=new-ft]]
      eq(1, eval('g:lua_ftplugin'))
      rmdir(ftplugin_folder)
    end)
  end)

  describe('indent', function()
    local indent_folder = table.concat({plug_dir, 'indent'}, sep)

    it('loads lua indents', function()
      local indent_file = table.concat({indent_folder , 'new-ft.lua'}, sep)
      mkdir_p(indent_folder)
      write_file(indent_file , [[vim.g.lua_indent = 1]])

      exec [[set filetype=new-ft]]
      eq(1, eval('g:lua_indent'))
      rmdir(indent_folder)
    end)
  end)

  describe('syntax', function()
    local syntax_folder = table.concat({plug_dir, 'syntax'}, sep)

    it('loads lua syntaxes on filetype change', function()
      local syntax_file = table.concat({syntax_folder , 'my-lang.lua'}, sep)
      mkdir_p(syntax_folder)
      write_file(syntax_file , [[vim.g.lua_syntax = 1]])

      exec('set filetype=my-lang')
      eq(1, eval('g:lua_syntax'))
      rmdir(syntax_folder)
    end)

    it('loads lua syntaxes on syntax change', function()
      local syntax_file = table.concat({syntax_folder , 'my-lang.lua'}, sep)
      mkdir_p(syntax_folder)
      write_file(syntax_file , [[vim.g.lua_syntax = 5]])

      exec('set syntax=my-lang')
      eq(5, eval('g:lua_syntax'))
      rmdir(syntax_folder)
    end)
  end)

end)

