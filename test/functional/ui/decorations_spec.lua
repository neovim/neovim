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
      [13] = {background = Screen.colors.LightBlue};
      [14] = {background = Screen.colors.WebGray, foreground = Screen.colors.DarkBlue};
      [15] = {special = Screen.colors.Blue1, undercurl = true},
      [16] = {special = Screen.colors.Red, undercurl = true},
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
        on_end = on_do; _on_spell_nav = on_do;
      })
      return _G.ns1
    ]])
  end

  local function check_trace(expected)
    local actual = exec_lua [[ local b = beamtrace beamtrace = {} return b ]]
    expect_events(expected, actual, "beam trace")
  end

  it('does not OOM when inserting, rather than appending, to the decoration provider vector', function()
    -- Add a dummy decoration provider with a larger ns id than what setup_provider() creates.
    -- This forces get_decor_provider() to insert into the providers vector,
    -- rather than append, which used to spin in an infinite loop allocating
    -- memory until nvim crashed/was killed.
    setup_provider([[
      local ns2 = a.nvim_create_namespace "ns2"
      a.nvim_set_decoration_provider(ns2, {})
    ]])
    helpers.assert_alive()
  end)

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
      { "start", 4 };
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
      { "start", 5 };
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

  it('can indicate spellchecked points', function()
    exec [[
    set spell
    set spelloptions=noplainbuffer
    syntax off
    ]]

    insert [[
    I am well written text.
    i am not capitalized.
    I am a speling mistakke.
    ]]

    setup_provider [[
      local ns = a.nvim_create_namespace "spell"
      beamtrace = {}
      local function on_do(kind, ...)
        if kind == 'win' or kind == 'spell' then
          a.nvim_buf_set_extmark(0, ns, 0, 0, {
            end_row = 2,
            end_col = 23,
            spell = true,
            priority = 20,
            ephemeral = true
          })
        end
        table.insert(beamtrace, {kind, ...})
      end
    ]]

    check_trace {
      { "start", 5 };
      { "win", 1000, 1, 0, 5 };
      { "line", 1000, 1, 0 };
      { "line", 1000, 1, 1 };
      { "line", 1000, 1, 2 };
      { "line", 1000, 1, 3 };
      { "end", 5 };
    }

    feed "gg0"

    screen:expect{grid=[[
    ^I am well written text.                 |
    {15:i} am not capitalized.                   |
    I am a {16:speling} {16:mistakke}.                |
                                            |
    {1:~                                       }|
    {1:~                                       }|
    {1:~                                       }|
                                            |
    ]]}

    feed "]s"
    check_trace {
      { "spell", 1000, 1, 1, 0, 1, -1 };
    }
    screen:expect{grid=[[
    I am well written text.                 |
    {15:^i} am not capitalized.                   |
    I am a {16:speling} {16:mistakke}.                |
                                            |
    {1:~                                       }|
    {1:~                                       }|
    {1:~                                       }|
                                            |
    ]]}

    feed "]s"
    check_trace {
      { "spell", 1000, 1, 2, 7, 2, -1 };
    }
    screen:expect{grid=[[
    I am well written text.                 |
    {15:i} am not capitalized.                   |
    I am a {16:^speling} {16:mistakke}.                |
                                            |
    {1:~                                       }|
    {1:~                                       }|
    {1:~                                       }|
                                            |
    ]]}

    -- spell=false with lower priority doesn't disable spell
    local ns = meths.create_namespace "spell"
    local id = helpers.curbufmeths.set_extmark(ns, 0, 0, { priority = 30, end_row = 2, end_col = 23, spell = false })

    screen:expect{grid=[[
    I am well written text.                 |
    i am not capitalized.                   |
    I am a ^speling mistakke.                |
                                            |
    {1:~                                       }|
    {1:~                                       }|
    {1:~                                       }|
                                            |
    ]]}

    -- spell=false with higher priority does disable spell
    helpers.curbufmeths.set_extmark(ns, 0, 0, { id = id, priority = 10, end_row = 2, end_col = 23, spell = false })

    screen:expect{grid=[[
    I am well written text.                 |
    {15:i} am not capitalized.                   |
    I am a {16:^speling} {16:mistakke}.                |
                                            |
    {1:~                                       }|
    {1:~                                       }|
    {1:~                                       }|
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
          a.nvim_set_hl_ns_fast(win == thewin and _G.ns1 or ns2)
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

  it('can have virtual text', function()
    insert(mulholland)
    setup_provider [[
      local hl = a.nvim_get_hl_id_by_name "ErrorMsg"
      local test_ns = a.nvim_create_namespace "mulholland"
      function on_do(event, ...)
        if event == "line" then
          local win, buf, line = ...
          a.nvim_buf_set_extmark(buf, test_ns, line, 0, {
            virt_text = {{'+', 'ErrorMsg'}};
            virt_text_pos='overlay';
            ephemeral = true;
          })
        end
      end
    ]]

    screen:expect{grid=[[
      {2:+}/ just to see if there was an accident |
      {2:+}/ on Mulholland Drive                  |
      {2:+}ry_start();                            |
      {2:+}ufref_T save_buf;                      |
      {2:+}witch_buffer(&save_buf, buf);          |
      {2:+}osp = getmark(mark, false);            |
      {2:+}estore_buffer(&save_buf);^              |
                                              |
    ]]}
  end)

  it('can have virtual text of the style: right_align', function()
    insert(mulholland)
    setup_provider [[
      local hl = a.nvim_get_hl_id_by_name "ErrorMsg"
      local test_ns = a.nvim_create_namespace "mulholland"
      function on_do(event, ...)
        if event == "line" then
          local win, buf, line = ...
          a.nvim_buf_set_extmark(buf, test_ns, line, 0, {
            virt_text = {{'+'}, {string.rep(' ', line+1), 'ErrorMsg'}};
            virt_text_pos='right_align';
            ephemeral = true;
          })
        end
      end
    ]]

    screen:expect{grid=[[
      // just to see if there was an acciden+{2: }|
      // on Mulholland Drive               +{2:  }|
      try_start();                        +{2:   }|
      bufref_T save_buf;                 +{2:    }|
      switch_buffer(&save_buf, buf);    +{2:     }|
      posp = getmark(mark, false);     +{2:      }|
      restore_buffer(&save_buf);^      +{2:       }|
                                              |
    ]]}
  end)

  it('can highlight beyond EOL', function()
    insert(mulholland)
    setup_provider [[
      local test_ns = a.nvim_create_namespace "veberod"
      function on_do(event, ...)
        if event == "line" then
          local win, buf, line = ...
          if string.find(a.nvim_buf_get_lines(buf, line, line+1, true)[1], "buf") then
            a.nvim_buf_set_extmark(buf, test_ns, line, 0, {
              end_line = line+1;
              hl_group = 'DiffAdd';
              hl_eol = true;
              ephemeral = true;
            })
          end
        end
      end
    ]]

    screen:expect{grid=[[
      // just to see if there was an accident |
      // on Mulholland Drive                  |
      try_start();                            |
      {13:bufref_T save_buf;                      }|
      {13:switch_buffer(&save_buf, buf);          }|
      posp = getmark(mark, false);            |
      {13:restore_buffer(&save_buf);^              }|
                                              |
    ]]}
  end)

  it('can create and remove signs when CursorMoved autocommand validates botline #18661', function()
    exec_lua([[
      local lines = {}
      for i = 1, 200 do
        lines[i] = 'hello' .. tostring(i)
      end
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    ]])
    setup_provider([[
      local function on_do(kind, winid, bufnr, topline, botline_guess)
        if kind == 'win' then
          if topline < 100 and botline_guess > 100 then
            vim.api.nvim_buf_set_extmark(bufnr, ns1, 99, -1, { sign_text = 'X' })
          else
            vim.api.nvim_buf_clear_namespace(bufnr, ns1, 0, -1)
          end
        end
      end
    ]])
    command([[autocmd CursorMoved * call line('w$')]])
    meths.win_set_cursor(0, {100, 0})
    screen:expect([[
      {14:  }hello97                               |
      {14:  }hello98                               |
      {14:  }hello99                               |
      X ^hello100                              |
      {14:  }hello101                              |
      {14:  }hello102                              |
      {14:  }hello103                              |
                                              |
    ]])
    meths.win_set_cursor(0, {1, 0})
    screen:expect([[
      ^hello1                                  |
      hello2                                  |
      hello3                                  |
      hello4                                  |
      hello5                                  |
      hello6                                  |
      hello7                                  |
                                              |
    ]])
  end)
end)

describe('extmark decorations', function()
  local screen, ns
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
      [25] = {background = Screen.colors.LightRed};
      [26] = {background=Screen.colors.DarkGrey, foreground=Screen.colors.LightGrey};
      [27] = {background = Screen.colors.Plum1};
    }

    ns = meths.create_namespace 'test'
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

  it('empty virtual text at eol should not break colorcolumn #17860', function()
    insert(example_text)
    feed('gg')
    command('set colorcolumn=40')
    screen:expect([[
      ^for _,item in ipairs(items) do         {25: }          |
          local text, hl_id_cell, count = unp{25:a}ck(item)  |
          if hl_id_cell ~= nil then          {25: }          |
              hl_id = hl_id_cell             {25: }          |
          end                                {25: }          |
          for _ = 1, (count or 1) do         {25: }          |
              local cell = line[colpos]      {25: }          |
              cell.text = text               {25: }          |
              cell.hl_id = hl_id             {25: }          |
              colpos = colpos+1              {25: }          |
          end                                {25: }          |
      end                                    {25: }          |
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
    ]])
    meths.buf_set_extmark(0, ns, 4, 0, { virt_text={{''}}, virt_text_pos='eol'})
    screen:expect_unchanged()
  end)

  it('can have virtual text of overlay position', function()
    insert(example_text)
    feed 'gg'

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
    meths.buf_set_extmark(0, ns, 2, 26, { virt_text={{'bork bork bork '}, {'bork bork bork', 'ErrorMsg'}}, virt_text_pos='overlay'})
    -- empty virt_text should not change anything
    meths.buf_set_extmark(0, ns, 6, 16, { virt_text={{''}}, virt_text_pos='overlay'})

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

    command 'set ft=lua'
    command 'syntax on'

    screen:expect{grid=[[
      {5:^for} _,item {5:in} {6:ipairs}(items) {5:do}                    |
          {5:local} text, hl_id_cell, count {5:=} unpack(item)  |
          {5:if} hl_id_cell {5:~=} {13:nil} {5:then}                     |
              hl_id {5:=} hl_id_cell                        |
          {5:end}                                           |
          {5:for} _ {5:=} {13:1}, (count {5:or} {13:1}) {5:do}                    |
              {5:local} cell {5:=} line[colpos]                 |
              cell.text {5:=} text                          |
              cell.hl_id {5:=} hl_id                        |
              colpos {5:=} colpos{5:+}{13:1}                         |
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
          {5:l}{8:blen}{7:dy}{10:e}{7:text}{10:h}{7:-}{10:_}{7:here}ell, count {5:=} unpack(item)  |
          {5:i}{12:c}{11:ombining col}{12:or} {13:nil} {5:then}                     |
           {11:replacing color}d_cell                        |
          {5:e}{8:bl}{7:endy}{10: }{7:text}{10: }{7:-}{10: }{7:here}                           |
          {5:f}{12:co}{11:mbi}{12:n}{11:i}{16:n}{11:g color}t {5:or} {13:1}) {5:do}                    |
           {11:replacing color} line[colpos]                 |
              cell.text {5:=} text                          |
              cell.hl_id {5:=} hl_id                        |
              colpos {5:=} colpos{5:+}{13:1}                         |
          {5:end}                                           |
      {5:end}                                               |
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
    ]]}

    feed 'V5G'
    screen:expect{grid=[[
      {17:for}{18: _,item }{17:in}{18: }{19:ipairs}{18:(items) }{17:do}                    |
      {18:    }{17:l}{20:blen}{21:dy}{22:e}{21:text}{22:h}{21:-}{22:_}{21:here}{18:ell, count }{17:=}{18: unpack(item)}  |
      {18:    }{17:i}{12:c}{11:ombining col}{12:or}{18: }{23:nil}{18: }{17:then}                     |
      {18:     }{11:replacing color}{18:d_cell}                        |
      {18:    }{5:^e}{17:nd}                                           |
          {5:f}{12:co}{11:mbi}{12:n}{11:i}{16:n}{11:g color}t {5:or} {13:1}) {5:do}                    |
           {11:replacing color} line[colpos]                 |
              cell.text {5:=} text                          |
              cell.hl_id {5:=} hl_id                        |
              colpos {5:=} colpos{5:+}{13:1}                         |
          {5:end}                                           |
      {5:end}                                               |
      {1:~                                                 }|
      {1:~                                                 }|
      {24:-- VISUAL LINE --}                                 |
    ]]}

    feed 'jj'
    screen:expect{grid=[[
      {17:for}{18: _,item }{17:in}{18: }{19:ipairs}{18:(items) }{17:do}                    |
      {18:    }{17:l}{20:blen}{21:dy}{22:e}{21:text}{22:h}{21:-}{22:_}{21:here}{18:ell, count }{17:=}{18: unpack(item)}  |
      {18:    }{17:i}{12:c}{11:ombining col}{12:or}{18: }{23:nil}{18: }{17:then}                     |
      {18:     }{11:replacing color}{18:d_cell}                        |
      {18:    }{17:end}                                           |
      {18:    }{17:for}{18: _ }{17:=}{18: }{23:1}{18:, (count }{17:or}{18: }{23:1}{18:) }{17:do}                    |
      {18:    }^ {18:   }{17:local}{18: cell }{17:=}{18: line[colpos]}                 |
              cell.text {5:=} text                          |
              cell.hl_id {5:=} hl_id                        |
              colpos {5:=} colpos{5:+}{13:1}                         |
          {5:end}                                           |
      {5:end}                                               |
      {1:~                                                 }|
      {1:~                                                 }|
      {24:-- VISUAL LINE --}                                 |
    ]]}
  end)

  it('can have virtual text of fixed win_col position', function()
    insert(example_text)
    feed 'gg'
    meths.buf_set_extmark(0, ns, 1, 0, { virt_text={{'Very', 'ErrorMsg'}},   virt_text_win_col=31, hl_mode='blend'})
    meths.buf_set_extmark(0, ns, 2, 10, { virt_text={{'Much', 'ErrorMsg'}},   virt_text_win_col=31, hl_mode='blend'})
    meths.buf_set_extmark(0, ns, 3, 15, { virt_text={{'Error', 'ErrorMsg'}}, virt_text_win_col=31, hl_mode='blend'})
    meths.buf_set_extmark(0, ns, 7, 21, { virt_text={{'-', 'NonText'}}, virt_text_win_col=4, hl_mode='blend'})
    -- empty virt_text should not change anything
    meths.buf_set_extmark(0, ns, 8, 0, { virt_text={{''}}, virt_text_win_col=14, hl_mode='blend'})

    screen:expect{grid=[[
      ^for _,item in ipairs(items) do                    |
          local text, hl_id_cell, cou{4:Very} unpack(item)  |
          if hl_id_cell ~= nil then  {4:Much}               |
              hl_id = hl_id_cell     {4:Error}              |
          end                                           |
          for _ = 1, (count or 1) do                    |
              local cell = line[colpos]                 |
          {1:-}   cell.text = text                          |
              cell.hl_id = hl_id                        |
              colpos = colpos+1                         |
          end                                           |
      end                                               |
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
    ]]}

    feed '3G12|i<cr><esc>'
    screen:expect{grid=[[
      for _,item in ipairs(items) do                    |
          local text, hl_id_cell, cou{4:Very} unpack(item)  |
          if hl_i                    {4:Much}               |
      ^d_cell ~= nil then                                |
              hl_id = hl_id_cell     {4:Error}              |
          end                                           |
          for _ = 1, (count or 1) do                    |
              local cell = line[colpos]                 |
          {1:-}   cell.text = text                          |
              cell.hl_id = hl_id                        |
              colpos = colpos+1                         |
          end                                           |
      end                                               |
      {1:~                                                 }|
                                                        |
    ]]}

    feed 'u:<cr>'
    screen:expect{grid=[[
      for _,item in ipairs(items) do                    |
          local text, hl_id_cell, cou{4:Very} unpack(item)  |
          if hl_i^d_cell ~= nil then  {4:Much}               |
              hl_id = hl_id_cell     {4:Error}              |
          end                                           |
          for _ = 1, (count or 1) do                    |
              local cell = line[colpos]                 |
          {1:-}   cell.text = text                          |
              cell.hl_id = hl_id                        |
              colpos = colpos+1                         |
          end                                           |
      end                                               |
      {1:~                                                 }|
      {1:~                                                 }|
      :                                                 |
    ]]}

    feed '8|i<cr><esc>'
    screen:expect{grid=[[
      for _,item in ipairs(items) do                    |
          local text, hl_id_cell, cou{4:Very} unpack(item)  |
          if                                            |
      ^hl_id_cell ~= nil then         {4:Much}               |
              hl_id = hl_id_cell     {4:Error}              |
          end                                           |
          for _ = 1, (count or 1) do                    |
              local cell = line[colpos]                 |
          {1:-}   cell.text = text                          |
              cell.hl_id = hl_id                        |
              colpos = colpos+1                         |
          end                                           |
      end                                               |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('can have virtual text which combines foreground and background groups', function()
    screen:set_default_attr_ids {
      [1] = {bold=true, foreground=Screen.colors.Blue};
      [2] = {background = tonumber('0x123456'), foreground = tonumber('0xbbbbbb')};
      [3] = {background = tonumber('0x123456'), foreground = tonumber('0xcccccc')};
      [4] = {background = tonumber('0x234567'), foreground = tonumber('0xbbbbbb')};
      [5] = {background = tonumber('0x234567'), foreground = tonumber('0xcccccc')};
      [6] = {bold = true, foreground = tonumber('0xcccccc'), background = tonumber('0x234567')};
    }

    exec [[
      hi BgOne guibg=#123456
      hi BgTwo guibg=#234567
      hi FgEin guifg=#bbbbbb
      hi FgZwei guifg=#cccccc
      hi VeryBold gui=bold
    ]]

    meths.buf_set_extmark(0, ns, 0, 0, { virt_text={
      {'a', {'BgOne', 'FgEin'}};
      {'b', {'BgOne', 'FgZwei'}};
      {'c', {'BgTwo', 'FgEin'}};
      {'d', {'BgTwo', 'FgZwei'}};
      {'X', {'BgTwo', 'FgZwei', 'VeryBold'}};
    }})

    screen:expect{grid=[[
      ^ {2:a}{3:b}{4:c}{5:d}{6:X}                                            |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('does not crash when deleting a cleared buffer #15212', function()
    exec_lua [[
      ns = vim.api.nvim_create_namespace("myplugin")
      vim.api.nvim_buf_set_extmark(0, ns, 0, 0, {virt_text = {{"a"}}, end_col = 0})
    ]]
    screen:expect{grid=[[
      ^ a                                                |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
    ]]}

    exec_lua [[
      vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
      vim.cmd("bdelete")
    ]]
    screen:expect{grid=[[
      ^                                                  |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
    ]]}
    helpers.assert_alive()
  end)

  it('conceal #19007', function()
    screen:try_resize(50, 5)
    insert('foo\n')
    command('let &conceallevel=2')
    meths.buf_set_extmark(0, ns, 0, 0, {end_col=0, end_row=2, conceal='X'})
    screen:expect([[
        {26:X}                                                 |
        ^                                                  |
        {1:~                                                 }|
        {1:~                                                 }|
                                                          |
      ]])
  end)

  it('avoids redraw issue #20651', function()
    exec_lua[[
      vim.cmd.normal'10oXXX'
      vim.cmd.normal'gg'
      local ns = vim.api.nvim_create_namespace('ns')

      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_open_win(bufnr, false, { relative = 'win', height = 1, width = 1, row = 0, col = 0 })

      vim.api.nvim_create_autocmd('CursorMoved', { callback = function()
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        vim.api.nvim_buf_set_extmark(0, ns, row, 0, { id = 1 })
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, {})
        vim.schedule(function()
          vim.api.nvim_buf_set_extmark(0, ns, row, 0, {
            id = 1,
            virt_text = {{'HELLO', 'Normal'}},
          })
        end)
      end
      })
    ]]

    for _ = 1, 3 do
      helpers.sleep(10)
      feed 'j'
    end

    screen:expect{grid=[[
      {27: }                                                 |
      XXX                                               |
      XXX                                               |
      ^XXX HELLO                                         |
      XXX                                               |
      XXX                                               |
      XXX                                               |
      XXX                                               |
      XXX                                               |
      XXX                                               |
      XXX                                               |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
    ]]}

  end)

  it('underline attribute with higher priority takes effect #22371', function()
    screen:try_resize(50, 3)
    insert('aaabbbaaa')
    exec([[
      hi TestUL gui=underline guifg=Blue
      hi TestUC gui=undercurl guisp=Red
      hi TestBold gui=bold
    ]])
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue};
      [1] = {underline = true, foreground = Screen.colors.Blue};
      [2] = {undercurl = true, special = Screen.colors.Red};
      [3] = {underline = true, foreground = Screen.colors.Blue, special = Screen.colors.Red};
      [4] = {undercurl = true, foreground = Screen.colors.Blue, special = Screen.colors.Red};
      [5] = {bold = true, underline = true, foreground = Screen.colors.Blue};
      [6] = {bold = true, undercurl = true, special = Screen.colors.Red};
    })

    meths.buf_set_extmark(0, ns, 0, 0, { end_col = 9, hl_group = 'TestUL', priority = 20 })
    meths.buf_set_extmark(0, ns, 0, 3, { end_col = 6, hl_group = 'TestUC', priority = 30 })
    screen:expect([[
      {1:aaa}{4:bbb}{1:aa^a}                                         |
      {0:~                                                 }|
                                                        |
    ]])
    meths.buf_clear_namespace(0, ns, 0, -1)
    meths.buf_set_extmark(0, ns, 0, 0, { end_col = 9, hl_group = 'TestUC', priority = 20 })
    meths.buf_set_extmark(0, ns, 0, 3, { end_col = 6, hl_group = 'TestUL', priority = 30 })
    screen:expect([[
      {2:aaa}{3:bbb}{2:aa^a}                                         |
      {0:~                                                 }|
                                                        |
    ]])
    meths.buf_clear_namespace(0, ns, 0, -1)
    meths.buf_set_extmark(0, ns, 0, 0, { end_col = 9, hl_group = 'TestUL', priority = 30 })
    meths.buf_set_extmark(0, ns, 0, 3, { end_col = 6, hl_group = 'TestUC', priority = 20 })
    screen:expect([[
      {1:aaa}{3:bbb}{1:aa^a}                                         |
      {0:~                                                 }|
                                                        |
    ]])
    meths.buf_clear_namespace(0, ns, 0, -1)
    meths.buf_set_extmark(0, ns, 0, 0, { end_col = 9, hl_group = 'TestUC', priority = 30 })
    meths.buf_set_extmark(0, ns, 0, 3, { end_col = 6, hl_group = 'TestUL', priority = 20 })
    screen:expect([[
      {2:aaa}{4:bbb}{2:aa^a}                                         |
      {0:~                                                 }|
                                                        |
    ]])

    -- When only one highlight group has an underline attribute, it should always take effect.
    meths.buf_clear_namespace(0, ns, 0, -1)
    meths.buf_set_extmark(0, ns, 0, 0, { end_col = 9, hl_group = 'TestUL', priority = 20 })
    meths.buf_set_extmark(0, ns, 0, 3, { end_col = 6, hl_group = 'TestBold', priority = 30 })
    screen:expect([[
      {1:aaa}{5:bbb}{1:aa^a}                                         |
      {0:~                                                 }|
                                                        |
    ]])
    meths.buf_clear_namespace(0, ns, 0, -1)
    meths.buf_set_extmark(0, ns, 0, 0, { end_col = 9, hl_group = 'TestUL', priority = 30 })
    meths.buf_set_extmark(0, ns, 0, 3, { end_col = 6, hl_group = 'TestBold', priority = 20 })
    screen:expect_unchanged(true)
    meths.buf_clear_namespace(0, ns, 0, -1)
    meths.buf_set_extmark(0, ns, 0, 0, { end_col = 9, hl_group = 'TestUC', priority = 20 })
    meths.buf_set_extmark(0, ns, 0, 3, { end_col = 6, hl_group = 'TestBold', priority = 30 })
    screen:expect([[
      {2:aaa}{6:bbb}{2:aa^a}                                         |
      {0:~                                                 }|
                                                        |
    ]])
    meths.buf_clear_namespace(0, ns, 0, -1)
    meths.buf_set_extmark(0, ns, 0, 0, { end_col = 9, hl_group = 'TestUC', priority = 30 })
    meths.buf_set_extmark(0, ns, 0, 3, { end_col = 6, hl_group = 'TestBold', priority = 20 })
    screen:expect_unchanged(true)
  end)

end)

describe('decorations: virtual lines', function()
  local screen, ns
  before_each(function()
    clear()
    screen = Screen.new(50, 12)
    screen:attach()
    screen:set_default_attr_ids {
      [1] = {bold=true, foreground=Screen.colors.Blue};
      [2] = {foreground = Screen.colors.Cyan4};
      [3] = {background = Screen.colors.Yellow1};
      [4] = {bold = true};
      [5] = {background = Screen.colors.Yellow, foreground = Screen.colors.Blue};
      [6] = {foreground = Screen.colors.Blue};
      [7] = {foreground = Screen.colors.SlateBlue};
      [8] = {background = Screen.colors.WebGray, foreground = Screen.colors.DarkBlue};
      [9] = {foreground = Screen.colors.Brown};
    }

    ns = meths.create_namespace 'test'
  end)

  local example_text = [[
if (h->n_buckets < new_n_buckets) { // expand
  khkey_t *new_keys = (khkey_t *)krealloc((void *)h->keys, new_n_buckets * sizeof(khkey_t));
  h->keys = new_keys;
  if (kh_is_map && val_size) {
    char *new_vals = krealloc( h->vals_buf, new_n_buckets * val_size);
    h->vals_buf = new_vals;
  }
}]]

  it('works with one line', function()
    insert(example_text)
    feed 'gg'
    meths.buf_set_extmark(0, ns, 1, 33, {
      virt_lines={ {{">> ", "NonText"}, {"krealloc", "Identifier"}, {": change the size of an allocation"}}};
      virt_lines_above=true;
    })

    screen:expect{grid=[[
      ^if (h->n_buckets < new_n_buckets) { // expand     |
      {1:>> }{2:krealloc}: change the size of an allocation     |
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = krealloc( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      }                                                 |
                                                        |
    ]]}

    feed '/krealloc<cr>'
    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
      {1:>> }{2:krealloc}: change the size of an allocation     |
        khkey_t *new_keys = (khkey_t *){3:^krealloc}((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = {3:krealloc}( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      }                                                 |
      /krealloc                                         |
    ]]}

    -- virtual line remains anchored to the extmark
    feed 'i<cr>'
    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)                 |
      {1:>> }{2:krealloc}: change the size of an allocation     |
      {3:^krealloc}((void *)h->keys, new_n_buckets * sizeof(k|
      hkey_t));                                         |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = {3:krealloc}( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      {4:-- INSERT --}                                      |
    ]]}

    feed '<esc>3+'
    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)                 |
      {1:>> }{2:krealloc}: change the size of an allocation     |
      {3:krealloc}((void *)h->keys, new_n_buckets * sizeof(k|
      hkey_t));                                         |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          ^char *new_vals = {3:krealloc}( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
                                                        |
    ]]}

    meths.buf_set_extmark(0, ns, 5, 0, {
      virt_lines = { {{"^^ REVIEW:", "Todo"}, {" new_vals variable seems unnecessary?", "Comment"}} };
    })
    -- TODO: what about the cursor??
    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)                 |
      {1:>> }{2:krealloc}: change the size of an allocation     |
      {3:krealloc}((void *)h->keys, new_n_buckets * sizeof(k|
      hkey_t));                                         |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          ^char *new_vals = {3:krealloc}( h->vals_buf, new_n_|
      buckets * val_size);                              |
      {5:^^ REVIEW:}{6: new_vals variable seems unnecessary?}   |
          h->vals_buf = new_vals;                       |
                                                        |
    ]]}

    meths.buf_clear_namespace(0, ns, 0, -1)
    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)                 |
      {3:krealloc}((void *)h->keys, new_n_buckets * sizeof(k|
      hkey_t));                                         |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = {3:krealloc}( h->vals_buf, new_n_|
      buck^ets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      }                                                 |
                                                        |
    ]]}
  end)


  it('works with text at the beginning of the buffer', function()
    insert(example_text)
    feed 'gg'

    screen:expect{grid=[[
      ^if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = krealloc( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      }                                                 |
      {1:~                                                 }|
                                                        |
    ]]}

    meths.buf_set_extmark(0, ns, 0, 0, {
      virt_lines={
        {{"refactor(khash): ", "Special"}, {"take size of values as parameter"}};
        {{"Author: Dev Devsson, "}, {"Tue Aug 31 10:13:37 2021", "Comment"}};
      };
      virt_lines_above=true;
      right_gravity=false;
    })

    -- placing virt_text on topline does not automatically cause a scroll
    screen:expect{grid=[[
      ^if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = krealloc( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      }                                                 |
      {1:~                                                 }|
                                                        |
    ]], unchanged=true}

    feed '<c-b>'
    screen:expect{grid=[[
      {7:refactor(khash): }take size of values as parameter |
      Author: Dev Devsson, {6:Tue Aug 31 10:13:37 2021}     |
      ^if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = krealloc( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
                                                        |
    ]]}
  end)

  it('works with text at the end of the buffer', function()
    insert(example_text)
    feed 'G'

    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = krealloc( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      ^}                                                 |
      {1:~                                                 }|
                                                        |
    ]]}

    local id = meths.buf_set_extmark(0, ns, 7, 0, {
      virt_lines={{{"Grugg"}}};
      right_gravity=false;
    })

    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = krealloc( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      ^}                                                 |
      Grugg                                             |
                                                        |
    ]]}

    screen:try_resize(50, 11)
    feed('gg')
    screen:expect{grid=[[
      ^if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = krealloc( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      }                                                 |
                                                        |
    ]]}

    feed('G<C-E>')
    screen:expect{grid=[[
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = krealloc( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      ^}                                                 |
      Grugg                                             |
                                                        |
    ]]}

    feed('gg')
    screen:expect{grid=[[
      ^if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = krealloc( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      }                                                 |
                                                        |
    ]]}

    screen:try_resize(50, 12)
    feed('G')
    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = krealloc( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      ^}                                                 |
      Grugg                                             |
                                                        |
    ]]}

    meths.buf_del_extmark(0, ns, id)
    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = krealloc( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      ^}                                                 |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('works beyond end of the buffer with virt_lines_above', function()
    insert(example_text)
    feed 'G'

    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = krealloc( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      ^}                                                 |
      {1:~                                                 }|
                                                        |
    ]]}

    local id = meths.buf_set_extmark(0, ns, 8, 0, {
      virt_lines={{{"Grugg"}}};
      virt_lines_above = true,
    })

    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = krealloc( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      ^}                                                 |
      Grugg                                             |
                                                        |
    ]]}

    feed('dd')
    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = krealloc( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        ^}                                               |
      Grugg                                             |
      {1:~                                                 }|
                                                        |
    ]]}

    feed('dk')
    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          ^char *new_vals = krealloc( h->vals_buf, new_n_|
      buckets * val_size);                              |
      Grugg                                             |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
    ]]}

    feed('dgg')
    screen:expect{grid=[[
      ^                                                  |
      Grugg                                             |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      --No lines in buffer--                            |
    ]]}

    meths.buf_del_extmark(0, ns, id)
    screen:expect{grid=[[
      ^                                                  |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      --No lines in buffer--                            |
    ]]}
  end)

  it('does not cause syntax ml_get error at the end of a buffer #17816', function()
    command([[syntax region foo keepend start='^foo' end='^$']])
    command('syntax sync minlines=100')
    insert('foo')
    meths.buf_set_extmark(0, ns, 0, 0, {virt_lines = {{{'bar', 'Comment'}}}})
    screen:expect([[
      fo^o                                               |
      {6:bar}                                               |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
    ]])
  end)

  it('works with a block scrolling up', function()
    screen:try_resize(30, 7)
    insert("aa\nbb\ncc\ndd\nee\nff\ngg\nhh")
    feed 'gg'

    meths.buf_set_extmark(0, ns, 6, 0, {
      virt_lines={
        {{"they see me"}};
        {{"scrolling", "Special"}};
        {{"they"}};
        {{"hatin'", "Special"}};
      };
    })

    screen:expect{grid=[[
      ^aa                            |
      bb                            |
      cc                            |
      dd                            |
      ee                            |
      ff                            |
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      ^bb                            |
      cc                            |
      dd                            |
      ee                            |
      ff                            |
      gg                            |
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      ^cc                            |
      dd                            |
      ee                            |
      ff                            |
      gg                            |
      they see me                   |
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      ^dd                            |
      ee                            |
      ff                            |
      gg                            |
      they see me                   |
      {7:scrolling}                     |
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      ^ee                            |
      ff                            |
      gg                            |
      they see me                   |
      {7:scrolling}                     |
      they                          |
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      ^ff                            |
      gg                            |
      they see me                   |
      {7:scrolling}                     |
      they                          |
      {7:hatin'}                        |
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      ^gg                            |
      they see me                   |
      {7:scrolling}                     |
      they                          |
      {7:hatin'}                        |
      hh                            |
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      they see me                   |
      {7:scrolling}                     |
      they                          |
      {7:hatin'}                        |
      ^hh                            |
      {1:~                             }|
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      {7:scrolling}                     |
      they                          |
      {7:hatin'}                        |
      ^hh                            |
      {1:~                             }|
      {1:~                             }|
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      they                          |
      {7:hatin'}                        |
      ^hh                            |
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      {7:hatin'}                        |
      ^hh                            |
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      ^hh                            |
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
                                    |
    ]]}
  end)

  it('works with sign and numbercolumns', function()
    insert(example_text)
    feed 'gg'
    command 'set number signcolumn=yes'
    screen:expect{grid=[[
      {8:  }{9:  1 }^if (h->n_buckets < new_n_buckets) { // expan|
      {8:  }{9:    }d                                           |
      {8:  }{9:  2 }  khkey_t *new_keys = (khkey_t *)krealloc((v|
      {8:  }{9:    }oid *)h->keys, new_n_buckets * sizeof(khkey_|
      {8:  }{9:    }t));                                        |
      {8:  }{9:  3 }  h->keys = new_keys;                       |
      {8:  }{9:  4 }  if (kh_is_map && val_size) {              |
      {8:  }{9:  5 }    char *new_vals = krealloc( h->vals_buf, |
      {8:  }{9:    }new_n_buckets * val_size);                  |
      {8:  }{9:  6 }    h->vals_buf = new_vals;                 |
      {8:  }{9:  7 }  }                                         |
                                                        |
    ]]}

    local markid = meths.buf_set_extmark(0, ns, 2, 0, {
      virt_lines={
        {{"Some special", "Special"}};
        {{"remark about codes", "Comment"}};
      };
    })

    screen:expect{grid=[[
      {8:  }{9:  1 }^if (h->n_buckets < new_n_buckets) { // expan|
      {8:  }{9:    }d                                           |
      {8:  }{9:  2 }  khkey_t *new_keys = (khkey_t *)krealloc((v|
      {8:  }{9:    }oid *)h->keys, new_n_buckets * sizeof(khkey_|
      {8:  }{9:    }t));                                        |
      {8:  }{9:  3 }  h->keys = new_keys;                       |
      {8:  }{9:    }{7:Some special}                                |
      {8:  }{9:    }{6:remark about codes}                          |
      {8:  }{9:  4 }  if (kh_is_map && val_size) {              |
      {8:  }{9:  5 }    char *new_vals = krealloc( h->vals_buf, |
      {8:  }{9:    }new_n_buckets * val_size);                  |
                                                        |
    ]]}

    meths.buf_set_extmark(0, ns, 2, 0, {
      virt_lines={
        {{"Some special", "Special"}};
        {{"remark about codes", "Comment"}};
      };
      virt_lines_leftcol=true;
      id=markid;
    })
    screen:expect{grid=[[
      {8:  }{9:  1 }^if (h->n_buckets < new_n_buckets) { // expan|
      {8:  }{9:    }d                                           |
      {8:  }{9:  2 }  khkey_t *new_keys = (khkey_t *)krealloc((v|
      {8:  }{9:    }oid *)h->keys, new_n_buckets * sizeof(khkey_|
      {8:  }{9:    }t));                                        |
      {8:  }{9:  3 }  h->keys = new_keys;                       |
      {7:Some special}                                      |
      {6:remark about codes}                                |
      {8:  }{9:  4 }  if (kh_is_map && val_size) {              |
      {8:  }{9:  5 }    char *new_vals = krealloc( h->vals_buf, |
      {8:  }{9:    }new_n_buckets * val_size);                  |
                                                        |
    ]]}
  end)


  it('works with hard tabs', function()
    insert(example_text)
    feed 'gg'
    meths.buf_set_extmark(0, ns, 1, 0, {
      virt_lines={ {{">>", "NonText"}, {"\tvery\ttabby", "Identifier"}, {"text\twith\ttabs"}}};
    })
    screen:expect{grid=[[
      ^if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
      {1:>>}{2:      very    tabby}text       with    tabs      |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = krealloc( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      }                                                 |
                                                        |
    ]]}

    command 'set tabstop=4'
    screen:expect{grid=[[
      ^if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
      {1:>>}{2:  very    tabby}text   with    tabs              |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = krealloc( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      }                                                 |
                                                        |
    ]]}

    command 'set number'
    screen:expect{grid=[[
      {9:  1 }^if (h->n_buckets < new_n_buckets) { // expand |
      {9:  2 }  khkey_t *new_keys = (khkey_t *)krealloc((voi|
      {9:    }d *)h->keys, new_n_buckets * sizeof(khkey_t));|
      {9:    }{1:>>}{2:  very    tabby}text   with    tabs          |
      {9:  3 }  h->keys = new_keys;                         |
      {9:  4 }  if (kh_is_map && val_size) {                |
      {9:  5 }    char *new_vals = krealloc( h->vals_buf, ne|
      {9:    }w_n_buckets * val_size);                      |
      {9:  6 }    h->vals_buf = new_vals;                   |
      {9:  7 }  }                                           |
      {9:  8 }}                                             |
                                                        |
    ]]}

    command 'set tabstop&'
    screen:expect{grid=[[
      {9:  1 }^if (h->n_buckets < new_n_buckets) { // expand |
      {9:  2 }  khkey_t *new_keys = (khkey_t *)krealloc((voi|
      {9:    }d *)h->keys, new_n_buckets * sizeof(khkey_t));|
      {9:    }{1:>>}{2:      very    tabby}text       with    tabs  |
      {9:  3 }  h->keys = new_keys;                         |
      {9:  4 }  if (kh_is_map && val_size) {                |
      {9:  5 }    char *new_vals = krealloc( h->vals_buf, ne|
      {9:    }w_n_buckets * val_size);                      |
      {9:  6 }    h->vals_buf = new_vals;                   |
      {9:  7 }  }                                           |
      {9:  8 }}                                             |
                                                        |
    ]]}
  end)

end)

describe('decorations: signs', function()
  local screen, ns
  before_each(function()
    clear()
    screen = Screen.new(50, 10)
    screen:attach()
    screen:set_default_attr_ids {
      [1] = {foreground = Screen.colors.Blue4, background = Screen.colors.Grey};
      [2] = {foreground = Screen.colors.Blue1, bold = true};
      [3] = {background = Screen.colors.Yellow1, foreground = Screen.colors.Blue1};
    }

    ns = meths.create_namespace 'test'
    meths.win_set_option(0, 'signcolumn', 'auto:9')
  end)

  local example_text = [[
l1
l2
l3
l4
l5
]]

  it('can add a single sign (no end row)', function()
    insert(example_text)
    feed 'gg'

    meths.buf_set_extmark(0, ns, 1, -1, {sign_text='S'})

    screen:expect{grid=[[
      {1:  }^l1                                              |
      S l2                                              |
      {1:  }l3                                              |
      {1:  }l4                                              |
      {1:  }l5                                              |
      {1:  }                                                |
      {2:~                                                 }|
      {2:~                                                 }|
      {2:~                                                 }|
                                                        |
    ]]}

  end)

  it('can add a single sign (with end row)', function()
    insert(example_text)
    feed 'gg'

    meths.buf_set_extmark(0, ns, 1, -1, {sign_text='S', end_row=1})

    screen:expect{grid=[[
      {1:  }^l1                                              |
      S l2                                              |
      {1:  }l3                                              |
      {1:  }l4                                              |
      {1:  }l5                                              |
      {1:  }                                                |
      {2:~                                                 }|
      {2:~                                                 }|
      {2:~                                                 }|
                                                        |
    ]]}

  end)

  it('can add multiple signs (single extmark)', function()
    pending('TODO(lewis6991): Support ranged signs')
    insert(example_text)
    feed 'gg'

    meths.buf_set_extmark(0, ns, 1, -1, {sign_text='S', end_row = 2})

    screen:expect{grid=[[
      {1:  }^l1                                              |
      S l2                                              |
      S l3                                              |
      {1:  }l4                                              |
      {1:  }l5                                              |
      {1:  }                                                |
      {2:~                                                 }|
      {2:~                                                 }|
      {2:~                                                 }|
                                                        |
    ]]}

  end)

  it('can add multiple signs (multiple extmarks)', function()
    pending('TODO(lewis6991): Support ranged signs')
    insert(example_text)
    feed'gg'

    meths.buf_set_extmark(0, ns, 1, -1, {sign_text='S1'})
    meths.buf_set_extmark(0, ns, 3, -1, {sign_text='S2', end_row = 4})

    screen:expect{grid=[[
      {1:  }^l1                                              |
      S1l2                                              |
      {1:  }l3                                              |
      S2l4                                              |
      S2l5                                              |
      {1:  }                                                |
      {2:~                                                 }|
      {2:~                                                 }|
      {2:~                                                 }|
                                                        |
    ]]}

  end)

  it('can add multiple signs (multiple extmarks) 2', function()
    insert(example_text)
    feed 'gg'

    meths.buf_set_extmark(0, ns, 1, -1, {sign_text='S1'})
    meths.buf_set_extmark(0, ns, 1, -1, {sign_text='S2'})

    screen:expect{grid=[[
      {1:    }^l1                                            |
      S2S1l2                                            |
      {1:    }l3                                            |
      {1:    }l4                                            |
      {1:    }l5                                            |
      {1:    }                                              |
      {2:~                                                 }|
      {2:~                                                 }|
      {2:~                                                 }|
                                                        |
    ]]}

    -- TODO(lewis6991): Support ranged signs
    -- meths.buf_set_extmark(1, ns, 1, -1, {sign_text='S3', end_row = 2})

    -- screen:expect{grid=[[
    --   {1:      }^l1                                          |
    --   S3S2S1l2                                          |
    --   S3{1:    }l3                                          |
    --   {1:      }l4                                          |
    --   {1:      }l5                                          |
    --   {1:      }                                            |
    --   {2:~                                                 }|
    --   {2:~                                                 }|
    --   {2:~                                                 }|
    --                                                     |
    -- ]]}

  end)

  it('can add multiple signs (multiple extmarks) 3', function()
    pending('TODO(lewis6991): Support ranged signs')

    insert(example_text)
    feed 'gg'

    meths.buf_set_extmark(0, ns, 1, -1, {sign_text='S1', end_row=2})
    meths.buf_set_extmark(0, ns, 2, -1, {sign_text='S2', end_row=3})

    screen:expect{grid=[[
      {1:    }^l1                                            |
      S1{1:  }l2                                            |
      S2S1l3                                            |
      S2{1:  }l4                                            |
      {1:    }l5                                            |
      {1:    }                                              |
      {2:~                                                 }|
      {2:~                                                 }|
      {2:~                                                 }|
                                                        |
    ]]}
  end)

  it('can add multiple signs (multiple extmarks) 4', function()
    insert(example_text)
    feed 'gg'

    meths.buf_set_extmark(0, ns, 0, -1, {sign_text='S1', end_row=0})
    meths.buf_set_extmark(0, ns, 1, -1, {sign_text='S2', end_row=1})

    screen:expect{grid=[[
      S1^l1                                              |
      S2l2                                              |
      {1:  }l3                                              |
      {1:  }l4                                              |
      {1:  }l5                                              |
      {1:  }                                                |
      {2:~                                                 }|
      {2:~                                                 }|
      {2:~                                                 }|
                                                        |
    ]]}
  end)

  it('works with old signs', function()
    insert(example_text)
    feed 'gg'

    helpers.command('sign define Oldsign text=x')
    helpers.command([[exe 'sign place 42 line=2 name=Oldsign buffer=' . bufnr('')]])

    meths.buf_set_extmark(0, ns, 0, -1, {sign_text='S1'})
    meths.buf_set_extmark(0, ns, 1, -1, {sign_text='S2'})
    meths.buf_set_extmark(0, ns, 0, -1, {sign_text='S4'})
    meths.buf_set_extmark(0, ns, 2, -1, {sign_text='S5'})

    screen:expect{grid=[[
      S4S1^l1                                            |
      x S2l2                                            |
      S5{1:  }l3                                            |
      {1:    }l4                                            |
      {1:    }l5                                            |
      {1:    }                                              |
      {2:~                                                 }|
      {2:~                                                 }|
      {2:~                                                 }|
                                                        |
    ]]}
  end)

  it('works with old signs (with range)', function()
    pending('TODO(lewis6991): Support ranged signs')
    insert(example_text)
    feed 'gg'

    helpers.command('sign define Oldsign text=x')
    helpers.command([[exe 'sign place 42 line=2 name=Oldsign buffer=' . bufnr('')]])

    meths.buf_set_extmark(0, ns, 0, -1, {sign_text='S1'})
    meths.buf_set_extmark(0, ns, 1, -1, {sign_text='S2'})
    meths.buf_set_extmark(0, ns, 0, -1, {sign_text='S3', end_row = 4})
    meths.buf_set_extmark(0, ns, 0, -1, {sign_text='S4'})
    meths.buf_set_extmark(0, ns, 2, -1, {sign_text='S5'})

    screen:expect{grid=[[
      S3S4S1^l1                                          |
      S2S3x l2                                          |
      S5S3{1:  }l3                                          |
      S3{1:    }l4                                          |
      S3{1:    }l5                                          |
      {1:      }                                            |
      {2:~                                                 }|
      {2:~                                                 }|
      {2:~                                                 }|
                                                        |
    ]]}
  end)

  it('can add a ranged sign (with start out of view)', function()
    pending('TODO(lewis6991): Support ranged signs')

    insert(example_text)
    command 'set signcolumn=yes:2'
    feed 'gg'
    feed '2<C-e>'

    meths.buf_set_extmark(0, ns, 1, -1, {sign_text='X', end_row=3})

    screen:expect{grid=[[
      X {1:  }^l3                                            |
      X {1:  }l4                                            |
      {1:    }l5                                            |
      {1:    }                                              |
      {2:~                                                 }|
      {2:~                                                 }|
      {2:~                                                 }|
      {2:~                                                 }|
      {2:~                                                 }|
                                                        |
    ]]}

  end)

  it('can add lots of signs', function()
    screen:try_resize(40, 10)
    command 'normal 10oa b c d e f g h'

    for i = 1, 10 do
      meths.buf_set_extmark(0, ns, i,  0, { end_col =  1, hl_group='Todo' })
      meths.buf_set_extmark(0, ns, i,  2, { end_col =  3, hl_group='Todo' })
      meths.buf_set_extmark(0, ns, i,  4, { end_col =  5, hl_group='Todo' })
      meths.buf_set_extmark(0, ns, i,  6, { end_col =  7, hl_group='Todo' })
      meths.buf_set_extmark(0, ns, i,  8, { end_col =  9, hl_group='Todo' })
      meths.buf_set_extmark(0, ns, i, 10, { end_col = 11, hl_group='Todo' })
      meths.buf_set_extmark(0, ns, i, 12, { end_col = 13, hl_group='Todo' })
      meths.buf_set_extmark(0, ns, i, 14, { end_col = 15, hl_group='Todo' })
      meths.buf_set_extmark(0, ns, i, -1, { sign_text='W' })
      meths.buf_set_extmark(0, ns, i, -1, { sign_text='X' })
      meths.buf_set_extmark(0, ns, i, -1, { sign_text='Y' })
      meths.buf_set_extmark(0, ns, i, -1, { sign_text='Z' })
    end

    screen:expect{grid=[[
      X Y Z W {3:a} {3:b} {3:c} {3:d} {3:e} {3:f} {3:g} {3:h}                 |
      X Y Z W {3:a} {3:b} {3:c} {3:d} {3:e} {3:f} {3:g} {3:h}                 |
      X Y Z W {3:a} {3:b} {3:c} {3:d} {3:e} {3:f} {3:g} {3:h}                 |
      X Y Z W {3:a} {3:b} {3:c} {3:d} {3:e} {3:f} {3:g} {3:h}                 |
      X Y Z W {3:a} {3:b} {3:c} {3:d} {3:e} {3:f} {3:g} {3:h}                 |
      X Y Z W {3:a} {3:b} {3:c} {3:d} {3:e} {3:f} {3:g} {3:h}                 |
      X Y Z W {3:a} {3:b} {3:c} {3:d} {3:e} {3:f} {3:g} {3:h}                 |
      X Y Z W {3:a} {3:b} {3:c} {3:d} {3:e} {3:f} {3:g} {3:h}                 |
      X Y Z W {3:a} {3:b} {3:c} {3:d} {3:e} {3:f} {3:g} {3:^h}                 |
                                              |
    ]]}
  end)

  it('works with priority #19716', function()
    screen:try_resize(20, 3)
    insert(example_text)
    feed 'gg'

    helpers.command('sign define Oldsign text=O3')
    helpers.command([[exe 'sign place 42 line=1 name=Oldsign priority=10 buffer=' . bufnr('')]])

    meths.buf_set_extmark(0, ns, 0, -1, {sign_text='S4', priority=100})
    meths.buf_set_extmark(0, ns, 0, -1, {sign_text='S2', priority=5})
    meths.buf_set_extmark(0, ns, 0, -1, {sign_text='S5', priority=200})
    meths.buf_set_extmark(0, ns, 0, -1, {sign_text='S1', priority=1})

    screen:expect{grid=[[
      S1S2O3S4S5^l1        |
      {1:          }l2        |
                          |
    ]]}

    -- Check truncation works too
    meths.win_set_option(0, 'signcolumn', 'auto')

    screen:expect{grid=[[
      S5^l1                |
      {1:  }l2                |
                          |
    ]]}
  end)

  it('does not set signcolumn for signs without text', function()
    screen:try_resize(20, 3)
    meths.win_set_option(0, 'signcolumn', 'auto')
    insert(example_text)
    feed 'gg'
    meths.buf_set_extmark(0, ns, 0, -1, {number_hl_group='Error'})
    screen:expect{grid=[[
      ^l1                  |
      l2                  |
                          |
    ]]}
  end)

end)

describe('decorations: virt_text', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 10)
    screen:attach()
    screen:set_default_attr_ids {
      [1] = {foreground = Screen.colors.Brown};
      [2] = {foreground = Screen.colors.Fuchsia};
      [3] = {bold = true, foreground = Screen.colors.Blue1};
    }
  end)

  it('avoids regression in #17638', function()
    exec_lua[[
      vim.wo.number = true
      vim.wo.relativenumber = true
    ]]

    command 'normal 4ohello'
    command 'normal aVIRTUAL'

    local ns = meths.create_namespace('test')

    meths.buf_set_extmark(0, ns, 2, 0, {
      virt_text = {{"hello", "String"}},
      virt_text_win_col = 20,
    })

    screen:expect{grid=[[
      {1:  4 }                                              |
      {1:  3 }hello                                         |
      {1:  2 }hello               {2:hello}                     |
      {1:  1 }hello                                         |
      {1:5   }helloVIRTUA^L                                  |
      {3:~                                                 }|
      {3:~                                                 }|
      {3:~                                                 }|
      {3:~                                                 }|
                                                        |
    ]]}

    -- Trigger a screen update
    feed('k')

    screen:expect{grid=[[
      {1:  3 }                                              |
      {1:  2 }hello                                         |
      {1:  1 }hello               {2:hello}                     |
      {1:4   }hell^o                                         |
      {1:  1 }helloVIRTUAL                                  |
      {3:~                                                 }|
      {3:~                                                 }|
      {3:~                                                 }|
      {3:~                                                 }|
                                                        |
    ]]}
  end)

  it('redraws correctly when re-using extmark ids', function()
    command 'normal 5ohello'

    screen:expect{grid=[[
                                                        |
      hello                                             |
      hello                                             |
      hello                                             |
      hello                                             |
      hell^o                                             |
      {3:~                                                 }|
      {3:~                                                 }|
      {3:~                                                 }|
                                                        |
    ]]}

    local ns = meths.create_namespace('ns')
    for row = 1, 5 do
      meths.buf_set_extmark(0, ns, row, 0, { id = 1, virt_text = {{'world', 'Normal'}} })
    end

    screen:expect{grid=[[
                                                        |
      hello                                             |
      hello                                             |
      hello                                             |
      hello                                             |
      hell^o world                                       |
      {3:~                                                 }|
      {3:~                                                 }|
      {3:~                                                 }|
                                                        |
    ]]}
  end)

end)
