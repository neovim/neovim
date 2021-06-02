local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local exec = helpers.exec
local mkdir_p = helpers.mkdir_p
local rmdir = helpers.rmdir
local write_file = helpers.write_file

describe('runtime:', function()
  local xhome = 'Xhome'
  local pathsep = helpers.get_pathsep()
  local xconfig = xhome .. pathsep .. 'Xconfig'

  before_each(function()
    clear()
    mkdir_p(xconfig .. pathsep .. 'nvim')
  end)

  after_each(function()
    rmdir(xhome)
  end)

  describe('plugin', function()
    before_each(clear)
    it('loads plugin/*.lua from XDG config home', function()
      local plugin_folder_path = table.concat({xconfig, 'nvim', 'plugin'}, pathsep)
      local plugin_file_path = table.concat({plugin_folder_path, 'plugin.lua'}, pathsep)
      mkdir_p(plugin_folder_path)
      write_file(plugin_file_path, [[ vim.g.lua_plugin = 1 ]])

      clear{ args_rm={'-u' }, env={ XDG_CONFIG_HOME=xconfig }}

      eq(1, eval('g:lua_plugin'))
      rmdir(plugin_folder_path)
    end)


    it('loads plugin/*.lua from start plugins', function()
      local plugin_path = table.concat({xconfig, 'nvim', 'pack', 'catagory',
      'start', 'test_plugin'}, pathsep)
      local plugin_folder_path = table.concat({plugin_path, 'plugin'}, pathsep)
      local plugin_file_path = table.concat({plugin_folder_path, 'plugin.lua'},
      pathsep)
      mkdir_p(plugin_folder_path)
      write_file(plugin_file_path, [[vim.g.lua_plugin = 2]])

      clear{ args_rm={'-u' }, env={ XDG_CONFIG_HOME=xconfig }}

      eq(2, eval('g:lua_plugin'))
      rmdir(plugin_path)
    end)
  end)

  describe('colors', function()
    before_each(clear)
    it('loads lua colorscheme', function()
      local colorscheme_folder = table.concat({xconfig, 'nvim', 'colors'},
                                                   pathsep)
      local colorscheme_file = table.concat({colorscheme_folder, 'new_colorscheme.lua'},
                                            pathsep)
      mkdir_p(colorscheme_folder)
      write_file(colorscheme_file, [[vim.g.lua_colorscheme = 1]])

      clear{ args_rm={'-' }, env={ XDG_CONFIG_HOME=xconfig }}
      exec('colorscheme new_colorscheme')

      eq(1, eval('g:lua_colorscheme'))
      rmdir(colorscheme_folder)
    end)

    it('loads vim colorscheme when both lua and vim version exist', function()
      local colorscheme_folder = table.concat({xconfig, 'nvim', 'colors'},
                                                   pathsep)
      local colorscheme_file = table.concat({colorscheme_folder, 'new_colorscheme'},
                                            pathsep)
      mkdir_p(colorscheme_folder)
      write_file(colorscheme_file..'.vim', [[let g:colorscheme = 'vim']])
      write_file(colorscheme_file..'.lua', [[vim.g.colorscheme = 'lua']])

      clear{ args_rm={'-u' }, env={ XDG_CONFIG_HOME=xconfig }}
      exec('colorscheme new_colorscheme')

      eq('vim', eval('g:colorscheme'))
      rmdir(colorscheme_folder)
    end)
  end)

  describe('compiler', function()
    local compiler_folder = table.concat({xconfig, 'nvim', 'compiler'}, pathsep)
    before_each(clear)

    it('loads lua compilers', function()
      local compiler_file = table.concat({compiler_folder, 'new_compiler.lua'},
                                            pathsep)
      mkdir_p(compiler_folder)
      write_file(compiler_file, [[vim.g.lua_compiler = 1]])

      clear{ args_rm={'-' }, env={ XDG_CONFIG_HOME=xconfig }}
      exec('compiler new_compiler')

      eq(1, eval('g:lua_compiler'))
      rmdir(compiler_folder)
    end)

    it('loads vim compilers when both lua and vim version exist', function()
      local compiler_file = table.concat({compiler_folder, 'new_compiler'},
                                            pathsep)
      mkdir_p(compiler_folder)
      write_file(compiler_file..'.vim', [[let g:compiler = 'vim']])
      write_file(compiler_file..'.lua', [[vim.g.compiler = 'lua']])

      clear{ args_rm={'-u' }, env={ XDG_CONFIG_HOME=xconfig }}
      exec('compiler new_compiler')

      eq('vim', eval('g:compiler'))
      rmdir(compiler_folder)
    end)
  end)

  describe('ftplugin', function()
    local ftplugin_folder = table.concat({xconfig, 'nvim', 'ftplugin'}, pathsep)

    before_each(clear)

    it('loads lua ftplugins', function()
      local ftplugin_file = table.concat({ftplugin_folder , 'new-ft.lua'}, pathsep)
      mkdir_p(ftplugin_folder)
      write_file(ftplugin_file , [[ vim.g.lua_ftplugin = 1 ]])

      clear{ args_rm={'-u' }, env={ XDG_CONFIG_HOME=xconfig, VIMRUNTIME='runtime/' }}

      exec [[set filetype=new-ft]]
      eq(1, eval('g:lua_ftplugin'))
      rmdir(ftplugin_folder)
    end)
  end)
end)

