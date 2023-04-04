local M = {}

function M.foldtext()
  local foldtext = vim.fn.foldtext()

  if vim.api.nvim_buf_get_name(0) ~= 'health://' then
    return foldtext
  end

  if vim.b.failedchecks == nil then
    vim.b.failedchecks = vim.empty_dict()
  end

  if vim.b.failedchecks[foldtext] == nil then
    local warning = '- WARNING '
    local warninglen = string.len(warning)
    local error = '- ERROR '
    local errorlen = string.len(error)
    local failedchecks = vim.b.failedchecks
    failedchecks[foldtext] = false

    local foldcontent = vim.api.nvim_buf_get_lines(0, vim.v.foldstart - 1, vim.v.foldend, false)
    for _, line in ipairs(foldcontent) do
      if string.sub(line, 1, warninglen) == warning or string.sub(line, 1, errorlen) == error then
        failedchecks[foldtext] = true
        break
      end
    end

    vim.b.failedchecks = failedchecks
  end

  return vim.b.failedchecks[foldtext] and '+WE' .. foldtext:sub(4) or foldtext
end

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
