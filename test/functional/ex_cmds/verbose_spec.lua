local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local exec = helpers.exec
local exec_capture = helpers.exec_capture
local write_file = helpers.write_file
local call_viml_function = helpers.meths.call_function

describe('lua verbose:', function()
  clear()

  local script_file = 'test_luafile.lua'
  local current_dir = call_viml_function('getcwd', {})
  current_dir = call_viml_function('fnamemodify', {current_dir, ':~'})
  local separator = helpers.get_pathsep()

  write_file(script_file, [[
vim.api.nvim_set_option('hlsearch', false)
vim.bo.expandtab = true
vim.opt.number = true
vim.api.nvim_set_keymap('n', '<leader>key', ':echo "test"<cr>', {noremap = true})
]])
  exec(':source '..script_file)

  teardown(function()
    os.remove(script_file)
  end)

  it('Shows last set location when option is set through api from lua', function()
    local result = exec_capture(':verbose set hlsearch?')
    eq(string.format([[
nohlsearch
	Last set from %s line 1]],
       table.concat{current_dir, separator, script_file}), result)
  end)

  it('Shows last set location when option is set through vim.o shorthands', function()
    local result = exec_capture(':verbose set expandtab?')
    eq(string.format([[
  expandtab
	Last set from %s line 2]],
       table.concat{current_dir, separator, script_file}), result)
  end)

  it('Shows last set location when option is set through vim.opt', function()
    local result = exec_capture(':verbose set number?')
    eq(string.format([[
  number
	Last set from %s line 3]],
       table.concat{current_dir, separator, script_file}), result)
  end)

  it('Shows last set location when keymap is set through api from lua', function()
    local result = exec_capture(':verbose map <leader>key')
    eq(string.format([[

n  \key        * :echo "test"<CR>
	Last set from %s line 4]],
       table.concat{current_dir, separator, script_file}), result)
  end)
end)
