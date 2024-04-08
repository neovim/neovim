-- Test for BufWritePre autocommand that deletes or unloads the buffer.
-- Test for BufUnload autocommand that unloads all other buffers.

local t = require('test.functional.testutil')(after_each)
local source = t.source
local clear, command, expect, eq, eval = t.clear, t.command, t.expect, t.eq, t.eval
local write_file, dedent = t.write_file, t.dedent
local read_file = t.read_file
local expect_exit = t.expect_exit

describe('autocommands that delete and unload buffers:', function()
  local test_file = 'Xtest-008_autocommands.out'
  local text1 = dedent([[
    start of Xxx1
      test
    end of Xxx]])
  local text2 = text1:gsub('1', '2')
  setup(function()
    write_file('Xxx1', text1 .. '\n')
    write_file('Xxx2', text2 .. '\n')
  end)
  teardown(function()
    os.remove(test_file)
    os.remove('Xxx1')
    os.remove('Xxx2')
  end)
  before_each(clear)

  it('BufWritePre, BufUnload', function()
    command('au BufWritePre Xxx1 bunload')
    command('au BufWritePre Xxx2 bwipe')
    command('e Xxx2')
    eq('Xxx2', eval('bufname("%")'))
    command('e Xxx1')
    eq('Xxx1', eval('bufname("%")'))
    -- The legacy test file did not check the error message.
    command('let v:errmsg = "no error"')
    command('silent! write')
    eq('E203: Autocommands deleted or unloaded buffer to be written', eval('v:errmsg'))
    eq('Xxx2', eval('bufname("%")'))
    expect(text2)
    -- Start editing Xxx2.
    command('e! Xxx2')
    -- The legacy test file did not check the error message.
    command('let v:errmsg = "no error"')
    -- Write Xxx2, will delete the buffer and give an error msg.
    command('silent! write')
    eq('E203: Autocommands deleted or unloaded buffer to be written', eval('v:errmsg'))
    eq('Xxx1', eval('bufname("%")'))
    expect(text1)
  end)
  it('BufUnload, VimLeave', function()
    source([[
      func CloseAll()
	let i = 0
	while i <= bufnr('$')
	  if i != bufnr('%') && bufloaded(i)
	    exe  i . "bunload"
	  endif
	  let i += 1
	endwhile
      endfunc
      func WriteToOut()
	edit! ]] .. test_file .. [[

	$put ='VimLeave done'
	write
      endfunc
      set shada='100
      au BufUnload * call CloseAll()
      au VimLeave * call WriteToOut()
    ]])
    -- Must disable 'hidden' so that the BufUnload autocmd is triggered between
    -- each :edit
    command('set nohidden')
    command('silent! edit Xxx2')
    command('silent! edit Xxx1')
    command('silent! edit Makefile') -- an existing file
    command('silent! split new2')
    expect_exit(command, 'silent! quit')
    eq('VimLeave done', string.match(read_file(test_file), '^%s*(.-)%s*$'))
  end)
end)
