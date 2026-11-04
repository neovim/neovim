-- Fake `ssh` for remote-ssh tests: `nvim -l fake-ssh.lua {config} {ssh-args}`. Behaves as {config}
-- (JSON, see `setup_fake_ssh()` in ssh_spec.lua) says, and writes to its `dir`:
--   tunnel.args         Args of the tunnel (`-L`) command, and the script it got on stdin.
--   tunnel.pid          PID of the tunnel.
--   forward.cancelled   Created by `-O cancel -L`.

io.stdout:setvbuf('no')
local config = vim.json.decode(table.remove(_G.arg, 1))
local dir = config.dir
local args = table.concat(_G.arg, ' ')

local function fail(msg)
  io.stderr:write(msg, '\n')
  os.exit(1)
end

local function write(name, data)
  local f = assert(io.open(vim.fs.joinpath(dir, name), 'wb'))
  f:write(data)
  f:close()
end

if args:find('^%-G ') then
  io.stdout:write(config.ssh_config)
  os.exit(0)
elseif args:find('uname -s && uname -m', 1, true) then
  io.stdout:write(config.uname)
  os.exit(0)
elseif args:find('-O cancel -L', 1, true) then
  write('forward.cancelled', '')
  os.exit(0)
elseif not args:find(' -L ', 1, true) then
  fail(('Unexpected SSH command: %s'):format(args))
end

-- The script on stdin, which stays open (see `run_script()`).
local script = {} --- @type string[]
for line in io.stdin:lines() do
  script[#script + 1] = line
  if line == 'main "$@"' then
    break
  end
end
args = ('%s %s'):format(args, table.concat(script, '\n'))
if not args:find('ControlMaster', 1, true) then
  fail('FAIL: Multiplexing flags missing!')
elseif not args:find(' sh %-s .*main "%$@"') then
  fail('FAIL: tunnel script not fed to sh -s')
end
write('tunnel.args', args)
write('tunnel.pid', tostring(vim.uv.os_getpid()))

local tunnel = config.tunnel
local server --- @type vim.SystemObj?
if tunnel.serve then
  -- Serves a headless Nvim at the `-L` socket, as the remote does. Its stdin (`--embed`) ends with
  -- this process, and so does the server.
  local sock = assert(args:match('%-L ([^:]+)'))
  local cmd = { config.nvim_prog, '--embed', '--headless', '--clean', '-i', 'NONE' }
  server = vim.system(vim.list_extend(cmd, { '--listen', sock }), { stdin = true })
  vim.wait(10000, function()
    return vim.uv.fs_stat(sock) ~= nil
  end)
  io.stdout:write('NVIM_READY\n')
end
io.stdout:write(tunnel.stdout or '')
io.stderr:write(tunnel.stderr or '')
if tunnel.exit then
  os.exit(tunnel.exit)
elseif server then
  -- As the remote script: ends when its server exits.
  server:wait()
  os.exit(0)
end
-- Until killed.
vim.wait(60000)
