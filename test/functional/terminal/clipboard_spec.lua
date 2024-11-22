local t = require('test.testutil')
local n = require('test.functional.testnvim')()

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

  it('can write to the system clipboard', function()
    eq('Test', eval('g:clipboard.name'))

    local text = 'Hello, world! This is some\nexample text\nthat spans multiple\nlines'
    local encoded = exec_lua('return vim.base64.encode(...)', text)

    local function osc52(arg)
      return string.format('\027]52;;%s\027\\', arg)
    end

    fn.jobstart({ testprg('shell-test'), '-t', osc52(encoded) }, { term = true })

    retry(nil, 1000, function()
      eq(text, exec_lua([[ return vim.g.clipboard_data ]]))
    end)
  end)
end)
