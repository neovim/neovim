local a = vim.api
local query = require'vim.treesitter.query'
local language = require'vim.treesitter.language'

-- TODO(bfredl): currently we retain parsers for the lifetime of the buffer.
-- Consider use weak references to release parser if all plugins are done with
-- it.
local parsers = {}

local Parser = {}
Parser.__index = Parser

--- Parses the buffer if needed and returns a tree.
--
-- Calling this will call the on_changedtree callbacks if the tree has changed.
--
-- @returns An up to date tree
-- @returns If the tree changed with this call, the changed ranges
function Parser:parse()
  if self.valid then
    return self._tree_immutable
  end
  local changes

  self._tree, changes = self._parser:parse(self._tree, self:input_source())

  self._tree_immutable = self._tree:copy()

  self.valid = true

  if not vim.tbl_isempty(changes) then
    for _, cb in ipairs(self.changedtree_cbs) do
      cb(changes)
    end
  end

  return self._tree_immutable, changes
end

function Parser:input_source()
  return self.bufnr or self.str
end

function Parser:_on_bytes(bufnr, changed_tick,
                          start_row, start_col, start_byte,
                          old_row, old_col, old_byte,
                          new_row, new_col, new_byte)
  local old_end_col = old_col + ((old_row == 0) and start_col or 0)
  local new_end_col = new_col + ((new_row == 0) and start_col or 0)
  self._tree:edit(start_byte,start_byte+old_byte,start_byte+new_byte,
                    start_row, start_col,
                    start_row+old_row, old_end_col,
                    start_row+new_row, new_end_col)
  self.valid = false

  for _, cb in ipairs(self.bytes_cbs) do
    cb(bufnr, changed_tick,
      start_row, start_col, start_byte,
      old_row, old_col, old_byte,
      new_row, new_col, new_byte)
  end
end

--- Registers callbacks for the parser
-- @param cbs An `nvim_buf_attach`-like table argument with the following keys :
--  `on_bytes` : see `nvim_buf_attach`, but this will be called _after_ the parsers callback.
--  `on_changedtree` : a callback that will be called everytime the tree has syntactical changes.
--      it will only be passed one argument, that is a table of the ranges (as node ranges) that
--      changed.
function Parser:register_cbs(cbs)
  if not cbs then return end

  if cbs.on_changedtree then
    table.insert(self.changedtree_cbs, cbs.on_changedtree)
  end

  if cbs.on_bytes then
    table.insert(self.bytes_cbs, cbs.on_bytes)
  end
end

--- Sets the included ranges for the current parser
--
-- @param ranges A table of nodes that will be used as the ranges the parser should include.
function Parser:set_included_ranges(ranges)
  self._parser:set_included_ranges(ranges)
  -- The buffer will need to be parsed again later
  self.valid = false
end

--- Gets the included ranges for the parsers
function Parser:included_ranges()
  return self._parser:included_ranges()
end

local M = vim.tbl_extend("error", query, language)

setmetatable(M, {
  __index = function (t, k)
      if k == "TSHighlighter" then
        a.nvim_err_writeln("vim.TSHighlighter is deprecated, please use vim.treesitter.highlighter")
        t[k] = require'vim.treesitter.highlighter'
        return t[k]
      elseif k == "highlighter" then
        t[k] = require'vim.treesitter.highlighter'
        return t[k]
      end
   end
 })

--- Creates a new parser.
--
-- It is not recommended to use this, use vim.treesitter.get_parser() instead.
--
-- @param bufnr The buffer the parser will be tied to
-- @param lang The language of the parser.
-- @param id The id the parser will have
function M._create_parser(bufnr, lang, id)
  language.require_language(lang)
  if bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end

  vim.fn.bufload(bufnr)

  local self = setmetatable({bufnr=bufnr, lang=lang, valid=false}, Parser)
  self._parser = vim._create_ts_parser(lang)
  self.changedtree_cbs = {}
  self.bytes_cbs = {}
  self:parse()
    -- TODO(bfredl): use weakref to self, so that the parser is free'd is no plugin is
    -- using it.
  local function bytes_cb(_, ...)
    return self:_on_bytes(...)
  end
  local detach_cb = nil
  if id ~= nil then
    detach_cb = function()
      if parsers[id] == self then
        parsers[id] = nil
      end
    end
  end
  a.nvim_buf_attach(self.bufnr, false, {on_bytes=bytes_cb, on_detach=detach_cb})
  return self
end

--- Gets the parser for this bufnr / ft combination.
--
-- If needed this will create the parser.
-- Unconditionnally attach the provided callback
--
-- @param bufnr The buffer the parser should be tied to
-- @param ft The filetype of this parser
-- @param buf_attach_cbs See Parser:register_cbs
--
-- @returns The parser
function M.get_parser(bufnr, lang, buf_attach_cbs)
  if bufnr == nil or bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end
  if lang == nil then
    lang = a.nvim_buf_get_option(bufnr, "filetype")
  end
  local id = tostring(bufnr)..'_'..lang

  if parsers[id] == nil then
    parsers[id] = M._create_parser(bufnr, lang, id)
  end

  parsers[id]:register_cbs(buf_attach_cbs)

  return parsers[id]
end

function M.get_string_parser(str, lang)
  vim.validate {
    str = { str, 'string' },
    lang = { lang, 'string' }
  }
  language.require_language(lang)

  local self = setmetatable({str=str, lang=lang, valid=false}, Parser)
  self._parser = vim._create_ts_parser(lang)
  self:parse()

  return self
end

return M
