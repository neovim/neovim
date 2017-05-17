-- Test suite for checking :lua* commands
local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local NIL = helpers.NIL
local clear = helpers.clear
local meths = helpers.meths
local funcs = helpers.funcs
local source = helpers.source
local dedent = helpers.dedent
local exc_exec = helpers.exc_exec
local write_file = helpers.write_file
local redir_exec = helpers.redir_exec
local curbufmeths = helpers.curbufmeths

before_each(clear)

describe(':lua command', function()
  it('works', function()
    eq('', redir_exec(
      'lua vim.api.nvim_buf_set_lines(1, 1, 2, false, {"TEST"})'))
    eq({'', 'TEST'}, curbufmeths.get_lines(0, 100, false))
    source(dedent([[
      lua << EOF
        vim.api.nvim_buf_set_lines(1, 1, 2, false, {"TSET"})
      EOF]]))
    eq({'', 'TSET'}, curbufmeths.get_lines(0, 100, false))
    source(dedent([[
      lua << EOF
        vim.api.nvim_buf_set_lines(1, 1, 2, false, {"SETT"})]]))
    eq({'', 'SETT'}, curbufmeths.get_lines(0, 100, false))
    source(dedent([[
      lua << EOF
        vim.api.nvim_buf_set_lines(1, 1, 2, false, {"ETTS"})
        vim.api.nvim_buf_set_lines(1, 2, 3, false, {"TTSE"})
        vim.api.nvim_buf_set_lines(1, 3, 4, false, {"STTE"})
      EOF]]))
    eq({'', 'ETTS', 'TTSE', 'STTE'}, curbufmeths.get_lines(0, 100, false))
  end)
  it('throws catchable errors', function()
    eq([[Vim(lua):E5104: Error while creating lua chunk: [string "<VimL compiled string>"]:1: unexpected symbol near ')']],
       exc_exec('lua ()'))
    eq([[Vim(lua):E5105: Error while calling lua chunk: [string "<VimL compiled string>"]:1: TEST]],
       exc_exec('lua error("TEST")'))
    eq([[Vim(lua):E5105: Error while calling lua chunk: [string "<VimL compiled string>"]:1: Invalid buffer id]],
       exc_exec('lua vim.api.nvim_buf_set_lines(-10, 1, 1, false, {"TEST"})'))
    eq({''}, curbufmeths.get_lines(0, 100, false))
  end)
  it('works with NULL errors', function()
    eq([=[Vim(lua):E5105: Error while calling lua chunk: [NULL]]=],
       exc_exec('lua error(nil)'))
  end)
  it('accepts embedded NLs without heredoc', function()
    -- Such code is usually used for `:execute 'lua' {generated_string}`:
    -- heredocs do not work in this case.
    meths.command([[
      lua
        vim.api.nvim_buf_set_lines(1, 1, 2, false, {"ETTS"})
        vim.api.nvim_buf_set_lines(1, 2, 3, false, {"TTSE"})
        vim.api.nvim_buf_set_lines(1, 3, 4, false, {"STTE"})
    ]])
    eq({'', 'ETTS', 'TTSE', 'STTE'}, curbufmeths.get_lines(0, 100, false))
  end)
  it('preserves global and not preserves local variables', function()
    eq('', redir_exec('lua gvar = 42'))
    eq('', redir_exec('lua local lvar = 100500'))
    eq(NIL, funcs.luaeval('lvar'))
    eq(42, funcs.luaeval('gvar'))
  end)
  it('works with long strings', function()
    local s = ('x'):rep(100500)

    eq('\nE5104: Error while creating lua chunk: [string "<VimL compiled string>"]:1: unfinished string near \'<eof>\'', redir_exec(('lua vim.api.nvim_buf_set_lines(1, 1, 2, false, {"%s})'):format(s)))
    eq({''}, curbufmeths.get_lines(0, -1, false))

    eq('', redir_exec(('lua vim.api.nvim_buf_set_lines(1, 1, 2, false, {"%s"})'):format(s)))
    eq({'', s}, curbufmeths.get_lines(0, -1, false))
  end)
end)

