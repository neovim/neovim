-- Tests for the "term://" buffer name URI.
--
-- - jobstart()
-- - The ex_edit commands:
--    - :badd
--    - :balt
--    - :buffer
--    - :edit
--    - :pedit
-- - The ex_splitview commands:
--    - :split
--    - :vsplit
--    - :tabedit
--    - :tabfind
-- - The do_bufdel => buflist_findpat commands:
--    - :bdelete
--    - :bwipeout
-- - The goto_buffer commands:
--    - :buffer
--    - :sbuffer
--
-- - Other:
--    - :argadd
--    - :argedit
--    - :file

local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local Screen = require('test.functional.ui.screen')

local api = n.api
local command = n.command
local eq = t.eq
local fn = n.fn
local matches = t.matches
local ok = t.ok
local pesc = vim.pesc
local testprg = n.testprg

--- Asserts that the term:// URI is valid and returns the cmd args `["cmd", …]` part (where "cmd" is
--- the last segment of the absolute path, if it is absolute).
---
--- If the list form is not found, returns the string form.
---
--- @param buf? string
--- @return string # command + args
local function uri_args(buf)
  local b = buf or fn.bufname('%')
  -- Get the command + args from the URI.
  -- The other URI parts are fixed or system-specific, thus don't need to capture them.
  -- If this returns `nil` then that means the URI is malformed.
  local m = assert(b:match('term://.*//%d+:(.*)'), vim.inspect(b)) ---@type string
  -- testprg('shell-test')
  local listargs = m:match('%[(.*)%]')
  -- local fragment = m:match(…)
  if not listargs then
    return m
  end
  local cmdargs = vim.split(listargs, ',')
  -- "/foo/bar.exe" => "bar"
  local cmdname = assert(cmdargs[1]):gsub('.*[/\\]', ''):gsub('%.exe', '')
  cmdargs[1] = cmdname
  return ('[%s]'):format(table.concat(cmdargs, ','))
end

