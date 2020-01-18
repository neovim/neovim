local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local expect = helpers.expect
local feed = helpers.feed
local insert = helpers.insert
local meths = helpers.meths

describe('insert-mode Ctrl-O', function()
  before_each(clear)

  it('enters command mode for one command', function()
    feed('ihello world<C-o>')
    feed(':let ctrlo = "test"<CR>')
    feed('iii')
    expect('hello worldiii')
    eq(1, eval('ctrlo ==# "test"'))
  end)

  it('re-enters insert mode at the end of the line when running startinsert', function()
    -- #6962
    feed('ihello world<C-o>')
    feed(':startinsert<CR>')
    feed('iii')
    expect('hello worldiii')
  end)

  it('re-enters insert mode at the beginning of the line when running startinsert', function()
    insert('hello world')
    feed('0<C-o>')
    feed(':startinsert<CR>')
    feed('aaa')
    expect('aaahello world')
  end)

  it('re-enters insert mode in the middle of the line when running startinsert', function()
    insert('hello world')
    feed('bi<C-o>')
    feed(':startinsert<CR>')
    feed('ooo')
    expect('hello oooworld')
  end)

  it("doesn't cancel Ctrl-O mode when processing event", function()
    feed('iHello World<c-o>')
    eq({mode='niI', blocking=false}, meths.get_mode()) -- fast event
    eq(2, eval('1+1')) -- causes K_EVENT key
    eq({mode='niI', blocking=false}, meths.get_mode()) -- still in ctrl-o mode
    feed('dd')
    eq({mode='i', blocking=false}, meths.get_mode()) -- left ctrl-o mode
    expect('') -- executed the command
  end)
end)
