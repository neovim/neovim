local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')

local clear = t.clear
local command = t.command
local dedent = t.dedent
local eq = t.eq
local fn = t.fn
local eval = t.eval
local exec = t.exec
local feed = t.feed

describe(':autocmd', function()
  before_each(function()
    clear({ '-u', 'NONE' })
  end)

  it('should not segfault when you just do autocmd', function()
    command ':autocmd'
  end)

  it('should filter based on ++once', function()
    command 'autocmd! BufEnter'
    command "autocmd BufEnter * :echo 'Hello'"
    command [[augroup TestingOne]]
    command [[  autocmd BufEnter * :echo "Line 1"]]
    command [[  autocmd BufEnter * :echo "Line 2"]]
    command [[augroup END]]

    eq(
      dedent([[

       --- Autocommands ---
       BufEnter
           *         :echo 'Hello'
       TestingOne  BufEnter
           *         :echo "Line 1"
                     :echo "Line 2"]]),
      fn.execute('autocmd BufEnter')
    )
  end)

  it('should not show group information if interrupted', function()
    local screen = Screen.new(50, 6)
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue1 }, -- NonText
      [2] = { bold = true, foreground = Screen.colors.SeaGreen }, -- MoreMsg
      [3] = { bold = true, foreground = Screen.colors.Magenta }, -- Title
    })
    screen:attach()
    exec([[
      set more
      autocmd! BufEnter
      augroup test_1
        autocmd BufEnter A echo 'A'
        autocmd BufEnter B echo 'B'
        autocmd BufEnter C echo 'C'
        autocmd BufEnter D echo 'D'
        autocmd BufEnter E echo 'E'
        autocmd BufEnter F echo 'F'
      augroup END
      autocmd! BufLeave
      augroup test_1
        autocmd BufLeave A echo 'A'
        autocmd BufLeave B echo 'B'
        autocmd BufLeave C echo 'C'
        autocmd BufLeave D echo 'D'
        autocmd BufLeave E echo 'E'
        autocmd BufLeave F echo 'F'
      augroup END
    ]])
    feed(':autocmd<CR>')
    screen:expect([[
      :autocmd                                          |
      {3:--- Autocommands ---}                              |
      {3:test_1}  {3:BufEnter}                                  |
          A         echo 'A'                            |
          B         echo 'B'                            |
      {2:-- More --}^                                        |
    ]])
    feed('q')
    screen:expect([[
      ^                                                  |
      {1:~                                                 }|*4
                                                        |
    ]])
  end)

  it('should not show group information for deleted pattern', function()
    exec([[
      autocmd! BufEnter
      augroup test_1
        autocmd BufEnter A echo 'A'
        autocmd BufEnter B echo 'B'
        autocmd BufEnter C echo 'C'
      augroup END
      augroup test_2
        autocmd BufEnter foo echo 'foo'
      augroup END
      augroup test_3
        autocmd BufEnter D echo 'D'
        autocmd BufEnter E echo 'E'
        autocmd BufEnter F echo 'F'
      augroup END

      func Func()
        autocmd! test_2 BufEnter
        let g:output = execute('autocmd BufEnter')
      endfunc

      autocmd User foo call Func()
      doautocmd User foo
    ]])
    eq(
      dedent([[

      --- Autocommands ---
      test_1  BufEnter
          A         echo 'A'
          B         echo 'B'
          C         echo 'C'
      test_3  BufEnter
          D         echo 'D'
          E         echo 'E'
          F         echo 'F']]),
      eval('g:output')
    )
  end)

  it('can filter by pattern #17973', function()
    exec([[
      autocmd! BufEnter
      autocmd! User
      augroup test_1
        autocmd BufEnter A echo "A1"
        autocmd BufEnter B echo "B1"
        autocmd User A echo "A1"
        autocmd User B echo "B1"
      augroup END
      augroup test_2
        autocmd BufEnter A echo "A2"
        autocmd BufEnter B echo "B2"
        autocmd User A echo "A2"
        autocmd User B echo "B2"
      augroup END
      augroup test_3
        autocmd BufEnter A echo "A3"
        autocmd BufEnter B echo "B3"
        autocmd User A echo "A3"
        autocmd User B echo "B3"
      augroup END
    ]])
    eq(
      dedent([[

      --- Autocommands ---
      test_1  User
          A         echo "A1"
      test_2  User
          A         echo "A2"
      test_3  User
          A         echo "A3"]]),
      fn.execute('autocmd User A')
    )
    eq(
      dedent([[

      --- Autocommands ---
      test_1  BufEnter
          B         echo "B1"
      test_2  BufEnter
          B         echo "B2"
      test_3  BufEnter
          B         echo "B3"
      test_1  User
          B         echo "B1"
      test_2  User
          B         echo "B2"
      test_3  User
          B         echo "B3"]]),
      fn.execute('autocmd * B')
    )
    eq(
      dedent([[

      --- Autocommands ---
      test_3  BufEnter
          B         echo "B3"
      test_3  User
          B         echo "B3"]]),
      fn.execute('autocmd test_3 * B')
    )
  end)

  it('should skip consecutive patterns', function()
    exec([[
      autocmd! BufEnter
      augroup test_1
        autocmd BufEnter A echo 'A'
        autocmd BufEnter A echo 'B'
        autocmd BufEnter A echo 'C'
        autocmd BufEnter B echo 'D'
        autocmd BufEnter B echo 'E'
        autocmd BufEnter B echo 'F'
      augroup END
      augroup test_2
        autocmd BufEnter C echo 'A'
        autocmd BufEnter C echo 'B'
        autocmd BufEnter C echo 'C'
        autocmd BufEnter D echo 'D'
        autocmd BufEnter D echo 'E'
        autocmd BufEnter D echo 'F'
      augroup END

      let g:output = execute('autocmd BufEnter')
    ]])
    eq(
      dedent([[

      --- Autocommands ---
      test_1  BufEnter
          A         echo 'A'
                    echo 'B'
                    echo 'C'
          B         echo 'D'
                    echo 'E'
                    echo 'F'
      test_2  BufEnter
          C         echo 'A'
                    echo 'B'
                    echo 'C'
          D         echo 'D'
                    echo 'E'
                    echo 'F']]),
      eval('g:output')
    )
  end)
end)
