local health = vim.health

local M = {}

function M.check()
  health.start('Clipboard (optional)')

  if
    os.getenv('TMUX')
    and vim.fn.executable('tmux') == 1
    and vim.fn.executable('pbpaste') == 1
    and not health.cmd_ok('pbpaste')
  then
    local tmux_version = string.match(vim.fn.system('tmux -V'), '%d+%.%d+')
    local advice = {
      'Install tmux 2.6+.  https://superuser.com/q/231130',
      'or use tmux with reattach-to-user-namespace.  https://superuser.com/a/413233',
    }
    health.error('pbcopy does not work with tmux version: ' .. tmux_version, advice)
  end

  local clipboard_tool = vim.fn['provider#clipboard#Executable']()
  if vim.g.clipboard ~= nil and clipboard_tool == '' then
    local error_message = vim.fn['provider#clipboard#Error']()
    health.error(
      error_message,
      "Use the example in :help g:clipboard as a template, or don't set g:clipboard at all."
    )
  elseif clipboard_tool:find('^%s*$') then
    health.warn(
      'No clipboard tool found. Clipboard registers (`"+` and `"*`) will not work.',
      ':help clipboard'
    )
  else
    health.ok('Clipboard tool found: ' .. clipboard_tool)
  end
end

return M
