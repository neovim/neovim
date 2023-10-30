local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local feed = helpers.feed
local matches = helpers.matches
local pcall_err = helpers.pcall_err

describe('vim.snippet', function()
  before_each(function()
    clear()

    exec_lua([[
      vim.keymap.set({ 'i', 's' }, '<Tab>', function() vim.snippet.jump(1) end, { buffer = true })
      vim.keymap.set({ 'i', 's' }, '<S-Tab>', function() vim.snippet.jump(-1) end, { buffer = true })
    ]])
  end)
  after_each(clear)

  --- @param snippet string[]
  --- @param expected string[]
  --- @param settings? string
  --- @param prefix? string
  local function test_success(snippet, expected, settings, prefix)
    if settings then
      exec_lua(settings)
    end
    if prefix then
      feed('i' .. prefix)
    end
    exec_lua('vim.snippet.expand(...)', table.concat(snippet, '\n'))
    eq(expected, helpers.buf_lines(0))
  end

  --- @param snippet string
  --- @param err string
  local function test_fail(snippet, err)
    matches(err, pcall_err(exec_lua, string.format('vim.snippet.expand("%s")', snippet)))
  end

  it('adds base indentation to inserted text', function()
    test_success(
      { 'function $1($2)', '  $0', 'end' },
      { '  function ()', '    ', '  end' },
      '',
      '  '
    )
  end)

  it('adds indentation based on the start of snippet lines', function()
    test_success({ 'if $1 then', '  $0', 'end' }, { 'if  then', '  ', 'end' })
  end)

  it('replaces tabs with spaces when expandtab is set', function()
    test_success(
      { 'function $1($2)', '\t$0', 'end' },
      { 'function ()', '  ', 'end' },
      [[
      vim.o.expandtab = true
      vim.o.shiftwidth = 2
      ]]
    )
  end)

  it('respects tabs when expandtab is not set', function()
    test_success(
      { 'function $1($2)', '\t$0', 'end' },
      { 'function ()', '\t', 'end' },
      'vim.o.expandtab = false'
    )
  end)

  it('inserts known variable value', function()
    test_success({ '; print($TM_CURRENT_LINE)' }, { 'foo; print(foo)' }, nil, 'foo')
  end)

  it('uses default when variable is not set', function()
    test_success({ 'print(${TM_CURRENT_WORD:foo})' }, { 'print(foo)' })
  end)

  it('replaces unknown variables by placeholders', function()
    test_success({ 'print($UNKNOWN)' }, { 'print(UNKNOWN)' })
  end)

  it('does not jump outside snippet range', function()
    test_success({ 'function $1($2)', '  $0', 'end' }, { 'function ()', '  ', 'end' })
    eq(false, exec_lua('return vim.snippet.jumpable(-1)'))
    feed('<Tab><Tab>i')
    eq(false, exec_lua('return vim.snippet.jumpable(1)'))
  end)

  it('navigates backwards', function()
    test_success({ 'function $1($2) end' }, { 'function () end' })
    feed('<Tab><S-Tab>foo')
    eq({ 'function foo() end' }, helpers.buf_lines(0))
  end)

  it('visits all tabstops', function()
    local function cursor()
      return exec_lua('return vim.api.nvim_win_get_cursor(0)')
    end

    test_success({ 'function $1($2)', '  $0', 'end' }, { 'function ()', '  ', 'end' })
    eq({ 1, 9 }, cursor())
    feed('<Tab>')
    eq({ 1, 10 }, cursor())
    feed('<Tab>')
    eq({ 2, 2 }, cursor())
  end)

  it('syncs text of tabstops with equal indexes', function()
    test_success({ 'var double = ${1:x} + ${1:x}' }, { 'var double = x + x' })
    feed('123')
    eq({ 'var double = 123 + 123' }, helpers.buf_lines(0))
  end)

  it('cancels session with changes outside the snippet', function()
    test_success({ 'print($1)' }, { 'print()' })
    feed('<Esc>O-- A comment')
    eq(false, exec_lua('return vim.snippet.active()'))
    eq({ '-- A comment', 'print()' }, helpers.buf_lines(0))
  end)

  it('handles non-consecutive tabstops', function()
    test_success({ 'class $1($3) {', '  $0', '}' }, { 'class () {', '  ', '}' })
    feed('Foo') -- First tabstop
    feed('<Tab><Tab>') -- Jump to $0
    feed('// Inside') -- Insert text
    eq({ 'class Foo() {', '  // Inside', '}' }, helpers.buf_lines(0))
  end)

  it('handles multiline placeholders', function()
    test_success(
      { 'public void foo() {', '  ${0:// TODO Auto-generated', '  throw;}', '}' },
      { 'public void foo() {', '  // TODO Auto-generated', '  throw;', '}' }
    )
  end)

  it('inserts placeholder in all tabstops when the first tabstop has the placeholder', function()
    test_success(
      { 'for (${1:int} ${2:x} = ${3:0}; $2 < ${4:N}; $2++) {', '  $0', '}' },
      { 'for (int x = 0; x < N; x++) {', '  ', '}' }
    )
  end)

  it('inserts placeholder in all tabstops when a later tabstop has the placeholder', function()
    test_success(
      { 'for (${1:int} $2 = ${3:0}; ${2:x} < ${4:N}; $2++) {', '  $0', '}' },
      { 'for (int x = 0; x < N; x++) {', '  ', '}' }
    )
  end)

  it('errors with multiple placeholders for the same index', function()
    test_fail('class ${1:Foo} { void ${1:foo}() {} }', 'multiple placeholders for tabstop $1')
  end)

  it('errors with multiple $0 tabstops', function()
    test_fail('function $1() { $0 }$0', 'multiple $0 tabstops')
  end)

  it('cancels session when deleting the snippet', function()
    test_success({ 'local function $1()', '  $0', 'end' }, { 'local function ()', '  ', 'end' })
    feed('<esc>Vjjd')
    eq(false, exec_lua('return vim.snippet.active()'))
  end)

  it('cancels session when inserting outside snippet region', function()
    feed('i<cr>')
    test_success({ 'local function $1()', '  $0', 'end' }, { '', 'local function ()', '  ', 'end' })
    feed('<esc>O-- A comment')
    eq(false, exec_lua('return vim.snippet.active()'))
  end)
end)
