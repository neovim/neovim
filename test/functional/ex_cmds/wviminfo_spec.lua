local helpers, lfs = require('test.functional.helpers'), require('lfs')
local clear, execute, eq, neq, spawn, nvim_prog, set_session, wait =
  helpers.clear, helpers.execute, helpers.eq, helpers.neq, helpers.spawn,
  helpers.nvim_prog, helpers.set_session, helpers.wait

-- Lua does not have a sleep function so we use the system command.  If the
-- command does not support sub second precision we use math.floor() to get
-- full seconds.
local sleep = function(millisec)
  local sec = millisec / 1000
  local round = math.floor(sec)
  if round == 0 then round = 1 end
  os.execute('sleep '..sec..' || sleep '..round)
end

describe(':wviminfo', function()
  local file = 'foo'
  before_each(function()
    clear()
    os.remove(file)
  end)

  it('creates a file', function()
    -- TODO
    -- Set up the nvim session to be able to write viminfo files.  Is it
    -- possible to do this outside of the it() call?
    local nvim2 = spawn({nvim_prog, '-u', 'NONE', '--embed'})
    --local nvim2 = spawn({nvim_prog, '-u', 'NONE', '--embed', '--cmd', 'let hans=42' })
    set_session(nvim2)
    --eq(43, eval('hans'))

    -- Assert that the file does not exist.
    eq(nil, lfs.attributes(file))
    execute('wv! '..file)
    wait()
    -- Assert that the file does exist.
    neq(nil, lfs.attributes(file))
  end)

  it('overwrites existing files', function()
    -- TODO see above
    local nvim2 = spawn({nvim_prog, '-u', 'NONE', '--embed'})
    set_session(nvim2)

    local text = 'foo test'

    local fp = io.open(file, 'w')
    fp:write(text)
    fp:flush()
    fp:close()
    -- Assert that the file already exists.
    neq(nil, lfs.attributes(file))
    execute('wv! '..file)
    wait()
    -- Assert that the contents of the file changed.
    neq(text, io.open(file):read())
  end)

  teardown(function()
    os.remove(file)
  end)
end)
