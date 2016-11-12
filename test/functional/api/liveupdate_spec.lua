local helpers = require('test.functional.helpers')(after_each)
local eq, ok = helpers.eq, helpers.ok
local buffer, command, eval, nvim, next_message = helpers.buffer,
  helpers.command, helpers.eval, helpers.nvim, helpers.next_message

local origlines = {"original line 1",
                   "original line 2",
                   "original line 3",
                   "original line 4",
                   "original line 5",
                   "original line 6"}

function editoriginal(activate, lines)
  if not lines then
    lines = origlines
  end
  -- load up the file with the correct contents
  helpers.clear()
  return open(activate, lines)
end

function open(activate, lines)
  local filename = helpers.tmpname()
  helpers.write_file(filename, table.concat(lines, "\n").."\n")
  command('edit ' .. filename)
  local b = nvim('get_current_buf')
  -- what is the value of b:changedtick?
  local tick = eval('b:changedtick')

  -- turn on live updates, ensure that the LiveUpdateStart messages
  -- arrive as expectected
  if activate then
    ok(buffer('live_updates', b, true))
    expectn('LiveUpdateStart', {b, tick, lines, false})
  end

  return b, tick, filename
end

function reopen(buf, expectedlines)
  ok(buffer('live_updates', buf, false))
  expectn('LiveUpdateEnd', {buf})
  -- for some reason the :edit! increments tick by 2
  command('edit!')
  local tick = eval('b:changedtick')
  ok(buffer('live_updates', buf, true))
  expectn('LiveUpdateStart', {buf, tick, origlines, false})
  command('normal! gg')
  return tick
end

function expectn(name, args)
  -- expect the next message to be the specified notification event
  eq({'notification', name, args}, next_message())
end

