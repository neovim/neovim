local helpers = require('test.functional.helpers')(after_each)
local command = helpers.command
local insert = helpers.insert
local eq = helpers.eq
local clear = helpers.clear
local meths = helpers.meths
local feed = helpers.feed
local feed_command = helpers.feed_command
local write_file = helpers.write_file
local exec = helpers.exec
local exc_exec = helpers.exc_exec
local exec_lua = helpers.exec_lua
local eval = helpers.eval
local exec_capture = helpers.exec_capture
local neq = helpers.neq
local matches = helpers.matches

describe(':source', function()
  before_each(function()
    clear()
  end)

  it('current buffer', function()
    insert([[
      let a = 2
      let b = #{
        \ k: "v"
       "\ (o_o)
        \ }
      let c = expand("<SID>") | set cursorline
      let s:s = 0zbeef.cafe
      let d = s:s]])

    command('source')
    eq('2', meths.exec('echo a', true))
    eq("{'k': 'v'}", meths.exec('echo b', true))
    eq("<SNR>1_", meths.exec('echo c', true))
    eq("0zBEEFCAFE", meths.exec('echo d', true))
    matches('line 6$', exec_capture('verbose set cursorline?'))

    exec('set cpoptions+=C')
    eq('Vim(let):E15: Invalid expression: #{', exc_exec('source'))
  end)

  it('selection in current buffer', function()
    insert([[
      let a = 2
      let a = 3 | set cursorline
      let a = 4
      let b = #{
       "\ (>_<)
        \ K: "V"
        \ }
      function! s:C() abort
        return expand("<SID>") .. "C()"
      endfunction
      let D = {-> s:C()}]])

    -- Source the 2nd line only
    feed('ggjV')
    feed_command(':source')
    eq('3', meths.exec('echo a', true))
    matches('line 2$', exec_capture('verbose set cursorline?'))

    -- Disable 'cursorline' to make sure the LastSet line nr is changed.
    feed_command('set nocursorline')
    eq('nocursorline', exec_capture('verbose set cursorline?'))

    -- Source from 2nd line to end of file
    feed('ggjVG')
    feed_command(':source')
    eq('4', meths.exec('echo a', true))
    eq("{'K': 'V'}", meths.exec('echo b', true))
    eq("<SNR>1_C()", meths.exec('echo D()', true))
    matches('line 2$', exec_capture('verbose set cursorline?'))

    -- Source last line only
    feed_command(':$source')
    eq("<SNR>1_C()", meths.exec('echo D()', true))

    exec('set cpoptions+=C')
    eq('Vim(let):E15: Invalid expression: #{', exc_exec("'<,'>source"))
  end)

  it('current buffer reuses SID', function()
    insert [[
      " also shouldn't cause a redefinition error when `:source`ing the
      " same buffer twice (script context uses a new sequence number)
      func s:Foo()
      endfunc
      let id = expand("<SID>")
    ]]
    command('source')
    eq("<SNR>1_", eval('g:id'))
    command('source')
    eq("<SNR>1_", eval('g:id'))

    -- Ensure a new buffer has a different SID
    command('new')
    insert [[
      let id = expand("<SID>")
    ]]
    command('source')
    eq("<SNR>2_", eval('g:id'))
    command('source')
    eq("<SNR>2_", eval('g:id'))

    command('wincmd p')
    command('source')
    eq("<SNR>1_", eval('g:id'))

    -- Scripts should be anonymous
    eq("", exec_capture(':scriptnames'))
  end)

  it('does not break if current buffer is modified while sourced', function()
    insert [[
      bwipeout!
      let a = 123
    ]]
    command('source')
    eq('123', meths.exec('echo a', true))
  end)

  it('multiline heredoc command', function()
    insert([[
      lua << EOF
      y = 4
      EOF]])

    command('source')
    eq('4', meths.exec('echo luaeval("y")', true))
  end)

  it('can source lua files', function()
    local test_file = 'test.lua'
    write_file (test_file, [[vim.g.sourced_lua = 1]])

    exec('source ' .. test_file)

    eq(1, eval('g:sourced_lua'))
    os.remove(test_file)
  end)

  it('can source selected region in lua file', function()
    local test_file = 'test.lua'

    write_file (test_file, [[
      vim.g.b = 5
      vim.g.b = 6
      vim.g.b = 7
      a = [=[
       "\ a
        \ b]=]
    ]])

    command('edit '..test_file)

    feed('ggjV')
    feed_command(':source')
    eq(6, eval('g:b'))

    feed('GVkk')
    feed_command(':source')
    eq('   "\\ a\n    \\ b', exec_lua('return _G.a'))

    os.remove(test_file)
  end)

  it('can source current lua buffer without argument', function()
    local test_file = 'test.lua'

    write_file (test_file, [[
      vim.g.c = 10
      vim.g.c = 11
      vim.g.c = 12
      a = [=[
        \ 1
       "\ 2]=]
      vim.cmd [=[
        let s:a = 3
        let g:a = expand('<SID>')
      ]=]
    ]])

    command('edit '..test_file)
    feed_command(':source')

    eq(12, eval('g:c'))
    eq('    \\ 1\n   "\\ 2', exec_lua('return _G.a'))
    eq('<SNR>1_', eval('g:a'))
    os.remove(test_file)
  end)

  it("doesn't throw E484 for lua parsing/runtime errors", function()
    local test_file = 'test.lua'

    -- Does throw E484 for unreadable files
    local ok, result = pcall(exec_capture, ":source "..test_file ..'noexisting')
    eq(false, ok)
    neq(nil, result:find("E484"))

    -- Doesn't throw for parsing error
    write_file (test_file, "vim.g.c = ")
    ok, result = pcall(exec_capture, ":source "..test_file)
    eq(false, ok)
    eq(nil, result:find("E484"))
    os.remove(test_file)

    -- Doesn't throw for runtime error
    write_file (test_file, "error('Cause error anyway :D')")
    ok, result = pcall(exec_capture, ":source "..test_file)
    eq(false, ok)
    eq(nil, result:find("E484"))
    os.remove(test_file)
  end)
end)
