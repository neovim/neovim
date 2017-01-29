-- Test suite for checking :lua* commands
local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local clear = helpers.clear
local meths = helpers.meths
local source = helpers.source
local dedent = helpers.dedent
local exc_exec = helpers.exc_exec
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
end)
