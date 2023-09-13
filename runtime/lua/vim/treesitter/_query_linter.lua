local api = vim.api

local namespace = api.nvim_create_namespace('vim.treesitter.query_linter')

local M = {}

--- @class QueryLinterNormalizedOpts
--- @field langs string[]
--- @field clear boolean

--- @alias vim.treesitter.ParseError {msg: string, range: Range4}

--- @private
--- Caches parse results for queries for each language.
--- Entries of parse_cache[lang][query_text] will either be true for successful parse or contain the
--- message and range of the parse error.
--- @type table<string,table<string,vim.treesitter.ParseError|true>>
local parse_cache = {}

--- Contains language dependent context for the query linter
--- @class QueryLinterLanguageContext
--- @field lang string? Current `lang` of the targeted parser
--- @field parser_info table? Parser info returned by vim.treesitter.language.inspect
--- @field is_first_lang boolean Whether this is the first language of a linter run checking queries for multiple `langs`

--- @private
--- Adds a diagnostic for node in the query buffer
--- @param diagnostics Diagnostic[]
--- @param range Range4
--- @param lint string
--- @param lang string?
local function add_lint_for_node(diagnostics, range, lint, lang)
  local message = lint:gsub('\n', ' ')
  diagnostics[#diagnostics + 1] = {
    lnum = range[1],
    end_lnum = range[3],
    col = range[2],
    end_col = range[4],
    severity = vim.diagnostic.ERROR,
    message = message,
    source = lang,
  }
end

--- @private
--- Determines the target language of a query file by its path: <lang>/<query_type>.scm
--- @param buf integer
--- @return string?
local function guess_query_lang(buf)
  local filename = api.nvim_buf_get_name(buf)
  if filename ~= '' then
    return vim.F.npcall(vim.fn.fnamemodify, filename, ':p:h:t')
  end
end

--- @private
--- @param buf integer
--- @param opts QueryLinterOpts|QueryLinterNormalizedOpts|nil
--- @return QueryLinterNormalizedOpts
local function normalize_opts(buf, opts)
  opts = opts or {}
  if not opts.langs then
    opts.langs = guess_query_lang(buf)
  end

  if type(opts.langs) ~= 'table' then
    --- @diagnostic disable-next-line:assign-type-mismatch
    opts.langs = { opts.langs }
  end

  --- @cast opts QueryLinterNormalizedOpts
  opts.langs = opts.langs or {}
  return opts
end

local lint_query = [[;; query
  (program [(named_node) (list) (grouping)] @toplevel)
  (named_node
    name: _ @node.named)
  (anonymous_node
    name: _ @node.anonymous)
  (field_definition
    name: (identifier) @field)
  (predicate
    name: (identifier) @predicate.name
    type: (predicate_type) @predicate.type)
  (ERROR) @error
]]

--- @private
--- @param err string
--- @param node TSNode
--- @return vim.treesitter.ParseError
local function get_error_entry(err, node)
  local start_line, start_col = node:range()
  local line_offset, col_offset, msg = err:gmatch('.-:%d+: Query error at (%d+):(%d+)%. ([^:]+)')() ---@type string, string, string
  start_line, start_col =
    start_line + tonumber(line_offset) - 1, start_col + tonumber(col_offset) - 1
  local end_line, end_col = start_line, start_col
  if msg:match('^Invalid syntax') or msg:match('^Impossible') then
    -- Use the length of the underlined node
    local underlined = vim.split(err, '\n')[2]
    end_col = end_col + #underlined
  elseif msg:match('^Invalid') then
    -- Use the length of the problematic type/capture/field
    end_col = end_col + #msg:match('"([^"]+)"')
  end

  return {
    msg = msg,
    range = { start_line, start_col, end_line, end_col },
  }
end

--- @private
--- @param node TSNode
--- @param buf integer
--- @param lang string
--- @param diagnostics Diagnostic[]
local function check_toplevel(node, buf, lang, diagnostics)
  local query_text = vim.treesitter.get_node_text(node, buf)

  if not parse_cache[lang] then
    parse_cache[lang] = {}
  end

  local lang_cache = parse_cache[lang]

  if lang_cache[query_text] == nil then
    local cache_val, err = pcall(vim.treesitter.query.parse, lang, query_text) ---@type boolean|vim.treesitter.ParseError, string|Query

    if not cache_val and type(err) == 'string' then
      cache_val = get_error_entry(err, node)
    end

    lang_cache[query_text] = cache_val
  end

  local cache_entry = lang_cache[query_text]

  if type(cache_entry) ~= 'boolean' then
    add_lint_for_node(diagnostics, cache_entry.range, cache_entry.msg, lang)
  end
