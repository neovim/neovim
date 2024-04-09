local t = require('test.functional.testutil')()

local clear = t.clear
local command = t.command
local dedent = t.dedent
local eval = t.eval
local eq = t.eq
local feed = t.feed
local api = t.api
local exec_capture = t.exec_capture

describe('TabNewEntered', function()
  describe('au TabNewEntered', function()
    describe('with * as <afile>', function()
      it('matches when entering any new tab', function()
        clear()
        command('au! TabNewEntered * echom "tabnewentered:".tabpagenr().":".bufnr("")')
        eq('tabnewentered:2:2', api.nvim_exec('tabnew', true))
        eq('tabnewentered:3:3', api.nvim_exec('tabnew test.x2', true))
      end)
    end)
    describe('with FILE as <afile>', function()
      it('matches when opening a new tab for FILE', function()
        clear()
        command('au! TabNewEntered Xtest-tabnewentered echom "tabnewentered:match"')
        eq('tabnewentered:match', api.nvim_exec('tabnew Xtest-tabnewentered', true))
      end)
    end)
    describe('with CTRL-W T', function()
      it('works when opening a new tab with CTRL-W T', function()
        clear()
        command('au! TabNewEntered * echom "entered"')
        command('tabnew test.x2')
        command('split')
        eq('entered', api.nvim_exec('execute "normal \\<C-W>T"', true))
      end)
    end)
    describe('with tab split #4334', function()
      it('works when create a tab by using tab split command', function()
        clear()
        command('au! TabNewEntered * let b:entered = "entered"')
        command('tab split')
        eq('entered', api.nvim_exec('echo b:entered', true))
      end)
    end)
  end)
end)

describe('TabEnter', function()
  before_each(clear)
  it('has correct previous tab when entering any new tab', function()
    command('augroup TEMP')
    command('au! TabEnter * echom "tabenter:".tabpagenr().":".tabpagenr(\'#\')')
    command('augroup END')
    eq('tabenter:2:1', api.nvim_exec('tabnew', true))
    eq('tabenter:3:2', api.nvim_exec('tabnew test.x2', true))
    command('augroup! TEMP')
  end)
  it('has correct previous tab when entering any preexisting tab', function()
    command('tabnew')
    command('tabnew')
    command('augroup TEMP')
    command('au! TabEnter * echom "tabenter:".tabpagenr().":".tabpagenr(\'#\')')
    command('augroup END')
    eq('tabenter:1:3', api.nvim_exec('tabnext', true))
    eq('tabenter:2:1', api.nvim_exec('tabnext', true))
    command('augroup! TEMP')
  end)
end)

