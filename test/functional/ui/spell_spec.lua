-- Test for scenarios involving 'spell'

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local exec = n.exec
local feed = n.feed
local insert = n.insert
local api = n.api
local is_os = t.is_os

describe("'spell'", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(80, 8)
    screen:add_extra_attr_ids {
      [100] = { special = Screen.colors.Red, undercurl = true },
      [101] = { special = Screen.colors.Blue, undercurl = true },
      [102] = { foreground = Screen.colors.Blue, special = Screen.colors.Red, undercurl = true },
      [103] = { foreground = tonumber('0x6a0dad') },
      [104] = { foreground = Screen.colors.Red, underline = true },
      [105] = { foreground = Screen.colors.Blue, underline = true },
    }
  end)

  it('joins long lines #7937', function()
    if is_os('openbsd') then
      pending('FIXME #12104', function() end)
      return
    end
    exec('set spell')
    insert([[
    Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod
    tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
    quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo
    consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse
    cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat
    non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
    ]])
    feed('ggJJJJJJ0')
    screen:expect([[
    {100:^Lorem} {100:ipsum} dolor sit {100:amet}, {100:consectetur} {100:adipiscing} {100:elit}, {100:sed} do {100:eiusmod} {100:tempor} {100:i}|
    {100:ncididunt} {100:ut} {100:labore} et {100:dolore} {100:magna} {100:aliqua}. {100:Ut} {100:enim} ad minim {100:veniam}, {100:quis} {100:nostru}|
    {100:d} {100:exercitation} {100:ullamco} {100:laboris} {100:nisi} {100:ut} {100:aliquip} ex ea {100:commodo} {100:consequat}. {100:Duis} {100:aut}|
    {100:e} {100:irure} dolor in {100:reprehenderit} in {100:voluptate} {100:velit} {100:esse} {100:cillum} {100:dolore} {100:eu} {100:fugiat} {100:n}|
    {100:ulla} {100:pariatur}. {100:Excepteur} {100:sint} {100:occaecat} {100:cupidatat} non {100:proident}, {100:sunt} in culpa {100:qui}|
     {100:officia} {100:deserunt} {100:mollit} {100:anim} id est {100:laborum}.                                   |
    {1:~                                                                               }|
                                                                                    |
    ]])
  end)

  -- oldtest: Test_spell_screendump()
  it('has correct highlight at start of line', function()
    exec([=[
      call setline(1, [
        \"This is some text without any spell errors.  Everything",
        \"should just be black, nothing wrong here.",
        \"",
        \"This line has a sepll error. and missing caps.",
        \"And and this is the the duplication.",
        \"with missing caps here.",
      \])
      set spell spelllang=en_nz
    ]=])
    screen:expect([[
      ^This is some text without any spell errors.  Everything                         |
      should just be black, nothing wrong here.                                       |
                                                                                      |
      This line has a {100:sepll} error. {101:and} missing caps.                                  |
      {100:And and} this is {100:the the} duplication.                                            |
      {101:with} missing caps here.                                                         |
      {1:~                                                                               }|
                                                                                      |
    ]])
  end)

  -- oldtest: Test_spell_screendump_spellcap()
  it('SpellCap highlight at start of line', function()
    exec([=[
      call setline(1, [
        \"   This line has a sepll error. and missing caps and trailing spaces.   ",
        \"another missing cap here.",
        \"",
        \"and here.",
        \"    ",
        \"and here."
      \])
      set spell spelllang=en
    ]=])
    screen:expect([[
      ^   This line has a {100:sepll} error. {101:and} missing caps and trailing spaces.           |
      {101:another} missing cap here.                                                       |
                                                                                      |
      {101:and} here.                                                                       |
                                                                                      |
      {101:and} here.                                                                       |
      {1:~                                                                               }|
                                                                                      |
    ]])
    -- After adding word missing Cap in next line is updated
    feed('3GANot<Esc>')
    screen:expect([[
         This line has a {100:sepll} error. {101:and} missing caps and trailing spaces.           |
      {101:another} missing cap here.                                                       |
      No^t                                                                             |
      and here.                                                                       |
                                                                                      |
      {101:and} here.                                                                       |
      {1:~                                                                               }|
                                                                                      |
    ]])
    -- Deleting a full stop removes missing Cap in next line
    feed('5Gdd<C-L>k$x')
    screen:expect([[
         This line has a {100:sepll} error. {101:and} missing caps and trailing spaces.           |
      {101:another} missing cap here.                                                       |
      Not                                                                             |
      and her^e                                                                        |
      and here.                                                                       |
      {1:~                                                                               }|*2
                                                                                      |
    ]])
    -- Undo also updates the next line (go to command line to remove message)
    feed('u:<Esc>')
    screen:expect([[
         This line has a {100:sepll} error. {101:and} missing caps and trailing spaces.           |
      {101:another} missing cap here.                                                       |
      Not                                                                             |
      and here^.                                                                       |
      {101:and} here.                                                                       |
      {1:~                                                                               }|*2
                                                                                      |
    ]])
    -- Folding an empty line does not remove Cap in next line
    feed('uzfk:<Esc>')
    screen:expect([[
         This line has a {100:sepll} error. {101:and} missing caps and trailing spaces.           |
      {101:another} missing cap here.                                                       |
      Not                                                                             |
      {13:^+--  2 lines: and here.·························································}|
      {101:and} here.                                                                       |
      {1:~                                                                               }|*2
                                                                                      |
    ]])
    -- Folding the end of a sentence does not remove Cap in next line
    -- and editing a line does not remove Cap in current line
    feed('Jzfkk$x')
    screen:expect([[
         This line has a {100:sepll} error. {101:and} missing caps and trailing spaces.           |
      {101:another} missing cap her^e                                                        |
      {13:+--  2 lines: Not·······························································}|
      {101:and} here.                                                                       |
      {1:~                                                                               }|*3
                                                                                      |
    ]])
    -- Cap is correctly applied in the first row of a window
    feed('<C-E><C-L>')
    screen:expect([[
      {101:another} missing cap her^e                                                        |
      {13:+--  2 lines: Not·······························································}|
      {101:and} here.                                                                       |
      {1:~                                                                               }|*4
                                                                                      |
    ]])
    -- Adding an empty line does not remove Cap in "mod_bot" area
    feed('zbO<Esc>')
    screen:expect([[
         This line has a {100:sepll} error. {101:and} missing caps and trailing spaces.           |
      ^                                                                                |
      {101:another} missing cap here                                                        |
      {13:+--  2 lines: Not·······························································}|
      {101:and} here.                                                                       |
      {1:~                                                                               }|*2
                                                                                      |
    ]])
    -- Multiple empty lines does not remove Cap in the line after
    feed('O<Esc><C-L>')
    screen:expect([[
         This line has a {100:sepll} error. {101:and} missing caps and trailing spaces.           |
      ^                                                                                |
                                                                                      |
      {101:another} missing cap here                                                        |
      {13:+--  2 lines: Not·······························································}|
      {101:and} here.                                                                       |
      {1:~                                                                               }|
                                                                                      |
    ]])
  end)

  -- oldtest: Test_spell_compatible()
  it([[redraws properly when using "C" and "$" is in 'cpo']], function()
    exec([=[
      call setline(1, [
        \ "test "->repeat(20),
        \ "",
        \ "end",
      \ ])
      set spell cpo+=$
    ]=])
    feed('51|C')
    screen:expect([[
      {101:test} test test test test test test test test test ^test test test test test test |
      test test test test$                                                            |
                                                                                      |
      {101:end}                                                                             |
      {1:~                                                                               }|*3
      {5:-- INSERT --}                                                                    |
    ]])
    feed('x')
    screen:expect([[
      {101:test} test test test test test test test test test x^est test test test test test |
      test test test test$                                                            |
                                                                                      |
      {101:end}                                                                             |
      {1:~                                                                               }|*3
      {5:-- INSERT --}                                                                    |
    ]])
  end)

  it('extmarks, "noplainbuffer" and syntax #20385 #23398', function()
    exec('set filetype=c')
    exec('syntax on')
    exec('set spell')
    insert([[
      #include <stdbool.h>
      bool func(void);
      // I am a speling mistakke]])
    feed('ge')
    screen:expect([[
      {103:#include }{26:<stdbool.h>}                                                            |
      {6:bool} func({6:void});                                                                |
      {18:// I am a }{102:spelin^g}{18: }{102:mistakke}                                                      |
      {1:~                                                                               }|*4
                                                                                      |
    ]])
    feed(']s')
    screen:expect([[
      {103:#include }{26:<stdbool.h>}                                                            |
      {6:bool} func({6:void});                                                                |
      {18:// I am a }{102:speling}{18: }{102:^mistakke}                                                      |
      {1:~                                                                               }|*4
                                                                                      |
    ]])
    feed(']s')
    screen:expect([[
      {103:#include }{26:<stdbool.h>}                                                            |
      {6:bool} func({6:void});                                                                |
      {18:// I am a }{102:^speling}{18: }{102:mistakke}                                                      |
      {1:~                                                                               }|*4
      {19:search hit BOTTOM, continuing at TOP}                                            |
    ]])
    exec('echo ""')
    local ns = api.nvim_create_namespace('spell')
    -- extmark with spell=true enables spell
    local id = api.nvim_buf_set_extmark(0, ns, 1, 4, { end_row = 1, end_col = 10, spell = true })
    screen:expect([[
      {103:#include }{26:<stdbool.h>}                                                            |
      {6:bool} {100:func}({6:void});                                                                |
      {18:// I am a }{102:^speling}{18: }{102:mistakke}                                                      |
      {1:~                                                                               }|*4
                                                                                      |
    ]])
    feed('[s')
    screen:expect([[
      {103:#include }{26:<stdbool.h>}                                                            |
      {6:bool} {100:^func}({6:void});                                                                |
      {18:// I am a }{102:speling}{18: }{102:mistakke}                                                      |
      {1:~                                                                               }|*4
                                                                                      |
    ]])
    api.nvim_buf_del_extmark(0, ns, id)
    -- extmark with spell=false disables spell
    id = api.nvim_buf_set_extmark(0, ns, 2, 18, { end_row = 2, end_col = 26, spell = false })
    screen:expect([[
      {103:#include }{26:<stdbool.h>}                                                            |
      {6:bool} ^func({6:void});                                                                |
      {18:// I am a }{102:speling}{18: mistakke}                                                      |
      {1:~                                                                               }|*4
                                                                                      |
    ]])
    feed('[s')
    screen:expect([[
      {103:#include }{26:<stdbool.h>}                                                            |
      {6:bool} func({6:void});                                                                |
      {18:// I am a }{102:^speling}{18: mistakke}                                                      |
      {1:~                                                                               }|*4
      {19:search hit TOP, continuing at BOTTOM}                                            |
    ]])
    exec('echo ""')
    api.nvim_buf_del_extmark(0, ns, id)
    screen:expect([[
      {103:#include }{26:<stdbool.h>}                                                            |
      {6:bool} func({6:void});                                                                |
      {18:// I am a }{102:^speling}{18: }{102:mistakke}                                                      |
      {1:~                                                                               }|*4
                                                                                      |
    ]])
    feed(']s')
    screen:expect([[
      {103:#include }{26:<stdbool.h>}                                                            |
      {6:bool} func({6:void});                                                                |
      {18:// I am a }{102:speling}{18: }{102:^mistakke}                                                      |
      {1:~                                                                               }|*4
                                                                                      |
    ]])
    -- "noplainbuffer" shouldn't change spellchecking behavior with syntax enabled
    exec('set spelloptions+=noplainbuffer')
    screen:expect_unchanged()
    feed('[s')
    screen:expect([[
      {103:#include }{26:<stdbool.h>}                                                            |
      {6:bool} func({6:void});                                                                |
      {18:// I am a }{102:^speling}{18: }{102:mistakke}                                                      |
      {1:~                                                                               }|*4
                                                                                      |
    ]])
    -- no spellchecking with "noplainbuffer" and syntax disabled
    exec('syntax off')
    screen:expect([[
      #include <stdbool.h>                                                            |
      bool func(void);                                                                |
      // I am a ^speling mistakke                                                      |
      {1:~                                                                               }|*4
                                                                                      |
    ]])
    feed(']s')
    screen:expect([[
      #include <stdbool.h>                                                            |
      bool func(void);                                                                |
      // I am a ^speling mistakke                                                      |
      {1:~                                                                               }|*4
      {19:search hit BOTTOM, continuing at TOP}                                            |
    ]])
    exec('echo ""')
    -- everything is spellchecked without "noplainbuffer" with syntax disabled
    exec('set spelloptions&')
    screen:expect([[
      #include <{100:stdbool}.h>                                                            |
      {100:bool} {100:func}(void);                                                                |
      // I am a {100:^speling} {100:mistakke}                                                      |
      {1:~                                                                               }|*4
                                                                                      |
    ]])
    feed('[s')
    screen:expect([[
      #include <{100:stdbool}.h>                                                            |
      {100:bool} {100:^func}(void);                                                                |
      // I am a {100:speling} {100:mistakke}                                                      |
      {1:~                                                                               }|*4
                                                                                      |
    ]])
  end)

  it('and syntax does not clear extmark highlighting at the start of a word', function()
    screen:try_resize(43, 3)
    exec([[
      set spell
      syntax match Constant "^.*$"
      call setline(1, "This is some text without any spell errors.")
    ]])
    local ns = api.nvim_create_namespace('spell')
    api.nvim_buf_set_extmark(0, ns, 0, 0, { hl_group = 'WarningMsg', end_col = 43 })
    screen:expect([[
      {19:^This is some text without any spell errors.}|
      {1:~                                          }|
                                                 |
    ]])
  end)

  it('overrides syntax when Visual selection is active', function()
    screen:try_resize(43, 3)
    exec([[
      hi! Comment guibg=NONE guifg=Blue gui=NONE guisp=NONE
      hi! SpellBad guibg=NONE guifg=Red gui=NONE guisp=NONE
      hi! Visual guibg=NONE guifg=NONE gui=underline guisp=NONE
      syn match Comment "//.*"
      call setline(1, '// Here is a misspeld word.')
      set spell
    ]])
    screen:expect([[
      {18:^// Here is a }{19:misspeld}{18: word.}                |
      {1:~                                          }|
                                                 |
    ]])
    feed('V')
    screen:expect([[
      {18:^/}{105:/ Here is a }{104:misspeld}{105: word.}                |
      {1:~                                          }|
      {5:-- VISUAL LINE --}                          |
    ]])
  end)

  it("global value works properly for 'spelloptions'", function()
    screen:try_resize(43, 3)
    exec('set spell')
    -- :setglobal applies to future buffers but not current buffer
    exec('setglobal spelloptions=camel')
    insert('Here is TheCamelWord being spellchecked')
    screen:expect([[
      Here is {100:TheCamelWord} being spellchecke^d    |
      {1:~                                          }|
                                                 |
    ]])
    exec('enew')
    insert('There is TheCamelWord being spellchecked')
    screen:expect([[
      There is TheCamelWord being spellchecke^d   |
      {1:~                                          }|
                                                 |
    ]])
    -- :setlocal applies to current buffer but not future buffers
    exec('setlocal spelloptions=')
    screen:expect([[
      There is {100:TheCamelWord} being spellchecke^d   |
      {1:~                                          }|
                                                 |
    ]])
    exec('enew')
    insert('What is TheCamelWord being spellchecked')
    screen:expect([[
      What is TheCamelWord being spellchecke^d    |
      {1:~                                          }|
                                                 |
    ]])
    -- :set applies to both current buffer and future buffers
    exec('set spelloptions=')
    screen:expect([[
      What is {100:TheCamelWord} being spellchecke^d    |
      {1:~                                          }|
                                                 |
    ]])
    exec('enew')
    insert('Where is TheCamelWord being spellchecked')
    screen:expect([[
      Where is {100:TheCamelWord} being spellchecke^d   |
      {1:~                                          }|
                                                 |
    ]])
  end)

  local function test_spell_false_nav(ephemeral)
    screen:try_resize(50, 8)
    insert('Splel\nSplle\nSepll\nSpele\nSpeel')
    feed('gg0')
    exec('set shortmess+=s spell spelloptions=noplainbuffer')

    n.exec_lua(function()
      local ns = vim.api.nvim_create_namespace('spell')
      if ephemeral then
        local decors = {} --- @type [integer,integer,vim.api.keyset.set_extmark][]
        local function on_do()
          for _, decor in ipairs(decors) do
            vim.api.nvim_buf_set_extmark(
              0,
              ns,
              decor[1],
              decor[2],
              vim.tbl_deep_extend('error', decor[3], { ephemeral = true })
            )
          end
        end
        vim.api.nvim_set_decoration_provider(ns, {
          on_win = on_do,
          _on_spell_nav = on_do,
        })
        function _G.Update(new_decors)
          decors = new_decors
          vim.cmd('redraw!')
        end
      else
        --- @param decors [integer,integer,vim.api.keyset.set_extmark][]
        function _G.Update(decors)
          vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
          for _, decor in ipairs(decors) do
            vim.api.nvim_buf_set_extmark(0, ns, decor[1], decor[2], decor[3])
          end
          vim.cmd('redraw!')
        end
      end
    end)

    n.exec_lua(function()
      _G.Update({
        { 0, 0, { end_row = 5, spell = true, priority = 0 } },
        { 2, 0, { end_row = 3, spell = false, priority = 1 } },
      })
    end)
    screen:expect([[
      {100:^Splel}                                             |
      {100:Splle}                                             |
      Sepll                                             |
      {100:Spele}                                             |
      {100:Speel}                                             |
      {1:~                                                 }|*2
                                                        |
    ]])

    t.eq({ 1, 0 }, api.nvim_win_get_cursor(0))
    feed(']s')
    t.eq({ 2, 0 }, api.nvim_win_get_cursor(0))
    feed(']s')
    t.eq({ 4, 0 }, api.nvim_win_get_cursor(0))
    feed(']s')
    t.eq({ 5, 0 }, api.nvim_win_get_cursor(0))
    feed(']s')
    t.eq({ 1, 0 }, api.nvim_win_get_cursor(0))
    feed('[s')
    t.eq({ 5, 0 }, api.nvim_win_get_cursor(0))
    feed('[s')
    t.eq({ 4, 0 }, api.nvim_win_get_cursor(0))
    feed('[s')
    t.eq({ 2, 0 }, api.nvim_win_get_cursor(0))
    feed('[s')
    t.eq({ 1, 0 }, api.nvim_win_get_cursor(0))

    n.exec_lua(function()
      _G.Update({
        { 0, 0, { end_row = 5, spell = true, priority = 0 } },
        { 3, 0, { end_row = 5, spell = false, priority = 1 } },
        { 3, 0, { end_row = 4, spell = true, priority = 2 } },
      })
    end)
    screen:expect([[
      {100:^Splel}                                             |
      {100:Splle}                                             |
      {100:Sepll}                                             |
      {100:Spele}                                             |
      Speel                                             |
      {1:~                                                 }|*2
                                                        |
    ]])

    t.eq({ 1, 0 }, api.nvim_win_get_cursor(0))
    feed(']s')
    t.eq({ 2, 0 }, api.nvim_win_get_cursor(0))
    feed(']s')
    t.eq({ 3, 0 }, api.nvim_win_get_cursor(0))
    feed(']s')
    t.eq({ 4, 0 }, api.nvim_win_get_cursor(0))
    feed(']s')
    t.eq({ 1, 0 }, api.nvim_win_get_cursor(0))
    feed('[s')
    t.eq({ 4, 0 }, api.nvim_win_get_cursor(0))
    feed('[s')
    t.eq({ 3, 0 }, api.nvim_win_get_cursor(0))
    feed('[s')
    t.eq({ 2, 0 }, api.nvim_win_get_cursor(0))
    feed('[s')
    t.eq({ 1, 0 }, api.nvim_win_get_cursor(0))
  end

  describe('spell=false decoration on line with spelling mistake #39441', function()
    it('using ephemeral decorations', function()
      test_spell_false_nav(true)
    end)

    it('using non-ephemeral extmarks', function()
      test_spell_false_nav(false)
    end)
  end)
end)
