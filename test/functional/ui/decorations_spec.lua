local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local feed = n.feed
local insert = n.insert
local exec_lua = n.exec_lua
local exec = n.exec
local expect_events = t.expect_events
local api = n.api
local fn = n.fn
local command = n.command
local eq = t.eq
local assert_alive = n.assert_alive
local pcall_err = t.pcall_err

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
      [18] = {bold = true, foreground = Screen.colors.SeaGreen};
      [19] = {bold = true};
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
      { "win", 1000, 1, 0, 6 };
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
      { "win", 1000, 1, 0, 6 };
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
      { "win", 1000, 1, 0, 3 };
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
      {1:~                                       }|*3
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
      {1:~                                       }|*3
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
      {1:~                                       }|*3
                                              |
    ]]}

    -- spell=false with higher priority does disable spell
    local ns = api.nvim_create_namespace "spell"
    local id = api.nvim_buf_set_extmark(0, ns, 0, 0, { priority = 30, end_row = 2, end_col = 23, spell = false })

    screen:expect{grid=[[
      I am well written text.                 |
      i am not capitalized.                   |
      I am a ^speling mistakke.                |
                                              |
      {1:~                                       }|*3
                                              |
    ]]}

    feed "]s"
    screen:expect{grid=[[
      I am well written text.                 |
      i am not capitalized.                   |
      I am a ^speling mistakke.                |
                                              |
      {1:~                                       }|*3
      {17:search hit BOTTOM, continuing at TOP}    |
    ]]}
    command('echo ""')

    -- spell=false with lower priority doesn't disable spell
    api.nvim_buf_set_extmark(0, ns, 0, 0, { id = id, priority = 10, end_row = 2, end_col = 23, spell = false })

    screen:expect{grid=[[
      I am well written text.                 |
      {15:i} am not capitalized.                   |
      I am a {16:^speling} {16:mistakke}.                |
                                              |
      {1:~                                       }|*3
                                              |
    ]]}

    feed "]s"
    screen:expect{grid=[[
      I am well written text.                 |
      {15:i} am not capitalized.                   |
      I am a {16:speling} {16:^mistakke}.                |
                                              |
      {1:~                                       }|*3
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
    } do api.nvim_set_hl(ns1, k, v) end

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

    api.nvim_set_hl_ns(ns1)
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

    api.nvim_buf_set_virtual_text(0, 0, 2, {{'- not red', 'LinkGroup'}}, {})
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

    api.nvim_set_hl(ns1, 'LinkGroup', {fg = 'Blue'})
    api.nvim_set_hl_ns(ns1)

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

    api.nvim_buf_set_virtual_text(0, 0, 2, {{'- not red', 'LinkGroup'}}, {})
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

    api.nvim_set_hl(ns1, 'LinkGroup', {fg = 'Blue', default=true})
    api.nvim_set_hl_ns(ns1)
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

  it('virtual text works with wrapped lines', function()
    insert(mulholland)
    feed('ggJj3JjJ')
    setup_provider [[
      local hl = api.nvim_get_hl_id_by_name "ErrorMsg"
      local test_ns = api.nvim_create_namespace "mulholland"
      function on_do(event, ...)
        if event == "line" then
          local win, buf, line = ...
          api.nvim_buf_set_extmark(buf, test_ns, line, 0, {
            virt_text = {{string.rep('/', line+1), 'ErrorMsg'}};
            virt_text_pos='eol';
            ephemeral = true;
          })
          api.nvim_buf_set_extmark(buf, test_ns, line, 6, {
            virt_text = {{string.rep('*', line+1), 'ErrorMsg'}};
            virt_text_pos='overlay';
            ephemeral = true;
          })
          api.nvim_buf_set_extmark(buf, test_ns, line, 39, {
            virt_text = {{string.rep('!', line+1), 'ErrorMsg'}};
            virt_text_win_col=20;
            ephemeral = true;
          })
          api.nvim_buf_set_extmark(buf, test_ns, line, 40, {
            virt_text = {{string.rep('?', line+1), 'ErrorMsg'}};
            virt_text_win_col=10;
            ephemeral = true;
          })
          api.nvim_buf_set_extmark(buf, test_ns, line, 40, {
            virt_text = {{string.rep(';', line+1), 'ErrorMsg'}};
            virt_text_pos='overlay';
            ephemeral = true;
          })
          api.nvim_buf_set_extmark(buf, test_ns, line, 40, {
            virt_text = {{'+'}, {string.rep(' ', line+1), 'ErrorMsg'}};
            virt_text_pos='right_align';
            ephemeral = true;
          })
        end
      end
    ]]

    screen:expect{grid=[[
      // jus{2:*} to see if th{2:!}re was an accident |
      {2:;}n Mulholl{2:?}nd Drive {2:/}                 +{2: }|
      try_st{2:**}t(); bufref_{2:!!}save_buf; switch_b|
      {2:;;}fer(&sav{2:??}buf, buf); {2://}            +{2:  }|
      posp ={2:***}tmark(mark,{2:!!!}lse);^ restore_buf|
      {2:;;;}(&save_{2:???});  {2:///}                +{2:   }|
      {1:~                                       }|
                                              |
    ]]}
    command('setlocal breakindent breakindentopt=shift:2')
    screen:expect{grid=[[
      // jus{2:*} to see if th{2:!}re was an accident |
        {2:;}n Mulho{2:?}land Drive {2:/}               +{2: }|
      try_st{2:**}t(); bufref_{2:!!}save_buf; switch_b|
        {2:;;}fer(&s{2:??}e_buf, buf); {2://}          +{2:  }|
      posp ={2:***}tmark(mark,{2:!!!}lse);^ restore_buf|
        {2:;;;}(&sav{2:???}uf);  {2:///}              +{2:   }|
      {1:~                                       }|
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
      local function on_do(kind, winid, bufnr, topline, botline)
        if kind == 'win' then
          if topline < 100 and botline > 100 then
            api.nvim_buf_set_extmark(bufnr, ns1, 99, -1, { sign_text = 'X' })
          else
            api.nvim_buf_clear_namespace(bufnr, ns1, 0, -1)
          end
        end
      end
    ]])
    command([[autocmd CursorMoved * call line('w$')]])
    api.nvim_win_set_cursor(0, {100, 0})
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
    api.nvim_win_set_cursor(0, {1, 0})
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

  it('does allow removing extmarks during on_line callbacks', function()
    exec_lua([[
      eok = true
    ]])
    setup_provider([[
      local function on_do(kind, winid, bufnr, topline, botline)
        if kind == 'line' then
          api.nvim_buf_set_extmark(bufnr, ns1, 1, -1, { sign_text = 'X' })
          eok = pcall(api.nvim_buf_clear_namespace, bufnr, ns1, 0, -1)
        end
      end
    ]])
    exec_lua([[
      assert(eok == true)
    ]])
  end)

  it('on_line is invoked only for buffer lines', function()
    insert(mulholland)
    command('vnew')
    insert(mulholland)
    feed('dd')
    command('windo diffthis')

    exec_lua([[
      out_of_bound = false
    ]])
    setup_provider([[
      local function on_do(kind, _, bufnr, row)
        if kind == 'line' then
          if not api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] then
            out_of_bound = true
          end
        end
      end
    ]])

    feed('<C-e>')

    exec_lua([[
      assert(out_of_bound == false)
    ]])
  end)

  it('errors gracefully', function()
    insert(mulholland)

    setup_provider [[
    function on_do(...)
      error "Foo"
    end
    ]]

    screen:expect{grid=[[
      {2:Error in decoration provider ns1.start:} |
      {2:Error executing lua: [string "<nvim>"]:4}|
      {2:: Foo}                                   |
      {2:stack traceback:}                        |
      {2:        [C]: in function 'error'}        |
      {2:        [string "<nvim>"]:4: in function}|
      {2: <[string "<nvim>"]:3>}                  |
      {18:Press ENTER or type command to continue}^ |
    ]]}
  end)

  it('can add new providers during redraw #26652', function()
    setup_provider [[
    local ns = api.nvim_create_namespace('test_no_add')
    function on_do(...)
      api.nvim_set_decoration_provider(ns, {})
    end
    ]]

    n.assert_alive()
  end)

  it('is not invoked repeatedly in Visual mode with vim.schedule() #20235', function()
    exec_lua([[_G.cnt = 0]])
    setup_provider([[
      function on_do(event, ...)
        if event == 'win' then
          vim.schedule(function() end)
          _G.cnt = _G.cnt + 1
        end
      end
    ]])
    feed('v')
    screen:expect([[
      ^                                        |
      {1:~                                       }|*6
      {19:-- VISUAL --}                            |
    ]])
    eq(2, exec_lua([[return _G.cnt]]))
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
      [26] = {background = Screen.colors.DarkGrey, foreground = Screen.colors.LightGrey};
      [27] = {background = Screen.colors.LightGrey, foreground = Screen.colors.Black};
      [28] = {underline = true, foreground = Screen.colors.SlateBlue};
      [29] = {foreground = Screen.colors.SlateBlue, background = Screen.colors.LightGrey, underline = true};
      [30] = {foreground = Screen.colors.DarkCyan, background = Screen.colors.LightGrey, underline = true};
      [31] = {underline = true, foreground = Screen.colors.DarkCyan};
      [32] = {underline = true};
      [33] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGrey};
      [34] = {background = Screen.colors.Yellow};
      [35] = {background = Screen.colors.Yellow, bold = true, foreground = Screen.colors.Blue};
      [36] = {foreground = Screen.colors.Blue1, bold = true, background = Screen.colors.Red};
      [37] = {background = Screen.colors.WebGray, foreground = Screen.colors.DarkBlue};
      [38] = {background = Screen.colors.LightBlue};
      [39] = {foreground = Screen.colors.Blue1, background = Screen.colors.LightCyan1, bold = true};
      [40] = {reverse = true};
      [41] = {bold = true, reverse = true};
      [42] = {undercurl = true, special = Screen.colors.Red};
      [43] = {background = Screen.colors.Yellow, undercurl = true, special = Screen.colors.Red};
      [44] = {background = Screen.colors.LightMagenta};
    }

    ns = api.nvim_create_namespace 'test'
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
      {1:~                                                 }|*2
                                                        |
    ]])
    api.nvim_buf_set_extmark(0, ns, 4, 0, { virt_text={{''}}, virt_text_pos='eol'})
    screen:expect_unchanged()
  end)

  it('can have virtual text of overlay position', function()
    insert(example_text)
    feed 'gg'

    for i = 1,9 do
      api.nvim_buf_set_extmark(0, ns, i, 0, { virt_text={{'|', 'LineNr'}}, virt_text_pos='overlay'})
      if i == 3 or (i >= 6 and i <= 9) then
        api.nvim_buf_set_extmark(0, ns, i, 4, { virt_text={{'|', 'NonText'}}, virt_text_pos='overlay'})
      end
    end
    api.nvim_buf_set_extmark(0, ns, 9, 10, { virt_text={{'foo'}, {'bar', 'MoreMsg'}, {'!!', 'ErrorMsg'}}, virt_text_pos='overlay'})

    -- can "float" beyond end of line
    api.nvim_buf_set_extmark(0, ns, 5, 28, { virt_text={{'loopy', 'ErrorMsg'}}, virt_text_pos='overlay'})
    -- bound check: right edge of window
    api.nvim_buf_set_extmark(0, ns, 2, 26, { virt_text={{'bork bork bork'}, {(' bork'):rep(10), 'ErrorMsg'}}, virt_text_pos='overlay'})
    -- empty virt_text should not change anything
    api.nvim_buf_set_extmark(0, ns, 6, 16, { virt_text={{''}}, virt_text_pos='overlay'})

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
      {1:~                                                 }|*2
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
      {1:~                     }|*2
                            |
    ]]}

    -- truncating in the middle of a char leaves a space
    api.nvim_buf_set_lines(0, 0, 1, true, {'for _,item in ipairs(items) do  -- 古古古'})
    api.nvim_buf_set_lines(0, 10, 12, true, {'    end  -- ??????????', 'end  -- ?古古古古?古古'})
    api.nvim_buf_set_extmark(0, ns, 0, 35, { virt_text={{'A', 'ErrorMsg'}, {'AA'}}, virt_text_pos='overlay'})
    api.nvim_buf_set_extmark(0, ns, 10, 19, { virt_text={{'口口口', 'ErrorMsg'}}, virt_text_pos='overlay'})
    api.nvim_buf_set_extmark(0, ns, 11, 21, { virt_text={{'口口口', 'ErrorMsg'}}, virt_text_pos='overlay'})
    api.nvim_buf_set_extmark(0, ns, 11, 8, { virt_text={{'口口', 'ErrorMsg'}}, virt_text_pos='overlay'})
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
      {1:~                     }|*2
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

    api.nvim_buf_clear_namespace(0, ns, 0, -1)
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

  it('overlay virtual text works with wrapped lines #25158', function()
    screen:try_resize(50, 6)
    insert(('ab'):rep(100))
    for i = 0, 9 do
      api.nvim_buf_set_extmark(0, ns, 0, 42 + i, { virt_text={{tostring(i), 'ErrorMsg'}}, virt_text_pos='overlay'})
      api.nvim_buf_set_extmark(0, ns, 0, 91 + i, { virt_text={{tostring(i), 'ErrorMsg'}}, virt_text_pos='overlay', virt_text_hide=true})
    end
    screen:expect{grid=[[
      ababababababababababababababababababababab{4:01234567}|
      {4:89}abababababababababababababababababababa{4:012345678}|
      {4:9}babababababababababababababababababababababababab|
      ababababababababababababababababababababababababa^b|
      {1:~                                                 }|
                                                        |
    ]]}

    command('set showbreak=++')
    screen:expect{grid=[[
      ababababababababababababababababababababab{4:01234567}|
      {1:++}{4:89}abababababababababababababababababababa{4:0123456}|
      {1:++}{4:789}babababababababababababababababababababababab|
      {1:++}abababababababababababababababababababababababab|
      {1:++}ababa^b                                          |
                                                        |
    ]]}

    feed('2gkvg0')
    screen:expect{grid=[[
      ababababababababababababababababababababab{4:01234567}|
      {1:++}{4:89}abababababababababababababababababababa{4:0123456}|
      {1:++}^a{27:babab}ababababababababababababababababababababab|
      {1:++}abababababababababababababababababababababababab|
      {1:++}ababab                                          |
      {24:-- VISUAL --}                                      |
    ]]}

    feed('o')
    screen:expect{grid=[[
      ababababababababababababababababababababab{4:01234567}|
      {1:++}{4:89}abababababababababababababababababababa{4:0123456}|
      {1:++}{27:ababa}^bababababababababababababababababababababab|
      {1:++}abababababababababababababababababababababababab|
      {1:++}ababab                                          |
      {24:-- VISUAL --}                                      |
    ]]}

    feed('gk')
    screen:expect{grid=[[
      ababababababababababababababababababababab{4:01234567}|
      {1:++}{4:89}aba^b{27:ababababababababababababababababababababab}|
      {1:++}{27:a}{4:89}babababababababababababababababababababababab|
      {1:++}abababababababababababababababababababababababab|
      {1:++}ababab                                          |
      {24:-- VISUAL --}                                      |
    ]]}

    feed('o')
    screen:expect{grid=[[
      ababababababababababababababababababababab{4:01234567}|
      {1:++}{4:89}aba{27:bababababababababababababababababababababab}|
      {1:++}^a{4:89}babababababababababababababababababababababab|
      {1:++}abababababababababababababababababababababababab|
      {1:++}ababab                                          |
      {24:-- VISUAL --}                                      |
    ]]}

    feed('<Esc>$')
    command('set number showbreak=')
    screen:expect{grid=[[
      {2:  1 }ababababababababababababababababababababab{4:0123}|
      {2:    }{4:456789}abababababababababababababababababababa{4:0}|
      {2:    }{4:123456789}babababababababababababababababababab|
      {2:    }ababababababababababababababababababababababab|
      {2:    }abababababababa^b                              |
                                                        |
    ]]}

    command('set cpoptions+=n')
    screen:expect{grid=[[
      {2:  1 }ababababababababababababababababababababab{4:0123}|
      {4:456789}abababababababababababababababababababa{4:01234}|
      {4:56789}babababababababababababababababababababababab|
      ababababababababababababababababababababababababab|
      aba^b                                              |
                                                        |
    ]]}

    feed('0g$hi<Tab>')
    screen:expect{grid=[[
      {2:  1 }ababababababababababababababababababababab{4:01}  |
        {4:^23456789}abababababababababababababababababababa{4:0}|
      {4:123456789}babababababababababababababababababababab|
      ababababababababababababababababababababababababab|
      abababab                                          |
      {24:-- INSERT --}                                      |
    ]]}
  end)

  it('virt_text_hide hides overlay virtual text when extmark is off-screen', function()
    screen:try_resize(50, 3)
    command('set nowrap')
    api.nvim_buf_set_lines(0, 0, -1, true, {'-- ' .. ('…'):rep(57)})
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text={{'?????', 'ErrorMsg'}}, virt_text_pos='overlay', virt_text_hide=true})
    api.nvim_buf_set_extmark(0, ns, 0, 123, { virt_text={{'!!!!!', 'ErrorMsg'}}, virt_text_pos='overlay', virt_text_hide=true})
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
    api.nvim_buf_set_lines(0, 0, -1, true, {'\t\tline 1'})
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = {{'AA', 'Search'}}, virt_text_pos = 'overlay', hl_mode = 'combine' })
    api.nvim_buf_set_extmark(0, ns, 0, 1, { virt_text = {{'BB', 'Search'}}, virt_text_pos = 'overlay', hl_mode = 'combine' })
    api.nvim_buf_set_extmark(0, ns, 0, 2, { virt_text = {{'CC', 'Search'}}, virt_text_pos = 'overlay', hl_mode = 'combine' })
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
      {1:~                                                 }|*2
                                                        |
    ]]}

    command 'hi Blendy guibg=Red blend=30'
    command 'hi! Visual guifg=NONE guibg=LightGrey'
    api.nvim_buf_set_extmark(0, ns, 1, 5, { virt_text={{'blendy text - here', 'Blendy'}}, virt_text_pos='overlay', hl_mode='blend'})
    api.nvim_buf_set_extmark(0, ns, 2, 5, { virt_text={{'combining color', 'Blendy'}}, virt_text_pos='overlay', hl_mode='combine'})
    api.nvim_buf_set_extmark(0, ns, 3, 5, { virt_text={{'replacing color', 'Blendy'}}, virt_text_pos='overlay', hl_mode='replace'})

    api.nvim_buf_set_extmark(0, ns, 4, 5, { virt_text={{'blendy text - here', 'Blendy'}}, virt_text_pos='overlay', hl_mode='blend', virt_text_hide=true})
    api.nvim_buf_set_extmark(0, ns, 5, 5, { virt_text={{'combining color', 'Blendy'}}, virt_text_pos='overlay', hl_mode='combine', virt_text_hide=true})
    api.nvim_buf_set_extmark(0, ns, 6, 5, { virt_text={{'replacing color', 'Blendy'}}, virt_text_pos='overlay', hl_mode='replace', virt_text_hide=true})

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
      {1:~                                                 }|*2
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
      {1:~                                                 }|*2
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
      {1:~                                                 }|*2
      {24:-- VISUAL LINE --}                                 |
    ]]}
  end)

  it('can have virtual text of right_align and fixed win_col position', function()
    insert(example_text)
    feed 'gg'
    api.nvim_buf_set_extmark(0, ns, 1, 0, { virt_text={{'Very', 'ErrorMsg'}}, virt_text_win_col=31, hl_mode='blend'})
    api.nvim_buf_set_extmark(0, ns, 1, 0, { virt_text={{'VERY', 'ErrorMsg'}}, virt_text_pos='right_align', hl_mode='blend'})
    api.nvim_buf_set_extmark(0, ns, 2, 10, { virt_text={{'Much', 'ErrorMsg'}}, virt_text_win_col=31, hl_mode='blend'})
    api.nvim_buf_set_extmark(0, ns, 2, 10, { virt_text={{'MUCH', 'ErrorMsg'}}, virt_text_pos='right_align', hl_mode='blend'})
    api.nvim_buf_set_extmark(0, ns, 3, 14, { virt_text={{'Error', 'ErrorMsg'}}, virt_text_win_col=31, hl_mode='blend'})
    api.nvim_buf_set_extmark(0, ns, 3, 14, { virt_text={{'ERROR', 'ErrorMsg'}}, virt_text_pos='right_align', hl_mode='blend'})
    api.nvim_buf_set_extmark(0, ns, 7, 21, { virt_text={{'-', 'NonText'}}, virt_text_win_col=4, hl_mode='blend'})
    api.nvim_buf_set_extmark(0, ns, 7, 21, { virt_text={{'-', 'NonText'}}, virt_text_pos='right_align', hl_mode='blend'})
    -- empty virt_text should not change anything
    api.nvim_buf_set_extmark(0, ns, 8, 0, { virt_text={{''}}, virt_text_win_col=14, hl_mode='blend'})
    api.nvim_buf_set_extmark(0, ns, 8, 0, { virt_text={{''}}, virt_text_pos='right_align', hl_mode='blend'})

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
      {1:~                                                 }|*2
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
      {1:~                                                 }|*2
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

    api.nvim_buf_set_extmark(0, ns, 4, 50, { virt_text={{'EOL', 'NonText'}} })
    screen:expect{grid=[[
      for _,item in ipairs(items) do                    |
          local text, hl_id_cell, cou{4:Very} unpack(ite{4:VERY}|
          if                                            |
      hl_id_cell ~= nil then         {4:Much}           {4:MUCH}|
              --^ -- -- -- -- -- -- --{4:Error}- -- hl_i{4:ERROR}|
      l_id_cell {1:EOL}                                     |
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
      = hl_id_cell {1:EOL}               {4:Error}         {4:ERROR}|
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

    command 'set number'
    screen:expect{grid=[[
      {2:  1 }for _,item in ipairs(items) do                |
      {2:  2 }    local text, hl_id_cell, cou{4:Very} unpack{4:VERY}|
      {2:    }m)                                            |
      {2:  3 }    if                                        |
      {2:  4 }hl_id_cell ~= nil then         {4:Much}       {4:MUCH}|
      {2:  5 }        --^ -- -- -- -- -- -- -- -- -- -- -- hl|
      {2:    }_id = hl_id_cell {1:EOL}           {4:Error}     {4:ERROR}|
      {2:  6 }    end                                       |
      {2:  7 }    for _ = 1, (count or 1) do                |
      {2:  8 }        local cell = line[colpos]             |
      {2:  9 }    {1:-}   cell.text = text                     {1:-}|
      {2: 10 }        cell.hl_id = hl_id                    |
      {2: 11 }        colpos = colpos+1                     |
      {2: 12 }    end                                       |
                                                        |
    ]]}

    command 'set cpoptions+=n'
    screen:expect{grid=[[
      {2:  1 }for _,item in ipairs(items) do                |
      {2:  2 }    local text, hl_id_cell, cou{4:Very} unpack{4:VERY}|
      m)                                                |
      {2:  3 }    if                                        |
      {2:  4 }hl_id_cell ~= nil then         {4:Much}       {4:MUCH}|
      {2:  5 }        --^ -- -- -- -- -- -- -- -- -- -- -- hl|
      _id = hl_id_cell {1:EOL}           {4:Error}         {4:ERROR}|
      {2:  6 }    end                                       |
      {2:  7 }    for _ = 1, (count or 1) do                |
      {2:  8 }        local cell = line[colpos]             |
      {2:  9 }    {1:-}   cell.text = text                     {1:-}|
      {2: 10 }        cell.hl_id = hl_id                    |
      {2: 11 }        colpos = colpos+1                     |
      {2: 12 }    end                                       |
                                                        |
    ]]}

    command 'set cpoptions-=n nowrap'
    screen:expect{grid=[[
      {2:  1 }for _,item in ipairs(items) do                |
      {2:  2 }    local text, hl_id_cell, cou{4:Very} unpack{4:VERY}|
      {2:  3 }    if                                        |
      {2:  4 }hl_id_cell ~= nil then         {4:Much}       {4:MUCH}|
      {2:  5 }        --^ -- -- -- -- -- -- --{4:Error}- -- {4:ERROR}|
      {2:  6 }    end                                       |
      {2:  7 }    for _ = 1, (count or 1) do                |
      {2:  8 }        local cell = line[colpos]             |
      {2:  9 }    {1:-}   cell.text = text                     {1:-}|
      {2: 10 }        cell.hl_id = hl_id                    |
      {2: 11 }        colpos = colpos+1                     |
      {2: 12 }    end                                       |
      {2: 13 }end                                           |
      {1:~                                                 }|
                                                        |
    ]]}

    feed '12zl'
    screen:expect{grid=[[
      {2:  1 }n ipairs(items) do                            |
      {2:  2 }xt, hl_id_cell, count = unpack({4:Very})      {4:VERY}|
      {2:  3 }                                              |
      {2:  4 }= nil then                     {4:Much}       {4:MUCH}|
      {2:  5 }^- -- -- -- -- -- -- -- -- -- --{4:Error}d = h{4:ERROR}|
      {2:  6 }                                              |
      {2:  7 }1, (count or 1) do                            |
      {2:  8 }l cell = line[colpos]                         |
      {2:  9 }.tex{1:-} = text                                 {1:-}|
      {2: 10 }.hl_id = hl_id                                |
      {2: 11 }os = colpos+1                                 |
      {2: 12 }                                              |
      {2: 13 }                                              |
      {1:~                                                 }|
                                                        |
    ]]}

    feed('fhi<Tab>')
    screen:expect{grid=[[
      {2:  1 }n ipairs(items) do                            |
      {2:  2 }xt, hl_id_cell, count = unpack({4:Very})      {4:VERY}|
      {2:  3 }                                              |
      {2:  4 }= nil then                     {4:Much}       {4:MUCH}|
      {2:  5 }- -- -- -- -- -- -- -- -- -- --{4:Error}^hl_id{4:ERROR}|
      {2:  6 }                                              |
      {2:  7 }1, (count or 1) do                            |
      {2:  8 }l cell = line[colpos]                         |
      {2:  9 }.tex{1:-} = text                                 {1:-}|
      {2: 10 }.hl_id = hl_id                                |
      {2: 11 }os = colpos+1                                 |
      {2: 12 }                                              |
      {2: 13 }                                              |
      {1:~                                                 }|
      {24:-- INSERT --}                                      |
    ]]}

    feed('<Esc>0')
    screen:expect{grid=[[
      {2:  1 }for _,item in ipairs(items) do                |
      {2:  2 }    local text, hl_id_cell, cou{4:Very} unpack{4:VERY}|
      {2:  3 }    if                                        |
      {2:  4 }hl_id_cell ~= nil then         {4:Much}       {4:MUCH}|
      {2:  5 }^        -- -- -- -- -- -- -- --{4:Error}- -- {4:ERROR}|
      {2:  6 }    end                                       |
      {2:  7 }    for _ = 1, (count or 1) do                |
      {2:  8 }        local cell = line[colpos]             |
      {2:  9 }    {1:-}   cell.text = text                     {1:-}|
      {2: 10 }        cell.hl_id = hl_id                    |
      {2: 11 }        colpos = colpos+1                     |
      {2: 12 }    end                                       |
      {2: 13 }end                                           |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('virtual text win_col out of window does not break display #25645', function()
    screen:try_resize(51, 6)
    command('vnew')
    api.nvim_buf_set_lines(0, 0, -1, false, { string.rep('a', 50) })
    screen:expect{grid=[[
      ^aaaaaaaaaaaaaaaaaaaaaaaaa│                         |
      aaaaaaaaaaaaaaaaaaaaaaaaa│{1:~                        }|
      {1:~                        }│{1:~                        }|*2
      {41:[No Name] [+]             }{40:[No Name]                }|
                                                         |
    ]]}
    local extmark_opts = { virt_text_win_col = 35, virt_text = { { ' ', 'Comment' } } }
    api.nvim_buf_set_extmark(0, ns, 0, 0, extmark_opts)
    screen:expect_unchanged()
    assert_alive()
  end)

  it('can have virtual text on folded line', function()
    insert([[
      11111
      22222
      33333]])
    command('1,2fold')
    screen:try_resize(50, 3)
    feed('zb')
    -- XXX: the behavior of overlay virtual text at non-zero column is strange:
    -- 1. With 'wrap' it is never shown.
    -- 2. With 'nowrap' it is shown only if the extmark is hidden before leftcol.
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = {{'AA', 'Underlined'}}, hl_mode = 'combine', virt_text_pos = 'overlay' })
    api.nvim_buf_set_extmark(0, ns, 0, 5, { virt_text = {{'BB', 'Underlined'}}, hl_mode = 'combine', virt_text_win_col = 10 })
    api.nvim_buf_set_extmark(0, ns, 0, 2, { virt_text = {{'CC', 'Underlined'}}, hl_mode = 'combine', virt_text_pos = 'right_align' })
    screen:expect{grid=[[
      {29:AA}{33:-  2 lin}{29:BB}{33:: 11111·····························}{29:CC}|
      3333^3                                             |
                                                        |
    ]]}
    command('set nowrap')
    screen:expect_unchanged()
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

  it('virtual text works below diff filler lines', function()
    screen:try_resize(53, 8)
    insert([[
      aaaaa
      bbbbb
      ccccc
      ddddd
      eeeee]])
    command('rightbelow vnew')
    insert([[
      bbbbb
      ccccc
      ddddd
      eeeee]])
    command('windo diffthis')
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = {{'AA', 'Underlined'}}, virt_text_pos = 'overlay' })
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = {{'BB', 'Underlined'}}, virt_text_win_col = 10 })
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = {{'CC', 'Underlined'}}, virt_text_pos = 'right_align' })
    screen:expect{grid=[[
      {37:  }{38:aaaaa                   }│{37:  }{39:------------------------}|
      {37:  }bbbbb                   │{37:  }{28:AA}bbb     {28:BB}          {28:CC}|
      {37:  }ccccc                   │{37:  }ccccc                   |
      {37:  }ddddd                   │{37:  }ddddd                   |
      {37:  }eeeee                   │{37:  }eeee^e                   |
      {1:~                         }│{1:~                         }|
      {40:[No Name] [+]              }{41:[No Name] [+]             }|
                                                           |
    ]]}
    command('windo set wrap')
    screen:expect_unchanged()
  end)

  it('can have virtual text which combines foreground and background groups', function()
    screen:try_resize(20, 5)

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

    insert('##')
    local vt = {
      {'a', {'BgOne', 'FgEin'}};
      {'b', {'BgOne', 'FgZwei'}};
      {'c', {'BgTwo', 'FgEin'}};
      {'d', {'BgTwo', 'FgZwei'}};
      {'X', {'BgTwo', 'FgZwei', 'VeryBold'}};
    }
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = vt, virt_text_pos = 'eol' })
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = vt, virt_text_pos = 'right_align' })
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = vt, virt_text_pos = 'inline' })
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_lines = { vt, vt } })
    screen:expect{grid=[[
      {2:a}{3:b}{4:c}{5:d}{6:X}#^# {2:a}{3:b}{4:c}{5:d}{6:X}  {2:a}{3:b}{4:c}{5:d}{6:X}|
      {2:a}{3:b}{4:c}{5:d}{6:X}               |*2
      {1:~                   }|
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
      {1:~                                                 }|*13
                                                        |
    ]]}

    exec_lua [[
      vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
      vim.cmd("bdelete")
    ]]
    screen:expect{grid=[[
      ^                                                  |
      {1:~                                                 }|*13
                                                        |
    ]]}
    assert_alive()
  end)

  it('conceal with conceal char #19007', function()
    screen:try_resize(50, 5)
    insert('foo\n')
    api.nvim_buf_set_extmark(0, ns, 0, 0, {end_col=0, end_row=2, conceal='X'})
    command('set conceallevel=2')
    screen:expect([[
      {26:X}                                                 |
      ^                                                  |
      {1:~                                                 }|*2
                                                        |
    ]])
    command('set conceallevel=1')
    screen:expect_unchanged()

    eq("conceal char has to be printable", pcall_err(api.nvim_buf_set_extmark, 0, ns, 0, 0, {end_col=0, end_row=2, conceal='\255'}))
  end)

  it('conceal with composed conceal char', function()
    screen:try_resize(50, 5)
    insert('foo\n')
    api.nvim_buf_set_extmark(0, ns, 0, 0, {end_col=0, end_row=2, conceal='ẍ̲'})
    command('set conceallevel=2')
    screen:expect([[
      {26:ẍ̲}                                                 |
      ^                                                  |
      {1:~                                                 }|*2
                                                        |
    ]])
    command('set conceallevel=1')
    screen:expect_unchanged()

    -- this is rare, but could happen. Save at least the first codepoint
    api.nvim__invalidate_glyph_cache()
    screen:expect{grid=[[
      {26:x}                                                 |
      ^                                                  |
      {1:~                                                 }|*2
                                                        |
    ]]}
  end)

  it('conceal without conceal char #24782', function()
    screen:try_resize(50, 5)
    insert('foobar\n')
    api.nvim_buf_set_extmark(0, ns, 0, 0, {end_col=3, conceal=''})
    command('set listchars=conceal:?')
    command('let &conceallevel=1')
    screen:expect([[
      {26:?}bar                                              |
      ^                                                  |
      {1:~                                                 }|*2
                                                        |
    ]])
    command('let &conceallevel=2')
    screen:expect([[
      bar                                               |
      ^                                                  |
      {1:~                                                 }|*2
                                                        |
    ]])
  end)

  it('conceal works just before truncated double-width char #21486', function()
    screen:try_resize(40, 4)
    api.nvim_buf_set_lines(0, 0, -1, true, {'', ('a'):rep(37) .. '<>古'})
    api.nvim_buf_set_extmark(0, ns, 1, 37, {end_col=39, conceal=''})
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

  it('redraws properly when adding/removing conceal on non-current line', function()
    screen:try_resize(50, 5)
    api.nvim_buf_set_lines(0, 0, -1, true, {'abcd', 'efgh','ijkl', 'mnop'})
    command('setlocal conceallevel=2')
    screen:expect{grid=[[
      ^abcd                                              |
      efgh                                              |
      ijkl                                              |
      mnop                                              |
                                                        |
    ]]}
    api.nvim_buf_set_extmark(0, ns, 2, 1, {end_col=3, conceal=''})
    screen:expect{grid=[[
      ^abcd                                              |
      efgh                                              |
      il                                                |
      mnop                                              |
                                                        |
    ]]}
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    screen:expect{grid=[[
      ^abcd                                              |
      efgh                                              |
      ijkl                                              |
      mnop                                              |
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
      vim.uv.sleep(10)
      feed 'j'
    end

    screen:expect{grid=[[
      {44: }                                                 |
      XXX                                               |*2
      ^XXX HELLO                                         |
      XXX                                               |*7
      {1:~                                                 }|*3
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

    api.nvim_buf_set_extmark(0, ns, 0, 0, { end_col = 9, hl_group = 'TestUL', priority = 20 })
    api.nvim_buf_set_extmark(0, ns, 0, 3, { end_col = 6, hl_group = 'TestUC', priority = 30 })
    screen:expect([[
      {1:aaa}{4:bbb}{1:aa^a}                                         |
      {0:~                                                 }|
                                                        |
    ]])
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_extmark(0, ns, 0, 0, { end_col = 9, hl_group = 'TestUC', priority = 20 })
    api.nvim_buf_set_extmark(0, ns, 0, 3, { end_col = 6, hl_group = 'TestUL', priority = 30 })
    screen:expect([[
      {2:aaa}{3:bbb}{2:aa^a}                                         |
      {0:~                                                 }|
                                                        |
    ]])
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_extmark(0, ns, 0, 0, { end_col = 9, hl_group = 'TestUL', priority = 30 })
    api.nvim_buf_set_extmark(0, ns, 0, 3, { end_col = 6, hl_group = 'TestUC', priority = 20 })
    screen:expect([[
      {1:aaa}{3:bbb}{1:aa^a}                                         |
      {0:~                                                 }|
                                                        |
    ]])
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_extmark(0, ns, 0, 0, { end_col = 9, hl_group = 'TestUC', priority = 30 })
    api.nvim_buf_set_extmark(0, ns, 0, 3, { end_col = 6, hl_group = 'TestUL', priority = 20 })
    screen:expect([[
      {2:aaa}{4:bbb}{2:aa^a}                                         |
      {0:~                                                 }|
                                                        |
    ]])

    -- When only one highlight group has an underline attribute, it should always take effect.
    for _, d in ipairs({-5, 5}) do
      api.nvim_buf_clear_namespace(0, ns, 0, -1)
      screen:expect([[
        aaabbbaa^a                                         |
        {0:~                                                 }|
                                                          |
      ]])
      api.nvim_buf_set_extmark(0, ns, 0, 0, { end_col = 9, hl_group = 'TestUL', priority = 25 + d })
      api.nvim_buf_set_extmark(0, ns, 0, 3, { end_col = 6, hl_group = 'TestBold', priority = 25 - d })
      screen:expect([[
        {1:aaa}{5:bbb}{1:aa^a}                                         |
        {0:~                                                 }|
                                                          |
      ]])
    end
    for _, d in ipairs({-5, 5}) do
      api.nvim_buf_clear_namespace(0, ns, 0, -1)
      screen:expect([[
        aaabbbaa^a                                         |
        {0:~                                                 }|
                                                          |
      ]])
      api.nvim_buf_set_extmark(0, ns, 0, 0, { end_col = 9, hl_group = 'TestUC', priority = 25 + d })
      api.nvim_buf_set_extmark(0, ns, 0, 3, { end_col = 6, hl_group = 'TestBold', priority = 25 - d })
      screen:expect([[
        {2:aaa}{6:bbb}{2:aa^a}                                         |
        {0:~                                                 }|
                                                          |
      ]])
    end
  end)

  it('highlight is combined with syntax and sign linehl #20004', function()
    screen:try_resize(50, 3)
    insert([[
      function Func()
      end]])
    feed('gg')
    command('set ft=lua')
    command('syntax on')
    command('hi default MyMark guibg=LightGrey')
    api.nvim_buf_set_extmark(0, ns, 0, 0, { end_col = 3, hl_mode = 'combine', hl_group = 'MyMark' })
    command('hi default MyLine gui=underline')
    command('sign define CurrentLine linehl=MyLine')
    fn.sign_place(6, 'Test', 'CurrentLine', '', { lnum = 1 })
    screen:expect{grid=[[
      {30:^fun}{31:ction}{32: Func()                                   }|
      {6:end}                                               |
                                                        |
    ]]}
  end)

  it('highlight works after TAB with sidescroll #14201', function()
    screen:try_resize(50, 3)
    command('set nowrap')
    api.nvim_buf_set_lines(0, 0, -1, true, {'\tword word word word'})
    api.nvim_buf_set_extmark(0, ns, 0, 1, { end_col = 3, hl_group = 'ErrorMsg' })
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
    api.nvim_buf_set_lines(0, 0, -1, true, {'this is the\ttab'})
    api.nvim_buf_set_extmark(0, ns, 0, 11, { end_col = 15, hl_group = 'ErrorMsg' })
    screen:expect{grid=[[
      ^this is the{4:     tab}                               |
      {1:~                                                 }|
                                                        |
    ]]}

    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_extmark(0, ns, 0, 12, { end_col = 15, hl_group = 'ErrorMsg' })
    screen:expect{grid=[[
      ^this is the     {4:tab}                               |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('highlight applies to a full TAB on line with matches #20885', function()
    screen:try_resize(50, 3)
    api.nvim_buf_set_lines(0, 0, -1, true, {'\t-- match1', '        -- match2'})
    fn.matchadd('NonText', 'match')
    api.nvim_buf_set_extmark(0, ns, 0, 0, { end_row = 1, end_col = 0, hl_group = 'Search' })
    api.nvim_buf_set_extmark(0, ns, 1, 0, { end_row = 2, end_col = 0, hl_group = 'Search' })
    screen:expect{grid=[[
      {34:       ^ -- }{35:match}{34:1}                                 |
      {34:        -- }{35:match}{34:2}                                 |
                                                        |
    ]]}
  end)

  pending('highlight applies to a full TAB in visual block mode', function()
    screen:try_resize(50, 8)
    command('hi! Visual guifg=NONE guibg=LightGrey')
    api.nvim_buf_set_lines(0, 0, -1, true, {'asdf', '\tasdf', '\tasdf', '\tasdf', 'asdf'})
    api.nvim_buf_set_extmark(0, ns, 0, 0, {end_row = 5, end_col = 0, hl_group = 'Underlined'})
    screen:expect([[
      {28:^asdf}                                              |
      {28:        asdf}                                      |*3
      {28:asdf}                                              |
      {1:~                                                 }|*2
                                                        |
    ]])
    feed('<C-V>Gll')
    screen:expect([[
      {29:asd}{28:f}                                              |
      {29:   }{28:     asdf}                                      |*3
      {29:as}{28:^df}                                              |
      {1:~                                                 }|*2
      {24:-- VISUAL BLOCK --}                                |
    ]])
  end)

  it('highlight works properly with multibyte text and spell #26771', function()
    insert('口口\n')
    screen:try_resize(50, 3)
    api.nvim_buf_set_extmark(0, ns, 0, 0, { end_col = 3, hl_group = 'Search' })
    screen:expect([[
      {34:口}口                                              |
      ^                                                  |
                                                        |
    ]])
    command('setlocal spell')
    screen:expect([[
      {43:口}{42:口}                                              |
      ^                                                  |
                                                        |
    ]])
  end)

  it('supports multiline highlights', function()
    insert(example_text)
    feed 'gg'
    for _,i in ipairs {1,2,3,5,6,7} do
      for _,j in ipairs {2,5,10,15} do
        api.nvim_buf_set_extmark(0, ns, i, j, { end_col=j+2, hl_group = 'NonText'})
      end
    end
    screen:expect{grid=[[
      ^for _,item in ipairs(items) do                    |
        {1:  }l{1:oc}al {1:te}xt,{1: h}l_id_cell, count = unpack(item)  |
        {1:  }i{1:f }hl_{1:id}_ce{1:ll} ~= nil then                     |
        {1:  } {1:  } hl{1:_i}d ={1: h}l_id_cell                        |
          end                                           |
        {1:  }f{1:or} _ {1:= }1, {1:(c}ount or 1) do                    |
        {1:  } {1:  } lo{1:ca}l c{1:el}l = line[colpos]                 |
        {1:  } {1:  } ce{1:ll}.te{1:xt} = text                          |
              cell.hl_id = hl_id                        |
              colpos = colpos+1                         |
          end                                           |
      end                                               |
      {1:~                                                 }|*2
                                                        |
    ]]}
    feed'5<c-e>'
    screen:expect{grid=[[
      ^  {1:  }f{1:or} _ {1:= }1, {1:(c}ount or 1) do                    |
        {1:  } {1:  } lo{1:ca}l c{1:el}l = line[colpos]                 |
        {1:  } {1:  } ce{1:ll}.te{1:xt} = text                          |
              cell.hl_id = hl_id                        |
              colpos = colpos+1                         |
          end                                           |
      end                                               |
      {1:~                                                 }|*7
                                                        |
    ]]}

    api.nvim_buf_set_extmark(0, ns, 1, 0, { end_line=8, end_col=10, hl_group = 'ErrorMsg'})
    screen:expect{grid=[[
      {4:^  }{36:  }{4:f}{36:or}{4: _ }{36:= }{4:1, }{36:(c}{4:ount or 1) do}                    |
      {4:  }{36:  }{4: }{36:  }{4: lo}{36:ca}{4:l c}{36:el}{4:l = line[colpos]}                 |
      {4:  }{36:  }{4: }{36:  }{4: ce}{36:ll}{4:.te}{36:xt}{4: = text}                          |
      {4:        ce}ll.hl_id = hl_id                        |
              colpos = colpos+1                         |
          end                                           |
      end                                               |
      {1:~                                                 }|*7
                                                        |
    ]]}
  end)

  local function with_undo_restore(val)
    screen:try_resize(50, 5)
    insert(example_text)
    feed'gg'
    api.nvim_buf_set_extmark(0, ns, 0, 6, { end_col=13, hl_group = 'NonText', undo_restore=val})
    screen:expect{grid=[[
      ^for _,{1:item in} ipairs(items) do                    |
          local text, hl_id_cell, count = unpack(item)  |
          if hl_id_cell ~= nil then                     |
              hl_id = hl_id_cell                        |
                                                        |
    ]]}

    api.nvim_buf_set_text(0, 0, 4, 0, 8, {''})
    screen:expect{grid=[[
      ^for {1:em in} ipairs(items) do                        |
          local text, hl_id_cell, count = unpack(item)  |
          if hl_id_cell ~= nil then                     |
              hl_id = hl_id_cell                        |
                                                        |
    ]]}
  end

  it("highlights do reapply to restored text after delete", function()
    with_undo_restore(true) -- also default behavior

    command('silent undo')
    screen:expect{grid=[[
      ^for _,{1:item in} ipairs(items) do                    |
          local text, hl_id_cell, count = unpack(item)  |
          if hl_id_cell ~= nil then                     |
              hl_id = hl_id_cell                        |
                                                        |
    ]]}
  end)

  it("highlights don't reapply to restored text after delete with undo_restore=false", function()
    with_undo_restore(false)

    command('silent undo')
    screen:expect{grid=[[
      ^for _,it{1:em in} ipairs(items) do                    |
          local text, hl_id_cell, count = unpack(item)  |
          if hl_id_cell ~= nil then                     |
              hl_id = hl_id_cell                        |
                                                        |
    ]]}

    eq({ { 1, 0, 8, { end_col = 13, end_right_gravity = false, end_row = 0,
                       hl_eol = false, hl_group = "NonText", undo_restore = false,
                       ns_id = 1, priority = 4096, right_gravity = true } } },
       api.nvim_buf_get_extmarks(0, ns, {0,0}, {0, -1}, {details=true}))
  end)

  it('virtual text works with rightleft', function()
    screen:try_resize(50, 3)
    insert('abcdefghijklmn')
    feed('0')
    command('set rightleft')
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = {{'EOL', 'Underlined'}}})
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = {{'right_align', 'Underlined'}}, virt_text_pos = 'right_align' })
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = {{'win_col', 'Underlined'}}, virt_text_win_col = 20 })
    api.nvim_buf_set_extmark(0, ns, 0, 2, { virt_text = {{'overlayed', 'Underlined'}}, virt_text_pos = 'overlay' })
    screen:expect{grid=[[
      {28:ngila_thgir}            {28:loc_niw}  {28:LOE} nml{28:deyalrevo}b^a|
      {1:                                                 ~}|
                                                        |
    ]]}

    insert(('#'):rep(32))
    feed('0')
    screen:expect{grid=[[
      {28:ngila_tdeyalrevo}ba#####{28:loc_niw}###################^#|
      {1:                                                 ~}|
                                                        |
    ]]}

    insert(('#'):rep(16))
    feed('0')
    screen:expect{grid=[[
      {28:ngila_thgir}############{28:loc_niw}###################^#|
                                        {28:LOE} nml{28:deyalrevo}|
                                                        |
    ]]}

    insert('###')
    feed('0')
    screen:expect{grid=[[
      #################################################^#|
      {28:ngila_thgir}            {28:loc_niw} {28:LOE} nml{28:deyalrevo}ba#|
                                                        |
    ]]}

    command('set number')
    screen:expect{grid=[[
      #############################################^#{2: 1  }|
      {28:ngila_thgir}        {28:loc_niw} nml{28:deyalrevo}ba#####{2:    }|
                                                        |
    ]]}

    command('set cpoptions+=n')
    screen:expect{grid=[[
      #############################################^#{2: 1  }|
      {28:ngila_thgir}            {28:loc_niw} nml{28:deyalrevo}ba#####|
                                                        |
    ]]}
  end)

  it('virtual text overwrites double-width char properly', function()
    screen:try_resize(50, 3)
    insert('abcdefghij口klmnopqrstu口vwx口yz')
    feed('0')
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = {{'!!!!!', 'Underlined'}}, virt_text_win_col = 11 })
    screen:expect{grid=[[
      ^abcdefghij {28:!!!!!}opqrstu口vwx口yz                  |
      {1:~                                                 }|
                                                        |
    ]]}
    feed('8x')
    screen:expect{grid=[[
      ^ij口klmnopq{28:!!!!!} vwx口yz                          |
      {1:~                                                 }|
                                                        |
    ]]}
    feed('3l5x')
    screen:expect{grid=[[
      ij口^pqrstu {28:!!!!!} yz                               |
      {1:~                                                 }|
                                                        |
    ]]}
    feed('5x')
    screen:expect{grid=[[
      ij口^u口vwx {28:!!!!!}                                  |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('virtual text blending space does not overwrite double-width char', function()
    screen:try_resize(50, 3)
    insert('abcdefghij口klmnopqrstu口vwx口yz')
    feed('0')
    command('hi Blendy guibg=Red blend=30')
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = {{' !  ! ', 'Blendy'}}, virt_text_win_col = 8, hl_mode = 'blend' })
    screen:expect{grid=[[
      ^abcdefgh{10:i}{7:!}{10:口}{7:!}{10:l}mnopqrstu口vwx口yz                  |
      {1:~                                                 }|
                                                        |
    ]]}
    feed('x')
    screen:expect{grid=[[
      ^bcdefghi{10:j}{7:!}{10: k}{7:!}{10:m}nopqrstu口vwx口yz                   |
      {1:~                                                 }|
                                                        |
    ]]}
    feed('x')
    screen:expect{grid=[[
      ^cdefghij{10: }{7:!}{10:kl}{7:!}{10:n}opqrstu口vwx口yz                    |
      {1:~                                                 }|
                                                        |
    ]]}
    feed('x')
    screen:expect{grid=[[
      ^defghij口{7:!}{10:lm}{7:!}{10:o}pqrstu口vwx口yz                     |
      {1:~                                                 }|
                                                        |
    ]]}
    feed('7x')
    screen:expect{grid=[[
      ^口klmnop{10:q}{7:!}{10:st}{7:!}{10:口}vwx口yz                            |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('virtual text works with double-width char and rightleft', function()
    screen:try_resize(50, 3)
    insert('abcdefghij口klmnopqrstu口vwx口yz')
    feed('0')
    command('set rightleft')
    screen:expect{grid=[[
                        zy口xwv口utsrqponmlk口jihgfedcb^a|
      {1:                                                 ~}|
                                                        |
    ]]}
    api.nvim_buf_set_extmark(0, ns, 0, 2, { virt_text = {{'overlayed', 'Underlined'}}, virt_text_pos = 'overlay' })
    api.nvim_buf_set_extmark(0, ns, 0, 14, { virt_text = {{'古', 'Underlined'}}, virt_text_pos = 'overlay' })
    api.nvim_buf_set_extmark(0, ns, 0, 20, { virt_text = {{'\t', 'Underlined'}}, virt_text_pos = 'overlay' })
    api.nvim_buf_set_extmark(0, ns, 0, 29, { virt_text = {{'古', 'Underlined'}}, virt_text_pos = 'overlay' })
    screen:expect{grid=[[
                        zy {28:古}wv {28:     }qpon{28:古}k {28:deyalrevo}b^a|
      {1:                                                 ~}|
                                                        |
    ]]}
  end)

  it('virtual text is drawn correctly after delete and undo #27368', function()
    insert('aaa\nbbb\nccc\nddd\neee')
    command('vsplit')
    api.nvim_buf_set_extmark(0, ns, 2, 0, { virt_text = {{'EOL'}} })
    feed('3gg')
    screen:expect{grid=[[
      aaa                      │aaa                     |
      bbb                      │bbb                     |
      ^ccc EOL                  │ccc EOL                 |
      ddd                      │ddd                     |
      eee                      │eee                     |
      {1:~                        }│{1:~                       }|*8
      {41:[No Name] [+]             }{40:[No Name] [+]           }|
                                                        |
    ]]}
    feed('dd')
    screen:expect{grid=[[
      aaa                      │aaa                     |
      bbb                      │bbb                     |
      ^ddd EOL                  │ddd EOL                 |
      eee                      │eee                     |
      {1:~                        }│{1:~                       }|*9
      {41:[No Name] [+]             }{40:[No Name] [+]           }|
                                                        |
    ]]}
    command('silent undo')
    screen:expect{grid=[[
      aaa                      │aaa                     |
      bbb                      │bbb                     |
      ^ccc EOL                  │ccc EOL                 |
      ddd                      │ddd                     |
      eee                      │eee                     |
      {1:~                        }│{1:~                       }|*8
      {41:[No Name] [+]             }{40:[No Name] [+]           }|
                                                        |
    ]]}
  end)

  it('virtual text does not crash with blend, conceal and wrap #27836', function()
    screen:try_resize(50, 3)
    insert(('a'):rep(45) .. '|hidden|' .. ('b'):rep(45))
    command('syntax match test /|hidden|/ conceal')
    command('set conceallevel=2 concealcursor=n')
    api.nvim_buf_set_extmark(0, ns, 0, 0, {virt_text = {{'FOO'}}, virt_text_pos='right_align', hl_mode='blend'})
    screen:expect{grid=[[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  FOO|
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb^b     |
                                                        |
    ]]}
  end)

  it('works with both hl_group and sign_hl_group', function()
    screen:try_resize(50, 3)
    insert('abcdefghijklmn')
    api.nvim_buf_set_extmark(0, ns, 0, 0, {sign_text='S', sign_hl_group='NonText', hl_group='Error', end_col=14})
    screen:expect{grid=[[
      {1:S }{4:abcdefghijklm^n}                                  |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('virt_text_repeat_linebreak repeats virtual text on wrapped lines', function()
    screen:try_resize(40, 5)
    api.nvim_set_option_value('breakindent', true, {})
    insert(example_text)
    api.nvim_buf_set_extmark(0, ns, 1, 0, { virt_text = {{'│', 'NonText'}}, virt_text_pos = 'overlay', virt_text_repeat_linebreak = true })
    api.nvim_buf_set_extmark(0, ns, 1, 3, { virt_text = {{'│', 'NonText'}}, virt_text_pos = 'overlay', virt_text_repeat_linebreak = true })
    command('norm gg')
    screen:expect{grid=[[
      ^for _,item in ipairs(items) do          |
      {1:│}  {1:│}local text, hl_id_cell, count = unpa|
      {1:│}  {1:│}ck(item)                            |
          if hl_id_cell ~= nil then           |
                                              |
    ]]}
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    api.nvim_buf_set_extmark(0, ns, 1, 0, { virt_text = {{'│', 'NonText'}}, virt_text_repeat_linebreak = true, virt_text_win_col = 0 })
    api.nvim_buf_set_extmark(0, ns, 1, 0, { virt_text = {{'│', 'NonText'}}, virt_text_repeat_linebreak = true, virt_text_win_col = 2 })
    screen:expect{grid=[[
      ^for _,item in ipairs(items) do          |
      {1:│} {1:│} local text, hl_id_cell, count = unpa|
      {1:│} {1:│} ck(item)                            |
          if hl_id_cell ~= nil then           |
                                              |
    ]]}
  end)

  it('supports URLs', function()
    insert(example_text)

    local url = 'https://example.com'

    screen:add_extra_attr_ids {
        u = { url = "https://example.com" },
    }

    api.nvim_buf_set_extmark(0, ns, 1, 4, {
      end_col = 14,
      url = url,
    })

    screen:expect{grid=[[
      for _,item in ipairs(items) do                    |
          {u:local text}, hl_id_cell, count = unpack(item)  |
          if hl_id_cell ~= nil then                     |
              hl_id = hl_id_cell                        |
          end                                           |
          for _ = 1, (count or 1) do                    |
              local cell = line[colpos]                 |
              cell.text = text                          |
              cell.hl_id = hl_id                        |
              colpos = colpos+1                         |
          end                                           |
      en^d                                               |
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('can replace marks in place with different decorations #27211', function()
    local mark = api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_lines = {{{"foo", "ErrorMsg"}}}, })
    screen:expect{grid=[[
      ^                                                  |
      {4:foo}                                               |
      {1:~                                                 }|*12
                                                        |
    ]]}

    api.nvim_buf_set_extmark(0, ns, 0, 0, {
      id = mark,
      virt_text = { { "testing", "NonText" } },
      virt_text_pos = "inline",
    })
    screen:expect{grid=[[
      {1:^testing}                                           |
      {1:~                                                 }|*13
                                                        |
    ]]}

    api.nvim_buf_del_extmark(0, ns, mark)
    screen:expect{grid=[[
      ^                                                  |
      {1:~                                                 }|*13
                                                        |
    ]]}

    n.assert_alive()
  end)

  it('priority ordering of overlay or win_col virtual text at same position', function()
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = {{'A'}}, virt_text_pos = 'overlay', priority = 100 })
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = {{'A'}}, virt_text_win_col = 30, priority = 100 })
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = {{'BB'}}, virt_text_pos = 'overlay', priority = 90 })
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = {{'BB'}}, virt_text_win_col = 30, priority = 90 })
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = {{'CCC'}}, virt_text_pos = 'overlay', priority = 80 })
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = {{'CCC'}}, virt_text_win_col = 30, priority = 80 })
    screen:expect([[
      ^ABC                           ABC                 |
      {1:~                                                 }|*13
                                                        |
    ]])
  end)

  it('priority ordering of inline and non-inline virtual text at same char', function()
    insert(('?'):rep(40) .. ('!'):rep(30))
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = {{'A'}}, virt_text_pos = 'overlay', priority = 10 })
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = {{'a'}}, virt_text_win_col = 15, priority = 10 })
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = {{'BBBB'}}, virt_text_pos = 'inline', priority = 15 })
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = {{'C'}}, virt_text_pos = 'overlay', priority = 20 })
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = {{'c'}}, virt_text_win_col = 17, priority = 20 })
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = {{'DDDD'}}, virt_text_pos = 'inline', priority = 25 })
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = {{'E'}}, virt_text_pos = 'overlay', priority = 30 })
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = {{'e'}}, virt_text_win_col = 19, priority = 30 })
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = {{'FFFF'}}, virt_text_pos = 'inline', priority = 35 })
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = {{'G'}}, virt_text_pos = 'overlay', priority = 40 })
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = {{'g'}}, virt_text_win_col = 21, priority = 40 })
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = {{'HHHH'}}, virt_text_pos = 'inline', priority = 45 })
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = {{'I'}}, virt_text_pos = 'overlay', priority = 50 })
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = {{'i'}}, virt_text_win_col = 23, priority = 50 })
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = {{'JJJJ'}}, virt_text_pos = 'inline', priority = 55 })
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = {{'K'}}, virt_text_pos = 'overlay', priority = 60 })
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = {{'k'}}, virt_text_win_col = 25, priority = 60 })
    screen:expect([[
      ???????????????a?c?e????????????????????ABBBCDDDEF|
      FFGHHHIJJJK!!!!!!!!!!g!i!k!!!!!!!!!!!!!^!          |
      {1:~                                                 }|*12
                                                        |
    ]])
    feed('02x$')
    screen:expect([[
      ???????????????a?c?e??????????????????ABBBCDDDEFFF|
      GHHHIJJJK!!!!!!!!!!!!g!i!k!!!!!!!!!!!^!            |
      {1:~                                                 }|*12
                                                        |
    ]])
    feed('02x$')
    screen:expect([[
      ???????????????a?c?e?g??????????????ABBBCDDDEFFFGH|
      HHIJJJK!!!!!!!!!!!!!!!!i!k!!!!!!!!!^!              |
      {1:~                                                 }|*12
                                                        |
    ]])
    feed('02x$')
    screen:expect([[
      ???????????????a?c?e?g????????????ABBBCDDDEFFFGHHH|
      IJJJK!!!!!!!!!!!!!!!!!!i!k!!!!!!!^!                |
      {1:~                                                 }|*12
                                                        |
    ]])
    command('set nowrap')
    feed('0')
    screen:expect([[
      ^???????????????a?c?e?g?i?k????????ABBBCDDDEFFFGHHH|
      {1:~                                                 }|*13
                                                        |
    ]])
    feed('2x')
    screen:expect([[
      ^???????????????a?c?e?g?i?k??????ABBBCDDDEFFFGHHHIJ|
      {1:~                                                 }|*13
                                                        |
    ]])
    feed('2x')
    screen:expect([[
      ^???????????????a?c?e?g?i?k????ABBBCDDDEFFFGHHHIJJJ|
      {1:~                                                 }|*13
                                                        |
    ]])
    feed('2x')
    screen:expect([[
      ^???????????????a?c?e?g?i?k??ABBBCDDDEFFFGHHHIJJJK!|
      {1:~                                                 }|*13
                                                        |
    ]])
  end)
