local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local eq = helpers.eq
local api = helpers.api
local fn = helpers.fn
local exec = helpers.exec
local feed = helpers.feed

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

  it('should fire on unload buf', function()
    fn.writefile({ 'Test file Xxx1' }, 'Xxx1')
    fn.writefile({ 'Test file Xxx2' }, 'Xxx2')
    local fname = 'Xtest_functional_autocmd_unload'

    local content = [[
      func UnloadAllBufs()
        let i = 1
        while i <= bufnr('$')
          if i != bufnr('%') && bufloaded(i)
            exe  i . 'bunload'
          endif
          let i += 1
        endwhile
      endfunc
      au BufUnload * call UnloadAllBufs()
      au VimLeave * call writefile(['Test Finished'], 'Xout')
      set nohidden
      edit Xxx1
      split Xxx2
      q
    ]]

    fn.writefile(fn.split(content, '\n'), fname)

    fn.delete('Xout')
    fn.system(string.format('%s --clean -N -S %s', api.nvim_get_vvar('progpath'), fname))
    eq(1, fn.filereadable('Xout'))

    fn.delete('Xxx1')
    fn.delete('Xxx2')
    fn.delete(fname)
    fn.delete('Xout')
  end)

  -- oldtest: Test_delete_ml_get_errors()
  it('no ml_get error with TextChanged autocommand and delete', function()
    local screen = Screen.new(75, 10)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = { background = Screen.colors.Cyan },
    })
    exec([[
      set noshowcmd noruler scrolloff=0
      source test/old/testdir/samples/matchparen.vim
      edit test/old/testdir/samples/box.txt
    ]])
    feed('249GV<C-End>d')
    screen:expect {
      grid = [[
              const auto themeEmoji = _forPeer->themeEmoji();                    |
              if (themeEmoji.isEmpty()) {                                        |
                      return nonCustom;                                          |
              }                                                                  |
              const auto &themes = _forPeer->owner().cloudThemes();              |
              const auto theme = themes.themeForEmoji(themeEmoji);               |
              if (!theme) {1:{}                                                      |
                      return nonCustom;                                          |
              {1:^}}                                                                  |
      353 fewer lines                                                            |
    ]],
    }
    feed('<PageUp>')
    screen:expect {
      grid = [[
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
    ]],
    }
  end)
end)
