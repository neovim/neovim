local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local eq = t.eq
local api = n.api
local fn = n.fn
local exec = n.exec
local feed = n.feed
local assert_log = t.assert_log
local check_close = n.check_close
local is_os = t.is_os

local testlog = 'Xtest_autocmd_oldtest_log'

describe('oldtests', function()
  before_each(clear)

  after_each(function()
    check_close()
    os.remove(testlog)
  end)

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
    clear({ env = { NVIM_LOG_FILE = testlog } })
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

    if is_os('win') then
      assert_log('stream write failed. RPC canceled; closing channel', testlog)
    end
  end)

  -- oldtest: Test_delete_ml_get_errors()
  it('no ml_get error with TextChanged autocommand and delete', function()
    local screen = Screen.new(75, 10)
    screen:attach()
    screen:add_extra_attr_ids {
      [100] = { background = Screen.colors.Cyan1 },
    }
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
              if (!theme) {100:{}                                                      |
                      return nonCustom;                                          |
              {100:^}}                                                                  |
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
