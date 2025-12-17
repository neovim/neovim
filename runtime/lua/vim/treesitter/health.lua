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

  health.start('Treesitter queries')
  local query_files = vim.api.nvim_get_runtime_file('queries/**/*.scm', true)
  ---@class QueryEntry
  ---@field lang string
  ---@field type string
  ---@field path string
  ---@field index integer
  local queries_by_lang = {} ---@type table<string, QueryEntry[]>
  for i, query_file in ipairs(query_files) do
    local lang, query_type = query_file:match('queries/([^/]+)/([^/]+)%.scm$')
    if lang and query_type then
      if not queries_by_lang[lang] then
        queries_by_lang[lang] = {}
      end
      table.insert(queries_by_lang[lang], {
        lang = lang,
        type = query_type,
        path = query_file,
        index = i,
      })
    end
  end
  if vim.tbl_isempty(queries_by_lang) then
    health.warn('No query files found')
  else
    for lang, queries in vim.spairs(queries_by_lang) do
      table.sort(queries, function(a, b)
        if a.type == b.type then
          return a.index < b.index
        else
          return a.type < b.type
        end
      end)

      for i, query in ipairs(queries) do
        local is_duplicate = i > 1 and queries[i - 1].type == query.type
        if is_duplicate then
          health.ok(
            string.format('Language: %-15s %s (not loaded): %s', lang, query.type, query.path)
          )
        else
          health.ok(string.format('Language: %-15s %s: %s', lang, query.type, query.path))
        end
      end
    end
  end
end

return M
