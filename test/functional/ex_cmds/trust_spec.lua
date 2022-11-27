local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local eq = helpers.eq
local clear = helpers.clear
local command = helpers.command
local pathsep = helpers.get_pathsep()
local iswin = helpers.iswin()
local funcs = helpers.funcs

describe(':trust', function()
  local xstate = 'Xstate'

  setup(function()
    helpers.mkdir_p(xstate .. pathsep .. (iswin and 'nvim-data' or 'nvim'))
  end)

  teardown(function()
    helpers.rmdir(xstate)
  end)

  before_each(function()
    helpers.write_file('test_file', 'test')
    clear{env={XDG_STATE_HOME=xstate}}
  end)

  after_each(function()
    os.remove('test_file')
  end)

  it('deny then allow then forget a file using current buffer', function()
    local screen = Screen.new(80, 8)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
    })

    local cwd = funcs.getcwd()
    local hash = funcs.sha256(helpers.read_file('test_file'))

    command('edit test_file')
    command('trust')
    screen:expect([[
      ^test                                                                            |
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      "]] .. cwd .. pathsep .. [[test_file" trusted.                                     |
    ]])
    trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('%s %s', hash, cwd .. pathsep .. 'test_file'), vim.trim(trust))

    command('trust ++deny')
    screen:expect([[
      ^test                                                                            |
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      "]] .. cwd .. pathsep .. [[test_file" denied.                                      |
    ]])
    local trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('! %s', cwd .. pathsep .. 'test_file'), vim.trim(trust))

    command('trust ++remove')
    screen:expect([[
      ^test                                                                            |
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      "]] .. cwd .. pathsep .. [[test_file" removed.                                     |
    ]])
    trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
    eq(string.format(''), vim.trim(trust))
  end)

  it('deny then allow then forget a file using current buffer', function()
    local screen = Screen.new(80, 8)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
    })

    local cwd = funcs.getcwd()
    local hash = funcs.sha256(helpers.read_file('test_file'))

    command('edit test_file')
    command('trust ++deny')
    screen:expect([[
      ^test                                                                            |
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      "]] .. cwd .. pathsep .. [[test_file" denied.                                      |
    ]])
    local trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('! %s', cwd .. pathsep .. 'test_file'), vim.trim(trust))

    command('trust')
    screen:expect([[
      ^test                                                                            |
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      "]] .. cwd .. pathsep .. [[test_file" trusted.                                     |
    ]])
    trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('%s %s', hash, cwd .. pathsep .. 'test_file'), vim.trim(trust))

    command('trust ++remove')
    screen:expect([[
      ^test                                                                            |
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      "]] .. cwd .. pathsep .. [[test_file" removed.                                     |
    ]])
    trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
    eq(string.format(''), vim.trim(trust))
  end)

  it('deny then forget a file using file path', function()
    local screen = Screen.new(80, 8)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
    })

    local cwd = funcs.getcwd()
    local hash = funcs.sha256(helpers.read_file('test_file'))

    command('trust ++deny test_file')
    screen:expect([[
      ^                                                                                |
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      "]] .. cwd .. pathsep .. [[test_file" denied.                                      |
    ]])
    trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
    eq(string.format('! %s', cwd .. pathsep .. 'test_file'), vim.trim(trust))

    command('trust ++remove test_file')
    screen:expect([[
      ^                                                                                |
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      "]] .. cwd .. pathsep .. [[test_file" removed.                                     |
    ]])
    trust = helpers.read_file(funcs.stdpath('state') .. pathsep .. 'trust')
    eq(string.format(''), vim.trim(trust))
  end)
end)
