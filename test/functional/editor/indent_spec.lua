local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed = helpers.clear, helpers.feed
local api = helpers.api
local feed_command = helpers.feed_command

local function set_lines(line_b, line_e, ...)
  api.nvim_buf_set_lines(0, line_b, line_e, true, { ... })
end

local function setup(width, height)
  clear()
  local screen = Screen.new(width, height + 1)
  screen:attach()
  feed_command('setl listchars=space:.,tab:>- list')
  return screen
end

describe("i_Tab with 'sw' not equal to 'ts'", function()
  it('works with mixed tabs and spaces', function()
    local screen = setup(50, 1)
    feed_command('setl ts=5 sw=20 nowrap')
    set_lines(0, 1, '\t\t\t\t' .. (' '):rep(19) .. 'a')
    feed('^i<Tab>')
    screen:expect([[
      >---->---->---->---->---->---->---->----^a         |
      -- INSERT --                                      |
    ]])

    screen = setup(50, 1)
    feed_command('setl ts=5 sw=20 nowrap')
    set_lines(0, 1, '\t' .. (' '):rep(4) .. '\t' .. (' '):rep(9) .. '\t' .. (' '):rep(8) .. 'a')
    feed('^6hi<Tab>')
    screen:expect([[
      >---->---->---->---->---->---->---->----^......a   |
      -- INSERT --                                      |
    ]])
  end)

  -- no effect, since listchars contains tab
  it("works with 'cpoptions=L'", function()
    local screen = setup(50, 1)
    feed_command('setl ts=5 sw=20 nowrap cpoptions+=L')
    set_lines(0, 1, '\t\t\t\t' .. (' '):rep(19) .. 'a')
    feed('^i<Tab>')
    screen:expect([[
      >---->---->---->---->---->---->---->----^a         |
      -- INSERT --                                      |
    ]])

    screen = setup(50, 1)
    feed_command('setl ts=5 sw=20 nowrap cpoptions+=L')
    set_lines(0, 1, '\t' .. (' '):rep(4) .. '\t' .. (' '):rep(9) .. '\t' .. (' '):rep(8) .. 'a')
    feed('^6hi<Tab>')
    screen:expect([[
      >---->---->---->---->---->---->---->----^......a   |
      -- INSERT --                                      |
    ]])
  end)

  it("works with 'cpoptions=L' with tab as ^I", function()
    local screen = setup(50, 1)
    feed_command('setl ts=5 sw=20 nowrap cpoptions+=L listchars=space:.')
    set_lines(0, 1, '\t\t\t\t\t\t\t\t' .. (' '):rep(5) .. 'a')
    feed('^i<Tab>')
    screen:expect([[
      ^I^I^I^I^I^I^I^I^I^I^I^I^I^I^I^I^I^I^I^I^a         |
      -- INSERT --                                      |
    ]])

    screen = setup(50, 1)
    feed_command('setl ts=5 sw=20 nowrap cpoptions+=L listchars=space:.')
    set_lines(0, 1, '\t' .. (' '):rep(1) .. '\t' .. (' '):rep(3) .. '\t' .. (' '):rep(4) .. 'a')
    feed('^3hi<Tab>')
    screen:expect([[
      ^I^I^I^I^I^I^I^I^I^I^...a                          |
      -- INSERT --                                      |
    ]])
  end)

  it("works with 'cpoptions=L' with tab as <09>", function()
    local screen = setup(50, 1)
    feed_command('setl ts=5 sw=20 nowrap')
    feed_command('setl display+=uhex cpoptions+=L listchars=space:.')
    set_lines(0, 1, '\t\t\t\t' .. (' '):rep(5) .. 'a')
    feed('^i<Tab>')
    screen:expect([[
      <09><09><09><09><09><09><09><09><09><09>^a         |
      -- INSERT --                                      |
    ]])

    screen = setup(50, 1)
    feed_command('setl ts=5 sw=20 nowrap')
    feed_command('setl display+=uhex cpoptions+=L listchars=space:.')
    set_lines(0, 1, '\t' .. (' '):rep(3) .. '\t' .. (' '):rep(6) .. '\t' .. (' '):rep(7) .. 'a')
    feed('^5hi<Tab>')
    screen:expect([[
      <09><09><09><09><09><09><09><09><09><09>^.....a    |
      -- INSERT --                                      |
    ]])
  end)

  it('works in replace mode', function()
    local screen = setup(80, 1)
    feed_command('setl ts=5 sw=20 nowrap')
    set_lines(0, 1, '\t' .. (' '):rep(4) .. '\t' .. (' '):rep(9) .. '\t' .. (' '):rep(8) .. 'a')
    feed('^6hR<Tab><Tab>')
    screen:expect([[
      >----....>.........>..>-->---->---->---->---->---->---->----^....a               |
      -- REPLACE --                                                                   |
    ]])

    feed('<BS>')
    screen:expect([[
      >----....>.........>..>-->---->---->----^.....a                                  |
      -- REPLACE --                                                                   |
    ]])

    feed('<BS>')
    screen:expect([[
      >----....>.........>^........a                                                   |
      -- REPLACE --                                                                   |
    ]])

    feed('<BS>')
    screen:expect([[
      ^>----....>.........>........a                                                   |
      -- REPLACE --                                                                   |
    ]])
  end)

  it('works in virtual replace mode', function()
    local screen = setup(80, 1)
    feed_command('setl ts=5 sw=20 nowrap')
    set_lines(0, 1, '\t    \t         \t        ' .. ('a'):rep(20) .. ('b'):rep(20))
    feed('^6hgR<Tab><Tab>')
    screen:expect([[
      >----....>.........>..>-->---->---->---->---->---->---->----^bbbbbbbb            |
      -- VREPLACE --                                                                  |
    ]])

    feed('<BS>')
    screen:expect([[
      >----....>.........>..>-->---->---->----^aaaaaaaabbbbbbbbbbbbbbbbbbbb            |
      -- VREPLACE --                                                                  |
    ]])

    feed('<BS>')
    screen:expect([[
      >----....>.........>^........aaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbb            |
      -- VREPLACE --                                                                  |
    ]])

    feed('<BS>')
    screen:expect([[
      ^>----....>.........>........aaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbb            |
      -- VREPLACE --                                                                  |
    ]])
  end)

  it("works with 'bri'", function()
    pending('skipped (not yet fixed)')

    local screen = setup(20, 4)
    feed_command('setl ts=5 sw=20 bri briopt=min:10')
    set_lines(0, 1, '\t\t\t\t' .. (' '):rep(19) .. 'a')
    feed('^i<Tab>')
    screen:expect([[
      >---->---->---->----|
                >---->----|
                >---->----|
                ^a         |
      -- INSERT --        |
    ]])
  end)
end)

