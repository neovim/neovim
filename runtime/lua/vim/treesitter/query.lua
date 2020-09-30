local a = vim.api
local language = require'vim.treesitter.language'

-- query: pattern matching on trees
-- predicate matching is implemented in lua
local Query = {}
Query.__index = Query

local M = {}

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
-- @param bufnr the buffer from which the node in extracted.
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

--- Adds a new predicates to be used in queries
--
-- @param name the name of the predicate, without leading #
-- @param handler the handler function to be used
--    signature will be (match, pattern, bufnr, predicate)
function M.add_predicate(name, handler, force)
  if predicate_handlers[name] and not force then
    a.nvim_err_writeln(string.format("Overriding %s", name))
  end

  predicate_handlers[name] = handler
end

--- Returns the list of currently supported predicates
function M.list_predicates()
  return vim.tbl_keys(predicate_handlers)
end

local function xor(x, y)
  return (x or y) and not (x and y)
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
    if string.sub(pred[1], 1, 4) == "not-" then
      pred_name = string.sub(pred[1], 5)
      is_not = true
    else
      pred_name = pred[1]
      is_not = false
    end

    local handler = predicate_handlers[pred_name]

    if not handler then
      a.nvim_err_writeln(string.format("No handler for %s", pred[1]))
      return false
    end

    local pred_matches = handler(match, pattern, source, pred)

    if not xor(is_not, pred_matches) then
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
function Query:iter_captures(node, source, start, stop)
  if type(source) == "number" and source == 0 then
    source = vim.api.nvim_get_current_buf()
  end
  local raw_iter = node:_rawquery(self.query, true, start, stop)
  local function iter()
    local capture, captured_node, match = raw_iter()
    if match ~= nil then
      local active = self:match_preds(match, match.pattern, source)
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
function Query:iter_matches(node, source, start, stop)
  if type(source) == "number" and source == 0 then
    source = vim.api.nvim_get_current_buf()
  end
  local raw_iter = node:_rawquery(self.query, false, start, stop)
  local function iter()
    local pattern, match = raw_iter()
    if match ~= nil then
      local active = self:match_preds(match, pattern, source)
      if not active then
        return iter() -- tail call: try next match
      end
    end
    return pattern, match
  end
  return iter
end

return M
