local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear, insert, eq = n.clear, n.insert, t.eq
local command, expect = n.command, n.expect
local feed, eval = n.feed, n.eval
local exc_exec = n.exc_exec

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
