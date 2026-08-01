-- See also: test/old/testdir/test_options.vim
local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each, setup = t.describe, t.it, t.before_each, t.setup
local command, clear = n.command, n.clear
local poke_eventloop = n.poke_eventloop
local source, expect = n.source, n.expect
local eval = n.eval
local exec_lua = n.exec_lua
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

describe('callback (func/expr) options', function()
  before_each(clear)

  it('accept a Lua function, preserving identity and captured upvalues', function()
    -- 'operatorfunc' is global; 'tagfunc' is buffer-local: exercise both storage paths.
    eq(
      { identity = true, captured = 'CAP', kind = 'function', optset_old = '', optset_new = true },
      exec_lua(function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abcdef' })
        local captured = 'CAP'
        _G.seen = nil
        local fn = function(_)
          _G.seen = captured
        end
        -- OptionSet emits with Lua function as "<Lua …>".
        local optset
        vim.api.nvim_create_autocmd('OptionSet', {
          pattern = 'operatorfunc',
          callback = function()
            optset = { old = vim.v.option_old, new = vim.v.option_new }
          end,
        })
        vim.o.operatorfunc = fn
        vim.cmd('normal! g@l')
        return {
          identity = vim.o.operatorfunc == fn,
          captured = _G.seen,
          kind = type(vim.o.operatorfunc),
          optset_old = optset.old,
          optset_new = tostring(optset.new):match('^<Lua ') ~= nil,
        }
      end)
    )
    eq(
      true,
      exec_lua(function()
        local tfn = function(_, _, _)
          return {}
        end
        vim.bo.tagfunc = tfn
        return vim.bo.tagfunc == tfn
      end)
    )
    -- Vimscript GC traverses buffer-local callback options; a Lua-function callback must survive it
    -- garbagecollect() defers to main loop, so spin it with a motion to actually run collection.
    command('call garbagecollect(1)')
    n.feed('ll')
    poke_eventloop()
    eq('function', exec_lua('return type(vim.bo.tagfunc)'))
  end)

  it('accept a string funcref, read back as a string', function()
    eq(
      { type = 'string', value = 'SomeFunc' },
      exec_lua(function()
        vim.o.operatorfunc = 'SomeFunc'
        return { type = type(vim.o.operatorfunc), value = vim.o.operatorfunc }
      end)
    )
  end)

  it('reject a non-function, non-string value', function()
    matches(
      "Invalid 'operatorfunc': expected a valid type, got Integer",
      pcall_err(exec_lua, 'vim.o.operatorfunc = 42')
    )
    -- Only callback (func/expr) options accept a function; others reject it.
    matches(
      "Invalid 'statusline': expected a valid type, got Function",
      pcall_err(exec_lua, 'vim.o.statusline = function() end')
    )
    matches(
      "Invalid 'shiftwidth': expected a valid type, got Function",
      pcall_err(exec_lua, 'vim.bo.shiftwidth = function() end')
    )
  end)

  it("preserve a partial's bound args when the value is copied to the global default", function()
    -- 'tagfunc' is buffer-local; setting it also copies the value to the global default (which
    -- new buffers inherit). A partial must keep its bound args across that copy.
    command([[
      func! Foo(bound, pat, flags, info)
        return []
      endfunc
      set tagfunc=function('Foo',\ [10])
    ]])
    eq("function('Foo', [10])", eval('&g:tagfunc'))
  end)

  it('keep the previous callback when set to an invalid function', function()
    command('set operatorfunc=GoodFunc')
    matches('E700:', pcall_err(command, "set operatorfunc=function('NoSuchFuncXYZ')"))
    eq('GoodFunc', eval('&operatorfunc'))
  end)

  it(':set', function()
    command('set operatorfunc=SomeFunc')
    command('set quickfixtextfunc={\\ d\\ ->\\ []\\ }')
    exec_lua(function()
      vim.o.omnifunc = function() end
      vim.wo.foldexpr = function() end
    end)
    command('set all')
    n.assert_alive()

    -- ":set opt?" shows funcref/lambda name, or "<Lua …>".
    local function set_q(opt)
      return n.api.nvim_exec2(('set %s?'):format(opt), { output = true }).output
    end
    eq('  operatorfunc=SomeFunc', set_q('operatorfunc'))
    matches("^  quickfixtextfunc=function%('<lambda>%d+'%)$", set_q('quickfixtextfunc'))
    matches('^  omnifunc=<Lua .+:%d+>$', set_q('omnifunc'))
    matches('^  foldexpr=<Lua .+:%d+>$', set_q('foldexpr'))
    eq(set_q('omnifunc'), set_q('omnifunc')) -- Stable: no per-read ref id.

    -- ":set opt=<Tab>" completes a funcref value, but not a Lua function.
    eq({ 'SomeFunc' }, n.fn.getcompletion('set operatorfunc=', 'cmdline'))
    eq({}, n.fn.getcompletion('set omnifunc=', 'cmdline'))
  end)

  it("expr option ('foldexpr') accepts string, reads back string", function()
    eq(
      { kind = 'string', value = 'v:lnum - 1', l1 = 0, l3 = 2 },
      exec_lua(function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c', 'd' })
        vim.wo.foldmethod = 'expr'
        vim.wo.foldexpr = 'v:lnum - 1'
        return {
          kind = type(vim.wo.foldexpr),
          value = vim.wo.foldexpr,
          l1 = vim.fn.foldlevel(1),
          l3 = vim.fn.foldlevel(3),
        }
      end)
    )
  end)

  it("expr option ('foldexpr') accepts Lua function, preserving identity", function()
    -- Lua-function 'foldexpr' is invoked per line.
    eq(
      { identity = true, kind = 'function', l2 = 0, l3 = 1 },
      exec_lua(function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c', 'd' })
        local fn = function()
          return vim.v.lnum >= 3 and 1 or 0
        end
        vim.wo.foldmethod = 'expr'
        vim.wo.foldexpr = fn
        return {
          identity = vim.wo.foldexpr == fn,
          kind = type(vim.wo.foldexpr),
          l2 = vim.fn.foldlevel(2),
          l3 = vim.fn.foldlevel(3),
        }
      end)
    )
  end)

  it("buffer-local expr option ('indentexpr') accepts Lua function", function()
    -- Exercises the buffer-local Callback path (copy/free) and get_expr_indent via `==`.
    eq(
      { identity = true, indent = 8 },
      exec_lua(function()
        local myfn = function()
          return 8
        end
        vim.bo.indentexpr = myfn
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'line1', 'line2' })
        vim.cmd('normal! 2G==')
        return {
          identity = vim.bo.indentexpr == myfn,
          indent = vim.fn.indent(2),
        }
      end)
    )
  end)

  it("Lua function 'formatexpr' on another buffer (vim.bo[bufnr])", function()
    -- Sets via the non-curbuf API path (context switch), the way LSP configures 'formatexpr'.
    eq(
      { identity = true, cur_unchanged = true, invoked = true },
      exec_lua(function()
        local buf = vim.api.nvim_create_buf(true, false)
        local invoked = false
        local fexpr = function()
          invoked = true
          return 0
        end
        vim.bo[buf].formatexpr = fexpr
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'some text to format' })
        local identity = vim.bo[buf].formatexpr == fexpr
        vim.api.nvim_buf_call(buf, function()
          vim.cmd('normal! gqq')
        end)
        return {
          identity = identity,
          cur_unchanged = vim.bo.formatexpr == '',
          invoked = invoked,
        }
      end)
    )
  end)

  it("omits a Lua-function value from :mksession/:mkvimrc (no ':set' form)", function()
    -- A Lua function has no ":set" representation, so it must be skipped, not crash the writer.
    local session = exec_lua(function()
      vim.opt.sessionoptions:append('options')
      vim.o.operatorfunc = 'StrOpFunc' -- string funcref: written
      vim.o.quickfixtextfunc = function() end -- Lua function: omitted
      local f = vim.fn.tempname()
      vim.cmd('mksession! ' .. f)
      vim.cmd('mkvimrc! ' .. vim.fn.tempname()) -- also exercises the makeset()/put_set() path
      return table.concat(vim.fn.readfile(f), '\n')
    end)
    matches('operatorfunc=StrOpFunc', session)
    eq(nil, session:find('quickfixtextfunc'))
  end)
end)
