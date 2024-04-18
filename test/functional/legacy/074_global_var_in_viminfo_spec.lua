-- Tests for storing global variables in the .shada file

local t = require('test.functional.testutil')()
local clear, command, eq, neq, eval, poke_eventloop =
  t.clear, t.command, t.eq, t.neq, t.eval, t.poke_eventloop

describe('storing global variables in ShaDa files', function()
  local tempname = 'Xtest-functional-legacy-074'
  setup(function()
    clear()
    os.remove(tempname)
  end)

  it('is working', function()
    clear { args_rm = { '-i' }, args = { '-i', 'Xviminfo' } }

    local test_dict = { foo = 1, bar = 0, longvarible = 1000 }
    local test_list = {
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      24,
      25,
      26,
      27,
      28,
      29,
      30,
      31,
      32,
      33,
      34,
      35,
      36,
      37,
      38,
      39,
      40,
      41,
      42,
      43,
      44,
      45,
      46,
      47,
      48,
      49,
      50,
      51,
      52,
      53,
      54,
      55,
      56,
      57,
      58,
      59,
      60,
      61,
      62,
      63,
      64,
      65,
      66,
      67,
      68,
      69,
      70,
      71,
      72,
      73,
      74,
      75,
      76,
      77,
      78,
      79,
      80,
      81,
      82,
      83,
      84,
      85,
      86,
      87,
      88,
      89,
      90,
      91,
      92,
      93,
      94,
      95,
      96,
      97,
      98,
      99,
      100,
    }

    command('set visualbell')
    command('set shada+=!')
    command("let MY_GLOBAL_DICT={'foo': 1, 'bar': 0, 'longvarible': 1000}")
    -- Store a really long list. Initially this was testing line wrapping in
    -- viminfo, but shada files has no line wrapping, no matter how long the
    -- list is.
    command('let MY_GLOBAL_LIST=range(1, 100)')

    eq(test_dict, eval('MY_GLOBAL_DICT'))
    eq(test_list, eval('MY_GLOBAL_LIST'))

    command('wsh! ' .. tempname)
    poke_eventloop()

    -- Assert that the shada file exists.
    neq(nil, vim.uv.fs_stat(tempname))
    command('unlet MY_GLOBAL_DICT')
    command('unlet MY_GLOBAL_LIST')
    -- Assert that the variables where deleted.
    eq(0, eval('exists("MY_GLOBAL_DICT")'))
    eq(0, eval('exists("MY_GLOBAL_LIST")'))

    command('rsh! ' .. tempname)

    eq(test_list, eval('MY_GLOBAL_LIST'))
    eq(test_dict, eval('MY_GLOBAL_DICT'))
  end)

  teardown(function()
    os.remove(tempname)
  end)
end)
