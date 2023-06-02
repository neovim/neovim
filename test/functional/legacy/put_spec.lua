local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local exec_lua = helpers.exec_lua
local meths = helpers.meths
local source = helpers.source
local eq = helpers.eq

local function sizeoflong()
  if not exec_lua('return pcall(require, "ffi")') then
    pending('missing LuaJIT FFI')
  end
  return exec_lua('return require("ffi").sizeof(require("ffi").typeof("long"))')
end

describe('put', function()
  before_each(clear)
  after_each(function() eq({}, meths.get_vvar('errors')) end)

  it('very large count 64-bit', function()
    if sizeoflong() < 8 then
      pending('Skipped: only works with 64 bit long ints')
    end

    source [[
      new
      let @" = repeat('x', 100)
      call assert_fails('norm 999999999p', 'E1240:')
      bwipe!
    ]]
  end)

  it('very large count (visual block) 64-bit', function()
    if sizeoflong() < 8 then
      pending('Skipped: only works with 64 bit long ints')
    end

    source [[
      new
      call setline(1, repeat('x', 100))
      exe "norm \<C-V>$y"
      call assert_fails('norm 999999999p', 'E1240:')
      bwipe!
    ]]
  end)

  -- oldtest: Test_put_other_window()
  it('above topline in buffer in two splits', function()
    local screen = Screen.new(80, 10)
    screen:attach()
    source([[
      40vsplit
      0put ='some text at the top'
      put ='  one more text'
      put ='  two more text'
      put ='  three more text'
      put ='  four more text'
    ]])

    screen:expect([[
      some text at the top                    │some text at the top                   |
        one more text                         │  one more text                        |
        two more text                         │  two more text                        |
        three more text                       │  three more text                      |
        ^four more text                        │  four more text                       |
                                              │                                       |
      ~                                       │~                                      |
      ~                                       │~                                      |
      [No Name] [+]                            [No Name] [+]                          |
                                                                                      |
    ]])
  end)

  -- oldtest: Test_put_in_last_displayed_line()
  it('in last displayed line', function()
    local screen = Screen.new(75, 10)
    screen:attach()
    source([[
      autocmd CursorMoved * eval line('w$')
      let @a = 'x'->repeat(&columns * 2 - 2)
      eval range(&lines)->setline(1)
      call feedkeys('G"ap')
    ]])

    screen:expect([[
      2                                                                          |
      3                                                                          |
      4                                                                          |
      5                                                                          |
      6                                                                          |
      7                                                                          |
      8                                                                          |
      9xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx|
      xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx^x |
                                                                                 |
    ]])
  end)
end)
