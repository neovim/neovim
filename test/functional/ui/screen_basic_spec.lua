local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local spawn, set_session, clear = helpers.spawn, helpers.set_session, helpers.clear
local feed, execute = helpers.feed, helpers.execute
local insert = helpers.insert

describe('Initial screen', function()
  local screen
  local nvim_argv = {helpers.nvim_prog, '-u', 'NONE', '-i', 'NONE', '-N',
                     '--cmd', 'set shortmess+=I background=light noswapfile',
                     '--embed'}

  before_each(function()
    local screen_nvim = spawn(nvim_argv)
    set_session(screen_nvim)
    screen = Screen.new()
    screen:attach()
    screen:set_default_attr_ignore( {{bold=true, foreground=255}} )
  end)

  after_each(function()
    screen:detach()
  end)

  it('is the default initial screen', function()
      screen:expect([[
      ^                                                     |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      [No Name]                                            |
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
    screen:set_default_attr_ignore( {{bold=true, foreground=255}} )
  end)

  after_each(function()
    screen:detach()
  end)

  describe(':suspend', function()
    it('is forwarded to the UI', function()
      local function check()
        if not screen.suspended then
          return 'Screen was not suspended'
        end
      end
      execute('suspend')
      screen:wait(check)
      screen.suspended = false
      feed('<c-z>')
      screen:wait(check)
    end)
  end)

  describe('bell/visual bell', function()
    it('is forwarded to the UI', function()
      feed('<left>')
      screen:wait(function()
        if not screen.bell or screen.visual_bell then
          return 'Bell was not sent'
        end
      end)
      screen.bell = false
      execute('set visualbell')
      feed('<left>')
      screen:wait(function()
        if not screen.visual_bell or screen.bell then
          return 'Visual bell was not sent'
        end
      end)
    end)
  end)

  describe(':set title', function()
    it('is forwarded to the UI', function()
      local expected = 'test-title'
      execute('set titlestring='..expected)
      execute('set title')
      screen:wait(function()
        local actual = screen.title
        if actual ~= expected then
          return 'Expected title to be "'..expected..'" but was "'..actual..'"'
        end
      end)
    end)

    it('has correct default title with unnamed file', function()
      local expected = '[No Name] - NVIM'
      execute('set title')
      screen:wait(function()
        local actual = screen.title
        if actual ~= expected then
          return 'Expected title to be "'..expected..'" but was "'..actual..'"'
        end
      end)
    end)

    it('has correct default title with named file', function()
      local expected = 'myfile (/mydir) - NVIM'
      execute('set title')
      execute('file /mydir/myfile')
      screen:wait(function()
        local actual = screen.title
        if actual ~= expected then
          return 'Expected title to be "'..expected..'" but was "'..actual..'"'
        end
      end)
    end)
  end)

  describe(':set icon', function()
    it('is forwarded to the UI', function()
      local expected = 'test-icon'
      execute('set iconstring='..expected)
      execute('set icon')
      screen:wait(function()
        local actual = screen.icon
        if actual ~= expected then
          return 'Expected title to be "'..expected..'" but was "'..actual..'"'
        end
      end)
    end)
  end)

  describe('window', function()
    describe('split', function()
      it('horizontal', function()
        execute('sp')
        screen:expect([[
          ^                                                     |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          [No Name]                                            |
                                                               |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          [No Name]                                            |
          :sp                                                  |
        ]])
      end)

      it('horizontal and resize', function()
        execute('sp')
        execute('resize 8')
        screen:expect([[
          ^                                                     |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          [No Name]                                            |
                                                               |
          ~                                                    |
          ~                                                    |
          [No Name]                                            |
          :resize 8                                            |
        ]])
      end)

      it('horizontal and vertical', function()
        execute('sp', 'vsp', 'vsp')
        screen:expect([[
          ^                    |                |               |
          ~                   |~               |~              |
          ~                   |~               |~              |
          ~                   |~               |~              |
          ~                   |~               |~              |
          ~                   |~               |~              |
          [No Name]            [No Name]        [No Name]      |
                                                               |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          [No Name]                                            |
                                                               |
        ]])
        insert('hello')
        screen:expect([[
          hell^o               |hello           |hello          |
          ~                   |~               |~              |
          ~                   |~               |~              |
          ~                   |~               |~              |
          ~                   |~               |~              |
          ~                   |~               |~              |
          [No Name] [+]        [No Name] [+]    [No Name] [+]  |
          hello                                                |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          [No Name] [+]                                        |
                                                               |
        ]])
      end)
    end)
  end)

  describe('tabnew', function()
    it('creates a new buffer', function()
      execute('sp', 'vsp', 'vsp')
      insert('hello')
      screen:expect([[
        hell^o               |hello           |hello          |
        ~                   |~               |~              |
        ~                   |~               |~              |
        ~                   |~               |~              |
        ~                   |~               |~              |
        ~                   |~               |~              |
        [No Name] [+]        [No Name] [+]    [No Name] [+]  |
        hello                                                |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        [No Name] [+]                                        |
                                                             |
      ]])
      execute('tabnew')
      insert('hello2')
      feed('h')
      screen:expect([[
         4+ [No Name]  + [No Name]                          X|
        hell^o2                                               |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
                                                             |
      ]])
      execute('tabprevious')
      screen:expect([[
         4+ [No Name]  + [No Name]                          X|
        hell^o               |hello           |hello          |
        ~                   |~               |~              |
        ~                   |~               |~              |
        ~                   |~               |~              |
        ~                   |~               |~              |
        ~                   |~               |~              |
        [No Name] [+]        [No Name] [+]    [No Name] [+]  |
        hello                                                |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        [No Name] [+]                                        |
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
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        -- INSERT --                                         |
      ]])
    end)
  end)

  describe('normal mode', function()
    -- https://code.google.com/p/vim/issues/detail?id=339
    it("setting 'ruler' doesn't reset the preferred column", function()
      execute('set virtualedit=')
      feed('i0123456<cr>789<esc>kllj')
      execute('set ruler')
      feed('k')
      screen:expect([[
        0123^456                                              |
        789                                                  |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        :set ruler                         1,5           All |
      ]])
    end)
  end)

  describe('command mode', function()
    it('typing commands', function()
      feed(':ls')
      screen:expect([[
                                                             |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        :ls^                                                  |
      ]])
    end)

    it('execute command with multi-line output', function()
      feed(':ls<cr>')
      screen:expect([[
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        :ls                                                  |
          1 %a   "[No Name]"                    line 1       |
        Press ENTER or type command to continue^              |
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
      execute('sp', 'vsp', 'vsp')
      screen:expect([[
        and                 |and             |and            |
        clearing            |clearing        |clearing       |
        in                  |in              |in             |
        split               |split           |split          |
        windows             |windows         |windows        |
        ^                    |                |               |
        [No Name] [+]        [No Name] [+]    [No Name] [+]  |
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        [No Name] [+]                                        |
                                                             |
      ]])
    end)

    it('only affects the current scroll region', function()
      feed('6k')
      screen:expect([[
        ^scrolling           |and             |and            |
        and                 |clearing        |clearing       |
        clearing            |in              |in             |
        in                  |split           |split          |
        split               |windows         |windows        |
        windows             |                |               |
        [No Name] [+]        [No Name] [+]    [No Name] [+]  |
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        [No Name] [+]                                        |
                                                             |
      ]])
      feed('<c-w>l')
      screen:expect([[
        scrolling           |and                 |and        |
        and                 |clearing            |clearing   |
        clearing            |in                  |in         |
        in                  |split               |split      |
        split               |windows             |windows    |
        windows             |^                    |           |
        [No Name] [+]        [No Name] [+]        <Name] [+] |
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        [No Name] [+]                                        |
                                                             |
      ]])
      feed('gg')
      screen:expect([[
        scrolling           |^Inserting           |and        |
        and                 |text                |clearing   |
        clearing            |with                |in         |
        in                  |many                |split      |
        split               |lines               |windows    |
        windows             |to                  |           |
        [No Name] [+]        [No Name] [+]        <Name] [+] |
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        [No Name] [+]                                        |
                                                             |
      ]])
      feed('7j')
      screen:expect([[
        scrolling           |with                |and        |
        and                 |many                |clearing   |
        clearing            |lines               |in         |
        in                  |to                  |split      |
        split               |test                |windows    |
        windows             |^scrolling           |           |
        [No Name] [+]        [No Name] [+]        <Name] [+] |
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        [No Name] [+]                                        |
                                                             |
      ]])
      feed('2j')
      screen:expect([[
        scrolling           |lines               |and        |
        and                 |to                  |clearing   |
        clearing            |test                |in         |
        in                  |scrolling           |split      |
        split               |and                 |windows    |
        windows             |^clearing            |           |
        [No Name] [+]        [No Name] [+]        <Name] [+] |
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        [No Name] [+]                                        |
                                                             |
      ]])
      feed('5k')
      screen:expect([[
        scrolling           |^lines               |and        |
        and                 |to                  |clearing   |
        clearing            |test                |in         |
        in                  |scrolling           |split      |
        split               |and                 |windows    |
        windows             |clearing            |           |
        [No Name] [+]        [No Name] [+]        <Name] [+] |
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        [No Name] [+]                                        |
                                                             |
      ]])
      feed('k')
      screen:expect([[
        scrolling           |^many                |and        |
        and                 |lines               |clearing   |
        clearing            |to                  |in         |
        in                  |test                |split      |
        split               |scrolling           |windows    |
        windows             |and                 |           |
        [No Name] [+]        [No Name] [+]        <Name] [+] |
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        [No Name] [+]                                        |
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
        ~                        |
        ~                        |
        ~                        |
        -- INSERT --             |
      ]])
    end)

    -- FIXME this has some race conditions that cause it to fail periodically
    pending('has minimum width/height values', function()
      screen:try_resize(1, 1)
      screen:expect([[
        -- INS^ERT --|
                    |
      ]])
      feed('<esc>:ls')
      screen:expect([[
        resize      |
        :ls^         |
      ]])
    end)
  end)
end)
