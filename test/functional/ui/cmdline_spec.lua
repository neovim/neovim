local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, eq = helpers.clear, helpers.feed, helpers.eq
local source = helpers.source
local ok = helpers.ok
local command = helpers.command

if helpers.pending_win32(pending) then return end

describe('external cmdline', function()
  local screen
  local last_level = 0
  local cmdline = {}
  local block = nil

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach({rgb=true, ext_cmdline=true})
    screen:set_on_event_handler(function(name, data)
      if name == "cmdline_show" then
        local content, pos, firstc, prompt, indent, level = unpack(data)
        ok(level > 0)
        cmdline[level] = {content=content, pos=pos, firstc=firstc,
                          prompt=prompt, indent=indent}
        last_level = level
      elseif name == "cmdline_hide" then
        local level = data[1]
        cmdline[level] = nil
      elseif name == "cmdline_special_char" then
        local char, shift, level = unpack(data)
        cmdline[level].special = {char, shift}
      elseif name == "cmdline_pos" then
        local pos, level = unpack(data)
        cmdline[level].pos = pos
      elseif name == "cmdline_block_show" then
        block = data[1]
      elseif name == "cmdline_block_append" then
        block[#block+1] = data[1]
      elseif name == "cmdline_block_hide" then
        block = nil
      end
    end)
  end)

  after_each(function()
    screen:detach()
  end)

  local function expect_cmdline(level, expected)
    local attr_ids = screen._default_attr_ids
    local attr_ignore = screen._default_attr_ignore
    local actual = ''
    for _, chunk in ipairs(cmdline[level] and cmdline[level].content or {}) do
      local attrs, text = chunk[1], chunk[2]
      if screen:_equal_attrs(attrs, {}) then
        actual = actual..text
      else
        local attr_id = screen:_get_attr_id(attr_ids, attr_ignore, attrs)
        actual =  actual..'{' .. attr_id .. ':' .. text .. '}'
      end
    end
    eq(expected, actual)
  end

  it('works', function()
    feed(':')
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], nil, nil, function()
      eq(1, last_level)
      eq({{
        content = { { {}, "" } },
        firstc = ":",
        indent = 0,
        pos = 0,
        prompt = ""
      }}, cmdline)
    end)

    feed('sign')
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], nil, nil, function()
      eq({{
        content = { { {}, "sign" } },
        firstc = ":",
        indent = 0,
        pos = 4,
        prompt = ""
      }}, cmdline)
    end)

    feed('<Left>')
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], nil, nil, function()
      eq({{
        content = { { {}, "sign" } },
        firstc = ":",
        indent = 0,
        pos = 3,
        prompt = ""
      }}, cmdline)
    end)

    feed('<bs>')
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], nil, nil, function()
      eq({{
        content = { { {}, "sin" } },
        firstc = ":",
        indent = 0,
        pos = 2,
        prompt = ""
      }}, cmdline)
    end)

    feed('<Esc>')
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], nil, nil, function()
      eq({}, cmdline)
    end)
  end)

  it("works with input()", function()
    feed(':call input("input", "default")<cr>')
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], nil, nil, function()
      eq({{
        content = { { {}, "default" } },
        firstc = "",
        indent = 0,
        pos = 7,
        prompt = "input"
      }}, cmdline)
    end)
    feed('<cr>')
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], nil, nil, function()
      eq({}, cmdline)
    end)

  end)

  it("works with special chars and nested cmdline", function()
    feed(':xx<c-r>')
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], nil, nil, function()
      eq({{
        content = { { {}, "xx" } },
        firstc = ":",
        indent = 0,
        pos = 2,
        prompt = "",
        special = {'"', true},
      }}, cmdline)
    end)

    feed('=')
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], nil, nil, function()
      eq({{
        content = { { {}, "xx" } },
        firstc = ":",
        indent = 0,
        pos = 2,
        prompt = "",
        special = {'"', true},
      },{
        content = { { {}, "" } },
        firstc = "=",
        indent = 0,
        pos = 0,
        prompt = "",
      }}, cmdline)
    end)

    feed('1+2')
    local expectation = {{
        content = { { {}, "xx" } },
        firstc = ":",
        indent = 0,
        pos = 2,
        prompt = "",
        special = {'"', true},
      },{
        content = { { {}, "1+2" } },
        firstc = "=",
        indent = 0,
        pos = 3,
        prompt = "",
      }}
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], nil, nil, function()
      eq(expectation, cmdline)
    end)

    -- erase information, so we check if it is retransmitted
    cmdline = {}
    command("redraw!")
    -- redraw! forgets cursor position. Be OK with that, as UI should indicate
    -- focus is at external cmdline anyway.
    screen:expect([[
                               |
      ~                        |
      ~                        |
      ~                        |
      ^                         |
    ]], nil, nil, function()
      eq(expectation, cmdline)
    end)


    feed('<cr>')
    screen:expect([[
                               |
      ~                        |
      ~                        |
      ~                        |
      ^                         |
    ]], nil, nil, function()
      eq({{
        content = { { {}, "xx3" } },
        firstc = ":",
        indent = 0,
        pos = 3,
        prompt = "",
      }}, cmdline)
    end)

    feed('<esc>')
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], nil, nil, function()
      eq({}, cmdline)
    end)
  end)

  it("works with function definitions", function()
    feed(':function Foo()<cr>')
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], nil, nil, function()
      eq({{
        content = { { {}, "" } },
        firstc = ":",
        indent = 2,
        pos = 0,
        prompt = "",
      }}, cmdline)
      eq({{{{}, 'function Foo()'}}}, block)
    end)

    feed('line1<cr>')
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], nil, nil, function()
      eq({{{{}, 'function Foo()'}},
          {{{}, '  line1'}}}, block)
    end)

    block = {}
    command("redraw!")
    screen:expect([[
                               |
      ~                        |
      ~                        |
      ~                        |
      ^                         |
    ]], nil, nil, function()
      eq({{{{}, 'function Foo()'}},
          {{{}, '  line1'}}}, block)
    end)


    feed('endfunction<cr>')
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], nil, nil, function()
      eq(nil, block)
    end)
  end)

  it("works with cmdline window", function()
    feed(':make')
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], nil, nil, function()
      eq({{
        content = { { {}, "make" } },
        firstc = ":",
        indent = 0,
        pos = 4,
        prompt = ""
      }}, cmdline)
    end)

    feed('<c-f>')
    screen:expect([[
                               |
      [No Name]                |
      :make^                    |
      [Command Line]           |
                               |
    ]], nil, nil, function()
      eq({}, cmdline)
    end)

    -- nested cmdline
    feed(':yank')
    screen:expect([[
                               |
      [No Name]                |
      :make^                    |
      [Command Line]           |
                               |
    ]], nil, nil, function()
      eq({nil, {
        content = { { {}, "yank" } },
        firstc = ":",
        indent = 0,
        pos = 4,
        prompt = ""
      }}, cmdline)
    end)

    cmdline = {}
    command("redraw!")
    screen:expect([[
                               |
      [No Name]                |
      :make                    |
      [Command Line]           |
      ^                         |
    ]], nil, nil, function()
      eq({nil, {
        content = { { {}, "yank" } },
        firstc = ":",
        indent = 0,
        pos = 4,
        prompt = ""
      }}, cmdline)
    end)

    feed("<c-c>")
    screen:expect([[
                               |
      [No Name]                |
      :make^                    |
      [Command Line]           |
                               |
    ]], nil, nil, function()
      eq({}, cmdline)
    end)

    feed("<c-c>")
    screen:expect([[
                               |
      [No Name]                |
      :make^                    |
      [Command Line]           |
                               |
    ]], nil, nil, function()
      eq({{
        content = { { {}, "make" } },
        firstc = ":",
        indent = 0,
        pos = 4,
        prompt = ""
      }}, cmdline)
    end)

    cmdline = {}
    command("redraw!")
    screen:expect([[
                               |
      ~                        |
      ~                        |
      ~                        |
      ^                         |
    ]], nil, nil, function()
      eq({{
        content = { { {}, "make" } },
        firstc = ":",
        indent = 0,
        pos = 4,
        prompt = ""
      }}, cmdline)
    end)
  end)

  it('works with highlighted cmdline', function()
      source([[
        highlight RBP1 guibg=Red
        highlight RBP2 guibg=Yellow
        highlight RBP3 guibg=Green
        highlight RBP4 guibg=Blue
        let g:NUM_LVLS = 4
        function RainBowParens(cmdline)
          let ret = []
          let i = 0
          let lvl = 0
          while i < len(a:cmdline)
            if a:cmdline[i] is# '('
              call add(ret, [i, i + 1, 'RBP' . ((lvl % g:NUM_LVLS) + 1)])
              let lvl += 1
            elseif a:cmdline[i] is# ')'
              let lvl -= 1
              call add(ret, [i, i + 1, 'RBP' . ((lvl % g:NUM_LVLS) + 1)])
            endif
            let i += 1
          endwhile
          return ret
        endfunction
        map <f5>  :let x = input({'prompt':'>','highlight':'RainBowParens'})<cr>
        "map <f5>  :let x = input({'prompt':'>'})<cr>
      ]])
      screen:set_default_attr_ids({
        RBP1={background = Screen.colors.Red},
        RBP2={background = Screen.colors.Yellow},
        RBP3={background = Screen.colors.Green},
        RBP4={background = Screen.colors.Blue},
        EOB={bold = true, foreground = Screen.colors.Blue1},
        ERR={foreground = Screen.colors.Grey100, background = Screen.colors.Red},
        SK={foreground = Screen.colors.Blue},
        PE={bold = true, foreground = Screen.colors.SeaGreen4}
      })
      feed('<f5>(a(b)a)')
      screen:expect([[
        ^                         |
        {EOB:~                        }|
        {EOB:~                        }|
        {EOB:~                        }|
                                 |
      ]], nil, nil, function()
        expect_cmdline(1, '{RBP1:(}a{RBP2:(}b{RBP2:)}a{RBP1:)}')
      end)
  end)
end)
