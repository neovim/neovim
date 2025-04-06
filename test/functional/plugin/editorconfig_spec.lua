local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local command = n.command
local eq = t.eq
local pathsep = n.get_pathsep()
local fn = n.fn
local api = n.api

local testdir = 'Xtest-editorconfig'

--- @param name string
--- @param expected table<string,any>
local function test_case(name, expected)
  local filename = testdir .. pathsep .. name
  command('edit ' .. filename)

  for opt, val in pairs(expected) do
    local opt_info = api.nvim_get_option_info2(opt, {})
    if opt_info.scope == 'win' then
      eq(val, api.nvim_get_option_value(opt, { win = 0 }), name)
    elseif opt_info.scope == 'buf' then
      eq(val, api.nvim_get_option_value(opt, { buf = 0 }), name)
    else
      eq(val, api.nvim_get_option_value(opt, {}), name)
    end
  end
end

setup(function()
  n.mkdir_p(testdir)
  t.write_file(
    testdir .. pathsep .. '.editorconfig',
    [[
    root = true

    [3_space.txt]
    indent_style = space
    indent_size = 3
    tab_width = 3

    [4_space.py]
    indent_style = space
    indent_size = 4
    tab_width = 8

    [space.txt]
    indent_style = space
    indent_size = tab

    [tab.txt]
    indent_style = tab

    [4_tab.txt]
    indent_style = tab
    indent_size = 4
    tab_width = 4

    [4_tab_width_of_8.txt]
    indent_style = tab
    indent_size = 4
    tab_width = 8

    [lf.txt]
    end_of_line = lf

    [crlf.txt]
    end_of_line = crlf

    [cr.txt]
    end_of_line = cr

    [utf-8.txt]
    charset = utf-8

    [utf-8-bom.txt]
    charset = utf-8-bom

    [utf-16be.txt]
    charset = utf-16be

    [utf-16le.txt]
    charset = utf-16le

    [latin1.txt]
    charset = latin1

    [with_newline.txt]
    insert_final_newline = true

    [without_newline.txt]
    insert_final_newline = false

    [trim.txt]
    trim_trailing_whitespace = true

    [no_trim.txt]
    trim_trailing_whitespace = false

    [max_line_length.txt]
    max_line_length = 42

    [short_spelling_language.txt]
    spelling_language = de

    [long_spelling_language.txt]
    spelling_language = en-NZ
    ]]
  )
end)

teardown(function()
  n.rmdir(testdir)
end)

describe('editorconfig', function()
  before_each(function()
    -- Remove -u NONE so that plugins (i.e. editorconfig.lua) are loaded
    clear({ args_rm = { '-u' } })
  end)

  it('sets indent options', function()
    test_case('3_space.txt', {
      expandtab = true,
      shiftwidth = 3,
      softtabstop = -1,
      tabstop = 3,
    })

    test_case('4_space.py', {
      expandtab = true,
      shiftwidth = 4,
      softtabstop = -1,
      tabstop = 8,
    })

    test_case('space.txt', {
      expandtab = true,
      shiftwidth = 0,
      softtabstop = 0,
    })

    test_case('tab.txt', {
      expandtab = false,
      shiftwidth = 0,
      softtabstop = 0,
    })

    test_case('4_tab.txt', {
      expandtab = false,
      shiftwidth = 4,
      softtabstop = -1,
      tabstop = 4,
    })

    test_case('4_tab_width_of_8.txt', {
      expandtab = false,
      shiftwidth = 4,
      softtabstop = -1,
      tabstop = 8,
    })
  end)

  it('sets end-of-line options', function()
    test_case('lf.txt', { fileformat = 'unix' })
    test_case('crlf.txt', { fileformat = 'dos' })
    test_case('cr.txt', { fileformat = 'mac' })
  end)

  it('sets encoding options', function()
    test_case('utf-8.txt', { fileencoding = 'utf-8', bomb = false })
    test_case('utf-8-bom.txt', { fileencoding = 'utf-8', bomb = true })
    test_case('utf-16be.txt', { fileencoding = 'utf-16', bomb = false })
    test_case('utf-16le.txt', { fileencoding = 'utf-16le', bomb = false })
    test_case('latin1.txt', { fileencoding = 'latin1', bomb = false })
  end)

  it('sets newline options', function()
    test_case('with_newline.txt', { fixendofline = true })
    test_case('without_newline.txt', { fixendofline = false })
  end)

  it('respects trim_trailing_whitespace', function()
    local filename = testdir .. pathsep .. 'trim.txt'
    -- luacheck: push ignore 613
    local untrimmed = [[
This line ends in whitespace 
So does this one    
And this one         
But not this one
]]
    -- luacheck: pop
    local trimmed = untrimmed:gsub('%s+\n', '\n')

    t.write_file(filename, untrimmed)
    command('edit ' .. filename)
    command('write')
    command('bdelete')
    eq(trimmed, t.read_file(filename))

    filename = testdir .. pathsep .. 'no_trim.txt'
    t.write_file(filename, untrimmed)
    command('edit ' .. filename)
    command('write')
    command('bdelete')
    eq(untrimmed, t.read_file(filename))
  end)

  it('sets textwidth', function()
    test_case('max_line_length.txt', { textwidth = 42 })
  end)

  it('can be disabled globally', function()
    api.nvim_set_var('editorconfig', false)
    api.nvim_set_option_value('shiftwidth', 42, {})
    test_case('3_space.txt', { shiftwidth = 42 })
  end)

  it('can be disabled per-buffer', function()
    api.nvim_set_option_value('shiftwidth', 42, {})
    local bufnr = fn.bufadd(testdir .. pathsep .. '3_space.txt')
    api.nvim_buf_set_var(bufnr, 'editorconfig', false)
    test_case('3_space.txt', { shiftwidth = 42 })
    test_case('4_space.py', { shiftwidth = 4 })
  end)

  it('does not operate on invalid buffers', function()
    local ok, err = unpack(n.exec_lua(function()
      vim.cmd.edit('test.txt')
      local bufnr = vim.api.nvim_get_current_buf()
      vim.cmd.bwipeout(bufnr)
      return { pcall(require('editorconfig').config, bufnr) }
    end))

    eq(true, ok, err)
  end)

  it('sets spelllang', function()
    test_case('short_spelling_language.txt', { spelllang = 'de' })
    test_case('long_spelling_language.txt', { spelllang = 'en_nz' })
  end)
end)
