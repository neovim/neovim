local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local retry = t.retry
local is_os = t.is_os
local skip = t.skip
local tmpname = t.tmpname

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
            -- A binary payload (e.g. OSC 52 from :terminal) arrives as a string "blob".
            local data = vim.islist(lines) and table.concat(lines, '\n') or lines
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

  local function osc52(arg)
    return string.format('\027]52;;%s\027\\', arg)
  end

  it('passes OSC 52 payload to a function provider verbatim as a string', function()
    exec_lua([[
      local function record(reg, type)
        if type == 'copy' then
          return function(lines)
            vim.g.test_clip_data = lines
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

    -- The payload reaches the provider as a string ("blob"), with newlines intact.
    local text = 'line one\nline two\nline three'
    local encoded = exec_lua('return vim.base64.encode(...)', text)
    fn.jobstart({ testprg('shell-test'), '-t', osc52(encoded) }, { term = true })

    retry(nil, 1000, function()
      eq(text, exec_lua([[ return vim.g.test_clip_data ]]))
    end)

    -- A trailing newline is preserved as-is.
    command('enew!')
    local trailing = 'a\n'
    local encoded_trailing = exec_lua('return vim.base64.encode(...)', trailing)
    fn.jobstart({ testprg('shell-test'), '-t', osc52(encoded_trailing) }, { term = true })

    retry(nil, 1000, function()
      eq(trailing, exec_lua([[ return vim.g.test_clip_data ]]))
    end)
  end)

  it('preserves newlines when OSC 52 payload goes to a channel provider', function()
    skip(is_os('win'))
    -- Channel providers get the payload on a job's stdin. A newline in a list item
    -- would be encoded as a NUL byte (:help channel-lines), collapsing the content.
    local outfile = tmpname()
    exec_lua(
      [[
      local outfile = ...
      vim.g.clipboard = {
        name = 'TestCmd',
        copy = {
          ['+'] = { 'sh', '-c', 'cat > ' .. outfile },
          ['*'] = { 'sh', '-c', 'cat > ' .. outfile },
        },
        paste = {
          ['+'] = { 'true' },
          ['*'] = { 'true' },
        },
      }
    ]],
      outfile
    )

    local text = 'line one\nline two\nline three'
    local encoded = exec_lua('return vim.base64.encode(...)', text)
    fn.jobstart({ testprg('shell-test'), '-t', osc52(encoded) }, { term = true })

    -- Read raw bytes: a buggy provider would write NUL separators here, not newlines.
    retry(nil, 1000, function()
      eq(
        text,
        exec_lua(
          [[
            local f = assert(io.open(..., 'rb'))
            local data = f:read('*a')
            f:close()
            return data
          ]],
          outfile
        )
      )
    end)
  end)
end)
