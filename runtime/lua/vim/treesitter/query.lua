local a = vim.api
local lang = require'vim.treesitter.language'

-- query: pattern matching on trees
-- predicate matching is implemented in lua
local Query = {}
Query.__index = Query

local M = {}

local magic_prefixes = {['\\v']=true, ['\\m']=true, ['\\M']=true, ['\\V']=true}
local function check_magic(str)
  if string.len(str) < 2 or magic_prefixes[string.sub(str, 1, 2)] then
    return str
  end
  return '\\v'..str
end

-- Some treesitter grammars extend others.
-- We can use that to import the queries of the base language
local base_language_map = {
  cpp = {'c'},
  typescript = {'javascript'},
  tsx = {'typescript', 'javascript'},
}

--- Register a language as using base_language as it's base.
--
-- @param language The language
-- @param base_langue The language of which the queries will be used as a base.
function M.base_language_add(language, base_language)
  if not base_language_map[language] then
    base_language_map[language] = {}
  end

  table.insert(base_language_map[language], base_language)
end

--- Returns the base languages of a given language
--
-- @param language The language
--
-- @returns A table containing the languages @param language uses as it's base.
function M.base_language_get(language)
  return base_language_map[language] or {}
end

--- Parses a query.
--
-- @param language The language
-- @param query A string containing the query (s-expr syntax)
--
-- @returns The query
function M.parse_query(language, query)
  lang.require_language(language)
  local self = setmetatable({}, Query)
  self.query = vim._ts_parse_query(language, vim.fn.escape(query,'\\'))
  self.info = self.query:inspect()
  self.captures = self.info.captures
  self.regexes = {}
  for id, preds in pairs(self.info.patterns) do
    local regexes = {}
    for i, pred in ipairs(preds) do
      if (pred[1] == "match?" and type(pred[2]) == "number"
          and type(pred[3]) == "string") then
        regexes[i] = vim.regex(check_magic(pred[3]))
      end
    end
    if not vim.tbl_isempty(regexes) then
      self.regexes[id] = regexes
    end
  end
  return self
end

local function read_query_file(filename)
  local contents = {}

  vim.list_extend(contents, vim.fn.readfile(filename))

  return table.concat(contents, '\n')
end

--- Gets a fully fledged query from runtime files
--
-- @param lang The source language
-- @param query_name The name of the query (without `.scm`)
--
-- @returns The query
function M.get_query(language, query_name)
  local query_string = ''
  if vim.fn.filereadable(query_name) == 1 then
    query_string = read_query_file(query_name)
  else
    local query_files = a.nvim_get_runtime_file(string.format('queries/%s/%s.scm', language, query_name), false)
    -- First read the files defined for this exact language
    if #query_files > 0 then
      query_string = read_query_file(query_files[#query_files]) .. "\n" .. query_string
    end

    -- Prepend the base language queries this allows to extend the C query to match C++ use case.
    for _, base_lang in ipairs(M.base_language_get(language)) do
      local base_files = a.nvim_get_runtime_file(string.format('queries/%s/%s.scm', base_lang, query_name), false)
      if base_files and #base_files > 0 then
          query_string = read_query_file(base_files[#base_files]) .. "\n" .. query_string
      end
    end
  end

  -- Finaly parse the query
  if #query_string > 0 then
    return M.parse_query(language, query_string)
  end
end

-- TODO(vigoux): support multiline nodes too
local function get_node_text(node, bufnr)
  local start_row, start_col, end_row, end_col = node:range()
  if start_row ~= end_row then
    return nil
  end
  local line = a.nvim_buf_get_lines(bufnr, start_row, start_row+1, true)[1]
  return string.sub(line, start_col+1, end_col)
end

-- Predicate handler receive the following arguments
-- (match, pattern, bufnr, regexes, index, predicate)
local predicate_handlers = {
  ["eq?"] = function(match, _, bufnr, _, _, predicate)
      local node = match[predicate[2]]
      local node_text = get_node_text(node, bufnr)

      local str
      if type(predicate[3]) == "string" then
        -- (#eq? @aa "foo")
        str = predicate[3]
      else
        -- (#eq? @aa @bb)
        str = get_node_text(match[predicate[3]], bufnr)
      end

      if node_text ~= str or str == nil then
        return false
      end

      return true
  end,
  ["match?"] = function(match, _, bufnr, regexes, index, predicate)
      if not regexes or not regexes[index] then
        return false
      end
      local node = match[predicate[2]]
      local start_row, start_col, end_row, end_col = node:range()
      if start_row ~= end_row then
        return false
      end
      if not regexes[index]:match_line(bufnr, start_row, start_col, end_col) then
        return false
      end

      return true
  end,
}

function M.add_predicate(name, handler)
  predicate_handlers[name] = handler
end

function Query:match_preds(match, pattern, bufnr)
  local preds = self.info.patterns[pattern]
  if not preds then
    return true
  end
  local regexes = self.regexes[pattern]
  for i, pred in pairs(preds) do
    -- Here we only want to return if a predicate DOES NOT match, and
    -- continue on the other case. This way unknown predicates will not be considered,
    -- which allows some testing and easier user extensibility (#12173).
    -- Also, tree-sitter strips the leading # from predicates for us.
    if predicate_handlers[pred[1]] and
      not predicate_handlers[pred[1]](match, pattern, bufnr, regexes, i, pred) then
      return false
    end
  end
  return true
end

--- Iterates of the captures of self on a given range.
--
-- @param node The node under witch the search will occur
-- @param buffer The source buffer to search
-- @param start The starting line of the search
-- @param stop The stoping line of the search (end-exclusive)
--
-- @returns The matching capture id
-- @returns The captured node
function Query:iter_captures(node, bufnr, start, stop)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local raw_iter = node:_rawquery(self.query, true, start, stop)
  local function iter()
    local capture, captured_node, match = raw_iter()
    if match ~= nil then
      local active = self:match_preds(match, match.pattern, bufnr)
      match.active = active
      if not active then
        return iter() -- tail call: try next match
      end
    end
    return capture, captured_node
  end
  return iter
end

--- Iterates of the matches of self on a given range.
--
-- @param node The node under witch the search will occur
-- @param buffer The source buffer to search
-- @param start The starting line of the search
-- @param stop The stoping line of the search (end-exclusive)
--
-- @returns The matching pattern id
-- @returns The matching match
function Query:iter_matches(node, bufnr, start, stop)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local raw_iter = node:_rawquery(self.query, false, start, stop)
  local function iter()
    local pattern, match = raw_iter()
    if match ~= nil then
      local active = self:match_preds(match, pattern, bufnr)
      if not active then
        return iter() -- tail call: try next match
      end
    end
    return pattern, match
  end
  return iter
end

return M
