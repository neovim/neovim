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
local mkdir = helpers.mkdir
local rmdir = helpers.rmdir
local is_os = helpers.is_os

describe(':source', function()
  before_each(function()
    clear()
  end)

  it('sourcing a file that is deleted and recreated is consistent vim-patch:8.1.0151', function()
    local test_file = 'Xfile.vim'
    local other_file = 'Xfoobar'
    local script = [[
      func Func()
      endfunc
    ]]
    write_file(test_file, script)
    command('source ' .. test_file)
    os.remove(test_file)
    write_file(test_file, script)
    command('source ' .. test_file)
    os.remove(test_file)
    write_file(other_file, '')
    write_file(test_file, script)
    command('source ' .. test_file)
    os.remove(other_file)
    os.remove(test_file)
  end)

  it("changing 'shellslash' changes the result of expand()", function()
    if not is_os('win') then
      pending("'shellslash' only works on Windows")
      return
    end
    meths.set_option('shellslash', false)
    mkdir('Xshellslash')

    write_file([[Xshellslash/Xstack.vim]], [[
      let g:stack1 = expand('<stack>')
      set shellslash
      let g:stack2 = expand('<stack>')
      set noshellslash
      let g:stack3 = expand('<stack>')
    ]])

    for _ = 1, 2 do
      command([[source Xshellslash/Xstack.vim]])
      matches([[Xshellslash\Xstack%.vim]], meths.get_var('stack1'))
      matches([[Xshellslash/Xstack%.vim]], meths.get_var('stack2'))
      matches([[Xshellslash\Xstack%.vim]], meths.get_var('stack3'))
    end

    write_file([[Xshellslash/Xstack.lua]], [[
      vim.g.stack1 = vim.fn.expand('<stack>')
      vim.o.shellslash = true
      vim.g.stack2 = vim.fn.expand('<stack>')
      vim.o.shellslash = false
      vim.g.stack3 = vim.fn.expand('<stack>')
    ]])

    for _ = 1, 2 do
      command([[source Xshellslash/Xstack.lua]])
      matches([[Xshellslash\Xstack%.lua]], meths.get_var('stack1'))
      matches([[Xshellslash/Xstack%.lua]], meths.get_var('stack2'))
      matches([[Xshellslash\Xstack%.lua]], meths.get_var('stack3'))
    end

    rmdir('Xshellslash')
  end)

  it('current buffer', function()
    insert([[
      let a = 2
      let b = #{
        \ k: "v"
       "\ (o_o)
        \ }
      let c = expand("<SID>")->empty()
      let s:s = 0zbeef.cafe
      let d = s:s]])

    command('source')
    eq('2', meths.exec2('echo a', { output = true }).output)
    eq("{'k': 'v'}", meths.exec2('echo b', { output = true }).output)

    -- Script items are created only on script var access
    eq("1", meths.exec2('echo c', { output = true }).output)
    eq("0zBEEFCAFE", meths.exec2('echo d', { output = true }).output)

    exec('set cpoptions+=C')
    eq('Vim(let):E723: Missing end of Dictionary \'}\': ', exc_exec('source'))
  end)

  it('selection in current buffer', function()
    insert([[
      let a = 2
      let a = 3
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
    eq('3', meths.exec2('echo a', { output = true }).output)

    -- Source from 2nd line to end of file
    feed('ggjVG')
    feed_command(':source')
    eq('4', meths.exec2('echo a', { output = true }).output)
    eq("{'K': 'V'}", meths.exec2('echo b', { output = true }).output)
    eq("<SNR>1_C()", meths.exec2('echo D()', { output = true }).output)

    -- Source last line only
    feed_command(':$source')
    eq('Vim(echo):E117: Unknown function: s:C', exc_exec('echo D()'))

    exec('set cpoptions+=C')
    eq('Vim(let):E723: Missing end of Dictionary \'}\': ', exc_exec("'<,'>source"))
  end)

  it('does not break if current buffer is modified while sourced', function()
    insert [[
      bwipeout!
      let a = 123
    ]]
    command('source')
    eq('123', meths.exec2('echo a', { output = true }).output)
  end)

  it('multiline heredoc command', function()
    insert([[
      lua << EOF
      y = 4
      EOF]])

    command('source')
    eq('4', meths.exec2('echo luaeval("y")', { output = true }).output)
  end)

  it('can source lua files', function()
    local test_file = 'test.lua'
    write_file(test_file, [[
      vim.g.sourced_lua = 1
      vim.g.sfile_value = vim.fn.expand('<sfile>')
      vim.g.stack_value = vim.fn.expand('<stack>')
      vim.g.script_value = vim.fn.expand('<script>')
    ]])

    command('set shellslash')
    command('source ' .. test_file)
    eq(1, eval('g:sourced_lua'))
    matches([[/test%.lua$]], meths.get_var('sfile_value'))
    matches([[/test%.lua$]], meths.get_var('stack_value'))
    matches([[/test%.lua$]], meths.get_var('script_value'))

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

    write_file(test_file, [[
      vim.g.c = 10
      vim.g.c = 11
      vim.g.c = 12
      a = [=[
        \ 1
       "\ 2]=]
      vim.g.sfile_value = vim.fn.expand('<sfile>')
      vim.g.stack_value = vim.fn.expand('<stack>')
      vim.g.script_value = vim.fn.expand('<script>')
    ]])

    command('edit '..test_file)
    feed_command(':source')

    eq(12, eval('g:c'))
    eq('    \\ 1\n   "\\ 2', exec_lua('return _G.a'))
    eq(':source (no file)', meths.get_var('sfile_value'))
    eq(':source (no file)', meths.get_var('stack_value'))
    eq(':source (no file)', meths.get_var('script_value'))

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
