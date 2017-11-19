local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local funcs = helpers.funcs
local nvim_prog = helpers.nvim_prog
local nvim_set = helpers.nvim_set
local read_file = helpers.read_file
local retry = helpers.retry
local iswin = helpers.iswin

describe('startup', function()
  before_each(function()
    clear()
  end)
  after_each(function()
    os.remove('Xtest_startup_ttyout')
  end)

  it('pipe at both ends: has("ttyin")==0 has("ttyout")==0', function()
    -- system() puts a pipe at both ends.
    local out = funcs.system({ nvim_prog, '-u', 'NONE', '-i', 'NONE', '--headless',
                               '--cmd', nvim_set,
                               '-c', [[echo has('ttyin') has('ttyout')]],
                               '+q' })
    eq('0 0', out)
  end)
  it('with --embed: has("ttyin")==0 has("ttyout")==0', function()
    local screen = Screen.new(25, 3)
    -- Remote UI connected by --embed.
    screen:attach()
    command([[echo has('ttyin') has('ttyout')]])
    screen:expect([[
      ^                         |
      ~                        |
      0 0                      |
    ]])
  end)
  it('in a TTY: has("ttyin")==1 has("ttyout")==1', function()
    local screen = Screen.new(25, 3)
    screen:attach()
    if iswin() then
      command([[set shellcmdflag=/s\ /c shellxquote=\"]])
    end
    -- Running in :terminal
    command([[exe printf("terminal %s -u NONE -i NONE --cmd \"]]
            ..nvim_set..[[\" ]]
            ..[[-c \"echo has('ttyin') has('ttyout')\""]]
            ..[[, shellescape(v:progpath))]])
    screen:expect([[
      ^                         |
      1 1                      |
                               |
    ]])
  end)
  it('output to pipe: has("ttyin")==1 has("ttyout")==0', function()
    local screen = Screen.new(25, 5)
    screen:attach()
    if iswin() then
      command([[set shellcmdflag=/s\ /c shellxquote=\"]])
    end
    -- Running in :terminal
    command([[exe printf("terminal %s -u NONE -i NONE --cmd \"]]
            ..nvim_set..[[\" ]]
            ..[[-c \"call writefile([has('ttyin'), has('ttyout')], 'Xtest_startup_ttyout')\"]]
            ..[[-c q | cat -v"]]  -- Output to a pipe.
            ..[[, shellescape(v:progpath))]])
    retry(nil, 3000, function()
      screen:sleep(1)
      eq('1\n0\n',  -- stdin is a TTY, stdout is a pipe
         read_file('Xtest_startup_ttyout'))
    end)
  end)
  it('input from pipe: has("ttyin")==0 has("ttyout")==1', function()
    local screen = Screen.new(25, 5)
    screen:attach()
    if iswin() then
      command([[set shellcmdflag=/s\ /c shellxquote=\"]])
    end
    -- Running in :terminal
    command([[exe printf("terminal echo foo | ]]  -- Input from a pipe.
            ..[[%s -u NONE -i NONE --cmd \"]]
            ..nvim_set..[[\" ]]
            ..[[-c \"call writefile([has('ttyin'), has('ttyout')], 'Xtest_startup_ttyout')\"]]
            ..[[-c q -- -"]]
            ..[[, shellescape(v:progpath))]])
    retry(nil, 3000, function()
      screen:sleep(1)
      eq('0\n1\n',  -- stdin is a pipe, stdout is a TTY
         read_file('Xtest_startup_ttyout'))
    end)
  end)
end)

