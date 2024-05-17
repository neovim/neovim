local health = vim.health
local iswin = vim.loop.os_uname().sysname == 'Windows_NT'

local M = {}

function M.check()
  health.start('Ruby provider (optional)')

  if health.provider_disabled('ruby') then
    return
  end

  if vim.fn.executable('ruby') == 0 or vim.fn.executable('gem') == 0 then
    health.warn(
      '`ruby` and `gem` must be in $PATH.',
      'Install Ruby and verify that `ruby` and `gem` commands work.'
    )
    return
  end
  health.info('Ruby: ' .. health.system({ 'ruby', '-v' }))

  local host, _ = vim.provider.ruby.detect()
  if (not host) or host:find('^%s*$') then
    health.warn('`neovim-ruby-host` not found.', {
      'Run `gem install neovim` to ensure the neovim RubyGem is installed.',
      'Run `gem environment` to ensure the gem bin directory is in $PATH.',
      'If you are using rvm/rbenv/chruby, try "rehashing".',
      'See :help g:ruby_host_prog for non-standard gem installations.',
      'You may disable this provider (and warning) by adding `let g:loaded_ruby_provider = 0` to your init.vim',
    })
    return
  end
  health.info('Host: ' .. host)

  local latest_gem_cmd = (iswin and 'cmd /c gem list -ra "^^neovim$"' or 'gem list -ra ^neovim$')
  local ok, latest_gem = health.cmd_ok(vim.split(latest_gem_cmd, ' '))
  if not ok or latest_gem:find('^%s*$') then
    health.error(
      'Failed to run: ' .. latest_gem_cmd,
      { "Make sure you're connected to the internet.", 'Are you behind a firewall or proxy?' }
    )
    return
  end
  local gem_split = vim.split(latest_gem, [[neovim (\|, \|)$]])
  latest_gem = gem_split[1] or 'not found'

  local current_gem_cmd = { host, '--version' }
  local current_gem
  ok, current_gem = health.cmd_ok(current_gem_cmd)
  if not ok then
    health.error(
      'Failed to run: ' .. table.concat(current_gem_cmd, ' '),
      { 'Report this issue with the output of: ', table.concat(current_gem_cmd, ' ') }
    )
    return
  end

  if vim.version.lt(current_gem, latest_gem) then
    local message = 'Gem "neovim" is out-of-date. Installed: '
      .. current_gem
      .. ', latest: '
      .. latest_gem
    health.warn(message, 'Run in shell: gem update neovim')
  else
    health.ok('Latest "neovim" gem is installed: ' .. current_gem)
  end
end

return M
