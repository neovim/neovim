local helpers = require('test.functional.helpers')(after_each)
local clear, eval, eq = helpers.clear, helpers.eval, helpers.eq
local feed, command = helpers.feed, helpers.command

describe('ModeChanged', function()
  before_each(function()
    clear()
    command('let g:count = 0')
    command('au ModeChanged * let g:event = copy(v:event)')
    command('au ModeChanged * let g:count += 1')
  end)

  it('picks up terminal mode changes', function()
    command("term")
    feed('i')
    eq({
      old_mode = 'nt',
      new_mode = 't'
    }, eval('g:event'))
    feed('<c-\\><c-n>')
    eq({
      old_mode = 't',
      new_mode = 'nt'
    }, eval('g:event'))
    eq(3, eval('g:count'))
    command("bd!")

    -- v:event is cleared after the autocommand is done
    eq({}, eval('v:event'))
  end)
end)
