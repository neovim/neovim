local helpers = require('test.functional.helpers')(after_each)
local eq, clear, eval, feed, meths, retry =
  helpers.eq, helpers.clear, helpers.eval, helpers.feed, helpers.meths, helpers.retry

describe('K', function()
  local test_file = 'K_spec_out'
  before_each(function()
    clear()
    os.remove(test_file)
  end)
  after_each(function()
    os.remove(test_file)
  end)

  it("invokes colon-prefixed 'keywordprg' as Vim command", function()
    helpers.source([[
      let @a='fnord'
      set keywordprg=:put]])

    -- K on the text "a" resolves to `:put a`.
    feed('ia<ESC>K')
    helpers.expect([[
      a
      fnord]])
  end)

  it("invokes non-prefixed 'keywordprg' as shell command", function()
    helpers.source([[
      let @a='fnord'
      set keywordprg=echo\ fnord>>]])

    -- K on the text "K_spec_out" resolves to `!echo fnord >> K_spec_out`.
    feed('i'..test_file..'<ESC>K')
    retry(nil, nil, function() eq(1, eval('filereadable("'..test_file..'")')) end)
    eq({'fnord'}, eval("readfile('"..test_file.."')"))
    -- Confirm that Neovim is still in terminal mode after K is pressed (#16692).
    helpers.sleep(500)
    eq('t', eval('mode()'))
    feed('<space>')  -- Any key, not just <space>, can be used here to escape.
    eq('n', eval('mode()'))
  end)

  it("<esc> kills the buffer for a running 'keywordprg' command", function()
    helpers.source('set keywordprg=less')
    eval('writefile(["hello", "world"], "' .. test_file .. '")')
    feed('i' .. test_file .. '<esc>K')
    eq('t', eval('mode()'))
    -- Confirm that an arbitrary keypress doesn't escape (i.e., the process is
    -- still running). If the process were no longer running, an arbitrary
    -- keypress would escape.
    helpers.sleep(500)
    feed('<space>')
    eq('t', eval('mode()'))
    -- Confirm that <esc> kills the buffer for the running command.
    local bufnr = eval('bufnr()')
    feed('<esc>')
    eq('n', eval('mode()'))
    helpers.neq(bufnr, eval('bufnr()'))
  end)

  it('empty string falls back to :help #19298', function()
    meths.set_option_value('keywordprg', '', {})
    meths.buf_set_lines(0, 0, -1, true, {'doesnotexist'})
    feed('K')
    eq('E149: Sorry, no help for doesnotexist', meths.get_vvar('errmsg'))
  end)

end)
