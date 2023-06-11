-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)
local luv = require('luv')

local command = helpers.command
local meths = helpers.meths
local funcs = helpers.funcs
local clear = helpers.clear
local eq = helpers.eq
local fail = helpers.fail
local exec_lua = helpers.exec_lua
local feed = helpers.feed
local expect_events = helpers.expect_events
local write_file = helpers.write_file
local dedent = helpers.dedent

local origlines = {"original line 1",
                   "original line 2",
                   "original line 3",
                   "original line 4",
                   "original line 5",
                   "original line 6",
                   "    indented line"}

before_each(function ()
  clear()
  exec_lua [[
    local evname = ...
    local events = {}

    function test_register(bufnr, evname, id, changedtick, utf_sizes, preview)
      local function callback(...)
        table.insert(events, {id, ...})
        if test_unreg == id then
          return true
        end
      end
      local opts = {[evname]=callback, on_detach=callback, on_reload=callback, utf_sizes=utf_sizes, preview=preview}
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
  ]]
end)

describe('lua buffer event callbacks: on_lines', function()
  local function setup_eventcheck(verify, utf_sizes, lines)
    local lastsize
    meths.buf_set_lines(0, 0, -1, true, lines)
    if verify then
      lastsize = meths.buf_get_offset(0, meths.buf_line_count(0))
    end
    exec_lua("return test_register(...)", 0, "on_lines", "test1",false,utf_sizes)
    local verify_name = "test1"

    local function check_events(expected)
      local events = exec_lua("return get_events(...)" )
      if utf_sizes then
        -- this test case uses ASCII only, so sizes should be the same.
        -- Unicode is tested below.
        for _, event in ipairs(expected) do
          event[9] = event[9] or event[8]
          event[10] = event[10] or event[9]
        end
      end
      expect_events(expected, events, "line updates")
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
    return check_events, function(new) verify_name = new end
  end


  -- verifying the sizes with nvim_buf_get_offset is nice (checks we cannot
  -- assert the wrong thing), but masks errors with unflushed lines (as
  -- nvim_buf_get_offset forces a flush of the memline). To be safe run the
  -- test both ways.
  local function check(verify,utf_sizes)
    local check_events, verify_name = setup_eventcheck(verify, utf_sizes, origlines)

    local tick = meths.buf_get_changedtick(0)
    command('set autoindent')
    command('normal! GyyggP')
    tick = tick + 1
    check_events {{ "test1", "lines", 1, tick, 0, 0, 1, 0}}

    meths.buf_set_lines(0, 3, 5, true, {"changed line"})
    tick = tick + 1
    check_events {{ "test1", "lines", 1, tick, 3, 5, 4, 32 }}

    exec_lua("return test_register(...)", 0, "on_lines", "test2", true, utf_sizes)
    tick = tick + 1
    command('undo')

    -- plugins can opt in to receive changedtick events, or choose
    -- to only receive actual changes.
    check_events {
      { "test1", "lines", 1, tick, 3, 4, 5, 13 };
      { "test2", "lines", 1, tick, 3, 4, 5, 13 };
      { "test2", "changedtick", 1, tick+1 };
    }
    tick = tick + 1

    tick = tick + 1
    command('redo')
    check_events {
      { "test1", "lines", 1, tick, 3, 5, 4, 32 };
      { "test2", "lines", 1, tick, 3, 5, 4, 32 };
      { "test2", "changedtick", 1, tick+1 };
    }
    tick = tick + 1

    tick = tick + 1
    command('undo!')
    check_events {
      { "test1", "lines", 1, tick, 3, 4, 5, 13 };
      { "test2", "lines", 1, tick, 3, 4, 5, 13 };
      { "test2", "changedtick", 1, tick+1 };
    }
    tick = tick + 1

    -- simulate next callback returning true
    exec_lua("test_unreg = 'test1'")

    meths.buf_set_lines(0, 6, 7, true, {"x1","x2","x3"})
    tick = tick + 1

    -- plugins can opt in to receive changedtick events, or choose
    -- to only receive actual changes.
    check_events {
      { "test1", "lines", 1, tick, 6, 7, 9, 16 };
      { "test2", "lines", 1, tick, 6, 7, 9, 16 };
    }

    verify_name "test2"

    meths.buf_set_lines(0, 1, 1, true, {"added"})
    tick = tick + 1
    check_events {{ "test2", "lines", 1, tick, 1, 1, 2, 0 }}

    feed('wix')
    tick = tick + 1
    check_events {{ "test2", "lines", 1, tick, 4, 5, 5, 16 }}

    -- check hot path for multiple insert
    feed('yz')
    tick = tick + 1
    check_events {{ "test2", "lines", 1, tick, 4, 5, 5, 17 }}

    feed('<bs>')
    tick = tick + 1
    check_events {{ "test2", "lines", 1, tick, 4, 5, 5, 19 }}

    feed('<esc>Go')
    tick = tick + 1
    check_events {{ "test2", "lines", 1, tick, 11, 11, 12, 0 }}

    feed('x')
    tick = tick + 1
    check_events {{ "test2", "lines", 1, tick, 11, 12, 12, 5 }}

    command('bwipe!')
    check_events {{ "test2", "detach", 1 }}
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

  local function check_unicode(verify)
    local unicode_text = {"ascii text",
                          "latin text åäö",
                          "BMP text ɧ αλφά",
                          "BMP text 汉语 ↥↧",
                          "SMP 🤦 🦄🦃",
                          "combining å بِيَّة"}
    local check_events, verify_name = setup_eventcheck(verify, true, unicode_text)

    local tick = meths.buf_get_changedtick(0)

    feed('ggdd')
    tick = tick + 1
    check_events {{ "test1", "lines", 1, tick, 0, 1, 0, 11, 11, 11 }}

    feed('A<bs>')
    tick = tick + 1
    check_events {{ "test1", "lines", 1, tick, 0, 1, 1, 18, 15, 15 }}

    feed('<esc>jylp')
    tick = tick + 1
    check_events {{ "test1", "lines", 1, tick, 1, 2, 2, 21, 16, 16 }}

    feed('+eea<cr>')
    tick = tick + 1
    check_events {{ "test1", "lines", 1, tick, 2, 3, 4, 23, 15, 15 }}

    feed('<esc>jdw')
    tick = tick + 1
    -- non-BMP chars count as 2 UTF-2 codeunits
    check_events {{ "test1", "lines", 1, tick, 4, 5, 5, 18, 9, 12 }}

    feed('+rx')
    tick = tick + 1
    -- count the individual codepoints of a composed character.
    check_events {{ "test1", "lines", 1, tick, 5, 6, 6, 27, 20, 20 }}

    feed('kJ')
    tick = tick + 1
    -- verification fails with multiple line updates, sorry about that
    verify_name ""
    -- NB: this is inefficient (but not really wrong).
    check_events {
      { "test1", "lines", 1,   tick, 4, 5, 5, 14, 5, 8 };
      { "test1", "lines", 1, tick+1, 5, 6, 5, 27, 20, 20 };
    }
  end

  it('works with utf_sizes and unicode text', function()
    check_unicode(false)
  end)

  it('works with utf_sizes and unicode text with verify', function()
    check_unicode(true)
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

  it('has valid cursor position while deleting lines', function()
    meths.buf_set_lines(0, 0, -1, true, { "line_1", "line_2", "line_3", "line_4"})
    meths.win_set_cursor(0, {2, 0})
    eq(2, meths.win_get_cursor(0)[1])
    meths.buf_set_lines(0, 0, -1, true, { "line_1", "line_2", "line_3"})
    eq(2, meths.win_get_cursor(0)[1])
  end)

  it('does not SEGFAULT when accessing window buffer info in on_detach #14998', function()
    local code = [[
      local buf = vim.api.nvim_create_buf(false, false)

      vim.cmd"split"
      vim.api.nvim_win_set_buf(0, buf)

      vim.api.nvim_buf_attach(buf, false, {
        on_detach = function(_, buf)
          vim.fn.tabpagebuflist()
          vim.fn.win_findbuf(buf)
        end
      })
    ]]

    exec_lua(code)
    command("q!")
    helpers.assert_alive()

    exec_lua(code)
    command("bd!")
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

  it('calling nvim_buf_call() from callback does not cause Normal mode CTRL-A to misbehave #16729', function()
    exec_lua([[
      vim.api.nvim_buf_attach(0, false, {
        on_lines = function(...)
          vim.api.nvim_buf_call(0, function() end)
        end,
      })
    ]])
    feed('itest123<Esc><C-A>')
    eq('test124', meths.get_current_line())
  end)
end)

describe('lua: nvim_buf_attach on_bytes', function()
  -- verifying the sizes with nvim_buf_get_offset is nice (checks we cannot
  -- assert the wrong thing), but masks errors with unflushed lines (as
  -- nvim_buf_get_offset forces a flush of the memline). To be safe run the
  -- test both ways.
  local function setup_eventcheck(verify, start_txt)
    if start_txt then
      meths.buf_set_lines(0, 0, -1, true, start_txt)
    else
      start_txt = meths.buf_get_lines(0, 0, -1, true)
    end
    local shadowbytes = table.concat(start_txt, '\n') .. '\n'
    -- TODO: while we are brewing the real strong coffee,
    -- verify should check buf_get_offset after every check_events
    if verify then
      local len = meths.buf_get_offset(0, meths.buf_line_count(0))
      eq(len == -1 and 1 or len, string.len(shadowbytes))
    end
    exec_lua("return test_register(...)", 0, "on_bytes", "test1", false, false, true)
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
        elseif event[1] == verify_name and event[2] == "reload" then
          shadowbytes = table.concat(meths.buf_get_lines(0, 0, -1, true), '\n') .. '\n'
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
        -- meths.set_option_value('autoindent', true, {})
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
        meths.set_option_value('autoindent', true, {})
        feed 'Go'
        check_events {
          { "test1", "bytes", 1, 4, 7, 0, 114, 0, 0, 0, 1, 0, 5 };
        }
        feed '<cr>'
        check_events {
          { "test1", "bytes", 1, 4, 7, 0, 114, 0, 4, 4, 0, 0, 0 };
          { "test1", "bytes", 1, 5, 7, 0, 114, 0, 0, 0, 1, 4, 5 };
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
      meths.set_option_value('formatoptions', 'ro', {})
      meths.set_option_value('filetype', 'c', {})
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
        { "test1", "bytes", 1, 6, 1, 2, 13, 0, 1, 1, 0, 0, 0 };
        { "test1", "bytes", 1, 7, 1, 2, 13, 0, 0, 0, 1, 3, 4 };
      }
    end)

    it('editing empty buffers', function()
      local check_events = setup_eventcheck(verify, {})

      feed 'ia'
      check_events {
        { "test1", "bytes", 1, 3, 0, 0, 0, 0, 0, 0, 0, 1, 1 };
      }
    end)

    it("deleting lines", function()
      local check_events = setup_eventcheck(verify, origlines)

      feed("dd")

      check_events {
        { "test1", "bytes", 1, 3, 0, 0, 0, 1, 0, 16, 0, 0, 0 };
      }

      feed("d2j")

      check_events {
        { "test1", "bytes", 1, 4, 0, 0, 0, 3, 0, 48, 0, 0, 0 };
      }

      feed("ld<c-v>2j")

      check_events {
        { "test1", "bytes", 1, 5, 0, 1, 1, 0, 1, 1, 0, 0, 0 };
        { "test1", "bytes", 1, 5, 1, 1, 16, 0, 1, 1, 0, 0, 0 };
        { "test1", "bytes", 1, 5, 2, 1, 31, 0, 1, 1, 0, 0, 0 };
      }

      feed("vjwd")

      check_events {
        { "test1", "bytes", 1, 10, 0, 1, 1, 1, 9, 23, 0, 0, 0 };
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

    it("linewise paste", function()
      local check_events = setup_eventcheck(verify, origlines)

      feed'yyp'
      check_events {
        { "test1", "bytes", 1, 3, 1, 0, 16, 0, 0, 0, 1, 0, 16 };
      }

      feed'Gyyp'
      check_events {
        { "test1", "bytes", 1, 4, 8, 0, 130, 0, 0, 0, 1, 0, 18 };
      }
    end)

    it('inccomand=nosplit and substitute', function()
      local check_events = setup_eventcheck(verify,
                                            {"abcde", "12345"})
      meths.set_option_value('inccommand', 'nosplit', {})

      -- linewise substitute
      feed(':%s/bcd/')
      check_events {
        { "test1", "bytes", 1, 3, 0, 1, 1, 0, 3, 3, 0, 0, 0 };
        { "test1", "bytes", 1, 5, 0, 1, 1, 0, 0, 0, 0, 3, 3 };
      }

      feed('a')
      check_events {
        { "test1", "bytes", 1, 3, 0, 1, 1, 0, 3, 3, 0, 1, 1 };
        { "test1", "bytes", 1, 5, 0, 1, 1, 0, 1, 1, 0, 3, 3 };
      }

      feed("<esc>")

      -- splitting lines
      feed([[:%s/abc/\r]])
      check_events {
        { "test1", "bytes", 1, 3, 0, 0, 0, 0, 3, 3, 1, 0, 1 };
        { "test1", "bytes", 1, 6, 0, 0, 0, 1, 0, 1, 0, 3, 3 };
      }

      feed("<esc>")
      -- multi-line regex
      feed([[:%s/de\n123/a]])

      check_events {
        { "test1", "bytes", 1, 3, 0, 3, 3, 1, 3, 6, 0, 1, 1 };
        { "test1", "bytes", 1, 6, 0, 3, 3, 0, 1, 1, 1, 3, 6 };
      }

      feed("<esc>")
      -- replacing with unicode
      feed(":%s/b/→")

      check_events {
        { "test1", "bytes", 1, 3, 0, 1, 1, 0, 1, 1, 0, 3, 3 };
        { "test1", "bytes", 1, 5, 0, 1, 1, 0, 3, 3, 0, 1, 1 };
      }

      feed("<esc>")
      -- replacing with expression register
      feed([[:%s/b/\=5+5]])
      check_events {
        { "test1", "bytes", 1, 3, 0, 1, 1, 0, 1, 1, 0, 2, 2 };
        { "test1", "bytes", 1, 5, 0, 1, 1, 0, 2, 2, 0, 1, 1 };
      }

      feed("<esc>")
      -- replacing with backslash
      feed([[:%s/b/\\]])
      check_events {
        { "test1", "bytes", 1, 3, 0, 1, 1, 0, 1, 1, 0, 1, 1 };
        { "test1", "bytes", 1, 5, 0, 1, 1, 0, 1, 1, 0, 1, 1 };
      }

      feed("<esc>")
      -- replacing with backslash from expression register
      feed([[:%s/b/\='\']])
      check_events {
        { "test1", "bytes", 1, 3, 0, 1, 1, 0, 1, 1, 0, 1, 1 };
        { "test1", "bytes", 1, 5, 0, 1, 1, 0, 1, 1, 0, 1, 1 };
      }

      feed("<esc>")
      -- replacing with backslash followed by another character
      feed([[:%s/b/\\!]])
      check_events {
        { "test1", "bytes", 1, 3, 0, 1, 1, 0, 1, 1, 0, 2, 2 };
        { "test1", "bytes", 1, 5, 0, 1, 1, 0, 2, 2, 0, 1, 1 };
      }

      feed("<esc>")
      -- replacing with backslash followed by another character from expression register
      feed([[:%s/b/\='\!']])
      check_events {
        { "test1", "bytes", 1, 3, 0, 1, 1, 0, 1, 1, 0, 2, 2 };
        { "test1", "bytes", 1, 5, 0, 1, 1, 0, 2, 2, 0, 1, 1 };
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

    it('checktime autoread', function()
      write_file("Xtest-reload", dedent [[
        old line 1
        old line 2]])
      local atime = os.time() - 10
      luv.fs_utime("Xtest-reload", atime, atime)
      command "e Xtest-reload"
      command "set autoread"

      local check_events = setup_eventcheck(verify, nil)

      write_file("Xtest-reload", dedent [[
        new line 1
        new line 2
        new line 3]])

      command "checktime"
      check_events {
        { "test1", "reload", 1 };
      }

      feed 'ggJ'
      check_events {
        { "test1", "bytes", 1, 5, 0, 10, 10, 1, 0, 1, 0, 1, 1 };
      }

      eq({'new line 1 new line 2', 'new line 3'}, meths.buf_get_lines(0, 0, -1, true))

      -- check we can undo and redo a reload event.
      feed 'u'
      check_events {
        { "test1", "bytes", 1, 8, 0, 10, 10, 0, 1, 1, 1, 0, 1 };
      }

      feed 'u'
      check_events {
        { "test1", "reload", 1 };
      }

      feed '<c-r>'
      check_events {
        { "test1", "reload", 1 };
      }

      feed '<c-r>'
      check_events {
        { "test1", "bytes", 1, 14, 0, 10, 10, 1, 0, 1, 0, 1, 1 };
      }
    end)

    it("tab with noexpandtab and softtabstop", function()
      command("set noet")
      command("set ts=4")
      command("set sw=2")
      command("set sts=4")

      local check_events = setup_eventcheck(verify, {'asdfasdf'})

      feed("gg0i<tab>")

      check_events {
        { "test1", "bytes", 1, 3, 0, 0, 0, 0, 0, 0, 0, 1, 1 },
        { "test1", "bytes", 1, 4, 0, 1, 1, 0, 0, 0, 0, 1, 1 },
      }
      feed("<tab>")

      -- when spaces are merged into a tabstop
      check_events {
        { "test1", "bytes", 1, 5, 0, 2, 2, 0, 0, 0, 0, 1, 1 },
        { "test1", "bytes", 1, 6, 0, 3, 3, 0, 0, 0, 0, 1, 1 },
        { "test1", "bytes", 1, 7, 0, 0, 0, 0, 4, 4, 0, 1, 1 },
      }


      feed("<esc>u")
      check_events {
        { "test1", "bytes", 1, 8, 0, 0, 0, 0, 1, 1, 0, 4, 4 },
        { "test1", "bytes", 1, 8, 0, 0, 0, 0, 4, 4, 0, 0, 0 }
      }

      -- in REPLACE mode
      feed("R<tab><tab>")
      check_events {
        { "test1", "bytes", 1, 9, 0, 0, 0, 0, 1, 1, 0, 1, 1 },
        { "test1", "bytes", 1, 10, 0, 1, 1, 0, 0, 0, 0, 1, 1 },
        { "test1", "bytes", 1, 11, 0, 2, 2, 0, 1, 1, 0, 1, 1 },
        { "test1", "bytes", 1, 12, 0, 3, 3, 0, 0, 0, 0, 1, 1 },
        { "test1", "bytes", 1, 13, 0, 0, 0, 0, 4, 4, 0, 1, 1 },
      }
      feed("<esc>u")
      check_events {
        { "test1", "bytes", 1, 14, 0, 0, 0, 0, 1, 1, 0, 4, 4 },
        { "test1", "bytes", 1, 14, 0, 2, 2, 0, 2, 2, 0, 1, 1 },
        { "test1", "bytes", 1, 14, 0, 0, 0, 0, 2, 2, 0, 1, 1 }
      }

      -- in VISUALREPLACE mode
      feed("gR<tab><tab>")
      check_events {
          { "test1", "bytes", 1, 15, 0, 0, 0, 0, 1, 1, 0, 1, 1 };
          { "test1", "bytes", 1, 16, 0, 1, 1, 0, 1, 1, 0, 1, 1 };
          { "test1", "bytes", 1, 17, 0, 2, 2, 0, 1, 1, 0, 1, 1 };
          { "test1", "bytes", 1, 18, 0, 3, 3, 0, 1, 1, 0, 1, 1 };
          { "test1", "bytes", 1, 19, 0, 3, 3, 0, 1, 1, 0, 0, 0 };
          { "test1", "bytes", 1, 20, 0, 3, 3, 0, 0, 0, 0, 1, 1 };
          { "test1", "bytes", 1, 22, 0, 2, 2, 0, 1, 1, 0, 0, 0 };
          { "test1", "bytes", 1, 23, 0, 2, 2, 0, 0, 0, 0, 1, 1 };
          { "test1", "bytes", 1, 25, 0, 1, 1, 0, 1, 1, 0, 0, 0 };
          { "test1", "bytes", 1, 26, 0, 1, 1, 0, 0, 0, 0, 1, 1 };
          { "test1", "bytes", 1, 28, 0, 0, 0, 0, 1, 1, 0, 0, 0 };
          { "test1", "bytes", 1, 29, 0, 0, 0, 0, 0, 0, 0, 1, 1 };
          { "test1", "bytes", 1, 31, 0, 0, 0, 0, 4, 4, 0, 1, 1 };
      }

      -- inserting tab after other tabs
      command("set sw=4")
      feed("<esc>0a<tab>")
      check_events {
        { "test1", "bytes", 1, 32, 0, 1, 1, 0, 0, 0, 0, 1, 1 };
        { "test1", "bytes", 1, 33, 0, 2, 2, 0, 0, 0, 0, 1, 1 };
        { "test1", "bytes", 1, 34, 0, 3, 3, 0, 0, 0, 0, 1, 1 };
        { "test1", "bytes", 1, 35, 0, 4, 4, 0, 0, 0, 0, 1, 1 };
        { "test1", "bytes", 1, 36, 0, 1, 1, 0, 4, 4, 0, 1, 1 };
      }
    end)

    it("retab", function()
      command("set noet")
      command("set ts=4")

      local check_events = setup_eventcheck(verify, {"			asdf"})
      command("retab 8")

      check_events {
        { "test1", "bytes", 1, 3, 0, 0, 0, 0, 7, 7, 0, 9, 9 };
      }
    end)

    it("sends events when undoing with undofile", function()
      write_file("Xtest-undofile", dedent([[
      12345
      hello world
      ]]))

      command("e! Xtest-undofile")
      command("set undodir=. | set undofile")

      local ns = helpers.request('nvim_create_namespace', "ns1")
      meths.buf_set_extmark(0, ns, 0, 0, {})

      eq({"12345", "hello world"}, meths.buf_get_lines(0, 0, -1, true))

      -- splice
      feed("gg0d2l")

      eq({"345", "hello world"}, meths.buf_get_lines(0, 0, -1, true))

      -- move
      command(".m+1")

      eq({"hello world", "345"}, meths.buf_get_lines(0, 0, -1, true))

      -- reload undofile and undo changes
      command("w")
      command("set noundofile")
      command("bw!")
      command("e! Xtest-undofile")

      command("set undofile")

      local check_events = setup_eventcheck(verify, nil)

      feed("u")
      eq({"345", "hello world"}, meths.buf_get_lines(0, 0, -1, true))

      check_events {
        { "test1", "bytes", 2, 6, 1, 0, 12, 1, 0, 4, 0, 0, 0 },
        { "test1", "bytes", 2, 6, 0, 0, 0, 0, 0, 0, 1, 0, 4 }
      }

      feed("u")
      eq({"12345", "hello world"}, meths.buf_get_lines(0, 0, -1, true))

      check_events {
        { "test1", "bytes", 2, 8, 0, 0, 0, 0, 0, 0, 0, 2, 2 }
      }
      command("bw!")
    end)

    it("blockwise paste with uneven line lengths", function()
      local check_events = setup_eventcheck(verify, {'aaaa', 'aaa', 'aaa'})

      -- eq({}, meths.buf_get_lines(0, 0, -1, true))
      feed("gg0<c-v>jj$d")

      check_events {
        { "test1", "bytes", 1, 3, 0, 0, 0, 0, 4, 4, 0, 0, 0 },
        { "test1", "bytes", 1, 3, 1, 0, 1, 0, 3, 3, 0, 0, 0 },
        { "test1", "bytes", 1, 3, 2, 0, 2, 0, 3, 3, 0, 0, 0 },
      }

      feed("p")
      check_events {
        { "test1", "bytes", 1, 4, 0, 0, 0, 0, 0, 0, 0, 4, 4 },
        { "test1", "bytes", 1, 4, 1, 0, 5, 0, 0, 0, 0, 3, 3 },
        { "test1", "bytes", 1, 4, 2, 0, 9, 0, 0, 0, 0, 3, 3 },
      }

    end)

    it(":luado", function()
      local check_events = setup_eventcheck(verify, {"abc", "12345"})

      command(".luado return 'a'")

      check_events {
        { "test1", "bytes", 1, 3, 0, 0, 0, 0, 3, 3, 0, 1, 1 };
      }

      command("luado return 10")

      check_events {
        { "test1", "bytes", 1, 4, 0, 0, 0, 0, 1, 1, 0, 2, 2 };
        { "test1", "bytes", 1, 5, 1, 0, 3, 0, 5, 5, 0, 2, 2 };
      }

    end)

    it("flushes deleted bytes on move", function()
      local check_events = setup_eventcheck(verify, {"AAA", "BBB", "CCC", "DDD"})

      feed(":.move+1<cr>")

      check_events {
        { "test1", "bytes", 1, 5, 0, 0, 0, 1, 0, 4, 0, 0, 0 };
        { "test1", "bytes", 1, 5, 1, 0, 4, 0, 0, 0, 1, 0, 4 };
      }

      feed("jd2j")

      check_events {
        { "test1", "bytes", 1, 6, 2, 0, 8, 2, 0, 8, 0, 0, 0 };
      }
    end)

    it("virtual edit", function ()
      local check_events = setup_eventcheck(verify, { "", "	" })

      meths.set_option_value('virtualedit', "all", {})

      feed [[<Right><Right>iab<ESC>]]

      check_events {
        { "test1", "bytes", 1, 3, 0, 0, 0, 0, 0, 0, 0, 2, 2 };
        { "test1", "bytes", 1, 4, 0, 2, 2, 0, 0, 0, 0, 2, 2 };
      }

      feed [[j<Right><Right>iab<ESC>]]

      check_events {
        { "test1", "bytes", 1, 5, 1, 0, 5, 0, 1, 1, 0, 8, 8 };
        { "test1", "bytes", 1, 6, 1, 5, 10, 0, 0, 0, 0, 2, 2 };
      }
    end)

    it("block visual paste", function()
      local check_events = setup_eventcheck(verify, {"AAA",
                                                     "BBB",
                                                     "CCC",
                                                     "DDD",
                                                     "EEE",
                                                     "FFF"})
      funcs.setreg("a", "___")
      feed([[gg0l<c-v>3jl"ap]])

      check_events {
        { "test1", "bytes", 1, 3, 0, 1, 1, 0, 2, 2, 0, 0, 0 };
        { "test1", "bytes", 1, 3, 1, 1, 3, 0, 2, 2, 0, 0, 0 };
        { "test1", "bytes", 1, 3, 2, 1, 5, 0, 2, 2, 0, 0, 0 };
        { "test1", "bytes", 1, 3, 3, 1, 7, 0, 2, 2, 0, 0, 0 };
        { "test1", "bytes", 1, 5, 0, 1, 1, 0, 0, 0, 0, 3, 3 };
        { "test1", "bytes", 1, 6, 1, 1, 6, 0, 0, 0, 0, 3, 3 };
        { "test1", "bytes", 1, 7, 2, 1, 11, 0, 0, 0, 0, 3, 3 };
        { "test1", "bytes", 1, 8, 3, 1, 16, 0, 0, 0, 0, 3, 3 };
      }
    end)

    it("visual paste", function()
      local check_events= setup_eventcheck(verify, { "aaa {", "b", "}" })
      -- Setting up
      feed[[jdd]]
      check_events {
        { "test1", "bytes", 1, 3, 1, 0, 6, 1, 0, 2, 0, 0, 0 };
      }

      -- Actually testing
      feed[[v%p]]
      check_events {
        { "test1", "bytes", 1, 8, 0, 4, 4, 1, 1, 3, 0, 0, 0 };
        { "test1", "bytes", 1, 8, 0, 4, 4, 0, 0, 0, 2, 0, 3 };
      }
    end)

    it("nvim_buf_set_lines", function()
      local check_events = setup_eventcheck(verify, {"AAA", "BBB"})

      -- delete
      meths.buf_set_lines(0, 0, 1, true, {})

      check_events {
        { "test1", "bytes", 1, 3, 0, 0, 0, 1, 0, 4, 0, 0, 0 };
      }

      -- add
      meths.buf_set_lines(0, 0, 0, true, {'asdf'})
      check_events {
        { "test1", "bytes", 1, 4, 0, 0, 0, 0, 0, 0, 1, 0, 5 };
      }

      -- replace
      meths.buf_set_lines(0, 0, 1, true, {'asdf', 'fdsa'})
      check_events {
        { "test1", "bytes", 1, 5, 0, 0, 0, 1, 0, 5, 2, 0, 10 };
      }
    end)

    it("flushes delbytes on substitute", function()
      local check_events = setup_eventcheck(verify, {"AAA", "BBB", "CCC"})

      feed("gg0")
      command("s/AAA/GGG/")

      check_events {
        { "test1", "bytes", 1, 3, 0, 0, 0, 0, 3, 3, 0, 3, 3 };
      }

      -- check that byte updates for :delete (which uses curbuf->deleted_bytes2)
      -- are correct
      command("delete")
      check_events {
        { "test1", "bytes", 1, 4, 0, 0, 0, 1, 0, 4, 0, 0, 0 };
      }
    end)

    it("flushes delbytes on join", function()
      local check_events = setup_eventcheck(verify, {"AAA", "BBB", "CCC"})

      feed("gg0J")

      check_events {
        { "test1", "bytes", 1, 3, 0, 3, 3, 1, 0, 1, 0, 1, 1 };
      }

      command("delete")
      check_events {
        { "test1", "bytes", 1, 5, 0, 0, 0, 1, 0, 8, 0, 0, 0 };
      }
    end)

    it("sends updates on U", function()
      feed("ggiAAA<cr>BBB")
      feed("<esc>gg$a CCC")

      local check_events = setup_eventcheck(verify, nil)

      feed("ggU")

      check_events {
         { "test1", "bytes", 1, 6, 0, 7, 7, 0, 0, 0, 0, 3, 3 };
      }
    end)

    it("delete in completely empty buffer", function()
      local check_events = setup_eventcheck(verify, nil)

      command "delete"
      check_events { }
    end)

    it("delete the only line of a buffer", function()
      local check_events = setup_eventcheck(verify, {"AAA"})

      command "delete"
      check_events {
        { "test1", "bytes", 1, 3, 0, 0, 0, 1, 0, 4, 1, 0, 1 };
      }
    end)

    it("delete the last line of a buffer with two lines", function()
      local check_events = setup_eventcheck(verify, {"AAA", "BBB"})

      command "2delete"
      check_events {
        { "test1", "bytes", 1, 3, 1, 0, 4, 1, 0, 4, 0, 0, 0 };
      }
    end)

    it(":sort lines", function()
      local check_events = setup_eventcheck(verify, {"CCC", "BBB", "AAA"})

      command "%sort"
      check_events {
        { "test1", "bytes", 1, 3, 0, 0, 0, 3, 0, 12, 3, 0, 12 };
      }
    end)

    it("handles already sorted lines", function()
      local check_events = setup_eventcheck(verify, {"AAA", "BBB", "CCC"})

      command "%sort"
      check_events { }
    end)

    it("works with accepting spell suggestions", function()
      local check_events = setup_eventcheck(verify, {"hallo world", "hallo world"})

      feed("gg0z=4<cr><cr>") -- accepts 'Hello'
      check_events {
        { "test1", "bytes", 1, 3, 0, 0, 0, 0, 2, 2, 0, 2, 2 };
      }

      command("spellrepall") -- replaces whole words
      check_events {
        { "test1", "bytes", 1, 4, 1, 0, 12, 0, 5, 5, 0, 5, 5 };
      }
    end)

    it('works with :diffput and :diffget', function()
      local check_events = setup_eventcheck(verify, {"AAA"})
      command('diffthis')
      command('new')
      command('diffthis')
      meths.buf_set_lines(0, 0, -1, true, {"AAA", "BBB"})
      feed('G')
      command('diffput')
      check_events {
        { "test1", "bytes", 1, 3, 1, 0, 4, 0, 0, 0, 1, 0, 4 };
      }
      meths.buf_set_lines(0, 0, -1, true, {"AAA", "CCC"})
      feed('<C-w>pG')
      command('diffget')
      check_events {
        { "test1", "bytes", 1, 4, 1, 0, 4, 1, 0, 4, 1, 0, 4 };
      }
    end)

    local function test_lockmarks(mode)
      local description = (mode ~= "") and mode or "(baseline)"
      it("test_lockmarks " .. description .. " %delete _", function()
        local check_events = setup_eventcheck(verify, {"AAA", "BBB", "CCC"})

        command(mode .. " %delete _")
        check_events {
          { "test1", "bytes", 1, 3, 0, 0, 0, 3, 0, 12, 1, 0, 1 };
        }
      end)

      it("test_lockmarks " .. description .. " append()", function()
        local check_events = setup_eventcheck(verify)

        command(mode .. " call append(0, 'CCC')")
        check_events {
          { "test1", "bytes", 1, 2, 0, 0, 0, 0, 0, 0, 1, 0, 4 };
        }

        command(mode .. " call append(1, 'BBBB')")
        check_events {
          { "test1", "bytes", 1, 3, 1, 0, 4, 0, 0, 0, 1, 0, 5 };
        }

        command(mode .. " call append(2, '')")
        check_events {
          { "test1", "bytes", 1, 4, 2, 0, 9, 0, 0, 0, 1, 0, 1 };
        }

        command(mode .. " $delete _")
        check_events {
          { "test1", "bytes", 1, 5, 3, 0, 10, 1, 0, 1, 0, 0, 0 };
        }

        eq("CCC|BBBB|", table.concat(meths.buf_get_lines(0, 0, -1, true), "|"))
      end)
    end

    -- check that behavior is identical with and without "lockmarks"
    test_lockmarks ""
    test_lockmarks "lockmarks"

    teardown(function()
      os.remove "Xtest-reload"
      os.remove "Xtest-undofile"
      os.remove ".Xtest-undofile.un~"
    end)
  end

  describe('(with verify) handles', function()
    do_both(true)
  end)

  describe('(without verify) handles', function()
    do_both(false)
  end)
end)

