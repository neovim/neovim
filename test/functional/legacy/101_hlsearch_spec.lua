-- Test for v:hlsearch

local helpers = require('test.functional.helpers')(after_each)
local clear, feed = helpers.clear, helpers.feed
local feed_command, expect = helpers.feed_command, helpers.expect

describe('v:hlsearch', function()
  setup(clear)

  it('is working', function()
    -- Last abc: Q
    feed_command('new')
    feed_command([[call setline(1, repeat(['aaa'], 10))]])
    feed_command('set hlsearch nolazyredraw')
    feed_command('let r=[]')
    feed_command('command -nargs=0 -bar AddR :call add(r, [screenattr(1, 1), v:hlsearch])')
    feed_command('/aaa')
    feed_command('AddR')
    feed_command('nohlsearch')
    feed_command('AddR')
    feed_command('let v:hlsearch=1')
    feed_command('AddR')
    feed_command('let v:hlsearch=0')
    feed_command('AddR')
    feed_command('set hlsearch')
    feed_command('AddR')
    feed_command('let v:hlsearch=0')
    feed_command('AddR')
    feed('n:AddR<cr>')
    feed_command('let v:hlsearch=0')
    feed_command('AddR')
    feed_command('/')
    feed_command('AddR')
    feed_command('set nohls')
    feed_command('/')
    feed_command('AddR')
    feed_command('let r1=r[0][0]')

    -- I guess it is not guaranteed that screenattr outputs always the same character
    feed_command([[call map(r, 'v:val[1].":".(v:val[0]==r1?"highlighted":"not highlighted")')]])
    feed_command('try')
    feed_command('   let v:hlsearch=[]')
    feed_command('catch')
    feed_command([[   call add(r, matchstr(v:exception,'^Vim(let):E\d\+:'))]])
    feed_command('endtry')
    feed_command('bwipeout!')
    feed_command('$put=r')
    feed_command('call garbagecollect(1)')
    feed_command('call getchar()')
    feed_command('1d', '1d')

    -- Assert buffer contents.
    expect([[
      1:highlighted
      0:not highlighted
      1:highlighted
      0:not highlighted
      1:highlighted
      0:not highlighted
      1:highlighted
      0:not highlighted
      1:highlighted
      0:not highlighted
      Vim(let):E745:]])
  end)
end)
