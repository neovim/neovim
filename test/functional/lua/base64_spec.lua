local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local pcall_err = helpers.pcall_err
local matches = helpers.matches

describe('vim.base64', function()
  before_each(clear)

  local function encode(s)
    return exec_lua([[return vim.base64.encode(...)]], s)
  end

  local function decode(s)
    return exec_lua([[return vim.base64.decode(...)]], s)
  end

  it('works', function()
    local values = {
      '',
      'Many hands make light work.',
      [[
        Call me Ishmael. Some years ago—never mind how long precisely—having little or no money in
        my purse, and nothing particular to interest me on shore, I thought I would sail about a
        little and see the watery part of the world.
      ]],
      [[
        It is a truth universally acknowledged, that a single man in possession of a good fortune,
        must be in want of a wife.
      ]],
      'Happy families are all alike; every unhappy family is unhappy in its own way.',
    }

    for _, v in ipairs(values) do
      eq(v, decode(encode(v)))
    end

    -- Explicitly check encoded output
    eq('VGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZwo=', encode('The quick brown fox jumps over the lazy dog\n'))

    -- Test vectors from rfc4648
    local rfc4648 = {
      { '', '' },
      { 'f', 'Zg==', },
      { 'fo', 'Zm8=' },
      { 'foo', 'Zm9v' },
      { 'foob', 'Zm9vYg==' },
      { 'fooba', 'Zm9vYmE=' },
      { 'foobar', 'Zm9vYmFy' },
    }

    for _, v in ipairs(rfc4648) do
      local input = v[1]
      local output = v[2]
      eq(output, encode(input))
      eq(input, decode(output))
    end
  end)

  it('detects invalid input', function()
    local invalid = {
      'A',
      'AA',
      'AAA',
      'A..A',
      'AA=A',
      'AA/=',
      'A/==',
      'A===',
      '====',
      'Zm9vYmFyZm9vYmFyA..A',
      'Zm9vYmFyZm9vYmFyAA=A',
      'Zm9vYmFyZm9vYmFyAA/=',
      'Zm9vYmFyZm9vYmFyA/==',
      'Zm9vYmFyZm9vYmFyA===',
      'A..AZm9vYmFyZm9vYmFy',
      'Zm9vYmFyZm9vAA=A',
      'Zm9vYmFyZm9vAA/=',
      'Zm9vYmFyZm9vA/==',
      'Zm9vYmFyZm9vA===',
    }

    for _, v in ipairs(invalid) do
      eq('Invalid input', pcall_err(decode, v))
    end

    eq('Expected 1 argument', pcall_err(encode))
    eq('Expected 1 argument', pcall_err(decode))
    matches('expected string', pcall_err(encode, 42))
    matches('expected string', pcall_err(decode, 42))
  end)
end)
