-- Tests for 'fixeol'

local helpers = require('test.functional.helpers')(after_each)
local feed = helpers.feed
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

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
    -- Use Unix fileformat for consistency.
    execute('set ff=unix')
    execute('enew!')
    feed('awith eol<esc>:w! XXEol<cr>')
    execute('enew!')
    execute('set noeol nofixeol')
    feed('awithout eol<esc>:w! XXNoEol<cr>')
    execute('set eol fixeol')
    execute('bwipe XXEol XXNoEol')

    -- Try editing files with 'fixeol' disabled.
    execute('e! XXEol')
    feed('ostays eol<esc>:set nofixeol<cr>')
    execute('w! XXTestEol')
    execute('e! XXNoEol')
    feed('ostays without<esc>:set nofixeol<cr>')
    execute('w! XXTestNoEol')
    execute('bwipe XXEol XXNoEol XXTestEol XXTestNoEol')
    execute('set fixeol')

    -- Append "END" to each file so that we can see what the last written char was.
    feed('ggdGaEND<esc>:w >>XXEol<cr>')
    execute('w >>XXNoEol')
    execute('w >>XXTestEol')
    execute('w >>XXTestNoEol')

    -- Concatenate the results.
    execute('e! test.out')
    feed('a0<esc>:$r XXEol<cr>')
    execute('$r XXNoEol')
    feed('Go1<esc>:$r XXTestEol<cr>')
    execute('$r XXTestNoEol')
    execute('w')

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
