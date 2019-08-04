-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)

local command = helpers.command
local meths = helpers.meths
local clear = helpers.clear
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local feed = helpers.feed

local origlines = {"original line 1",
                   "original line 2",
                   "original line 3",
                   "original line 4",
                   "original line 5",
                   "original line 6",
                   "    indented line"}

describe('lua: buffer event callbacks', function()
  before_each(function()
    clear()
    exec_lua([[
      local events = {}

      function test_register(bufnr, id, changedtick, utf_sizes)
        local function callback(...)
          table.insert(events, {id, ...})
          if test_unreg == id then
            return true
          end
        end
        local opts = {on_lines=callback, on_detach=callback, utf_sizes=utf_sizes}
        if changedtick then
          opts.on_changedtick = callback
        end
        vim.api.nvim_buf_attach(bufnr, false, opts)
      end

      function get_events()
        local ret_events = events
        events = {}
        return ret_events
      end
    ]])
  end)


  -- verifying the sizes with nvim_buf_get_offset is nice (checks we cannot
  -- assert the wrong thing), but masks errors with unflushed lines (as
  -- nvim_buf_get_offset forces a flush of the memline). To be safe run the
  -- test both ways.
  local function check(verify,utf_sizes)
    local lastsize
    meths.buf_set_lines(0, 0, -1, true, origlines)
    if verify then
      lastsize = meths.buf_get_offset(0, meths.buf_line_count(0))
    end
    exec_lua("return test_register(...)", 0, "test1",false,utf_sizes)
    local tick = meths.buf_get_changedtick(0)

    local verify_name = "test1"
    local function check_events(expected)
      local events = exec_lua("return get_events(...)" )
      if utf_sizes then
        -- this test case uses ASCII only, so sizes sshould be the same.
        -- Unicode is tested below.
        for _, event in ipairs(expected) do
          event[9] = event[8]
          event[10] = event[8]
        end
      end
      eq(expected, events)
      if verify then
        for _, event in ipairs(events) do
          if event[1] == verify_name and event[2] == "lines" then
            local startline, endline = event[5], event[7]
            local newrange = meths.buf_get_offset(0, endline) - meths.buf_get_offset(0, startline)
            local newsize = meths.buf_get_offset(0, meths.buf_line_count(0))
            local oldrange = newrange + lastsize - newsize
            eq(oldrange, event[8])
            lastsize = newsize
          end
        end
      end
    end

    command('set autoindent')
    command('normal! GyyggP')
    tick = tick + 1
    check_events({{ "test1", "lines", 1, tick, 0, 0, 1, 0}})

    meths.buf_set_lines(0, 3, 5, true, {"changed line"})
    tick = tick + 1
    check_events({{ "test1", "lines", 1, tick, 3, 5, 4, 32 }})

    exec_lua("return test_register(...)", 0, "test2", true, utf_sizes)
    tick = tick + 1
    command('undo')

    -- plugins can opt in to receive changedtick events, or choose
    -- to only recieve actual changes.
    check_events({{ "test1", "lines", 1, tick, 3, 4, 5, 13 },
        { "test2", "lines", 1, tick, 3, 4, 5, 13 },
        { "test2", "changedtick", 1, tick+1 } })
    tick = tick + 1

    -- simulate next callback returning true
    exec_lua("test_unreg = 'test1'")

    meths.buf_set_lines(0, 6, 7, true, {"x1","x2","x3"})
    tick = tick + 1

    -- plugins can opt in to receive changedtick events, or choose
    -- to only recieve actual changes.
    check_events({{ "test1", "lines", 1, tick, 6, 7, 9, 16 },
        { "test2", "lines", 1, tick, 6, 7, 9, 16 }})

    verify_name = "test2"

    meths.buf_set_lines(0, 1, 1, true, {"added"})
    tick = tick + 1
    check_events({{ "test2", "lines", 1, tick, 1, 1, 2, 0 }})

    feed('wix')
    tick = tick + 1
    check_events({{ "test2", "lines", 1, tick, 4, 5, 5, 16 }})

    -- check hot path for multiple insert
    feed('yz')
    tick = tick + 1
    check_events({{ "test2", "lines", 1, tick, 4, 5, 5, 17 }})

    feed('<bs>')
    tick = tick + 1
    check_events({{ "test2", "lines", 1, tick, 4, 5, 5, 19 }})

    feed('<esc>Go')
    tick = tick + 1
    check_events({{ "test2", "lines", 1, tick, 11, 11, 12, 0 }})

    feed('x')
    tick = tick + 1
    check_events({{ "test2", "lines", 1, tick, 11, 12, 12, 5 }})

    command('bwipe!')
    check_events({{ "test2", "detach", 1 }})
   end

  it('works', function()
    check(false)
  end)

  it('works with verify', function()
    check(true)
  end)

  it('works with utf_sizes and ASCII text', function()
    check(false,true)
  end)

  it('works with utf_sizes and unicode text', function()
    local unicode_text = {"ascii text",
                          "latin text åäö",
                          "BMP text ɧ αλφά",
                          "BMP text 汉语 ↥↧",
                          "SMP 🤦 🦄🦃",
                          "combining å بِيَّة"}
    meths.buf_set_lines(0, 0, -1, true, unicode_text)
    feed('gg')
    exec_lua("return test_register(...)", 0, "test1", false, true)
    local tick = meths.buf_get_changedtick(0)

    feed('dd')
    tick = tick + 1
    eq({{ "test1", "lines", 1, tick, 0, 1, 0, 11, 11, 11 }}, exec_lua("return get_events(...)" ))

    feed('A<bs>')
    tick = tick + 1
    eq({{ "test1", "lines", 1, tick, 0, 1, 1, 18, 15, 15 }}, exec_lua("return get_events(...)" ))

    feed('<esc>jylp')
    tick = tick + 1
    eq({{ "test1", "lines", 1, tick, 1, 2, 2, 21, 16, 16 }}, exec_lua("return get_events(...)" ))

    feed('+eea<cr>')
    tick = tick + 1
    eq({{ "test1", "lines", 1, tick, 2, 3, 4, 23, 15, 15 }}, exec_lua("return get_events(...)" ))

    feed('<esc>jdw')
    tick = tick + 1
    -- non-BMP chars count as 2 UTF-2 codeunits
    eq({{ "test1", "lines", 1, tick, 4, 5, 5, 18, 9, 12 }}, exec_lua("return get_events(...)" ))

    feed('+rx')
    tick = tick + 1
    -- count the individual codepoints of a composed character.
    eq({{ "test1", "lines", 1, tick, 5, 6, 6, 27, 20, 20 }}, exec_lua("return get_events(...)" ))

    feed('kJ')
    tick = tick + 1
    -- NB: this is inefficient (but not really wrong).
    eq({{ "test1", "lines", 1,   tick, 4, 5, 5, 14, 5, 8 },
        { "test1", "lines", 1, tick+1, 5, 6, 5, 27, 20, 20 }}, exec_lua("return get_events(...)" ))
  end)

end)
