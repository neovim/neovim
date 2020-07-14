local a = vim.api
local query = require'vim.treesitter.query'
local lang = require'vim.treesitter.language'

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

  if not vim.tbl_isempty(changes) then
    for _, cb in ipairs(self.changedtree_cbs) do
      cb(changes)
    end
  end

  return self.tree, changes
end

function Parser:_on_lines(bufnr, changed_tick, start_row, old_stop_row, stop_row, old_byte_size)
  local start_byte = a.nvim_buf_get_offset(bufnr,start_row)
  local stop_byte = a.nvim_buf_get_offset(bufnr,stop_row)
  local old_stop_byte = start_byte + old_byte_size
  self._parser:edit(start_byte,old_stop_byte,stop_byte,
                    start_row,0,old_stop_row,0,stop_row,0)
  self.valid = false

  for _, cb in ipairs(self.lines_cbs) do
    cb(bufnr, changed_tick, start_row, old_stop_row, stop_row, old_byte_size)
  end
end

function Parser:set_included_ranges(ranges)
  self._parser:set_included_ranges(ranges)
  -- The buffer will need to be parsed again later
  self.valid = false
end

-- TODO(vigoux): not that great way to do it, but that __index method bothers me...
local M = vim.tbl_extend("error", query, lang)

setmetatable(M, {
  __index = function (t, k)
      if k == "TSHighlighter" then
        t[k] = require'vim.treesitter.highlighter'
        return t[k]
      elseif k == "highlighter" then
        t[k] = require'vim.treesitter.highlighter'
        return t[k]
      end
   end
 })

function M._create_parser(bufnr, language, id)
  lang.require_language(language)
  if bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end

  vim.fn.bufload(bufnr)

  local self = setmetatable({bufnr=bufnr, lang=language, valid=false}, Parser)
  self._parser = vim._create_ts_parser(language)
  self.changedtree_cbs = {}
  self.lines_cbs = {}
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

function M.get_parser(bufnr, ft, buf_attach_cbs)
  if bufnr == nil or bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end
  if ft == nil then
    ft = a.nvim_buf_get_option(bufnr, "filetype")
  end
  local id = tostring(bufnr)..'_'..ft

  if parsers[id] == nil then
    parsers[id] = M._create_parser(bufnr, ft, id)
  end

  if buf_attach_cbs and buf_attach_cbs.on_changedtree then
    table.insert(parsers[id].changedtree_cbs, buf_attach_cbs.on_changedtree)
  end

  if buf_attach_cbs and buf_attach_cbs.on_lines then
    table.insert(parsers[id].lines_cbs, buf_attach_cbs.on_lines)
  end

  return parsers[id]
end

return M
