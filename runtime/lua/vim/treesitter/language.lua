local a = vim.api

local M = {}

function M.require_language(lang, path)
  if vim._ts_has_language(lang) then
    return true
  end
  if path == nil then
    local fname = 'parser/' .. lang .. '.*'
    local paths = a.nvim_get_runtime_file(fname, false)
    if #paths == 0 then
      -- TODO(bfredl): help tag?
      error("no parser for '"..lang.."' language")
    end
    path = paths[1]
  end
  vim._ts_add_language(path, lang)
end

function M.inspect_language(lang)
  M.require_language(lang)
  return vim._ts_inspect_language(lang)
end

return M
