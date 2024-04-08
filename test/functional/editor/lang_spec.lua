local t = require('test.functional.testutil')(after_each)
local clear, insert, eq = t.clear, t.insert, t.eq
local command, expect = t.command, t.expect
local feed, eval = t.feed, t.eval
local exc_exec = t.exc_exec

describe('gu and gU', function()
  before_each(clear)

  it('works in any locale with default casemap', function()
    eq('internal,keepascii', eval('&casemap'))
    insert('iI')
    feed('VgU')
    expect('II')
    feed('Vgu')
    expect('ii')
  end)

  describe('works in Turkish locale', function()
    clear()

    local err = exc_exec('lang ctype tr_TR.UTF-8')
    if err ~= 0 then
      pending('Locale tr_TR.UTF-8 not supported', function() end)
      return
    end

    before_each(function()
      command('lang ctype tr_TR.UTF-8')
    end)

    it('with default casemap', function()
      eq('internal,keepascii', eval('&casemap'))
      -- expect ASCII behavior
      insert('iI')
      feed('VgU')
      expect('II')
      feed('Vgu')
      expect('ii')
    end)

    it('with casemap=""', function()
      command('set casemap=')
      -- expect either Turkish locale behavior or ASCII behavior
      local iupper = eval("toupper('i')")
      if iupper == 'İ' then
        insert('iI')
        feed('VgU')
        expect('İI')
        feed('Vgu')
        expect('iı')
      elseif iupper == 'I' then
        insert('iI')
        feed('VgU')
        expect('II')
        feed('Vgu')
        expect('ii')
      else
        error("expected toupper('i') to be either 'I' or 'İ'")
      end
    end)
  end)
end)
