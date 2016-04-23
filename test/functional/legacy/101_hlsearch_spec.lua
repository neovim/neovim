-- Test for v:hlsearch

local helpers = require('test.functional.helpers')(after_each)
local clear, feed = helpers.clear, helpers.feed
local execute, expect = helpers.execute, helpers.expect

describe('v:hlsearch', function()
  setup(clear)

  it('is working', function()
    -- Last abc: Q
    execute('new')
    execute([[call setline(1, repeat(['aaa'], 10))]])
    execute('set hlsearch nolazyredraw')
    execute('let r=[]')
    execute('command -nargs=0 -bar AddR :call add(r, [screenattr(1, 1), v:hlsearch])')
    execute('/aaa')
    execute('AddR')
    execute('nohlsearch')
    execute('AddR')
    execute('let v:hlsearch=1')
    execute('AddR')
    execute('let v:hlsearch=0')
    execute('AddR')
    execute('set hlsearch')
    execute('AddR')
    execute('let v:hlsearch=0')
    execute('AddR')
    feed('n:AddR<cr>')
    execute('let v:hlsearch=0')
    execute('AddR')
    execute('/')
    execute('AddR')
    execute('set nohls')
    execute('/')
    execute('AddR')
    execute('let r1=r[0][0]')

    -- I guess it is not guaranteed that screenattr outputs always the same character
    execute([[call map(r, 'v:val[1].":".(v:val[0]==r1?"highlighted":"not highlighted")')]])
    execute('try')
    execute('   let v:hlsearch=[]')
    execute('catch')
    execute([[   call add(r, matchstr(v:exception,'^Vim(let):E\d\+:'))]])
    execute('endtry')
    execute('bwipeout!')
    execute('$put=r')
    execute('call garbagecollect(1)')
    execute('call getchar()')
    execute('1d', '1d')

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
      Vim(let):E706:]])
  end)
end)
