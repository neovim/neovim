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
    -- 1. Fix/cleanup the :help docs.
    -- 2. Fix the parser: https://github.com/neovim/tree-sitter-vimdoc
    -- 3. File a parser bug, and adjust the tolerance of this test in the meantime.

    local rv = exec_lua([[return require('scripts.gen_help_html').validate('./build/runtime/doc')]])
    -- Check that we actually found helpfiles.
    ok(rv.helpfiles > 100, '>100 :help files', rv.helpfiles)

    eq({}, rv.parse_errors, 'no parse errors')
    eq(0,  rv.err_count, 'no parse errors')
    eq({}, rv.invalid_links, 'invalid tags in :help docs')
    eq({}, rv.invalid_urls, 'invalid URLs in :help docs')
    eq({}, rv.invalid_spelling, 'invalid spelling in :help docs (see spell_dict in scripts/gen_help_html.lua)')
  end)

  it('gen_help_html.lua generates HTML', function()
    -- 1. Test that gen_help_html.lua actually works.
    -- 2. Test that parse errors did not increase wildly. Because we explicitly test only a few
    --    :help files, we can be precise about the tolerances here.

    local tmpdir = exec_lua('return vim.fs.dirname(vim.fn.tempname())')
    -- Because gen() is slow (~30s), this test is limited to a few files.
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
    eq(0, rv.err_count, 'parse errors in :help docs')
    eq({}, rv.invalid_links, 'invalid tags in :help docs')
  end)
end)
