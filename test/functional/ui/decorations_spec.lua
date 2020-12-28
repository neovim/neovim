local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local feed = helpers.feed
local insert = helpers.insert
local exec_lua = helpers.exec_lua
local exec = helpers.exec
local expect_events = helpers.expect_events
local meths = helpers.meths

describe('decorations providers', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(40, 8)
    screen:attach()
    screen:set_default_attr_ids {
      [1] = {bold=true, foreground=Screen.colors.Blue};
      [2] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red};
      [3] = {foreground = Screen.colors.Brown};
      [4] = {foreground = Screen.colors.Blue1};
      [5] = {foreground = Screen.colors.Magenta};
      [6] = {bold = true, foreground = Screen.colors.Brown};
      [7] = {background = Screen.colors.Gray90};
      [8] = {bold = true, reverse = true};
      [9] = {reverse = true};
      [10] = {italic = true, background = Screen.colors.Magenta};
      [11] = {foreground = Screen.colors.Red, background = tonumber('0x005028')};
      [12] = {foreground = tonumber('0x990000')};
    }
  end)

  local mulholland = [[
    // just to see if there was an accident
    // on Mulholland Drive
    try_start();
    bufref_T save_buf;
    switch_buffer(&save_buf, buf);
    posp = getmark(mark, false);
    restore_buffer(&save_buf); ]]

  local function setup_provider(code)
    return exec_lua ([[
      local a = vim.api
      _G.ns1 = a.nvim_create_namespace "ns1"
    ]] .. (code or [[
      beamtrace = {}
      local function on_do(kind, ...)
        table.insert(beamtrace, {kind, ...})
      end
    ]]) .. [[
      a.nvim_set_decoration_provider(_G.ns1, {
        on_start = on_do; on_buf = on_do;
        on_win = on_do; on_line = on_do;
        on_end = on_do;
      })
      return _G.ns1
    ]])
  end

  local function check_trace(expected)
    local actual = exec_lua [[ local b = beamtrace beamtrace = {} return b ]]
    expect_events(expected, actual, "beam trace")
  end

  it('leave a trace', function()
    insert(mulholland)

    setup_provider()

    screen:expect{grid=[[
      // just to see if there was an accident |
      // on Mulholland Drive                  |
      try_start();                            |
      bufref_T save_buf;                      |
      switch_buffer(&save_buf, buf);          |
      posp = getmark(mark, false);            |
      restore_buffer(&save_buf);^              |
                                              |
    ]]}
    check_trace {
      { "start", 4, 40 };
      { "win", 1000, 1, 0, 8 };
      { "line", 1000, 1, 0 };
      { "line", 1000, 1, 1 };
      { "line", 1000, 1, 2 };
      { "line", 1000, 1, 3 };
      { "line", 1000, 1, 4 };
      { "line", 1000, 1, 5 };
      { "line", 1000, 1, 6 };
      { "end", 4 };
    }

    feed "iü<esc>"
    screen:expect{grid=[[
      // just to see if there was an accident |
      // on Mulholland Drive                  |
      try_start();                            |
      bufref_T save_buf;                      |
      switch_buffer(&save_buf, buf);          |
      posp = getmark(mark, false);            |
      restore_buffer(&save_buf);^ü             |
                                              |
    ]]}
    check_trace {
      { "start", 5, 10 };
      { "buf", 1 };
      { "win", 1000, 1, 0, 8 };
      { "line", 1000, 1, 6 };
      { "end", 5 };
    }
  end)

  it('can have single provider', function()
    insert(mulholland)
    setup_provider [[
      local hl = a.nvim_get_hl_id_by_name "ErrorMsg"
      local test_ns = a.nvim_create_namespace "mulholland"
      function on_do(event, ...)
        if event == "line" then
          local win, buf, line = ...
          a.nvim_buf_set_extmark(buf, test_ns, line, line,
                             { end_line = line, end_col = line+1,
                               hl_group = hl,
                               ephemeral = true
                              })
        end
      end
    ]]

    screen:expect{grid=[[
      {2:/}/ just to see if there was an accident |
      /{2:/} on Mulholland Drive                  |
      tr{2:y}_start();                            |
      buf{2:r}ef_T save_buf;                      |
      swit{2:c}h_buffer(&save_buf, buf);          |
      posp {2:=} getmark(mark, false);            |
      restor{2:e}_buffer(&save_buf);^              |
                                              |
    ]]}
  end)

  it('can predefine highlights', function()
    screen:try_resize(40, 16)
    insert(mulholland)
    exec [[
      3
      set ft=c
      syntax on
      set number cursorline
      split
    ]]
    local ns1 = setup_provider()

    for k,v in pairs {
      LineNr = {italic=true, bg="Magenta"};
      Comment = {fg="#FF0000", bg = 80*256+40};
      CursorLine = {link="ErrorMsg"};
    } do meths.set_hl(ns1, k, v) end

    screen:expect{grid=[[
      {3:  1 }{4:// just to see if there was an accid}|
      {3:    }{4:ent}                                 |
      {3:  2 }{4:// on Mulholland Drive}              |
      {6:  3 }{7:^try_start();                        }|
      {3:  4 }bufref_T save_buf;                  |
      {3:  5 }switch_buffer(&save_buf, buf);      |
      {3:  6 }posp = getmark(mark, {5:false});        |
      {8:[No Name] [+]                           }|
      {3:  2 }{4:// on Mulholland Drive}              |
      {6:  3 }{7:try_start();                        }|
      {3:  4 }bufref_T save_buf;                  |
      {3:  5 }switch_buffer(&save_buf, buf);      |
      {3:  6 }posp = getmark(mark, {5:false});        |
      {3:  7 }restore_buffer(&save_buf);          |
      {9:[No Name] [+]                           }|
                                              |
    ]]}

    meths.set_hl_ns(ns1)
    screen:expect{grid=[[
      {10:  1 }{11:// just to see if there was an accid}|
      {10:    }{11:ent}                                 |
      {10:  2 }{11:// on Mulholland Drive}              |
      {6:  3 }{2:^try_start();                        }|
      {10:  4 }bufref_T save_buf;                  |
      {10:  5 }switch_buffer(&save_buf, buf);      |
      {10:  6 }posp = getmark(mark, {5:false});        |
      {8:[No Name] [+]                           }|
      {10:  2 }{11:// on Mulholland Drive}              |
      {6:  3 }{2:try_start();                        }|
      {10:  4 }bufref_T save_buf;                  |
      {10:  5 }switch_buffer(&save_buf, buf);      |
      {10:  6 }posp = getmark(mark, {5:false});        |
      {10:  7 }restore_buffer(&save_buf);          |
      {9:[No Name] [+]                           }|
                                              |
    ]]}

    exec_lua [[
      local a = vim.api
      local thewin = a.nvim_get_current_win()
      local ns2 = a.nvim_create_namespace 'ns2'
      a.nvim_set_decoration_provider (ns2, {
        on_win = function (_, win, buf)
          a.nvim_set_hl_ns(win == thewin and _G.ns1 or ns2)
        end;
      })
    ]]
    screen:expect{grid=[[
      {10:  1 }{11:// just to see if there was an accid}|
      {10:    }{11:ent}                                 |
      {10:  2 }{11:// on Mulholland Drive}              |
      {6:  3 }{2:^try_start();                        }|
      {10:  4 }bufref_T save_buf;                  |
      {10:  5 }switch_buffer(&save_buf, buf);      |
      {10:  6 }posp = getmark(mark, {5:false});        |
      {8:[No Name] [+]                           }|
      {3:  2 }{4:// on Mulholland Drive}              |
      {6:  3 }{7:try_start();                        }|
      {3:  4 }bufref_T save_buf;                  |
      {3:  5 }switch_buffer(&save_buf, buf);      |
      {3:  6 }posp = getmark(mark, {5:false});        |
      {3:  7 }restore_buffer(&save_buf);          |
      {9:[No Name] [+]                           }|
                                              |
    ]]}

  end)

  it('can break an existing link', function()
    insert(mulholland)
    local ns1 = setup_provider()

    exec [[
      highlight OriginalGroup guifg='#990000'
      highlight link LinkGroup OriginalGroup
    ]]

    meths.buf_set_virtual_text(0, 0, 2, {{'- not red', 'LinkGroup'}}, {})
    screen:expect{grid=[[
      // just to see if there was an accident |
      // on Mulholland Drive                  |
      try_start(); {12:- not red}                  |
      bufref_T save_buf;                      |
      switch_buffer(&save_buf, buf);          |
      posp = getmark(mark, false);            |
      restore_buffer(&save_buf);^              |
                                              |
    ]]}

    meths.set_hl(ns1, 'LinkGroup', {fg = 'Blue'})
    meths.set_hl_ns(ns1)

    screen:expect{grid=[[
      // just to see if there was an accident |
      // on Mulholland Drive                  |
      try_start(); {4:- not red}                  |
      bufref_T save_buf;                      |
      switch_buffer(&save_buf, buf);          |
      posp = getmark(mark, false);            |
      restore_buffer(&save_buf);^              |
                                              |
    ]]}
  end)

  it("with 'default': do not break an existing link", function()
    insert(mulholland)
    local ns1 = setup_provider()

    exec [[
      highlight OriginalGroup guifg='#990000'
      highlight link LinkGroup OriginalGroup
    ]]

    meths.buf_set_virtual_text(0, 0, 2, {{'- not red', 'LinkGroup'}}, {})
    screen:expect{grid=[[
      // just to see if there was an accident |
      // on Mulholland Drive                  |
      try_start(); {12:- not red}                  |
      bufref_T save_buf;                      |
      switch_buffer(&save_buf, buf);          |
      posp = getmark(mark, false);            |
      restore_buffer(&save_buf);^              |
                                              |
    ]]}

    meths.set_hl(ns1, 'LinkGroup', {fg = 'Blue', default=true})
    meths.set_hl_ns(ns1)
    feed 'k'

    screen:expect{grid=[[
      // just to see if there was an accident |
      // on Mulholland Drive                  |
      try_start(); {12:- not red}                  |
      bufref_T save_buf;                      |
      switch_buffer(&save_buf, buf);          |
      posp = getmark(mark, false^);            |
      restore_buffer(&save_buf);              |
                                              |
    ]]}
  end)
end)
