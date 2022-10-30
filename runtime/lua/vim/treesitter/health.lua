local M = {}
local ts = vim.treesitter
local health = require('vim.health')

--- Lists the parsers currently installed
---
---@return string[] list of parser files
function M.list_parsers()
  return vim.api.nvim_get_runtime_file('parser/*', true)
end

--- Performs a healthcheck for treesitter integration
function M.check()
  local parsers = M.list_parsers()

  health.report_info(string.format('Nvim runtime ABI version: %d', ts.language_version))

  for _, parser in pairs(parsers) do
    local parsername = vim.fn.fnamemodify(parser, ':t:r')
    local is_loadable, ret = pcall(ts.language.require_language, parsername)

    if not is_loadable or not ret then
      health.report_error(
        string.format('Parser "%s" failed to load (path: %s): %s', parsername, parser, ret or '?')
      )
    elseif ret then
      local lang = ts.language.inspect_language(parsername)
      health.report_ok(
        string.format('Parser: %-10s ABI: %d, path: %s', parsername, lang._abi_version, parser)
      )
    end
  end
end

return M
