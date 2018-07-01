local helpers = require('test.functional.helpers')(after_each)
local eq, ok = helpers.eq, helpers.ok
local buffer, command, eval, nvim, next_msg = helpers.buffer,
  helpers.command, helpers.eval, helpers.nvim, helpers.next_msg
local expect_err = helpers.expect_err
local nvim_prog = helpers.nvim_prog
local write_file = helpers.write_file

local origlines = {"original line 1",
                   "original line 2",
                   "original line 3",
                   "original line 4",
                   "original line 5",
                   "original line 6"}

local function expectn(name, args)
  -- expect the next message to be the specified notification event
  eq({'notification', name, args}, next_msg())
end

local function sendkeys(keys)
  nvim('input', keys)
  -- give nvim some time to process msgpack requests before possibly sending
  -- more key presses - otherwise they all pile up in the queue and get
  -- processed at once
  local ntime = os.clock() + 0.1
  repeat until os.clock() > ntime
end

local function open(activate, lines)
  local filename = helpers.tmpname()
  write_file(filename, table.concat(lines, "\n").."\n", true)
  command('edit ' .. filename)
  local b = nvim('get_current_buf')
  -- what is the value of b:changedtick?
  local tick = eval('b:changedtick')

  -- Enable buffer events, ensure that the nvim_buf_lines_event messages
  -- arrive as expected
  if activate then
    local firstline = 0
    ok(buffer('attach', b, true, {}))
    expectn('nvim_buf_lines_event', {b, tick, firstline, -1, lines, false})
  end

  return b, tick, filename
end

local function editoriginal(activate, lines)
  if not lines then
    lines = origlines
  end
  -- load up the file with the correct contents
  helpers.clear()
  return open(activate, lines)
end

local function reopen(buf, expectedlines)
  ok(buffer('detach', buf))
  expectn('nvim_buf_detach_event', {buf})
  -- for some reason the :edit! increments tick by 2
  command('edit!')
  local tick = eval('b:changedtick')
  ok(buffer('attach', buf, true, {}))
  local firstline = 0
  expectn('nvim_buf_lines_event', {buf, tick, firstline, -1, expectedlines, false})
  command('normal! gg')
  return tick
end

local function reopenwithfolds(b)
  -- discard any changes to the buffer
  local tick = reopen(b, origlines)

  -- use markers for folds, make all folds open by default
  command('setlocal foldmethod=marker foldlevel=20')

  -- add a fold
  command('2,4fold')
  tick = tick + 1
  expectn('nvim_buf_lines_event', {b, tick, 1, 4, {'original line 2/*{{{*/',
                                          'original line 3',
                                          'original line 4/*}}}*/'}, false})
  -- make a new fold that wraps lines 1-6
  command('1,6fold')
  tick = tick + 1
  expectn('nvim_buf_lines_event', {b, tick, 0, 6, {'original line 1/*{{{*/',
                                          'original line 2/*{{{*/',
                                          'original line 3',
                                          'original line 4/*}}}*/',
                                          'original line 5',
                                          'original line 6/*}}}*/'}, false})
  return tick
end

