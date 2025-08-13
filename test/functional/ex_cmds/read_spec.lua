local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq, neq, clear, pcall_err = t.eq, t.neq, n.clear, t.pcall_err
local fn = n.fn
local setline, getline, setcharpos, execute = fn.setline, fn.getline, fn.setcharpos, fn.execute

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

local function set_up()
  clear()
  local make_lines = string.format('let lines="%s"', table.concat(read_text, '\\n'))
  execute(make_lines)
end

local function clean_up()
  execute('unlet lines')
end

describe(':read :cmd', function()
  before_each(set_up)
  after_each(clean_up)
  it('inserts text from Ex command', function()
    test_read('read :echo lines', inserted_middle)
  end)
  it('inserts text from cmd at specific position', function()
    test_read('0read :echo lines', inserted_start)
  end)
  it('executes next command when using |', function()
    execute("let guard = 'fail'")
    test_read("read :echo lines | let guard='pass'", inserted_middle)
    eq('pass', vim.trim(execute('echo guard')))
  end)
  it('command reads can be undone', function()
    setline(1, original_text)
    execute('read :echo lines')
    neq(original_text, { getline(1), getline(2) })
    execute('undo')
    eq(original_text, { getline(1), getline(2) })
  end)
  it('failure modes', function()
    eq('Vim:E492: Not an editor command: asdfasdf', pcall_err(execute, ':read :asdfasdf'))
  end)
end)
