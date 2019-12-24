local a = vim.api

-- TODO(bfredl): currently we retain parsers for the lifetime of the buffer.
-- Consider use weak references to release parser if all plugins are done with
-- it.
local parsers = {}

local Parser = {}
Parser.__index = Parser

function Parser:parse()
  if self.valid then
    return self.tree
  end
  local changes
  self.tree, changes = self._parser:parse_buf(self.bufnr)
  self.valid = true
  for _, cb in ipairs(self.change_cbs) do
    cb(changes)
  end
  return self.tree, changes
end

function Parser:_on_lines(bufnr, _, start_row, old_stop_row, stop_row, old_byte_size)
  local start_byte = a.nvim_buf_get_offset(bufnr,start_row)
  local stop_byte = a.nvim_buf_get_offset(bufnr,stop_row)
  local old_stop_byte = start_byte + old_byte_size
  self._parser:edit(start_byte,old_stop_byte,stop_byte,
                    start_row,0,old_stop_row,0,stop_row,0)
  self.valid = false
end

local M = {
  add_language=vim._ts_add_language,
  inspect_language=vim._ts_inspect_language,
  parse_query = vim._ts_parse_query,
}

setmetatable(M, {
  __index = function (t, k)
      if k == "TSHighlighter" then
        t[k] = require'vim.tshighlighter'
        return t[k]
      end
   end
 })

function M.create_parser(bufnr, ft, id)
  if bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end
  local self = setmetatable({bufnr=bufnr, lang=ft, valid=false}, Parser)
  self._parser = vim._create_ts_parser(ft)
  self.change_cbs = {}
  self:parse()
    -- TODO(bfredl): use weakref to self, so that the parser is free'd is no plugin is
    -- using it.
  local function lines_cb(_, ...)
    return self:_on_lines(...)
  end
  local detach_cb = nil
  if id ~= nil then
    detach_cb = function()
      if parsers[id] == self then
        parsers[id] = nil
      end
    end
  end
  a.nvim_buf_attach(self.bufnr, false, {on_lines=lines_cb, on_detach=detach_cb})
  return self
end

function M.get_parser(bufnr, ft, cb)
  if bufnr == nil or bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end
  if ft == nil then
    ft = a.nvim_buf_get_option(bufnr, "filetype")
  end
  local id = tostring(bufnr)..'_'..ft

  if parsers[id] == nil then
    parsers[id] = M.create_parser(bufnr, ft, id)
  end
  if cb ~= nil then
    table.insert(parsers[id].change_cbs, cb)
  end
  return parsers[id]
end

-- query: pattern matching on trees
-- predicate matching is implemented in lua
local Query = {}
Query.__index = Query

function M.parse_query(lang, query)
  local self = setmetatable({}, Query)
  self.query = vim._ts_parse_query(lang, query)
  self.info = self.query:inspect()
  self.captures = self.info.captures
  return self
end

local function get_node_text(node, bufnr)
  local start_row, start_col, end_row, end_col = node:range()
  if start_row ~= end_row then
    return nil
  end
  local line = a.nvim_buf_get_lines(bufnr, start_row, start_row+1, true)[1]
  return string.sub(line, start_col+1, end_col)
end

local function match_preds(match, preds, bufnr)
  for _, pred in pairs(preds) do
    if pred[1] == "eq?" then
      local node = match[pred[2]]
      local node_text = get_node_text(node, bufnr)

      local str
      if type(pred[3]) == "string" then
        -- (eq? @aa "foo")
        str = pred[3]
      else
        -- (eq? @aa @bb)
        str = get_node_text(match[pred[3]], bufnr)
      end

      if node_text ~= str or str == nil then
        return false
      end
    else
      return false
    end
  end
  return true
end

function Query:iter_captures(node, bufnr, start, stop)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local raw_iter = node:_rawquery(self.query,true,start,stop)
  local function iter()
    local capture, captured_node, match = raw_iter()
    if match ~= nil then
      local preds = self.info.patterns[match.pattern]
      local active = match_preds(match, preds, bufnr)
      match.active = active
      if not active then
        return iter() -- tail call: try next match
      end
    end
    return capture, captured_node
  end
  return iter
end

function Query:iter_matches(node, bufnr, start, stop)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local raw_iter = node:_rawquery(self.query,false,start,stop)
  local function iter()
    local pattern, match = raw_iter()
    if match ~= nil then
      local preds = self.info.patterns[pattern]
      local active = (not preds) or match_preds(match, preds, bufnr)
      if not active then
        return iter() -- tail call: try next match
      end
    end
    return pattern, match
  end
  return iter
end

return M
