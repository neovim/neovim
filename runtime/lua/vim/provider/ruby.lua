local M = {}
local s_err ---@type string?
local s_host ---@type string?

function M.require(host)
  local prog = M.detect()
  local args = { prog }
  local ruby_plugins = vim.fn['remote#host#PluginsForHost'](host.name) ---@type any

  ---@param plugin any
  for _, plugin in ipairs(ruby_plugins) do
    table.insert(args, plugin.path)
  end

  return vim.fn['provider#Poll'](args, host.orig_name, '$NVIM_RUBY_LOG_FILE')
end

function M.call(method, args)
  if s_err then
    return
  end

  if not s_host then
    local ok, result = pcall(vim.fn['remote#host#Require'], 'legacy-ruby-provider') ---@type any, any
    if not ok then
      s_err = result
      vim.api.nvim_echo({ { result, 'WarningMsg' } }, true, {})
      return
    end
    s_host = result
  end

  return vim.fn.rpcrequest(s_host, 'ruby_' .. method, unpack(args))
end

function M.detect()
  local prog ---@type string
  if vim.g.ruby_host_prog then
    prog = vim.fn.expand(vim.g.ruby_host_prog, true)
  elseif vim.fn.has('win32') == 1 then
    prog = vim.fn.exepath('neovim-ruby-host.bat')
  else
    local p = vim.fn.exepath('neovim-ruby-host')
    if p == '' then
      prog = ''
    else
      -- neovim-ruby-host could be an rbenv shim for another Ruby version.
      local result = vim.system({ p }):wait()
      prog = result.code ~= 0 and '' or p
    end
  end
  local err = prog == '' and 'missing ruby or ruby-host' or ''
  return prog, err
end

function M.start(plugin_path)
  vim.fn['remote#host#RegisterClone']('legacy-ruby-provider', 'ruby')
  vim.fn['remote#host#RegisterPlugin']('legacy-ruby-provider', plugin_path, {})
end

return M
