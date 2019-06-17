-- TUI tests for "bracketed paste" mode.
-- http://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h2-Bracketed-Paste-Mode
local helpers = require('test.functional.helpers')
local child_tui = require('test.functional.tui.child_session')
local Screen = require('test.functional.ui.screen')
local execute = helpers.execute
local nvim_dir = helpers.nvim_dir
local eval = helpers.eval
local eq = helpers.eq
local feed_tui = child_tui.feed_data

describe('tui paste', function()
  local screen

  before_each(function()
    helpers.clear()
    screen = child_tui.screen_setup(0, '["'..helpers.nvim_prog..
      '", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile"]')

    -- Pasting can be really slow in the TUI, especially in ASAN.
    screen.timeout = 5000

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

  local function setup_harness()
    -- Delete the default PastePre/PastePost autocmds.
    feed_tui(":autocmd! PastePre,PastePost\n")

    -- Set up test handlers.
    feed_tui(":autocmd PastePre * "..
      "call feedkeys('iPastePre mode:'.mode(),'n')\n")
    feed_tui(":autocmd PastePost * "..
      "call feedkeys('PastePost mode:'.mode(),'n')\n")
  end

  it('handles long bursts of input', function()
    execute('set ruler')
    local t = {}
    for i = 1, 3000 do
      t[i] = 'item ' .. tostring(i)
    end
    feed_tui('i\027[200~')
    feed_tui(table.concat(t, '\n'))
    feed_tui('\027[201~')
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

  it('raises PastePre, PastePost in normal-mode', function()
    setup_harness()

    -- Send the "start paste" sequence.
    feed_tui("\027[200~")
    feed_tui("\npasted from terminal (1)\npasted from terminal (2)\n")
    -- Send the "stop paste" sequence.
    feed_tui("\027[201~")

    screen:expect([[
      PastePre mode:n                                   |
      pasted from terminal (1)                          |
      pasted from terminal (2)                          |
      PastePost mode:i{1: }                                 |
      [No Name] [+]                                     |
      -- INSERT --                                      |
      -- TERMINAL --                                    |
    ]])
  end)

  it('forwards spurious "start paste" sequence', function()
    setup_harness()
    -- If multiple "start paste" sequences are sent without a corresponding
    -- "stop paste" sequence, only the first occurrence should be consumed.

    -- Send the "start paste" sequence.
    feed_tui("\027[200~")
    feed_tui("\npasted from terminal (1)\n")
    -- Send spurious "start paste" sequence.
    feed_tui("\027[200~")
    feed_tui("\n")
    -- Send the "stop paste" sequence.
    feed_tui("\027[201~")

    screen:expect([[
      PastePre mode:n                                   |
      pasted from terminal (1)                          |
      {1:^[}200~                                            |
      PastePost mode:i{2: }                                 |
      [No Name] [+]                                     |
      -- INSERT --                                      |
      -- TERMINAL --                                    |
    ]], {
      [1] = {foreground = 4},
      [2] = {reverse = true},
    })
  end)

  it('ignores spurious "stop paste" sequence', function()
    setup_harness()
    -- If "stop paste" sequence is received without a preceding "start paste"
    -- sequence, it should be ignored.

    feed_tui("i")
    -- Send "stop paste" sequence.
    feed_tui("\027[201~")

    screen:expect([[
      {1: }                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      -- INSERT --                                      |
      -- TERMINAL --                                    |
    ]])
  end)

  it('raises PastePre, PastePost in command-mode', function()
    -- The default PastePre/PastePost handlers set the 'paste' option. To test,
    -- we define a command-mode map, then assert that the mapping was ignored
    -- during paste.
    feed_tui(":cnoremap st XXX\n")

    feed_tui(":not pasted")

    -- Paste did not start, so the mapping _should_ apply.
    screen:expect([[
                                                        |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      :not paXXXed{1: }                                     |
      -- TERMINAL --                                    |
    ]])

    feed_tui("\003")      -- CTRL-C
    feed_tui(":")
    feed_tui("\027[200~") -- Send the "start paste" sequence.
    feed_tui("pasted")

    -- Paste started, so the mapping should _not_ apply.
    screen:expect([[
                                                        |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      :pasted{1: }                                          |
      -- TERMINAL --                                    |
    ]])

    feed_tui("\003")      -- CTRL-C
    feed_tui(":")
    feed_tui("\027[201~") -- Send the "stop paste" sequence.
    feed_tui("not pasted")

    -- Paste stopped, so the mapping _should_ apply.
    screen:expect([[
                                                        |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      [No Name]                                         |
      :not paXXXed{1: }                                     |
      -- TERMINAL --                                    |
    ]])

  end)

  -- TODO
  it('sets undo-point after consecutive pastes', function()
  end)

  -- TODO
  it('handles missing "stop paste" sequence', function()
  end)

  -- TODO: error when pasting into 'nomodifiable' buffer:
  --      [error @ do_put:2656] 17043 - Failed to save undo information
  it("handles 'nomodifiable' buffer gracefully", function()
  end)

end)

