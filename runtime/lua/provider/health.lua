local M = {}

-- Returns true if `cmd` exits with success, else false.
local function cmd_ok(cmd)
  vim.fn.system(cmd)
  return vim.v.shell_error == 0
end

local function executable(exe)
  return vim.fn.executable(exe) == 1
end

local function is_blank(s)
  return s:find('^%s*$') ~= nil
end

local function clipboard()
  vim.health.report_start('Clipboard (optional)')

  if
    os.getenv('TMUX')
    and executable('tmux')
    and executable('pbpaste')
    and not cmd_ok('pbpaste')
  then
    local tmux_version = string.match(vim.fn.system('tmux -V'), '%d+%.%d+')
    local advice = {
      'Install tmux 2.6+.  https://superuser.com/q/231130',
      'or use tmux with reattach-to-user-namespace.  https://superuser.com/a/413233',
    }
    vim.health.report_error('pbcopy does not work with tmux version: ' .. tmux_version, advice)
  end

  local clipboard_tool = vim.fn['provider#clipboard#Executable']()
  if vim.g.clipboard and is_blank(clipboard_tool) then
    local error_message = vim.fn['provider#clipboard#Error']()
    vim.health.report_error(
      error_message,
      "Use the example in :help g:clipboard as a template, or don't set g:clipboard at all."
    )
  elseif is_blank(clipboard_tool) then
    vim.health.report_warn(
      'No clipboard tool found. Clipboard registers (`"+` and `"*`) will not work.',
      ':help clipboard'
    )
  else
    vim.health.report_ok('Clipboard tool found: ' .. clipboard_tool)
  end
end

function M.check()
  clipboard()
end

return M