end)

describe('decorations: inline virtual text', function()
  local screen, ns
  before_each( function()
    clear()
    screen = Screen.new(50, 3)
    screen:attach()
    screen:set_default_attr_ids {
      [1] = {bold=true, foreground=Screen.colors.Blue};
      [2] = {foreground = Screen.colors.Brown};
      [3] = {bold = true, foreground = Screen.colors.SeaGreen};
      [4] = {background = Screen.colors.Red1, foreground = Screen.colors.Gray100};
      [5] = {background = Screen.colors.Red1, bold = true};
      [6] = {foreground = Screen.colors.DarkCyan};
      [7] = {background = Screen.colors.LightGrey, foreground = Screen.colors.Black};
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
      [21] = {reverse = true, foreground = Screen.colors.SlateBlue}
    }

    ns = api.nvim_create_namespace 'test'
  end)


  it('works', function()
    screen:try_resize(50, 10)
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

    api.nvim_buf_set_extmark(0, ns, 1, 14, {virt_text={{': ', 'Special'}, {'string', 'Type'}}, virt_text_pos='inline'})
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

  it('works with 0-width chunk', function()
    screen:try_resize(50, 10)
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

    api.nvim_buf_set_extmark(0, ns, 0, 5, {virt_text={{''}, {''}}, virt_text_pos='inline'})
    api.nvim_buf_set_extmark(0, ns, 1, 14, {virt_text={{''}, {': ', 'Special'}}, virt_text_pos='inline'})
    api.nvim_buf_set_extmark(0, ns, 1, 48, {virt_text={{''}, {''}}, virt_text_pos='inline'})
    screen:expect{grid=[[
      ^for _,item in ipairs(items) do                    |
          local text{10:: }, hl_id_cell, count = unpack(item)|
          if hl_id_cell ~= nil then                     |
              hl_id = hl_id_cell                        |
          end                                           |
          for _ = 1, (count or 1) do                    |
              local cell = line[colpos]                 |
              cell.text = text                          |
              cell.hl_id = hl_id                        |
                                                        |
    ]]}

    api.nvim_buf_set_extmark(0, ns, 1, 14, {virt_text={{''}, {'string', 'Type'}}, virt_text_pos='inline'})
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

  it('Normal mode "gM" command works properly', function()
    command([[call setline(1, '123456789')]])
    api.nvim_buf_set_extmark(0, ns, 0, 2, { virt_text = { { 'bbb', 'Special' } }, virt_text_pos = 'inline' })
    api.nvim_buf_set_extmark(0, ns, 0, 7, { virt_text = { { 'bbb', 'Special' } }, virt_text_pos = 'inline' })
    feed('gM')
    screen:expect{grid=[[
      12{10:bbb}34^567{10:bbb}89                                   |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  local function test_normal_gj_gk()
    screen:try_resize(60, 6)
    command([[call setline(1, repeat([repeat('a', 55)], 2))]])
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = { { ('b'):rep(10), 'Special' } }, virt_text_pos = 'inline' })
    api.nvim_buf_set_extmark(0, ns, 1, 40, { virt_text = { { ('b'):rep(10), 'Special' } }, virt_text_pos = 'inline' })
    screen:expect{grid=[[
      ^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{10:bbbbbbbbbb}aaaaaaaaaa|
      aaaaa                                                       |
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{10:bbbbbbbbbb}aaaaaaaaaa|
      aaaaa                                                       |
      {1:~                                                           }|
                                                                  |
    ]]}
    feed('gj')
    screen:expect{grid=[[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{10:bbbbbbbbbb}aaaaaaaaaa|
      ^aaaaa                                                       |
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{10:bbbbbbbbbb}aaaaaaaaaa|
      aaaaa                                                       |
      {1:~                                                           }|
                                                                  |
    ]]}
    feed('gj')
    screen:expect{grid=[[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{10:bbbbbbbbbb}aaaaaaaaaa|
      aaaaa                                                       |
      ^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{10:bbbbbbbbbb}aaaaaaaaaa|
      aaaaa                                                       |
      {1:~                                                           }|
                                                                  |
    ]]}
    feed('gj')
    screen:expect{grid=[[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{10:bbbbbbbbbb}aaaaaaaaaa|
      aaaaa                                                       |
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{10:bbbbbbbbbb}aaaaaaaaaa|
      ^aaaaa                                                       |
      {1:~                                                           }|
                                                                  |
    ]]}
    feed('gk')
    screen:expect{grid=[[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{10:bbbbbbbbbb}aaaaaaaaaa|
      aaaaa                                                       |
      ^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{10:bbbbbbbbbb}aaaaaaaaaa|
      aaaaa                                                       |
      {1:~                                                           }|
                                                                  |
    ]]}
    feed('gk')
    screen:expect{grid=[[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{10:bbbbbbbbbb}aaaaaaaaaa|
      ^aaaaa                                                       |
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{10:bbbbbbbbbb}aaaaaaaaaa|
      aaaaa                                                       |
      {1:~                                                           }|
                                                                  |
    ]]}
    feed('gk')
    screen:expect{grid=[[
      ^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{10:bbbbbbbbbb}aaaaaaaaaa|
      aaaaa                                                       |
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{10:bbbbbbbbbb}aaaaaaaaaa|
      aaaaa                                                       |
      {1:~                                                           }|
                                                                  |
    ]]}
  end

  describe('Normal mode "gj" "gk" commands work properly', function()
    it('with virtualedit=', function()
      test_normal_gj_gk()
    end)

    it('with virtualedit=all', function()
      command('set virtualedit=all')
      test_normal_gj_gk()
    end)
  end)

  it('cursor positions are correct with multiple inline virtual text', function()
    insert('12345678')
    api.nvim_buf_set_extmark(0, ns, 0, 4, { virt_text = { { ' virtual text ', 'Special' } }, virt_text_pos = 'inline' })
    api.nvim_buf_set_extmark(0, ns, 0, 4, { virt_text = { { ' virtual text ', 'Special' } }, virt_text_pos = 'inline' })
    feed '^'
    feed '4l'
    screen:expect{grid=[[
      1234{10: virtual text  virtual text }^5678              |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('adjusts cursor location correctly when inserting around inline virtual text', function()
    insert('12345678')
    feed '$'
    api.nvim_buf_set_extmark(0, ns, 0, 4, { virt_text = { { ' virtual text ', 'Special' } }, virt_text_pos = 'inline' })

    screen:expect{grid=[[
      1234{10: virtual text }567^8                            |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('has correct highlighting with multi-byte characters', function()
    insert('12345678')
    api.nvim_buf_set_extmark(0, ns, 0, 4, { virt_text = { { 'múlti-byté chñröcters 修补', 'Special' } }, virt_text_pos = 'inline' })

    screen:expect{grid=[[
      1234{10:múlti-byté chñröcters 修补}567^8                |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('has correct cursor position when inserting around virtual text', function()
    insert('12345678')
    api.nvim_buf_set_extmark(0, ns, 0, 4, { virt_text = { { 'virtual text', 'Special' } }, virt_text_pos = 'inline' })
    feed '^'
    feed '3l'
    feed 'a'
    screen:expect{grid=[[
      1234{10:^virtual text}5678                              |
      {1:~                                                 }|
      {8:-- INSERT --}                                      |
    ]]}
    feed '<ESC>'
    screen:expect{grid=[[
      123^4{10:virtual text}5678                              |
      {1:~                                                 }|
                                                        |
    ]]}
    feed '^'
    feed '4l'
    feed 'i'
    screen:expect{grid=[[
      1234{10:^virtual text}5678                              |
      {1:~                                                 }|
      {8:-- INSERT --}                                      |
    ]]}
  end)

  it('has correct cursor position with virtual text on an empty line', function()
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = { { 'virtual text', 'Special' } }, virt_text_pos = 'inline' })
    screen:expect{grid=[[
      {10:^virtual text}                                      |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('text is drawn correctly with a wrapping virtual text', function()
    screen:try_resize(60, 8)
    exec([[
      call setline(1, ['', 'aaa', '', 'bbbbbb'])
      normal gg0
    ]])
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = { { string.rep('X', 60), 'Special' } }, virt_text_pos = 'inline' })
    api.nvim_buf_set_extmark(0, ns, 2, 0, { virt_text = { { string.rep('X', 61), 'Special' } }, virt_text_pos = 'inline' })
    feed('$')
    screen:expect{grid=[[
      {10:^XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      aaa                                                         |
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {10:X}                                                           |
      bbbbbb                                                      |
      {1:~                                                           }|*2
                                                                  |
    ]]}
    feed('j')
    screen:expect{grid=[[
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      aa^a                                                         |
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {10:X}                                                           |
      bbbbbb                                                      |
      {1:~                                                           }|*2
                                                                  |
    ]]}
    feed('j')
    screen:expect{grid=[[
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      aaa                                                         |
      {10:^XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {10:X}                                                           |
      bbbbbb                                                      |
      {1:~                                                           }|*2
                                                                  |
    ]]}
    feed('j')
    screen:expect{grid=[[
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      aaa                                                         |
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {10:X}                                                           |
      bbbbb^b                                                      |
      {1:~                                                           }|*2
                                                                  |
    ]]}
    feed('0<C-V>2l2k')
    screen:expect{grid=[[
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {7:aa}^a                                                         |
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {10:X}                                                           |
      {7:bbb}bbb                                                      |
      {1:~                                                           }|*2
      {8:-- VISUAL BLOCK --}                                          |
    ]]}
    feed([[<Esc>/aaa\n\%V<CR>]])
    screen:expect{grid=[[
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {12:^aaa }                                                        |
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {10:X}                                                           |
      bbbbbb                                                      |
      {1:~                                                           }|*2
      {16:search hit BOTTOM, continuing at TOP}                        |
    ]]}
    feed('3ggic')
    screen:expect{grid=[[
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {12:aaa }                                                        |
      c{10:^XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {10:XX}                                                          |
      bbbbbb                                                      |
      {1:~                                                           }|*2
      {8:-- INSERT --}                                                |
    ]]}
    feed([[<Esc>/aaa\nc\%V<CR>]])
    screen:expect{grid=[[
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {12:^aaa }                                                        |
      {12:c}{10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {10:XX}                                                          |
      bbbbbb                                                      |
      {1:~                                                           }|*2
      {16:search hit BOTTOM, continuing at TOP}                        |
    ]]}
  end)

  it('cursor position is correct with virtual text attached to hard TABs', function()
    command('set noexpandtab')
    feed('i')
    feed('<TAB>')
    feed('<TAB>')
    feed('test')
    feed('<ESC>')
    api.nvim_buf_set_extmark(0, ns, 0, 1, { virt_text = { { 'virtual text', 'Special' } }, virt_text_pos = 'inline' })
    feed('0')
    screen:expect{grid=[[
             ^ {10:virtual text}    test                      |
      {1:~                                                 }|
                                                        |
    ]]}

    feed('l')
    screen:expect{grid=[[
              {10:virtual text}   ^ test                      |
      {1:~                                                 }|
                                                        |
    ]]}

    feed('l')
    screen:expect{grid=[[
              {10:virtual text}    ^test                      |
      {1:~                                                 }|
                                                        |
    ]]}

    feed('l')
    screen:expect{grid=[[
              {10:virtual text}    t^est                      |
      {1:~                                                 }|
                                                        |
    ]]}

    feed('l')
    screen:expect{grid=[[
              {10:virtual text}    te^st                      |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('cursor position is correct with virtual text on an empty line', function()
    command('set linebreak')
    insert('one twoword')
    feed('0')
    api.nvim_buf_set_extmark(0, ns, 0, 3, { virt_text = { { ': virtual text', 'Special' } }, virt_text_pos = 'inline' })
    screen:expect{grid=[[
      ^one{10:: virtual text} twoword                         |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('search highlight is correct', function()
    insert('foo foo foo bar\nfoo foo foo bar')
    feed('gg0')
    api.nvim_buf_set_extmark(0, ns, 0, 9, { virt_text = { { 'AAA', 'Special' } }, virt_text_pos = 'inline' })
    api.nvim_buf_set_extmark(0, ns, 0, 9, { virt_text = { { 'BBB', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'combine' })
    api.nvim_buf_set_extmark(0, ns, 1, 9, { virt_text = { { 'CCC', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'combine' })
    api.nvim_buf_set_extmark(0, ns, 1, 9, { virt_text = { { 'DDD', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'replace' })
    screen:expect{grid=[[
      ^foo foo f{10:AAABBB}oo bar                             |
      foo foo f{10:CCCDDD}oo bar                             |
                                                        |
    ]]}

    feed('/foo')
    screen:expect{grid=[[
      {12:foo} {13:foo} {12:f}{10:AAA}{19:BBB}{12:oo} bar                             |
      {12:foo} {12:foo} {12:f}{19:CCC}{10:DDD}{12:oo} bar                             |
      /foo^                                              |
    ]]}

    api.nvim_buf_set_extmark(0, ns, 0, 13, { virt_text = { { 'EEE', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'combine' })
    feed('<C-G>')
    screen:expect{grid=[[
      {12:foo} {12:foo} {13:f}{10:AAA}{21:BBB}{13:oo} b{10:EEE}ar                          |
      {12:foo} {12:foo} {12:f}{19:CCC}{10:DDD}{12:oo} bar                             |
      /foo^                                              |
    ]]}
  end)

  it('Visual select highlight is correct', function()
    insert('foo foo foo bar\nfoo foo foo bar')
    feed('gg0')
    api.nvim_buf_set_extmark(0, ns, 0, 8, { virt_text = { { 'AAA', 'Special' } }, virt_text_pos = 'inline' })
    api.nvim_buf_set_extmark(0, ns, 0, 8, { virt_text = { { 'BBB', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'combine' })
    api.nvim_buf_set_extmark(0, ns, 1, 8, { virt_text = { { 'CCC', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'combine' })
    api.nvim_buf_set_extmark(0, ns, 1, 8, { virt_text = { { 'DDD', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'replace' })
    feed('8l')
    screen:expect{grid=[[
      foo foo {10:AAABBB}^foo bar                             |
      foo foo {10:CCCDDD}foo bar                             |
                                                        |
    ]]}

    feed('<C-V>')
    feed('2hj')
    screen:expect{grid=[[
      foo fo{7:o }{10:AAA}{20:BBB}{7:f}oo bar                             |
      foo fo^o{7: }{20:CCC}{10:DDD}{7:f}oo bar                             |
      {8:-- VISUAL BLOCK --}                                |
    ]]}

    api.nvim_buf_set_extmark(0, ns, 0, 10, { virt_text = { { 'EEE', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'combine' })
    screen:expect{grid=[[
      foo fo{7:o }{10:AAA}{20:BBB}{7:f}o{10:EEE}o bar                          |
      foo fo^o{7: }{20:CCC}{10:DDD}{7:f}oo bar                             |
      {8:-- VISUAL BLOCK --}                                |
    ]]}
  end)

  it('inside highlight range of another extmark', function()
    insert('foo foo foo bar\nfoo foo foo bar')
    api.nvim_buf_set_extmark(0, ns, 0, 8, { virt_text = { { 'AAA', 'Special' } }, virt_text_pos = 'inline' })
    api.nvim_buf_set_extmark(0, ns, 0, 8, { virt_text = { { 'BBB', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'combine' })
    api.nvim_buf_set_extmark(0, ns, 1, 8, { virt_text = { { 'CCC', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'combine' })
    api.nvim_buf_set_extmark(0, ns, 1, 8, { virt_text = { { 'DDD', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'replace' })
    api.nvim_buf_set_extmark(0, ns, 0, 4, { end_col = 11, hl_group = 'Search' })
    api.nvim_buf_set_extmark(0, ns, 1, 4, { end_col = 11, hl_group = 'Search' })
    screen:expect{grid=[[
      foo {12:foo }{10:AAA}{19:BBB}{12:foo} bar                             |
      foo {12:foo }{19:CCC}{10:DDD}{12:foo} ba^r                             |
                                                        |
    ]]}
  end)

  it('inside highlight range of syntax', function()
    insert('foo foo foo bar\nfoo foo foo bar')
    api.nvim_buf_set_extmark(0, ns, 0, 8, { virt_text = { { 'AAA', 'Special' } }, virt_text_pos = 'inline' })
    api.nvim_buf_set_extmark(0, ns, 0, 8, { virt_text = { { 'BBB', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'combine' })
    api.nvim_buf_set_extmark(0, ns, 1, 8, { virt_text = { { 'CCC', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'combine' })
    api.nvim_buf_set_extmark(0, ns, 1, 8, { virt_text = { { 'DDD', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'replace' })
    command([[syntax match Search 'foo \zsfoo foo\ze bar']])
    screen:expect{grid=[[
      foo {12:foo }{10:AAA}{19:BBB}{12:foo} bar                             |
      foo {12:foo }{19:CCC}{10:DDD}{12:foo} ba^r                             |
                                                        |
    ]]}
  end)

  it('cursor position is correct when inserting around a virtual text with left gravity', function()
    screen:try_resize(27, 4)
    insert(('a'):rep(15))
    api.nvim_buf_set_extmark(0, ns, 0, 8, { virt_text = { { ('>'):rep(43), 'Special' } }, virt_text_pos = 'inline', right_gravity = false })
    command('setlocal showbreak=+ breakindent breakindentopt=shift:2')
    feed('08l')
    screen:expect{grid=[[
      aaaaaaaa{10:>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}^aaaaaaa                 |
                                 |
    ]]}
    feed('i')
    screen:expect{grid=[[
      aaaaaaaa{10:>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}^aaaaaaa                 |
      {8:-- INSERT --}               |
    ]]}
    feed([[<C-\><C-O>]])
    screen:expect{grid=[[
      aaaaaaaa{10:>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}^aaaaaaa                 |
      {8:-- (insert) --}             |
    ]]}
    feed('D')
    screen:expect{grid=[[
      aaaaaaaa{10:>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>>>>>>>>>>>>>>>>>>>>>>>}|
      {1:^~                          }|
      {8:-- INSERT --}               |
    ]]}
    command('setlocal list listchars=eol:$')
    screen:expect{grid=[[
      aaaaaaaa{10:>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+^$}                       |
      {8:-- INSERT --}               |
    ]]}
    feed('<C-U>')
    screen:expect{grid=[[
      {10:>>>>>>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>>>>>>>>>>>>>>>}{1:^$}       |
      {1:~                          }|
      {8:-- INSERT --}               |
    ]]}
    feed('a')
    screen:expect{grid=[[
      {10:>>>>>>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>>>>>>>>>>>>>>>}a{1:^$}      |
      {1:~                          }|
      {8:-- INSERT --}               |
    ]]}
    feed('<Esc>')
    screen:expect{grid=[[
      {10:>>>>>>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>>>>>>>>>>>>>>>}^a{1:$}      |
      {1:~                          }|
                                 |
    ]]}
    feed('x')
    screen:expect{grid=[[
      {10:^>>>>>>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>>>>>>>>>>>>>>>}{1:$}       |
      {1:~                          }|
                                 |
    ]]}
  end)

  it('cursor position is correct when inserting around virtual texts with both left and right gravity', function()
    screen:try_resize(30, 4)
    command('setlocal showbreak=+ breakindent breakindentopt=shift:2')
    insert(('a'):rep(15))
    api.nvim_buf_set_extmark(0, ns, 0, 8, { virt_text = {{ ('>'):rep(32), 'Special' }}, virt_text_pos = 'inline', right_gravity = false })
    api.nvim_buf_set_extmark(0, ns, 0, 8, { virt_text = {{ ('<'):rep(32), 'Special' }}, virt_text_pos = 'inline', right_gravity = true })
    feed('08l')
    screen:expect{grid=[[
      aaaaaaaa{10:>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>>>>>>>>><<<<<<<<<<<<<<<<<}|
        {1:+}{10:<<<<<<<<<<<<<<<}^aaaaaaa     |
                                    |
    ]]}
    feed('i')
    screen:expect{grid=[[
      aaaaaaaa{10:>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>>>>>>>>>^<<<<<<<<<<<<<<<<<}|
        {1:+}{10:<<<<<<<<<<<<<<<}aaaaaaa     |
      {8:-- INSERT --}                  |
    ]]}
    feed('a')
    screen:expect{grid=[[
      aaaaaaaa{10:>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>>>>>>>>>}a{10:^<<<<<<<<<<<<<<<<}|
        {1:+}{10:<<<<<<<<<<<<<<<<}aaaaaaa    |
      {8:-- INSERT --}                  |
    ]]}
    feed([[<C-\><C-O>]])
    screen:expect{grid=[[
      aaaaaaaa{10:>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>>>>>>>>>}a{10:<<<<<<<<<<<<<<<<}|
        {1:+}{10:<<<<<<<<<<<<<<<<}^aaaaaaa    |
      {8:-- (insert) --}                |
    ]]}
    feed('D')
    screen:expect{grid=[[
      aaaaaaaa{10:>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>>>>>>>>>}a{10:^<<<<<<<<<<<<<<<<}|
        {1:+}{10:<<<<<<<<<<<<<<<<}           |
      {8:-- INSERT --}                  |
    ]]}
    feed('<BS>')
    screen:expect{grid=[[
      aaaaaaaa{10:>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>>>>>>>>>^<<<<<<<<<<<<<<<<<}|
        {1:+}{10:<<<<<<<<<<<<<<<}            |
      {8:-- INSERT --}                  |
    ]]}
    feed('<C-U>')
    screen:expect{grid=[[
      {10:>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>^<<<<<<<<<<<<<<<<<<<<<<<<<}|
        {1:+}{10:<<<<<<<}                    |
      {8:-- INSERT --}                  |
    ]]}
    feed('a')
    screen:expect{grid=[[
      {10:>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>}a{10:^<<<<<<<<<<<<<<<<<<<<<<<<}|
        {1:+}{10:<<<<<<<<}                   |
      {8:-- INSERT --}                  |
    ]]}
    feed('<Esc>')
    screen:expect{grid=[[
      {10:>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>}^a{10:<<<<<<<<<<<<<<<<<<<<<<<<}|
        {1:+}{10:<<<<<<<<}                   |
                                    |
    ]]}
    feed('x')
    screen:expect{grid=[[
      {10:^>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>><<<<<<<<<<<<<<<<<<<<<<<<<}|
        {1:+}{10:<<<<<<<}                    |
                                    |
    ]]}
    feed('i')
    screen:expect{grid=[[
      {10:>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:>>^<<<<<<<<<<<<<<<<<<<<<<<<<}|
        {1:+}{10:<<<<<<<}                    |
      {8:-- INSERT --}                  |
    ]]}
    screen:try_resize(32, 4)
    screen:expect{grid=[[
      {10:>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}|
        {1:+}{10:^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<}|
        {1:+}{10:<<<}                          |
      {8:-- INSERT --}                    |
    ]]}
    command('setlocal nobreakindent')
    screen:expect{grid=[[
      {10:>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}|
      {1:+}{10:^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<}|
      {1:+}{10:<}                              |
      {8:-- INSERT --}                    |
    ]]}
  end)

  it('draws correctly with no wrap multiple virtual text, where one is hidden', function()
    insert('abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz')
    command("set nowrap")
    api.nvim_buf_set_extmark(0, ns, 0, 50, { virt_text = { { 'virtual text', 'Special' } }, virt_text_pos = 'inline' })
    api.nvim_buf_set_extmark(0, ns, 0, 2, { virt_text = { { 'virtual text', 'Special' } }, virt_text_pos = 'inline' })
    feed('$')
    screen:expect{grid=[[
      opqrstuvwxyzabcdefghijklmnopqrstuvwx{10:virtual text}y^z|
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('draws correctly with no wrap and a long virtual text', function()
    insert('abcdefghi')
    command("set nowrap")
    api.nvim_buf_set_extmark(0, ns, 0, 2, { virt_text = { { string.rep('X', 55), 'Special' } }, virt_text_pos = 'inline' })
    feed('$')
    screen:expect{grid=[[
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}cdefgh^i|
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('tabs are the correct length with no wrap following virtual text', function()
    command('set nowrap')
    feed('itest<TAB>a<ESC>')
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = { { string.rep('a', 55), 'Special' } }, virt_text_pos = 'inline' })
    feed('gg$')
    screen:expect{grid=[[
      {10:aaaaaaaaaaaaaaaaaaaaaaaaa}test     ^a               |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('highlighting does not extend with no wrap and a long virtual text', function()
    insert('abcdef')
    command("set nowrap")
    api.nvim_buf_set_extmark(0, ns, 0, 3, { virt_text = { { string.rep('X', 50), 'Special' } }, virt_text_pos = 'inline' })
    feed('$')
    screen:expect{grid=[[
      {10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}de^f|
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('hidden virtual text does not interfere with Visual highlight', function()
    insert('abcdef')
    command('set nowrap')
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = { { 'XXX', 'Special' } }, virt_text_pos = 'inline' })
    feed('V2zl')
    screen:expect{grid=[[
      {10:X}{7:abcde}^f                                           |
      {1:~                                                 }|
      {8:-- VISUAL LINE --}                                 |
    ]]}
    feed('zl')
    screen:expect{grid=[[
      {7:abcde}^f                                            |
      {1:~                                                 }|
      {8:-- VISUAL LINE --}                                 |
    ]]}
    feed('zl')
    screen:expect{grid=[[
      {7:bcde}^f                                             |
      {1:~                                                 }|
      {8:-- VISUAL LINE --}                                 |
    ]]}
  end)

  it('highlighting is correct when virtual text wraps with number', function()
    screen:try_resize(50, 5)
    insert([[
    test
    test]])
    command('set number')
    api.nvim_buf_set_extmark(0, ns, 0, 1, { virt_text = { { string.rep('X', 55), 'Special' } }, virt_text_pos = 'inline' })
    feed('gg0')
    screen:expect{grid=[[
      {2:  1 }^t{10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {2:    }{10:XXXXXXXXXX}est                                 |
      {2:  2 }test                                          |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('highlighting is correct when virtual text is proceeded with a match', function()
    insert([[test]])
    api.nvim_buf_set_extmark(0, ns, 0, 2, { virt_text = { { 'virtual text', 'Special' } }, virt_text_pos = 'inline' })
    feed('gg0')
    command('match ErrorMsg /e/')
    screen:expect{grid=[[
      ^t{4:e}{10:virtual text}st                                  |
      {1:~                                                 }|
                                                        |
    ]]}
    command('match ErrorMsg /s/')
    screen:expect{grid=[[
      ^te{10:virtual text}{4:s}t                                  |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('smoothscroll works correctly when virtual text wraps', function()
    insert('foobar')
    api.nvim_buf_set_extmark(0, ns, 0, 3, { virt_text = { { string.rep('X', 55), 'Special' } }, virt_text_pos = 'inline' })
    command('setlocal smoothscroll')
    screen:expect{grid=[[
      foo{10:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX}|
      {10:XXXXXXXX}ba^r                                       |
                                                        |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
      {1:<<<}{10:XXXXX}ba^r                                       |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('in diff mode is highlighted correct', function()
    screen:try_resize(50, 10)
    insert([[
    9000
    0009
    0009
    9000
    0009
    ]])
    insert('aaa\tbbb')
    command("set diff")
    api.nvim_buf_set_extmark(0, ns, 0, 1, { virt_text = { { 'test', 'Special' } }, virt_text_pos = 'inline', right_gravity = false })
    api.nvim_buf_set_extmark(0, ns, 5, 0, { virt_text = { { '!', 'Special' } }, virt_text_pos = 'inline' })
    api.nvim_buf_set_extmark(0, ns, 5, 3, { virt_text = { { '' } }, virt_text_pos = 'inline' })
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
    screen:expect{grid=[[
      {9:^000                      }│{5:9}{14:test}{9:000                }|
      {9:000                      }│{9:000}{5:9}{9:                    }|*2
      {9:000                      }│{5:9}{9:000                    }|
      {9:000                      }│{9:000}{5:9}{9:                    }|
      {9:aaabbb                   }│{14:!}{9:aaa}{5:    }{9:bbb             }|
      {1:~                        }│{1:~                       }|*2
      {15:[No Name] [+]             }{13:[No Name] [+]           }|
                                                        |
    ]]}
    command('wincmd w | set nowrap')
    feed('zl')
    screen:expect{grid=[[
      {9:000                      }│{14:test}{9:000                 }|
      {9:000                      }│{9:00}{5:9}{9:                     }|*2
      {9:000                      }│{9:000                     }|
      {9:000                      }│{9:00}{5:9}{9:                     }|
      {9:aaabbb                   }│{9:aaa}{5:    }{9:bb^b              }|
      {1:~                        }│{1:~                       }|*2
      {13:[No Name] [+]             }{15:[No Name] [+]           }|
                                                        |
    ]]}
  end)

  it('correctly draws when there are multiple overlapping virtual texts on the same line with nowrap', function()
    command('set nowrap')
    insert('a')
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = { { string.rep('a', 55), 'Special' } }, virt_text_pos = 'inline' })
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = { { string.rep('b', 55), 'Special' } }, virt_text_pos = 'inline' })
    feed('$')
    screen:expect{grid=[[
      {10:bbbbbbbbbbbbbbbbbbbbbbbbb}^a                        |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('correctly draws when overflowing virtual text is followed by TAB with no wrap', function()
    command('set nowrap')
    feed('i<TAB>test<ESC>')
    api.nvim_buf_set_extmark( 0, ns, 0, 0, { virt_text = { { string.rep('a', 60), 'Special' } }, virt_text_pos = 'inline' })
    feed('0')
    screen:expect({grid=[[
      {10:aaaaaaaaaaaaaaaaaaaaaa}   ^ test                    |
      {1:~                                                 }|
                                                        |
    ]]})
  end)

  it('does not crash at column 0 when folded in a wide window', function()
    screen:try_resize(82, 5)
    command('hi! CursorLine guibg=NONE guifg=Red gui=NONE')
    command('set cursorline')
    insert([[
      aaaaa
      bbbbb

      ccccc]])
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = {{'foo'}}, virt_text_pos = 'inline' })
    api.nvim_buf_set_extmark(0, ns, 2, 0, { virt_text = {{'bar'}}, virt_text_pos = 'inline' })
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
      {1:~                                                                                 }|*2
                                                                                        |
    ]]}
    feed('j')
    screen:expect{grid=[[
      {17:+--  2 lines: aaaaa·······························································}|
      {18:^+--  2 lines: ccccc·······························································}|
      {1:~                                                                                 }|*2
                                                                                        |
    ]]}
  end)

  it('does not crash at right edge of wide window #23848', function()
    screen:try_resize(82, 5)
    api.nvim_buf_set_extmark(0, ns, 0, 0, {virt_text = {{('a'):rep(82)}, {'b'}}, virt_text_pos = 'inline'})
    screen:expect{grid=[[
      ^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      b                                                                                 |
      {1:~                                                                                 }|*2
                                                                                        |
    ]]}
    command('set nowrap')
    screen:expect{grid=[[
      ^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {1:~                                                                                 }|*3
                                                                                        |
    ]]}
    feed('82i0<Esc>0')
    screen:expect{grid=[[
      ^0000000000000000000000000000000000000000000000000000000000000000000000000000000000|
      {1:~                                                                                 }|*3
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

  it('lcs-extends is drawn with inline virtual text at end of screen line', function()
    exec([[
      setlocal nowrap list listchars=extends:!
      call setline(1, repeat('a', 51))
    ]])
    api.nvim_buf_set_extmark(0, ns, 0, 50, { virt_text = { { 'bbb', 'Special' } }, virt_text_pos = 'inline' })
    feed('20l')
    screen:expect{grid=[[
      aaaaaaaaaaaaaaaaaaaa^aaaaaaaaaaaaaaaaaaaaaaaaaaaaa{1:!}|
      {1:~                                                 }|
                                                        |
    ]]}
    feed('zl')
    screen:expect{grid=[[
      aaaaaaaaaaaaaaaaaaa^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{1:!}|
      {1:~                                                 }|
                                                        |
    ]]}
    feed('zl')
    screen:expect{grid=[[
      aaaaaaaaaaaaaaaaaa^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{10:b}{1:!}|
      {1:~                                                 }|
                                                        |
    ]]}
    feed('zl')
    screen:expect{grid=[[
      aaaaaaaaaaaaaaaaa^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{10:bb}{1:!}|
      {1:~                                                 }|
                                                        |
    ]]}
    feed('zl')
    screen:expect{grid=[[
      aaaaaaaaaaaaaaaa^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{10:bbb}a|
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('lcs-extends is drawn with only inline virtual text offscreen', function()
    command('set nowrap')
    command('set list')
    command('set listchars+=extends:c')
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_text = { { 'test', 'Special' } }, virt_text_pos = 'inline' })
    insert(string.rep('a', 50))
    feed('gg0')
    screen:expect{grid=[[
      ^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{1:c}|
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('blockwise Visual highlight with double-width virtual text (replace)', function()
    screen:try_resize(60, 6)
    insert('123456789\n123456789\n123456789\n123456789')
    api.nvim_buf_set_extmark(0, ns, 1, 1, { virt_text = { { '-口-', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'replace' })
    api.nvim_buf_set_extmark(0, ns, 2, 2, { virt_text = { { '口', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'replace' })
    feed('gg0')
    screen:expect{grid=[[
      ^123456789                                                   |
      1{10:-口-}23456789                                               |
      12{10:口}3456789                                                 |
      123456789                                                   |
      {1:~                                                           }|
                                                                  |
    ]]}
    feed('<C-V>3jl')
    screen:expect{grid=[[
      {7:12}3456789                                                   |
      {7:1}{10:-口-}23456789                                               |
      {7:12}{10:口}3456789                                                 |
      {7:1}^23456789                                                   |
      {1:~                                                           }|
      {8:-- VISUAL BLOCK --}                                          |
    ]]}
    feed('l')
    screen:expect{grid=[[
      {7:123}456789                                                   |
      {7:1}{10:-口-}23456789                                               |
      {7:12}{10:口}3456789                                                 |
      {7:12}^3456789                                                   |
      {1:~                                                           }|
      {8:-- VISUAL BLOCK --}                                          |
    ]]}
    feed('4l')
    screen:expect{grid=[[
      {7:1234567}89                                                   |
      {7:1}{10:-口-}{7:23}456789                                               |
      {7:12}{10:口}{7:345}6789                                                 |
      {7:123456}^789                                                   |
      {1:~                                                           }|
      {8:-- VISUAL BLOCK --}                                          |
    ]]}
    feed('Ol')
    screen:expect{grid=[[
      1{7:234567}89                                                   |
      1{10:-口-}{7:23}456789                                               |
      1{7:2}{10:口}{7:345}6789                                                 |
      1^2{7:34567}89                                                   |
      {1:~                                                           }|
      {8:-- VISUAL BLOCK --}                                          |
    ]]}
    feed('l')
    screen:expect{grid=[[
      12{7:34567}89                                                   |
      1{10:-口-}{7:23}456789                                               |
      12{10:口}{7:345}6789                                                 |
      12^3{7:4567}89                                                   |
      {1:~                                                           }|
      {8:-- VISUAL BLOCK --}                                          |
    ]]}
    feed('l')
    screen:expect{grid=[[
      123{7:4567}89                                                   |
      1{10:-口-}{7:23}456789                                               |
      12{10:口}{7:345}6789                                                 |
      123^4{7:567}89                                                   |
      {1:~                                                           }|
      {8:-- VISUAL BLOCK --}                                          |
    ]]}
  end)

  it('blockwise Visual highlight with double-width virtual text (combine)', function()
    screen:try_resize(60, 6)
    insert('123456789\n123456789\n123456789\n123456789')
    api.nvim_buf_set_extmark(0, ns, 1, 1, { virt_text = { { '-口-', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'combine' })
    api.nvim_buf_set_extmark(0, ns, 2, 2, { virt_text = { { '口', 'Special' } }, virt_text_pos = 'inline', hl_mode = 'combine' })
    feed('gg0')
    screen:expect{grid=[[
      ^123456789                                                   |
      1{10:-口-}23456789                                               |
      12{10:口}3456789                                                 |
      123456789                                                   |
      {1:~                                                           }|
                                                                  |
    ]]}
    feed('<C-V>3jl')
    screen:expect{grid=[[
      {7:12}3456789                                                   |
      {7:1}{20:-}{10:口-}23456789                                               |
      {7:12}{10:口}3456789                                                 |
      {7:1}^23456789                                                   |
      {1:~                                                           }|
      {8:-- VISUAL BLOCK --}                                          |
    ]]}
    feed('l')
    screen:expect{grid=[[
      {7:123}456789                                                   |
      {7:1}{20:-口}{10:-}23456789                                               |
      {7:12}{20:口}3456789                                                 |
      {7:12}^3456789                                                   |
      {1:~                                                           }|
      {8:-- VISUAL BLOCK --}                                          |
    ]]}
    feed('4l')
    screen:expect{grid=[[
      {7:1234567}89                                                   |
      {7:1}{20:-口-}{7:23}456789                                               |
      {7:12}{20:口}{7:345}6789                                                 |
      {7:123456}^789                                                   |
      {1:~                                                           }|
      {8:-- VISUAL BLOCK --}                                          |
    ]]}
    feed('Ol')
    screen:expect{grid=[[
      1{7:234567}89                                                   |
      1{20:-口-}{7:23}456789                                               |
      1{7:2}{20:口}{7:345}6789                                                 |
      1^2{7:34567}89                                                   |
      {1:~                                                           }|
      {8:-- VISUAL BLOCK --}                                          |
    ]]}
    feed('l')
    screen:expect{grid=[[
      12{7:34567}89                                                   |
      1{10:-}{20:口-}{7:23}456789                                               |
      12{20:口}{7:345}6789                                                 |
      12^3{7:4567}89                                                   |
      {1:~                                                           }|
      {8:-- VISUAL BLOCK --}                                          |
    ]]}
    feed('l')
    screen:expect{grid=[[
      123{7:4567}89                                                   |
      1{10:-}{20:口-}{7:23}456789                                               |
      12{20:口}{7:345}6789                                                 |
      123^4{7:567}89                                                   |
      {1:~                                                           }|
      {8:-- VISUAL BLOCK --}                                          |
    ]]}
  end)

  local function test_virt_inline_showbreak_smoothscroll()
    screen:try_resize(30, 6)
    exec([[
      highlight! link LineNr Normal
      setlocal number showbreak=+ breakindent breakindentopt=shift:2
      setlocal scrolloff=0 smoothscroll
      call setline(1, repeat('a', 28))
      normal! $
    ]])
    api.nvim_buf_set_extmark(0, ns, 0, 27, { virt_text = { { ('123'):rep(23) } }, virt_text_pos = 'inline' })
    feed(':<CR>')  -- Have a screen line that doesn't start with spaces
    screen:expect{grid=[[
        1 aaaaaaaaaaaaaaaaaaaaaaaaaa|
            {1:+}a1231231231231231231231|
            {1:+}23123123123123123123123|
            {1:+}12312312312312312312312|
            {1:+}3^a                     |
      :                             |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
            {1:+}a1231231231231231231231|
            {1:+}23123123123123123123123|
            {1:+}12312312312312312312312|
            {1:+}3^a                     |
      {1:~                             }|
      :                             |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
            {1:+}23123123123123123123123|
            {1:+}12312312312312312312312|
            {1:+}3^a                     |
      {1:~                             }|*2
      :                             |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
            {1:+}12312312312312312312312|
            {1:+}3^a                     |
      {1:~                             }|*3
      :                             |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
            {1:+}3^a                     |
      {1:~                             }|*4
      :                             |
    ]]}
    feed('zbi')
    screen:expect{grid=[[
        1 aaaaaaaaaaaaaaaaaaaaaaaaaa|
            {1:+}a^1231231231231231231231|
            {1:+}23123123123123123123123|
            {1:+}12312312312312312312312|
            {1:+}3a                     |
      {8:-- INSERT --}                  |
    ]]}
    feed('<BS>')
    screen:expect{grid=[[
        1 aaaaaaaaaaaaaaaaaaaaaaaaaa|
            {1:+}^12312312312312312312312|
            {1:+}31231231231231231231231|
            {1:+}23123123123123123123123|
            {1:+}a                      |
      {8:-- INSERT --}                  |
    ]]}
    feed('<Esc>l')
    feed(':<CR>')  -- Have a screen line that doesn't start with spaces
    screen:expect{grid=[[
        1 aaaaaaaaaaaaaaaaaaaaaaaaaa|
            {1:+}12312312312312312312312|
            {1:+}31231231231231231231231|
            {1:+}23123123123123123123123|
            {1:+}^a                      |
      :                             |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
            {1:+}12312312312312312312312|
            {1:+}31231231231231231231231|
            {1:+}23123123123123123123123|
            {1:+}^a                      |
      {1:~                             }|
      :                             |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
            {1:+}31231231231231231231231|
            {1:+}23123123123123123123123|
            {1:+}^a                      |
      {1:~                             }|*2
      :                             |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
            {1:+}23123123123123123123123|
            {1:+}^a                      |
      {1:~                             }|*3
      :                             |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
            {1:+}^a                      |
      {1:~                             }|*4
      :                             |
    ]]}
    feed('023x$')
    screen:expect{grid=[[
        1 aaa12312312312312312312312|
            {1:+}31231231231231231231231|
            {1:+}23123123123123123123123|
            {1:+}^a                      |
      {1:~                             }|
      :                             |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
            {1:+}31231231231231231231231|
            {1:+}23123123123123123123123|
            {1:+}^a                      |
      {1:~                             }|*2
      :                             |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
            {1:+}23123123123123123123123|
            {1:+}^a                      |
      {1:~                             }|*3
      :                             |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
            {1:+}^a                      |
      {1:~                             }|*4
      :                             |
    ]]}
    feed('zbi')
    screen:expect{grid=[[
        1 aaa^12312312312312312312312|
            {1:+}31231231231231231231231|
            {1:+}23123123123123123123123|
            {1:+}a                      |
      {1:~                             }|
      {8:-- INSERT --}                  |
    ]]}
    feed('<C-U>')
    screen:expect{grid=[[
        1 ^12312312312312312312312312|
            {1:+}31231231231231231231231|
            {1:+}23123123123123123123a  |
      {1:~                             }|*2
      {8:-- INSERT --}                  |
    ]]}
    feed('<Esc>')
    screen:expect{grid=[[
        1 12312312312312312312312312|
            {1:+}31231231231231231231231|
            {1:+}23123123123123123123^a  |
      {1:~                             }|*2
                                    |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
            {1:+}31231231231231231231231|
            {1:+}23123123123123123123^a  |
      {1:~                             }|*3
                                    |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
            {1:+}23123123123123123123^a  |
      {1:~                             }|*4
                                    |
    ]]}
    feed('zbx')
    screen:expect{grid=[[
        1 ^12312312312312312312312312|
            {1:+}31231231231231231231231|
            {1:+}23123123123123123123   |
      {1:~                             }|*2
                                    |
    ]]}
    feed('26ia<Esc>a')
    screen:expect{grid=[[
        1 aaaaaaaaaaaaaaaaaaaaaaaaaa|
            {1:+}^12312312312312312312312|
            {1:+}31231231231231231231231|
            {1:+}23123123123123123123123|
      {1:~                             }|
      {8:-- INSERT --}                  |
    ]]}
    feed([[<C-\><C-O>:setlocal breakindentopt=<CR>]])
    screen:expect{grid=[[
        1 aaaaaaaaaaaaaaaaaaaaaaaaaa|
          {1:+}^1231231231231231231231231|
          {1:+}2312312312312312312312312|
          {1:+}3123123123123123123      |
      {1:~                             }|
      {8:-- INSERT --}                  |
    ]]}
  end

  describe('with showbreak, smoothscroll', function()
    it('and cpoptions-=n', function()
      test_virt_inline_showbreak_smoothscroll()
    end)

    it('and cpoptions+=n', function()
      command('set cpoptions+=n')
      -- because of 'breakindent' the screen states are the same
      test_virt_inline_showbreak_smoothscroll()
    end)
  end)

  it('before TABs with smoothscroll', function()
    screen:try_resize(30, 6)
    exec([[
      setlocal list listchars=tab:<-> scrolloff=0 smoothscroll
      call setline(1, repeat("\t", 4) .. 'a')
      normal! $
    ]])
    api.nvim_buf_set_extmark(0, ns, 0, 3, { virt_text = { { ('12'):rep(32) } }, virt_text_pos = 'inline' })
    screen:expect{grid=[[
      {1:<------><------><------>}121212|
      121212121212121212121212121212|
      1212121212121212121212121212{1:<-}|
      {1:----->}^a                       |
      {1:~                             }|
                                    |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
      {1:<<<}212121212121212121212121212|
      1212121212121212121212121212{1:<-}|
      {1:----->}^a                       |
      {1:~                             }|*2
                                    |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
      {1:<<<}2121212121212121212121212{1:<-}|
      {1:----->}^a                       |
      {1:~                             }|*3
                                    |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
      {1:<<<-->}^a                       |
      {1:~                             }|*4
                                    |
    ]]}
    feed('zbh')
    screen:expect{grid=[[
      {1:<------><------><------>}121212|
      121212121212121212121212121212|
      1212121212121212121212121212{1:^<-}|
      {1:----->}a                       |
      {1:~                             }|
                                    |
    ]]}
    feed('i')
    screen:expect{grid=[[
      {1:<------><------><------>}^121212|
      121212121212121212121212121212|
      1212121212121212121212121212{1:<-}|
      {1:----->}a                       |
      {1:~                             }|
      {8:-- INSERT --}                  |
    ]]}
    feed('<C-O>:setlocal nolist<CR>')
    screen:expect{grid=[[
                              ^121212|
      121212121212121212121212121212|
      1212121212121212121212121212  |
            a                       |
      {1:~                             }|
      {8:-- INSERT --}                  |
    ]]}
    feed('<Esc>l')
    screen:expect{grid=[[
                              121212|
      121212121212121212121212121212|
      1212121212121212121212121212  |
           ^ a                       |
      {1:~                             }|
                                    |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
      {1:<<<}212121212121212121212121212|
      1212121212121212121212121212  |
           ^ a                       |
      {1:~                             }|*2
                                    |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
      {1:<<<}2121212121212121212121212  |
           ^ a                       |
      {1:~                             }|*3
                                    |
    ]]}
    feed('<C-E>')
    screen:expect{grid=[[
      {1:<<<}  ^ a                       |
      {1:~                             }|*4
                                    |
    ]]}
  end)

  it('before a space with linebreak', function()
    screen:try_resize(50, 6)
    exec([[
      setlocal linebreak showbreak=+ breakindent breakindentopt=shift:2
      call setline(1, repeat('a', 50) .. ' ' .. repeat('c', 45))
      normal! $
    ]])
    api.nvim_buf_set_extmark(0, ns, 0, 50, { virt_text = { { ('b'):rep(10) } }, virt_text_pos = 'inline' })
    screen:expect{grid=[[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
        {1:+}bbbbbbbbbb                                     |
        {1:+}cccccccccccccccccccccccccccccccccccccccccccc^c  |
      {1:~                                                 }|*2
                                                        |
    ]]}
    feed('05x$')
    screen:expect{grid=[[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbb|
        {1:+}bbbbb                                          |
        {1:+}cccccccccccccccccccccccccccccccccccccccccccc^c  |
      {1:~                                                 }|*2
                                                        |
    ]]}
  end)

  it('before double-width char that wraps', function()
    exec([[
      call setline(1, repeat('a', 40) .. '口' .. '12345')
      normal! $
    ]])
    api.nvim_buf_set_extmark(0, ns, 0, 40, { virt_text = { { ('b'):rep(9) } }, virt_text_pos = 'inline' })
    screen:expect{grid=[[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbb{1:>}|
      口1234^5                                           |
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
    screen:add_extra_attr_ids {
        [100] = { foreground = Screen.colors.Blue, background = Screen.colors.Yellow },
    }

    ns = api.nvim_create_namespace 'test'
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
    feed '2gg'
    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
        ^khkey_t *new_keys = (khkey_t *)krealloc((void *)|
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

    api.nvim_buf_set_extmark(0, ns, 1, 33, {
      virt_lines={ {{">> ", "NonText"}, {"krealloc", "Identifier"}, {": change the size of an allocation"}}};
      virt_lines_above=true;
    })

    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
      {1:>> }{25:krealloc}: change the size of an allocation     |
        ^khkey_t *new_keys = (khkey_t *)krealloc((void *)|
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
      {1:>> }{25:krealloc}: change the size of an allocation     |
        khkey_t *new_keys = (khkey_t *){10:^krealloc}((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = {10:krealloc}( h->vals_buf, new_n_|
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
      {1:>> }{25:krealloc}: change the size of an allocation     |
      {10:^krealloc}((void *)h->keys, new_n_buckets * sizeof(k|
      hkey_t));                                         |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = {10:krealloc}( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
      {5:-- INSERT --}                                      |
    ]]}

    feed '<esc>3+'
    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)                 |
      {1:>> }{25:krealloc}: change the size of an allocation     |
      {10:krealloc}((void *)h->keys, new_n_buckets * sizeof(k|
      hkey_t));                                         |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          ^char *new_vals = {10:krealloc}( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        }                                               |
                                                        |
    ]]}

    api.nvim_buf_set_extmark(0, ns, 5, 0, {
      virt_lines = { {{"^^ REVIEW:", "Todo"}, {" new_vals variable seems unnecessary?", "Comment"}} };
    })
    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)                 |
      {1:>> }{25:krealloc}: change the size of an allocation     |
      {10:krealloc}((void *)h->keys, new_n_buckets * sizeof(k|
      hkey_t));                                         |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          ^char *new_vals = {10:krealloc}( h->vals_buf, new_n_|
      buckets * val_size);                              |
      {100:^^ REVIEW:}{18: new_vals variable seems unnecessary?}   |
          h->vals_buf = new_vals;                       |
                                                        |
    ]]}

    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    screen:expect{grid=[[
      if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)                 |
      {10:krealloc}((void *)h->keys, new_n_buckets * sizeof(k|
      hkey_t));                                         |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          ^char *new_vals = {10:krealloc}( h->vals_buf, new_n_|
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

    api.nvim_buf_set_extmark(0, ns, 0, 0, {
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
      {16:refactor(khash): }take size of values as parameter |
      Author: Dev Devsson, {18:Tue Aug 31 10:13:37 2021}     |
      if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
        h->keys = new_keys;                             |
        if (kh_is_map && val_size) {                    |
          char *new_vals = krealloc( h->vals_buf, new_n_|
      buckets * val_size);                              |
          h->vals_buf = new_vals;                       |
        ^}                                               |
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

    local id = api.nvim_buf_set_extmark(0, ns, 7, 0, {
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

    api.nvim_buf_del_extmark(0, ns, id)
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

    local id = api.nvim_buf_set_extmark(0, ns, 8, 0, {
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
      {1:~                                                 }|*3
                                                        |
    ]]}

    feed('dgg')
    screen:expect{grid=[[
      ^                                                  |
      Grugg                                             |
      {1:~                                                 }|*9
      --No lines in buffer--                            |
    ]]}

    api.nvim_buf_del_extmark(0, ns, id)
    screen:expect{grid=[[
      ^                                                  |
      {1:~                                                 }|*10
      --No lines in buffer--                            |
    ]]}
  end)

  it('does not cause syntax ml_get error at the end of a buffer #17816', function()
    command([[syntax region foo keepend start='^foo' end='^$']])
    command('syntax sync minlines=100')
    insert('foo')
    api.nvim_buf_set_extmark(0, ns, 0, 0, {virt_lines = {{{'bar', 'Comment'}}}})
    screen:expect([[
      fo^o                                               |
      {18:bar}                                               |
      {1:~                                                 }|*9
                                                        |
    ]])
  end)

  it('works with a block scrolling up', function()
    screen:try_resize(30, 7)
    insert("aa\nbb\ncc\ndd\nee\nff\ngg\nhh")
    feed 'gg'

    api.nvim_buf_set_extmark(0, ns, 6, 0, {
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
      {16:scrolling}                     |
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      ^ee                            |
      ff                            |
      gg                            |
      they see me                   |
      {16:scrolling}                     |
      they                          |
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      ^ff                            |
      gg                            |
      they see me                   |
      {16:scrolling}                     |
      they                          |
      {16:hatin'}                        |
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      ^gg                            |
      they see me                   |
      {16:scrolling}                     |
      they                          |
      {16:hatin'}                        |
      hh                            |
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      they see me                   |
      {16:scrolling}                     |
      they                          |
      {16:hatin'}                        |
      ^hh                            |
      {1:~                             }|
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      {16:scrolling}                     |
      they                          |
      {16:hatin'}                        |
      ^hh                            |
      {1:~                             }|*2
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      they                          |
      {16:hatin'}                        |
      ^hh                            |
      {1:~                             }|*3
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      {16:hatin'}                        |
      ^hh                            |
      {1:~                             }|*4
                                    |
    ]]}

    feed '<c-e>'
    screen:expect{grid=[[
      ^hh                            |
      {1:~                             }|*5
                                    |
    ]]}
  end)

  it('works with sign and numbercolumns', function()
    insert(example_text2)
    feed 'gg'
    command 'set number signcolumn=yes'
    screen:expect{grid=[[
      {7:  }{8:  1 }^if (h->n_buckets < new_n_buckets) { // expan|
      {7:  }{8:    }d                                           |
      {7:  }{8:  2 }  khkey_t *new_keys = (khkey_t *)krealloc((v|
      {7:  }{8:    }oid *)h->keys, new_n_buckets * sizeof(khkey_|
      {7:  }{8:    }t));                                        |
      {7:  }{8:  3 }  h->keys = new_keys;                       |
      {7:  }{8:  4 }  if (kh_is_map && val_size) {              |
      {7:  }{8:  5 }    char *new_vals = krealloc( h->vals_buf, |
      {7:  }{8:    }new_n_buckets * val_size);                  |
      {7:  }{8:  6 }    h->vals_buf = new_vals;                 |
      {7:  }{8:  7 }  }                                         |
                                                        |
    ]]}

    local markid = api.nvim_buf_set_extmark(0, ns, 2, 0, {
      virt_lines={
        {{"Some special", "Special"}};
        {{"remark about codes", "Comment"}};
      };
    })

    screen:expect{grid=[[
      {7:  }{8:  1 }^if (h->n_buckets < new_n_buckets) { // expan|
      {7:  }{8:    }d                                           |
      {7:  }{8:  2 }  khkey_t *new_keys = (khkey_t *)krealloc((v|
      {7:  }{8:    }oid *)h->keys, new_n_buckets * sizeof(khkey_|
      {7:  }{8:    }t));                                        |
      {7:  }{8:  3 }  h->keys = new_keys;                       |
      {7:  }{8:    }{16:Some special}                                |
      {7:  }{8:    }{18:remark about codes}                          |
      {7:  }{8:  4 }  if (kh_is_map && val_size) {              |
      {7:  }{8:  5 }    char *new_vals = krealloc( h->vals_buf, |
      {7:  }{8:    }new_n_buckets * val_size);                  |
                                                        |
    ]]}

    api.nvim_buf_set_extmark(0, ns, 2, 0, {
      virt_lines={
        {{"Some special", "Special"}};
        {{"remark about codes", "Comment"}};
      };
      virt_lines_leftcol=true;
      id=markid;
    })
    screen:expect{grid=[[
      {7:  }{8:  1 }^if (h->n_buckets < new_n_buckets) { // expan|
      {7:  }{8:    }d                                           |
      {7:  }{8:  2 }  khkey_t *new_keys = (khkey_t *)krealloc((v|
      {7:  }{8:    }oid *)h->keys, new_n_buckets * sizeof(khkey_|
      {7:  }{8:    }t));                                        |
      {7:  }{8:  3 }  h->keys = new_keys;                       |
      {16:Some special}                                      |
      {18:remark about codes}                                |
      {7:  }{8:  4 }  if (kh_is_map && val_size) {              |
      {7:  }{8:  5 }    char *new_vals = krealloc( h->vals_buf, |
      {7:  }{8:    }new_n_buckets * val_size);                  |
                                                        |
    ]]}
  end)


  it('works with hard TABs', function()
    insert(example_text2)
    feed 'gg'
    api.nvim_buf_set_extmark(0, ns, 1, 0, {
      virt_lines={ {{">>", "NonText"}, {"\tvery\ttabby", "Identifier"}, {"text\twith\ttabs"}}};
    })
    screen:expect{grid=[[
      ^if (h->n_buckets < new_n_buckets) { // expand     |
        khkey_t *new_keys = (khkey_t *)krealloc((void *)|
      h->keys, new_n_buckets * sizeof(khkey_t));        |
      {1:>>}{25:      very    tabby}text       with    tabs      |
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
      {1:>>}{25:  very    tabby}text   with    tabs              |
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
      {8:  1 }^if (h->n_buckets < new_n_buckets) { // expand |
      {8:  2 }  khkey_t *new_keys = (khkey_t *)krealloc((voi|
      {8:    }d *)h->keys, new_n_buckets * sizeof(khkey_t));|
      {8:    }{1:>>}{25:  very    tabby}text   with    tabs          |
      {8:  3 }  h->keys = new_keys;                         |
      {8:  4 }  if (kh_is_map && val_size) {                |
      {8:  5 }    char *new_vals = krealloc( h->vals_buf, ne|
      {8:    }w_n_buckets * val_size);                      |
      {8:  6 }    h->vals_buf = new_vals;                   |
      {8:  7 }  }                                           |
      {8:  8 }}                                             |
                                                        |
    ]]}

    command 'set tabstop&'
    screen:expect{grid=[[
      {8:  1 }^if (h->n_buckets < new_n_buckets) { // expand |
      {8:  2 }  khkey_t *new_keys = (khkey_t *)krealloc((voi|
      {8:    }d *)h->keys, new_n_buckets * sizeof(khkey_t));|
      {8:    }{1:>>}{25:      very    tabby}text       with    tabs  |
      {8:  3 }  h->keys = new_keys;                         |
      {8:  4 }  if (kh_is_map && val_size) {                |
      {8:  5 }    char *new_vals = krealloc( h->vals_buf, ne|
      {8:    }w_n_buckets * val_size);                      |
      {8:  6 }    h->vals_buf = new_vals;                   |
      {8:  7 }  }                                           |
      {8:  8 }}                                             |
                                                        |
    ]]}
  end)

  it('does not show twice if end_row or end_col is specified #18622', function()
    screen:try_resize(50, 8)
    insert([[
      aaa
      bbb
      ccc
      ddd]])
    api.nvim_buf_set_extmark(0, ns, 0, 0, {end_row = 2, virt_lines = {{{'VIRT LINE 1', 'NonText'}}}})
    api.nvim_buf_set_extmark(0, ns, 3, 0, {end_col = 2, virt_lines = {{{'VIRT LINE 2', 'NonText'}}}})
    screen:expect{grid=[[
      aaa                                               |
      {1:VIRT LINE 1}                                       |
      bbb                                               |
      ccc                                               |
      dd^d                                               |
      {1:VIRT LINE 2}                                       |
      {1:~                                                 }|
                                                        |
    ]]}
  end)

  it('works with rightleft', function()
    screen:try_resize(50, 8)
    insert([[
      aaa
      bbb
      ccc
      ddd]])
    command('set number rightleft')
    api.nvim_buf_set_extmark(0, ns, 0, 0, {virt_lines = {{{'VIRT LINE 1', 'NonText'}}}, virt_lines_leftcol = true})
    api.nvim_buf_set_extmark(0, ns, 3, 0, {virt_lines = {{{'VIRT LINE 2', 'NonText'}}}})
    screen:expect{grid=[[
                                                 aaa{8: 1  }|
                                             {1:1 ENIL TRIV}|
                                                 bbb{8: 2  }|
                                                 ccc{8: 3  }|
                                                 ^ddd{8: 4  }|
                                         {1:2 ENIL TRIV}{8:    }|
      {1:                                                 ~}|
                                                        |
    ]]}
  end)

  it('works when using dd or yyp #23915 #23916', function()
    insert([[
      line1
      line2
      line3
      line4
      line5]])
    api.nvim_buf_set_extmark(0, ns, 0, 0, {virt_lines={{{"foo"}}, {{"bar"}}, {{"baz"}}}})
    screen:expect{grid=[[
      line1                                             |
      foo                                               |
      bar                                               |
      baz                                               |
      line2                                             |
      line3                                             |
      line4                                             |
      line^5                                             |
      {1:~                                                 }|*3
                                                        |
    ]]}

    feed('gg')
    feed('yyp')
    screen:expect{grid=[[
      line1                                             |
      foo                                               |
      bar                                               |
      baz                                               |
      ^line1                                             |
      line2                                             |
      line3                                             |
      line4                                             |
      line5                                             |
      {1:~                                                 }|*2
                                                        |
    ]]}

    feed('dd')
    screen:expect{grid=[[
      line1                                             |
      foo                                               |
      bar                                               |
      baz                                               |
      ^line2                                             |
      line3                                             |
      line4                                             |
      line5                                             |
      {1:~                                                 }|*3
                                                        |
    ]]}

    feed('kdd')
    screen:expect([[
      ^line2                                             |
      foo                                               |
      bar                                               |
      baz                                               |
      line3                                             |
      line4                                             |
      line5                                             |
      {1:~                                                 }|*4
                                                        |
    ]])
  end)

  it('does not break cursor position with concealcursor #27887', function()
    command('vsplit')
    insert('\n')
    api.nvim_set_option_value('conceallevel', 2, {})
    api.nvim_set_option_value('concealcursor', 'niv', {})
    api.nvim_buf_set_extmark(0, ns, 0, 0, { virt_lines = {{{'VIRT1'}}, {{'VIRT2'}}} })
    screen:expect([[
                               │                        |
      VIRT1                    │VIRT1                   |
      VIRT2                    │VIRT2                   |
      ^                         │                        |
      {1:~                        }│{1:~                       }|*6
      {3:[No Name] [+]             }{2:[No Name] [+]           }|
                                                        |
    ]])
  end)

  it('works with full page scrolling #28290', function()
    screen:try_resize(20, 8)
    command('call setline(1, range(20))')
    api.nvim_buf_set_extmark(0, ns, 10, 0, { virt_lines = {{{'VIRT1'}}, {{'VIRT2'}}} })
    screen:expect([[
      ^0                   |
      1                   |
      2                   |
      3                   |
      4                   |
      5                   |
      6                   |
                          |
    ]])
    feed('<C-F>')
    screen:expect([[
      ^5                   |
      6                   |
      7                   |
      8                   |
      9                   |
      10                  |
      VIRT1               |
                          |
    ]])
    feed('<C-F>')
    screen:expect([[
      ^10                  |
      VIRT1               |
      VIRT2               |
      11                  |
      12                  |
      13                  |
      14                  |
                          |
    ]])
    feed('<C-F>')
    screen:expect([[
      ^13                  |
      14                  |
      15                  |
      16                  |
      17                  |
      18                  |
      19                  |
                          |
    ]])
    feed('<C-B>')
    screen:expect([[
      10                  |
      VIRT1               |
      VIRT2               |
      11                  |
      12                  |
      13                  |
      ^14                  |
                          |
    ]])
    feed('<C-B>')
    screen:expect([[
      5                   |
      6                   |
      7                   |
      8                   |
      9                   |
      ^10                  |
      VIRT1               |
                          |
    ]])
    feed('<C-B>')
    screen:expect([[
      0                   |
      1                   |
      2                   |
      3                   |
      4                   |
      5                   |
      ^6                   |
                          |
    ]])
  end)
end)

describe('decorations: signs', function()
  local screen, ns
  before_each(function()
    clear()
    screen = Screen.new(50, 10)
    screen:attach()
    screen:add_extra_attr_ids {
        [100] = { foreground = Screen.colors.Blue, background = Screen.colors.Yellow },
    }

    ns = api.nvim_create_namespace 'test'
    api.nvim_set_option_value('signcolumn', 'auto:9', {})
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

    api.nvim_buf_set_extmark(0, ns, 1, -1, {sign_text='S'})

    screen:expect{grid=[[
      {7:  }^l1                                              |
      S l2                                              |
      {7:  }l3                                              |
      {7:  }l4                                              |
      {7:  }l5                                              |
      {7:  }                                                |
      {1:~                                                 }|*3
                                                        |
    ]]}
  end)

  it('can add a single sign (with end row)', function()
    insert(example_test3)
    feed 'gg'

    api.nvim_buf_set_extmark(0, ns, 1, -1, {sign_text='S', end_row=1})

    screen:expect{grid=[[
      {7:  }^l1                                              |
      S l2                                              |
      {7:  }l3                                              |
      {7:  }l4                                              |
      {7:  }l5                                              |
      {7:  }                                                |
      {1:~                                                 }|*3
                                                        |
    ]]}
  end)

  it('can add a single sign and text highlight', function()
    insert(example_test3)
    feed 'gg'

    api.nvim_buf_set_extmark(0, ns, 1, 0, {sign_text='S', hl_group='Todo', end_col=1})
    screen:expect{grid=[[
      {7:  }^l1                                              |
      S {100:l}2                                              |
      {7:  }l3                                              |
      {7:  }l4                                              |
      {7:  }l5                                              |
      {7:  }                                                |
      {1:~                                                 }|*3
                                                        |
    ]]}

    api.nvim_buf_clear_namespace(0, ns, 0, -1)
  end)

  it('can add multiple signs (single extmark)', function()
    insert(example_test3)
    feed 'gg'

    api.nvim_buf_set_extmark(0, ns, 1, -1, {sign_text='S', end_row = 2})

    screen:expect{grid=[[
      {7:  }^l1                                              |
      S l2                                              |
      S l3                                              |
      {7:  }l4                                              |
      {7:  }l5                                              |
      {7:  }                                                |
      {1:~                                                 }|*3
                                                        |
    ]]}
  end)

  it('can add multiple signs (multiple extmarks)', function()
    insert(example_test3)
    feed'gg'

    api.nvim_buf_set_extmark(0, ns, 1, -1, {sign_text='S1'})
    api.nvim_buf_set_extmark(0, ns, 3, -1, {sign_text='S2', end_row = 4})

    screen:expect{grid=[[
      {7:  }^l1                                              |
      S1l2                                              |
      {7:  }l3                                              |
      S2l4                                              |
      S2l5                                              |
      {7:  }                                                |
      {1:~                                                 }|*3
                                                        |
    ]]}
  end)

  it('can add multiple signs (multiple extmarks) 2', function()
    insert(example_test3)
    feed 'gg'

    api.nvim_buf_set_extmark(0, ns, 3, -1, {sign_text='S1'})
    api.nvim_buf_set_extmark(0, ns, 1, -1, {sign_text='S2', end_row = 3})
    screen:expect{grid=[[
      {7:    }^l1                                            |
      S2{7:  }l2                                            |
      S2{7:  }l3                                            |
      S2S1l4                                            |
      {7:    }l5                                            |
      {7:    }                                              |
      {1:~                                                 }|*3
                                                        |
    ]]}
  end)

  it('can add multiple signs (multiple extmarks) 3', function()

    insert(example_test3)
    feed 'gg'

    api.nvim_buf_set_extmark(0, ns, 1, -1, {sign_text='S1', end_row=2})
    api.nvim_buf_set_extmark(0, ns, 2, -1, {sign_text='S2', end_row=3})

    screen:expect{grid=[[
      {7:    }^l1                                            |
      S1{7:  }l2                                            |
      S2S1l3                                            |
      S2{7:  }l4                                            |
      {7:    }l5                                            |
      {7:    }                                              |
      {1:~                                                 }|*3
                                                        |
    ]]}
  end)

  it('can add multiple signs (multiple extmarks) 4', function()
    insert(example_test3)
    feed 'gg'

    api.nvim_buf_set_extmark(0, ns, 0, -1, {sign_text='S1', end_row=0})
    api.nvim_buf_set_extmark(0, ns, 1, -1, {sign_text='S2', end_row=1})

    screen:expect{grid=[[
      S1^l1                                              |
      S2l2                                              |
      {7:  }l3                                              |
      {7:  }l4                                              |
      {7:  }l5                                              |
      {7:  }                                                |
      {1:~                                                 }|*3
                                                        |
    ]]}
  end)

  it('works with old signs', function()
    insert(example_test3)
    feed 'gg'

    n.command('sign define Oldsign text=x')
    n.command([[exe 'sign place 42 line=2 name=Oldsign buffer=' . bufnr('')]])

    api.nvim_buf_set_extmark(0, ns, 0, -1, {sign_text='S1'})
    api.nvim_buf_set_extmark(0, ns, 1, -1, {sign_text='S2'})
    api.nvim_buf_set_extmark(0, ns, 0, -1, {sign_text='S4'})
    api.nvim_buf_set_extmark(0, ns, 2, -1, {sign_text='S5'})

    screen:expect{grid=[[
      S4S1^l1                                            |
      S2x l2                                            |
      S5{7:  }l3                                            |
      {7:    }l4                                            |
      {7:    }l5                                            |
      {7:    }                                              |
      {1:~                                                 }|*3
                                                        |
    ]]}
  end)

  it('works with old signs (with range)', function()
    insert(example_test3)
    feed 'gg'

    n.command('sign define Oldsign text=x')
    n.command([[exe 'sign place 42 line=2 name=Oldsign buffer=' . bufnr('')]])

    api.nvim_buf_set_extmark(0, ns, 0, -1, {sign_text='S1'})
    api.nvim_buf_set_extmark(0, ns, 1, -1, {sign_text='S2'})
    api.nvim_buf_set_extmark(0, ns, 0, -1, {sign_text='S3', end_row = 4})
    api.nvim_buf_set_extmark(0, ns, 0, -1, {sign_text='S4'})
    api.nvim_buf_set_extmark(0, ns, 2, -1, {sign_text='S5'})

    screen:expect{grid=[[
      S4S3S1^l1                                          |
      S3S2x l2                                          |
      S5S3{7:  }l3                                          |
      S3{7:    }l4                                          |
      S3{7:    }l5                                          |
      {7:      }                                            |
      {1:~                                                 }|*3
                                                        |
    ]]}
  end)

  it('can add a ranged sign (with start out of view)', function()
    insert(example_test3)
    command 'set signcolumn=yes:2'
    feed 'gg'
    feed '2<C-e>'

    api.nvim_buf_set_extmark(0, ns, 1, -1, {sign_text='X', end_row=3})

    screen:expect{grid=[[
      X {7:  }^l3                                            |
      X {7:  }l4                                            |
      {7:    }l5                                            |
      {7:    }                                              |
      {1:~                                                 }|*5
                                                        |
    ]]}
  end)

  it('can add lots of signs', function()
    screen:try_resize(40, 10)
    command 'normal 10oa b c d e f g h'

    for i = 1, 10 do
      api.nvim_buf_set_extmark(0, ns, i,  0, { end_col =  1, hl_group='Todo' })
      api.nvim_buf_set_extmark(0, ns, i,  2, { end_col =  3, hl_group='Todo' })
      api.nvim_buf_set_extmark(0, ns, i,  4, { end_col =  5, hl_group='Todo' })
      api.nvim_buf_set_extmark(0, ns, i,  6, { end_col =  7, hl_group='Todo' })
      api.nvim_buf_set_extmark(0, ns, i,  8, { end_col =  9, hl_group='Todo' })
      api.nvim_buf_set_extmark(0, ns, i, 10, { end_col = 11, hl_group='Todo' })
      api.nvim_buf_set_extmark(0, ns, i, 12, { end_col = 13, hl_group='Todo' })
      api.nvim_buf_set_extmark(0, ns, i, 14, { end_col = 15, hl_group='Todo' })
      api.nvim_buf_set_extmark(0, ns, i, -1, { sign_text='W' })
      api.nvim_buf_set_extmark(0, ns, i, -1, { sign_text='X' })
      api.nvim_buf_set_extmark(0, ns, i, -1, { sign_text='Y' })
      api.nvim_buf_set_extmark(0, ns, i, -1, { sign_text='Z' })
    end

    screen:expect{grid=[[
      Z Y X W {100:a} {100:b} {100:c} {100:d} {100:e} {100:f} {100:g} {100:h}                 |*8
      Z Y X W {100:a} {100:b} {100:c} {100:d} {100:e} {100:f} {100:g} {100:^h}                 |
                                              |
    ]]}
  end)

  it('works with priority #19716', function()
    screen:try_resize(20, 3)
    insert(example_test3)
    feed 'gg'

    command('sign define Oldsign text=O3')
    command([[exe 'sign place 42 line=1 name=Oldsign priority=10 buffer=' . bufnr('')]])

    api.nvim_buf_set_extmark(0, ns, 0, -1, {sign_text='S4', priority=100})
    api.nvim_buf_set_extmark(0, ns, 0, -1, {sign_text='S2', priority=5})
    api.nvim_buf_set_extmark(0, ns, 0, -1, {sign_text='S5', priority=200})
    api.nvim_buf_set_extmark(0, ns, 0, -1, {sign_text='S1', priority=1})

    screen:expect{grid=[[
      S5S4O3S2S1^l1        |
      {7:          }l2        |
                          |
    ]]}

    -- Check truncation works too
    api.nvim_set_option_value('signcolumn', 'auto', {})

    screen:expect{grid=[[
      S5^l1                |
      {7:  }l2                |
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
      {1:~                   }|
                          |
    ]]}

    api.nvim_buf_set_extmark(0, ns, 0, -1, {sign_text='S1', priority=1})
    screen:expect_unchanged()

    api.nvim_buf_set_extmark(0, ns, 0, -1, {sign_text='S5', priority=200})
    screen:expect{grid=[[
      S5O3O3O3O3O3O3O3O3^  |
      {1:~                   }|
                          |
    ]]}

    assert_alive()
  end)

  it('does not set signcolumn for signs without text', function()
    screen:try_resize(20, 3)
    api.nvim_set_option_value('signcolumn', 'auto', {})
    insert(example_test3)
    feed 'gg'
    api.nvim_buf_set_extmark(0, ns, 0, -1, {number_hl_group='Error'})
    screen:expect{grid=[[
      ^l1                  |
      l2                  |
                          |
    ]]}
  end)

  it('correct width when removing multiple signs from sentinel line', function()
    screen:try_resize(20, 4)
    insert(example_test3)
    api.nvim_buf_set_extmark(0, ns, 0, -1, {sign_text='S1', end_row=3})
    api.nvim_buf_set_extmark(0, ns, 1, -1, {invalidate = true, sign_text='S2'})
    api.nvim_buf_set_extmark(0, ns, 1, -1, {invalidate = true, sign_text='S3'})
    feed('2Gdd')

    screen:expect{grid=[[
      S1l1                |
      S1^l3                |
      S1l4                |
                          |
    ]]}
  end)

  it('correct width with multiple overlapping signs', function()
    screen:try_resize(20, 4)
    insert(example_test3)
    api.nvim_buf_set_extmark(0, ns, 0, -1, {sign_text='S1'})
    api.nvim_buf_set_extmark(0, ns, 0, -1, {sign_text='S2', end_row=2})
    api.nvim_buf_set_extmark(0, ns, 1, -1, {sign_text='S3', end_row=2})
    feed('gg')

    local s1 = [[
      S2S1^l1              |
      S3S2l2              |
      S3S2l3              |
                          |
    ]]
    screen:expect{grid=s1}
    -- Correct width when :move'ing a line with signs
    command('move2')
    screen:expect{grid=[[
      S3{7:    }l2            |
      S3S2S1^l1            |
      {7:      }l3            |
                          |
    ]]}
    command('silent undo')
    screen:expect{grid=s1}
    command('d')
    screen:expect{grid=[[
      S3S2S1^l2            |
      S3S2{7:  }l3            |
      {7:      }l4            |
                          |
    ]]}
    command('d')
    screen:expect{grid=[[
      S3S2S1^l3            |
      {7:      }l4            |
      {7:      }l5            |
                          |
    ]]}
  end)

  it('correct width when adding and removing multiple signs', function()
    screen:try_resize(20, 4)
    insert(example_test3)
    feed('gg')
    command([[
      let ns = nvim_create_namespace('')
      call nvim_buf_set_extmark(0, ns, 0, 0, {'sign_text':'S1', 'end_row':3})
      let s1 = nvim_buf_set_extmark(0, ns, 2, 0, {'sign_text':'S2', 'end_row':4})
      let s2 = nvim_buf_set_extmark(0, ns, 5, 0, {'sign_text':'S3'})
      let s3 = nvim_buf_set_extmark(0, ns, 6, 0, {'sign_text':'S3'})
      let s4 = nvim_buf_set_extmark(0, ns, 5, 0, {'sign_text':'S3'})
      let s5 = nvim_buf_set_extmark(0, ns, 6, 0, {'sign_text':'S3'})
      redraw!
      call nvim_buf_del_extmark(0, ns, s2)
      call nvim_buf_del_extmark(0, ns, s3)
      call nvim_buf_del_extmark(0, ns, s4)
      call nvim_buf_del_extmark(0, ns, s5)
      redraw!
      call nvim_buf_del_extmark(0, ns, s1)
    ]])
    screen:expect{grid=[[
      S1^l1                |
      S1l2                |
      S1l3                |
                          |
    ]]}
  end)

  it('correct width when deleting lines', function()
    screen:try_resize(20, 4)
    insert(example_test3)
    feed('gg')
    command([[
      let ns = nvim_create_namespace('')
      call nvim_buf_set_extmark(0, ns, 4, 0, {'sign_text':'S1'})
      call nvim_buf_set_extmark(0, ns, 4, 0, {'sign_text':'S2'})
      let s3 =  nvim_buf_set_extmark(0, ns, 5, 0, {'sign_text':'S3'})
      call nvim_buf_del_extmark(0, ns, s3)
      norm 4Gdd
    ]])
    screen:expect{grid=[[
      {7:    }l3              |
      S2S1l5              |
      {7:    }^                |
                          |
    ]]}
  end)

  it('correct width when splitting lines with signs on different columns', function()
    screen:try_resize(20, 4)
    insert(example_test3)
    feed('gg')
    api.nvim_buf_set_extmark(0, ns, 0, 0, {sign_text='S1'})
    api.nvim_buf_set_extmark(0, ns, 0, 1, {sign_text='S2'})
    feed('a<cr><esc>')
    screen:expect{grid=[[
      S1l                 |
      S2^1                 |
      {7:  }l2                |
                          |
    ]]}
  end)

  it('correct width after wiping a buffer', function()
    screen:try_resize(20, 4)
    insert(example_test3)
    feed('gg')
    local buf = api.nvim_get_current_buf()
    api.nvim_buf_set_extmark(buf, ns, 0, 0, { sign_text = 'h' })
    screen:expect{grid=[[
      h ^l1                |
      {7:  }l2                |
      {7:  }l3                |
                          |
    ]]}
    api.nvim_win_set_buf(0, api.nvim_create_buf(false, true))
    api.nvim_buf_delete(buf, {unload=true, force=true})
    api.nvim_buf_set_lines(buf, 0, -1, false, {''})
    api.nvim_win_set_buf(0, buf)
    screen:expect{grid=[[
      ^                    |
      {1:~                   }|*2
                          |
    ]]}
  end)

  it('correct width with moved marks before undo savepos', function()
    screen:try_resize(20, 4)
    insert(example_test3)
    feed('gg')
    exec_lua([[
      local ns = vim.api.nvim_create_namespace('')
      vim.api.nvim_buf_set_extmark(0, ns, 0, 0, { sign_text = 'S1' })
      vim.api.nvim_buf_set_extmark(0, ns, 1, 0, { sign_text = 'S2' })
      local s3 = vim.api.nvim_buf_set_extmark(0, ns, 2, 0, { sign_text = 'S3' })
      local s4 = vim.api.nvim_buf_set_extmark(0, ns, 2, 0, { sign_text = 'S4' })
      vim.schedule(function()
        vim.cmd('silent d3')
        vim.api.nvim_buf_set_extmark(0, ns, 2, 0, { id = s3, sign_text = 'S3' })
        vim.api.nvim_buf_set_extmark(0, ns, 2, 0, { id = s4, sign_text = 'S4' })
        vim.cmd('silent undo')
        vim.api.nvim_buf_del_extmark(0, ns, s3)
      end)
    ]])

    screen:expect{grid=[[
      S1^l1                |
      S2l2                |
      S4l3                |
                          |
    ]]}
  end)

  it('no crash with sign after many marks #27137', function()
    screen:try_resize(20, 4)
    insert('a')
    for _ = 0, 104 do
      api.nvim_buf_set_extmark(0, ns, 0, 0, {hl_group = 'Error', end_col = 1})
    end
    api.nvim_buf_set_extmark(0, ns, 0, 0, {sign_text = 'S1'})

    screen:expect{grid=[[
      S1{9:^a}                 |
      {1:~                   }|*2
                          |
    ]]}
  end)

  it('correct sort order with multiple namespaces and same id', function()
    local ns2 = api.nvim_create_namespace('')
    api.nvim_buf_set_extmark(0, ns, 0, 0, {sign_text = 'S1', id = 1})
    api.nvim_buf_set_extmark(0, ns2, 0, 0, {sign_text = 'S2', id = 1})

    screen:expect{grid=[[
      S2S1^                                              |
      {1:~                                                 }|*8
                                                        |
    ]]}
  end)

  it('correct number of signs after deleting text (#27046)', function()
    command('call setline(1, ["foo"]->repeat(31))')
    api.nvim_buf_set_extmark(0, ns, 0, 0, {end_row = 0, sign_text = 'S1'})
    api.nvim_buf_set_extmark(0, ns, 0, 0, {end_row = 0, end_col = 3, hl_group = 'Error'})
    api.nvim_buf_set_extmark(0, ns, 9, 0, {end_row = 9,  sign_text = 'S2'})
    api.nvim_buf_set_extmark(0, ns, 9, 0, {end_row = 9, end_col = 3, hl_group = 'Error'})
    api.nvim_buf_set_extmark(0, ns, 19, 0, {end_row = 19, sign_text = 'S3'})
    api.nvim_buf_set_extmark(0, ns, 19, 0, {end_row = 19, end_col = 3, hl_group = 'Error'})
    api.nvim_buf_set_extmark(0, ns, 29, 0, {end_row = 29, sign_text = 'S4'})
    api.nvim_buf_set_extmark(0, ns, 29, 0, {end_row = 29, end_col = 3, hl_group = 'Error'})
    api.nvim_buf_set_extmark(0, ns, 30, 0, {end_row = 30, sign_text = 'S5'})
    api.nvim_buf_set_extmark(0, ns, 30, 0, {end_row = 30, end_col = 3, hl_group = 'Error'})
    command('0d29')

    screen:expect{grid=[[
      S4S3S2S1{9:^foo}                                       |
      S5{7:      }{9:foo}                                       |
      {1:~                                                 }|*7
      29 fewer lines                                    |
    ]]}

    api.nvim_buf_clear_namespace(0, ns, 0, -1)
  end)

  it([[correct numberwidth with 'signcolumn' set to "number" #28984]], function()
    command('set number numberwidth=1 signcolumn=number')
    api.nvim_buf_set_extmark(0, ns, 0, 0, { sign_text = 'S1' })
    screen:expect({
      grid = [[
        S1 ^                                               |
        {1:~                                                 }|*8
                                                          |
      ]]
    })
    api.nvim_buf_del_extmark(0, ns, 1)
    screen:expect({
      grid = [[
        {8:1 }^                                                |
        {1:~                                                 }|*8
                                                          |
      ]]
    })
  end)
end)

describe('decorations: virt_text', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 10)
    screen:attach()
  end)

  it('avoids regression in #17638', function()
    exec_lua[[
      vim.wo.number = true
      vim.wo.relativenumber = true
    ]]

    command 'normal 4ohello'
    command 'normal aVIRTUAL'

    local ns = api.nvim_create_namespace('test')

    api.nvim_buf_set_extmark(0, ns, 2, 0, {
      virt_text = {{"hello", "String"}},
      virt_text_win_col = 20,
    })

    screen:expect{grid=[[
      {8:  4 }                                              |
      {8:  3 }hello                                         |
      {8:  2 }hello               {26:hello}                     |
      {8:  1 }hello                                         |
      {8:5   }helloVIRTUA^L                                  |
      {1:~                                                 }|*4
                                                        |
    ]]}

    -- Trigger a screen update
    feed('k')

    screen:expect{grid=[[
      {8:  3 }                                              |
      {8:  2 }hello                                         |
      {8:  1 }hello               {26:hello}                     |
      {8:4   }hell^o                                         |
      {8:  1 }helloVIRTUAL                                  |
      {1:~                                                 }|*4
                                                        |
    ]]}
  end)

  it('redraws correctly when re-using extmark ids', function()
    command 'normal 5ohello'

    screen:expect{grid=[[
                                                        |
      hello                                             |*4
      hell^o                                             |
      {1:~                                                 }|*3
                                                        |
    ]]}

    local ns = api.nvim_create_namespace('ns')
    for row = 1, 5 do
      api.nvim_buf_set_extmark(0, ns, row, 0, { id = 1, virt_text = {{'world', 'Normal'}} })
    end

    screen:expect{grid=[[
                                                        |
      hello                                             |*4
      hell^o world                                       |
      {1:~                                                 }|*3
                                                        |
    ]]}
  end)
end)

describe('decorations: window scoped', function()
  local screen, ns, win_other
  local url = 'https://example.com'
  before_each(function()
    clear()
    screen = Screen.new(20, 10)
    screen:attach()
    screen:add_extra_attr_ids {
      [100] = { special = Screen.colors.Red, undercurl = true },
      [101] = { url = 'https://example.com' },
    }

    ns = api.nvim_create_namespace 'test'

    insert('12345')

    win_other = api.nvim_open_win(0, false, {
      col=0,row=0,width=20,height=10,
      relative = 'win',style = 'minimal',
      hide = true
    })
  end)

  local noextmarks = {
    grid = [[
      1234^5               |
      {1:~                   }|*8
                          |
    ]],
  }

  local function set_extmark(line, col, opts)
    return api.nvim_buf_set_extmark(0, ns, line, col, opts)
  end

  it('hl_group', function()
    set_extmark(0, 0, {
      hl_group = 'Comment',
      end_col = 3,
    })

    api.nvim__ns_set(ns, { wins = { 0 } })

    screen:expect {
      grid = [[
      {18:123}4^5               |
      {1:~                   }|*8
                          |
    ]],
    }

    command 'split'
    command 'only'

    screen:expect(noextmarks)
  end)

  it('virt_text', function()
    set_extmark(0, 0, {
      virt_text = { { 'a', 'Comment' } },
      virt_text_pos = 'eol',
    })
    set_extmark(0, 5, {
      virt_text = { { 'b', 'Comment' } },
      virt_text_pos = 'inline',
    })
    set_extmark(0, 1, {
      virt_text = { { 'c', 'Comment' } },
      virt_text_pos = 'overlay',
    })
    set_extmark(0, 1, {
      virt_text = { { 'd', 'Comment' } },
      virt_text_pos = 'right_align',
    })

    api.nvim__ns_set(ns, { wins = { 0 } })

    screen:expect {
      grid = [[
      1{18:c}34^5{18:b} {18:a}           {18:d}|
      {1:~                   }|*8
                          |
    ]],
    }

    command 'split'
    command 'only'

    screen:expect(noextmarks)

    api.nvim__ns_set(ns, { wins = {} })

    screen:expect {
      grid = [[
      1{18:c}34^5{18:b} {18:a}           {18:d}|
      {1:~                   }|*8
                          |
    ]],
    }
  end)

  it('virt_lines', function()
    set_extmark(0, 0, {
      virt_lines = { { { 'a', 'Comment' } } },
    })

    api.nvim__ns_set(ns, { wins = { 0 } })

    screen:expect {
      grid = [[
      1234^5               |
      {18:a}                   |
      {1:~                   }|*7
                          |
    ]],
    }

    command 'split'
    command 'only'

    screen:expect(noextmarks)
  end)

  it('redraws correctly with inline virt_text and wrapping', function()
    set_extmark(0, 2, {
      virt_text = { { ('b'):rep(18), 'Comment' } },
      virt_text_pos = 'inline',
    })

    api.nvim__ns_set(ns, { wins = { 0 } })

    screen:expect {
      grid = [[
      12{18:bbbbbbbbbbbbbbbbbb}|
      34^5                 |
      {1:~                   }|*7
                          |
    ]],
    }

    api.nvim__ns_set(ns, { wins = { win_other } })

    screen:expect(noextmarks)
  end)

  pending('sign_text', function()
    -- TODO(altermo): The window signcolumn width is calculated wrongly (when `signcolumn=auto`)
    -- This happens in function `win_redraw_signcols` on line containing `buf_meta_total(buf, kMTMetaSignText) > 0`
    set_extmark(0, 0, {
      sign_text = 'a',
      sign_hl_group = 'Comment',
    })

    api.nvim__ns_set(ns, { wins = { 0 } })

    screen:expect {
      grid = [[
      a 1234^5             |
      {2:~                   }|*8
                          |
    ]],
    }

    command 'split'
    command 'only'

    screen:expect(noextmarks)
  end)

  it('statuscolumn hl group', function()
    set_extmark(0, 0, {
      number_hl_group = 'comment',
    })
    set_extmark(0, 0, {
      line_hl_group = 'comment',
    })

    command 'set number'

    api.nvim__ns_set(ns, { wins = { win_other } })

    screen:expect {
      grid = [[
      {8:  1 }1234^5           |
      {1:~                   }|*8
                          |
    ]],
    }

    api.nvim__ns_set(ns, { wins = { 0 } })

    screen:expect {
      grid = [[
      {18:  1 1234^5           }|
      {1:~                   }|*8
                          |
    ]],
    }

    command 'split'
    command 'only'

    screen:expect {
      grid = [[
      {8:  1 }1234^5           |
      {1:~                   }|*8
                          |
    ]],
    }
  end)

  it('spell', function()
    api.nvim_buf_set_lines(0, 0, -1, true, { 'aa' })

    set_extmark(0, 0, {
      spell = true,
      end_col = 2,
    })

    command 'set spelloptions=noplainbuffer'
    command 'set spell'
    command 'syntax off'

    screen:expect({ unchanged = true })

    api.nvim__ns_set(ns, { wins = { win_other } })

    screen:expect {
      grid = [[
      a^a                  |
      {1:~                   }|*8
                          |
    ]],
    }

    api.nvim__ns_set(ns, { wins = { 0 } })

    screen:expect {
      grid = [[
      {100:a^a}                  |
      {1:~                   }|*8
                          |
    ]],
    }

    command 'split'
    command 'only'

    screen:expect {
      grid = [[
      a^a                  |
      {1:~                   }|*8
                          |
    ]],
    }
  end)

  it('url', function()
    set_extmark(0, 0, {
      end_col = 3,
      url = url,
    })

    api.nvim__ns_set(ns, { wins = { 0 } })

    screen:expect {
      grid = [[
      {101:123}4^5               |
      {1:~                   }|*8
                          |
    ]],
    }

    command 'split'
    command 'only'

    screen:expect(noextmarks)
  end)

  it('change namespace scope', function()
    set_extmark(0, 0, {
      hl_group = 'Comment',
      end_col = 3,
    })

    api.nvim__ns_set(ns, { wins = { 0 } })
    eq({ wins={ api.nvim_get_current_win() } }, api.nvim__ns_get(ns))

    screen:expect {
      grid = [[
      {18:123}4^5               |
      {1:~                   }|*8
                          |
    ]],
    }

    command 'split'
    command 'only'

    screen:expect(noextmarks)

    api.nvim__ns_set(ns, { wins = { 0 } })
    eq({ wins={ api.nvim_get_current_win() } }, api.nvim__ns_get(ns))

    screen:expect {
      grid = [[
      {18:123}4^5               |
      {1:~                   }|*8
                          |
    ]],
    }

    local win_new = api.nvim_open_win(0, false, {
      col=0,row=0,width=20,height=10,
      relative = 'win',style = 'minimal',
      hide = true
    })

    api.nvim__ns_set(ns, { wins = { win_new } })
    eq({ wins={ win_new } }, api.nvim__ns_get(ns))

    screen:expect(noextmarks)
  end)

  it('namespace get works', function()
    eq({ wins = {} }, api.nvim__ns_get(ns))

    api.nvim__ns_set(ns, { wins = { 0 } })

    eq({ wins = { api.nvim_get_current_win() } }, api.nvim__ns_get(ns))

    api.nvim__ns_set(ns, { wins = {} })

    eq({ wins = {} }, api.nvim__ns_get(ns))
  end)

  it('remove window from namespace scope when deleted', function ()
    api.nvim__ns_set(ns, { wins = { 0 } })

    eq({ wins = { api.nvim_get_current_win() } }, api.nvim__ns_get(ns))

    command 'split'
    command 'only'

    eq({ wins = {} }, api.nvim__ns_get(ns))
  end)
end)

