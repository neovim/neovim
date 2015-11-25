-- Some sanity checks for the TUI using the builtin terminal emulator
-- as a simple way to send keys and assert screen state.
local helpers = require('test.functional.helpers')
local thelpers = require('test.functional.terminal.helpers')
local feed = thelpers.feed_data
local execute = helpers.execute
local nvim_dir = helpers.nvim_dir

describe('tui', function()
  local screen

  before_each(function()
    helpers.clear()
    screen = thelpers.screen_setup(0, '["'..helpers.nvim_prog..'", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile"]')
    -- right now pasting can be really slow in the TUI, especially in ASAN.
    -- this will be fixed later but for now we require a high timeout.
    screen.timeout = 60000
    screen:expect([[
      {1: }                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end)

  after_each(function()
    screen:detach()
  end)

  it('accepts basic utf-8 input', function()
    feed('iabc\ntest1\ntest2')
    screen:expect([[
      abc                                               |
      test1                                             |
      test2{1: }                                            |
      ~                                                 |
      [No Name] [+]                                     |
      -- INSERT --                                      |
      -- TERMINAL --                                    |
    ]])
    feed('\x1b')
    screen:expect([[
      abc                                               |
      test1                                             |
      test{1:2}                                             |
      ~                                                 |
      [No Name] [+]                                     |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end)

  it('interprets leading esc byte as the alt modifier', function()
    local keys = 'dfghjkl'
    for c in keys:gmatch('.') do
      execute('nnoremap <a-'..c..'> ialt-'..c..'<cr><esc>')
      feed('\x1b'..c)
    end
    screen:expect([[
      alt-j                                             |
      alt-k                                             |
      alt-l                                             |
      {1: }                                                 |
      [No Name] [+]                                     |
                                                        |
      -- TERMINAL --                                    |
    ]])
    feed('gg')
    screen:expect([[
      {1:a}lt-d                                             |
      alt-f                                             |
      alt-g                                             |
      alt-h                                             |
      [No Name] [+]                                     |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end)

  it('accepts ascii control sequences', function()
    feed('i')
    feed('\x16\x07') -- ctrl+g
    feed('\x16\x16') -- ctrl+v
    feed('\x16\x0d') -- ctrl+m
    screen:expect([[
    {3:^G^V^M}{1: }                                           |
    ~                                                 |
    ~                                                 |
    ~                                                 |
    [No Name] [+]                                     |
    -- INSERT --                                      |
    -- TERMINAL --                                    |
    ]], {[1] = {reverse = true}, [2] = {background = 11}, [3] = {foreground = 4}})
  end)

  it('automatically sends <Paste> for bracketed paste sequences', function()
    feed('i\x1b[200~')
    screen:expect([[
      {1: }                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      -- INSERT (paste) --                              |
      -- TERMINAL --                                    |
    ]])
    feed('pasted from terminal')
    screen:expect([[
      pasted from terminal{1: }                             |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name] [+]                                     |
      -- INSERT (paste) --                              |
      -- TERMINAL --                                    |
    ]])
    feed('\x1b[201~')
    screen:expect([[
      pasted from terminal{1: }                             |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name] [+]                                     |
      -- INSERT --                                      |
      -- TERMINAL --                                    |
    ]])
  end)

  it('can handle arbitrarily long bursts of input', function()
    execute('set ruler')
    local t = {}
    for i = 1, 3000 do
      t[i] = 'item ' .. tostring(i)
    end
    feed('i\x1b[200~')
    feed(table.concat(t, '\n'))
    feed('\x1b[201~')
    screen:expect([[
      item 2997                                         |
      item 2998                                         |
      item 2999                                         |
      item 3000{1: }                                        |
      [No Name] [+]                   3000,10        Bot|
      -- INSERT --                                      |
      -- TERMINAL --                                    |
    ]])
  end)
end)

describe('tui with non-tty file descriptors', function()
  before_each(helpers.clear)

  after_each(function()
    os.remove('testF') -- ensure test file is removed
  end)

  it('can handle pipes as stdout and stderr', function()
    local screen = thelpers.screen_setup(0, '"'..helpers.nvim_prog..' -u NONE -i NONE --cmd \'set noswapfile\' --cmd \'normal iabc\' > /dev/null 2>&1 && cat testF && rm testF"')
    screen:set_default_attr_ids({})
    screen:set_default_attr_ignore(true)
    feed(':w testF\n:q\n')
    screen:expect([[
      :w testF                                          |
      :q                                                |
      abc                                               |
                                                        |
      [Process exited 0]                                |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end)
end)

describe('tui focus event handling', function()
  local screen

  before_each(function()
    helpers.clear()
    screen = thelpers.screen_setup(0, '["'..helpers.nvim_prog..'", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile"]')
    execute('autocmd FocusGained * echo "gained"')
    execute('autocmd FocusLost * echo "lost"')
  end)

  it('can handle focus events in normal mode', function()
    feed('\x1b[I')
    screen:expect([[
      {1: }                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      gained                                            |
      -- TERMINAL --                                    |
    ]])

    feed('\x1b[O')
    screen:expect([[
      {1: }                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      lost                                              |
      -- TERMINAL --                                    |
    ]])
  end)

  it('can handle focus events in insert mode', function()
    execute('set noshowmode')
    feed('i')
    feed('\x1b[I')
    screen:expect([[
      {1: }                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      gained                                            |
      -- TERMINAL --                                    |
    ]])
    feed('\x1b[O')
    screen:expect([[
      {1: }                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      lost                                              |
      -- TERMINAL --                                    |
    ]])
  end)

  it('can handle focus events in cmdline mode', function()
    feed(':')
    feed('\x1b[I')
    screen:expect([[
                                                        |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      g{1:a}ined                                            |
      -- TERMINAL --                                    |
    ]])
    feed('\x1b[O')
    screen:expect([[
                                                        |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      l{1:o}st                                              |
      -- TERMINAL --                                    |
    ]])
  end)

  it('can handle focus events in terminal mode', function()
    execute('set shell='..nvim_dir..'/shell-test')
    execute('set laststatus=0')
    execute('set noshowmode')
    execute('terminal')
    feed('\x1b[I')
    screen:expect([[
      ready $                                           |
      [Process exited 0]{1: }                               |
                                                        |
                                                        |
                                                        |
      gained                                            |
      -- TERMINAL --                                    |
    ]])
   feed('\x1b[O')
    screen:expect([[
      ready $                                           |
      [Process exited 0]{1: }                               |
                                                        |
                                                        |
                                                        |
      lost                                              |
      -- TERMINAL --                                    |
    ]])
  end)
end)
