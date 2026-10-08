local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local eq = t.eq
local retry = t.retry

local clear = n.clear
local command = n.command
local exec_lua = n.exec_lua
local fn = n.fn
local testprg = n.testprg

describe(':terminal', function()
  before_each(clear)

  -- Copy `s` to the clipboard with an OSC 52 sequence from a terminal job.
  local function copy_via_osc52(s)
    command('enew!') -- `term = true` needs an empty buffer
    local seq = string.format('\027]52;;%s\027\\', vim.base64.encode(s))
    fn.jobstart({ testprg('shell-test'), '-t', seq }, { term = true })
  end

  local function expect_clipboard(expected)
    retry(nil, 1000, function()
      eq(expected, exec_lua('return vim.g.clipboard_data'))
    end)
  end

  -- Function provider recording the copy payload in g:clipboard_data.
  -- `blob` opts into the raw Blob.
  local function set_provider(blob)
    exec_lua(function(b)
      local function copy(data)
        vim.g.clipboard_data = data
      end
      local function paste()
        return { { 'from paste' }, 'v' }
      end
      vim.g.clipboard = {
        name = 'Test',
        blob = b,
        copy = { ['+'] = copy, ['*'] = copy },
        paste = { ['+'] = paste, ['*'] = paste },
      }
    end, blob)
  end

  it('OSC 52 copy passes a List of lines to a function provider', function()
    set_provider(false)
    command('set clipboard=unnamedplus')

    -- Multiline payloads must arrive split: a newline inside a list item would
    -- reach a command provider as NUL. Conversely a NUL becomes NL within its
    -- line (:help NL-used-for-Nul), and a trailing NL yields an empty line.
    copy_via_osc52('a\0b\nfoo\n\nbar\n') -- #41097
    expect_clipboard({ 'a\nb', 'foo', '', 'bar', '' })

    -- The cached payload is a Blob; comparing it with the List returned by
    -- paste must not raise E977 (Can only compare Blob with Blob).
    eq('from paste', fn.getreg('+'))
  end)

  it('OSC 52 copy passes a Blob to a function provider with blob = v:true', function()
    set_provider(true)

    copy_via_osc52('a\0b\n')
    expect_clipboard('a\0b\n') -- a Blob crosses into Lua as a binary string
  end)

  it('builtin OSC 52 provider forwards the Blob payload verbatim', function()
    exec_lua(function()
      vim.g.clipboard = 'osc52'
      vim.api.nvim_ui_send = function(seq)
        vim.g.clipboard_data = seq
      end
    end)

    copy_via_osc52('a\nb\0c\n')

    retry(nil, 1000, function()
      local seq = exec_lua('return vim.g.clipboard_data') or ''
      eq('a\nb\0c\n', vim.base64.decode(seq:match('\027%]52;%w?;([A-Za-z0-9+/=]*)') or ''))
    end)
  end)
end)