describe(':edit term://*', function()
  before_each(function()
    n.clear()
    api.nvim_set_option_value('shell', testprg('shell-test'), {})
    api.nvim_set_option_value('shellcmdflag', 'EXE', {})
  end)

  it('runs TermOpen event', function()
    api.nvim_set_var('termopen_runs', {})
    command('autocmd TermOpen * :call add(g:termopen_runs, expand("<amatch>"))')
    command('edit term://')
    local termopen_runs = api.nvim_get_var('termopen_runs')
    eq(1, #termopen_runs)
    local cwd = fn.fnamemodify('.', ':p:~'):gsub([[[\/]*$]], '')
    matches('^term://' .. pesc(cwd) .. '//%d+:$', termopen_runs[1])
  end)

  it('URI fragment', function()
    local screen = Screen.new(40, 4, { rgb = false })
    -- Don't need to escape "#" in a URI.
    command(
      ([[edit term://%s//\"%s\" arg1 arg2#my-fragment]]):format(
        n.nvim_dir,
        ('%sprintargs-test%s'):format(
          t.is_os('win') and '' or './',
          t.is_os('win') and '.exe' or ''
        )
      )
    )
    -- "#my-fragment" should NOT be sent to the shell.
    screen:expect {
      grid = [[
        ^ready $ "./printargs-test" arg1 arg2    |
                                                |
        [Process exited 0]                      |
                                                |
      ]],
    }
    matches([[printargs%-test.?e?x?e?" arg1 arg2#my%-fragment]], uri_args())

    command('edit test_alt_buf')
    command('edit test_new_buf')
    -- Don't need to escape "%", "#" in a URI.
    command(
      ([[edit term://\[\"%s\", \"arg#1\", \"arg%%2\"]#my-fragment]]):format(
        testprg('printargs-test')
      )
    )
    matches('[printargs-test", "arg#1", "arg%2"]', uri_args())
    -- "#my-fragment" should NOT be sent to the shell.
    screen:expect {
      grid = [[
        ^arg1=arg#1;arg2=arg%2;                  |
        [Process exited 0]                      |
                                                |*2
      ]],
    }
  end)

  it("runs TermOpen early enough to set buffer-local 'scrollback'", function()
    local columns, lines = 20, 4
    local screen = Screen.new(columns, lines, { rgb = false })
    local rep = 97
    api.nvim_set_option_value('shellcmdflag', 'REP ' .. rep, {})
    command('set shellxquote=') -- win: avoid extra quotes
    local sb = 10
    command(
      'autocmd TermOpen * :setlocal scrollback=' .. tostring(sb) .. '|call feedkeys("G", "n")'
    )
    command('edit term://foobar')

    local bufcontents = {} ---@type string[]
    local winheight = api.nvim_win_get_height(0)
    local buf_cont_start = rep - sb - winheight + 2
    for i = buf_cont_start, (rep - 1) do
      bufcontents[#bufcontents + 1] = ('%d: foobar'):format(i)
    end
    bufcontents[#bufcontents + 1] = ''
    bufcontents[#bufcontents + 1] = '[Process exited 0]'

    local exp_screen = '\n'
    for i = 1, (winheight - 1) do
      local line = bufcontents[#bufcontents - winheight + i]
      exp_screen = (exp_screen .. line .. (' '):rep(columns - #line) .. '|\n')
    end
    exp_screen = exp_screen .. '^[Process exited 0]  |\n'

    exp_screen = exp_screen .. (' '):rep(columns) .. '|\n'
    screen:expect(exp_screen)
    eq(bufcontents, api.nvim_buf_get_lines(0, 0, -1, true))
  end)

  it('handles truncated command JSON', function()
    -- jobstart(term=true) will truncate very long commands.
    -- The term://* BufReadCmd handler should not attempt to execute them.
    matches(
      'Command was truncated',
      t.pcall_err(n.command, 'edit ' .. fn.fnameescape([=[term://["ls", "..."] ]=]))
    )
  end)
end)

describe('jobstart(term=true)', function()
  before_each(function()
    n.clear()
    api.nvim_set_option_value('shell', testprg('shell-test'), {})
    api.nvim_set_option_value('shellcmdflag', 'EXE', {})
  end)

  it('sets full command as JSON array in term://… name', function()
    fn.jobstart({ testprg('shell-test'), 'arg#1', 'arg%2 with spaces' }, { term = true })
    -- Expected bufname: `term:///cwd//PID:["/path/to/shell-test", "arg1", "arg2"]`
    eq('[shell-test", "arg#1", "arg%2 with spaces"]', uri_args())

    command('enew!')
    -- Try a command with complex quoted args.
    fn.jobstart(
      { testprg('shell-test'), 'arg#1', [[["arg % 2"] "with" 'quotes']] },
      { term = true }
    )
    eq([=[[shell-test", "arg#1", "[\"arg % 2\"] \"with\" 'quotes'"]]=], uri_args())
  end)

  it('truncates term://… command JSON if too long', function()
    local long_arg = string.rep('x', 600)
    fn.jobstart({ testprg('shell-test'), 'arg1', '["arg 2"}', long_arg }, { term = true })
    -- Should look like: `term:///cwd//PID:["/path/to/shell-test", "arg1", "..."]`
    matches(
      [[^term://.*/%d+:%[".*/shell%-test%.?e?x?e?", "arg1", "%[\"arg 2\"}", "%.%.%."%]$]],
      fn.bufname('%')
    )
  end)
end)

describe(':argument', function()
  before_each(function()
    n.clear()
  end)

  it(':argadd does NOT magic-expand URI arg', function()
    eq({}, fn.argv())
    command([=[argadd term://[\"foo\",\ \"arg%#2\"]]=])
    eq({ 'term://["foo", "arg%#2"]' }, fn.argv())

    -- NOTE: :argdelete expects a Vim regex pattern, not a "filepath".
    -- Exercising it here anyway for reference.
    if t.is_os('win') then
      -- TODO(justinmk): why isn't "\[" needed on Windows?
      command([=[argdelete term://[\"foo\",\ \"arg%#2\"]]=])
    else
      -- "\[" is needed because :argdelete expects a Vim regex pattern.
      command([=[argdelete term://\[\"foo\",\ \"arg%#2\"]]=])
    end
    eq({}, fn.argv())
  end)

  it('does not restart :terminal buffer', function()
    command('terminal')
    command('argadd')
    local bufname_before = fn.bufname('%')
    local bufnr_before = fn.bufnr('%')
    matches('^term://', bufname_before) -- sanity

    command('argument 1')
    local bufname_after = fn.bufname('%')
    local bufnr_after = fn.bufnr('%')
    eq({ bufname_before }, fn.argv())
    ok(fn.line('$') > 1)
    eq(bufname_before, bufname_after)
    eq(bufnr_before, bufnr_after)
  end)
end)

-- TODO
-- describe(':file', function()
-- end)

describe(':badd', function()
  before_each(function()
    n.clear()
  end)

  it('does NOT magic-expand URI arg', function()
    eq('', fn.bufname('term*'))
    command([=[badd term://[\"echo\", \"\\"hi\\"\"]]=])
    if t.is_os('win') then
      -- TODO(justinmk): the '\' char is stripped on Windows, need to fix this.
      -- The buffer name should be preserved verbatim, Do not fsck with it!
      eq([=[term://["echo", ""hi""]]=], fn.bufname('term*'))
    else
      eq([=[term://["echo", "\"hi\""]]=], fn.bufname('term*'))
    end
  end)

  it('handles URI with fragment and special characters', function()
    command('edit foo')
    eq('', fn.bufname('term*'))
    command([=[badd term://[\"echo\", \"hi\"]#fragment]=])
    eq('foo', fn.bufname('#'))
    eq([=[term://["echo", "hi"]#fragment]=], fn.bufname('term*'))
  end)

  it('handles URI with percent and other special chars', function()
    command('edit foo')
    eq('', fn.bufname('term*'))
    command([=[badd term://path%20with%20spaces\#frag]=])
    eq([=[term://path%20with%20spaces#frag]=], fn.bufname('term*'))
    eq('foo', fn.bufname('%'))
  end)
end)

describe(':buffer', function()
  before_each(function()
    n.clear()
  end)

  it('does NOT magic-expand URI arg', function()
    command('enew')
    fn.jobstart(
      { testprg('shell-test'), 'arg#1', [[["arg % 2"] "with" 'quotes']] },
      { term = true }
    )
    local expected = [=[[shell-test", "arg#1", "[\"arg % 2\"] \"with\" 'quotes'"]]=]
    eq(expected, uri_args())
    command('edit foo')
    eq([[foo]], fn.bufname(''))
    command('buffer term://*\\[*]')
    eq(expected, uri_args())
  end)
end)

describe(':edit', function()
  before_each(function()
    n.clear()
  end)

  it('without arguments does not restart :terminal buffer', function()
    command('terminal')
    n.feed([[<C-\><C-N>]])
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
