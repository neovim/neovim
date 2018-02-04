-- Test for BufWritePre autocommand that deletes or unloads the buffer.
-- Test for BufUnload autocommand that unloads all other buffers.

local helpers = require('test.functional.helpers')(after_each)
local feed, source = helpers.feed, helpers.source
local clear, feed_command, expect, eq, eval = helpers.clear, helpers.feed_command, helpers.expect, helpers.eq, helpers.eval
local write_file, wait, dedent = helpers.write_file, helpers.wait, helpers.dedent
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
    feed_command('au BufWritePre Xxx1 bunload')
    feed_command('au BufWritePre Xxx2 bwipe')
    feed_command('e Xxx2')
    eq('Xxx2', eval('bufname("%")'))
    feed_command('e Xxx1')
    eq('Xxx1', eval('bufname("%")'))
    -- The legacy test file did not check the error message.
    feed_command('let v:errmsg = "no error"')
    feed_command('write')
    -- Discard all "hit enter" prompts and messages.
    feed('<C-L>')
    eq('E203: Autocommands deleted or unloaded buffer to be written',
      eval('v:errmsg'))
    eq('Xxx2', eval('bufname("%")'))
    expect(text2)
    -- Start editing Xxx2.
    feed_command('e! Xxx2')
    -- The legacy test file did not check the error message.
    feed_command('let v:errmsg = "no error"')
    -- Write Xxx2, will delete the buffer and give an error msg.
    feed_command('w')
    -- Discard all "hit enter" prompts and messages.
    feed('<C-L>')
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
    feed_command('e Xxx2')
    -- Discard all "hit enter" prompts and messages.
    feed('<C-L>')
    feed_command('e Xxx1')
    -- Discard all "hit enter" prompts and messages.
    feed('<C-L>')
    feed_command('e Makefile') -- an existing file
    feed('<C-L>')
    feed_command('sp new2')
    feed('<C-L>')
    feed_command('q')
    wait()
    eq('VimLeave done',
       string.match(read_file(test_file), "^%s*(.-)%s*$"))
  end)
end)
