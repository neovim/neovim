local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local command = helpers.command
local dedent = helpers.dedent
local eq = helpers.eq
local funcs = helpers.funcs
local exec = helpers.exec
local feed = helpers.feed

describe(":autocmd", function()
  before_each(function()
    clear({'-u', 'NONE'})
  end)

  it("should not segfault when you just do autocmd", function()
    command ":autocmd"
  end)

  it("should filter based on ++once", function()
    command "autocmd! BufEnter"
    command "autocmd BufEnter * :echo 'Hello'"
    command [[augroup TestingOne]]
    command [[  autocmd BufEnter * :echo "Line 1"]]
    command [[  autocmd BufEnter * :echo "Line 2"]]
    command [[augroup END]]

    eq(dedent([[

       --- Autocommands ---
       BufEnter
           *         :echo 'Hello'
       TestingOne  BufEnter
           *         :echo "Line 1"
                     :echo "Line 2"]]),
       funcs.execute('autocmd BufEnter'))

  end)

  it('should not show group information if interrupted', function()
    local screen = Screen.new(50, 6)
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},  -- NonText
      [2] = {bold = true, foreground = Screen.colors.SeaGreen},  -- MoreMsg
      [3] = {bold = true, foreground = Screen.colors.Magenta},  -- Title
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
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
    ]])
  end)
end)
