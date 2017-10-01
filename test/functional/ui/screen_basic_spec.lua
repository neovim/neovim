local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local spawn, set_session, clear = helpers.spawn, helpers.set_session, helpers.clear
local feed, command = helpers.feed, helpers.command
local insert = helpers.insert
local eq = helpers.eq
local eval = helpers.eval
local iswin = helpers.iswin

describe('screen', function()
  local screen
  local nvim_argv = {helpers.nvim_prog, '-u', 'NONE', '-i', 'NONE', '-N',
                     '--cmd', 'set shortmess+=I background=light noswapfile belloff= noshowcmd noruler',
                     '--embed'}

  before_each(function()
    local screen_nvim = spawn(nvim_argv)
    set_session(screen_nvim)
    screen = Screen.new()
    screen:attach()
    screen:set_default_attr_ids( {
      [0] = {bold=true, foreground=255},
      [1] = {bold=true, reverse=true},
    } )
  end)

  after_each(function()
    screen:detach()
  end)

  it('default initial screen', function()
      screen:expect([[
      ^                                                     |
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {1:[No Name]                                            }|
                                                           |
    ]])
  end)
end)

describe('Screen', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
    screen:set_default_attr_ids( {
      [0] = {bold=true, foreground=255},
      [1] = {bold=true, reverse=true},
      [2] = {bold=true},
      [3] = {reverse=true},
      [4] = {background = Screen.colors.LightGrey, underline = true},
      [5] = {background = Screen.colors.LightGrey, underline = true, bold = true, foreground = Screen.colors.Fuchsia},
      [6] = {bold = true, foreground = Screen.colors.Fuchsia},
      [7] = {bold = true, foreground = Screen.colors.SeaGreen},
    } )
  end)

  after_each(function()
    screen:detach()
  end)

  describe(':suspend', function()
    it('is forwarded to the UI', function()
      local function check()
        eq(true, screen.suspended)
      end
      command('suspend')
      screen:expect(check)
      screen.suspended = false
      feed('<c-z>')
      screen:expect(check)
    end)
  end)

  describe('bell/visual bell', function()
    it('is forwarded to the UI', function()
      feed('<left>')
      screen:expect(function()
        eq(true, screen.bell)
        eq(false, screen.visual_bell)
      end)
      screen.bell = false
      command('set visualbell')
      feed('<left>')
      screen:expect(function()
        eq(true, screen.visual_bell)
        eq(false, screen.bell)
      end)
    end)
  end)

  describe(':set title', function()
    it('is forwarded to the UI', function()
      local expected = 'test-title'
      command('set titlestring='..expected)
      command('set title')
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)

    it('has correct default title with unnamed file', function()
      local expected = '[No Name] - NVIM'
      command('set title')
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)

    it('has correct default title with named file', function()
      local expected = 'myfile (/mydir) - NVIM'
      if iswin() then
        expected = 'myfile (C:\\mydir) - NVIM'
      end
      command('set title')
      if iswin() then
        command('file C:\\mydir\\myfile')
      else
        command('file /mydir/myfile')
      end
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)
  end)

  describe(':set icon', function()
    it('is forwarded to the UI', function()
      local expected = 'test-icon'
      command('set iconstring='..expected)
      command('set icon')
      screen:expect(function()
        eq(expected, screen.icon)
      end)
    end)
  end)

  describe('window', function()
    describe('split', function()
      it('horizontal', function()
        command('sp')
        screen:expect([[
          ^                                                     |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {1:[No Name]                                            }|
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {3:[No Name]                                            }|
                                                               |
        ]])
      end)

      it('horizontal and resize', function()
        command('sp')
        command('resize 8')
        screen:expect([[
          ^                                                     |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {1:[No Name]                                            }|
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {3:[No Name]                                            }|
                                                               |
        ]])
      end)

      it('horizontal and vertical', function()
        command('sp')
        command('vsp')
        command('vsp')
        screen:expect([[
          ^                    {3:|}                {3:|}               |
          {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
          {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
          {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
          {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
          {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
          {1:[No Name]            }{3:[No Name]        [No Name]      }|
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {3:[No Name]                                            }|
                                                               |
        ]])
        insert('hello')
        screen:expect([[
          hell^o               {3:|}hello           {3:|}hello          |
          {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
          {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
          {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
          {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
          {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
          {1:[No Name] [+]        }{3:[No Name] [+]    [No Name] [+]  }|
          hello                                                |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {3:[No Name] [+]                                        }|
                                                               |
        ]])
      end)
    end)
  end)

  describe('tabnew', function()
    it('creates a new buffer', function()
      command('sp')
      command('vsp')
      command('vsp')
      insert('hello')
      screen:expect([[
        hell^o               {3:|}hello           {3:|}hello          |
        {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
        {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
        {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
        {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
        {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
        {1:[No Name] [+]        }{3:[No Name] [+]    [No Name] [+]  }|
        hello                                                |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
      command('tabnew')
      insert('hello2')
      feed('h')
      screen:expect([[
        {4: }{5:4}{4:+ [No Name] }{2: + [No Name] }{3:                         }{4:X}|
        hell^o2                                               |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])
      command('tabprevious')
      screen:expect([[
        {2: }{6:4}{2:+ [No Name] }{4: + [No Name] }{3:                         }{4:X}|
        hell^o               {3:|}hello           {3:|}hello          |
        {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
        {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
        {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
        {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
        {0:~                   }{3:|}{0:~               }{3:|}{0:~              }|
        {1:[No Name] [+]        }{3:[No Name] [+]    [No Name] [+]  }|
        hello                                                |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
    end)
  end)

  describe('insert mode', function()
    it('move to next line with <cr>', function()
      feed('iline 1<cr>line 2<cr>')
      screen:expect([[
        line 1                                               |
        line 2                                               |
        ^                                                     |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {2:-- INSERT --}                                         |
      ]])
    end)
  end)

  describe('normal mode', function()
    -- https://code.google.com/p/vim/issues/detail?id=339
    it("setting 'ruler' doesn't reset the preferred column", function()
      command('set virtualedit=')
      feed('i0123456<cr>789<esc>kllj')
      command('set ruler')
      feed('k')
      screen:expect([[
        0123^456                                              |
        789                                                  |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                           1,5           All |
      ]])
    end)
  end)

  describe('command mode', function()
    it('typing commands', function()
      feed(':ls')
      screen:expect([[
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        :ls^                                                  |
      ]])
    end)

    it('execute command with multi-line output', function()
      feed(':ls<cr>')
      screen:expect([[
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        :ls                                                  |
          1 %a   "[No Name]"                    line 1       |
        {7:Press ENTER or type command to continue}^              |
      ]])
      feed('<cr>') --  skip the "Press ENTER..." state or tests will hang
    end)
  end)

  describe('scrolling and clearing', function()
    before_each(function()
      insert([[
      Inserting
      text
      with
      many
      lines
      to
      test
      scrolling
      and
      clearing
      in
      split
      windows
      ]])
      command('sp')
      command('vsp')
      command('vsp')
      screen:expect([[
        and                 {3:|}and             {3:|}and            |
        clearing            {3:|}clearing        {3:|}clearing       |
        in                  {3:|}in              {3:|}in             |
        split               {3:|}split           {3:|}split          |
        windows             {3:|}windows         {3:|}windows        |
        ^                    {3:|}                {3:|}               |
        {1:[No Name] [+]        }{3:[No Name] [+]    [No Name] [+]  }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
    end)

    it('only affects the current scroll region', function()
      feed('6k')
      screen:expect([[
        ^scrolling           {3:|}and             {3:|}and            |
        and                 {3:|}clearing        {3:|}clearing       |
        clearing            {3:|}in              {3:|}in             |
        in                  {3:|}split           {3:|}split          |
        split               {3:|}windows         {3:|}windows        |
        windows             {3:|}                {3:|}               |
        {1:[No Name] [+]        }{3:[No Name] [+]    [No Name] [+]  }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
      feed('<c-w>l')
      screen:expect([[
        scrolling           {3:|}and                 {3:|}and        |
        and                 {3:|}clearing            {3:|}clearing   |
        clearing            {3:|}in                  {3:|}in         |
        in                  {3:|}split               {3:|}split      |
        split               {3:|}windows             {3:|}windows    |
        windows             {3:|}^                    {3:|}           |
        {3:[No Name] [+]        }{1:[No Name] [+]        }{3:<Name] [+] }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
      feed('gg')
      screen:expect([[
        scrolling           {3:|}^Inserting           {3:|}and        |
        and                 {3:|}text                {3:|}clearing   |
        clearing            {3:|}with                {3:|}in         |
        in                  {3:|}many                {3:|}split      |
        split               {3:|}lines               {3:|}windows    |
        windows             {3:|}to                  {3:|}           |
        {3:[No Name] [+]        }{1:[No Name] [+]        }{3:<Name] [+] }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
      feed('7j')
      screen:expect([[
        scrolling           {3:|}with                {3:|}and        |
        and                 {3:|}many                {3:|}clearing   |
        clearing            {3:|}lines               {3:|}in         |
        in                  {3:|}to                  {3:|}split      |
        split               {3:|}test                {3:|}windows    |
        windows             {3:|}^scrolling           {3:|}           |
        {3:[No Name] [+]        }{1:[No Name] [+]        }{3:<Name] [+] }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
      feed('2j')
      screen:expect([[
        scrolling           {3:|}lines               {3:|}and        |
        and                 {3:|}to                  {3:|}clearing   |
        clearing            {3:|}test                {3:|}in         |
        in                  {3:|}scrolling           {3:|}split      |
        split               {3:|}and                 {3:|}windows    |
        windows             {3:|}^clearing            {3:|}           |
        {3:[No Name] [+]        }{1:[No Name] [+]        }{3:<Name] [+] }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
      feed('5k')
      screen:expect([[
        scrolling           {3:|}^lines               {3:|}and        |
        and                 {3:|}to                  {3:|}clearing   |
        clearing            {3:|}test                {3:|}in         |
        in                  {3:|}scrolling           {3:|}split      |
        split               {3:|}and                 {3:|}windows    |
        windows             {3:|}clearing            {3:|}           |
        {3:[No Name] [+]        }{1:[No Name] [+]        }{3:<Name] [+] }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
      feed('k')
      screen:expect([[
        scrolling           {3:|}^many                {3:|}and        |
        and                 {3:|}lines               {3:|}clearing   |
        clearing            {3:|}to                  {3:|}in         |
        in                  {3:|}test                {3:|}split      |
        split               {3:|}scrolling           {3:|}windows    |
        windows             {3:|}and                 {3:|}           |
        {3:[No Name] [+]        }{1:[No Name] [+]        }{3:<Name] [+] }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
    end)
  end)

  describe('resize', function()
    before_each(function()
      screen:try_resize(25, 5)
      feed('iresize')
    end)

    it('rebuilds the whole screen', function()
      screen:expect([[
        resize^                   |
        {0:~                        }|
        {0:~                        }|
        {0:~                        }|
        {2:-- INSERT --}             |
      ]])
    end)

    it('has minimum width/height values', function()
      screen:try_resize(1, 1)
      screen:expect([[
        {2:-- INS^ERT --}|
                    |
      ]])
      feed('<esc>:ls')
      screen:expect([[
        resize      |
        :ls^         |
      ]])
    end)
  end)

  describe('press enter', function()
    it('does not crash on <F1> at “Press ENTER”', function()
      command('nnoremap <F1> :echo "TEST"<CR>')
      feed(':ls<CR>')
      screen:expect([[
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        :ls                                                  |
          1 %a   "[No Name]"                    line 1       |
        {7:Press ENTER or type command to continue}^              |
      ]])
      feed('<F1>')
      screen:expect([[
        ^                                                     |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        TEST                                                 |
      ]])
    end)
  end)
end)

describe('nvim_ui_attach()', function()
  before_each(function()
    clear()
  end)
  it('handles very large width/height #2180', function()
    local screen = Screen.new(999, 999)
    screen:attach()
    eq(999, eval('&lines'))
    eq(999, eval('&columns'))
  end)
  it('invalid option returns error', function()
    local screen = Screen.new()
    local status, rv = pcall(function() screen:attach({foo={'foo'}}) end)
    eq(false, status)
    eq('No such ui option', rv:match("No such .*"))
  end)
end)
