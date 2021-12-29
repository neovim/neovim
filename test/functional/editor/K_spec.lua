local helpers = require('test.functional.helpers')(after_each)
local eq, clear, eval, feed, retry =
  helpers.eq, helpers.clear, helpers.eval, helpers.feed, helpers.retry

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
  end)

end)
