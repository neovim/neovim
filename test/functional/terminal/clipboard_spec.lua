local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local retry = t.retry
local matches = t.matches
local pcall_err = t.pcall_err
local is_os = t.is_os
local skip = t.skip
local tmpname = t.tmpname
local read_file = t.read_file

local clear = n.clear
local command = n.command
local fn = n.fn
local testprg = n.testprg
local exec_lua = n.exec_lua
local eval = n.eval

local text = 'line one\nline two\nline three'
local lines = { 'line one', 'line two', 'line three' }

describe(':terminal', function()
  before_each(function()
    clear()

    exec_lua([[
      local function clipboard(reg, type)
        if type == 'copy' then
          -- Function providers get a List of lines by default.
          return function(lines)
            vim.g.clipboard_data = table.concat(lines, '\n')
          end
        end

        if type == 'paste' then
          return function()
            error()
          end
        end

        error('invalid type: ' .. type)
      end

      vim.g.clipboard = {
        name = 'Test',
        copy = {
          ['+'] = clipboard('+', 'copy'),
          ['*'] = clipboard('*', 'copy'),
        },
        paste = {
          ['+'] = clipboard('+', 'paste'),
          ['*'] = clipboard('*', 'paste'),
        },
      }
    ]])
  end)

  local function osc52(arg)
    return string.format('\027]52;;%s\027\\', arg)
  end

  -- Send `text` to the terminal as an OSC 52 copy sequence.
  local function copy_via_osc52(text)
    local encoded = exec_lua('return vim.base64.encode(...)', text)
    fn.jobstart({ testprg('shell-test'), '-t', osc52(encoded) }, { term = true })
  end

  -- Function provider recording the copy payload; blob=true opts into a Blob.
  local function setup_fn_provider(blob)
    exec_lua(
      [[
      local blob = ...
      vim.g.clipboard = {
        name = 'TestFn',
        blob = blob,
        copy = {
          ['+'] = function(lines) vim.g.test_clip_data = lines end,
          ['*'] = function(lines) vim.g.test_clip_data = lines end,
        },
        paste = { ['+'] = function() error() end, ['*'] = function() error() end },
      }
    ]],
      blob
    )
  end

  -- Command provider writing stdin to `outfile`; cache=true keeps the copy job alive.
  local function setup_cmd_provider(outfile, cache)
    exec_lua(
      [[
      local outfile, cache = ...
      local cmd = { 'sh', '-c', 'cat > ' .. outfile .. (cache and '; sleep 10' or '') }
      vim.g.clipboard = {
        name = 'TestCmd',
        cache_enabled = cache and 1 or 0,
        copy = { ['+'] = cmd, ['*'] = cmd },
        paste = { ['+'] = { 'true' }, ['*'] = { 'true' } },
      }
    ]],
      outfile,
      cache
    )
  end

  it('can write to the system clipboard', function()
    eq('Test', eval('g:clipboard.name'))

    local input = 'Hello, world! This is some\nexample text\nthat spans multiple\nlines'
    copy_via_osc52(input)

    retry(nil, 1000, function()
      eq(input, exec_lua([[ return vim.g.clipboard_data ]]))
    end)
  end)

  it('passes a List of lines to a function provider without the blob key', function()
    setup_fn_provider(false)

    copy_via_osc52(text)
    retry(nil, 1000, function()
      eq(lines, exec_lua([[ return vim.g.test_clip_data ]]))
    end)

    -- A trailing newline yields a trailing empty line.
    command('enew!')
    copy_via_osc52('a\n')
    retry(nil, 1000, function()
      eq({ 'a', '' }, exec_lua([[ return vim.g.test_clip_data ]]))
    end)

    -- A NUL byte becomes NL within its line (:help NL-used-for-Nul).
    command('enew!')
    copy_via_osc52('a\0b')
    retry(nil, 1000, function()
      eq({ 'a\nb' }, exec_lua([[ return vim.g.test_clip_data ]]))
    end)
  end)

  it('passes the payload verbatim to a function provider with blob = true', function()
    setup_fn_provider(true)

    copy_via_osc52(text)
    retry(nil, 1000, function()
      -- A Blob crosses into Lua as a plain (binary) string.
      eq(text, exec_lua([[ return vim.g.test_clip_data ]]))
    end)
  end)

  it('preserves newlines when the payload goes to a command provider', function()
    skip(is_os('win'))
    -- Command providers get the payload on stdin; a list item's newline would
    -- become NUL (:help channel-lines), so the Blob must be written verbatim.
    local outfile = tmpname()
    setup_cmd_provider(outfile, false)

    copy_via_osc52(text)
    retry(nil, 1000, function()
      eq(text, read_file(outfile))
    end)
  end)

  it('preserves newlines with a cache_enabled command provider', function()
    skip(is_os('win'))
    -- cache_enabled: jobsend writes the Blob to the copy job's stdin verbatim;
    -- while the job lives, get() returns the cached Blob, split on paste.
    local outfile = tmpname()
    setup_cmd_provider(outfile, true)

    copy_via_osc52(text)
    retry(nil, 1000, function()
      eq(text, read_file(outfile))
    end)

    -- Copy job still alive, so the cached Blob is pasted (paste cmd unused).
    eq(lines, fn.getreg('+', 1, true))
  end)

  it('builtin OSC 52 provider forwards the Blob payload verbatim', function()
    -- s:set_osc52 marks itself blob-capable, so NUL/NL bytes survive.
    exec_lua([[
      vim.g.clipboard = 'osc52'
      _G.osc52_seq = nil
      vim.api.nvim_ui_send = function(seq) _G.osc52_seq = seq end
    ]])

    copy_via_osc52('a\nb\0c\n')

    retry(nil, 1000, function()
      eq(
        'a\nb\0c\n',
        exec_lua([[
          local enc = _G.osc52_seq and _G.osc52_seq:match('\027%]52;%w?;([A-Za-z0-9+/=]*)')
          return enc and vim.base64.decode(enc)
        ]])
      )
    end)
  end)

  it('does not error when pasting after an OSC 52 Blob was cached', function()
    exec_lua([[
      vim.g.clipboard = {
        name = 'TestBlobCache',
        copy = {
          ['+'] = function(lines) vim.g.clipboard_data = table.concat(lines, '\n') end,
          ['*'] = function(_lines) end,
        },
        paste = {
          ['+'] = function() return { { 'from paste' }, 'v' } end,
          ['*'] = function() return { { '' }, 'v' } end,
        },
      }
      vim.o.clipboard = 'unnamedplus'
    ]])

    copy_via_osc52(text)
    retry(nil, 1000, function()
      eq(text, exec_lua([[ return vim.g.clipboard_data ]]))
    end)

    -- Cached data[0] is a Blob; comparing it against the List paste result
    -- must not raise E977 (Can only compare Blob with Blob).
    eq('from paste', fn.getreg('+'))
  end)
end)

