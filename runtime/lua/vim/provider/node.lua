local M = {}
local s_err ---@type string?
local s_host ---@type string?

--- @param version string?
--- @param min_version string
--- @return boolean
function M.is_minimum_version(version, min_version)
  local nodejs_version ---@type string?
  if version ~= nil and version ~= '' then
    local nodejs_version_system = vim.system({ 'node', '-v' }):wait()
    nodejs_version = nodejs_version_system.stdout or ''
    if nodejs_version_system.code ~= 0 or not vim.startswith(nodejs_version, 'v') then
      return false
    end
  else
    nodejs_version = version
  end
  -- Remove surrounding junk.  Example: 'v4.12.0' => '4.12.0'
  nodejs_version = vim.fn.matchstr(nodejs_version, [[\(\d\.\?\)\+]])
  return vim.version.ge(nodejs_version, min_version)
end

--- Support for --inspect-brk requires node 6.12+ or 7.6+ or 8+
--- @return boolean true if it's supported
function M.can_inspect()
  if vim.fn.executable('node') ~= 1 then
    return false
  end
  local ver_system = vim.system({ 'node', '-v' }):wait() or ''
  local ver = ver_system.stdout or ''
  if ver_system.code ~= 0 or not vim.startswith(ver, 'v') then
    return false
  end
  return (vim.startswith(ver, '6') and M.is_minimum_version(ver, '6.12.0'))
    or M.is_minimum_version(ver, '7.6.0')
end

function M.detect()
  return { '', 'failed to detect node' }
end

function M.require(host)
  local args = { 'node' }

  if vim.env.NVIM_NODE_HOST_DEBUG and M.can_inspect() then
    table.insert(args, '--inspect-brk')
  end

  local prog = vim.fn['provider#node#Detect']()[1] ---@type any
  table.insert(args, prog)

  return vim.fn['provider#Poll'](args, host.orig_name, '$NVIM_NODE_LOG_FILE')
end

function M.call(method, args)
  if s_err then
    return
  end

  if not s_host then
    local ok, result = pcall(vim.fn['remote#host#Require'], 'node') ---@type any, any
    if not ok then
      s_err = result
      vim.api.nvim_echo({ { result, 'WarningMsg' } }, true, {})
      return
    end
    s_host = result
  end

  return vim.fn.rpcrequest(s_host, 'node_' .. method, unpack(args))
end

function M.start()
  vim.fn['remote#host#RegisterPlugin']('node-provider', 'node', {})
end

return M
