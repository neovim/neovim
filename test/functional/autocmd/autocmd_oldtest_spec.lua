local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local eq = t.eq
local api = n.api
local fn = n.fn
local exec = n.exec
local feed = n.feed

describe('oldtests', function()
  before_each(clear)

  local exec_lines = function(str)
    return fn.split(fn.execute(str), '\n')
  end

  local add_an_autocmd = function()
    exec [[
      augroup vimBarTest
        au BufReadCmd * echo 'hello'
      augroup END
    ]]

    eq(3, #exec_lines('au vimBarTest'))
    eq(1, #api.nvim_get_autocmds({ group = 'vimBarTest' }))
  end

  it('should recognize a bar before the {event}', function()
    -- Good spacing
    add_an_autocmd()
    exec [[ augroup vimBarTest | au! | augroup END ]]
    eq(1, #exec_lines('au vimBarTest'))
    eq({}, api.nvim_get_autocmds({ group = 'vimBarTest' }))

    -- Sad spacing
    add_an_autocmd()
    exec [[ augroup vimBarTest| au!| augroup END ]]
    eq(1, #exec_lines('au vimBarTest'))

    -- test that a bar is recognized after the {event}
    add_an_autocmd()
    exec [[ augroup vimBarTest| au!BufReadCmd| augroup END ]]
    eq(1, #exec_lines('au vimBarTest'))

    add_an_autocmd()
    exec [[ au! vimBarTest|echo 'hello' ]]
    eq(1, #exec_lines('au vimBarTest'))
  end)

  -- oldtest: Test_delete_ml_get_errors()
  it('no ml_get error with TextChanged autocommand and delete', function()
    local screen = Screen.new(75, 10)
    screen:add_extra_attr_ids {
      [100] = { background = Screen.colors.Cyan1 },
    }
    exec([[
      set noshowcmd noruler scrolloff=0
      source test/old/testdir/samples/matchparen.vim
      edit test/old/testdir/samples/box.txt
    ]])
    feed('249GV<C-End>d')
    screen:expect([[
              const auto themeEmoji = _forPeer->themeEmoji();                    |
              if (themeEmoji.isEmpty()) {                                        |
                      return nonCustom;                                          |
              }                                                                  |
              const auto &themes = _forPeer->owner().cloudThemes();              |
              const auto theme = themes.themeForEmoji(themeEmoji);               |
              if (!theme) {100:{}                                                      |
                      return nonCustom;                                          |
              {100:^}}                                                                  |
      353 fewer lines                                                            |
    ]])
    feed('<PageUp>')
    screen:expect([[
                                                                                 |
      auto BackgroundBox::Inner::resolveResetCustomPaper() const                 |
      -> std::optional<Data::WallPaper> {                                        |
              if (!_forPeer) {                                                   |
                      return {};                                                 |
              }                                                                  |
              const auto nonCustom = Window::Theme::Background()->paper();       |
              const auto themeEmoji = _forPeer->themeEmoji();                    |
              ^if (themeEmoji.isEmpty()) {                                        |
      353 fewer lines                                                            |
    ]])
  end)
end)