describe('clipboard paste', function()
  before_each(clear)

  -- Provider whose '+' paste returns [expr, 'v'].
  local function set_blob_paste(expr)
    command(
      (
        "let g:clipboard = {'name': 'TestBlobPaste',"
        .. " 'copy': {'+': {... -> 0}, '*': {... -> 0}},"
        .. " 'paste': {'+': {-> [%s, 'v']}, '*': {-> [0z, 'v']}}}"
      ):format(expr)
    )
  end

  it('splits a Blob clipboard payload on newlines when pasting', function()
    -- A provider that returns the selection as a Blob (as the cache does for
    -- an OSC 52 copy) must be split into register lines by get_clipboard().
    set_blob_paste('0z6c696e65206f6e650a6c696e652074776f0a6c696e65207468726565')
    eq(lines, fn.getreg('+', 1, true))
  end)

  it('substitutes NUL and keeps a trailing newline when splitting a Blob', function()
    -- 0z610a6200630a = "a\nb\0c\n": embedded NUL -> NL, trailing NL -> empty line.
    set_blob_paste('0z610a6200630a')
    eq({ 'a', 'b\nc', '' }, fn.getreg('+', 1, true))
    eq('v', fn.getregtype('+'))
  end)

  it('rejects a NULL Blob paste payload as invalid data', function()
    set_blob_paste('v:_null_blob')
    matches('clipboard: provider returned invalid data', pcall_err(command, "call getreg('+')"))
  end)
end)
