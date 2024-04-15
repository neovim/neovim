local health = vim.health
local iswin = vim.loop.os_uname().sysname == 'Windows_NT'

local M = {}

function M.check()
  health.start('Node.js provider (optional)')

  if health.provider_disabled('node') then
    return
  end

  if
    vim.fn.executable('node') == 0
    or (
      vim.fn.executable('npm') == 0
      and vim.fn.executable('yarn') == 0
      and vim.fn.executable('pnpm') == 0
    )
  then
    health.warn(
      '`node` and `npm` (or `yarn`, `pnpm`) must be in $PATH.',
      'Install Node.js and verify that `node` and `npm` (or `yarn`, `pnpm`) commands work.'
    )
    return
  end

  -- local node_v = vim.fn.split(system({'node', '-v'}), "\n")[1] or ''
  local ok, node_v = health.cmd_ok({ 'node', '-v' })
  health.info('Node.js: ' .. node_v)
  if not ok or vim.version.lt(node_v, '6.0.0') then
    health.warn('Nvim node.js host does not support Node ' .. node_v)
    -- Skip further checks, they are nonsense if nodejs is too old.
    return
  end
  if vim.fn['provider#node#can_inspect']() == 0 then
    health.warn(
      'node.js on this system does not support --inspect-brk so $NVIM_NODE_HOST_DEBUG is ignored.'
    )
  end

  local node_detect_table = vim.fn['provider#node#Detect']()
  local host = node_detect_table[1]
  if host:find('^%s*$') then
    health.warn('Missing "neovim" npm (or yarn, pnpm) package.', {
      'Run in shell: npm install -g neovim',
      'Run in shell (if you use yarn): yarn global add neovim',
      'Run in shell (if you use pnpm): pnpm install -g neovim',
      'You may disable this provider (and warning) by adding `let g:loaded_node_provider = 0` to your init.vim',
    })
    return
  end
  health.info('Nvim node.js host: ' .. host)

  local manager = 'npm'
  if vim.fn.executable('yarn') == 1 then
    manager = 'yarn'
  elseif vim.fn.executable('pnpm') == 1 then
    manager = 'pnpm'
  end

  local latest_npm_cmd = (
    iswin and 'cmd /c ' .. manager .. ' info neovim --json' or manager .. ' info neovim --json'
  )
  local latest_npm
  ok, latest_npm = health.cmd_ok(vim.split(latest_npm_cmd, ' '))
  if not ok or latest_npm:find('^%s$') then
    health.error(
      'Failed to run: ' .. latest_npm_cmd,
      { "Make sure you're connected to the internet.", 'Are you behind a firewall or proxy?' }
    )
    return
  end

  local pcall_ok, pkg_data = pcall(vim.json.decode, latest_npm)
  if not pcall_ok then
    return 'error: ' .. latest_npm
  end
  local latest_npm_subtable = pkg_data['dist-tags'] or {}
  latest_npm = latest_npm_subtable['latest'] or 'unable to parse'

  local current_npm_cmd = { 'node', host, '--version' }
  local current_npm
  ok, current_npm = health.cmd_ok(current_npm_cmd)
  if not ok then
    health.error(
      'Failed to run: ' .. table.concat(current_npm_cmd, ' '),
      { 'Report this issue with the output of: ', table.concat(current_npm_cmd, ' ') }
    )
    return
  end

  if latest_npm ~= 'unable to parse' and vim.version.lt(current_npm, latest_npm) then
    local message = 'Package "neovim" is out-of-date. Installed: '
      .. current_npm:gsub('%\n$', '')
      .. ', latest: '
      .. latest_npm:gsub('%\n$', '')

    health.warn(message, {
      'Run in shell: npm install -g neovim',
      'Run in shell (if you use yarn): yarn global add neovim',
      'Run in shell (if you use pnpm): pnpm install -g neovim',
    })
  else
    health.ok('Latest "neovim" npm/yarn/pnpm package is installed: ' .. current_npm)
  end
end

return M
