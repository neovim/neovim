local a = vim.api
local language = require'vim.treesitter.language'

-- query: pattern matching on trees
-- predicate matching is implemented in lua
local Query = {}
Query.__index = Query

local M = {}

local function dedupe_files(files)
  local result = {}
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

function M.get_query_files(lang, query_name, is_included)
  local query_path = string.format('queries/%s/%s.scm', lang, query_name)
  local lang_files = dedupe_files(a.nvim_get_runtime_file(query_path, true))

  if #lang_files == 0 then return {} end

  local base_langs = {}

  -- Now get the base languages by looking at the first line of every file
  -- The syntax is the folowing :
  -- ;+ inherits: ({language},)*{language}
  --
  -- {language} ::= {lang} | ({lang})
  local MODELINE_FORMAT = "^;+%s*inherits%s*:?%s*([a-z_,()]+)%s*$"

  for _, file in ipairs(lang_files) do
    local modeline = safe_read(file, '*l')

    if modeline then
      local langlist = modeline:match(MODELINE_FORMAT)

      if langlist then
        for _, incllang in ipairs(vim.split(langlist, ',', true)) do
          local is_optional = incllang:match("%(.*%)")

          if is_optional then
            if not is_included then
              table.insert(base_langs, incllang:sub(2, #incllang - 1))
            end
          else
            table.insert(base_langs, incllang)
          end
        end
      end
    end
  end

  local query_files = {}
  for _, base_lang in ipairs(base_langs) do
    local base_files = M.get_query_files(base_lang, query_name, true)
    vim.list_extend(query_files, base_files)
  end
  vim.list_extend(query_files, lang_files)

  return query_files
end

local function read_query_files(filenames)
  local contents = {}

  for _,filename in ipairs(filenames) do
    table.insert(contents, safe_read(filename, '*a'))
  end

  return table.concat(contents, '')
end

--- The explicitly set queries from |vim.treesitter.query.set_query()|
local explicit_queries = setmetatable({}, {
  __index = function(t, k)
    local lang_queries = {}
    rawset(t, k, lang_queries)

    return lang_queries
  end,
})

--- Sets the runtime query {query_name} for {lang}
---
--- This allows users to override any runtime files and/or configuration
--- set by plugins.
---@param lang string: The language to use for the query
---@param query_name string: The name of the query (i.e. "highlights")
---@param text string: The query text (unparsed).
function M.set_query(lang, query_name, text)
  explicit_queries[lang][query_name] = M.parse_query(lang, text)
end

--- Returns the runtime query {query_name} for {lang}.
--
-- @param lang The language to use for the query
-- @param query_name The name of the query (i.e. "highlights")
--
-- @return The corresponding query, parsed.
function M.get_query(lang, query_name)
  if explicit_queries[lang][query_name] then
    return explicit_queries[lang][query_name]
  end

  local query_files = M.get_query_files(lang, query_name)
  local query_string = read_query_files(query_files)

  if #query_string > 0 then
    return M.parse_query(lang, query_string)
  end
end

--- Parses a query.
--
-- @param language The language
-- @param query A string containing the query (s-expr syntax)
--
-- @returns The query
function M.parse_query(lang, query)
  language.require_language(lang)
  local self = setmetatable({}, Query)
  self.query = vim._ts_parse_query(lang, query)
  self.info = self.query:inspect()
  self.captures = self.info.captures
  return self
end

-- TODO(vigoux): support multiline nodes too

--- Gets the text corresponding to a given node
-- @param node the node
-- @param bufnr the buffer from which the node is extracted.
function M.get_node_text(node, source)
  local start_row, start_col, start_byte = node:start()
  local end_row, end_col, end_byte = node:end_()

  if type(source) == "number" then
    if start_row ~= end_row then
      return nil
    end
    local line = a.nvim_buf_get_lines(source, start_row, start_row+1, true)[1]
    return string.sub(line, start_col+1, end_col)
  elseif type(source) == "string" then
    return source:sub(start_byte+1, end_byte)
  end
end

-- Predicate handler receive the following arguments
-- (match, pattern, bufnr, predicate)
local predicate_handlers = {
  ["eq?"] = function(match, _, source, predicate)
      local node = match[predicate[2]]
      local node_text = M.get_node_text(node, source)

      local str
      if type(predicate[3]) == "string" then
        -- (#eq? @aa "foo")
        str = predicate[3]
      else
        -- (#eq? @aa @bb)
        str = M.get_node_text(match[predicate[3]], source)
      end

      if node_text ~= str or str == nil then
        return false
      end

      return true
  end,

  ["lua-match?"] = function(match, _, source, predicate)
      local node = match[predicate[2]]
      local regex = predicate[3]
      local start_row, _, end_row, _ = node:range()
      if start_row ~= end_row then
        return false
      end

      return string.find(M.get_node_text(node, source), regex)
  end,

  ["match?"] = (function()
    local magic_prefixes = {['\\v']=true, ['\\m']=true, ['\\M']=true, ['\\V']=true}
    local function check_magic(str)
      if string.len(str) < 2 or magic_prefixes[string.sub(str,1,2)] then
        return str
      end
      return '\\v'..str
    end

    local compiled_vim_regexes = setmetatable({}, {
      __index = function(t, pattern)
        local res = vim.regex(check_magic(vim.fn.escape(pattern, '\\')))
        rawset(t, pattern, res)
        return res
      end
    })

    return function(match, _, source, pred)
      local node = match[pred[2]]
      local start_row, start_col, end_row, end_col = node:range()
      if start_row ~= end_row then
        return false
      end

      local regex = compiled_vim_regexes[pred[3]]
      return regex:match_line(source, start_row, start_col, end_col)
    end
  end)(),

  ["contains?"] = function(match, _, source, predicate)
    local node = match[predicate[2]]
    local node_text = M.get_node_text(node, source)

    for i=3,#predicate do
      if string.find(node_text, predicate[i], 1, true) then
        return true
      end
    end

    return false
  end
}

-- As we provide lua-match? also expose vim-match?
predicate_handlers["vim-match?"] = predicate_handlers["match?"]


-- Directives store metadata or perform side effects against a match.
-- Directives should always end with a `!`.
-- Directive handler receive the following arguments
-- (match, pattern, bufnr, predicate, metadata)
local directive_handlers = {
  ["set!"] = function(_, _, _, pred, metadata)
    if #pred == 4 then
      -- (#set! @capture "key" "value")
      metadata[pred[2]][pred[3]] = pred[4]
    else
      -- (#set! "key" "value")
      metadata[pred[2]] = pred[3]
    end
  end,
  -- Shifts the range of a node.
  -- Example: (#offset! @_node 0 1 0 -1)
  ["offset!"] = function(match, _, _, pred, metadata)
    local offset_node = match[pred[2]]
    local range = {offset_node:range()}
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
      metadata.content = {range}
    end
  end
}

--- Adds a new predicate to be used in queries
--
-- @param name the name of the predicate, without leading #
-- @param handler the handler function to be used
--    signature will be (match, pattern, bufnr, predicate)
function M.add_predicate(name, handler, force)
  if predicate_handlers[name] and not force then
    error(string.format("Overriding %s", name))
  end

  predicate_handlers[name] = handler
end

--- Adds a new directive to be used in queries
--
-- @param name the name of the directive, without leading #
-- @param handler the handler function to be used
--    signature will be (match, pattern, bufnr, predicate)
function M.add_directive(name, handler, force)
  if directive_handlers[name] and not force then
    error(string.format("Overriding %s", name))
  end

  directive_handlers[name] = handler
end

--- Returns the list of currently supported predicates
function M.list_predicates()
  return vim.tbl_keys(predicate_handlers)
end

local function xor(x, y)
  return (x or y) and not (x and y)
end

local function is_directive(name)
  return string.sub(name, -1) == "!"
end

function Query:match_preds(match, pattern, source)
  local preds = self.info.patterns[pattern]

  for _, pred in pairs(preds or {}) do
    -- Here we only want to return if a predicate DOES NOT match, and
    -- continue on the other case. This way unknown predicates will not be considered,
    -- which allows some testing and easier user extensibility (#12173).
    -- Also, tree-sitter strips the leading # from predicates for us.
    local pred_name
    local is_not

    -- Skip over directives... they will get processed after all the predicates.
    if not is_directive(pred[1]) then
      if string.sub(pred[1], 1, 4) == "not-" then
        pred_name = string.sub(pred[1], 5)
        is_not = true
      else
        pred_name = pred[1]
        is_not = false
      end

      local handler = predicate_handlers[pred_name]

      if not handler then
        error(string.format("No handler for %s", pred[1]))
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

--- Applies directives against a match and pattern.
function Query:apply_directives(match, pattern, source, metadata)
  local preds = self.info.patterns[pattern]

  for _, pred in pairs(preds or {}) do
    if is_directive(pred[1]) then
      local handler = directive_handlers[pred[1]]

      if not handler then
        error(string.format("No handler for %s", pred[1]))
        return
      end

      handler(match, pattern, source, pred, metadata)
    end
  end
end


--- Returns the start and stop value if set else the node's range.
-- When the node's range is used, the stop is incremented by 1
-- to make the search inclusive.
local function value_or_node_range(start, stop, node)
  if start == nil and stop == nil then
    local node_start, _, node_stop, _ = node:range()
    return node_start, node_stop + 1 -- Make stop inclusive
  end

  return start, stop
end

--- Iterates of the captures of self on a given range.
--
-- @param node The node under which the search will occur
-- @param buffer The source buffer to search
-- @param start The starting line of the search
-- @param stop The stopping line of the search (end-exclusive)
--
-- @returns The matching capture id
-- @returns The captured node
function Query:iter_captures(node, source, start, stop)
  if type(source) == "number" and source == 0 then
    source = vim.api.nvim_get_current_buf()
  end

  start, stop = value_or_node_range(start, stop, node)

  local raw_iter = node:_rawquery(self.query, true, start, stop)
  local function iter()
    local capture, captured_node, match = raw_iter()
    local metadata = {}

    if match ~= nil then
      local active = self:match_preds(match, match.pattern, source)
      match.active = active
      if not active then
        return iter() -- tail call: try next match
      end

      self:apply_directives(match, match.pattern, source, metadata)
    end
    return capture, captured_node, metadata
  end
  return iter
end

--- Iterates the matches of self on a given range.
--
-- @param node The node under which the search will occur
-- @param buffer The source buffer to search
-- @param start The starting line of the search
-- @param stop The stopping line of the search (end-exclusive)
--
-- @returns The matching pattern id
-- @returns The matching match
function Query:iter_matches(node, source, start, stop)
  if type(source) == "number" and source == 0 then
    source = vim.api.nvim_get_current_buf()
  end

  start, stop = value_or_node_range(start, stop, node)

  local raw_iter = node:_rawquery(self.query, false, start, stop)
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
    return pattern, match, metadata
  end
  return iter
end

return M
