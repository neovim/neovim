local M = {}

---@deprecated
function M.report_start(msg)
  vim.deprecate('vim.health.report_start()', 'vim.health.start()', '0.11')
  M.start(msg)
end
function M.start(msg)
  vim.fn['health#report_start'](msg)
end

---@deprecated
function M.report_info(msg)
  vim.deprecate('vim.health.report_info()', 'vim.health.info()', '0.11')
  M.info(msg)
end
function M.info(msg)
  vim.fn['health#report_info'](msg)
end

---@deprecated
function M.report_ok(msg)
  vim.deprecate('vim.health.report_ok()', 'vim.health.ok()', '0.11')
  M.ok(msg)
end
function M.ok(msg)
  vim.fn['health#report_ok'](msg)
end

---@deprecated
function M.report_warn(msg, ...)
  vim.deprecate('vim.health.report_warn()', 'vim.health.warn()', '0.11')
  M.warn(msg, ...)
end
function M.warn(msg, ...)
  vim.fn['health#report_warn'](msg, ...)
end

---@deprecated
function M.report_error(msg, ...)
  vim.deprecate('vim.health.report_error()', 'vim.health.error()', '0.11')
  M.error(msg, ...)
end
function M.error(msg, ...)
  vim.fn['health#report_error'](msg, ...)
end

local path2name = function(path)
  if path:match('%.lua$') then
    -- Lua: transform "../lua/vim/lsp/health.lua" into "vim.lsp"

    -- Get full path, make sure all slashes are '/'
    path = vim.fs.normalize(path)

    -- Remove everything up to the last /lua/ folder
    path = path:gsub('^.*/lua/', '')

    -- Remove the filename (health.lua)
    path = vim.fn.fnamemodify(path, ':h')

    -- Change slashes to dots
    path = path:gsub('/', '.')

    return path
  else
    -- Vim: transform "../autoload/health/provider.vim" into "provider"
    return vim.fn.fnamemodify(path, ':t:r')
  end
end

local PATTERNS = { '/autoload/health/*.vim', '/lua/**/**/health.lua', '/lua/**/**/health/init.lua' }
-- :checkhealth completion function used by ex_getln.c get_healthcheck_names()
M._complete = function()
  local names = vim.tbl_flatten(vim.tbl_map(function(pattern)
    return vim.tbl_map(path2name, vim.api.nvim_get_runtime_file(pattern, true))
  end, PATTERNS))
  -- Remove duplicates
  local unique = {}
  vim.tbl_map(function(f)
    unique[f] = true
  end, names)
  -- vim.health is this file, which is not a healthcheck
  unique['vim'] = nil
  return vim.tbl_keys(unique)
end

return M
