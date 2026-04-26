local M = {}
local health = vim.health

local function system(cmd)
  local result = vim.system(cmd, { text = true }):wait()
  if not result then -- Workaround https://github.com/neovim/neovim/issues/37922
    return false, 'command failed'
  end
  return result.code == 0, vim.trim(('%s\n%s'):format(result.stdout, result.stderr))
end

local function get_tmux_option(option)
  local cmd = { 'tmux', 'show-option', '-qvg', option } -- try global scope
  local ok, out = system(cmd)
  local val = vim.fn.substitute(out, [[\v(\s|\r|\n)]], '', 'g')
  if not ok then
    health.error(('command failed: %s\n%s'):format(vim.inspect(cmd), out))
    return 'error'
  elseif val == '' then
    cmd = { 'tmux', 'show-option', '-qvgs', option } -- try session scope
    ok, out = system(cmd)
    val = vim.fn.substitute(out, [[\v(\s|\r|\n)]], '', 'g')
    if not ok then
      health.error(('command failed: %s\n%s'):format(vim.inspect(cmd), out))
      return 'error'
    end
  end
  return val
end

function M.check()
  health.start('vim.ui.img')

  if not vim.env.TMUX or vim.fn.executable('tmux') == 0 then
    health.ok('no terminal multiplexer detected')
    return
  end

  local passthrough = get_tmux_option('allow-passthrough')
  if passthrough ~= 'error' then
    if passthrough == 'on' or passthrough == 'all' then
      health.ok('allow-passthrough: ' .. passthrough)
    else
      health.error(
        '`allow-passthrough` is not enabled. Images will not be displayed.',
        { 'Add to ~/.tmux.conf:\nset-option -g allow-passthrough on' }
      )
    end
  end
end

return M
