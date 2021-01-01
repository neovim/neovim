-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)

local command = helpers.command
local meths = helpers.meths
local funcs = helpers.funcs
local clear = helpers.clear
local eq = helpers.eq
local fail = helpers.fail
local exec_lua = helpers.exec_lua
local feed = helpers.feed
local deepcopy = helpers.deepcopy
local expect_events = helpers.expect_events

local origlines = {"original line 1",
                   "original line 2",
                   "original line 3",
                   "original line 4",
                   "original line 5",
                   "original line 6",
                   "    indented line"}

local function attach_buffer(evname)
  exec_lua([[
    local evname = ...
    local events = {}

    function test_register(bufnr, id, changedtick, utf_sizes, preview)
      local function callback(...)
        table.insert(events, {id, ...})
        if test_unreg == id then
          return true
        end
      end
      local opts = {[evname]=callback, on_detach=callback, utf_sizes=utf_sizes, preview=preview}
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
  ]], evname)
end

describe('lua buffer event callbacks: on_lines', function()
  before_each(function()
    clear()
    attach_buffer('on_lines')
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
        -- this test case uses ASCII only, so sizes should be the same.
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
    -- to only receive actual changes.
    check_events({{ "test1", "lines", 1, tick, 3, 4, 5, 13 },
        { "test2", "lines", 1, tick, 3, 4, 5, 13 },
        { "test2", "changedtick", 1, tick+1 } })
    tick = tick + 1

    -- simulate next callback returning true
    exec_lua("test_unreg = 'test1'")

    meths.buf_set_lines(0, 6, 7, true, {"x1","x2","x3"})
    tick = tick + 1

    -- plugins can opt in to receive changedtick events, or choose
    -- to only receive actual changes.
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

  it('has valid cursor position while shifting', function()
    meths.buf_set_lines(0, 0, -1, true, {'line1'})
    exec_lua([[
      vim.api.nvim_buf_attach(0, false, {
        on_lines = function()
          vim.api.nvim_set_var('listener_cursor_line', vim.api.nvim_win_get_cursor(0)[1])
        end,
      })
    ]])
    feed('>>')
    eq(1, meths.get_var('listener_cursor_line'))
  end)

  it('does not SEGFAULT when calling win_findbuf in on_detach', function()

    exec_lua[[
      local buf = vim.api.nvim_create_buf(false, false)

      vim.cmd"split"
      vim.api.nvim_win_set_buf(0, buf)

      vim.api.nvim_buf_attach(buf, false, {
        on_detach = function(_, buf)
          vim.fn.win_findbuf(buf)
        end
      })
    ]]

    command("q!")
    helpers.assert_alive()
  end)

  it('#12718 lnume', function()
    meths.buf_set_lines(0, 0, -1, true, {'1', '2', '3'})
    exec_lua([[
      vim.api.nvim_buf_attach(0, false, {
        on_lines = function(...)
          vim.api.nvim_set_var('linesev', { ... })
        end,
      })
    ]])
    feed('1G0')
    feed('y<C-v>2j')
    feed('G0')
    feed('p')
    -- Is the last arg old_byte_size correct? Doesn't matter for this PR
    eq(meths.get_var('linesev'), { "lines", 1, 4, 2, 3, 5, 4 })

    feed('2G0')
    feed('p')
    eq(meths.get_var('linesev'), { "lines", 1, 5, 1, 4, 4, 8 })

    feed('1G0')
    feed('P')
    eq(meths.get_var('linesev'), { "lines", 1, 6, 0, 3, 3, 9 })

  end)
end)

describe('lua: nvim_buf_attach on_bytes', function()
  before_each(function()
    clear()
    attach_buffer('on_bytes')
  end)

  -- verifying the sizes with nvim_buf_get_offset is nice (checks we cannot
  -- assert the wrong thing), but masks errors with unflushed lines (as
  -- nvim_buf_get_offset forces a flush of the memline). To be safe run the
  -- test both ways.
  local function setup_eventcheck(verify, start_txt)
    meths.buf_set_lines(0, 0, -1, true, start_txt)
    local shadow = deepcopy(start_txt)
    local shadowbytes = table.concat(shadow, '\n') .. '\n'
    -- TODO: while we are brewing the real strong coffe,
    -- verify should check buf_get_offset after every check_events
    if verify then
      local len = meths.buf_get_offset(0, meths.buf_line_count(0))
      eq(len == -1 and 1 or len, string.len(shadowbytes))
    end
    exec_lua("return test_register(...)", 0, "test1", false, false, true)
    meths.buf_get_changedtick(0)

    local verify_name = "test1"
    local function check_events(expected)
      local events = exec_lua("return get_events(...)" )
      expect_events(expected, events, "byte updates")

      if not verify then
        return
      end

      for _, event in ipairs(events) do
        for _, elem in ipairs(event) do
          if type(elem) == "number" and elem < 0 then
            fail(string.format("Received event has negative values"))
          end
        end

        if event[1] == verify_name and event[2] == "bytes" then
          local _, _, _, _, _, _, start_byte, _, _, old_byte, _, _, new_byte = unpack(event)
          local before = string.sub(shadowbytes, 1, start_byte)
          -- no text in the tests will contain 0xff bytes (invalid UTF-8)
          -- so we can use it as marker for unknown bytes
          local unknown = string.rep('\255', new_byte)
          local after = string.sub(shadowbytes, start_byte + old_byte + 1)
          shadowbytes = before .. unknown .. after
        end
      end

      local text = meths.buf_get_lines(0, 0, -1, true)
      local bytes = table.concat(text, '\n') .. '\n'

      eq(string.len(bytes), string.len(shadowbytes), '\non_bytes: total bytecount of buffer is wrong')
      for i = 1, string.len(shadowbytes) do
        local shadowbyte = string.sub(shadowbytes, i, i)
        if shadowbyte ~= '\255' then
          eq(string.sub(bytes, i, i), shadowbyte, i)
        end
      end
    end

    return check_events
  end

  -- Yes, we can do both
  local function do_both(verify)
    it('single and multiple join', function()
        local check_events = setup_eventcheck(verify, origlines)
        feed 'ggJ'
        check_events {
          {'test1', 'bytes', 1, 3, 0, 15, 15, 1, 0, 1, 0, 1, 1};
        }

        feed '3J'
        check_events {
          {'test1', 'bytes', 1, 5, 0, 31, 31, 1, 0, 1, 0, 1, 1};
          {'test1', 'bytes', 1, 5, 0, 47, 47, 1, 0, 1, 0, 1, 1};
        }
    end)

    it('opening lines', function()
        local check_events = setup_eventcheck(verify, origlines)
        -- meths.buf_set_option(0, 'autoindent', true)
        feed 'Go'
        check_events {
          { "test1", "bytes", 1, 4, 7, 0, 114, 0, 0, 0, 1, 0, 1 };
        }
        feed '<cr>'
        check_events {
          { "test1", "bytes", 1, 5, 7, 0, 114, 0, 0, 0, 1, 0, 1 };
        }
    end)

    it('opening lines with autoindent', function()
        local check_events = setup_eventcheck(verify, origlines)
        meths.buf_set_option(0, 'autoindent', true)
        feed 'Go'
        check_events {
          { "test1", "bytes", 1, 4, 7, 0, 114, 0, 0, 0, 1, 0, 5 };
        }
        feed '<cr>'
        check_events {
          { "test1", "bytes", 1, 4, 8, 0, 115, 0, 4, 4, 0, 0, 0 };
          { "test1", "bytes", 1, 5, 7, 4, 118, 0, 0, 0, 1, 4, 5 };
        }
    end)

    it('setline(num, line)', function()
      local check_events = setup_eventcheck(verify, origlines)
      funcs.setline(2, "babla")
      check_events {
        { "test1", "bytes", 1, 3, 1, 0, 16, 0, 15, 15, 0, 5, 5 };
      }

      funcs.setline(2, {"foo", "bar"})
      check_events {
        { "test1", "bytes", 1, 4, 1, 0, 16, 0, 5, 5, 0, 3, 3 };
        { "test1", "bytes", 1, 5, 2, 0, 20, 0, 15, 15, 0, 3, 3 };
      }

      local buf_len = meths.buf_line_count(0)
      funcs.setline(buf_len + 1, "baz")
      check_events {
        { "test1", "bytes", 1, 6, 7, 0, 90, 0, 0, 0, 1, 0, 4 };
      }
    end)

    it('continuing comments with fo=or', function()
      local check_events = setup_eventcheck(verify, {'// Comment'})
      meths.buf_set_option(0, 'formatoptions', 'ro')
      meths.buf_set_option(0, 'filetype', 'c')
      feed 'A<CR>'
      check_events {
        { "test1", "bytes", 1, 4, 0, 10, 10, 0, 0, 0, 1, 3, 4 };
      }

      feed '<ESC>'
      check_events {
        { "test1", "bytes", 1, 4, 1, 2, 13, 0, 1, 1, 0, 0, 0 };
      }

      feed 'ggo' -- goto first line to continue testing
      check_events {
        { "test1", "bytes", 1, 6, 1, 0, 11, 0, 0, 0, 1, 0, 4 };
      }

      feed '<CR>'
      check_events {
        { "test1", "bytes", 1, 6, 2, 2, 16, 0, 1, 1, 0, 0, 0 };
        { "test1", "bytes", 1, 7, 1, 3, 14, 0, 0, 0, 1, 3, 4 };
      }
    end)

    it('editing empty buffers', function()
      local check_events = setup_eventcheck(verify, {})

      feed 'ia'
      check_events {
        { "test1", "bytes", 1, 3, 0, 0, 0, 0, 0, 0, 0, 1, 1 };
      }
    end)

    it("changing lines", function()
      local check_events = setup_eventcheck(verify, origlines)

      feed "cc"
      check_events {
        { "test1", "bytes", 1, 4, 0, 0, 0, 0, 15, 15, 0, 0, 0 };
      }

      feed "<ESC>"
      check_events {}

      feed "c3j"
      check_events {
        { "test1", "bytes", 1, 4, 1, 0, 1, 3, 0, 48, 0, 0, 0 };
      }
    end)

    it("visual charwise paste", function()
      local check_events = setup_eventcheck(verify, {'1234567890'})
      funcs.setreg('a', '___')

      feed '1G1|vll'
      check_events {}

      feed '"ap'
      check_events {
        { "test1", "bytes", 1, 3, 0, 0, 0, 0, 3, 3, 0, 0, 0 };
        { "test1", "bytes", 1, 5, 0, 0, 0, 0, 0, 0, 0, 3, 3 };
      }
    end)

    it('blockwise paste', function()
      local check_events = setup_eventcheck(verify, {'1', '2', '3'})
      feed('1G0')
      feed('y<C-v>2j')
      feed('G0')
      feed('p')
      check_events {
        { "test1", "bytes", 1, 3, 2, 1, 5, 0, 0, 0, 0, 1, 1 };
        { "test1", "bytes", 1, 3, 3, 0, 7, 0, 0, 0, 0, 3, 3 };
        { "test1", "bytes", 1, 3, 4, 0, 10, 0, 0, 0, 0, 3, 3 };
      }

      feed('2G0')
      feed('p')
      check_events {
        { "test1", "bytes", 1, 4, 1, 1, 3, 0, 0, 0, 0, 1, 1 };
        { "test1", "bytes", 1, 4, 2, 1, 6, 0, 0, 0, 0, 1, 1 };
        { "test1", "bytes", 1, 4, 3, 1, 10, 0, 0, 0, 0, 1, 1 };
      }

      feed('1G0')
      feed('P')
      check_events {
        { "test1", "bytes", 1, 5, 0, 0, 0, 0, 0, 0, 0, 1, 1 };
        { "test1", "bytes", 1, 5, 1, 0, 3, 0, 0, 0, 0, 1, 1 };
        { "test1", "bytes", 1, 5, 2, 0, 7, 0, 0, 0, 0, 1, 1 };
      }

    end)

    it('inccomand=nosplit and substitute', function()
      if verify then pending("Verification can't be done when previewing") end

      local check_events = setup_eventcheck(verify, {"abcde"})
      meths.set_option('inccommand', 'nosplit')

      feed ':%s/bcd/'
      check_events {
        { "test1", "bytes", 1, 3, 0, 1, 1, 0, 3, 3, 0, 0, 0 };
      }

      feed 'a'
      check_events {
        { "test1", "bytes", 1, 3, 0, 1, 1, 0, 3, 3, 0, 1, 1 };
      }
    end)

    it('nvim_buf_set_text insert', function()
      local check_events = setup_eventcheck(verify, {"bastext"})
      meths.buf_set_text(0, 0, 3, 0, 3, {"fiol","kontra"})
      check_events {
        { "test1", "bytes", 1, 3, 0, 3, 3, 0, 0, 0, 1, 6, 11 };
      }

      meths.buf_set_text(0, 1, 6, 1, 6, {"punkt","syntgitarr","övnings"})
      check_events {
        { "test1", "bytes", 1, 4, 1, 6, 14, 0, 0, 0, 2, 8, 25 };
      }

      eq({ "basfiol", "kontrapunkt", "syntgitarr", "övningstext" },
         meths.buf_get_lines(0, 0, -1, true))
    end)

    it('nvim_buf_set_text replace', function()
      local check_events = setup_eventcheck(verify, origlines)

      meths.buf_set_text(0, 2, 3, 2, 8, {"very text"})
      check_events {
        { "test1", "bytes", 1, 3, 2, 3, 35, 0, 5, 5, 0, 9, 9 };
      }

      meths.buf_set_text(0, 3, 5, 3, 7, {" splitty","line "})
      check_events {
        { "test1", "bytes", 1, 4, 3, 5, 57, 0, 2, 2, 1, 5, 14 };
      }

      meths.buf_set_text(0, 0, 8, 1, 2, {"JOINY"})
      check_events {
        { "test1", "bytes", 1, 5, 0, 8, 8, 1, 2, 10, 0, 5, 5 };
      }

      meths.buf_set_text(0, 4, 0, 6, 0, {"was 5,6",""})
      check_events {
        { "test1", "bytes", 1, 6, 4, 0, 75, 2, 0, 32, 1, 0, 8 };
      }

      eq({ "originalJOINYiginal line 2", "orivery text line 3", "origi splitty",
           "line l line 4", "was 5,6", "    indented line" },
         meths.buf_get_lines(0, 0, -1, true))

    end)

    it('nvim_buf_set_text delete', function()
      local check_events = setup_eventcheck(verify, origlines)

      -- really {""} but accepts {} as a shorthand
      meths.buf_set_text(0, 0, 0, 1, 0, {})
      check_events {
        { "test1", "bytes", 1, 3, 0, 0, 0, 1, 0, 16, 0, 0, 0 };
      }

      -- TODO(bfredl): this works but is not as convenient as set_lines
      meths.buf_set_text(0, 4, 15, 5, 17, {""})
      check_events {
        { "test1", "bytes", 1, 4, 4, 15, 79, 1, 17, 18, 0, 0, 0 };
      }
      eq({ "original line 2", "original line 3", "original line 4",
           "original line 5", "original line 6" },
         meths.buf_get_lines(0, 0, -1, true))
    end)
  end

  describe('(with verify) handles', function()
    do_both(true)
  end)

  describe('(without verify) handles', function()
    do_both(false)
  end)
end)

