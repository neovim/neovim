local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local exec = n.exec
local exec_capture = n.exec_capture
local write_file = t.write_file
local api = n.api
local fn = n.fn

--- @param cmd string
--- @param v1 boolean
local function last_set_lua_verbose_tests(cmd, v1)
  local script_location, script_file
  -- All test cases below use the same Nvim instance.
  setup(function()
    clear(v1 and { args = { '-V1' } } or nil)
    script_file = 'test_verbose.lua'
    local current_dir = fn.getcwd()
    current_dir = fn.fnamemodify(current_dir, ':~')
    script_location = table.concat({ current_dir, n.get_pathsep(), script_file })

    write_file(
      script_file,
      [=[
vim.api.nvim_set_option_value('hlsearch', false, {})
vim.bo.expandtab = true
vim.opt.number = true
vim.api.nvim_exec2('set numberwidth=2', {})
vim.cmd('set colorcolumn=+1')

local function cb()
  -- This is a comment
  -- This is another comment
  vim.o.mouse = 'nv'
end

vim.api.nvim_set_keymap('n', '<leader>key1', ':echo "test"<cr>', {noremap = true})
vim.keymap.set('n', '<leader>key2', ':echo "test"<cr>')

vim.api.nvim_exec2("augroup test_group\
                     autocmd!\
                     autocmd FileType c setl cindent\
                     augroup END\
                  ", {})

vim.api.nvim_create_autocmd('FileType', {
  group = 'test_group',
  pattern = 'cpp',
  command = 'setl cindent',
})

vim.api.nvim_exec2(':highlight TestHL1 guibg=Blue', {})
vim.api.nvim_set_hl(0, 'TestHL2', { bg = 'Green' })

vim.api.nvim_command("command Bdelete :bd")
vim.api.nvim_create_user_command("TestCommand", ":echo 'Hello'", {})

vim.api.nvim_exec2 ("\
function Close_Window() abort\
  wincmd -\
endfunction\
", {})

local ret = vim.api.nvim_exec2 ("\
function! s:return80()\
  return 80\
endfunction\
let &tw = s:return80()\
", {})

local set_list = ([[
  func SetList()
%s
    set list
  endfunc
  call SetList()
]]):format(('\n'):rep(1234))
vim.api.nvim_exec2(set_list, {})

vim.api.nvim_create_autocmd('User', { pattern = 'set_mouse', callback = cb })
]=]
    )
    exec(cmd .. ' ' .. script_file)
    exec('doautocmd User set_mouse')
  end)

  local function get_last_set_location(linenr)
    return ('%s %s'):format(
      (cmd == 'source' or v1) and script_location or 'Lua',
      v1 and ('line %d'):format(linenr) or '(run Nvim with -V1 for more details)'
    )
  end

  local option_checks = {
    { 'nvim_set_option_value', 'hlsearch', 'nohlsearch', 1 },
    { 'vim.bo', 'expandtab', '  expandtab', 2 },
    { 'vim.opt', 'number', '  number', 3 },
    { 'nvim_exec2', 'numberwidth', '  numberwidth=2', 4 },
    { 'vim.cmd', 'colorcolumn', '  colorcolumn=+1', 5 },
    { 'Lua autocommand', 'mouse', '  mouse=nv', 10 },
  }

  teardown(function()
    os.remove(script_file)
  end)

  for _, check in ipairs(option_checks) do
    it(('for option set by %s'):format(check[1]), function()
      local result = exec_capture((':verbose set %s?'):format(check[2]))
      eq(
        string.format(
          [[
%s
	Last set from %s]],
          check[3],
          get_last_set_location(check[4])
        ),
        result
      )
    end)
  end

  it('for mapping set by nvim_set_keymap', function()
    local result = exec_capture(':verbose map <leader>key1')
    eq(
      string.format(
        [[

n  \key1       * :echo "test"<CR>
	Last set from %s]],
        get_last_set_location(13)
      ),
      result
    )
  end)

  it('for mapping set by vim.keymap.set', function()
    local result = exec_capture(':verbose map <leader>key2')
    eq(
      string.format(
        [[

n  \key2       * :echo "test"<CR>
	Last set from %s]],
        get_last_set_location(14)
      ),
      result
    )
  end)

  it('for autocmd set by nvim_exec2', function()
    local result = exec_capture(':verbose autocmd test_group Filetype c')
    eq(
      string.format(
        [[
--- Autocommands ---
test_group  FileType
    c         setl cindent
	Last set from %s]],
        get_last_set_location(16)
      ),
      result
    )
  end)

  it('for autocmd set by nvim_create_autocmd', function()
    local result = exec_capture(':verbose autocmd test_group Filetype cpp')
    eq(
      string.format(
        [[
--- Autocommands ---
test_group  FileType
    cpp       setl cindent
	Last set from %s]],
        get_last_set_location(22)
      ),
      result
    )
  end)

  it('for highlight group set by nvim_exec2', function()
    local result = exec_capture(':verbose highlight TestHL1')
    eq(
      string.format(
        [[
TestHL1        xxx guibg=Blue
	Last set from %s]],
        get_last_set_location(28)
      ),
      result
    )
  end)

  it('for highlight group set by nvim_set_hl', function()
    local result = exec_capture(':verbose highlight TestHL2')
    eq(
      string.format(
        [[
TestHL2        xxx guibg=Green
	Last set from %s]],
        get_last_set_location(29)
      ),
      result
    )
  end)

  it('for command defined by nvim_command', function()
    if cmd == 'luafile' then
      pending('nvim_command does not set the script context')
    end
    local result = exec_capture(':verbose command Bdelete')
    eq(
      string.format(
        [[
    Name              Args Address Complete    Definition
    Bdelete           0                        :bd
	Last set from %s]],
        get_last_set_location(31)
      ),
      result
    )
  end)

  it('for command defined by nvim_create_user_command', function()
    local result = exec_capture(':verbose command TestCommand')
    eq(
      string.format(
        [[
    Name              Args Address Complete    Definition
    TestCommand       0                        :echo 'Hello'
	Last set from %s]],
        get_last_set_location(32)
      ),
      result
    )
  end)

  it('for function defined by nvim_exec2', function()
    local result = exec_capture(':verbose function Close_Window')
    eq(
      string.format(
        [[
   function Close_Window() abort
	Last set from %s
1    wincmd -
   endfunction]],
        get_last_set_location(34)
      ),
      result
    )
  end)

  it('for option set by nvim_exec2 with anonymous sid', function()
    local result = exec_capture(':verbose set tw?')
    local loc = get_last_set_location(40)
    if loc == 'Lua (run Nvim with -V1 for more details)' then
      loc = 'anonymous :source (script id 1) line 5'
    end
    eq(
      string.format(
        [[
  textwidth=80
	Last set from %s]],
        loc
      ),
      result
    )
  end)

  it('for option set by function in nvim_exec2', function()
    local result = exec_capture(':verbose set list?')
    eq(
      string.format(
        [[
  list
	Last set from %s]],
        get_last_set_location(54)
      ),
      result
    )
  end)
