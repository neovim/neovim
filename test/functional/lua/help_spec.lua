-- Tests for gen_help_html.lua. Validates :help tags/links and HTML doc generation.
--
-- TODO: extract parts of gen_help_html.lua into Nvim stdlib?

local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local ok = helpers.ok

describe(':help docs', function()
  before_each(clear)
  it('validate', function()
    -- If this test fails, try these steps (in order):
    -- 1. Try to fix/cleanup the :help docs, especially Nvim-owned :help docs.
    -- 2. Try to fix the parser: https://github.com/vigoux/tree-sitter-vimdoc
    -- 3. File a parser bug, and adjust the tolerance of this test in the meantime.

    local rv = exec_lua([[return require('scripts.gen_help_html').validate('./build/runtime/doc')]])
    -- Check that parse errors did not increase wildly.
    -- TODO: yes, there are currently 24k+ parser errors.
    --       WIP: https://github.com/vigoux/tree-sitter-vimdoc/pull/16
    ok(rv.err_count < 24000, '<24000', rv.err_count)
    -- TODO: should be eq(0, …)
    ok(exec_lua('return vim.tbl_count(...)', rv.invalid_tags) < 538, '<538',
      exec_lua('return vim.inspect(...)', rv.invalid_tags))
  end)

  it('gen_help_html.lua generates HTML', function()
    -- Test:
    -- 1. Check that parse errors did not increase wildly. Because we explicitly test only a few
    --    :help files, we can be more precise about the tolerances here.
    -- 2. exercise gen_help_html.lua, check that it actually works.
    -- 3. check that its tree-sitter-vimdoc dependency is working.

    local tmpdir = exec_lua('return vim.fs.dirname(vim.fn.tempname())')
    -- Because gen() is slow (1 min), this test is limited to a few files.
    local rv = exec_lua([[
      local to_dir = ...
      return require('scripts.gen_help_html').gen(
        './build/runtime/doc',
        to_dir,
        { 'pi_health.txt', 'help.txt', 'index.txt', 'nvim.txt', }
      )
      ]],
      tmpdir
    )
    eq(4, #rv.helpfiles)
    ok(rv.err_count < 700, '<700', rv.err_count)
    -- TODO: should be eq(0, …)
    ok(exec_lua('return vim.tbl_count(...)', rv.invalid_tags) <= 32, '<=32',
      exec_lua('return vim.inspect(...)', rv.invalid_tags))
  end)
end)
