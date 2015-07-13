-- Test for BufWritePre autocommand that deletes or unloads the buffer.
-- Test for BufUnload autocommand that unloads all other buffers.

local helpers = require('test.functional.helpers')(after_each)
local feed, source = helpers.feed, helpers.source
local clear, execute, expect, eq, eval = helpers.clear, helpers.execute, helpers.expect, helpers.eq, helpers.eval
local write_file, wait, dedent = helpers.write_file, helpers.wait, helpers.dedent
local io = require('io')

describe('autocommands that delete and unload buffers:', function()
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
    os.remove('test.out')
    os.remove('Xxx1')
    os.remove('Xxx2')
  end)
  before_each(clear)

  it('BufWritePre, BufUnload', function()
    execute('au BufWritePre Xxx1 bunload')
    execute('au BufWritePre Xxx2 bwipe')
    execute('e Xxx2')
    eq('Xxx2', eval('bufname("%")'))
    execute('e Xxx1')
    eq('Xxx1', eval('bufname("%")'))
    -- The legacy test file did not check the error message.
    execute('let v:errmsg = "no error"')
    execute('write')
    -- Discard all "hit enter" prompts and messages.
    feed('<C-L>')
    eq('E203: Autocommands deleted or unloaded buffer to be written',
      eval('v:errmsg'))
    eq('Xxx2', eval('bufname("%")'))
    expect(text2)
    -- Start editing Xxx2.
    execute('e! Xxx2')
    -- The legacy test file did not check the error message.
    execute('let v:errmsg = "no error"')
    -- Write Xxx2, will delete the buffer and give an error msg.
    execute('w')
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
	edit! test.out
	$put ='VimLeave done'
	write
      endfunc
      set shada='100
      au BufUnload * call CloseAll()
      au VimLeave * call WriteToOut()
    ]])
    execute('e Xxx2')
    -- Discard all "hit enter" prompts and messages.
    feed('<C-L>')
    execute('e Xxx1')
    -- Discard all "hit enter" prompts and messages.
    feed('<C-L>')
    execute('e Makefile') -- an existing file
    feed('<C-L>')
    execute('sp new2')
    feed('<C-L>')
    execute('q')
    wait()
    eq('\nVimLeave done\n', io.open('test.out', 'r'):read('*all'))
  end)
end)
