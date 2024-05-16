local M = {}
local health = vim.health

local deprecated = {}

function M.check()
  if next(deprecated) == nil then
    health.ok('No deprecated functions detected')
    return
  end

  for name, v in vim.spairs(deprecated) do
    health.start('')

    local version, backtraces, alternative = v[1], v[2], v[3]
    local major, minor = version:match('(%d+)%.(%d+)')
    major, minor = tonumber(major), tonumber(minor)
    local removal_version = string.format('nvim-%d.%d', major, minor)
    local will_be_removed = vim.fn.has(removal_version) == 1 and 'was removed' or 'will be removed'

    local msg = ('%s is deprecated. Feature %s in Nvim %s'):format(name, will_be_removed, version)
    local msg_alternative = alternative and ('use %s instead.'):format(alternative)
    local advice = { msg_alternative }
    table.insert(advice, backtraces)
    advice = vim.iter(advice):flatten():totable()
    health.warn(msg, advice)
  end
end

function M.add(name, version, backtrace, alternative)
  if deprecated[name] == nil then
    deprecated[name] = { version, { backtrace }, alternative }
    return
  end

  local it = vim.iter(deprecated[name][2])
  if it:find(backtrace) == nil then
    table.insert(deprecated[name][2], backtrace)
  end
end

return M
