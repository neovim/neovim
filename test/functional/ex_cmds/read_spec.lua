local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq, write_file, clear, pcall_err = t.eq, t.write_file, n.clear, t.pcall_err
local fn = n.fn
local setline, getline, setcharpos, execute = fn.setline, fn.getline, fn.setcharpos, fn.execute

local tmp_file = 'text.txt'
local original_text = { 'First', 'Last' }
local read_text = { ' This is a line starts with a space', '  This one starts with two spaces.' }
local inserted_middle = { original_text[1], read_text[1], read_text[2], original_text[2] }
local inserted_start = { read_text[1], read_text[2], original_text[1], original_text[2] }

local function test_read(cmd, expected)
  setline(1, original_text)
  setcharpos('.', { 0, 0, 0 })
  execute(cmd)
  for i, e in ipairs(expected) do
    eq(e, getline(i))
  end
end

local function test_undo(cmd)
  setline(1, original_text)
  execute(cmd)
  execute('undo')
  eq(original_text, { getline(1), getline(2) })
end

describe(':read', function()
  local function cleanup()
    os.remove(tmp_file)
  end
  before_each(function()
    clear()
    cleanup()
    write_file(tmp_file, table.concat(read_text, '\n'), true)
  end)
  after_each(cleanup)
  it('inserts text from file', function()
    test_read('read ' .. tmp_file, inserted_middle)
    eq({ 0, 2, 2, 0 }, fn.getpos('.'))
  end)
  it('inserts text from shell', function()
    test_read('read !cat ' .. tmp_file, inserted_middle)
    eq({ 0, 3, 3, 0 }, fn.getpos('.'))
  end)
  it('inserts text from Ex command', function()
    local make_lines = string.format('let lines="%s"', table.concat(read_text, '\\n'))
    execute(make_lines)
    test_read('read :echo lines', inserted_middle)
  end)
  it('inserts text from file at specific position', function()
    test_read('0read ' .. tmp_file, inserted_start)
    eq({ 0, 1, 2, 0 }, fn.getpos('.'))
  end)
  it('inserts text from shell cmd at specific position', function()
    test_read('0read !cat ' .. tmp_file, inserted_start)
    eq({ 0, 2, 3, 0 }, fn.getpos('.'))
  end)
  it('executes next command when using |', function()
    local make_lines = string.format('let lines="%s"', table.concat(read_text, '\\n'))
    execute(make_lines)
    execute("let guard = 'fail'")
    test_read("read :echo lines | let guard='pass'", inserted_middle)
    eq('pass', vim.trim(execute('echo guard')))
  end)
  it('sets fileformat, fileencoding, bomb correctly', function()
    execute('set fileformat=dos')
    execute('set fileencoding=latin1')
    execute('set bomb')
    execute('read ++edit ' .. tmp_file)
    eq('fileformat=unix', vim.trim(execute('set fileformat?')))
    eq('fileencoding=utf-8', vim.trim(execute('set fileencoding?')))
    eq('nobomb', vim.trim(execute('set bomb?')))
  end)
  it('file reads can be undone', function()
    test_undo('read ' .. tmp_file)
  end)
  it('shell reads can be undone', function()
    test_undo('read !cat ' .. tmp_file)
  end)
  it('command reads can be undone', function()
    local make_lines = string.format('let lines="%s"', table.concat(read_text, '\\n'))
    execute(make_lines)
    test_undo('read :echo lines')
  end)
  it('errors out correctly when a non-existant file is used', function()
    eq("Vim(read):E484: Can't open file asdfasdf", pcall_err(execute, ':read asdfasdf'))
  end)
  it('errors out correctly when an invalid command is used', function()
    eq('Vim:E492: Not an editor command: asdfasdf', pcall_err(execute, ':read :asdfasdf'))
  end)
end)