describe('liveupdate', function()
  it('knows when you add line to a buffer', function()
    local b, tick = editoriginal(true)

    -- add a new line at the start of the buffer
    command('normal! GyyggP')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 0, 0, {'original line 6'}})

    -- add multiple lines at the start of the file
    command('normal! GkkyGggP')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 0, 0, {'original line 4',
                                           'original line 5',
                                           'original line 6'}})

    -- add one line to the middle of the file, several times
    command('normal! ggYjjp')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 3, 0, {'original line 4'}})
    command('normal! p')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 4, 0, {'original line 4'}})
    command('normal! p')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 5, 0, {'original line 4'}})

    -- add multiple lines to the middle of the file
    command('normal! gg4Yjjp')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 3, 0, {'original line 4',
                                           'original line 5',
                                           'original line 6',
                                           'original line 4'}})

    -- add one line to the end of the file
    command('normal! ggYGp')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 17, 0, {'original line 4'}})

    -- add one line to the end of the file, several times
    command('normal! ggYGppp')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 18, 0, {'original line 4'}})
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 19, 0, {'original line 4'}})
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 20, 0, {'original line 4'}})

    -- add several lines to the end of the file, several times
    command('normal! gg4YGp')
    command('normal! Gp')
    command('normal! Gp')
    firstfour = {'original line 4',
                 'original line 5',
                 'original line 6',
                 'original line 4'}
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 21, 0, firstfour})
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 25, 0, firstfour})
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 29, 0, firstfour})

    -- create a new empty buffer and wipe out the old one ... this will
    -- turn off live updates
    command('enew!')
    expectn('LiveUpdateEnd', {b})

    -- add a line at the start of an empty file
    command('enew')
    local tick = eval('b:changedtick')
    b2 = nvim('get_current_buf')
    ok(buffer('live_updates', b2, true))
    expectn('LiveUpdateStart', {b2, tick, {""}, false})
    eval('append(0, ["new line 1"])')
    tick = tick + 1
    expectn('LiveUpdate', {b2, tick, 0, 0, {'new line 1'}})

    -- turn off live updates manually
    buffer('live_updates', b2, false)
    expectn('LiveUpdateEnd', {b2})

    -- add multiple lines to a blank file
    command('enew!')
    b3 = nvim('get_current_buf')
    ok(buffer('live_updates', b3, true))
    tick = eval('b:changedtick')
    expectn('LiveUpdateStart', {b3, tick, {""}, false})
    eval('append(0, ["new line 1", "new line 2", "new line 3"])')
    tick = tick + 1
    expectn('LiveUpdate', {b3, tick, 0, 0, {'new line 1',
                                            'new line 2',
                                            'new line 3'}})

    -- use the API itself to add a line to the start of the buffer
    buffer('set_lines', b3, 0, 0, true, {'New First Line'})
    tick = tick + 1
    expectn('LiveUpdate', {b3, tick, 0, 0, {"New First Line"}})
  end)

  it('knows when you remove lines from a buffer', function()
    local b, tick = editoriginal(true)

    -- remove one line from start of file
    command('normal! dd')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 0, 1, {}})

    -- remove multiple lines from the start of the file
    command('normal! 4dd')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 0, 4, {}})

    -- remove multiple lines from middle of file
    tick = reopen(b, origlines)
    command('normal! jj3dd')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 2, 3, {}})

    -- remove one line from the end of the file
    tick = reopen(b, origlines)
    command('normal! Gdd')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 5, 1, {}})

    -- remove multiple lines from the end of the file
    tick = reopen(b, origlines)
    command('normal! 4G3dd')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 3, 3, {}})

    -- pretend to remove heaps lines from the end of the file but really
    -- just remove two
    tick = reopen(b, origlines)
    command('normal! Gk5dd')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 4, 2, {}})
  end)

  it('knows when you modify lines of text', function()
    local b, tick = editoriginal(true)

    -- some normal text editing
    command('normal! A555')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 0, 1, {'original line 1555'}})
    command('normal! jj8X')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 2, 1, {'origin3'}})

    -- modify multiple lines at once using visual block mode
    tick = reopen(b, origlines)
    command('normal! jjw')
    nvim('input', '\x16jjllx')
    tick = tick + 1
    expectn('LiveUpdate',
            {b, tick, 2, 3, {'original e 3', 'original e 4', 'original e 5'}})

    -- replace part of a line line using :s
    tick = reopen(b, origlines)
    command('3s/line 3/foo/')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 2, 1, {'original foo'}})

    -- replace parts of several lines line using :s
    tick = reopen(b, origlines)
    command('%s/line [35]/foo/')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 2, 3, {'original foo',
                                           'original line 4',
                                           'original foo'}})

    -- type text into the first line of a blank file, one character at a time
    command('enew!')
    tick = 2
    expectn('LiveUpdateEnd', {b})
    bnew = nvim('get_current_buf')
    ok(buffer('live_updates', bnew, true))
    expectn('LiveUpdateStart', {bnew, tick, {''}, false})
    nvim('input', 'i')
    nvim('input', 'h')
    nvim('input', 'e')
    nvim('input', 'l')
    nvim('input', 'l')
    nvim('input', 'o')
    expectn('LiveUpdate', {bnew, tick + 1, 0, 1, {'h'}})
    expectn('LiveUpdate', {bnew, tick + 2, 0, 1, {'he'}})
    expectn('LiveUpdate', {bnew, tick + 3, 0, 1, {'hel'}})
    expectn('LiveUpdate', {bnew, tick + 4, 0, 1, {'hell'}})
    expectn('LiveUpdate', {bnew, tick + 5, 0, 1, {'hello'}})
  end)

  it('knows when you replace lines', function()
    local b, tick = editoriginal(true)

    -- blast away parts of some lines with visual mode
    command('normal! jjwvjjllx')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 2, 1, {'original '}})
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 3, 1, {}})
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 3, 1, {'e 5'}})
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 2, 1, {'original e 5'}})
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 3, 1, {}})

    -- blast away a few lines using :g
    tick = reopen(b, origlines)
    command('global/line [35]/delete')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 2, 1, {}})
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 3, 1, {}})
  end)

  it('knows when you filter lines', function()
    -- Test filtering lines with !sort
    local b, tick = editoriginal(true, {"A", "C", "E", "B", "D", "F"})

    command('silent 2,5!sort')
    -- the change comes through as two changes:
    -- 1) addition of the new lines after the filtered lines
    -- 2) removal of the original lines
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 5, 0, {"B", "C", "D", "E"}})
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 1, 4, {}})
  end)

  it('deactivates when your buffer changes outside vim', function()
    -- Test changing file from outside vim and reloading using :edit
    local lines = {"Line 1", "Line 2"};
    local b, tick, filename = editoriginal(true, lines)

    command('normal! x')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 0, 1, {'ine 1'}})
    command('undo')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 0, 1, {'Line 1'}})
    tick = tick + 1

    -- change the file directly
    local f = io.open(filename, 'a')
    f:write("another line\n")
    f:flush()
    f:close()

    -- reopen the file and watch live updates shut down
    command('edit')
    expectn('LiveUpdateEnd', {b})
  end)

  it('allows a channel to watch multiple buffers at once', function()
    -- edit 3 buffers, make sure they all have windows visible so that when we
    -- move between buffers, none of them are unloaded
    b1, tick1, f1 = editoriginal(true, {'A1', 'A2'})
    b1nr = eval('bufnr("")')
    command('split')
    b2, tick2, f2 = open(true, {'B1', 'B2'})
    b2nr = eval('bufnr("")')
    command('split')
    b3, tick3, f3 = open(true, {'C1', 'C2'})
    b3nr = eval('bufnr("")')

    -- make a new window for moving between buffers
    command('split')

    command('b'..b1nr)
    command('normal! x')
    tick1 = tick1 + 1
    expectn('LiveUpdate', {b1, tick1, 0, 1, {'1'}})
    command('undo')
    tick1 = tick1 + 1
    expectn('LiveUpdate', {b1, tick1, 0, 1, {'A1'}})
    tick1 = tick1 + 1 -- :undo causes another increment after the LiveUpdate

    command('b'..b2nr)
    command('normal! x')
    tick2 = tick2 + 1
    expectn('LiveUpdate', {b2, tick2, 0, 1, {'1'}})
    command('undo')
    tick2 = tick2 + 1
    expectn('LiveUpdate', {b2, tick2, 0, 1, {'B1'}})
    tick2 = tick2 + 1 -- :undo causes another increment after the LiveUpdate

    command('b'..b3nr)
    command('normal! x')
    tick3 = tick3 + 1
    expectn('LiveUpdate', {b3, tick3, 0, 1, {'1'}})
    command('undo')
    tick3 = tick3 + 1
    expectn('LiveUpdate', {b3, tick3, 0, 1, {'C1'}})
  end)

  it('doesn\'t get confused when you turn watching on/off many times',
     function()
    local channel = nvim('get_api_info')[1]
    local b, tick = editoriginal(false)

    -- turn on live updates many times
    ok(buffer('live_updates', b, true))
    ok(buffer('live_updates', b, true))
    ok(buffer('live_updates', b, true))
    ok(buffer('live_updates', b, true))
    ok(buffer('live_updates', b, true))
    expectn('LiveUpdateStart', {b, tick, origlines, false})
    eval('rpcnotify('..channel..', "Hello There")')
    expectn('Hello There', {})

    -- turn live updates off many times
    ok(buffer('live_updates', b, false))
    ok(buffer('live_updates', b, false))
    ok(buffer('live_updates', b, false))
    ok(buffer('live_updates', b, false))
    ok(buffer('live_updates', b, false))
    expectn('LiveUpdateEnd', {b})
    eval('rpcnotify('..channel..', "Hello Again")')
    expectn('Hello Again', {})
  end)

  it('is able to notify several channels at once', function()
    helpers.clear()

    local addsession = function(where)
      eval('serverstart("'..where..'")')
      local session = helpers.connect(where)
      return session
    end

    -- create several new sessions, in addition to our main API
    sessions = {}
    sessions[1] = addsession(helpers.tmpname()..'.1')
    sessions[2] = addsession(helpers.tmpname()..'.2')
    sessions[3] = addsession(helpers.tmpname()..'.3')

    function request(sessionnr, method, ...)
      local status, rv = sessions[sessionnr]:request(method, ...)
      if not status then
        error(rv[2])
      end
      return rv
    end

    function wantn(sessionid, name, args)
      local session = sessions[sessionid]
      eq({'notification', name, args}, session:next_message())
    end

    -- edit a new file, but don't turn on live updates
    local lines = {'AAA', 'BBB'}
    local b, tick = open(false, lines)

    -- turn on live updates for sessions 1, 2 and 3
    ok(request(1, 'nvim_buf_live_updates', b, true))
    ok(request(2, 'nvim_buf_live_updates', b, true))
    ok(request(3, 'nvim_buf_live_updates', b, true))
    wantn(1, 'LiveUpdateStart', {b, tick, lines, false})
    wantn(2, 'LiveUpdateStart', {b, tick, lines, false})
    wantn(3, 'LiveUpdateStart', {b, tick, lines, false})

    -- make a change to the buffer
    command('normal! x')
    tick = tick + 1
    wantn(1, 'LiveUpdate', {b, tick, 0, 1, {'AA'}})
    wantn(2, 'LiveUpdate', {b, tick, 0, 1, {'AA'}})
    wantn(3, 'LiveUpdate', {b, tick, 0, 1, {'AA'}})

    -- stop watching on channel 1
    ok(request(1, 'nvim_buf_live_updates', b, false))
    wantn(1, 'LiveUpdateEnd', {b})

    -- undo the change to buffer 1
    command('undo')
    tick = tick + 1
    wantn(2, 'LiveUpdate', {b, tick, 0, 1, {'AAA'}})
    wantn(3, 'LiveUpdate', {b, tick, 0, 1, {'AAA'}})
    tick = tick + 1

    -- make sure there are no other pending LiveUpdate messages going to
    -- channel 1
    local channel1 = request(1, 'nvim_get_api_info')[1]
    eval('rpcnotify('..channel1..', "Hello")')
    wantn(1, 'Hello', {})

    -- close the buffer and channels 2 and 3 should get a LiveUpdateEnd
    -- notification
    command('edit')
    wantn(2, 'LiveUpdateEnd', {b})
    wantn(3, 'LiveUpdateEnd', {b})

    -- make sure there are no other pending LiveUpdate messages going to
    -- channel 1
    local channel1 = request(1, 'nvim_get_api_info')[1]
    eval('rpcnotify('..channel1..', "Hello Again")')
    wantn(1, 'Hello Again', {})
  end)

  it('turns off updates when a buffer is closed', function()
    local b, tick = editoriginal(true, {'AAA'})
    local channel = nvim('get_api_info')[1]

    -- test live updates are working
    command('normal! x')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 0, 1, {'AA'}})
    command('undo')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 0, 1, {'AAA'}})
    -- undo causes another increment of b:changedtick, but after the LiveUpdate
    -- has been sent
    tick = tick + 1

    -- close our buffer by creating a new one
    command('enew')
    expectn('LiveUpdateEnd', {b})

    -- reopen the original buffer, make sure there are no Live Updates sent
    command('b1')
    command('normal! x')

    eval('rpcnotify('..channel..', "Hello There")')
    expectn('Hello There', {})
  end)
  
  -- test what happens when a buffer is hidden
  it('keeps updates turned on if the buffer is hidden', function()
    local b, tick = editoriginal(true, {'AAA'})
    local channel = nvim('get_api_info')[1]

    -- test live updates are working
    command('normal! x')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 0, 1, {'AA'}})
    command('undo')
    tick = tick + 1
    expectn('LiveUpdate', {b, tick, 0, 1, {'AAA'}})

    -- close our buffer by creating a new one
    command('set hidden')
    command('enew')

    -- note that no LiveUpdateEnd is sent
    eval('rpcnotify('..channel..', "Hello There")')
    expectn('Hello There', {})

    -- reopen the original buffer, make sure Live Updates are still active
    command('b1')
    command('normal! x')
    tick = tick + 2
    expectn('LiveUpdate', {b, tick, 0, 1, {'AA'}})
  end)

  it('turns off live updates when a buffer is unloaded, deleted, or wiped',
     function()
    -- start with a blank nvim
    helpers.clear()
    -- need to make a new window with a buffer because :bunload doesn't let you
    -- unload the last buffer
    command('new')
    for i, cmd in ipairs({'bunload', 'bdelete', 'bwipeout'}) do
      -- open a brand spanking new file
      local b, filename = open(true, {'AAA'})

      -- call :bunload or whatever the command is, and then check that we
      -- receive a LiveUpdateEnd
      command(cmd)
      expectn('LiveUpdateEnd', {b})
    end
  end)
end)
