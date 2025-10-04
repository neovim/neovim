-- Ex cmdline buffer/filename handling for various commands:
-- The ex_edit commands:
--    :badd
--    :balt
--    :buffer
--    :edit
--    :pedit
-- The ex_splitview commands:
--    :split
--    :vsplit
--    :tabedit
--    :tabfind
-- The do_bufdel => buflist_findpat commands:
--    :bdelete
--    :bwipeout
-- The goto_buffer commands:
--    :buffer
--    :sbuffer
--
-- :argadd
-- :argedit
-- :file

local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq, command, fn = t.eq, n.command, n.fn
local ok = t.ok
local matches = t.matches
local clear = n.clear
local feed = n.feed

before_each(function()
  clear()
end)

describe(':argument', function()
  it(':argadd, :argdelete does NOT magic-expand URI arg', function()
    command([=[argadd term://[\"foo\"]]=])
    eq('[term://["foo"]]', vim.trim(fn.execute('args')))

    -- NOTE: :argdelete expects a Vim regex pattern, not a "filepath".
    if t.is_os('win') then
      -- TODO(justinmk): the '\' char is stripped on Windows, need to fix this.
      -- The buffer name should be preserved verbatim, DO NOT FSCK WITH IT!
      command([=[argdelete term://[\"foo\"]]=])
    else
      -- TODO(justinmk): should not need to escape the "[", URI should be treated literally.
      command([=[argdelete term://\[\"foo\"\]]=])
    end
    eq('', vim.trim(fn.execute('args')))
  end)

  it('does not restart :terminal buffer', function()
    command('terminal')
    n.feed([[<C-\><C-N>]])
    command('argadd')
    n.feed([[<C-\><C-N>]])
    local bufname_before = fn.bufname('%')
    local bufnr_before = fn.bufnr('%')
    matches('^term://', bufname_before) -- sanity

    command('argument 1')
    n.feed([[<C-\><C-N>]])

    local bufname_after = fn.bufname('%')
    local bufnr_after = fn.bufnr('%')
    eq('[' .. bufname_before .. ']', n.eval('trim(execute("args"))'))
    ok(fn.line('$') > 1)
    eq(bufname_before, bufname_after)
    eq(bufnr_before, bufnr_after)
  end)
end)

describe(':badd', function()
  it('does NOT magic-expand URI arg', function()
    command([=[badd term://[\"echo\", \"\\"hi\\"\"]]=])
    if t.is_os('win') then
      -- TODO(justinmk): the '\' char is stripped on Windows, need to fix this.
      -- The buffer name should be preserved verbatim, DO NOT FSCK WITH IT!
      eq([=[term://["echo", ""hi""]]=], fn.bufname('term*'))
    else
      eq([=[term://["echo", "\"hi\""]]=], fn.bufname('term*'))
    end
  end)
end)

describe(':buffer', function()
  -- TODO(justinmk) :buffer is not behaving yet 😇
  -- it('does NOT magic-expand URI arg', function()
  --   command([=[buffer term://[\"echo\", \"\\"hi\\"\"]]=])
  -- end)
end)

describe(':edit', function()
  it('without arguments does not restart :terminal buffer', function()
    command('terminal')
    feed([[<C-\><C-N>]])
    local bufname_before = fn.bufname('%')
    local bufnr_before = fn.bufnr('%')
    matches('^term://', bufname_before) -- sanity

    command('edit')

    local bufname_after = fn.bufname('%')
    local bufnr_after = fn.bufnr('%')
    ok(fn.line('$') > 1)
    eq(bufname_before, bufname_after)
    eq(bufnr_before, bufnr_after)
  end)
end)
