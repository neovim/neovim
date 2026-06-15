local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local retry = t.retry

local clear = n.clear
local command = n.command
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

  it('splits OSC 52 clipboard payload into one list entry per line', function()
    exec_lua([[
      local function record(reg, type)
        if type == 'copy' then
          return function(lines)
            vim.g.test_clip_lines = lines
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
        name = 'TestRecord',
        copy = {
          ['+'] = record('+', 'copy'),
          ['*'] = record('*', 'copy'),
        },
        paste = {
          ['+'] = record('+', 'paste'),
          ['*'] = record('*', 'paste'),
        },
      }
    ]])

    local function osc52(arg)
      return string.format('\027]52;;%s\027\\', arg)
    end

    local text = 'line one\nline two\nline three'
    local encoded = exec_lua('return vim.base64.encode(...)', text)
    fn.jobstart({ testprg('shell-test'), '-t', osc52(encoded) }, { term = true })

    retry(nil, 1000, function()
      eq({ 'line one', 'line two', 'line three' }, exec_lua([[ return vim.g.test_clip_lines ]]))
    end)

    -- A trailing newline yields a final empty segment.
    command('enew!')
    local trailing = 'a\n'
    local encoded_trailing = exec_lua('return vim.base64.encode(...)', trailing)
    fn.jobstart({ testprg('shell-test'), '-t', osc52(encoded_trailing) }, { term = true })

    retry(nil, 1000, function()
      eq({ 'a', '' }, exec_lua([[ return vim.g.test_clip_lines ]]))
    end)
  end)
end)