end

describe('lua :verbose with -V1', function()
  describe('"Last set" shows full location when using :source', function()
    last_set_lua_verbose_tests('source', true)
  end)

  describe('"Last set" shows full location using :luafile', function()
    last_set_lua_verbose_tests('luafile', true)
  end)
end)

describe('lua :verbose without -V1', function()
  describe('"Last set" shows file name when using :source', function()
    last_set_lua_verbose_tests('source', false)
  end)

  describe('"Last set" suggests -V1 when using :luafile', function()
    last_set_lua_verbose_tests('luafile', false)
  end)
end)

describe(':verbose when using API from Vimscript', function()
  local script_location, script_file
  -- All test cases below use the same Nvim instance.
  setup(function()
    clear()
    script_file = 'test_verbose.vim'
    local current_dir = fn.getcwd()
    current_dir = fn.fnamemodify(current_dir, ':~')
    script_location = table.concat({ current_dir, n.get_pathsep(), script_file })

    write_file(
      script_file,
      [[
call nvim_set_option_value('hlsearch', v:false, {})
call nvim_set_keymap('n', '<leader>key1', ':echo "test"<cr>', #{noremap: v:true})

call nvim_create_augroup('test_group', {})
call nvim_create_autocmd('FileType', #{
  \ group: 'test_group',
  \ pattern: 'cpp',
  \ command: 'setl cindent',
\ })

call nvim_set_hl(0, 'TestHL2', #{bg: 'Green'})
call nvim_create_user_command("TestCommand", ":echo 'Hello'", {})
]]
    )
    exec('source ' .. script_file)
  end)

  teardown(function()
    os.remove(script_file)
  end)

  it('"Last set" for option set by nvim_set_option_value', function()
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

  it('"Last set" for mapping set by nvim_set_keymap', function()
    local result = exec_capture(':verbose map <leader>key1')
    eq(
      string.format(
        [[

n  \key1       * :echo "test"<CR>
	Last set from %s line 2]],
        script_location
      ),
      result
    )
  end)

  it('"Last set" for autocmd set by nvim_create_autocmd', function()
    local result = exec_capture(':verbose autocmd test_group Filetype cpp')
    eq(
      string.format(
        [[
--- Autocommands ---
test_group  FileType
    cpp       setl cindent
	Last set from %s line 5]],
        script_location
      ),
      result
    )
  end)

  it('"Last set" for highlight group set by nvim_set_hl', function()
    local result = exec_capture(':verbose highlight TestHL2')
    eq(
      string.format(
        [[
TestHL2        xxx guibg=Green
	Last set from %s line 11]],
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
	Last set from %s line 12]],
        script_location
      ),
      result
    )
  end)
end)

