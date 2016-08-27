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

  -- turn on live updates, ensure that the LiveUpdateStart messages
  -- arrive as expectected
  if activate then
    ok(buffer('live_updates', b, true))
    expectn('LiveUpdateStart', {b, lines, false})
  end

  return b, filename
end

function reopen(buf, expectedlines)
  ok(buffer('live_updates', buf, false))
  expectn('LiveUpdateEnd', {buf})
  command('edit!')
  ok(buffer('live_updates', buf, true))
  expectn('LiveUpdateStart', {buf, origlines, false})
  command('normal! gg')
end

function expectn(name, args)
  -- expect the next message to be the specified notification event
  eq({'notification', name, args}, next_message())
end

describe('liveupdate', function()
  it('knows when you add line to a buffer', function()
    local b, filename = editoriginal(true)

    -- add a new line at the start of the buffer
    command('normal! GyyggP')
    expectn('LiveUpdate', {b, 0, 0, {'original line 6'}})

    -- add multiple lines at the start of the file
    command('normal! GkkyGggP')
    expectn('LiveUpdate', {b, 0, 0, {'original line 4',
                                     'original line 5',
                                     'original line 6'}})

    -- add one line to the middle of the file, several times
    command('normal! ggYjjp')
    command('normal! p')
    command('normal! p')
    expectn('LiveUpdate', {b, 3, 0, {'original line 4'}})
    expectn('LiveUpdate', {b, 4, 0, {'original line 4'}})
    expectn('LiveUpdate', {b, 5, 0, {'original line 4'}})

    -- add multiple lines to the middle of the file
    command('normal! gg4Yjjp')
    expectn('LiveUpdate', {b, 3, 0, {'original line 4',
                                     'original line 5',
                                     'original line 6',
                                     'original line 4'}})

    -- add one line to the end of the file
    command('normal! ggYGp')
    expectn('LiveUpdate', {b, 17, 0, {'original line 4'}})

    -- add one line to the end of the file, several times
    command('normal! ggYGppp')
    expectn('LiveUpdate', {b, 18, 0, {'original line 4'}})
    expectn('LiveUpdate', {b, 19, 0, {'original line 4'}})
    expectn('LiveUpdate', {b, 20, 0, {'original line 4'}})

    -- add several lines to the end of the file, several times
    command('normal! gg4YGp')
    command('normal! Gp')
    command('normal! Gp')
    firstfour = {'original line 4',
                 'original line 5',
                 'original line 6',
                 'original line 4'}
    expectn('LiveUpdate', {b, 21,  0, firstfour})
    expectn('LiveUpdate', {b, 25, 0, firstfour})
    expectn('LiveUpdate', {b, 29, 0, firstfour})

    -- create a new empty buffer and wipe out the old one ... this will
    -- turn off live updates
    command('enew!')
    expectn('LiveUpdateEnd', {b})

    -- add a line at the start of an empty file
    command('enew')
    b2 = nvim('get_current_buf')
    ok(buffer('live_updates', b2, true))
    expectn('LiveUpdateStart', {b2, {""}, false})
    eval('append(0, ["new line 1"])')
    expectn('LiveUpdate', {b2, 0, 0, {'new line 1'}})

    -- turn off live updates manually
    buffer('live_updates', b2, false)
    expectn('LiveUpdateEnd', {b2})

    -- add multiple lines to a blank file
    command('enew!')
    b3 = nvim('get_current_buf')
    ok(buffer('live_updates', b3, true))
    expectn('LiveUpdateStart', {b3, {""}, false})
    eval('append(0, ["new line 1", "new line 2", "new line 3"])')
    expectn('LiveUpdate', {b3, 0, 0, {'new line 1', 'new line 2', 'new line 3'}})

    -- use the API itself to add a line to the start of the buffer
    buffer('set_lines', b3, 0, 0, true, {'New First Line'})
    expectn('LiveUpdate', {b3, 0, 0, {"New First Line"}})

    os.remove(filename)
  end)

  it('knows when you remove lines from a buffer', function()
    local b, filename = editoriginal(true)

    -- remove one line from start of file
    command('normal! dd')
    expectn('LiveUpdate', {b, 0, 1, {}})

    -- remove multiple lines from the start of the file
    command('normal! 4dd')
    expectn('LiveUpdate', {b, 0, 4, {}})

    -- remove multiple lines from middle of file
    reopen(b, origlines)
    command('normal! jj3dd')
    expectn('LiveUpdate', {b, 2, 3, {}})

    -- remove one line from the end of the file
    reopen(b, origlines)
    command('normal! Gdd')
    expectn('LiveUpdate', {b, 5, 1, {}})

    -- remove multiple lines from the end of the file
    reopen(b, origlines)
    command('normal! 4G3dd')
    expectn('LiveUpdate', {b, 3, 3, {}})

    -- pretend to remove heaps lines from the end of the file but really
    -- just remove two
    reopen(b, origlines)
    command('normal! Gk5dd')
    expectn('LiveUpdate', {b, 4, 2, {}})

    os.remove(filename)
  end)

  it('knows when you modify lines of text', function()
    local b, filename = editoriginal(true)

    -- some normal text editing
    command('normal! A555')
    expectn('LiveUpdate', {b, 0, 1, {'original line 1555'}})
    command('normal! jj8X')
    expectn('LiveUpdate', {b, 2, 1, {'origin3'}})

    -- modify multiple lines at once using visual block mode
    reopen(b, origlines)
    command('normal! jjw')
    nvim('input', '\x16jjllx')
    expectn('LiveUpdate',
            {b, 2, 3, {'original e 3', 'original e 4', 'original e 5'}})

    ---- replace part of a line line using :s
    reopen(b, origlines)
    command('3s/line 3/foo/')
    expectn('LiveUpdate', {b, 2, 1, {'original foo'}})

    ---- replace parts of several lines line using :s
    reopen(b, origlines)
    command('%s/line [35]/foo/')
    expectn('LiveUpdate',
            {b, 2, 3, {'original foo', 'original line 4', 'original foo'}})

    -- type text into the first line of a blank file, one character at a time
    command('enew!')
    expectn('LiveUpdateEnd', {b})
    bnew = nvim('get_current_buf')
    ok(buffer('live_updates', bnew, true))
    expectn('LiveUpdateStart', {bnew, {''}, false})
    nvim('input', 'i')
    nvim('input', 'h')
    nvim('input', 'e')
    nvim('input', 'l')
    nvim('input', 'l')
    nvim('input', 'o')
    expectn('LiveUpdate', {bnew, 0, 1, {'h'}})
    expectn('LiveUpdate', {bnew, 0, 1, {'he'}})
    expectn('LiveUpdate', {bnew, 0, 1, {'hel'}})
    expectn('LiveUpdate', {bnew, 0, 1, {'hell'}})
    expectn('LiveUpdate', {bnew, 0, 1, {'hello'}})
  end)

  it('knows when you replace lines', function()
    local b, filename = editoriginal(true)

    -- blast away parts of some lines with visual mode
    command('normal! jjwvjjllx')
    expectn('LiveUpdate', {b, 2, 1, {'original '}})
    expectn('LiveUpdate', {b, 3, 1, {}})
    expectn('LiveUpdate', {b, 3, 1, {'e 5'}})
    expectn('LiveUpdate', {b, 2, 1, {'original e 5'}})
    expectn('LiveUpdate', {b, 3, 1, {}})

    -- blast away a few lines using :g
    reopen(b, origlines)
    command('global/line [35]/delete')
    expectn('LiveUpdate', {b, 2, 1, {}})
    expectn('LiveUpdate', {b, 3, 1, {}})
  end)

  it('knows when you filter lines', function()
    -- Test filtering lines with !sort
    local b, filename = editoriginal(true, {"A", "C", "E", "B", "D", "F"})

    command('silent 2,5!sort')
    -- the change comes through as two changes:
    -- 1) addition of the new lines after the filtered lines
    -- 2) removal of the original lines
    expectn('LiveUpdate', {b, 5, 0, {"B", "C", "D", "E"}})
    expectn('LiveUpdate', {b, 1, 4, {}})
  end)

  it('deactivates when your buffer changes outside vim', function()
    -- Test changing file from outside vim and reloading using :edit
    local lines = {"Line 1", "Line 2"};
    local b, filename = editoriginal(true, lines)

    command('normal! x')
    expectn('LiveUpdate', {b, 0, 1, {'ine 1'}})
    command('undo')
    expectn('LiveUpdate', {b, 0, 1, {'Line 1'}})

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
    b1, f1 = editoriginal(true, {'A1', 'A2'})
    b1nr = eval('bufnr("")')
    command('split')
    b2, f2 = open(true, {'B1', 'B2'})
    b2nr = eval('bufnr("")')
    command('split')
    b3, f3 = open(true, {'C1', 'C2'})
    b3nr = eval('bufnr("")')

    -- make a new window for moving between buffers
    command('split')

    command('b'..b1nr)
    command('normal! x')
    command('undo')
    expectn('LiveUpdate', {b1, 0, 1, {'1'}})
    expectn('LiveUpdate', {b1, 0, 1, {'A1'}})

    command('b'..b2nr)
    command('normal! x')
    command('undo')
    expectn('LiveUpdate', {b2, 0, 1, {'1'}})
    expectn('LiveUpdate', {b2, 0, 1, {'B1'}})

    command('b'..b3nr)
    command('normal! x')
    command('undo')
    expectn('LiveUpdate', {b3, 0, 1, {'1'}})
    expectn('LiveUpdate', {b3, 0, 1, {'C1'}})
  end)

  it('doesn\'t get confused when you turn watching on/off many times',
     function()
    local channel = nvim('get_api_info')[1]
    local b, filename = editoriginal(false)

    -- turn on live updates many times
    ok(buffer('live_updates', b, true))
    ok(buffer('live_updates', b, true))
    ok(buffer('live_updates', b, true))
    ok(buffer('live_updates', b, true))
    ok(buffer('live_updates', b, true))
    expectn('LiveUpdateStart', {b, origlines, false})
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

  it('doesnt get confused when you turn watching on/off many times',
     function()
    local channel = nvim('get_api_info')[1]
    local b, filename = editoriginal(false)

    -- turn on live updates many times
    ok(buffer('live_updates', b, true))
    ok(buffer('live_updates', b, true))
    ok(buffer('live_updates', b, true))
    ok(buffer('live_updates', b, true))
    ok(buffer('live_updates', b, true))
    expectn('LiveUpdateStart', {b, origlines, false})
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
    local b, filename = open(false, lines)

    -- turn on live updates for sessions 1, 2 and 3
    ok(request(1, 'nvim_buf_live_updates', b, true))
    ok(request(2, 'nvim_buf_live_updates', b, true))
    ok(request(3, 'nvim_buf_live_updates', b, true))
    wantn(1, 'LiveUpdateStart', {b, lines, false})
    wantn(2, 'LiveUpdateStart', {b, lines, false})
    wantn(3, 'LiveUpdateStart', {b, lines, false})

    -- make a change to the buffer
    command('normal! x')
    wantn(1, 'LiveUpdate', {b, 0, 1, {'AA'}})
    wantn(2, 'LiveUpdate', {b, 0, 1, {'AA'}})
    wantn(3, 'LiveUpdate', {b, 0, 1, {'AA'}})

    -- stop watching on channel 1
    ok(request(1, 'nvim_buf_live_updates', b, false))
    wantn(1, 'LiveUpdateEnd', {b})

    -- undo the change to buffer 1
    command('undo')
    wantn(2, 'LiveUpdate', {b, 0, 1, {'AAA'}})
    wantn(3, 'LiveUpdate', {b, 0, 1, {'AAA'}})

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
    local b, filename = editoriginal(true, {'AAA'})
    local channel = nvim('get_api_info')[1]

    -- test live updates are working
    command('normal! x')
    expectn('LiveUpdate', {b, 0, 1, {'AA'}})
    command('undo')
    expectn('LiveUpdate', {b, 0, 1, {'AAA'}})

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
    local b, filename = editoriginal(true, {'AAA'})
    local channel = nvim('get_api_info')[1]

    -- test live updates are working
    command('normal! x')
    expectn('LiveUpdate', {b, 0, 1, {'AA'}})
    command('undo')
    expectn('LiveUpdate', {b, 0, 1, {'AAA'}})

    -- close our buffer by creating a new one
    command('set hidden')
    command('enew')

    -- note that no LiveUpdateEnd is sent
    eval('rpcnotify('..channel..', "Hello There")')
    expectn('Hello There', {})

    -- reopen the original buffer, make sure Live Updates are still active
    command('b1')
    command('normal! x')
    expectn('LiveUpdate', {b, 0, 1, {'AA'}})
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