describe('API: buffer events:', function()
  it('when lines are added', function()
    local b, tick = editoriginal(true)

    -- add a new line at the start of the buffer
    command('normal! GyyggP')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 0, {'original line 6'}, false})

    -- add multiple lines at the start of the file
    command('normal! GkkyGggP')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 0, {'original line 4',
                                           'original line 5',
                                           'original line 6'}, false})

    -- add one line to the middle of the file, several times
    command('normal! ggYjjp')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 3, 3, {'original line 4'}, false})
    command('normal! p')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 4, 4, {'original line 4'}, false})
    command('normal! p')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 5, 5, {'original line 4'}, false})

    -- add multiple lines to the middle of the file
    command('normal! gg4Yjjp')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 3, 3, {'original line 4',
                                           'original line 5',
                                           'original line 6',
                                           'original line 4'}, false})

    -- add one line to the end of the file
    command('normal! ggYGp')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 17, 17, {'original line 4'}, false})

    -- add one line to the end of the file, several times
    command('normal! ggYGppp')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 18, 18, {'original line 4'}, false})
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 19, 19, {'original line 4'}, false})
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 20, 20, {'original line 4'}, false})

    -- add several lines to the end of the file, several times
    command('normal! gg4YGp')
    command('normal! Gp')
    command('normal! Gp')
    local firstfour = {'original line 4',
                 'original line 5',
                 'original line 6',
                 'original line 4'}
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 21, 21, firstfour, false})
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 25, 25, firstfour, false})
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 29, 29, firstfour, false})

    -- create a new empty buffer and wipe out the old one ... this will
    -- turn off buffer events
    command('enew!')
    expectn('nvim_buf_detach_event', {b})

    -- add a line at the start of an empty file
    command('enew')
    tick = eval('b:changedtick')
    local b2 = nvim('get_current_buf')
    ok(buffer('attach', b2, true, {}))
    expectn('nvim_buf_lines_event', {b2, tick, 0, -1, {""}, false})
    eval('append(0, ["new line 1"])')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b2, tick, 0, 0, {'new line 1'}, false})

    -- turn off buffer events manually
    buffer('detach', b2)
    expectn('nvim_buf_detach_event', {b2})

    -- add multiple lines to a blank file
    command('enew!')
    local b3 = nvim('get_current_buf')
    ok(buffer('attach', b3, true, {}))
    tick = eval('b:changedtick')
    expectn('nvim_buf_lines_event', {b3, tick, 0, -1, {""}, false})
    eval('append(0, ["new line 1", "new line 2", "new line 3"])')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b3, tick, 0, 0, {'new line 1',
                                            'new line 2',
                                            'new line 3'}, false})

    -- use the API itself to add a line to the start of the buffer
    buffer('set_lines', b3, 0, 0, true, {'New First Line'})
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b3, tick, 0, 0, {"New First Line"}, false})
  end)

  it('when lines are removed', function()
    local b, tick = editoriginal(true)

    -- remove one line from start of file
    command('normal! dd')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 1, {}, false})

    -- remove multiple lines from the start of the file
    command('normal! 4dd')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 4, {}, false})

    -- remove multiple lines from middle of file
    tick = reopen(b, origlines)
    command('normal! jj3dd')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 2, 5, {}, false})

    -- remove one line from the end of the file
    tick = reopen(b, origlines)
    command('normal! Gdd')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 5, 6, {}, false})

    -- remove multiple lines from the end of the file
    tick = reopen(b, origlines)
    command('normal! 4G3dd')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 3, 6, {}, false})

    -- pretend to remove heaps lines from the end of the file but really
    -- just remove two
    tick = reopen(b, origlines)
    command('normal! Gk5dd')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 4, 6, {}, false})
  end)

  it('when text is changed', function()
    local b, tick = editoriginal(true)

    -- some normal text editing
    command('normal! A555')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 1, {'original line 1555'}, false})
    command('normal! jj8X')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 2, 3, {'origin3'}, false})

    -- modify multiple lines at once using visual block mode
    tick = reopen(b, origlines)
    command('normal! jjw')
    sendkeys('<C-v>jjllx')
    tick = tick + 1
    expectn('nvim_buf_lines_event',
            {b, tick, 2, 5, {'original e 3', 'original e 4', 'original e 5'}, false})

    -- replace part of a line line using :s
    tick = reopen(b, origlines)
    command('3s/line 3/foo/')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 2, 3, {'original foo'}, false})

    -- replace parts of several lines line using :s
    tick = reopen(b, origlines)
    command('%s/line [35]/foo/')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 2, 5, {'original foo',
                                           'original line 4',
                                           'original foo'}, false})

    -- type text into the first line of a blank file, one character at a time
    command('enew!')
    tick = 2
    expectn('nvim_buf_detach_event', {b})
    local bnew = nvim('get_current_buf')
    ok(buffer('attach', bnew, true, {}))
    expectn('nvim_buf_lines_event', {bnew, tick, 0, -1, {''}, false})
    sendkeys('i')
    sendkeys('h')
    sendkeys('e')
    sendkeys('l')
    sendkeys('l')
    sendkeys('o\nworld')
    expectn('nvim_buf_lines_event', {bnew, tick + 1, 0, 1, {'h'}, false})
    expectn('nvim_buf_lines_event', {bnew, tick + 2, 0, 1, {'he'}, false})
    expectn('nvim_buf_lines_event', {bnew, tick + 3, 0, 1, {'hel'}, false})
    expectn('nvim_buf_lines_event', {bnew, tick + 4, 0, 1, {'hell'}, false})
    expectn('nvim_buf_lines_event', {bnew, tick + 5, 0, 1, {'hello'}, false})
    expectn('nvim_buf_lines_event', {bnew, tick + 6, 0, 1, {'hello', ''}, false})
    expectn('nvim_buf_lines_event', {bnew, tick + 7, 1, 2, {'world'}, false})
  end)

  it('when lines are replaced', function()
    local b, tick = editoriginal(true)

    -- blast away parts of some lines with visual mode
    command('normal! jjwvjjllx')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 2, 3, {'original '}, false})
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 3, 4, {}, false})
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 3, 4, {'e 5'}, false})
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 2, 3, {'original e 5'}, false})
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 3, 4, {}, false})

    -- blast away a few lines using :g
    tick = reopen(b, origlines)
    command('global/line [35]/delete')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 2, 3, {}, false})
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 3, 4, {}, false})
  end)

  it('when lines are filtered', function()
    -- Test filtering lines with !cat
    local b, tick = editoriginal(true, {"A", "C", "E", "B", "D", "F"})

    command('silent 2,5!cat')
    -- the change comes through as two changes:
    -- 1) addition of the new lines after the filtered lines
    -- 2) removal of the original lines
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 5, 5, {"C", "E", "B", "D"}, false})
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 1, 5, {}, false})
  end)

  it('when you use "o"', function()
    local b, tick = editoriginal(true, {'AAA', 'BBB'})
    command('set noautoindent nosmartindent')

    -- use 'o' to start a new line from a line with no indent
    command('normal! o')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 1, 1, {""}, false})

    -- undo the change, indent line 1 a bit, and try again
    command('undo')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 1, 2, {}, false})
    tick = tick + 1
    expectn('nvim_buf_changedtick_event', {b, tick})
    command('set autoindent')
    command('normal! >>')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 1, {"\tAAA"}, false})
    command('normal! ommm')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 1, 1, {"\t"}, false})
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 1, 2, {"\tmmm"}, false})

    -- undo the change, and try again with 'O'
    command('undo')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 1, 2, {'\t'}, false})
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 1, 2, {}, false})
    tick = tick + 1
    expectn('nvim_buf_changedtick_event', {b, tick})
    command('normal! ggOmmm')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 0, {"\t"}, false})
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 1, {"\tmmm"}, false})
  end)

  it('deactivates if the buffer is changed externally', function()
    -- Test changing file from outside vim and reloading using :edit
    local lines = {"Line 1", "Line 2"};
    local b, tick, filename = editoriginal(true, lines)

    command('normal! x')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 1, {'ine 1'}, false})
    command('undo')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 1, {'Line 1'}, false})
    tick = tick + 1
    expectn('nvim_buf_changedtick_event', {b, tick})

    -- change the file directly
    write_file(filename, "another line\n", true, true)

    -- reopen the file and watch buffer events shut down
    command('edit')
    expectn('nvim_buf_detach_event', {b})
  end)

  it('channel can watch many buffers at once', function()
    -- edit 3 buffers, make sure they all have windows visible so that when we
    -- move between buffers, none of them are unloaded
    local b1, tick1 = editoriginal(true, {'A1', 'A2'})
    local b1nr = eval('bufnr("")')
    command('split')
    local b2, tick2 = open(true, {'B1', 'B2'})
    local b2nr = eval('bufnr("")')
    command('split')
    local b3, tick3 = open(true, {'C1', 'C2'})
    local b3nr = eval('bufnr("")')

    -- make a new window for moving between buffers
    command('split')

    command('b'..b1nr)
    command('normal! x')
    tick1 = tick1 + 1
    expectn('nvim_buf_lines_event', {b1, tick1, 0, 1, {'1'}, false})
    command('undo')
    tick1 = tick1 + 1
    expectn('nvim_buf_lines_event', {b1, tick1, 0, 1, {'A1'}, false})
    tick1 = tick1 + 1
    expectn('nvim_buf_changedtick_event', {b1, tick1})

    command('b'..b2nr)
    command('normal! x')
    tick2 = tick2 + 1
    expectn('nvim_buf_lines_event', {b2, tick2, 0, 1, {'1'}, false})
    command('undo')
    tick2 = tick2 + 1
    expectn('nvim_buf_lines_event', {b2, tick2, 0, 1, {'B1'}, false})
    tick2 = tick2 + 1
    expectn('nvim_buf_changedtick_event', {b2, tick2})

    command('b'..b3nr)
    command('normal! x')
    tick3 = tick3 + 1
    expectn('nvim_buf_lines_event', {b3, tick3, 0, 1, {'1'}, false})
    command('undo')
    tick3 = tick3 + 1
    expectn('nvim_buf_lines_event', {b3, tick3, 0, 1, {'C1'}, false})
    tick3 = tick3 + 1
    expectn('nvim_buf_changedtick_event', {b3, tick3})
  end)

  it('does not get confused if enabled/disabled many times',
     function()
    local channel = nvim('get_api_info')[1]
    local b, tick = editoriginal(false)

    -- Enable buffer events many times.
    ok(buffer('attach', b, true, {}))
    ok(buffer('attach', b, true, {}))
    ok(buffer('attach', b, true, {}))
    ok(buffer('attach', b, true, {}))
    ok(buffer('attach', b, true, {}))
    expectn('nvim_buf_lines_event', {b, tick, 0, -1, origlines, false})
    eval('rpcnotify('..channel..', "Hello There")')
    expectn('Hello There', {})

    -- Disable buffer events many times.
    ok(buffer('detach', b))
    ok(buffer('detach', b))
    ok(buffer('detach', b))
    ok(buffer('detach', b))
    ok(buffer('detach', b))
    expectn('nvim_buf_detach_event', {b})
    eval('rpcnotify('..channel..', "Hello Again")')
    expectn('Hello Again', {})
  end)

  it('can notify several channels at once', function()
    helpers.clear()

    -- create several new sessions, in addition to our main API
    local sessions = {}
    local pipe = helpers.new_pipename()
    eval("serverstart('"..pipe.."')")
    sessions[1] = helpers.connect(pipe)
    sessions[2] = helpers.connect(pipe)
    sessions[3] = helpers.connect(pipe)

    local function request(sessionnr, method, ...)
      local status, rv = sessions[sessionnr]:request(method, ...)
      if not status then
        error(rv[2])
      end
      return rv
    end

    local function wantn(sessionid, name, args)
      local session = sessions[sessionid]
      eq({'notification', name, args}, session:next_message())
    end

    -- Edit a new file, but don't enable buffer events.
    local lines = {'AAA', 'BBB'}
    local b, tick = open(false, lines)

    -- Enable buffer events for sessions 1, 2 and 3.
    ok(request(1, 'nvim_buf_attach', b, true, {}))
    ok(request(2, 'nvim_buf_attach', b, true, {}))
    ok(request(3, 'nvim_buf_attach', b, true, {}))
    wantn(1, 'nvim_buf_lines_event', {b, tick, 0, -1, lines, false})
    wantn(2, 'nvim_buf_lines_event', {b, tick, 0, -1, lines, false})
    wantn(3, 'nvim_buf_lines_event', {b, tick, 0, -1, lines, false})

    -- Change the buffer.
    command('normal! x')
    tick = tick + 1
    wantn(1, 'nvim_buf_lines_event', {b, tick, 0, 1, {'AA'}, false})
    wantn(2, 'nvim_buf_lines_event', {b, tick, 0, 1, {'AA'}, false})
    wantn(3, 'nvim_buf_lines_event', {b, tick, 0, 1, {'AA'}, false})

    -- Stop watching on channel 1.
    ok(request(1, 'nvim_buf_detach', b))
    wantn(1, 'nvim_buf_detach_event', {b})

    -- Undo the change to buffer 1.
    command('undo')
    tick = tick + 1
    wantn(2, 'nvim_buf_lines_event', {b, tick, 0, 1, {'AAA'}, false})
    wantn(3, 'nvim_buf_lines_event', {b, tick, 0, 1, {'AAA'}, false})
    tick = tick + 1
    wantn(2, 'nvim_buf_changedtick_event', {b, tick})
    wantn(3, 'nvim_buf_changedtick_event', {b, tick})

    -- make sure there are no other pending nvim_buf_lines_event messages going to
    -- channel 1
    local channel1 = request(1, 'nvim_get_api_info')[1]
    eval('rpcnotify('..channel1..', "Hello")')
    wantn(1, 'Hello', {})

    -- close the buffer and channels 2 and 3 should get a nvim_buf_detach_event
    -- notification
    command('edit')
    wantn(2, 'nvim_buf_detach_event', {b})
    wantn(3, 'nvim_buf_detach_event', {b})

    -- make sure there are no other pending nvim_buf_lines_event messages going to
    -- channel 1
    channel1 = request(1, 'nvim_get_api_info')[1]
    eval('rpcnotify('..channel1..', "Hello Again")')
    wantn(1, 'Hello Again', {})
  end)

  it('works with :diffput and :diffget', function()
    if os.getenv("APPVEYOR") then
      pending("Fails on appveyor for some reason.", function() end)
    end

    local b1, tick1 = editoriginal(true, {"AAA", "BBB"})
    local channel = nvim('get_api_info')[1]
    command('diffthis')
    command('rightbelow vsplit')
    local b2, tick2 = open(true, {"BBB", "CCC"})
    command('diffthis')
    -- go back to first buffer, and push the 'AAA' line to the second buffer
    command('1wincmd w')
    command('normal! gg')
    command('diffput')
    tick2 = tick2 + 1
    expectn('nvim_buf_lines_event', {b2, tick2, 0, 0, {"AAA"}, false})

    -- use :diffget to grab the other change from buffer 2
    command('normal! G')
    command('diffget')
    tick1 = tick1 + 1
    expectn('nvim_buf_lines_event', {b1, tick1, 2, 2, {"CCC"}, false})

    eval('rpcnotify('..channel..', "Goodbye")')
    expectn('Goodbye', {})
  end)

  it('works with :sort', function()
    -- test for :sort
    local b, tick = editoriginal(true, {"B", "D", "C", "A", "E"})
    command('%sort')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 5, {"A", "B", "C", "D", "E"}, false})
  end)

  it('works with :left', function()
    local b, tick = editoriginal(true, {" A", "  B", "B", "\tB", "\t\tC"})
    command('2,4left')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 1, 4, {"B", "B", "B"}, false})
  end)

  it('works with :right', function()
    local b, tick = editoriginal(true, {" A",
                                        "\t  B",
                                        "\t  \tBB",
                                        " \tB",
                                        "\t\tC"})
    command('set ts=2 et')
    command('2,4retab')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 1, 4, {"    B", "      BB", "  B"}, false})
  end)

  it('works with :move', function()
    local b, tick = editoriginal(true, origlines)
    -- move text down towards the end of the file
    command('2,3move 4')
    tick = tick + 2
    expectn('nvim_buf_lines_event', {b, tick, 4, 4, {"original line 2",
                                           "original line 3"}, false})
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 1, 3, {}, false})

    -- move text up towards the start of the file
    tick = reopen(b, origlines)
    command('4,5move 2')
    tick = tick + 2
    expectn('nvim_buf_lines_event', {b, tick, 2, 2, {"original line 4",
                                           "original line 5"}, false})
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 5, 7, {}, false})
  end)

  it('when you manually add/remove folds', function()
    local b = editoriginal(true)
    local tick = reopenwithfolds(b)

    -- delete the inner fold
    command('normal! zR3Gzd')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 1, 4, {'original line 2',
                                           'original line 3',
                                           'original line 4'}, false})
    -- delete the outer fold
    command('normal! zd')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 6, origlines, false})

    -- discard changes and put the folds back
    tick = reopenwithfolds(b)

    -- remove both folds at once
    command('normal! ggzczD')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 6, origlines, false})

    -- discard changes and put the folds back
    tick = reopenwithfolds(b)

    -- now delete all folds at once
    command('normal! zE')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 6, origlines, false})

    -- create a fold from line 4 to the end of the file
    command('normal! 4GA/*{{{*/')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 3, 4, {'original line 4/*{{{*/'}, false})

    -- delete the fold which only has one marker
    command('normal! Gzd')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 3, 6, {'original line 4',
                                           'original line 5',
                                           'original line 6'}, false})
  end)

  it('detaches if the buffer is closed', function()
    local b, tick = editoriginal(true, {'AAA'})
    local channel = nvim('get_api_info')[1]

    -- Test that buffer events are working.
    command('normal! x')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 1, {'AA'}, false})
    command('undo')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 1, {'AAA'}, false})
    tick = tick + 1
    expectn('nvim_buf_changedtick_event', {b, tick})

    -- close our buffer by creating a new one
    command('enew')
    expectn('nvim_buf_detach_event', {b})

    -- Reopen the original buffer, make sure there are no buffer events sent.
    command('b1')
    command('normal! x')

    eval('rpcnotify('..channel..', "Hello There")')
    expectn('Hello There', {})
  end)

  it('stays attached if the buffer is hidden', function()
    local b, tick = editoriginal(true, {'AAA'})
    local channel = nvim('get_api_info')[1]

    -- Test that buffer events are working.
    command('normal! x')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 1, {'AA'}, false})
    command('undo')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 1, {'AAA'}, false})
    tick = tick + 1
    expectn('nvim_buf_changedtick_event', {b, tick})

    -- Close our buffer by creating a new one.
    command('set hidden')
    command('enew')

    -- Assert that no nvim_buf_detach_event is sent.
    eval('rpcnotify('..channel..', "Hello There")')
    expectn('Hello There', {})

    -- Reopen the original buffer, assert that buffer events are still active.
    command('b1')
    command('normal! x')
    tick = tick + 1
    expectn('nvim_buf_lines_event', {b, tick, 0, 1, {'AA'}, false})
  end)

  it('detaches if the buffer is unloaded/deleted/wiped',
     function()
    -- start with a blank nvim
    helpers.clear()
    -- need to make a new window with a buffer because :bunload doesn't let you
    -- unload the last buffer
    for _, cmd in ipairs({'bunload', 'bdelete', 'bwipeout'}) do
      command('new')
      -- open a brand spanking new file
      local b = open(true, {'AAA'})

      -- call :bunload or whatever the command is, and then check that we
      -- receive a nvim_buf_detach_event
      command(cmd)
      expectn('nvim_buf_detach_event', {b})
    end
  end)

  it('does not send the buffer content if not requested', function()
    helpers.clear()
    local b, tick = editoriginal(false)
    ok(buffer('attach', b, false, {}))
    expectn('nvim_buf_changedtick_event', {b, tick})
  end)

  it('returns a proper error on nonempty options dict', function()
    helpers.clear()
    local b = editoriginal(false)
    expect_err("dict isn't empty", buffer, 'attach', b, false, {builtin="asfd"})
  end)

