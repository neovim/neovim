local M = {}
local s_err ---@type string?
local s_host ---@type string?

function M.require(host, prog)
  local args = { prog, '-e', 'use Neovim::Ext; start_host();' }

  -- Collect registered perl plugins into args
  local perl_plugins = vim.fn['remote#host#PluginsForHost'](host.name) ---@type any
  ---@param plugin any
  for _, plugin in ipairs(perl_plugins) do
    table.insert(args, plugin.path)
  end

  return vim.fn['provider#Poll'](args, host.orig_name, '$NVIM_PERL_LOG_FILE')
end

--- @return string? path to detected perl, if any; nil if not found
--- @return string? error message if perl can't be detected; nil if success
function M.detect()
  -- use g:perl_host_prog if set or check if perl is on the path
  local prog = vim.fn.exepath(vim.g.perl_host_prog or 'perl')
  if prog == '' then
    return nil, 'No perl executable found'
  end

  -- if perl is available, make sure we have 5.22+
  if vim.system({ prog, '-e', 'use v5.22' }):wait().code ~= 0 then
    return nil, 'Perl version is too old, 5.22+ required'
  end

  -- if perl is available, make sure the required module is available
  if vim.system({ prog, '-W', '-MNeovim::Ext', '-e', '' }):wait().code ~= 0 then
    return nil, '"Neovim::Ext" cpan module is not installed'
  end
  return prog, nil
end

function M.call(method, args)
  if s_err then
    return
  end

  if not s_host then
    -- Ensure that we can load the Perl host before bootstrapping
    local ok, result = pcall(vim.fn['remote#host#Require'], 'legacy-perl-provider') ---@type any, any
    if not ok then
      s_err = result
      vim.api.nvim_echo({ { result, 'WarningMsg' } }, true, {})
      return
    end
    s_host = result
  end

  return vim.fn.rpcrequest(s_host, 'perl_' .. method, unpack(args))
end

function M.start()
  -- The perl provider plugin will run in a separate instance of the perl host.
  vim.fn['remote#host#RegisterClone']('legacy-perl-provider', 'perl')
  vim.fn['remote#host#RegisterPlugin']('legacy-perl-provider', 'ScriptHost.pm', {})
end

return M