end

--- @private
--- @param buf integer
--- @param match table<integer,TSNode>
--- @param query Query
--- @param lang_context QueryLinterLanguageContext
--- @param diagnostics Diagnostic[]
local function lint_match(buf, match, query, lang_context, diagnostics)
  local lang = lang_context.lang
  local parser_info = lang_context.parser_info

  for id, node in pairs(match) do
    local cap_id = query.captures[id]

    -- perform language-independent checks only for first lang
    if lang_context.is_first_lang and cap_id == 'error' then
      local node_text = vim.treesitter.get_node_text(node, buf):gsub('\n', ' ')
      add_lint_for_node(diagnostics, { node:range() }, 'Syntax error: ' .. node_text)
    end

    -- other checks rely on Neovim parser introspection
    if lang and parser_info and cap_id == 'toplevel' then
      check_toplevel(node, buf, lang, diagnostics)
    end
  end
end

--- @private
--- @param buf integer Buffer to lint
--- @param opts QueryLinterOpts|QueryLinterNormalizedOpts|nil Options for linting
function M.lint(buf, opts)
  if buf == 0 then
    buf = api.nvim_get_current_buf()
  end

  local diagnostics = {}
  local query = vim.treesitter.query.parse('query', lint_query)

  opts = normalize_opts(buf, opts)

  -- perform at least one iteration even with no langs to perform language independent checks
  for i = 1, math.max(1, #opts.langs) do
    local lang = opts.langs[i]

    --- @type (table|nil)
    local parser_info = vim.F.npcall(vim.treesitter.language.inspect, lang)

    local parser = vim.treesitter.get_parser(buf)
    parser:parse()
    parser:for_each_tree(function(tree, ltree)
      if ltree:lang() == 'query' then
        for _, match, _ in query:iter_matches(tree:root(), buf, 0, -1) do
          local lang_context = {
            lang = lang,
            parser_info = parser_info,
            is_first_lang = i == 1,
          }
          lint_match(buf, match, query, lang_context, diagnostics)
        end
      end
    end)
  end

  vim.diagnostic.set(namespace, buf, diagnostics)
end

--- @private
--- @param buf integer
function M.clear(buf)
  vim.diagnostic.reset(namespace, buf)
end

--- @private
--- @param findstart integer
--- @param base string
function M.omnifunc(findstart, base)
  if findstart == 1 then
    local result =
      api.nvim_get_current_line():sub(1, api.nvim_win_get_cursor(0)[2]):find('["#%-%w]*$')
    return result - 1
  end

  local buf = api.nvim_get_current_buf()
  local query_lang = guess_query_lang(buf)

  local ok, parser_info = pcall(vim.treesitter.language.inspect, query_lang)
  if not ok then
    return -2
  end

  local items = {}
  for _, f in pairs(parser_info.fields) do
    if f:find(base, 1, true) then
      table.insert(items, f .. ':')
    end
  end
  for _, p in pairs(vim.treesitter.query.list_predicates()) do
    local text = '#' .. p
    local found = text:find(base, 1, true)
    if found and found <= 2 then -- with or without '#'
      table.insert(items, text)
    end
    text = '#not-' .. p
    found = text:find(base, 1, true)
    if found and found <= 2 then -- with or without '#'
      table.insert(items, text)
    end
  end
  for _, p in pairs(vim.treesitter.query.list_directives()) do
    local text = '#' .. p
    local found = text:find(base, 1, true)
    if found and found <= 2 then -- with or without '#'
      table.insert(items, text)
    end
  end
  for _, s in pairs(parser_info.symbols) do
    local text = s[2] and s[1] or '"' .. s[1]:gsub([[\]], [[\\]]) .. '"' ---@type string
    if text:find(base, 1, true) then
      table.insert(items, text)
    end
  end
  return { words = items, refresh = 'always' }
end

return M
