local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local feed = helpers.feed
local insert = helpers.insert
local exec_lua = helpers.exec_lua
local exec = helpers.exec
local expect_events = helpers.expect_events
local meths = helpers.meths
local command = helpers.command

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

describe('extmark decorations', function()
  local screen
  before_each( function()
    clear()
    screen = Screen.new(50, 15)
    screen:attach()
    screen:set_default_attr_ids {
      [1] = {bold=true, foreground=Screen.colors.Blue};
      [2] = {foreground = Screen.colors.Brown};
      [3] = {bold = true, foreground = Screen.colors.SeaGreen};
      [4] = {background = Screen.colors.Red1, foreground = Screen.colors.Gray100};
      [5] = {foreground = Screen.colors.Brown, bold = true};
      [6] = {foreground = Screen.colors.DarkCyan};
      [7] = {foreground = Screen.colors.Grey0, background = tonumber('0xff4c4c')};
      [8] = {foreground = tonumber('0x180606'), background = tonumber('0xff4c4c')};
      [9] = {foreground = tonumber('0xe40c0c'), background = tonumber('0xff4c4c'), bold = true};
      [10] = {foreground = tonumber('0xb20000'), background = tonumber('0xff4c4c')};
      [11] = {blend = 30, background = Screen.colors.Red1};
      [12] = {foreground = Screen.colors.Brown, blend = 30, background = Screen.colors.Red1, bold = true};
      [13] = {foreground = Screen.colors.Fuchsia};
      [14] = {background = Screen.colors.Red1, foreground = Screen.colors.Black};
      [15] = {background = Screen.colors.Red1, foreground = tonumber('0xb20000')};
      [16] = {blend = 30, background = Screen.colors.Red1, foreground = Screen.colors.Magenta1};
      [17] = {bold = true, foreground = Screen.colors.Brown, background = Screen.colors.LightGrey};
      [18] = {background = Screen.colors.LightGrey};
      [19] = {foreground = Screen.colors.Cyan4, background = Screen.colors.LightGrey};
      [20] = {foreground = tonumber('0x180606'), background = tonumber('0xf13f3f')};
      [21] = {foreground = Screen.colors.Gray0, background = tonumber('0xf13f3f')};
      [22] = {foreground = tonumber('0xb20000'), background = tonumber('0xf13f3f')};
      [23] = {foreground = Screen.colors.Magenta1, background = Screen.colors.LightGrey};
      [24] = {bold = true};
    }
  end)

  local example_text = [[
for _,item in ipairs(items) do
    local text, hl_id_cell, count = unpack(item)
    if hl_id_cell ~= nil then
        hl_id = hl_id_cell
    end
    for _ = 1, (count or 1) do
        local cell = line[colpos]
        cell.text = text
        cell.hl_id = hl_id
        colpos = colpos+1
    end
end]]

  it('can have virtual text of overlay position', function()
    insert(example_text)
    feed 'gg'

    local ns = meths.create_namespace 'test'
    for i = 1,9 do
      meths.buf_set_extmark(0, ns, i, 0, { virt_text={{'|', 'LineNr'}}, virt_text_pos='overlay'})
      if i == 3 or (i >= 6 and i <= 9) then
        meths.buf_set_extmark(0, ns, i, 4, { virt_text={{'|', 'NonText'}}, virt_text_pos='overlay'})
      end
    end
    meths.buf_set_extmark(0, ns, 9, 10, { virt_text={{'foo'}, {'bar', 'MoreMsg'}, {'!!', 'ErrorMsg'}}, virt_text_pos='overlay'})

    -- can "float" beyond end of line
    meths.buf_set_extmark(0, ns, 5, 28, { virt_text={{'loopy', 'ErrorMsg'}}, virt_text_pos='overlay'})
    -- bound check: right edge of window
    meths.buf_set_extmark(0, ns, 2, 26, { virt_text={{'bork bork bork ' }, {'bork bork bork', 'ErrorMsg'}}, virt_text_pos='overlay'})

    screen:expect{grid=[[
      ^for _,item in ipairs(items) do                    |
      {2:|}   local text, hl_id_cell, count = unpack(item)  |
      {2:|}   if hl_id_cell ~= nil tbork bork bork {4:bork bork}|
      {2:|}   {1:|}   hl_id = hl_id_cell                        |
      {2:|}   end                                           |
      {2:|}   for _ = 1, (count or 1) {4:loopy}                 |
      {2:|}   {1:|}   local cell = line[colpos]                 |
      {2:|}   {1:|}   cell.text = text                          |
      {2:|}   {1:|}   cell.hl_id = hl_id                        |
      {2:|}   {1:|}   cofoo{3:bar}{4:!!}olpos+1                         |
          end                                           |
      end                                               |
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
    ]]}


    -- handles broken lines
    screen:try_resize(22, 25)
    screen:expect{grid=[[
      ^for _,item in ipairs(i|
      tems) do              |
      {2:|}   local text, hl_id_|
      cell, count = unpack(i|
      tem)                  |
      {2:|}   if hl_id_cell ~= n|
      il tbork bork bork {4:bor}|
      {2:|}   {1:|}   hl_id = hl_id_|
      cell                  |
      {2:|}   end               |
      {2:|}   for _ = 1, (count |
      or 1) {4:loopy}           |
      {2:|}   {1:|}   local cell = l|
      ine[colpos]           |
      {2:|}   {1:|}   cell.text = te|
      xt                    |
      {2:|}   {1:|}   cell.hl_id = h|
      l_id                  |
      {2:|}   {1:|}   cofoo{3:bar}{4:!!}olpo|
      s+1                   |
          end               |
      end                   |
      {1:~                     }|
      {1:~                     }|
                            |
    ]]}
  end)

  it('can have virtual text of overlay position and styling', function()
    insert(example_text)
    feed 'gg'
    local ns = meths.create_namespace 'test'

    command 'set ft=lua'
    command 'syntax on'

    screen:expect{grid=[[
      {5:^for} _,item {5:in} {6:ipairs}(items) {5:do}                    |
          {5:local} text, hl_id_cell, count = unpack(item)  |
          {5:if} hl_id_cell ~= {13:nil} {5:then}                     |
              hl_id = hl_id_cell                        |
          {5:end}                                           |
          {5:for} _ = {13:1}, (count {5:or} {13:1}) {5:do}                    |
              {5:local} cell = line[colpos]                 |
              cell.text = text                          |
              cell.hl_id = hl_id                        |
              colpos = colpos+{13:1}                         |
          {5:end}                                           |
      {5:end}                                               |
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
    ]]}

    command 'hi Blendy guibg=Red blend=30'
    meths.buf_set_extmark(0, ns, 1, 5, { virt_text={{'blendy text - here', 'Blendy'}}, virt_text_pos='overlay', hl_mode='blend'})
    meths.buf_set_extmark(0, ns, 2, 5, { virt_text={{'combining color', 'Blendy'}}, virt_text_pos='overlay', hl_mode='combine'})
    meths.buf_set_extmark(0, ns, 3, 5, { virt_text={{'replacing color', 'Blendy'}}, virt_text_pos='overlay', hl_mode='replace'})

    meths.buf_set_extmark(0, ns, 4, 5, { virt_text={{'blendy text - here', 'Blendy'}}, virt_text_pos='overlay', hl_mode='blend', virt_text_hide=true})
    meths.buf_set_extmark(0, ns, 5, 5, { virt_text={{'combining color', 'Blendy'}}, virt_text_pos='overlay', hl_mode='combine', virt_text_hide=true})
    meths.buf_set_extmark(0, ns, 6, 5, { virt_text={{'replacing color', 'Blendy'}}, virt_text_pos='overlay', hl_mode='replace', virt_text_hide=true})

    screen:expect{grid=[[
      {5:^for} _,item {5:in} {6:ipairs}(items) {5:do}                    |
          {5:l}{8:blen}{7:dy}{10:e}{7:text}{10:h}{7:-}{10:_}{7:here}ell, count = unpack(item)  |
          {5:i}{12:c}{11:ombining color} {13:nil} {5:then}                     |
           {11:replacing color}d_cell                        |
          {5:e}{8:bl}{14:endy}{15:i}{14:text}{15:o}{14:-}{15:o}{14:h}{7:ere}                           |
          {5:f}{12:co}{11:mbini}{16:n}{11:g color}t {5:or} {13:1}) {5:do}                    |
           {11:replacing color} line[colpos]                 |
              cell.text = text                          |
              cell.hl_id = hl_id                        |
              colpos = colpos+{13:1}                         |
          {5:end}                                           |
      {5:end}                                               |
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
    ]]}

    feed 'V5G'
    screen:expect{grid=[[
      {17:for}{18: _,item }{17:in}{18: }{19:ipairs}{18:(items) }{17:do}                    |
      {18:    }{17:l}{20:blen}{21:dy}{22:e}{21:text}{22:h}{21:-}{22:_}{21:here}{18:ell, count = unpack(item)}  |
      {18:    }{17:i}{12:c}{11:ombining color}{18: }{23:nil}{18: }{17:then}                     |
      {18:     }{11:replacing color}{18:d_cell}                        |
      {18:    }{5:^e}{17:nd}                                           |
          {5:f}{12:co}{11:mbini}{16:n}{11:g color}t {5:or} {13:1}) {5:do}                    |
           {11:replacing color} line[colpos]                 |
              cell.text = text                          |
              cell.hl_id = hl_id                        |
              colpos = colpos+{13:1}                         |
          {5:end}                                           |
      {5:end}                                               |
      {1:~                                                 }|
      {1:~                                                 }|
      {24:-- VISUAL LINE --}                                 |
    ]]}

    feed 'jj'
    screen:expect{grid=[[
      {17:for}{18: _,item }{17:in}{18: }{19:ipairs}{18:(items) }{17:do}                    |
      {18:    }{17:l}{20:blen}{21:dy}{22:e}{21:text}{22:h}{21:-}{22:_}{21:here}{18:ell, count = unpack(item)}  |
      {18:    }{17:i}{12:c}{11:ombining color}{18: }{23:nil}{18: }{17:then}                     |
      {18:     }{11:replacing color}{18:d_cell}                        |
      {18:    }{17:end}                                           |
      {18:    }{17:for}{18: _ = }{23:1}{18:, (count }{17:or}{18: }{23:1}{18:) }{17:do}                    |
      {18:    }^ {18:   }{17:local}{18: cell = line[colpos]}                 |
              cell.text = text                          |
              cell.hl_id = hl_id                        |
              colpos = colpos+{13:1}                         |
          {5:end}                                           |
      {5:end}                                               |
      {1:~                                                 }|
      {1:~                                                 }|
      {24:-- VISUAL LINE --}                                 |
    ]]}
  end)
end)