describe('tabpage/previous', function()
  before_each(clear)
  local function switches_to_previous_after_new_tab_creation_at_end(characters)
    return function()
      -- Add three tabs for a total of four
      command('tabnew')
      command('tabnew')
      command('tabnew')

      -- The previous tab is now the third.
      eq(3, eval("tabpagenr('#')"))

      -- Switch to the previous (third) tab
      feed(characters)

      eq(
        dedent([=[

          Tab page 1
              [No Name]
          Tab page 2
              [No Name]
          Tab page 3
          >   [No Name]
          Tab page 4
          #   [No Name]]=]),
        exec_capture('tabs')
      )

      -- The previous tab is now the fourth.
      eq(4, eval("tabpagenr('#')"))
    end
  end
  it(
    'switches to previous via g<Tab> after new tab creation at end',
    switches_to_previous_after_new_tab_creation_at_end('g<Tab>')
  )
  it(
    'switches to previous via <C-W>g<Tab>. after new tab creation at end',
    switches_to_previous_after_new_tab_creation_at_end('<C-W>g<Tab>')
  )
  it(
    'switches to previous via <C-Tab>. after new tab creation at end',
    switches_to_previous_after_new_tab_creation_at_end('<C-Tab>')
  )
  it(
    'switches to previous via :tabn #<CR>. after new tab creation at end',
    switches_to_previous_after_new_tab_creation_at_end(':tabn #<CR>')
  )

  local function switches_to_previous_after_new_tab_creation_in_middle(characters)
    return function()
      -- Add three tabs for a total of four
      command('tabnew')
      command('tabnew')
      command('tabnew')
      -- Switch to the second tab
      command('tabnext 2')
      -- Add a new tab after the second tab
      command('tabnew')

      -- The previous tab is now the second.
      eq(2, eval("tabpagenr('#')"))

      -- Switch to the previous (second) tab
      feed(characters)
      eq(
        dedent([=[

         Tab page 1
             [No Name]
         Tab page 2
         >   [No Name]
         Tab page 3
         #   [No Name]
         Tab page 4
             [No Name]
         Tab page 5
             [No Name]]=]),
        exec_capture('tabs')
      )

      -- The previous tab is now the third.
      eq(3, eval("tabpagenr('#')"))
    end
  end
  it(
    'switches to previous via g<Tab> after new tab creation in middle',
    switches_to_previous_after_new_tab_creation_in_middle('g<Tab>')
  )
  it(
    'switches to previous via <C-W>g<Tab> after new tab creation in middle',
    switches_to_previous_after_new_tab_creation_in_middle('<C-W>g<Tab>')
  )
  it(
    'switches to previous via <C-Tab> after new tab creation in middle',
    switches_to_previous_after_new_tab_creation_in_middle('<C-Tab>')
  )
  it(
    'switches to previous via :tabn #<CR> after new tab creation in middle',
    switches_to_previous_after_new_tab_creation_in_middle(':tabn #<CR>')
  )

  local function switches_to_previous_after_switching_to_next_tab(characters)
    return function()
      -- Add three tabs for a total of four
      command('tabnew')
      command('tabnew')
      command('tabnew')
      -- Switch to the next (first) tab
      command('tabnext')

      -- The previous tab is now the fourth.
      eq(4, eval("tabpagenr('#')"))

      -- Switch to the previous (fourth) tab
      feed(characters)

      eq(
        dedent([=[

         Tab page 1
         #   [No Name]
         Tab page 2
             [No Name]
         Tab page 3
             [No Name]
         Tab page 4
         >   [No Name]]=]),
        exec_capture('tabs')
      )

      -- The previous tab is now the first.
      eq(1, eval("tabpagenr('#')"))
    end
  end
  it(
    'switches to previous via g<Tab> after switching to next tab',
    switches_to_previous_after_switching_to_next_tab('g<Tab>')
  )
  it(
    'switches to previous via <C-W>g<Tab> after switching to next tab',
    switches_to_previous_after_switching_to_next_tab('<C-W>g<Tab>')
  )
  it(
    'switches to previous via <C-Tab> after switching to next tab',
    switches_to_previous_after_switching_to_next_tab('<C-Tab>')
  )
  it(
    'switches to previous via :tabn #<CR> after switching to next tab',
    switches_to_previous_after_switching_to_next_tab(':tabn #<CR>')
  )

  local function switches_to_previous_after_switching_to_last_tab(characters)
    return function()
      -- Add three tabs for a total of four
      command('tabnew')
      command('tabnew')
      command('tabnew')
      -- Switch to the next (first) tab
      command('tabnext')
      -- Switch to the last (fourth) tab.
      command('tablast')

      -- The previous tab is now the second.
      eq(1, eval("tabpagenr('#')"))

      -- Switch to the previous (second) tab
      feed(characters)

      eq(
        dedent([=[

         Tab page 1
         >   [No Name]
         Tab page 2
             [No Name]
         Tab page 3
             [No Name]
         Tab page 4
         #   [No Name]]=]),
        exec_capture('tabs')
      )

      -- The previous tab is now the fourth.
      eq(4, eval("tabpagenr('#')"))
    end
  end
  it(
    'switches to previous after switching to last tab',
    switches_to_previous_after_switching_to_last_tab('g<Tab>')
  )
  it(
    'switches to previous after switching to last tab',
    switches_to_previous_after_switching_to_last_tab('<C-W>g<Tab>')
  )
  it(
    'switches to previous after switching to last tab',
    switches_to_previous_after_switching_to_last_tab('<C-Tab>')
  )
  it(
    'switches to previous after switching to last tab',
    switches_to_previous_after_switching_to_last_tab(':tabn #<CR>')
  )

  local function switches_to_previous_after_switching_to_previous_tab(characters)
    return function()
      -- Add three tabs for a total of four
      command('tabnew')
      command('tabnew')
      command('tabnew')
      -- Switch to the previous (third) tab
      command('tabprevious')

      -- The previous tab is now the fourth.
      eq(4, eval("tabpagenr('#')"))

      -- Switch to the previous (fourth) tab
      feed(characters)

      eq(
        dedent([=[

         Tab page 1
             [No Name]
         Tab page 2
             [No Name]
         Tab page 3
         #   [No Name]
         Tab page 4
         >   [No Name]]=]),
        exec_capture('tabs')
      )

      -- The previous tab is now the third.
      eq(3, eval("tabpagenr('#')"))
    end
  end
  it(
    'switches to previous via g<Tab> after switching to previous tab',
    switches_to_previous_after_switching_to_previous_tab('g<Tab>')
  )
  it(
    'switches to previous via <C-W>g<Tab> after switching to previous tab',
    switches_to_previous_after_switching_to_previous_tab('<C-W>g<Tab>')
  )
  it(
    'switches to previous via <C-Tab> after switching to previous tab',
    switches_to_previous_after_switching_to_previous_tab('<C-Tab>')
  )
  it(
    'switches to previous via :tabn #<CR> after switching to previous tab',
    switches_to_previous_after_switching_to_previous_tab(':tabn #<CR>')
  )

  local function switches_to_previous_after_switching_to_first_tab(characters)
    return function()
      -- Add three tabs for a total of four
      command('tabnew')
      command('tabnew')
      command('tabnew')
      -- Switch to the previous (third) tab
      command('tabprevious')
      -- Switch to the first tab
      command('tabfirst')

      -- The previous tab is now the third.
      eq(3, eval("tabpagenr('#')"))

      -- Switch to the previous (third) tab
      feed(characters)

      eq(
        dedent([=[

         Tab page 1
         #   [No Name]
         Tab page 2
             [No Name]
         Tab page 3
         >   [No Name]
         Tab page 4
             [No Name]]=]),
        exec_capture('tabs')
      )

      -- The previous tab is now the first.
      eq(1, eval("tabpagenr('#')"))
    end
  end
  it(
    'switches to previous via g<Tab> after switching to first tab',
    switches_to_previous_after_switching_to_first_tab('g<Tab>')
  )
  it(
    'switches to previous via <C-W>g<Tab> after switching to first tab',
    switches_to_previous_after_switching_to_first_tab('<C-W>g<Tab>')
  )
  it(
    'switches to previous via <C-Tab> after switching to first tab',
    switches_to_previous_after_switching_to_first_tab('<C-Tab>')
  )
  it(
    'switches to previous via :tabn #<CR> after switching to first tab',
    switches_to_previous_after_switching_to_first_tab(':tabn #<CR>')
  )

  local function switches_to_previous_after_numbered_tab_switch(characters)
    return function()
      -- Add three tabs for a total of four
      command('tabnew')
      command('tabnew')
      command('tabnew')
      -- Switch to the second tab
      command('tabnext 2')

      -- The previous tab is now the fourth.
      eq(4, eval("tabpagenr('#')"))

      -- Switch to the previous (fourth) tab
      feed(characters)

      eq(
        dedent([=[

         Tab page 1
             [No Name]
         Tab page 2
         #   [No Name]
         Tab page 3
             [No Name]
         Tab page 4
         >   [No Name]]=]),
        exec_capture('tabs')
      )

      -- The previous tab is now the second.
      eq(2, eval("tabpagenr('#')"))
    end
  end
  it(
    'switches to previous via g<Tab> after numbered tab switch',
    switches_to_previous_after_numbered_tab_switch('g<Tab>')
  )
  it(
    'switches to previous via <C-W>g<Tab> after numbered tab switch',
    switches_to_previous_after_numbered_tab_switch('<C-W>g<Tab>')
  )
  it(
    'switches to previous via <C-Tab> after numbered tab switch',
    switches_to_previous_after_numbered_tab_switch('<C-Tab>')
  )
  it(
    'switches to previous via :tabn #<CR> after numbered tab switch',
    switches_to_previous_after_numbered_tab_switch(':tabn #<CR>')
  )

  local function switches_to_previous_after_switching_to_previous(characters1, characters2)
    return function()
      -- Add three tabs for a total of four
      command('tabnew')
      command('tabnew')
      command('tabnew')
      -- Switch to the second tab
      command('tabnext 2')
      -- Switch to the previous (fourth) tab
      feed(characters1)

      -- The previous tab is now the second.
      eq(2, eval("tabpagenr('#')"))

      -- Switch to the previous (second) tab
      feed(characters2)

      eq(
        dedent([=[

         Tab page 1
             [No Name]
         Tab page 2
         >   [No Name]
         Tab page 3
             [No Name]
         Tab page 4
         #   [No Name]]=]),
        exec_capture('tabs')
      )

      -- The previous tab is now the fourth.
      eq(4, eval("tabpagenr('#')"))
    end
  end
  it(
    'switches to previous via g<Tab> after switching to previous via g<Tab>',
    switches_to_previous_after_switching_to_previous('g<Tab>', 'g<Tab>')
  )
  it(
    'switches to previous via <C-W>g<Tab> after switching to previous via g<Tab>',
    switches_to_previous_after_switching_to_previous('g<Tab>', '<C-W>g<Tab>')
  )
  it(
    'switches to previous via <C-Tab> after switching to previous via g<Tab>',
    switches_to_previous_after_switching_to_previous('g<Tab>', '<C-Tab>')
  )
  it(
    'switches to previous via :tabn #<CR> after switching to previous via g<Tab>',
    switches_to_previous_after_switching_to_previous('g<Tab>', ':tabn #<CR>')
  )
  it(
    'switches to previous via g<Tab> after switching to previous via <C-W>g<Tab>',
    switches_to_previous_after_switching_to_previous('<C-W>g<Tab>', 'g<Tab>')
  )
  it(
    'switches to previous via <C-W>g<Tab> after switching to previous via <C-W>g<Tab>',
    switches_to_previous_after_switching_to_previous('<C-W>g<Tab>', '<C-W>g<Tab>')
  )
  it(
    'switches to previous via <C-Tab> after switching to previous via <C-W>g<Tab>',
    switches_to_previous_after_switching_to_previous('<C-W>g<Tab>', '<C-Tab>')
  )
  it(
    'switches to previous via :tabn #<CR> after switching to previous via <C-W>g<Tab>',
    switches_to_previous_after_switching_to_previous('<C-W>g<Tab>', ':tabn #<CR>')
  )
  it(
    'switches to previous via g<Tab> after switching to previous via <C-Tab>',
    switches_to_previous_after_switching_to_previous('<C-Tab>', 'g<Tab>')
  )
  it(
    'switches to previous via <C-W>g<Tab> after switching to previous via <C-Tab>',
    switches_to_previous_after_switching_to_previous('<C-Tab>', '<C-W>g<Tab>')
  )
  it(
    'switches to previous via <C-Tab> after switching to previous via <C-Tab>',
    switches_to_previous_after_switching_to_previous('<C-Tab>', '<C-Tab>')
  )
  it(
    'switches to previous via :tabn #<CR> after switching to previous via <C-Tab>',
    switches_to_previous_after_switching_to_previous('<C-Tab>', ':tabn #<CR>')
  )
  it(
    'switches to previous via g<Tab> after switching to previous via :tabn #<CR>',
    switches_to_previous_after_switching_to_previous(':tabn #<CR>', 'g<Tab>')
  )
  it(
    'switches to previous via <C-W>g<Tab> after switching to previous via :tabn #<CR>',
    switches_to_previous_after_switching_to_previous(':tabn #<CR>', '<C-W>g<Tab>')
  )
  it(
    'switches to previous via <C-Tab> after switching to previous via <C-Tab>',
    switches_to_previous_after_switching_to_previous(':tabn #<CR>', '<C-Tab>')
  )
  it(
    'switches to previous via :tabn #<CR> after switching to previous via :tabn #<CR>',
    switches_to_previous_after_switching_to_previous(':tabn #<CR>', ':tabn #<CR>')
  )

  local function does_not_switch_to_previous_after_closing_current_tab(characters)
    return function()
      -- Add three tabs for a total of four
      command('tabnew')
      command('tabnew')
      command('tabnew')
      -- Close the current (fourth tab)
      command('wincmd c')

      -- The previous tab is now the "zeroth" -- there isn't one.
      eq(0, eval("tabpagenr('#')"))

      -- At this point, switching to the "previous" (i.e. fourth) tab would mean
      -- switching to either a dangling or a null pointer.
      feed(characters)

      eq(
        dedent([=[

         Tab page 1
             [No Name]
         Tab page 2
             [No Name]
         Tab page 3
         >   [No Name]]=]),
        exec_capture('tabs')
      )

      -- The previous tab is now the "zero".
      eq(0, eval("tabpagenr('#')"))
    end
  end
  it(
    'does not switch to previous via g<Tab> after closing current tab',
    does_not_switch_to_previous_after_closing_current_tab('g<Tab>')
  )
  it(
    'does not switch to previous via <C-W>g<Tab> after closing current tab',
    does_not_switch_to_previous_after_closing_current_tab('<C-W>g<Tab>')
  )
  it(
    'does not switch to previous via <C-Tab> after closing current tab',
    does_not_switch_to_previous_after_closing_current_tab('<C-Tab>')
  )
  it(
    'does not switch to previous via :tabn #<CR> after closing current tab',
    does_not_switch_to_previous_after_closing_current_tab(':tabn #<CR>')
  )

  local function does_not_switch_to_previous_after_entering_operator_pending(characters)
    return function()
      -- Add three tabs for a total of four
      command('tabnew')
      command('tabnew')
      command('tabnew')

      -- The previous tab is now the third.
      eq(3, eval("tabpagenr('#')"))

      -- Enter operator pending mode.
      feed('d')
      eq('no', eval('mode(1)'))

      -- At this point switching to the previous tab should have no effect
      -- other than leaving operator pending mode.
      feed(characters)

      -- Attempting to switch tabs returns us to normal mode.
      eq('n', eval('mode()'))

      -- The current tab is still the fourth.
      eq(4, eval('tabpagenr()'))

      -- The previous tab is still the third.
      eq(3, eval("tabpagenr('#')"))
    end
  end
  it(
    'does not switch to previous via g<Tab> after entering operator pending',
    does_not_switch_to_previous_after_entering_operator_pending('g<Tab>')
  )
  -- NOTE: When in operator pending mode, attempting to switch to previous has
  --       the following effect:
  --       - Ctrl-W exits operator pending mode
  --       - g<Tab> switches to the previous tab
  --       In other words, the effect of "<C-W>g<Tab>" is to switch to the
  --       previous tab even from operator pending mode, but only thanks to the
  --       fact that the suffix after "<C-W>" in "<C-W>g<Tab>" just happens to
  --       be the same as the normal mode command to switch to the previous tab.
  -- it('does not switch to previous via <C-W>g<Tab> after entering operator pending',
  --   does_not_switch_to_previous_after_entering_operator_pending('<C-W>g<Tab>'))
  it(
    'does not switch to previous via <C-Tab> after entering operator pending',
    does_not_switch_to_previous_after_entering_operator_pending('<C-Tab>')
  )
  -- NOTE: When in operator pending mode, pressing : leaves operator pending
  --       mode and enters command mode, so :tabn #<CR> does in fact switch
  --       tabs.
  -- it('does not switch to previous via :tabn #<CR> after entering operator pending',
  --   does_not_switch_to_previous_after_entering_operator_pending(':tabn #<CR>'))

  local function cmdline_win_prevents_tab_switch(characters, completion_visible)
    return function()
      -- Add three tabs for a total of four
      command('tabnew')
      command('tabnew')
      command('tabnew')

      -- The previous tab is now the third.
      eq(3, eval("tabpagenr('#')"))

      -- Edit : command line in command-line window
      feed('q:')

      local cmdline_win_id = eval('win_getid()')

      -- At this point switching to the previous tab should have no effect.
      feed(characters)

      -- Attempting to switch tabs maintains the current window.
      eq(cmdline_win_id, eval('win_getid()'))
      eq(completion_visible, eval('complete_info().pum_visible'))

      -- The current tab is still the fourth.
      eq(4, eval('tabpagenr()'))

      -- The previous tab is still the third.
      eq(3, eval("tabpagenr('#')"))
    end
  end
  it('cmdline-win prevents tab switch via g<Tab>', cmdline_win_prevents_tab_switch('g<Tab>', 0))
  it(
    'cmdline-win prevents tab switch via <C-W>g<Tab>',
    cmdline_win_prevents_tab_switch('<C-W>g<Tab>', 1)
  )
  it('cmdline-win prevents tab switch via <C-Tab>', cmdline_win_prevents_tab_switch('<C-Tab>', 0))
  it(
    'cmdline-win prevents tab switch via :tabn #<CR>',
    cmdline_win_prevents_tab_switch(':tabn #<CR>', 0)
  )

  it(':tabs indicates correct prevtab curwin', function()
    -- Add three tabs for a total of four
    command('tabnew')
    command('tabnew')
    command('split')
    command('vsplit')
    feed('<C-w>p')
    command('tabnew')

    -- The previous tab is now the three.
    eq(3, eval("tabpagenr('#')"))

    eq(
      dedent([=[

         Tab page 1
             [No Name]
         Tab page 2
             [No Name]
         Tab page 3
             [No Name]
         #   [No Name]
             [No Name]
         Tab page 4
         >   [No Name]]=]),
      exec_capture('tabs')
    )
  end)
end)
