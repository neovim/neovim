-- Test for BufWritePre autocommand that deletes or unloads the buffer.
-- Test for BufUnload autocommand that unloads all other buffers.

local helpers = require('test.functional.helpers')(after_each)
local source = helpers.source
local clear, command, expect, eq, eval = helpers.clear, helpers.command, helpers.expect, helpers.eq, helpers.eval
local write_file, dedent = helpers.write_file, helpers.dedent
local read_file = helpers.read_file

describe('autocommands that delete and unload buffers:', function()
  local test_file = 'Xtest-008_autocommands.out'
  local text1 = dedent([[
    start of Xxx1
      test
    end of Xxx]])
  local text2 = text1:gsub('1', '2')
  setup(function()
    write_file('Xxx1', text1..'\n')
    write_file('Xxx2', text2..'\n')
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
    eq('E203: Autocommands deleted or unloaded buffer to be written',
      eval('v:errmsg'))
    eq('Xxx2', eval('bufname("%")'))
    expect(text2)
    -- Start editing Xxx2.
    command('e! Xxx2')
    -- The legacy test file did not check the error message.
    command('let v:errmsg = "no error"')
    -- Write Xxx2, will delete the buffer and give an error msg.
    command('silent! write')
    eq('E203: Autocommands deleted or unloaded buffer to be written',
      eval('v:errmsg'))
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
	edit! ]]..test_file..[[

	$put ='VimLeave done'
	write
      endfunc
      set shada='100
      au BufUnload * call CloseAll()
      au VimLeave * call WriteToOut()
    ]])
    command('silent! edit Xxx2')
    command('silent! edit Xxx1')
    command('silent! edit Makefile') -- an existing file
    command('silent! split new2')
    command('silent! quit')
    eq('VimLeave done',
       string.match(read_file(test_file), "^%s*(.-)%s*$"))
  end)
end)
