-- Fake `ssh` for remote-ssh tests:
--    nvim -l fake-ssh.lua {config} {ssh-args}
--
-- Behaves as {config} (JSON, see `setup_fake_ssh()` in ssh_spec.lua) says, and writes to its `dir`:
--   tunnel.args         Args of the tunnel (`-L`) command, and the script it got on stdin.
--   tunnel.pid          PID of the tunnel.
--   forward.cancelled   Created by `-O cancel -L`.
--   home/               Remote $HOME of remote commands.

io.stdout:setvbuf('no')
--- @type { dir: string, nvim_prog: string, ssh_config: string, uname: string, tunnel: table }
local config = vim.json.decode(table.remove(_G.arg, 1))

local function write(name, data)
  local f = assert(io.open(vim.fs.joinpath(config.dir, name), 'wb'))
  f:write(data)
  f:close()
end

--- Parses `ssh {options} -- {destination} [{command}…]`, as ssh does. Fails on an option that
--- `get_ssh_cmd()` does not use, or a missing `--`.
---
--- @param argv string[]
--- @return table<string, string|true> opts Value (or true) of each option, and `-o` options by key.
---   Example: `{ T = true, L = 'a.sock:b.sock', ControlMaster = 'auto' }`
--- @return string? cmd Remote command: its words joined by spaces, as ssh does.
local function parse_args(argv)
  local takes_value = { G = false, T = false, L = true, O = true, o = true, p = true }
  local opts = {} --- @type table<string, string|true>
  local i = 1
  while argv[i] ~= '--' do
    local flag = (argv[i] or ''):match('^%-(%a)$')
    if takes_value[flag] == nil then
      error(('Unexpected SSH arg: %s'):format(argv[i] or '(missing `--`)'), 0)
    elseif flag == 'o' then
      local key, value = assert(argv[i + 1]):match('^(%a+)=(.*)$')
      opts[key] = value
    else
      opts[flag] = takes_value[flag] and assert(argv[i + 1]) or true
    end
    i = i + (takes_value[flag] and 2 or 1)
  end
  local cmd = argv[i + 2] and table.concat(argv, ' ', i + 2) or nil
  return opts, cmd
end

--- Runs remote command `cmd` as sshd does: in the login shell (here `sh`).
--- @return integer exit_code
local function run_remote(cmd)
  local env = { HOME = vim.fs.joinpath(config.dir, 'home'), PATH = os.getenv('PATH') }
  local stdin = io.stdin:read('*a')
  local res = vim.system({ 'sh', '-c', cmd }, { stdin = stdin, clear_env = true, env = env }):wait()
  io.stdout:write(res.stdout)
  io.stderr:write(res.stderr)
  return res.code
end

--- Fakes the tunnel: `-L {local}:{remote} … sh -s -- {args}`, with remote_ssh.sh on stdin (see
--- `run_script()`). Behaves as `config.tunnel` says.
--- @return integer exit_code
local function tunnel(opts, cmd)
  -- Stdin stays open, so reads only up to the script's last line.
  local script = {} --- @type string[]
  for line in io.stdin:lines() do
    script[#script + 1] = line
    if line == 'main "$@"' then
      break
    end
  end
  if not (cmd or ''):find('^sh %-s %-%- ') or script[#script] ~= 'main "$@"' then
    error('tunnel script not fed to sh -s', 0)
  end
  write('tunnel.args', ('%s %s'):format(table.concat(_G.arg, ' '), table.concat(script, '\n')))
  write('tunnel.pid', tostring(vim.uv.os_getpid()))

  local server --- @type vim.SystemObj?
  if config.tunnel.serve then
    -- Serves a headless Nvim at the local socket, as the remote does at the remote one. Its stdin
    -- (`--embed`) ends with this process, and so does the server.
    local sock = assert(opts.L:match('^[^:]+'))
    local nvim = { config.nvim_prog, '--embed', '--headless', '--clean', '-i', 'NONE' }
    server = vim.system(vim.list_extend(nvim, { '--listen', sock }), { stdin = true })
    vim.wait(10000, function()
      return vim.uv.fs_stat(sock) ~= nil
    end)
    io.stdout:write('NVIM_READY\n')
  end
  io.stdout:write(config.tunnel.stdout or '')
  io.stderr:write(config.tunnel.stderr or '')
  if config.tunnel.exit then
    return config.tunnel.exit
  elseif server then
    -- As the remote script: ends when its server exits.
    server:wait()
    return 0
  end
  vim.wait(60000) -- Until killed.
  return 0
end

--- @return integer exit_code
local function main()
  local opts, cmd = parse_args(_G.arg)
  if opts.G then -- Prints the effective ssh_config.
    io.stdout:write(config.ssh_config)
    return 0
  elseif opts.ControlMaster ~= 'auto' then
    error('multiplexing flags missing', 0)
  elseif opts.O == 'cancel' then -- Cancels a forward of the ssh master.
    write('forward.cancelled', '')
    return 0
  elseif opts.L then
    return tunnel(opts, cmd)
  elseif cmd == 'uname -s && uname -m' then -- Fake remote system.
    io.stdout:write(config.uname)
    return 0
  elseif cmd then
    return run_remote(cmd)
  end
  error(('Unexpected SSH command: %s'):format(table.concat(_G.arg, ' ')), 0)
end

os.exit(main())
