-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)

local command = helpers.command
local meths = helpers.meths
local clear = helpers.clear
local eq = helpers.eq

local origlines = {"original line 1",
                   "original line 2",
                   "original line 3",
                   "original line 4",
                   "original line 5",
                   "original line 6"}

describe('lua: buffer event callbacks', function()
  before_each(function()
    clear()
    meths.execute_lua([[
      local events = {}

      function test_register(bufnr, id, changedtick)
        local function callback(...)
          table.insert(events, {id, ...})
          if test_unreg == id then
            return true
          end
        end
        local opts = {on_lines=callback, on_detach=callback}
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
    ]], {})
  end)

  it('works', function()
    meths.buf_set_lines(0, 0, -1, true, origlines)
    meths.execute_lua("return test_register(...)", {0, "test1"})
    local tick = meths.buf_get_changedtick(0)

    command('normal! GyyggP')
    tick = tick + 1
    eq({{ "test1", "lines", 1, tick, 0, 0, 1 }},
       meths.execute_lua("return get_events(...)", {}))

    meths.buf_set_lines(0, 3, 5, true, {"changed line"})
    tick = tick + 1
    eq({{ "test1", "lines", 1, tick, 3, 5, 4 }},
       meths.execute_lua("return get_events(...)", {}))

    meths.execute_lua("return test_register(...)", {0, "test2", true})
    tick = tick + 1
    command('undo')

    -- plugins can opt in to receive changedtick events, or choose
    -- to only recieve actual changes.
    eq({{ "test1", "lines", 1, tick, 3, 4, 5 },
        { "test2", "lines", 1, tick, 3, 4, 5 },
        { "test2", "changedtick", 1, tick+1 } },
       meths.execute_lua("return get_events(...)", {}))
    tick = tick + 1

    -- simulate next callback returning true
    meths.execute_lua("test_unreg = 'test1'", {})

    meths.buf_set_lines(0, 6, 7, true, {"x1","x2","x3"})
    tick = tick + 1

    -- plugins can opt in to receive changedtick events, or choose
    -- to only recieve actual changes.
    eq({{ "test1", "lines", 1, tick, 6, 7, 9 },
        { "test2", "lines", 1, tick, 6, 7, 9 }},
       meths.execute_lua("return get_events(...)", {}))

    meths.buf_set_lines(0, 1, 1, true, {"added"})
    tick = tick + 1
    eq({{ "test2", "lines", 1, tick, 1, 1, 2 }},
       meths.execute_lua("return get_events(...)", {}))

    command('bwipe!')
    eq({{ "test2", "detach", 1 }},
       meths.execute_lua("return get_events(...)", {}))
  end)
end)
