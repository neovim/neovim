local M = {}
local ts = vim.treesitter
local health = vim.health

--- Performs a healthcheck for treesitter integration
function M.check()
  health.start('Treesitter features')

  health.info(
    string.format(
      'Treesitter ABI support: min %d, max %d',
      vim.treesitter.minimum_language_version,
      ts.language_version
    )
  )

  local can_wasm = vim._ts_add_language_from_wasm ~= nil
  health.info(string.format('WASM parser support: %s', tostring(can_wasm)))

  health.start('Treesitter parsers')
  local parsers = vim.api.nvim_get_runtime_file('parser/*', true)
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
end

return M
