local helpers = require('test.functional.helpers')
local call = helpers.call
local clear = helpers.clear
local eq = helpers.eq
local matches = helpers.matches

local function spawn_flaky_host()
  -- create a fake remote plugin host that dies immediately on startup
  local flaky_code = "echo 'FLAKY HOST STARTUP ERROR' >&2;exit 7"
  local argv = {'sh', '-c', flaky_code}
  local long_name = 'flaky rplugin host'

  -- calling provider#Poll() should fail with an error message
  local status, errmsg = pcall(call, 'provider#Poll', argv, long_name, '$NVIM_FLAKY_LOG_FILE')
  -- the call to provider#Poll() should fail, and the error message should
  -- mention the log file
  eq(false, status)
  return errmsg
end

describe('remote host provider', function()
  before_each(clear)

  it('tells you when startup has failed', function()
    errmsg = spawn_flaky_host()
    matches('Failed to load flaky rplugin host', errmsg)
    matches('recorded in $NVIM_LOG_FILE', errmsg)
    matches('possibly $NVIM_FLAKY_LOG_FILE', errmsg)
  end)

  it('writes stderr to $NVIM_LOG_FILE', function()
    local nvim_log = 'Xnvim_log'
    os.remove(nvim_log)

    -- restart nvim with the correct $NVIM_LOG_FILE
    clear({env={NVIM_LOG_FILE=nvim_log}})

    spawn_flaky_host()

    -- STDERR must have been written to the log file
    local found_stderr_in_logs = false
    for line in io.lines(nvim_log) do
      local pos = string.match(line, 'FLAKY HOST STARTUP ERROR')
      if pos then
        found_stderr_in_logs = true
        break
      end
    end

    -- NOTE: we need to kill the old nvim before we'll be able to remove the logfile
    clear()
    os.remove(nvim_log)

    if not found_stderr_in_logs then
      error("Did not find host's stderr in $NVIM_LOG_FILE")
    end
  end)
end)
