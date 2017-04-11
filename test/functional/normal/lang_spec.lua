local helpers = require('test.functional.helpers')(after_each)
local clear, insert, eq = helpers.clear, helpers.insert, helpers.eq
local command, expect = helpers.command, helpers.expect
local feed, eval = helpers.feed, helpers.eval
local exc_exec = helpers.exc_exec

describe('gu and gU', function()
  before_each(clear)

  it('works in any locale with default casemap', function()
    eq('internal,keepascii', eval('&casemap'))
    insert("iI")
    feed("VgU")
    expect("II")
    feed("Vgu")
    expect("ii")
  end)

  describe('works in Turkish locale', function()
    if helpers.pending_win32(pending) then return end

    clear()
    if eval('has("mac")') ~= 0 then
      pending("not yet on macOS", function() end)
      return
    end

    local err = exc_exec('lang ctype tr_TR.UTF-8')
    if err ~= 0 then
      pending("Locale tr_TR.UTF-8 not supported", function() end)
      return
    end

    before_each(function()
      command('lang ctype tr_TR.UTF-8')
    end)

    it('with default casemap', function()
      eq('internal,keepascii', eval('&casemap'))
      -- expect ASCII behavior
      insert("iI")
      feed("VgU")
      expect("II")
      feed("Vgu")
      expect("ii")
    end)

    it('with casemap=""', function()
      command('set casemap=')
      -- expect Turkish locale behavior
      insert("iI")
      feed("VgU")
      expect("İI")
      feed("Vgu")
      expect("iı")
    end)

  end)
end)
