local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local lfs = require('lfs')
local command = helpers.command
local insert = helpers.insert
local clear = helpers.clear
local feed = helpers.feed
local nvim_async = helpers.nvim_async
local lfs = require('lfs')

describe('backupcopy=no fcnotify', function()
  local screen

  before_each(function()
    clear('--cmd', 'runtime plugin/fcnotify.vim')
    screen = Screen.new(50, 10)
    screen:attach()
    screen:set_default_attr_ids({
      EOB={bold = true, foreground = Screen.colors.Blue1},
      T={foreground=Screen.colors.Red},
      RBP1={background=Screen.colors.Red},
      RBP2={background=Screen.colors.Yellow},
      RBP3={background=Screen.colors.Green},
      RBP4={background=Screen.colors.Blue},
      SEP={bold = true, reverse = true},
      CONFIRM={bold = true, foreground = Screen.colors.SeaGreen4},
    })
  end)

  it('changed unmodified buffer', function()
    local path = 'Xtest-foo'
    helpers.write_file(path, 'aa bb')
    lfs.touch(path, os.time() - 10)
    command('set fcnotify=changed')

    command('edit '..path)
    -- TODO: Why is unload triggered here?
    screen:expect{grid=[[
      ^aa bb                                             |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      Xtest-foo not exists                              |
    ]]}



    local expected_additions = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, expected_additions)
    screen:expect{grid=[[
      ^line 1                                            |
      line 2                                            |
      line 3                                            |
      line 4                                            |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      "Xtest-foo" 4L, 28C                               |
    ]]}
  end)

  it('changed modified buffer', function()
    local path = 'Xtest-foo'
    helpers.write_file(path, 'aa bb')
    lfs.touch(path, os.time() - 10)
    command('set fcnotify=changed')

    command('edit '..path)
    feed([[o]])
    feed([[<esc>]])
    screen:expect{grid=[[
      aa bb                                             |
      ^                                                  |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
                                                        |
    ]]}

    local expected_additions = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, expected_additions)
    screen:expect{grid=[[
      aa bb                                             |
                                                        |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {SEP:                                                  }|
                                                        |
      {CONFIRM:File Xtest-foo changed. Would you like to reload?} |
      {CONFIRM:[Y]es, (S)how diff, (N)o: }^                        |
    ]]}

    feed([[<cr>]])
    -- TODO: Change this after fixing checktime prompt
    feed([[l]])
  end)

  it('never', function()
    local path = 'Xtest-foo'
    helpers.write_file(path, 'aa bb')
    lfs.touch(path, os.time() - 10)
    command('set fcnotify=changed')

    command('edit '..path)
    -- TODO: Why is unload triggered here?
    screen:expect{grid=[[
      ^aa bb                                             |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      Xtest-foo not exists                              |
    ]]}


    local expected_additions = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, expected_additions)
    screen:expect{grid=[[
      ^line 1                                            |
      line 2                                            |
      line 3                                            |
      line 4                                            |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      "Xtest-foo" 4L, 28C                               |
    ]]}
  end)

  it('always', function()
    local path = 'Xtest-foo'
    helpers.write_file(path, 'aa bb')
    lfs.touch(path, os.time() - 10)
    command('set fcnotify=always')

    command('edit '..path)
    -- TODO: Why is unload triggered here?
    screen:expect{grid=[[
      ^aa bb                                             |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      Xtest-foo not exists                              |
    ]]}


    local expected_additions = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, expected_additions)
    screen:expect{grid=[[
      aa bb                                             |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {SEP:                                                  }|
      Xtest-foo not exists                              |
      {CONFIRM:File Xtest-foo changed. Would you like to reload?} |
      {CONFIRM:[Y]es, (S)how diff, (N)o: }^                        |
    ]]}

    feed([[<cr>]])
  end)
end)

describe('backupcopy=yes fcnotify', function()
  local screen

  before_each(function()
    clear('--cmd', 'runtime plugin/fcnotify.vim', '-c', 'set backupcopy=yes')
    screen = Screen.new(50, 10)
    screen:attach()
    screen:set_default_attr_ids({
      EOB={bold = true, foreground = Screen.colors.Blue1},
      T={foreground=Screen.colors.Red},
      RBP1={background=Screen.colors.Red},
      RBP2={background=Screen.colors.Yellow},
      RBP3={background=Screen.colors.Green},
      RBP4={background=Screen.colors.Blue},
      SEP={bold = true, reverse = true},
      CONFIRM={bold = true, foreground = Screen.colors.SeaGreen4},
    })
  end)

  it('changed unmodified buffer', function()
    local path = 'Xtest-foo'
    helpers.write_file(path, 'aa bb')
    lfs.touch(path, os.time() - 10)
    command('set fcnotify=changed')

    command('edit '..path)
    -- TODO: Why is unload triggered here?
    screen:expect{grid=[[
      ^aa bb                                             |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      Xtest-foo not exists                              |
    ]]}


    local expected_additions = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, expected_additions)
    screen:expect{grid=[[
      ^line 1                                            |
      line 2                                            |
      line 3                                            |
      line 4                                            |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      "Xtest-foo" 4L, 28C                               |
    ]]}
  end)

  it('changed modified buffer', function()
    local path = 'Xtest-foo'
    helpers.write_file(path, 'aa bb')
    lfs.touch(path, os.time() - 10)
    command('set fcnotify=changed')

    command('edit '..path)
    feed([[o]])
    feed([[<esc>]])
    screen:expect{grid=[[
      aa bb                                             |
      ^                                                  |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
                                                        |
    ]]}

    local expected_additions = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, expected_additions)
    screen:expect{grid=[[
      aa bb                                             |
                                                        |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {SEP:                                                  }|
                                                        |
      {CONFIRM:File Xtest-foo changed. Would you like to reload?} |
      {CONFIRM:[Y]es, (S)how diff, (N)o: }^                        |
    ]]}

    feed([[<cr>]])
    -- TODO: Change this after fixing checktime prompt
    feed([[l]])
  end)

  it('never', function()
    local path = 'Xtest-foo'
    helpers.write_file(path, 'aa bb')
    lfs.touch(path, os.time() - 10)
    command('set fcnotify=changed')

    command('edit '..path)
    -- TODO: Why is unload triggered here?
    screen:expect{grid=[[
      ^aa bb                                             |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      Xtest-foo not exists                              |
    ]]}


    local expected_additions = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, expected_additions)
    screen:expect{grid=[[
      ^line 1                                            |
      line 2                                            |
      line 3                                            |
      line 4                                            |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      "Xtest-foo" 4L, 28C                               |
    ]]}
  end)

  it('always', function()
    local path = 'Xtest-foo'
    helpers.write_file(path, 'aa bb')
    lfs.touch(path, os.time() - 10)
    command('set fcnotify=always')

    command('edit '..path)
    -- TODO: Why is unload triggered here?
    screen:expect{grid=[[
      ^aa bb                                             |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      Xtest-foo not exists                              |
    ]]}


    local expected_additions = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, expected_additions)
    screen:expect{grid=[[
      aa bb                                             |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {SEP:                                                  }|
      Xtest-foo not exists                              |
      {CONFIRM:File Xtest-foo changed. Would you like to reload?} |
      {CONFIRM:[Y]es, (S)how diff, (N)o: }^                        |
    ]]}
    feed([[<cr>]])
  end)
end)
