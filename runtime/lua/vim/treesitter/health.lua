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

  ---@class ParserEntry
  ---@field name string
  ---@field path string
  ---@field index integer runtime path index (unique)

  local sorted_parsers = {} ---@type ParserEntry[]

  for i, parser in ipairs(parsers) do
    local parsername = vim.fn.fnamemodify(parser, ':t:r')
    table.insert(sorted_parsers, { name = parsername, path = parser, index = i })
  end

  table.sort(sorted_parsers, function(a, b)
    if a.name == b.name then
      return a.index < b.index -- if names are the same sort by rtpath index (unique)
    else
      return a.name < b.name
    end
  end)

  for i, parser in ipairs(sorted_parsers) do
    local is_loadable, err_or_nil = pcall(ts.language.add, parser.name)

    if not is_loadable then
      health.error(
        string.format(
          'Parser "%s" failed to load (path: %s): %s',
          parser.name,
          parser.path,
          err_or_nil or '?'
        )
      )
    elseif i > 1 and sorted_parsers[i - 1].name == parser.name then
      -- Sorted by runtime path order (load order), thus, if the previous parser has the same name,
      -- the current parser will not be loaded and `ts.language.inspect(parser.name)` with have
      -- incorrect information.
      health.ok(string.format('Parser: %-20s (not loaded), path: %s', parser.name, parser.path))
    else
      local lang = ts.language.inspect(parser.name)
      health.ok(
        string.format('Parser: %-25s ABI: %d, path: %s', parser.name, lang.abi_version, parser.path)
      )
    end
  end
end

return M
