local api = vim.api
local language = require('vim.treesitter.language')

local M = {}

---@nodoc
---Parsed query, see |vim.treesitter.query.parse()|
---
---@class vim.treesitter.Query
---@field lang string name of the language for this parser
---@field captures string[] list of (unique) capture names defined in query
---@field info vim.treesitter.QueryInfo contains information used in the query (e.g. captures, predicates, directives)
---@field query TSQuery userdata query object
local Query = {}
Query.__index = Query

---@package
---@see vim.treesitter.query.parse
---@param lang string
---@param ts_query TSQuery
---@return vim.treesitter.Query
function Query.new(lang, ts_query)
  local self = setmetatable({}, Query)
  local query_info = ts_query:inspect() ---@type TSQueryInfo
  self.query = ts_query
  self.lang = lang
  self.info = {
    captures = query_info.captures,
    patterns = query_info.patterns,
  }
  self.captures = self.info.captures
  return self
end

---@nodoc
---Information for Query, see |vim.treesitter.query.parse()|
---@class vim.treesitter.QueryInfo
---
---List of (unique) capture names defined in query.
---@field captures string[]
---
---Contains information about predicates and directives.
---Key is pattern id, and value is list of predicates or directives defined in the pattern.
---A predicate or directive is a list of (integer|string); integer represents `capture_id`, and
---string represents (literal) arguments to predicate/directive. See |treesitter-predicates|
---and |treesitter-directives| for more details.
---@field patterns table<integer, (integer|string)[][]>

---@param files string[]
---@return string[]
local function dedupe_files(files)
  local result = {}
  ---@type table<string,boolean>
  local seen = {}

  for _, path in ipairs(files) do
    if not seen[path] then
      table.insert(result, path)
      seen[path] = true
    end
  end

  return result
end

local function safe_read(filename, read_quantifier)
  local file, err = io.open(filename, 'r')
  if not file then
    error(err)
  end
  local content = file:read(read_quantifier)
  io.close(file)
  return content
end

--- Adds {ilang} to {base_langs}, only if {ilang} is different than {lang}
---
---@return boolean true If lang == ilang
local function add_included_lang(base_langs, lang, ilang)
  if lang == ilang then
    return true
  end
  table.insert(base_langs, ilang)
  return false
end

---@deprecated
function M.get_query_files(...)
  vim.deprecate(
    'vim.treesitter.query.get_query_files()',
    'vim.treesitter.query.get_files()',
    '0.10'
  )
  return M.get_files(...)
end

