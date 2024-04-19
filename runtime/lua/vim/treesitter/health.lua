local M = {}
local ts = vim.treesitter
local health = vim.health

--- Performs a healthcheck for treesitter integration
function M.check()
  local parsers = vim.api.nvim_get_runtime_file('parser/*', true)

  health.info(string.format('Nvim runtime ABI version: %d', ts.language_version))

  for _, parser in pairs(parsers) do
    local parsername = vim.fn.fnamemodify(parser, ':t:r')
    local is_loadable, err_or_nil = pcall(ts.language.add, parsername)

    if not is_loadable then
      health.error(
        string.format(
          'Parser "%s" failed to load (path: %s): %s',
          parsername,
          parser,
          err_or_nil or '?'
        )
      )
    else
      local lang = ts.language.inspect(parsername)
      health.ok(
        string.format('Parser: %-20s ABI: %d, path: %s', parsername, lang._abi_version, parser)
      )
    end
  end

  local can_wasm = vim._ts_add_language_from_wasm ~= nil
  health.info(string.format('Can load WASM parsers: %s', tostring(can_wasm)))
end

return M
