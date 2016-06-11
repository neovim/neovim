-- Specs for bang/filter commands

local helpers = require('test.functional.helpers')(after_each)
local feed, execute, clear = helpers.feed, helpers.execute, helpers.clear
local mkdir, write_file, rmdir = helpers.mkdir, helpers.write_file, helpers.rmdir

local Screen = require('test.functional.ui.screen')


describe('issues', function()
  local screen

  before_each(function()
    clear()
    rmdir('bang_filter_spec')
    mkdir('bang_filter_spec')
    write_file('bang_filter_spec/f1', 'f1')
    write_file('bang_filter_spec/f2', 'f2')
    write_file('bang_filter_spec/f3', 'f3')
    screen = Screen.new()
    screen:attach()
  end)

  after_each(function()
    rmdir('bang_filter_spec')
  end)

  it('#3269 Last line of shell output is not truncated', function()
    execute([[nnoremap <silent>\l :!ls bang_filter_spec<cr>]])
    feed([[\l]])
    screen:expect([[
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      :!ls bang_filter_spec                                |
                                                           |
      f1                                                   |
      f2                                                   |
      f3                                                   |
      Press ENTER or type command to continue^              |
    ]])
  end)

end)