describe(':luado command', function()
  it('works', function()
    curbufmeths.set_lines(0, 1, false, {"ABC", "def", "gHi"})
    eq('', redir_exec('luado lines = (lines or {}) lines[#lines + 1] = {linenr, line}'))
    eq({'ABC', 'def', 'gHi'}, curbufmeths.get_lines(0, -1, false))
    eq({{1, 'ABC'}, {2, 'def'}, {3, 'gHi'}}, funcs.luaeval('lines'))

    -- Automatic transformation of numbers
    eq('', redir_exec('luado return linenr'))
    eq({'1', '2', '3'}, curbufmeths.get_lines(0, -1, false))

    eq('', redir_exec('luado return ("<%02x>"):format(line:byte())'))
    eq({'<31>', '<32>', '<33>'}, curbufmeths.get_lines(0, -1, false))
  end)
  it('stops processing lines when suddenly out of lines', function()
    curbufmeths.set_lines(0, 1, false, {"ABC", "def", "gHi"})
    eq('', redir_exec('2,$luado runs = ((runs or 0) + 1) vim.api.nvim_command("%d")'))
    eq({''}, curbufmeths.get_lines(0, -1, false))
    eq(1, funcs.luaeval('runs'))
  end)
  it('works correctly when changing lines out of range', function()
    curbufmeths.set_lines(0, 1, false, {"ABC", "def", "gHi"})
    eq('\nE322: line number out of range: 1 past the end\nE320: Cannot find line 2',
       redir_exec('2,$luado vim.api.nvim_command("%d") return linenr'))
    eq({''}, curbufmeths.get_lines(0, -1, false))
  end)
  it('fails on errors', function()
    eq([[Vim(luado):E5109: Error while creating lua chunk: [string "<VimL compiled string>"]:1: unexpected symbol near ')']],
       exc_exec('luado ()'))
    eq([[Vim(luado):E5111: Error while calling lua function: [string "<VimL compiled string>"]:1: attempt to perform arithmetic on global 'liness' (a nil value)]],
       exc_exec('luado return liness + 1'))
  end)
  it('works with NULL errors', function()
    eq([=[Vim(luado):E5111: Error while calling lua function: [NULL]]=],
       exc_exec('luado error(nil)'))
  end)
  it('fails in sandbox when needed', function()
    curbufmeths.set_lines(0, 1, false, {"ABC", "def", "gHi"})
    eq('\nE48: Not allowed in sandbox: sandbox luado runs = (runs or 0) + 1',
       redir_exec('sandbox luado runs = (runs or 0) + 1'))
    eq(NIL, funcs.luaeval('runs'))
  end)
  it('works with long strings', function()
    local s = ('x'):rep(100500)

    eq('\nE5109: Error while creating lua chunk: [string "<VimL compiled string>"]:1: unfinished string near \'<eof>\'', redir_exec(('luado return "%s'):format(s)))
    eq({''}, curbufmeths.get_lines(0, -1, false))

    eq('', redir_exec(('luado return "%s"'):format(s)))
    eq({s}, curbufmeths.get_lines(0, -1, false))
  end)
end)

describe(':luafile', function()
  local fname = 'Xtest-functional-lua-commands-luafile'

  after_each(function()
    os.remove(fname)
  end)

  it('works', function()
    write_file(fname, [[
        vim.api.nvim_buf_set_lines(1, 1, 2, false, {"ETTS"})
        vim.api.nvim_buf_set_lines(1, 2, 3, false, {"TTSE"})
        vim.api.nvim_buf_set_lines(1, 3, 4, false, {"STTE"})
    ]])
    eq('', redir_exec('luafile ' .. fname))
    eq({'', 'ETTS', 'TTSE', 'STTE'}, curbufmeths.get_lines(0, 100, false))
  end)

  it('correctly errors out', function()
    write_file(fname, '()')
    eq(("Vim(luafile):E5112: Error while creating lua chunk: %s:1: unexpected symbol near ')'"):format(fname),
       exc_exec('luafile ' .. fname))
    write_file(fname, 'vimm.api.nvim_buf_set_lines(1, 1, 2, false, {"ETTS"})')
    eq(("Vim(luafile):E5113: Error while calling lua chunk: %s:1: attempt to index global 'vimm' (a nil value)"):format(fname),
       exc_exec('luafile ' .. fname))
  end)
  it('works with NULL errors', function()
    write_file(fname, 'error(nil)')
    eq([=[Vim(luafile):E5113: Error while calling lua chunk: [NULL]]=],
       exc_exec('luafile ' .. fname))
  end)
end)
