-- See also: test/old/testdir/test_options.vim
local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each, setup = t.describe, t.it, t.before_each, t.setup
local command, clear = n.command, n.clear
local source, expect = n.source, n.expect
local matches = t.matches
local pcall_err = t.pcall_err
local eq = t.eq

describe('options', function()
  setup(clear)

  it('should not throw any exception', function()
    command('options')
  end)
end)

describe('options :set', function()
  before_each(clear)

  it("should keep two comma when 'path' is changed", function()
    source([[
      set path=foo,,bar
      set path-=bar
      set path+=bar
      $put =&path]])

    expect([[

      foo,,bar]])
  end)

  it("'winminheight'", function()
    local _ = Screen.new(20, 11)
    source([[
      set wmh=0 stal=2
      below sp | wincmd _
      below sp | wincmd _
      below sp | wincmd _
      below sp
    ]])
    matches('E36: Not enough room', pcall_err(command, 'set wmh=1'))
  end)

  it("'winminheight' with tabline", function()
    local _ = Screen.new(20, 11)
    source([[
      set wmh=0 stal=2
      split
      split
      split
      split
      tabnew
    ]])
    matches('E36: Not enough room', pcall_err(command, 'set wmh=1'))
  end)

  it("'scroll'", function()
    local screen = Screen.new(42, 16)
    source([[
      set scroll=2
      set laststatus=2
    ]])
    command('verbose set scroll?')
    screen:expect([[
                                                |
      {1:~                                         }|*11
      {3:                                          }|
        scroll=7                                |
              Last set from changed window size |
      {6:Press ENTER or type command to continue}^   |
    ]])
  end)

  it('foldcolumn and signcolumn to empty string is disallowed', function()
    matches("E474: Invalid value ''.*fdc=", pcall_err(command, 'set fdc='))
    matches('E474: Invalid argument: scl=', pcall_err(command, 'set scl='))
  end)
end)

describe('options validation', function()
  before_each(clear)

  -- Improved error messages for structured "key:value" options ("schema" in options.lua).
  it('reports specific errors for structured (schema) options', function()
    eq("Vim(set):E474: Unknown item 'foo': diffopt=foo", pcall_err(command, 'set diffopt=foo'))
    eq(
      "Vim(set):E474: 'context' requires a number: diffopt=context:x",
      pcall_err(command, 'set diffopt=context:x')
    )
    eq(
      'Vim(set):E474: '
        .. "'algorithm' must be one of: myers, minimal, patience, histogram: diffopt=algorithm:bad",
      pcall_err(command, 'set diffopt=algorithm:bad')
    )
    eq(
      "Vim(set):E474: 'filler' does not take a value: diffopt=filler:1",
      pcall_err(command, 'set diffopt=filler:1')
    )
    eq(
      "Vim(set):E474: 'ver' number is out of range: mousescroll=ver:99999999999",
      pcall_err(command, 'set mousescroll=ver:99999999999')
    )
  end)

  -- Enum / flag-list options name the offending value and list the valid ones.
  it('reports specific errors for enum and flag-list options', function()
    eq(
      "Vim(set):E474: Invalid value 'x', expected one of: single, double: ambiwidth=x",
      pcall_err(command, 'set ambiwidth=x')
    )
    eq(
      'Vim(set):E474: '
        .. "Invalid value 'x', expected one of: yes, auto, no, breaksymlink, breakhardlink: backupcopy=x",
      pcall_err(command, 'set backupcopy=x')
    )
  end)
end)
