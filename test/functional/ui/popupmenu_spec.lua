local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed = helpers.clear, helpers.feed
local source = helpers.source

describe('ui/ext_popupmenu', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(60, 8)
    screen:attach({rgb=true, ext_popupmenu=true})
    screen:set_default_attr_ids({
      [1] = {bold=true, foreground=Screen.colors.Blue},
      [2] = {bold = true},
    })
  end)

  it('works', function()
    source([[
      function! TestComplete() abort
        call complete(1, ['foo', 'bar', 'spam'])
        return ''
      endfunction
    ]])
    local expected = {
      {'foo', '', '', ''},
      {'bar', '', '', ''},
      {'spam', '', '', ''},
    }
    feed('o<C-r>=TestComplete()<CR>')
    screen:expect{grid=[[
                                                                  |
      foo^                                                         |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=expected,
      pos=0,
      anchor={1,0},
    }}

    feed('<c-p>')
    screen:expect{grid=[[
                                                                  |
      ^                                                            |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=expected,
      pos=-1,
      anchor={1,0},
    }}

    -- down moves the selection in the menu, but does not insert anything
    feed('<down><down>')
    screen:expect{grid=[[
                                                                  |
      ^                                                            |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=expected,
      pos=1,
      anchor={1,0},
    }}

    feed('<cr>')
    screen:expect{grid=[[
                                                                  |
      bar^                                                         |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]]}
  end)
end)
