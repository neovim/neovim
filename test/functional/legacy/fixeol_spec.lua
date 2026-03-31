-- Tests for 'fixeol'

local n = require('test.functional.testnvim')()

local feed = n.feed
local clear, feed_command, expect = n.clear, n.feed_command, n.expect

describe('fixeol', function()
  local function rmtestfiles()
    os.remove('test.out')
    os.remove('XXEol')
    os.remove('XXNoEol')
    os.remove('XXTestEol')
    os.remove('XXTestNoEol')
  end
  setup(function()
    clear()
    rmtestfiles()
  end)
  teardown(function()
    rmtestfiles()
  end)

  it('is working', function()
    -- First write two test files – with and without trailing EOL.
    feed_command('enew!')
    feed('awith eol<esc>:w! XXEol<cr>')
    feed_command('enew!')
    feed_command('set noeol nofixeol')
    feed('awithout eol<esc>:w! XXNoEol<cr>')
    feed_command('set eol fixeol')
    feed_command('bwipe XXEol XXNoEol')

    -- Try editing files with 'fixeol' disabled.
    feed_command('e! XXEol')
    feed('ostays eol<esc>:set nofixeol<cr>')
    feed_command('w! XXTestEol')
    feed_command('e! XXNoEol')
    feed('ostays without<esc>:set nofixeol<cr>')
    feed_command('w! XXTestNoEol')
    feed_command('bwipe! XXEol XXNoEol XXTestEol XXTestNoEol')
    feed_command('set fixeol')

    -- Append "END" to each file so that we can see what the last written char was.
    feed('ggdGaEND<esc>:w >>XXEol<cr>')
    feed_command('w >>XXNoEol')
    feed_command('w >>XXTestEol')
    feed_command('w >>XXTestNoEol')

    -- Concatenate the results.
    feed_command('e! test.out')
    feed('a0<esc>:$r XXEol<cr>')
    feed_command('$r XXNoEol')
    feed('Go1<esc>:$r XXTestEol<cr>')
    feed_command('$r XXTestNoEol')
    feed_command('w')

    -- Assert buffer contents.
    expect([=[
      0
      with eol
      END
      without eolEND
      1
      with eol
      stays eol
      END
      without eol
      stays withoutEND]=])
  end)
end)