describe('i_CTRL-T inside indentation', function()
  it("works with 'noexpandtab'", function()
    local screen = setup(30, 1)
    feed_command('setl ts=3 sw=3 noexpandtab nowrap')
    set_lines(0, 1, '\t\t' .. 'a')
    feed('^hi<C-T>') -- last tab before first non-blank
    screen:expect([[
      >-->--^>--a                    |
      -- INSERT --                  |
    ]])
  end)

  it("works with 'noexpandtab' with spaces", function()
    local screen = setup(30, 1)
    feed_command('setl ts=5 sw=5 noexpandtab nowrap')
    local s = (' '):rep(5)
    local t = '\t'
    set_lines(0, 1, t .. s .. t .. s .. '    a')
    feed('^hhhi<C-T>')
    -- inserts 2 spaces to make cursor 3 cells behind first non-blank
    screen:expect([[
      >---->---->---->----..^>--a    |
      -- INSERT --                  |
    ]])
  end)

  it("works with 'noexpandtab' and 'bri'", function()
    pending('skipped (not yet fixed)')

    local screen = setup(20, 3)
    feed_command('setl ts=12 sw=12 noexpandtab wrap bri briopt=min:5')
    local t = '\t'
    set_lines(0, 1, t .. t .. 'a')
    feed('^hi<C-T>')
    screen:expect([[
      >----------->-------|
                     ----^>|
                     -----|
      -- INSERT --        |
    ]])
  end)

  it('works with inline virtual text', function()
    pending('skipped (not yet fixed)')

    local screen = setup(70, 1)
    feed_command('setl ts=10 sw=10 nowrap')
    set_lines(0, 1, '\t\t\t\t' .. 'a')
    local ns = api.nvim_create_namespace('')
    api.nvim_buf_set_extmark(0, ns, 0, 0, {
      virt_text = { { ('a'):rep(50) } },
      virt_text_pos = 'inline',
    })
    feed('^hi<C-T>') -- last tab before first non-blank
    screen:expect([[
      --------->---------^>---------aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      -- INSERT --                                                          |
    ]])
  end)
end)

describe('Shift right in visual block mode', function()
  it('adds one tab', function()
    local screen = setup(20, 4)
    set_lines(0, 1, 'a\t\t\t\t' .. (' '):rep(20) .. 'a')
    feed_command('setl ts=5 sw=5')
    helpers.exec([=[execute "norm! 0l\<C-V>>"]=]) -- shift first tab
    screen:expect([[
      a^>--->---->---->----|
      >---->---->---->----|
      >----a              |
      ~                   |
      :setl ts=5 sw=5     |
    ]])
  end)

  it("does not work with 'bri'", function()
    local screen = setup(20, 4)
    feed_command('setl ts=5 sw=5 bri briopt=min:10')
    set_lines(0, 1, 'a\t\t\t\t' .. (' '):rep(20) .. 'a')
    helpers.exec([=[execute "norm! 0l\<C-V>>"]=]) -- shift first tab
    -- 'breakindent' should have had no effect, since the line starts with "a"
    screen:expect([[
      a^>--->---->---->----|
      >---->---->---->----|
      >---->---->---->----|
      >----a              |
                          |
    ]])
  end)
end)