--- Gets the list of files used to make up a query
---
---@param lang string Language to get query for
---@param query_name string Name of the query to load (e.g., "highlights")
---@param is_included (boolean|nil) Internal parameter, most of the time left as `nil`
---@return string[] query_files List of files to load for given query and language
function M.get_files(lang, query_name, is_included)
  local query_path = string.format('queries/%s/%s.scm', lang, query_name)
  local lang_files = dedupe_files(api.nvim_get_runtime_file(query_path, true))

  if #lang_files == 0 then
    return {}
  end

  local base_query = nil ---@type string?
  local extensions = {}

  local base_langs = {} ---@type string[]

  -- Now get the base languages by looking at the first line of every file
  -- The syntax is the following :
  -- ;+ inherits: ({language},)*{language}
  --
  -- {language} ::= {lang} | ({lang})
  local MODELINE_FORMAT = '^;+%s*inherits%s*:?%s*([a-z_,()]+)%s*$'
  local EXTENDS_FORMAT = '^;+%s*extends%s*$'

  for _, filename in ipairs(lang_files) do
    local file, err = io.open(filename, 'r')
    if not file then
      error(err)
    end

    local extension = false

    for modeline in
      ---@return string
      function()
        return file:read('*l')
      end
    do
      if not vim.startswith(modeline, ';') then
        break
      end

      local langlist = modeline:match(MODELINE_FORMAT)
      if langlist then
        ---@diagnostic disable-next-line:param-type-mismatch
        for _, incllang in ipairs(vim.split(langlist, ',', true)) do
          local is_optional = incllang:match('%(.*%)')

          if is_optional then
            if not is_included then
              if add_included_lang(base_langs, lang, incllang:sub(2, #incllang - 1)) then
                extension = true
              end
            end
          else
            if add_included_lang(base_langs, lang, incllang) then
              extension = true
            end
          end
        end
      elseif modeline:match(EXTENDS_FORMAT) then
        extension = true
      end
    end

    if extension then
      table.insert(extensions, filename)
    elseif base_query == nil then
      base_query = filename
    end
    io.close(file)
  end

  local query_files = {}
  for _, base_lang in ipairs(base_langs) do
    local base_files = M.get_files(base_lang, query_name, true)
    vim.list_extend(query_files, base_files)
  end
  vim.list_extend(query_files, { base_query })
  vim.list_extend(query_files, extensions)

  return query_files
end

---@param filenames string[]
---@return string
local function read_query_files(filenames)
  local contents = {}

  for _, filename in ipairs(filenames) do
    table.insert(contents, safe_read(filename, '*a'))
  end

  return table.concat(contents, '')
end

-- The explicitly set queries from |vim.treesitter.query.set()|
---@type table<string,table<string,vim.treesitter.Query>>
local explicit_queries = setmetatable({}, {
  __index = function(t, k)
    local lang_queries = {}
    rawset(t, k, lang_queries)

    return lang_queries
  end,
})

---@deprecated
function M.set_query(...)
  vim.deprecate('vim.treesitter.query.set_query()', 'vim.treesitter.query.set()', '0.10')
  M.set(...)
end

--- Sets the runtime query named {query_name} for {lang}
---
--- This allows users to override any runtime files and/or configuration
--- set by plugins.
---
---@param lang string Language to use for the query
---@param query_name string Name of the query (e.g., "highlights")
---@param text string Query text (unparsed).
function M.set(lang, query_name, text)
  explicit_queries[lang][query_name] = M.parse(lang, text)
end

---@deprecated
function M.get_query(...)
  vim.deprecate('vim.treesitter.query.get_query()', 'vim.treesitter.query.get()', '0.10')
  return M.get(...)
end

--- Returns the runtime query {query_name} for {lang}.
---
---@param lang string Language to use for the query
---@param query_name string Name of the query (e.g. "highlights")
---
---@return vim.treesitter.Query|nil : Parsed query. `nil` if no query files are found.
M.get = vim.func._memoize('concat-2', function(lang, query_name)
  if explicit_queries[lang][query_name] then
    return explicit_queries[lang][query_name]
  end

  local query_files = M.get_files(lang, query_name)
  local query_string = read_query_files(query_files)

  if #query_string == 0 then
    return nil
  end

  return M.parse(lang, query_string)
end)

---@deprecated
function M.parse_query(...)
  vim.deprecate('vim.treesitter.query.parse_query()', 'vim.treesitter.query.parse()', '0.10')
  return M.parse(...)
end

--- Parse {query} as a string. (If the query is in a file, the caller
--- should read the contents into a string before calling).
---
--- Returns a `Query` (see |lua-treesitter-query|) object which can be used to
--- search nodes in the syntax tree for the patterns defined in {query}
--- using the `iter_captures` and `iter_matches` methods.
---
--- Exposes `info` and `captures` with additional context about {query}.
---   - `captures` contains the list of unique capture names defined in {query}.
---   - `info.captures` also points to `captures`.
---   - `info.patterns` contains information about predicates.
---
---@param lang string Language to use for the query
---@param query string Query in s-expr syntax
---
---@return vim.treesitter.Query Parsed query
---
---@see |vim.treesitter.query.get()|
M.parse = vim.func._memoize('concat-2', function(lang, query)
  language.add(lang)

  local ts_query = vim._ts_parse_query(lang, query)
  return Query.new(lang, ts_query)
end)

---@deprecated
function M.get_range(...)
  vim.deprecate('vim.treesitter.query.get_range()', 'vim.treesitter.get_range()', '0.10')
  return vim.treesitter.get_range(...)
end

---@deprecated
function M.get_node_text(...)
  vim.deprecate('vim.treesitter.query.get_node_text()', 'vim.treesitter.get_node_text()', '0.10')
  return vim.treesitter.get_node_text(...)
end

--- Implementations of predicates that can optionally be prefixed with "any-".
---
--- These functions contain the implementations for each predicate, correctly
--- handling the "any" vs "all" semantics. They are called from the
--- predicate_handlers table with the appropriate arguments for each predicate.
local impl = {
  --- @param match vim.treesitter.query.TSMatch
  --- @param source integer|string
  --- @param predicate any[]
  --- @param any boolean
  ['eq'] = function(match, source, predicate, any)
    local nodes = match[predicate[2]]
    if not nodes or #nodes == 0 then
      return true
    end

    for _, node in ipairs(nodes) do
      local node_text = vim.treesitter.get_node_text(node, source)

      local str ---@type string
      if type(predicate[3]) == 'string' then
        -- (#eq? @aa "foo")
        str = predicate[3]
      else
        -- (#eq? @aa @bb)
        local other = assert(match[predicate[3]])
        assert(#other == 1, '#eq? does not support comparison with captures on multiple nodes')
        str = vim.treesitter.get_node_text(other[1], source)
      end

      local res = str ~= nil and node_text == str
      if any and res then
        return true
      elseif not any and not res then
        return false
      end
    end

    return not any
  end,

  --- @param match vim.treesitter.query.TSMatch
  --- @param source integer|string
  --- @param predicate any[]
  --- @param any boolean
  ['lua-match'] = function(match, source, predicate, any)
    local nodes = match[predicate[2]]
    if not nodes or #nodes == 0 then
      return true
    end

    for _, node in ipairs(nodes) do
      local regex = predicate[3]
      local res = string.find(vim.treesitter.get_node_text(node, source), regex) ~= nil
      if any and res then
        return true
      elseif not any and not res then
        return false
      end
    end

    return not any
  end,

  ['match'] = (function()
    local magic_prefixes = { ['\\v'] = true, ['\\m'] = true, ['\\M'] = true, ['\\V'] = true }
    local function check_magic(str)
      if string.len(str) < 2 or magic_prefixes[string.sub(str, 1, 2)] then
        return str
      end
      return '\\v' .. str
    end

    local compiled_vim_regexes = setmetatable({}, {
      __index = function(t, pattern)
        local res = vim.regex(check_magic(pattern))
        rawset(t, pattern, res)
        return res
      end,
    })

    --- @param match vim.treesitter.query.TSMatch
    --- @param source integer|string
    --- @param predicate any[]
    --- @param any boolean
    return function(match, source, predicate, any)
      local nodes = match[predicate[2]]
      if not nodes or #nodes == 0 then
        return true
      end

      for _, node in ipairs(nodes) do
        local regex = compiled_vim_regexes[predicate[3]] ---@type vim.regex
        local res = regex:match_str(vim.treesitter.get_node_text(node, source))
        if any and res then
          return true
        elseif not any and not res then
          return false
        end
      end
      return not any
    end
  end)(),

  --- @param match vim.treesitter.query.TSMatch
  --- @param source integer|string
  --- @param predicate any[]
  --- @param any boolean
  ['contains'] = function(match, source, predicate, any)
    local nodes = match[predicate[2]]
    if not nodes or #nodes == 0 then
      return true
    end

    for _, node in ipairs(nodes) do
      local node_text = vim.treesitter.get_node_text(node, source)

      for i = 3, #predicate do
        local res = string.find(node_text, predicate[i], 1, true)
        if any and res then
          return true
        elseif not any and not res then
          return false
        end
      end
    end

    return not any
  end,
}

---@nodoc
---@class vim.treesitter.query.TSMatch
---@field pattern? integer
---@field active? boolean
---@field [integer] TSNode[]

---@alias TSPredicate fun(match: vim.treesitter.query.TSMatch, pattern: integer, source: integer|string, predicate: any[]): boolean

-- Predicate handler receive the following arguments
-- (match, pattern, bufnr, predicate)
---@type table<string,TSPredicate>
local predicate_handlers = {
  ['eq?'] = function(match, _, source, predicate)
    return impl['eq'](match, source, predicate, false)
  end,

  ['any-eq?'] = function(match, _, source, predicate)
    return impl['eq'](match, source, predicate, true)
  end,

  ['lua-match?'] = function(match, _, source, predicate)
    return impl['lua-match'](match, source, predicate, false)
  end,

  ['any-lua-match?'] = function(match, _, source, predicate)
    return impl['lua-match'](match, source, predicate, true)
  end,

  ['match?'] = function(match, _, source, predicate)
    return impl['match'](match, source, predicate, false)
  end,

  ['any-match?'] = function(match, _, source, predicate)
    return impl['match'](match, source, predicate, true)
  end,

  ['contains?'] = function(match, _, source, predicate)
    return impl['contains'](match, source, predicate, false)
  end,

  ['any-contains?'] = function(match, _, source, predicate)
    return impl['contains'](match, source, predicate, true)
  end,

  ['any-of?'] = function(match, _, source, predicate)
    local nodes = match[predicate[2]]
    if not nodes or #nodes == 0 then
      return true
    end

    for _, node in ipairs(nodes) do
      local node_text = vim.treesitter.get_node_text(node, source)

      -- Since 'predicate' will not be used by callers of this function, use it
      -- to store a string set built from the list of words to check against.
      local string_set = predicate['string_set'] --- @type table<string, boolean>
      if not string_set then
        string_set = {}
        for i = 3, #predicate do
          string_set[predicate[i]] = true
        end
        predicate['string_set'] = string_set
      end

      if string_set[node_text] then
        return true
      end
    end

    return false
  end,

  ['has-ancestor?'] = function(match, _, _, predicate)
    local nodes = match[predicate[2]]
    if not nodes or #nodes == 0 then
      return true
    end

    for _, node in ipairs(nodes) do
      local ancestor_types = {} --- @type table<string, boolean>
      for _, type in ipairs({ unpack(predicate, 3) }) do
        ancestor_types[type] = true
      end

      local cur = node:parent()
      while cur do
        if ancestor_types[cur:type()] then
          return true
        end
        cur = cur:parent()
      end
    end
    return false
  end,

  ['has-parent?'] = function(match, _, _, predicate)
    local nodes = match[predicate[2]]
    if not nodes or #nodes == 0 then
      return true
    end

    for _, node in ipairs(nodes) do
      if vim.list_contains({ unpack(predicate, 3) }, node:parent():type()) then
        return true
      end
    end
    return false
  end,
}

-- As we provide lua-match? also expose vim-match?
predicate_handlers['vim-match?'] = predicate_handlers['match?']
predicate_handlers['any-vim-match?'] = predicate_handlers['any-match?']

---@nodoc
---@class vim.treesitter.query.TSMetadata
---@field range? Range
---@field conceal? string
---@field [integer] vim.treesitter.query.TSMetadata
---@field [string] integer|string

---@alias TSDirective fun(match: vim.treesitter.query.TSMatch, _, _, predicate: (string|integer)[], metadata: vim.treesitter.query.TSMetadata)

-- Predicate handler receive the following arguments
-- (match, pattern, bufnr, predicate)

-- Directives store metadata or perform side effects against a match.
-- Directives should always end with a `!`.
-- Directive handler receive the following arguments
-- (match, pattern, bufnr, predicate, metadata)
---@type table<string,TSDirective>
local directive_handlers = {
  ['set!'] = function(_, _, _, pred, metadata)
    if #pred >= 3 and type(pred[2]) == 'number' then
      -- (#set! @capture key value)
      local capture_id, key, value = pred[2], pred[3], pred[4]
      if not metadata[capture_id] then
        metadata[capture_id] = {}
      end
      metadata[capture_id][key] = value
    else
      -- (#set! key value)
      local key, value = pred[2], pred[3]
      metadata[key] = value or true
    end
  end,
  -- Shifts the range of a node.
  -- Example: (#offset! @_node 0 1 0 -1)
  ['offset!'] = function(match, _, _, pred, metadata)
    local capture_id = pred[2] --[[@as integer]]
    local nodes = match[capture_id]
    assert(#nodes == 1, '#offset! does not support captures on multiple nodes')

    local node = nodes[1]

    if not metadata[capture_id] then
      metadata[capture_id] = {}
    end

    local range = metadata[capture_id].range or { node:range() }
    local start_row_offset = pred[3] or 0
    local start_col_offset = pred[4] or 0
    local end_row_offset = pred[5] or 0
    local end_col_offset = pred[6] or 0

    range[1] = range[1] + start_row_offset
    range[2] = range[2] + start_col_offset
    range[3] = range[3] + end_row_offset
    range[4] = range[4] + end_col_offset

    -- If this produces an invalid range, we just skip it.
    if range[1] < range[3] or (range[1] == range[3] and range[2] <= range[4]) then
      metadata[capture_id].range = range
    end
  end,
  -- Transform the content of the node
  -- Example: (#gsub! @_node ".*%.(.*)" "%1")
  ['gsub!'] = function(match, _, bufnr, pred, metadata)
    assert(#pred == 4)

    local id = pred[2]
    assert(type(id) == 'number')

    local nodes = match[id]
    assert(#nodes == 1, '#gsub! does not support captures on multiple nodes')
    local node = nodes[1]
    local text = vim.treesitter.get_node_text(node, bufnr, { metadata = metadata[id] }) or ''

    if not metadata[id] then
      metadata[id] = {}
    end

    local pattern, replacement = pred[3], pred[4]
    assert(type(pattern) == 'string')
    assert(type(replacement) == 'string')

    metadata[id].text = text:gsub(pattern, replacement)
  end,
  -- Trim blank lines from end of the node
  -- Example: (#trim! @fold)
  -- TODO(clason): generalize to arbitrary whitespace removal
  ['trim!'] = function(match, _, bufnr, pred, metadata)
    local capture_id = pred[2]
    assert(type(capture_id) == 'number')

    local nodes = match[capture_id]
    assert(#nodes == 1, '#trim! does not support captures on multiple nodes')
    local node = nodes[1]

    local start_row, start_col, end_row, end_col = node:range()

    -- Don't trim if region ends in middle of a line
    if end_col ~= 0 then
      return
    end

    while end_row >= start_row do
      -- As we only care when end_col == 0, always inspect one line above end_row.
      local end_line = api.nvim_buf_get_lines(bufnr, end_row - 1, end_row, true)[1]

      if end_line ~= '' then
        break
      end

      end_row = end_row - 1
    end

    -- If this produces an invalid range, we just skip it.
    if start_row < end_row or (start_row == end_row and start_col <= end_col) then
      metadata[capture_id] = metadata[capture_id] or {}
      metadata[capture_id].range = { start_row, start_col, end_row, end_col }
    end
  end,
}

--- Adds a new predicate to be used in queries
---
---@param name string Name of the predicate, without leading #
---@param handler function(match: table<integer,TSNode[]>, pattern: integer, source: integer|string, predicate: any[], metadata: table)
---   - see |vim.treesitter.query.add_directive()| for argument meanings
---@param opts table<string, any> Optional options:
---                                 - force (boolean): Override an existing
---                                   predicate of the same name
---                                 - all (boolean): Use the correct
---                                   implementation of the match table where
---                                   capture IDs map to a list of nodes instead
---                                   of a single node. Defaults to false (for
---                                   backward compatibility). This option will
---                                   eventually become the default and removed.
function M.add_predicate(name, handler, opts)
  -- Backward compatibility: old signature had "force" as boolean argument
  if type(opts) == 'boolean' then
    opts = { force = opts }
  end

  opts = opts or {}

  if predicate_handlers[name] and not opts.force then
    error(string.format('Overriding existing predicate %s', name))
  end

  if opts.all then
    predicate_handlers[name] = handler
  else
    --- @param match table<integer, TSNode[]>
    local function wrapper(match, ...)
      local m = {} ---@type table<integer, TSNode>
      for k, v in pairs(match) do
        if type(k) == 'number' then
          m[k] = v[#v]
        end
      end
      return handler(m, ...)
    end
    predicate_handlers[name] = wrapper
  end
end

--- Adds a new directive to be used in queries
---
--- Handlers can set match level data by setting directly on the
--- metadata object `metadata.key = value`. Additionally, handlers
--- can set node level data by using the capture id on the
--- metadata table `metadata[capture_id].key = value`
---
---@param name string Name of the directive, without leading #
---@param handler function(match: table<integer,TSNode[]>, pattern: integer, source: integer|string, predicate: any[], metadata: table)
---   - match: A table mapping capture IDs to a list of captured nodes
---   - pattern: the index of the matching pattern in the query file
---   - predicate: list of strings containing the full directive being called, e.g.
---     `(node (#set! conceal "-"))` would get the predicate `{ "#set!", "conceal", "-" }`
---@param opts table<string, any> Optional options:
---                                 - force (boolean): Override an existing
---                                   predicate of the same name
---                                 - all (boolean): Use the correct
---                                   implementation of the match table where
---                                   capture IDs map to a list of nodes instead
---                                   of a single node. Defaults to false (for
---                                   backward compatibility). This option will
---                                   eventually become the default and removed.
function M.add_directive(name, handler, opts)
  -- Backward compatibility: old signature had "force" as boolean argument
  if type(opts) == 'boolean' then
    opts = { force = opts }
  end

  opts = opts or {}

  if directive_handlers[name] and not opts.force then
    error(string.format('Overriding existing directive %s', name))
  end

  if opts.all then
    directive_handlers[name] = handler
  else
    --- @param match table<integer, TSNode[]>
    local function wrapper(match, ...)
      local m = {} ---@type table<integer, TSNode>
      for k, v in pairs(match) do
        m[k] = v[#v]
      end
      handler(m, ...)
    end
    directive_handlers[name] = wrapper
  end
end

--- Lists the currently available directives to use in queries.
---@return string[] List of supported directives.
function M.list_directives()
  return vim.tbl_keys(directive_handlers)
end

--- Lists the currently available predicates to use in queries.
---@return string[] List of supported predicates.
function M.list_predicates()
  return vim.tbl_keys(predicate_handlers)
end

local function xor(x, y)
  return (x or y) and not (x and y)
end

local function is_directive(name)
  return string.sub(name, -1) == '!'
end

---@private
---@param match vim.treesitter.query.TSMatch
---@param pattern integer
---@param source integer|string
function Query:match_preds(match, pattern, source)
  local preds = self.info.patterns[pattern]

  for _, pred in pairs(preds or {}) do
    -- Here we only want to return if a predicate DOES NOT match, and
    -- continue on the other case. This way unknown predicates will not be considered,
    -- which allows some testing and easier user extensibility (#12173).
    -- Also, tree-sitter strips the leading # from predicates for us.
    local is_not = false

    -- Skip over directives... they will get processed after all the predicates.
    if not is_directive(pred[1]) then
      local pred_name = pred[1]
      if pred_name:match('^not%-') then
        pred_name = pred_name:sub(5)
        is_not = true
      end

      local handler = predicate_handlers[pred_name]

      if not handler then
        error(string.format('No handler for %s', pred[1]))
        return false
      end

      local pred_matches = handler(match, pattern, source, pred)

      if not xor(is_not, pred_matches) then
        return false
      end
    end
  end
  return true
end

---@private
---@param match vim.treesitter.query.TSMatch
---@param metadata vim.treesitter.query.TSMetadata
function Query:apply_directives(match, pattern, source, metadata)
  local preds = self.info.patterns[pattern]

  for _, pred in pairs(preds or {}) do
    if is_directive(pred[1]) then
      local handler = directive_handlers[pred[1]]

      if not handler then
        error(string.format('No handler for %s', pred[1]))
        return
      end

      handler(match, pattern, source, pred, metadata)
    end
  end
end

--- Returns the start and stop value if set else the node's range.
-- When the node's range is used, the stop is incremented by 1
-- to make the search inclusive.
---@param start integer|nil
---@param stop integer|nil
---@param node TSNode
---@return integer, integer
local function value_or_node_range(start, stop, node)
  if start == nil then
    start = node:start()
  end
  if stop == nil then
    stop = node:end_() + 1 -- Make stop inclusive
  end

  return start, stop
end

--- Iterate over all captures from all matches inside {node}
---
--- {source} is needed if the query contains predicates; then the caller
--- must ensure to use a freshly parsed tree consistent with the current
--- text of the buffer (if relevant). {start} and {stop} can be used to limit
--- matches inside a row range (this is typically used with root node
--- as the {node}, i.e., to get syntax highlight matches in the current
--- viewport). When omitted, the {start} and {stop} row values are used from the given node.
---
--- The iterator returns three values: a numeric id identifying the capture,
--- the captured node, and metadata from any directives processing the match.
--- The following example shows how to get captures by name:
---
--- ```lua
--- for id, node, metadata in query:iter_captures(tree:root(), bufnr, first, last) do
---   local name = query.captures[id] -- name of the capture in the query
---   -- typically useful info about the node:
---   local type = node:type() -- type of the captured node
---   local row1, col1, row2, col2 = node:range() -- range of the capture
---   -- ... use the info here ...
--- end
--- ```
---
---@param node TSNode under which the search will occur
---@param source (integer|string) Source buffer or string to extract text from
---@param start? integer Starting line for the search. Defaults to `node:start()`.
---@param stop? integer Stopping line for the search (end-exclusive). Defaults to `node:end_()`.
---
---@return (fun(end_line: integer|nil): integer, TSNode, vim.treesitter.query.TSMetadata):
---        capture id, capture node, metadata
function Query:iter_captures(node, source, start, stop)
  if type(source) == 'number' and source == 0 then
    source = api.nvim_get_current_buf()
  end

  start, stop = value_or_node_range(start, stop, node)

  local raw_iter = node:_rawquery(self.query, true, start, stop) ---@type fun(): integer, TSNode, vim.treesitter.query.TSMatch
  local function iter(end_line)
    local capture, captured_node, match = raw_iter()
    local metadata = {}

    if match ~= nil then
      local active = self:match_preds(match, match.pattern, source)
      match.active = active
      if not active then
        if end_line and captured_node:range() > end_line then
          return nil, captured_node, nil
        end
        return iter(end_line) -- tail call: try next match
      end

      self:apply_directives(match, match.pattern, source, metadata)
    end
    return capture, captured_node, metadata
  end
  return iter
end

--- Iterates the matches of self on a given range.
---
--- Iterate over all matches within a {node}. The arguments are the same as for
--- |Query:iter_captures()| but the iterated values are different: an (1-based)
--- index of the pattern in the query, a table mapping capture indices to a list
--- of nodes, and metadata from any directives processing the match.
---
--- WARNING: Set `all=true` to ensure all matching nodes in a match are
--- returned, otherwise only the last node in a match is returned, breaking captures
--- involving quantifiers such as `(comment)+ @comment`. The default option
--- `all=false` is only provided for backward compatibility and will be removed
--- after Nvim 0.10.
---
--- Example:
---
--- ```lua
--- for pattern, match, metadata in cquery:iter_matches(tree:root(), bufnr, 0, -1, { all = true }) do
---   for id, nodes in pairs(match) do
---     local name = query.captures[id]
---     for _, node in ipairs(nodes) do
---       -- `node` was captured by the `name` capture in the match
---
---       local node_data = metadata[id] -- Node level metadata
---       ... use the info here ...
---     end
---   end
--- end
--- ```
---
---
---@param node TSNode under which the search will occur
---@param source (integer|string) Source buffer or string to search
---@param start? integer Starting line for the search. Defaults to `node:start()`.
---@param stop? integer Stopping line for the search (end-exclusive). Defaults to `node:end_()`.
---@param opts? table Optional keyword arguments:
---   - max_start_depth (integer) if non-zero, sets the maximum start depth
---     for each match. This is used to prevent traversing too deep into a tree.
---   - all (boolean) When set, the returned match table maps capture IDs to a list of nodes.
---     Older versions of iter_matches incorrectly mapped capture IDs to a single node, which is
---     incorrect behavior. This option will eventually become the default and removed.
---
---@return (fun(): integer, table<integer, TSNode[]>, table): pattern id, match, metadata
function Query:iter_matches(node, source, start, stop, opts)
  local all = opts and opts.all
  if type(source) == 'number' and source == 0 then
    source = api.nvim_get_current_buf()
  end

  start, stop = value_or_node_range(start, stop, node)

  local raw_iter = node:_rawquery(self.query, false, start, stop, opts) ---@type fun(): integer, vim.treesitter.query.TSMatch
  local function iter()
    local pattern, match = raw_iter()
    local metadata = {}

    if match ~= nil then
      local active = self:match_preds(match, pattern, source)
      if not active then
        return iter() -- tail call: try next match
      end

      self:apply_directives(match, pattern, source, metadata)
    end

    if not all then
      -- Convert the match table into the old buggy version for backward
      -- compatibility. This is slow. Plugin authors, if you're reading this, set the "all"
      -- option!
      local old_match = {} ---@type table<integer, TSNode>
      for k, v in pairs(match or {}) do
        old_match[k] = v[#v]
      end
      return pattern, old_match, metadata
    end

    return pattern, match, metadata
  end
  return iter
end

--- Optional keyword arguments:
--- @class vim.treesitter.query.lint.Opts
--- @inlinedoc
---
--- Language(s) to use for checking the query.
--- If multiple languages are specified, queries are validated for all of them
--- @field langs? string|string[]
---
--- Just clear current lint errors
--- @field clear boolean

--- Lint treesitter queries using installed parser, or clear lint errors.
---
--- Use |treesitter-parsers| in runtimepath to check the query file in {buf} for errors:
---
---   - verify that used nodes are valid identifiers in the grammar.
---   - verify that predicates and directives are valid.
---   - verify that top-level s-expressions are valid.
---
--- The found diagnostics are reported using |diagnostic-api|.
--- By default, the parser used for verification is determined by the containing folder
--- of the query file, e.g., if the path ends in `/lua/highlights.scm`, the parser for the
--- `lua` language will be used.
---@param buf (integer) Buffer handle
---@param opts? vim.treesitter.query.lint.Opts
function M.lint(buf, opts)
  if opts and opts.clear then
    vim.treesitter._query_linter.clear(buf)
  else
    vim.treesitter._query_linter.lint(buf, opts)
  end
end

--- Omnifunc for completing node names and predicates in treesitter queries.
---
--- Use via
---
--- ```lua
--- vim.bo.omnifunc = 'v:lua.vim.treesitter.query.omnifunc'
--- ```
---
--- @param findstart 0|1
--- @param base string
function M.omnifunc(findstart, base)
  return vim.treesitter._query_linter.omnifunc(findstart, base)
end

--- Opens a live editor to query the buffer you started from.
---
--- Can also be shown with *:EditQuery*.
---
--- If you move the cursor to a capture name ("@foo"), text matching the capture is highlighted in
--- the source buffer. The query editor is a scratch buffer, use `:write` to save it. You can find
--- example queries at `$VIMRUNTIME/queries/`.
---
--- @param lang? string language to open the query editor for. If omitted, inferred from the current buffer's filetype.
function M.edit(lang)
  vim.treesitter.dev.edit_query(lang)
end

return M
