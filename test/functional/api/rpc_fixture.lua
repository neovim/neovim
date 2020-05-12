--- RPC server fixture.
--
-- Lua's paths are passed as arguments to reflect the path in the test itself.
package.path = arg[1]
package.cpath = arg[2]

local mpack = require('mpack')
local StdioStream = require('nvim.stdio_stream')
local Session = require('nvim.session')

local stdio_stream = StdioStream.open()
local session = Session.new(stdio_stream)

local function on_request(method, args)
  if method == 'poll' then
    return 'ok'
  elseif method == 'write_stderr' then
    io.stderr:write(args[1])
    return "done!"
  elseif method == "exit" then
    session:stop()
    return mpack.NIL
  end
end

local function on_notification(event, args)
  if event == 'ping' and #args == 0 then
    session:notify("nvim_eval", "rpcnotify(g:channel, 'pong')")
  end
end

session:run(on_request, on_notification)
