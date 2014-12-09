local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local clear, feed, execute = helpers.clear, helpers.feed, helpers.execute
local insert = helpers.insert

describe('Screen', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
  end)

  after_each(function()
    screen:detach()
  end)

  describe('window', function()
    describe('split', function()
      it('horizontal', function()
        execute('sp')
        screen:expect([[
          ^                                                    |
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
          ^                                                    |
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
          ^                   |                |               |
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
          hell^               |hello           |hello          |
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
        hell^               |hello           |hello          |
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
        hell^2                                               |
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
        hell^               |hello           |hello          |
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
        ^                                                    |
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
        :ls^                                                 |
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
        Press ENTER or type command to continue^             |
      ]])
      feed('<cr>') --  skip the "Press ENTER..." state or tests will hang
    end)
  end)
end)
