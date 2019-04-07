local deps_prefix = (os.getenv('DEPS_PREFIX') and os.getenv('DEPS_PREFIX')
                     or './.deps/usr')

package.path = deps_prefix .. '/share/lua/5.1/?.lua;' ..
               deps_prefix .. '/share/lua/5.1/?/init.lua;' ..
               package.path

package.cpath = deps_prefix .. '/lib/lua/5.1/?.so;' ..
                package.cpath

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