end)

describe('API: buffer events:', function()
  before_each(function()
    helpers.clear()
  end)

  local function lines_subset(first, second)
    for i = 1,#first do
      if first[i] ~= second[i] then
        return false
      end
    end
    return true
  end

  local function lines_equal(f, s)
    return lines_subset(f, s) and lines_subset(s, f)
  end

  local function assert_match_somewhere(expected_lines, buffer_lines)
    local msg = next_msg()

    while(msg ~= nil) do
      local event = msg[2]
      if event == 'nvim_buf_lines_event' then
        local args = msg[3]
        local starts = args[3]
        local newlines = args[5]

        -- Size of the contained nvim instance is 23 lines, this might change
        -- with the test setup. Note updates are continguous.
        assert(#newlines <= 23)

        for i = 1,#newlines do
          buffer_lines[starts + i] = newlines[i]
        end
        -- we don't compare the msg area of the embedded nvim, it's too flakey
        buffer_lines[23] = nil

        if lines_equal(buffer_lines, expected_lines) then
          -- OK
          return
        end
      end
      msg = next_msg()
    end
    assert(false, 'did not match/receive expected nvim_buf_lines_event lines')
  end

  it('when :terminal lines change', function()
    local buffer_lines = {}
    local expected_lines = {}
    command('terminal "'..nvim_prog..'" -u NONE -i NONE -n -c "set shortmess+=A"')
    local b = nvim('get_current_buf')
    ok(buffer('attach', b, true, {}))

    for _ = 1,22 do
      table.insert(expected_lines,'~')
    end
    expected_lines[1] = ''
    expected_lines[22] = ('tmp_terminal_nvim'..(' '):rep(45)
                          ..'0,0-1          All')

    sendkeys('i:e tmp_terminal_nvim<Enter>')
    assert_match_somewhere(expected_lines, buffer_lines)

    expected_lines[1] = 'Blarg'
    expected_lines[22] = ('tmp_terminal_nvim [+]'..(' '):rep(41)
                          ..'1,6            All')

    sendkeys('iBlarg')
    assert_match_somewhere(expected_lines, buffer_lines)

    for i = 1,21 do
      expected_lines[i] = 'xyz'
    end
    expected_lines[22] = ('tmp_terminal_nvim [+]'..(' '):rep(41)
                          ..'31,4           Bot')

    local s = string.rep('\nxyz', 30)
    sendkeys(s)
    assert_match_somewhere(expected_lines, buffer_lines)
  end)

end)
