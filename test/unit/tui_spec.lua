local helpers = require("test.unit.helpers")(after_each)
local cimport = helpers.cimport
local eq = helpers.eq
local ffi = helpers.ffi
local itp = helpers.gen_itp(it)
local to_cstr = helpers.to_cstr

local cinput = cimport("./src/nvim/tui/input.h")
local rbuffer = cimport("./test/unit/fixtures/rbuffer.h")
local globals = cimport("./src/nvim/globals.h")
local multiqueue = cimport("./test/unit/fixtures/multiqueue.h")
local ui_client = cimport("./src/nvim/ui_client.h")

itp('handle_background_color', function()
  local handle_background_color = cinput.handle_background_color
  local term_input = ffi.new('TermInput', {})
  local events = globals.main_loop.thread_events
  local kIncomplete = cinput.kIncomplete
  local kNotApplicable = cinput.kNotApplicable
  local kComplete = cinput.kComplete

  -- Short-circuit when not waiting for response.
  term_input.waiting_for_bg_response = 0
  eq(kNotApplicable, handle_background_color(term_input))

  local capacity = 100
  local rbuf = ffi.gc(rbuffer.rbuffer_new(capacity), rbuffer.rbuffer_free)
  term_input.read_stream.buffer = rbuf

  local function assert_bg(colorspace, color, bg)
    local term_response = '\027]11;'..colorspace..':'..color..'\007'
    rbuffer.rbuffer_write(rbuf, to_cstr(term_response), #term_response)

    term_input.waiting_for_bg_response = 1
    eq(kComplete, handle_background_color(term_input))
    eq(0, term_input.waiting_for_bg_response)
    eq(0, multiqueue.multiqueue_size(events))
    eq(bg, ({[0]="light", [1] = "dark", [-1] = "none"})
           [tonumber(ui_client.ui_client_bg_response)])

    -- Buffer has been consumed.
    eq(0, rbuf.size)
  end

  assert_bg('rgb', '0000/0000/0000', 'dark')
  assert_bg('rgb', 'ffff/ffff/ffff', 'light')
  assert_bg('rgb', '000/000/000', 'dark')
  assert_bg('rgb', 'fff/fff/fff', 'light')
  assert_bg('rgb', '00/00/00', 'dark')
  assert_bg('rgb', 'ff/ff/ff', 'light')
  assert_bg('rgb', '0/0/0', 'dark')
  assert_bg('rgb', 'f/f/f', 'light')

  assert_bg('rgb', 'f/0/0', 'dark')
  assert_bg('rgb', '0/f/0', 'light')
  assert_bg('rgb', '0/0/f', 'dark')

  assert_bg('rgb', '1/1/1', 'dark')
  assert_bg('rgb', '2/2/2', 'dark')
  assert_bg('rgb', '3/3/3', 'dark')
  assert_bg('rgb', '4/4/4', 'dark')
  assert_bg('rgb', '5/5/5', 'dark')
  assert_bg('rgb', '6/6/6', 'dark')
  assert_bg('rgb', '7/7/7', 'dark')
  assert_bg('rgb', '8/8/8', 'light')
  assert_bg('rgb', '9/9/9', 'light')
  assert_bg('rgb', 'a/a/a', 'light')
  assert_bg('rgb', 'b/b/b', 'light')
  assert_bg('rgb', 'c/c/c', 'light')
  assert_bg('rgb', 'd/d/d', 'light')
  assert_bg('rgb', 'e/e/e', 'light')

  assert_bg('rgb', '0/e/0', 'light')
  assert_bg('rgb', '0/d/0', 'light')
  assert_bg('rgb', '0/c/0', 'dark')
  assert_bg('rgb', '0/b/0', 'dark')

  assert_bg('rgb', 'f/0/f', 'dark')
  assert_bg('rgb', 'f/1/f', 'dark')
  assert_bg('rgb', 'f/2/f', 'dark')
  assert_bg('rgb', 'f/3/f', 'light')
  assert_bg('rgb', 'f/4/f', 'light')

  assert_bg('rgba', '0000/0000/0000/0000', 'dark')
  assert_bg('rgba', '0000/0000/0000/ffff', 'dark')
  assert_bg('rgba', 'ffff/ffff/ffff/0000', 'light')
  assert_bg('rgba', 'ffff/ffff/ffff/ffff', 'light')
  assert_bg('rgba', '000/000/000/000', 'dark')
  assert_bg('rgba', '000/000/000/fff', 'dark')
  assert_bg('rgba', 'fff/fff/fff/000', 'light')
  assert_bg('rgba', 'fff/fff/fff/fff', 'light')
  assert_bg('rgba', '00/00/00/00', 'dark')
  assert_bg('rgba', '00/00/00/ff', 'dark')
  assert_bg('rgba', 'ff/ff/ff/00', 'light')
  assert_bg('rgba', 'ff/ff/ff/ff', 'light')
  assert_bg('rgba', '0/0/0/0', 'dark')
  assert_bg('rgba', '0/0/0/f', 'dark')
  assert_bg('rgba', 'f/f/f/0', 'light')
  assert_bg('rgba', 'f/f/f/f', 'light')


  -- Incomplete sequence: necessarily correct behavior.
  local term_response = '\027]11;rgba:f/f/f/f'  -- missing '\007
  rbuffer.rbuffer_write(rbuf, to_cstr(term_response), #term_response)

  term_input.waiting_for_bg_response = 1
  eq(kIncomplete, handle_background_color(term_input))
  eq(1, term_input.waiting_for_bg_response)
  eq(#term_response, rbuf.size)

  term_response = '\007'
  rbuffer.rbuffer_write(rbuf, to_cstr(term_response), #term_response)
  eq(kComplete, handle_background_color(term_input))
  eq(0, term_input.waiting_for_bg_response)

  eq(0, tonumber(ui_client.ui_client_bg_response))
  eq(0, multiqueue.multiqueue_size(events))
  eq(0, rbuf.size)

  term_response = '\027]11;rg'
  rbuffer.rbuffer_write(rbuf, to_cstr(term_response), #term_response)

  term_input.waiting_for_bg_response = 1
  eq(kIncomplete, handle_background_color(term_input))
  eq(1, term_input.waiting_for_bg_response)
  eq(#term_response, rbuf.size)

  term_response = 'ba:f/f/f/f\007'
  rbuffer.rbuffer_write(rbuf, to_cstr(term_response), #term_response)
  eq(kComplete, handle_background_color(term_input))
  eq(0, term_input.waiting_for_bg_response)

  eq(0, tonumber(ui_client.ui_client_bg_response))
  eq(0, multiqueue.multiqueue_size(events))
  eq(0, rbuf.size)


  -- Does nothing when not at start of buffer.
  term_response = '123\027]11;rgba:f/f/f/f\007456'
  rbuffer.rbuffer_write(rbuf, to_cstr(term_response), #term_response)

  term_input.waiting_for_bg_response = 3
  eq(kNotApplicable, handle_background_color(term_input))
  eq(2, term_input.waiting_for_bg_response)

  eq(0, multiqueue.multiqueue_size(events))
  eq(#term_response, rbuf.size)
  rbuffer.rbuffer_consumed(rbuf, #term_response)


  -- Keeps trailing buffer.
  term_response = '\027]11;rgba:f/f/f/f\007456'
  rbuffer.rbuffer_write(rbuf, to_cstr(term_response), #term_response)

  term_input.waiting_for_bg_response = 1
  eq(kComplete, handle_background_color(term_input))
  eq(0, term_input.waiting_for_bg_response)

  eq(0, multiqueue.multiqueue_size(events))
  eq(3, rbuf.size)
  rbuffer.rbuffer_consumed(rbuf, rbuf.size)
end)
