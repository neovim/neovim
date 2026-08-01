local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local eq = t.eq
local retry = t.retry

local clear = n.clear
local fn = n.fn
local testprg = n.testprg
local exec_lua = n.exec_lua
local eval = n.eval

describe(':terminal', function()
  before_each(function()
    clear()

    exec_lua([[
      local function clipboard(reg, type)
        if type == 'copy' then
          return function(lines)
            vim.g.clipboard_lines = lines
            local data = table.concat(lines, '\n')
            vim.g.clipboard_data = data
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

  it('can write to the system clipboard', function()
    eq('Test', eval('g:clipboard.name'))

    local text = 'Hello, world! This is some\nexample text\nthat spans multiple\nlines'
    local encoded = exec_lua('return vim.base64.encode(...)', text)

    fn.jobstart({ testprg('shell-test'), '-t', osc52(encoded) }, { term = true })

    retry(nil, 1000, function()
      eq(text, exec_lua([[ return vim.g.clipboard_data ]]))
    end)

    -- Multiline payloads must arrive split into separate list items: a newline
    -- inside a single item would be sent to a command-line provider as NUL.
    eq({
      'Hello, world! This is some',
      'example text',
      'that spans multiple',
      'lines',
    }, exec_lua([[ return vim.g.clipboard_lines ]]))
  end)

  it('multiline copy does not send newlines as NUL #41097', function()
    local text = '\nfoo\n\nbar\n'
    local encoded = exec_lua('return vim.base64.encode(...)', text)

    fn.jobstart({ testprg('shell-test'), '-t', osc52(encoded) }, { term = true })

    retry(nil, 1000, function()
      eq({ '', 'foo', '', 'bar', '' }, exec_lua([[ return vim.g.clipboard_lines ]]))
    end)
  end)
end)
