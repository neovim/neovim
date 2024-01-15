local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local exec = helpers.exec
local exec_capture = helpers.exec_capture
local write_file = helpers.write_file
local call_viml_function = helpers.api.nvim_call_function

local function last_set_tests(cmd)
  local script_location, script_file
  -- All test cases below use the same nvim instance.
  setup(function()
    clear { args = { '-V1' } }
    script_file = 'test_verbose.lua'
    local current_dir = call_viml_function('getcwd', {})
    current_dir = call_viml_function('fnamemodify', { current_dir, ':~' })
    script_location = table.concat { current_dir, helpers.get_pathsep(), script_file }

    write_file(
      script_file,
      [[
vim.api.nvim_set_option_value('hlsearch', false, {})
vim.bo.expandtab = true
vim.opt.number = true
vim.api.nvim_set_keymap('n', '<leader>key1', ':echo "test"<cr>', {noremap = true})
vim.keymap.set('n', '<leader>key2', ':echo "test"<cr>')

vim.api.nvim_exec2("augroup test_group\
                     autocmd!\
                     autocmd FileType c setl cindent\
                     augroup END\
                  ", {})

vim.api.nvim_command("command Bdelete :bd")
vim.api.nvim_create_user_command("TestCommand", ":echo 'Hello'", {})

vim.api.nvim_exec ("\
function Close_Window() abort\
  wincmd -\
endfunction\
", false)

local ret = vim.api.nvim_exec ("\
function! s:return80()\
  return 80\
endfunction\
let &tw = s:return80()\
", true)
]]
    )
    exec(cmd .. ' ' .. script_file)
  end)

  teardown(function()
    os.remove(script_file)
  end)

  it('"Last set" for option set by Lua', function()
    local result = exec_capture(':verbose set hlsearch?')
    eq(
      string.format(
        [[
nohlsearch
	Last set from %s line 1]],
        script_location
      ),
      result
    )
  end)

  it('"Last set" for option set by vim.o', function()
    local result = exec_capture(':verbose set expandtab?')
    eq(
      string.format(
        [[
  expandtab
	Last set from %s line 2]],
        script_location
      ),
      result
    )
  end)

  it('"Last set" for option set by vim.opt', function()
    local result = exec_capture(':verbose set number?')
    eq(
      string.format(
        [[
  number
	Last set from %s line 3]],
        script_location
      ),
      result
    )
  end)

  it('"Last set" for mapping set by Lua', function()
    local result = exec_capture(':verbose map <leader>key1')
    eq(
      string.format(
        [[

n  \key1       * :echo "test"<CR>
	Last set from %s line 4]],
        script_location
      ),
      result
    )
  end)

  it('"Last set" for mapping set by vim.keymap', function()
    local result = exec_capture(':verbose map <leader>key2')
    eq(
      string.format(
        [[

n  \key2       * :echo "test"<CR>
	Last set from %s line 5]],
        script_location
      ),
      result
    )
  end)

  it('"Last set" for autocmd by vim.api.nvim_exec', function()
    local result = exec_capture(':verbose autocmd test_group Filetype c')
    eq(
      string.format(
        [[
--- Autocommands ---
test_group  FileType
    c         setl cindent
	Last set from %s line 7]],
        script_location
      ),
      result
    )
  end)

  it('"Last set" for command defined by nvim_command', function()
    if cmd == 'luafile' then
      pending('nvim_command does not set the script context')
    end
    local result = exec_capture(':verbose command Bdelete')
    eq(
      string.format(
        [[
    Name              Args Address Complete    Definition
    Bdelete           0                        :bd
	Last set from %s line 13]],
        script_location
      ),
      result
    )
  end)

  it('"Last set" for command defined by nvim_create_user_command', function()
    local result = exec_capture(':verbose command TestCommand')
    eq(
      string.format(
        [[
    Name              Args Address Complete    Definition
    TestCommand       0                        :echo 'Hello'
	Last set from %s line 14]],
        script_location
      ),
      result
    )
  end)

  it('"Last set" for function', function()
    local result = exec_capture(':verbose function Close_Window')
    eq(
      string.format(
        [[
   function Close_Window() abort
	Last set from %s line 16
1    wincmd -
   endfunction]],
        script_location
      ),
      result
    )
  end)

  it('"Last set" works with anonymous sid', function()
    local result = exec_capture(':verbose set tw?')
    eq(
      string.format(
        [[
  textwidth=80
	Last set from %s line 22]],
        script_location
      ),
      result
    )
  end)
end

describe('lua :verbose when using :source', function()
  last_set_tests('source')
end)

describe('lua :verbose when using :luafile', function()
  last_set_tests('luafile')
end)

describe('lua verbose:', function()
  local script_file

  setup(function()
    clear()
    script_file = 'test_luafile.lua'
    write_file(
      script_file,
      [[
    vim.api.nvim_set_option_value('hlsearch', false, {})
    ]]
    )
    exec(':source ' .. script_file)
  end)

  teardown(function()
    os.remove(script_file)
  end)

  it('is disabled when verbose = 0', function()
    local result = exec_capture(':verbose set hlsearch?')
    eq(
      [[
nohlsearch
	Last set from Lua]],
      result
    )
  end)
end)
