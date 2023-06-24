local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local feed = helpers.feed
local insert = helpers.insert
local exec_lua = helpers.exec_lua
local exec = helpers.exec
local expect_events = helpers.expect_events
local meths = helpers.meths
local funcs = helpers.funcs
local curbufmeths = helpers.curbufmeths
local command = helpers.command
local assert_alive = helpers.assert_alive

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
      [15] = {special = Screen.colors.Blue, undercurl = true},
      [16] = {special = Screen.colors.Red, undercurl = true},
      [17] = {foreground = Screen.colors.Red},
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
      local api = vim.api
      _G.ns1 = api.nvim_create_namespace "ns1"
    ]] .. (code or [[
      beamtrace = {}
      local function on_do(kind, ...)
        table.insert(beamtrace, {kind, ...})
      end
    ]]) .. [[
      api.nvim_set_decoration_provider(_G.ns1, {
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
      local ns2 = api.nvim_create_namespace "ns2"
      api.nvim_set_decoration_provider(ns2, {})
    ]])
    assert_alive()
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
      { "buf", 1, 5 };
      { "win", 1000, 1, 0, 8 };
      { "line", 1000, 1, 6 };
      { "end", 5 };
    }
  end)

  it('can have single provider', function()
    insert(mulholland)
    setup_provider [[
      local hl = api.nvim_get_hl_id_by_name "ErrorMsg"
      local test_ns = api.nvim_create_namespace "mulholland"
      function on_do(event, ...)
        if event == "line" then
          local win, buf, line = ...
          api.nvim_buf_set_extmark(buf, test_ns, line, line,
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
      local ns = api.nvim_create_namespace "spell"
      beamtrace = {}
      local function on_do(kind, ...)
        if kind == 'win' or kind == 'spell' then
          api.nvim_buf_set_extmark(0, ns, 0, 0, {
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

    -- spell=false with higher priority does disable spell
    local ns = meths.create_namespace "spell"
    local id = curbufmeths.set_extmark(ns, 0, 0, { priority = 30, end_row = 2, end_col = 23, spell = false })

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

    feed "]s"
    screen:expect{grid=[[
      I am well written text.                 |
      i am not capitalized.                   |
      I am a ^speling mistakke.                |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {17:search hit BOTTOM, continuing at TOP}    |
    ]]}
    command('echo ""')

    -- spell=false with lower priority doesn't disable spell
    curbufmeths.set_extmark(ns, 0, 0, { id = id, priority = 10, end_row = 2, end_col = 23, spell = false })

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

    feed "]s"
    screen:expect{grid=[[
      I am well written text.                 |
      {15:i} am not capitalized.                   |
      I am a {16:speling} {16:^mistakke}.                |
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
      local api = vim.api
      local thewin = api.nvim_get_current_win()
      local ns2 = api.nvim_create_namespace 'ns2'
      api.nvim_set_decoration_provider (ns2, {
        on_win = function (_, win, buf)
          api.nvim_set_hl_ns_fast(win == thewin and _G.ns1 or ns2)
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
      local hl = api.nvim_get_hl_id_by_name "ErrorMsg"
      local test_ns = api.nvim_create_namespace "mulholland"
      function on_do(event, ...)
        if event == "line" then
          local win, buf, line = ...
          api.nvim_buf_set_extmark(buf, test_ns, line, 0, {
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
      local hl = api.nvim_get_hl_id_by_name "ErrorMsg"
      local test_ns = api.nvim_create_namespace "mulholland"
      function on_do(event, ...)
        if event == "line" then
          local win, buf, line = ...
          api.nvim_buf_set_extmark(buf, test_ns, line, 0, {
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
      local test_ns = api.nvim_create_namespace "veberod"
      function on_do(event, ...)
        if event == "line" then
          local win, buf, line = ...
          if string.find(api.nvim_buf_get_lines(buf, line, line+1, true)[1], "buf") then
            api.nvim_buf_set_extmark(buf, test_ns, line, 0, {
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
            api.nvim_buf_set_extmark(bufnr, ns1, 99, -1, { sign_text = 'X' })
          else
            api.nvim_buf_clear_namespace(bufnr, ns1, 0, -1)
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

  it('does not allow removing extmarks during on_line callbacks', function()
    exec_lua([[
      eok = true
    ]])
    setup_provider([[
      local function on_do(kind, winid, bufnr, topline, botline_guess)
        if kind == 'line' then
          api.nvim_buf_set_extmark(bufnr, ns1, 1, -1, { sign_text = 'X' })
          eok = pcall(api.nvim_buf_clear_namespace, bufnr, ns1, 0, -1)
        end
      end
    ]])
    exec_lua([[
      assert(eok == false)
    ]])
  end)
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
      [19] = {foreground = Screen.colors.DarkCyan, background = Screen.colors.LightGrey};
      [20] = {foreground = tonumber('0x180606'), background = tonumber('0xf13f3f')};
      [21] = {foreground = Screen.colors.Gray0, background = tonumber('0xf13f3f')};
      [22] = {foreground = tonumber('0xb20000'), background = tonumber('0xf13f3f')};
      [23] = {foreground = Screen.colors.Magenta1, background = Screen.colors.LightGrey};
      [24] = {bold = true};
      [25] = {background = Screen.colors.LightRed};
      [26] = {background=Screen.colors.DarkGrey, foreground=Screen.colors.LightGrey};
      [27] = {background = Screen.colors.Plum1};
      [28] = {underline = true, foreground = Screen.colors.SlateBlue};
      [29] = {foreground = Screen.colors.SlateBlue, background = Screen.colors.LightGray, underline = true};
      [30] = {foreground = Screen.colors.DarkCyan, background = Screen.colors.LightGray, underline = true};
      [31] = {underline = true, foreground = Screen.colors.DarkCyan};
      [32] = {underline = true};
      [33] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGray};
      [34] = {background = Screen.colors.Yellow};
      [35] = {background = Screen.colors.Yellow, bold = true, foreground = Screen.colors.Blue};
    }

    ns = meths.create_namespace 'test'
  end)

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
    meths.buf_set_extmark(0, ns, 2, 26, { virt_text={{'bork bork bork'}, {(' bork'):rep(10), 'ErrorMsg'}}, virt_text_pos='overlay'})
    -- empty virt_text should not change anything
    meths.buf_set_extmark(0, ns, 6, 16, { virt_text={{''}}, virt_text_pos='overlay'})

    screen:expect{grid=[[
      ^for _,item in ipairs(items) do                    |
      {2:|}   local text, hl_id_cell, count = unpack(item)  |
      {2:|}   if hl_id_cell ~= nil tbork bork bork{4: bork bork}|
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
      il tbork bork bork{4: bor}|
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

    -- truncating in the middle of a char leaves a space
    meths.buf_set_lines(0, 0, 1, true, {'for _,item in ipairs(items) do  -- 古古古'})
    meths.buf_set_lines(0, 10, 12, true, {'    end  -- ??????????', 'end  -- ?古古古古?古古'})
    meths.buf_set_extmark(0, ns, 0, 35, { virt_text={{'A', 'ErrorMsg'}, {'AA'}}, virt_text_pos='overlay'})
    meths.buf_set_extmark(0, ns, 10, 19, { virt_text={{'口口口', 'ErrorMsg'}}, virt_text_pos='overlay'})
    meths.buf_set_extmark(0, ns, 11, 21, { virt_text={{'口口口', 'ErrorMsg'}}, virt_text_pos='overlay'})
    meths.buf_set_extmark(0, ns, 11, 8, { virt_text={{'口口', 'ErrorMsg'}}, virt_text_pos='overlay'})
    screen:expect{grid=[[
      ^for _,item in ipairs(i|
      tems) do  -- {4:A}AA 古   |
      {2:|}   local text, hl_id_|
      cell, count = unpack(i|
      tem)                  |
      {2:|}   if hl_id_cell ~= n|
      il tbork bork bork{4: bor}|
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
          end  -- ???????{4:口 }|
      end  -- {4:口口} 古古{4:口口 }|
      {1:~                     }|
      {1:~                     }|
                            |
    ]]}

    screen:try_resize(82, 13)
    screen:expect{grid=[[
      ^for _,item in ipairs(items) do  -- {4:A}AA 古                                         |
      {2:|}   local text, hl_id_cell, count = unpack(item)                                  |
      {2:|}   if hl_id_cell ~= nil tbork bork bork{4: bork bork bork bork bork bork bork bork b}|
      {2:|}   {1:|}   hl_id = hl_id_cell                                                        |
      {2:|}   end                                                                           |
      {2:|}   for _ = 1, (count or 1) {4:loopy}                                                 |
      {2:|}   {1:|}   local cell = line[colpos]                                                 |
      {2:|}   {1:|}   cell.text = text                                                          |
      {2:|}   {1:|}   cell.hl_id = hl_id                                                        |
      {2:|}   {1:|}   cofoo{3:bar}{4:!!}olpos+1                                                         |
          end  -- ???????{4:口口口}                                                         |
      end  -- {4:口口} 古古{4:口口口}                                                           |
                                                                                        |
    ]]}

    meths.buf_clear_namespace(0, ns, 0, -1)
    screen:expect{grid=[[
      ^for _,item in ipairs(items) do  -- 古古古                                         |
          local text, hl_id_cell, count = unpack(item)                                  |
          if hl_id_cell ~= nil then                                                     |
              hl_id = hl_id_cell                                                        |
          end                                                                           |
          for _ = 1, (count or 1) do                                                    |
              local cell = line[colpos]                                                 |
              cell.text = text                                                          |
              cell.hl_id = hl_id                                                        |
              colpos = colpos+1                                                         |
          end  -- ??????????                                                            |
      end  -- ?古古古古?古古                                                            |
                                                                                        |
    ]]}
  end)

  it('virt_text_hide hides overlay virtual text when extmark is off-screen', function()
    screen:try_resize(50, 3)
    command('set nowrap')
    meths.buf_set_lines(0, 0, -1, true, {'-- ' .. ('…'):rep(57)})
    meths.buf_set_extmark(0, ns, 0, 0, { virt_text={{'?????', 'ErrorMsg'}}, virt_text_pos='overlay', virt_text_hide=true})
    meths.buf_set_extmark(0, ns, 0, 123, { virt_text={{'!!!!!', 'ErrorMsg'}}, virt_text_pos='overlay', virt_text_hide=true})
    screen:expect{grid=[[
      {4:^?????}……………………………………………………………………………………………………{4:!!!!!}……|
      {1:~                                                 }|
                                                        |
    ]]}
    feed('40zl')
    screen:expect{grid=[[
      ^………{4:!!!!!}………………………………                              |
      {1:~                                                 }|
                                                        |
    ]]}
    feed('3zl')
    screen:expect{grid=[[
      {4:^!!!!!}………………………………                                 |
      {1:~                                                 }|
                                                        |
    ]]}
    feed('7zl')
    screen:expect{grid=[[
      ^…………………………                                        |
      {1:~                                                 }|
                                                        |
    ]]}

    command('set wrap smoothscroll')
    screen:expect{grid=[[
      {4:?????}……………………………………………………………………………………………………{4:!!!!!}……|
      ^…………………………                                        |
                                                        |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
      {1:<<<}………………^…                                        |
      {1:~                                                 }|
                                                        |
    ]]}
    screen:try_resize(40, 3)
    screen:expect{grid=[[
      {1:<<<}{4:!!!!!}……………………………^…                    |
      {1:~                                       }|
                                              |
    ]]}
    feed('<C-Y>')
    screen:expect{grid=[[
      {4:?????}……………………………………………………………………………………………|
      ………{4:!!!!!}……………………………^…                    |
                                              |
    ]]}
  end)

  it('overlay virtual text works on and after a TAB #24022', function()
    screen:try_resize(40, 3)
    meths.buf_set_lines(0, 0, -1, true, {'\t\tline 1'})
    meths.buf_set_extmark(0, ns, 0, 0, { virt_text = {{'AA', 'Search'}}, virt_text_pos = 'overlay', hl_mode = 'combine' })
    meths.buf_set_extmark(0, ns, 0, 1, { virt_text = {{'BB', 'Search'}}, virt_text_pos = 'overlay', hl_mode = 'combine' })
    meths.buf_set_extmark(0, ns, 0, 2, { virt_text = {{'CC', 'Search'}}, virt_text_pos = 'overlay', hl_mode = 'combine' })
    screen:expect{grid=[[
      {34:AA}     ^ {34:BB}      {34:CC}ne 1                  |
      {1:~                                       }|
                                              |
    ]]}
    command('setlocal list listchars=tab:<->')
    screen:expect{grid=[[
      {35:^AA}{1:----->}{35:BB}{1:----->}{34:CC}ne 1                  |
      {1:~                                       }|
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

  it('can have virtual text of right_align and fixed win_col position', function()
    insert(example_text)
    feed 'gg'
    meths.buf_set_extmark(0, ns, 1, 0, { virt_text={{'Very', 'ErrorMsg'}},   virt_text_win_col=31, hl_mode='blend'})
    meths.buf_set_extmark(0, ns, 1, 0, { virt_text={{'VERY', 'ErrorMsg'}}, virt_text_pos='right_align', hl_mode='blend'})
    meths.buf_set_extmark(0, ns, 2, 10, { virt_text={{'Much', 'ErrorMsg'}},   virt_text_win_col=31, hl_mode='blend'})
    meths.buf_set_extmark(0, ns, 2, 10, { virt_text={{'MUCH', 'ErrorMsg'}}, virt_text_pos='right_align', hl_mode='blend'})
    meths.buf_set_extmark(0, ns, 3, 15, { virt_text={{'Error', 'ErrorMsg'}}, virt_text_win_col=31, hl_mode='blend'})
    meths.buf_set_extmark(0, ns, 3, 15, { virt_text={{'ERROR', 'ErrorMsg'}}, virt_text_pos='right_align', hl_mode='blend'})
    meths.buf_set_extmark(0, ns, 7, 21, { virt_text={{'-', 'NonText'}}, virt_text_win_col=4, hl_mode='blend'})
    meths.buf_set_extmark(0, ns, 7, 21, { virt_text={{'-', 'NonText'}}, virt_text_pos='right_align', hl_mode='blend'})
    -- empty virt_text should not change anything
    meths.buf_set_extmark(0, ns, 8, 0, { virt_text={{''}}, virt_text_win_col=14, hl_mode='blend'})
    meths.buf_set_extmark(0, ns, 8, 0, { virt_text={{''}}, virt_text_pos='right_align', hl_mode='blend'})

    screen:expect{grid=[[
      ^for _,item in ipairs(items) do                    |
          local text, hl_id_cell, cou{4:Very} unpack(ite{4:VERY}|
          if hl_id_cell ~= nil then  {4:Much}           {4:MUCH}|
              hl_id = hl_id_cell     {4:Error}         {4:ERROR}|
          end                                           |
          for _ = 1, (count or 1) do                    |
              local cell = line[colpos]                 |
          {1:-}   cell.text = text                         {1:-}|
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
          local text, hl_id_cell, cou{4:Very} unpack(ite{4:VERY}|
          if hl_i                    {4:Much}           {4:MUCH}|
      ^d_cell ~= nil then                                |
              hl_id = hl_id_cell     {4:Error}         {4:ERROR}|
          end                                           |
          for _ = 1, (count or 1) do                    |
              local cell = line[colpos]                 |
          {1:-}   cell.text = text                         {1:-}|
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
          local text, hl_id_cell, cou{4:Very} unpack(ite{4:VERY}|
          if hl_i^d_cell ~= nil then  {4:Much}           {4:MUCH}|
              hl_id = hl_id_cell     {4:Error}         {4:ERROR}|
          end                                           |
          for _ = 1, (count or 1) do                    |
              local cell = line[colpos]                 |
          {1:-}   cell.text = text                         {1:-}|
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
          local text, hl_id_cell, cou{4:Very} unpack(ite{4:VERY}|
          if                                            |
      ^hl_id_cell ~= nil then         {4:Much}           {4:MUCH}|
              hl_id = hl_id_cell     {4:Error}         {4:ERROR}|
          end                                           |
          for _ = 1, (count or 1) do                    |
              local cell = line[colpos]                 |
          {1:-}   cell.text = text                         {1:-}|
              cell.hl_id = hl_id                        |
              colpos = colpos+1                         |
          end                                           |
      end                                               |
      {1:~                                                 }|
                                                        |
    ]]}

    feed 'jI-- <esc>..........'
    screen:expect{grid=[[
      for _,item in ipairs(items) do                    |
          local text, hl_id_cell, cou{4:Very} unpack(ite{4:VERY}|
          if                                            |
      hl_id_cell ~= nil then         {4:Much}           {4:MUCH}|
              --^ -- -- -- -- -- -- --{4:Error}- -- hl_i{4:ERROR}|
      l_id_cell                                         |
          end                                           |
          for _ = 1, (count or 1) do                    |
              local cell = line[colpos]                 |
          {1:-}   cell.text = text                         {1:-}|
              cell.hl_id = hl_id                        |
              colpos = colpos+1                         |
          end                                           |
      end                                               |
                                                        |
    ]]}

    feed '.'
    screen:expect{grid=[[
      for _,item in ipairs(items) do                    |
          local text, hl_id_cell, cou{4:Very} unpack(ite{4:VERY}|
          if                                            |
      hl_id_cell ~= nil then         {4:Much}           {4:MUCH}|
              --^ -- -- -- -- -- -- -- -- -- -- -- hl_id |
      = hl_id_cell                   {4:Error}         {4:ERROR}|
          end                                           |
          for _ = 1, (count or 1) do                    |
              local cell = line[colpos]                 |
          {1:-}   cell.text = text                         {1:-}|
              cell.hl_id = hl_id                        |
              colpos = colpos+1                         |
          end                                           |
      end                                               |
                                                        |
    ]]}

    command 'set nowrap'
    screen:expect{grid=[[
      for _,item in ipairs(items) do                    |
          local text, hl_id_cell, cou{4:Very} unpack(ite{4:VERY}|
          if                                            |
      hl_id_cell ~= nil then         {4:Much}           {4:MUCH}|
              --^ -- -- -- -- -- -- --{4:Error}- -- -- h{4:ERROR}|
          end                                           |
          for _ = 1, (count or 1) do                    |
              local cell = line[colpos]                 |
          {1:-}   cell.text = text                         {1:-}|
              cell.hl_id = hl_id                        |
              colpos = colpos+1                         |
          end                                           |
      end                                               |
      {1:~                                                 }|
                                                        |
    ]]}

    feed('8zl')
    screen:expect{grid=[[
      em in ipairs(items) do                            |
      l text, hl_id_cell, count = unp{4:Very}item)      {4:VERY}|
                                                        |
      ll ~= nil then                 {4:Much}           {4:MUCH}|
      --^ -- -- -- -- -- -- -- -- -- -{4:Error}hl_id = h{4:ERROR}|
                                                        |
      _ = 1, (count or 1) do                            |
      local cell = line[colpos]                         |
      cell{1:-}text = text                                 {1:-}|
      cell.hl_id = hl_id                                |
      colpos = colpos+1                                 |
                                                        |
                                                        |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('can have virtual text on folded line', function()
    insert([[
      11111
      22222
      33333]])
    command('1,2fold')
    command('set nowrap')
    screen:try_resize(50, 3)
    feed('zb')
    -- XXX: the behavior of overlay virtual text at non-zero column is strange:
    -- 1. With 'wrap' it is never shown.
    -- 2. With 'nowrap' it is shown only if the extmark is hidden before leftcol.
    meths.buf_set_extmark(0, ns, 0, 0, { virt_text = {{'AA', 'Underlined'}}, hl_mode = 'combine', virt_text_pos = 'overlay' })
    meths.buf_set_extmark(0, ns, 0, 1, { virt_text = {{'BB', 'Underlined'}}, hl_mode = 'combine', virt_text_win_col = 10 })
    meths.buf_set_extmark(0, ns, 0, 2, { virt_text = {{'CC', 'Underlined'}}, hl_mode = 'combine', virt_text_pos = 'right_align' })
    screen:expect{grid=[[
      {29:AA}{33:-  2 lin}{29:BB}{33:: 11111·····························}{29:CC}|
      3333^3                                             |
                                                        |
    ]]}
    feed('zl')
    screen:expect{grid=[[
      {29:AA}{33:-  2 lin}{29:BB}{33:: 11111·····························}{29:CC}|
      333^3                                              |
                                                        |
    ]]}
    feed('zl')
    screen:expect{grid=[[
      {29:AA}{33:-  2 lin}{29:BB}{33:: 11111·····························}{29:CC}|
      33^3                                               |
                                                        |
    ]]}
    feed('zl')
    screen:expect{grid=[[
      {29:AA}{33:-  2 lin}{29:BB}{33:: 11111·····························}{29:CC}|
      3^3                                                |
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
    assert_alive()
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

  it('conceal works just before truncated double-width char #21486', function()
    screen:try_resize(40, 4)
    meths.buf_set_lines(0, 0, -1, true, {'', ('a'):rep(37) .. '<>古'})
    meths.buf_set_extmark(0, ns, 1, 37, {end_col=39, conceal=''})
    command('setlocal conceallevel=2')
    screen:expect{grid=[[
      ^                                        |
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{1:>}  |
      古                                      |
                                              |
    ]]}
    feed('j')
    screen:expect{grid=[[
                                              |
      ^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa<>{1:>}|
      古                                      |
                                              |
    ]]}
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

  it('highlight is combined with syntax and sign linehl #20004', function()
    screen:try_resize(50, 3)
    insert([[
      function Func()
      end]])
    feed('gg')
    command('set ft=lua')
    command('syntax on')
    meths.buf_set_extmark(0, ns, 0, 0, { end_col = 3, hl_mode = 'combine', hl_group = 'Visual' })
    command('hi default MyLine gui=underline')
    command('sign define CurrentLine linehl=MyLine')
    funcs.sign_place(6, 'Test', 'CurrentLine', '', { lnum = 1 })
    screen:expect{grid=[[
      {30:^fun}{31:ction}{32: Func()                                   }|
      {6:end}                                               |
                                                        |
    ]]}
  end)

  it('highlight works after TAB with sidescroll #14201', function()
    screen:try_resize(50, 3)
    command('set nowrap')
    meths.buf_set_lines(0, 0, -1, true, {'\tword word word word'})
    meths.buf_set_extmark(0, ns, 0, 1, { end_col = 3, hl_group = 'ErrorMsg' })
    screen:expect{grid=[[
             ^ {4:wo}rd word word word                       |
      {1:~                                                 }|
                                                        |
    ]]}
    feed('7zl')
    screen:expect{grid=[[
       {4:^wo}rd word word word                              |
      {1:~                                                 }|
                                                        |
    ]]}
    feed('zl')
    screen:expect{grid=[[
      {4:^wo}rd word word word                               |
      {1:~                                                 }|
                                                        |
    ]]}
    feed('zl')
    screen:expect{grid=[[
      {4:^o}rd word word word                                |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('highlights the beginning of a TAB char correctly #23734', function()
    screen:try_resize(50, 3)
    meths.buf_set_lines(0, 0, -1, true, {'this is the\ttab'})
    meths.buf_set_extmark(0, ns, 0, 11, { end_col = 15, hl_group = 'ErrorMsg' })
    screen:expect{grid=[[
      ^this is the{4:     tab}                               |
      {1:~                                                 }|
                                                        |
    ]]}

    meths.buf_clear_namespace(0, ns, 0, -1)
    meths.buf_set_extmark(0, ns, 0, 12, { end_col = 15, hl_group = 'ErrorMsg' })
    screen:expect{grid=[[
      ^this is the     {4:tab}                               |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('highlight applies to a full TAB on line with matches #20885', function()
    screen:try_resize(50, 3)
    meths.buf_set_lines(0, 0, -1, true, {'\t-- match1', '        -- match2'})
    funcs.matchadd('Underlined', 'match')
    meths.buf_set_extmark(0, ns, 0, 0, { end_row = 1, end_col = 0, hl_group = 'Visual' })
    meths.buf_set_extmark(0, ns, 1, 0, { end_row = 2, end_col = 0, hl_group = 'Visual' })
    screen:expect{grid=[[
      {18:       ^ -- }{29:match}{18:1}                                 |
      {18:        -- }{29:match}{18:2}                                 |
                                                        |
    ]]}
  end)

  pending('highlight applies to a full TAB in visual block mode', function()
    screen:try_resize(50, 8)
    meths.buf_set_lines(0, 0, -1, true, {'asdf', '\tasdf', '\tasdf', '\tasdf', 'asdf'})
    meths.buf_set_extmark(0, ns, 0, 0, {end_row = 5, end_col = 0, hl_group = 'Underlined'})
    screen:expect([[
      {28:^asdf}                                              |
      {28:        asdf}                                      |
      {28:        asdf}                                      |
      {28:        asdf}                                      |
      {28:asdf}                                              |
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
    ]])
    feed('<C-V>Gll')
    screen:expect([[
      {29:asd}{28:f}                                              |
      {29:   }{28:     asdf}                                      |
      {29:   }{28:     asdf}                                      |
      {29:   }{28:     asdf}                                      |
      {29:as}{28:^df}                                              |
      {1:~                                                 }|
      {1:~                                                 }|
      {24:-- VISUAL BLOCK --}                                |
    ]])
  end)
end)

describe('decorations: inline virtual text', function()
  local screen, ns
  before_each( function()
    clear()
    screen = Screen.new(50, 10)
    screen:attach()
    screen:set_default_attr_ids {
      [1] = {bold=true, foreground=Screen.colors.Blue};
      [2] = {foreground = Screen.colors.Brown};
      [3] = {bold = true, foreground = Screen.colors.SeaGreen};
      [4] = {background = Screen.colors.Red1, foreground = Screen.colors.Gray100};
      [5] = {background = Screen.colors.Red1, bold = true};
      [6] = {foreground = Screen.colors.DarkCyan};
      [7] = {background = Screen.colors.LightGrey};
      [8] = {bold = true};
      [9] = {background = Screen.colors.Plum1};
      [10] = {foreground = Screen.colors.SlateBlue};
      [11] = {blend = 30, background = Screen.colors.Red1};
      [12] = {background = Screen.colors.Yellow};
      [13] = {reverse = true};
      [14] = {foreground = Screen.colors.SlateBlue, background = Screen.colors.LightMagenta};
      [15] = {bold = true, reverse = true};
      [16] = {foreground = Screen.colors.Red};
      [17] = {background = Screen.colors.LightGrey, foreground = Screen.colors.DarkBlue};
      [18] = {background = Screen.colors.LightGrey, foreground = Screen.colors.Red};
      [19] = {background = Screen.colors.Yellow, foreground = Screen.colors.SlateBlue};
      [20] = {background = Screen.colors.LightGrey, foreground = Screen.colors.SlateBlue};
    }

    ns = meths.create_namespace 'test'
  end)


  it('works', function()
    insert(example_text)
    feed 'gg'
    screen:expect{grid=[[
      ^for _,item in ipairs(items) do                    |
          local text, hl_id_cell, count = unpack(item)  |
          if hl_id_cell ~= nil then                     |
              hl_id = hl_id_cell                        |
          end                                           |
          for _ = 1, (count or 1) do                    |
              local cell = line[colpos]                 |
              cell.text = text                          |
              cell.hl_id = hl_id                        |
                                                        |
    ]]}

    meths.buf_set_extmark(0, ns, 1, 14, {virt_text={{': ', 'Special'}, {'string', 'Type'}}, virt_text_pos='inline'})
    screen:expect{grid=[[
      ^for _,item in ipairs(items) do                    |
          local text{10:: }{3:string}, hl_id_cell, count = unpack|
      (item)                                            |
          if hl_id_cell ~= nil then                     |
              hl_id = hl_id_cell                        |
          end                                           |
          for _ = 1, (count or 1) do                    |
              local cell = line[colpos]                 |
              cell.text = text                          |
                                                        |
    ]]}

    screen:try_resize(55, 10)
    screen:expect{grid=[[
      ^for _,item in ipairs(items) do                         |
          local text{10:: }{3:string}, hl_id_cell, count = unpack(item|
      )                                                      |
          if hl_id_cell ~= nil then                          |
              hl_id = hl_id_cell                             |
          end                                                |
          for _ = 1, (count or 1) do                         |
              local cell = line[colpos]                      |
              cell.text = text                               |
                                                             |
    ]]}

    screen:try_resize(56, 10)
    screen:expect{grid=[[
      ^for _,item in ipairs(items) do                          |
          local text{10:: }{3:string}, hl_id_cell, count = unpack(item)|
          if hl_id_cell ~= nil then                           |
              hl_id = hl_id_cell                              |
          end                                                 |
          for _ = 1, (count or 1) do                          |
              local cell = line[colpos]                       |
              cell.text = text                                |
              cell.hl_id = hl_id                              |
                                                              |
    ]]}
  end)

  it('works with empty chunk', function()
    insert(example_text)
    feed 'gg'
    screen:expect{grid=[[
      ^for _,item in ipairs(items) do                    |
          local text, hl_id_cell, count = unpack(item)  |
          if hl_id_cell ~= nil then                     |
              hl_id = hl_id_cell                        |
          end                                           |
          for _ = 1, (count or 1) do                    |
              local cell = line[colpos]                 |
              cell.text = text                          |
              cell.hl_id = hl_id                        |
                                                        |
    ]]}

    meths.buf_set_extmark(0, ns, 0, 5, {virt_text={{''}, {''}}, virt_text_pos='inline'})
    meths.buf_set_extmark(0, ns, 1, 14, {virt_text={{''}, {': ', 'Special'}, {'string', 'Type'}}, virt_text_pos='inline'})
    feed('V')
    screen:expect{grid=[[
      ^f{7:or _,item in ipairs(items) do}                    |
          local text{10:: }{3:string}, hl_id_cell, count = unpack|
      (item)                                            |
          if hl_id_cell ~= nil then                     |
              hl_id = hl_id_cell                        |
          end                                           |
          for _ = 1, (count or 1) do                    |
              local cell = line[colpos]                 |
              cell.text = text                          |
      {8:-- VISUAL LINE --}                                 |
    ]]}

    feed('<Esc>jf,')
    screen:expect{grid=[[
      for _,item in ipairs(items) do                    |
          local text{10:: }{3:string}^, hl_id_cell, count = unpack|
      (item)                                            |
          if hl_id_cell ~= nil then                     |
              hl_id = hl_id_cell                        |
          end                                           |
          for _ = 1, (count or 1) do                    |
              local cell = line[colpos]                 |
              cell.text = text                          |
                                                        |
    ]]}
  end)

  it('cursor positions are correct with multiple inline virtual text', function()
    insert('12345678')
    meths.buf_set_extmark(0, ns, 0, 4,
        { virt_text = { { ' virtual text ', 'Special' } }, virt_text_pos = 'inline' })
    meths.buf_set_extmark(0, ns, 0, 4,
        { virt_text = { { ' virtual text ', 'Special' } }, virt_text_pos = 'inline' })
    feed '^'
    feed '4l'
    screen:expect { grid = [[
      1234{10: virtual text  virtual text }^5678              |
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

  it('adjusts cursor location correctly when inserting around inline virtual text', function()
    insert('12345678')
    feed '$'
    meths.buf_set_extmark(0, ns, 0, 4,
            { virt_text = { { ' virtual text ', 'Special' } }, virt_text_pos = 'inline' })

    screen:expect { grid = [[
      1234{10: virtual text }567^8                            |
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

  it('has correct highlighting with multi-byte characters', function()
    insert('12345678')
    meths.buf_set_extmark(0, ns, 0, 4,
            { virt_text = { { 'múlti-byté chñröcters 修补', 'Special' } }, virt_text_pos = 'inline' })

    screen:expect { grid = [[
      1234{10:múlti-byté chñröcters 修补}567^8                |
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

  it('has correct cursor position when inserting around virtual text', function()
    insert('12345678')
    meths.buf_set_extmark(0, ns, 0, 4,
            { virt_text = { { 'virtual text', 'Special' } }, virt_text_pos = 'inline' })
    feed '^'
    feed '3l'
    feed 'a'
    screen:expect { grid = [[
      1234{10:^virtual text}5678                              |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {8:-- INSERT --}                                      |
      ]]}
    feed '<ESC>'
    screen:expect{grid=[[
      123^4{10:virtual text}5678                              |
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
    feed '^'
    feed '4l'
    feed 'i'
    screen:expect { grid = [[
      1234{10:^virtual text}5678                              |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {8:-- INSERT --}                                      |
      ]]}
  end)

  it('has correct cursor position with virtual text on an empty line', function()
    meths.buf_set_extmark(0, ns, 0, 0,
            { virt_text = { { 'virtual text', 'Special' } }, virt_text_pos = 'inline' })
    screen:expect { grid = [[
      {10:^virtual text}                                      |
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

  it('text is drawn correctly when inserting a wrapping virtual text on an empty line', function()
    feed('o<esc>')
    insert([[aaaaaaa

bbbbbbb]])
    meths.buf_set_extmark(0, ns, 0, 0,
            { virt_text = { { string.rep('X', 51), 'Special' } }, virt_text_pos = 'inline' })
    meths.buf_set_extmark(0, ns, 2, 0,
            { virt_text = { { string.rep('X', 50), 'Special' } }, virt_text_pos = 'inline' })
    feed('gg0')
    screen:expect { grid = [[
      {10:^XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {10:X}                                                 |
      aaaaaaa                                           |
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      bbbbbbb                                           |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
      ]]}

    feed('j')
    screen:expect { grid = [[
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {10:X}                                                 |
      ^aaaaaaa                                           |
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      bbbbbbb                                           |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
      ]]}

    feed('j')
    screen:expect { grid = [[
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {10:X}                                                 |
      aaaaaaa                                           |
      {10:^XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      bbbbbbb                                           |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
      ]]}

    feed('j')
    screen:expect { grid = [[
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {10:X}                                                 |
      aaaaaaa                                           |
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      ^bbbbbbb                                           |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
      ]]}
  end)

  it('cursor position is correct with virtual text attached to hard tabs', function()
    command('set noexpandtab')
    feed('i')
    feed('<TAB>')
    feed('<TAB>')
    feed('test')
    feed('<ESC>')
    meths.buf_set_extmark(0, ns, 0, 1,
            { virt_text = { { 'virtual text', 'Special' } }, virt_text_pos = 'inline' })
    feed('0')
    screen:expect { grid = [[
             ^ {10:virtual text}    test                      |
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

    feed('l')
    screen:expect { grid = [[
              {10:virtual text}   ^ test                      |
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

    feed('l')
    screen:expect { grid = [[
              {10:virtual text}    ^test                      |
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

    feed('l')
    screen:expect { grid = [[
              {10:virtual text}    t^est                      |
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

    feed('l')
    screen:expect { grid = [[
              {10:virtual text}    te^st                      |
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

  it('cursor position is correct with virtual text on an empty line', function()
    command('set linebreak')
    insert('one twoword')
    feed('0')
    meths.buf_set_extmark(0, ns, 0, 3,
            { virt_text = { { ': virtual text', 'Special' } }, virt_text_pos = 'inline' })
    screen:expect { grid = [[
      ^one{10:: virtual text} twoword                         |
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

  it('search highlight is correct', function()
    insert('foo foo foo foo\nfoo foo foo foo')
    feed('gg0')
    meths.buf_set_extmark(0, ns, 0, 9, { virt_text = { { 'AAA', 'Special' } }, virt_text_pos = 'inline' })
    meths.buf_set_extmark(0, ns, 0, 9, { virt_text = { { 'BBB', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'combine' })
    meths.buf_set_extmark(0, ns, 1, 9, { virt_text = { { 'CCC', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'combine' })
    meths.buf_set_extmark(0, ns, 1, 9, { virt_text = { { 'DDD', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'replace' })
    screen:expect { grid = [[
      ^foo foo f{10:AAABBB}oo foo                             |
      foo foo f{10:CCCDDD}oo foo                             |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
      ]]}

    feed('/foo')
    screen:expect { grid = [[
      {12:foo} {13:foo} {12:f}{10:AAA}{19:BBB}{12:oo} {12:foo}                             |
      {12:foo} {12:foo} {12:f}{19:CCC}{10:DDD}{12:oo} {12:foo}                             |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      /foo^                                              |
      ]]}
  end)

  it('visual select highlight is correct', function()
    insert('foo foo foo foo\nfoo foo foo foo')
    feed('gg0')
    meths.buf_set_extmark(0, ns, 0, 8, { virt_text = { { 'AAA', 'Special' } }, virt_text_pos = 'inline' })
    meths.buf_set_extmark(0, ns, 0, 8, { virt_text = { { 'BBB', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'combine' })
    meths.buf_set_extmark(0, ns, 1, 8, { virt_text = { { 'CCC', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'combine' })
    meths.buf_set_extmark(0, ns, 1, 8, { virt_text = { { 'DDD', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'replace' })
    feed('8l')
    screen:expect { grid = [[
      foo foo {10:AAABBB}^foo foo                             |
      foo foo {10:CCCDDD}foo foo                             |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
      ]]}

    feed('<C-V>')
    feed('2hj')
    screen:expect { grid = [[
      foo fo{7:o }{10:AAA}{20:BBB}{7:f}oo foo                             |
      foo fo^o{7: }{20:CCC}{10:DDD}{7:f}oo foo                             |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {8:-- VISUAL BLOCK --}                                |
      ]]}
  end)

  it('cursor position is correct when inserting around a virtual text with right gravity set to false', function()
    insert('foo foo foo foo')
    meths.buf_set_extmark(0, ns, 0, 8,
      { virt_text = { { 'virtual text', 'Special' } }, virt_text_pos = 'inline', right_gravity = false })
    feed('0')
    feed('8l')
    screen:expect { grid = [[
      foo foo {10:virtual text}^foo foo                       |
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

    feed('i')
    screen:expect { grid = [[
      foo foo {10:virtual text}^foo foo                       |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {8:-- INSERT --}                                      |
      ]]}
  end)

  it('cursor position is correct when inserting around virtual texts with both left and right gravity', function()
    insert('foo foo foo foo')
    meths.buf_set_extmark(0, ns, 0, 8, { virt_text = {{ '>>', 'Special' }}, virt_text_pos = 'inline', right_gravity = false })
    meths.buf_set_extmark(0, ns, 0, 8, { virt_text = {{ '<<', 'Special' }}, virt_text_pos = 'inline', right_gravity = true })
    feed('08l')
    screen:expect{ grid = [[
      foo foo {10:>><<}^foo foo                               |
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

    feed('i')
    screen:expect { grid = [[
      foo foo {10:>>^<<}foo foo                               |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {8:-- INSERT --}                                      |
      ]]}
  end)

  it('draws correctly with no wrap multiple virtual text, where one is hidden', function()
    insert('abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz')
    command("set nowrap")
    meths.buf_set_extmark(0, ns, 0, 50,
      { virt_text = { { 'virtual text', 'Special' } }, virt_text_pos = 'inline' })
    meths.buf_set_extmark(0, ns, 0, 2,
      { virt_text = { { 'virtual text', 'Special' } }, virt_text_pos = 'inline' })
    feed('$')
    screen:expect { grid = [[
      opqrstuvwxyzabcdefghijklmnopqrstuvwx{10:virtual text}y^z|
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

  it('draws correctly with no wrap and a long virtual text', function()
    insert('abcdefghi')
    command("set nowrap")
    meths.buf_set_extmark(0, ns, 0, 2,
      { virt_text = { { string.rep('X', 55), 'Special' } }, virt_text_pos = 'inline' })
    feed('$')
    screen:expect { grid = [[
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}cdefgh^i|
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

  it('tabs are the correct length with no wrap following virtual text', function()
    command('set nowrap')
    feed('itest<TAB>a<ESC>')
    meths.buf_set_extmark(0, ns, 0, 0,
      { virt_text = { { string.rep('a', 55), 'Special' } }, virt_text_pos = 'inline' })
    feed('gg$')
    screen:expect { grid = [[
      {10:aaaaaaaaaaaaaaaaaaaaaaaaa}test     ^a               |
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

  it('highlighting does not extend when no wrap is enabled with a long virtual text', function()
    insert('abcdef')
    command("set nowrap")
    meths.buf_set_extmark(0, ns, 0, 3,
      { virt_text = { { string.rep('X', 50), 'Special' } }, virt_text_pos = 'inline' })
    feed('$')
    screen:expect { grid = [[
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}de^f|
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

  it('hidden virtual text does not interfere with Visual highlight', function()
    insert('abcdef')
    command('set nowrap')
    meths.buf_set_extmark(0, ns, 0, 0, { virt_text = { { 'XXX', 'Special' } }, virt_text_pos = 'inline' })
    feed('V2zl')
    screen:expect{grid=[[
      {10:X}{7:abcde}^f                                           |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {8:-- VISUAL LINE --}                                 |
    ]]}
    feed('zl')
    screen:expect{grid=[[
      {7:abcde}^f                                            |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {8:-- VISUAL LINE --}                                 |
    ]]}
    feed('zl')
    screen:expect{grid=[[
      {7:bcde}^f                                             |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {8:-- VISUAL LINE --}                                 |
    ]]}
  end)

  it('highlighting is correct when virtual text wraps with number', function()
    insert([[
    test
    test]])
    command('set number')
    meths.buf_set_extmark(0, ns, 0, 1,
      { virt_text = { { string.rep('X', 55), 'Special' } }, virt_text_pos = 'inline' })
    feed('gg0')
    screen:expect { grid = [[
      {2:  1 }^t{10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {2:    }{10:XXXXXXXXXX}est                                 |
      {2:  2 }test                                          |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
      ]]}
  end)

  it('highlighting is correct when virtual text is proceeded with a match', function()
    insert([[test]])
    meths.buf_set_extmark(0, ns, 0, 2,
      { virt_text = { { 'virtual text', 'Special' } }, virt_text_pos = 'inline' })
    feed('gg0')
    command('match ErrorMsg /e/')
    screen:expect { grid = [[
      ^t{4:e}{10:virtual text}st                                  |
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
    command('match ErrorMsg /s/')
    screen:expect { grid = [[
      ^te{10:virtual text}{4:s}t                                  |
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

  it('smoothscroll works correctly when virtual text wraps', function()
    insert('foobar')
    meths.buf_set_extmark(0, ns, 0, 3,
      { virt_text = { { string.rep('X', 55), 'Special' } }, virt_text_pos = 'inline' })
    command('setlocal smoothscroll')
    screen:expect{grid=[[
      foo{10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {10:XXXXXXXX}ba^r                                       |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
      {1:<<<}{10:XXXXX}ba^r                                       |
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

  it('in diff mode is highlighted correct', function()
    insert([[
    9000
    0009
    0009
    9000
    0009
    ]])
    insert('aaa\tbbb')
    command("set diff")
    meths.buf_set_extmark(0, ns, 0, 1, { virt_text = { { 'test', 'Special' } }, virt_text_pos = 'inline', right_gravity = false })
    meths.buf_set_extmark(0, ns, 5, 0, { virt_text = { { '!', 'Special' } }, virt_text_pos = 'inline' })
    meths.buf_set_extmark(0, ns, 5, 3, { virt_text = { { '' } }, virt_text_pos = 'inline' })
    command("vnew")
    insert([[
    000
    000
    000
    000
    000
    ]])
    insert('aaabbb')
    command("set diff")
    feed('gg0')
    screen:expect { grid = [[
      {9:^000                      }│{5:9}{14:test}{9:000                }|
      {9:000                      }│{9:000}{5:9}{9:                    }|
      {9:000                      }│{9:000}{5:9}{9:                    }|
      {9:000                      }│{5:9}{9:000                    }|
      {9:000                      }│{9:000}{5:9}{9:                    }|
      {9:aaabbb                   }│{14:!}{9:aaa}{5:    }{9:bbb             }|
      {1:~                        }│{1:~                       }|
      {1:~                        }│{1:~                       }|
      {15:[No Name] [+]             }{13:[No Name] [+]           }|
                                                        |
      ]]}
    command('wincmd w | set nowrap')
    feed('zl')
    screen:expect { grid = [[
      {9:000                      }│{14:test}{9:000                 }|
      {9:000                      }│{9:00}{5:9}{9:                     }|
      {9:000                      }│{9:00}{5:9}{9:                     }|
      {9:000                      }│{9:000                     }|
      {9:000                      }│{9:00}{5:9}{9:                     }|
      {9:aaabbb                   }│{9:aaa}{5:    }{9:bb^b              }|
      {1:~                        }│{1:~                       }|
      {1:~                        }│{1:~                       }|
      {13:[No Name] [+]             }{15:[No Name] [+]           }|
                                                        |
      ]]}
  end)

  it('correctly draws when there are multiple overlapping virtual texts on the same line with nowrap', function()
    command('set nowrap')
    insert('a')
    meths.buf_set_extmark(0, ns, 0, 0,
      { virt_text = { { string.rep('a', 55), 'Special' } }, virt_text_pos = 'inline' })
    meths.buf_set_extmark(0, ns, 0, 0,
      { virt_text = { { string.rep('b', 55), 'Special' } }, virt_text_pos = 'inline' })
    feed('$')
    screen:expect { grid = [[
      {10:bbbbbbbbbbbbbbbbbbbbbbbbb}^a                        |
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

  it('correctly draws when overflowing virtual text is followed by tab with no wrap', function()
    command('set nowrap')
    feed('i<TAB>test<ESC>')
    meths.buf_set_extmark(
      0,
      ns,
      0,
      0,
      { virt_text = { { string.rep('a', 60), 'Special' } }, virt_text_pos = 'inline' }
    )
    feed('0')
    screen:expect({
      grid = [[
      {10:aaaaaaaaaaaaaaaaaaaaaa}   ^ test                    |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
      ]],
    })
  end)

  it('does not crash at column 0 when folded in a wide window', function()
    screen:try_resize(82, 5)
    command('hi! CursorLine guibg=NONE guifg=Red gui=NONE')
    command('set cursorline')
    insert([[
      aaaaa
      bbbbb

      ccccc]])
    meths.buf_set_extmark(0, ns, 0, 0, { virt_text = {{'foo'}}, virt_text_pos = 'inline' })
    meths.buf_set_extmark(0, ns, 2, 0, { virt_text = {{'bar'}}, virt_text_pos = 'inline' })
    screen:expect{grid=[[
      fooaaaaa                                                                          |
      bbbbb                                                                             |
      bar                                                                               |
      {16:cccc^c                                                                             }|
                                                                                        |
    ]]}
    command('1,2fold')
    screen:expect{grid=[[
      {17:+--  2 lines: aaaaa·······························································}|
      bar                                                                               |
      {16:cccc^c                                                                             }|
      {1:~                                                                                 }|
                                                                                        |
    ]]}
    feed('2k')
    screen:expect{grid=[[
      {18:^+--  2 lines: aaaaa·······························································}|
      bar                                                                               |
      ccccc                                                                             |
      {1:~                                                                                 }|
                                                                                        |
    ]]}
    command('3,4fold')
    screen:expect{grid=[[
      {18:^+--  2 lines: aaaaa·······························································}|
      {17:+--  2 lines: ccccc·······························································}|
      {1:~                                                                                 }|
      {1:~                                                                                 }|
                                                                                        |
    ]]}
    feed('j')
    screen:expect{grid=[[
      {17:+--  2 lines: aaaaa·······························································}|
      {18:^+--  2 lines: ccccc·······························································}|
      {1:~                                                                                 }|
      {1:~                                                                                 }|
                                                                                        |
    ]]}
  end)

  it('does not crash at right edge of wide window #23848', function()
    screen:try_resize(82, 5)
    meths.buf_set_extmark(0, ns, 0, 0, {virt_text = {{('a'):rep(82)}, {'b'}}, virt_text_pos = 'inline'})
    screen:expect{grid=[[
      ^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      b                                                                                 |
      {1:~                                                                                 }|
      {1:~                                                                                 }|
                                                                                        |
    ]]}
    command('set nowrap')
    screen:expect{grid=[[
      ^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:~                                                                                 }|
      {1:~                                                                                 }|
      {1:~                                                                                 }|
                                                                                        |
    ]]}
    feed('82i0<Esc>0')
    screen:expect{grid=[[
      ^0000000000000000000000000000000000000000000000000000000000000000000000000000000000|
      {1:~                                                                                 }|
      {1:~                                                                                 }|
      {1:~                                                                                 }|
                                                                                        |
    ]]}
    command('set wrap')
    screen:expect{grid=[[
      ^0000000000000000000000000000000000000000000000000000000000000000000000000000000000|
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      b                                                                                 |
      {1:~                                                                                 }|
                                                                                        |
    ]]}
  end)

  it('list "extends" is drawn with only inline virtual text offscreen', function()
    command('set nowrap')
    command('set list')
    command('set listchars+=extends:c')
    meths.buf_set_extmark(0, ns, 0, 0,
      { virt_text = { { 'test', 'Special' } }, virt_text_pos = 'inline' })
    insert(string.rep('a', 50))
    feed('gg0')
    screen:expect { grid = [[
      ^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{1:c}|
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
end)

describe('decorations: virtual lines', function()
  local screen, ns
  before_each(function()
    clear()
    screen = Screen.new(50, 12)
    screen:attach()
    screen:set_default_attr_ids {
      [1] = {bold=true, foreground=Screen.colors.Blue};
      [2] = {foreground = Screen.colors.DarkCyan};
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

  local example_text2 = [[
if (h->n_buckets < new_n_buckets) { // expand
  khkey_t *new_keys = (khkey_t *)krealloc((void *)h->keys, new_n_buckets * sizeof(khkey_t));
  h->keys = new_keys;
  if (kh_is_map && val_size) {
    char *new_vals = krealloc( h->vals_buf, new_n_buckets * val_size);
    h->vals_buf = new_vals;
  }
}]]

  it('works with one line', function()
    insert(example_text2)
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
    -- Cursor should be drawn on the correct line. #22704
    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)                 |
      {3:krealloc}((void *)h->keys, new_n_buckets * sizeof(k|
      hkey_t));                                         |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          ^char *new_vals = {3:krealloc}( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      }                                                 |
                                                        |
    ]]}
  end)

  it('works with text at the beginning of the buffer', function()
    insert(example_text2)
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
    insert(example_text2)
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
    insert(example_text2)
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
    insert(example_text2)
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
    insert(example_text2)
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

  it('does not show twice if end_row or end_col is specified #18622', function()
    insert([[
      aaa
      bbb
      ccc
      ddd]])
    meths.buf_set_extmark(0, ns, 0, 0, {end_row = 2, virt_lines = {{{'VIRT LINE 1', 'NonText'}}}})
    meths.buf_set_extmark(0, ns, 3, 0, {end_col = 2, virt_lines = {{{'VIRT LINE 2', 'NonText'}}}})
    screen:expect{grid=[[
      aaa                                               |
      {1:VIRT LINE 1}                                       |
      bbb                                               |
      ccc                                               |
      dd^d                                               |
      {1:VIRT LINE 2}                                       |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
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
    meths.set_option_value('signcolumn', 'auto:9', {})
  end)

  local example_test3 = [[
l1
l2
l3
l4
l5
]]

  it('can add a single sign (no end row)', function()
    insert(example_test3)
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
    insert(example_test3)
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
    insert(example_test3)
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
    insert(example_test3)
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
    insert(example_test3)
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

    insert(example_test3)
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
    insert(example_test3)
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
    insert(example_test3)
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
    insert(example_test3)
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

    insert(example_test3)
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
    insert(example_test3)
    feed 'gg'

    command('sign define Oldsign text=O3')
    command([[exe 'sign place 42 line=1 name=Oldsign priority=10 buffer=' . bufnr('')]])

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
    meths.set_option_value('signcolumn', 'auto', {})

    screen:expect{grid=[[
      S5^l1                |
      {1:  }l2                |
                          |
    ]]}
  end)

  it('does not overflow with many old signs #23852', function()
    screen:try_resize(20, 3)

    command('set signcolumn:auto:9')
    command('sign define Oldsign text=O3')
    command([[exe 'sign place 01 line=1 name=Oldsign priority=10 buffer=' . bufnr('')]])
    command([[exe 'sign place 02 line=1 name=Oldsign priority=10 buffer=' . bufnr('')]])
    command([[exe 'sign place 03 line=1 name=Oldsign priority=10 buffer=' . bufnr('')]])
    command([[exe 'sign place 04 line=1 name=Oldsign priority=10 buffer=' . bufnr('')]])
    command([[exe 'sign place 05 line=1 name=Oldsign priority=10 buffer=' . bufnr('')]])
    command([[exe 'sign place 06 line=1 name=Oldsign priority=10 buffer=' . bufnr('')]])
    command([[exe 'sign place 07 line=1 name=Oldsign priority=10 buffer=' . bufnr('')]])
    command([[exe 'sign place 08 line=1 name=Oldsign priority=10 buffer=' . bufnr('')]])
    command([[exe 'sign place 09 line=1 name=Oldsign priority=10 buffer=' . bufnr('')]])
    screen:expect{grid=[[
      O3O3O3O3O3O3O3O3O3^  |
      {2:~                   }|
                          |
    ]]}

    meths.buf_set_extmark(0, ns, 0, -1, {sign_text='S1', priority=1})
    screen:expect_unchanged()

    meths.buf_set_extmark(0, ns, 0, -1, {sign_text='S5', priority=200})
    screen:expect{grid=[[
      O3O3O3O3O3O3O3O3S5^  |
      {2:~                   }|
                          |
    ]]}

    assert_alive()
  end)

  it('does not set signcolumn for signs without text', function()
    screen:try_resize(20, 3)
    meths.set_option_value('signcolumn', 'auto', {})
    insert(example_test3)
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