describe(':verbose when using API from RPC', function()
  -- All test cases below use the same Nvim instance.
  setup(clear)

  it('"Last set" for option set by nvim_set_option_value', function()
    api.nvim_set_option_value('hlsearch', false, {})
    local result = exec_capture(':verbose set hlsearch?')
    eq(
      [[
nohlsearch
	Last set from API client (channel id 1)]],
      result
    )
  end)

  it('"Last set" for mapping set by nvim_set_keymap', function()
    api.nvim_set_keymap('n', '<leader>key1', ':echo "test"<cr>', { noremap = true })
    local result = exec_capture(':verbose map <leader>key1')
    eq(
      [[

n  \key1       * :echo "test"<CR>
	Last set from API client (channel id 1)]],
      result
    )
  end)

  it('"Last set" for autocmd set by nvim_create_autocmd', function()
    api.nvim_create_augroup('test_group', {})
    api.nvim_create_autocmd('FileType', {
      group = 'test_group',
      pattern = 'cpp',
      command = 'setl cindent',
    })
    local result = exec_capture(':verbose autocmd test_group Filetype cpp')
    eq(
      [[
--- Autocommands ---
test_group  FileType
    cpp       setl cindent
	Last set from API client (channel id 1)]],
      result
    )
  end)

  it('"Last set" for highlight group set by nvim_set_hl', function()
    api.nvim_set_hl(0, 'TestHL2', { bg = 'Green' })
    local result = exec_capture(':verbose highlight TestHL2')
    eq(
      [[
TestHL2        xxx guibg=Green
	Last set from API client (channel id 1)]],
      result
    )
  end)

  it('"Last set" for command defined by nvim_create_user_command', function()
    api.nvim_create_user_command('TestCommand', ":echo 'Hello'", {})
    local result = exec_capture(':verbose command TestCommand')
    eq(
      [[
    Name              Args Address Complete    Definition
    TestCommand       0                        :echo 'Hello'
	Last set from API client (channel id 1)]],
      result
    )
  end)
end)
