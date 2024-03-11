local health = vim.health

local M = {}

function M.check()
  health.start('Perl provider (optional)')

  if health.provider_disabled('perl') then
    return
  end

  local perl_exec, perl_warnings = vim.provider.perl.detect()

  if not perl_exec then
    health.warn(assert(perl_warnings), {
      'See :help provider-perl for more information.',
      'You may disable this provider (and warning) by adding `let g:loaded_perl_provider = 0` to your init.vim',
    })
    health.warn('No usable perl executable found')
    return
  end

  health.info('perl executable: ' .. perl_exec)

  -- we cannot use cpanm that is on the path, as it may not be for the perl
  -- set with g:perl_host_prog
  local ok = health.cmd_ok({ perl_exec, '-W', '-MApp::cpanminus', '-e', '' })
  if not ok then
    return { perl_exec, '"App::cpanminus" module is not installed' }
  end

  local latest_cpan_cmd = {
    perl_exec,
    '-MApp::cpanminus::fatscript',
    '-e',
    'my $app = App::cpanminus::script->new; $app->parse_options ("--info", "-q", "Neovim::Ext"); exit $app->doit',
  }
  local latest_cpan
  ok, latest_cpan = health.cmd_ok(latest_cpan_cmd)
  if not ok or latest_cpan:find('^%s*$') then
    health.error(
      'Failed to run: ' .. table.concat(latest_cpan_cmd, ' '),
      { "Make sure you're connected to the internet.", 'Are you behind a firewall or proxy?' }
    )
    return
  elseif latest_cpan[1] == '!' then
    local cpanm_errs = vim.split(latest_cpan, '!')
    if cpanm_errs[1]:find("Can't write to ") then
      local advice = {}
      for i = 2, #cpanm_errs do
        advice[#advice + 1] = cpanm_errs[i]
      end

      health.warn(cpanm_errs[1], advice)
      -- Last line is the package info
      latest_cpan = cpanm_errs[#cpanm_errs]
    else
      health.error('Unknown warning from command: ' .. latest_cpan_cmd, cpanm_errs)
      return
    end
  end
  latest_cpan = vim.fn.matchstr(latest_cpan, [[\(\.\?\d\)\+]])
  if latest_cpan:find('^%s*$') then
    health.error('Cannot parse version number from cpanm output: ' .. latest_cpan)
    return
  end

  local current_cpan_cmd = { perl_exec, '-W', '-MNeovim::Ext', '-e', 'print $Neovim::Ext::VERSION' }
  local current_cpan
  ok, current_cpan = health.cmd_ok(current_cpan_cmd)
  if not ok then
    health.error(
      'Failed to run: ' .. table.concat(current_cpan_cmd, ' '),
      { 'Report this issue with the output of: ', table.concat(current_cpan_cmd, ' ') }
    )
    return
  end

  if vim.version.lt(current_cpan, latest_cpan) then
    local message = 'Module "Neovim::Ext" is out-of-date. Installed: '
      .. current_cpan
      .. ', latest: '
      .. latest_cpan
    health.warn(message, 'Run in shell: cpanm -n Neovim::Ext')
  else
    health.ok('Latest "Neovim::Ext" cpan module is installed: ' .. current_cpan)
  end
end

return M
