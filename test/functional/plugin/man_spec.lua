local helpers = require('test.functional.helpers')(after_each)
local plugin_helpers = require('test.functional.plugin.helpers')

local Screen = require('test.functional.ui.screen')

local buffer, command, eval = helpers.buffer, helpers.command, helpers.eval

before_each(function()
  plugin_helpers.reset()
  helpers.clear()
  command('syntax on')
  command('set filetype=man')
end)

describe('In autoload/man.vim', function()
  describe('function man#highlight_formatted_text', function()
    local screen

    before_each(function()
      command('syntax off') -- Ignore syntax groups
      screen = Screen.new(52, 5)
      screen:attach()
    end)

    after_each(function()
      screen:detach()
    end)

    local function expect(string)
      screen:expect(string,
      {
        b = { bold = true },
        i = { italic = true },
        u = { underline = true },
        bi = { bold = true, italic = true },
        biu = { bold = true, italic = true, underline = true },
      },
      {{ bold = true, foreground = Screen.colors.Blue }})
    end

    local function expect_without_highlights(string)
      screen:expect(string, nil, true)
    end

    local function insert_lines(...)
      buffer('set_lines', 0, 0, 1, false, { ... })
    end

    it('clears backspaces from text', function()
      insert_lines(
        "this i\bis\bs a\ba test",
        "with _\bo_\bv_\be_\br_\bs_\bt_\br_\bu_\bc_\bk text"
      )

      expect_without_highlights([[
      ^this i^His^Hs a^Ha test                             |
      with _^Ho_^Hv_^He_^Hr_^Hs_^Ht_^Hr_^Hu_^Hc_^Hk text  |
      ~                                                   |
      ~                                                   |
                                                          |
      ]])

      eval('man#highlight_formatted_text()')

      expect_without_highlights([[
      ^this is a test                                      |
      with overstruck text                                |
      ~                                                   |
      ~                                                   |
                                                          |
      ]])
    end)

    it('clears escape sequences from text', function()
      insert_lines(
        "this \027[1mis \027[3ma \027[4mtest\027[0m",
        "\027[4mwith\027[24m \027[4mescaped\027[24m \027[4mtext\027[24m"
      )

      expect_without_highlights([[
      ^this ^[[1mis ^[[3ma ^[[4mtest^[[0m                  |
      ^[[4mwith^[[24m ^[[4mescaped^[[24m ^[[4mtext^[[24m  |
      ~                                                   |
      ~                                                   |
                                                          |
      ]])

      eval('man#highlight_formatted_text()')

      expect_without_highlights([[
      ^this is a test                                      |
      with escaped text                                   |
      ~                                                   |
      ~                                                   |
                                                          |
      ]])
    end)

    it('highlights overstruck text', function()
      insert_lines(
        "this i\bis\bs a\ba test",
        "with _\bo_\bv_\be_\br_\bs_\bt_\br_\bu_\bc_\bk text"
      )
      eval('man#highlight_formatted_text()')

      expect([[
      ^this {b:is} {b:a} test                                      |
      with {u:overstruck} text                                |
      ~                                                   |
      ~                                                   |
                                                          |
      ]])
    end)

    it('highlights escape sequences in text', function()
      insert_lines(
        "this \027[1mis \027[3ma \027[4mtest\027[0m",
        "\027[4mwith\027[24m \027[4mescaped\027[24m \027[4mtext\027[24m"
      )
      eval('man#highlight_formatted_text()')

      expect([[
      ^this {b:is }{bi:a }{biu:test}                                      |
      {u:with} {u:escaped} {u:text}                                   |
      ~                                                   |
      ~                                                   |
                                                          |
      ]])
    end)

    it('highlights multibyte text', function()
      insert_lines(
        "this i\bis\bs あ\bあ test",
        "with _\bö_\bv_\be_\br_\bs_\bt_\br_\bu_\bc_\bk te\027[3mxt¶\027[0m"
      )
      eval('man#highlight_formatted_text()')

      expect([[
      ^this {b:is} {b:あ} test                                     |
      with {u:överstruck} te{i:xt¶}                               |
      ~                                                   |
      ~                                                   |
                                                          |
      ]])
    end)

    it('highlights underscores based on context', function()
      insert_lines(
        "_\b_b\bbe\beg\bgi\bin\bns\bs",
        "m\bmi\bid\bd_\b_d\bdl\ble\be",
        "_\bm_\bi_\bd_\b__\bd_\bl_\be"
      )
      eval('man#highlight_formatted_text()')

      expect([[
      {b:^_begins}                                             |
      {b:mid_dle}                                             |
      {u:mid_dle}                                             |
      ~                                                   |
                                                          |
      ]])
    end)

    it('highlights various bullet formats', function()
      insert_lines(
        "· ·\b·",
        "+\bo",
        "+\b+\bo\bo double"
      )
      eval('man#highlight_formatted_text()')

      expect([[
      ^· {b:·}                                                 |
      {b:·}                                                   |
      {b:·} double                                            |
      ~                                                   |
                                                          |
      ]])
    end)
  end)
end)
