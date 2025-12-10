local M = {}
local ts = vim.treesitter
local health = vim.health

--- Performs a healthcheck for treesitter integration
function M.check()
  health.start('Treesitter features')

  health.info(
    string.format(
      'Treesitter ABI support: min %d, max %d',
      ts.minimum_language_version,
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

  -- Show quarantined parsers first
  local quarantined = ts.language.get_quarantined()
  if vim.tbl_count(quarantined) > 0 then
    health.start('Quarantined parsers (previously crashed)')
    for lang, err_msg in pairs(quarantined) do
      health.error(string.format('Parser: %s - %s', lang, err_msg))
    end
  end

  -- Test all parsers
  health.start('Parser health check')
  for i, parser in ipairs(sorted_parsers) do
    -- Skip if this is a duplicate parser (lower priority in runtime path)
    if i > 1 and sorted_parsers[i - 1].name == parser.name then
      health.ok(string.format('Parser: %-20s (not loaded), path: %s', parser.name, parser.path))
      goto continue
    end

    -- Try to load the parser
    local is_loadable, err_or_nil = pcall(ts.language.add, parser.name)

    if not is_loadable then
      -- Failed to load - check if it's quarantined
      if ts.language.is_quarantined(parser.name) then
        health.error(
          string.format(
            'Parser "%s" is quarantined (crashed during load), path: %s',
            parser.name,
            parser.path
          )
        )
      else
        health.error(
          string.format(
            'Parser "%s" failed to load (path: %s): %s',
            parser.name,
            parser.path,
            err_or_nil or '?'
          )
        )
      end
      goto continue
    end

    -- Parser loaded successfully - now test it
    ---@diagnostic disable-next-line: no-unknown
    local test_ok, test_err = vim._ts_test_parser(parser.name)

    if not test_ok then
      health.error(
        string.format(
          'Parser "%s" crashed during test (path: %s): %s\nRecommendation: Run :TSUninstall %s and :TSInstall %s to rebuild',
          parser.name,
          parser.path,
          test_err or 'unknown error',
          parser.name,
          parser.name
        )
      )
    else
      local lang = ts.language.inspect(parser.name)
      health.ok(
        string.format('Parser: %-25s ABI: %d, path: %s', parser.name, lang.abi_version, parser.path)
      )
    end

    ::continue::
  end
end

return M
