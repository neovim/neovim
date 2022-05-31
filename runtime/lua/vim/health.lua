local M = {}

function M.report_start(msg)
  vim.fn['health#report_start'](msg)
end

function M.report_info(msg)
  vim.fn['health#report_info'](msg)
end

function M.report_ok(msg)
  vim.fn['health#report_ok'](msg)
end

function M.report_warn(msg, ...)
  vim.fn['health#report_warn'](msg, ...)
end

function M.report_error(msg, ...)
  vim.fn['health#report_error'](msg, ...)
end

local path2name = function(path)
  if path:match('%.lua$') then
    -- Lua: transform "../lua/vim/lsp/health.lua" into "vim.lsp"
    return path:gsub('.-lua[%\\%/]', '', 1):gsub('[%\\%/]', '.'):gsub('%.health.-$', '')
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
