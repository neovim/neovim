local a = vim.api
local query = require'vim.treesitter.query'
local language = require'vim.treesitter.language'
local LanguageTree = require'vim.treesitter.languagetree'

-- TODO(bfredl): currently we retain parsers for the lifetime of the buffer.
-- Consider use weak references to release parser if all plugins are done with
-- it.
local parsers = {}

local M = vim.tbl_extend("error", query, language)

M.language_version = vim._ts_get_language_version()

setmetatable(M, {
  __index = function (t, k)
      if k == "highlighter" then
        t[k] = require'vim.treesitter.highlighter'
        return t[k]
      elseif k == "language" then
        t[k] = require"vim.treesitter.language"
        return t[k]
      elseif k == "query" then
        t[k] = require"vim.treesitter.query"
        return t[k]
      end
   end
 })

--- Creates a new parser.
---
--- It is not recommended to use this, use vim.treesitter.get_parser() instead.
---
---@param bufnr The buffer the parser will be tied to
---@param lang The language of the parser
---@param opts Options to pass to the created language tree
function M._create_parser(bufnr, lang, opts)
  language.require_language(lang)
  if bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end

  vim.fn.bufload(bufnr)

  local self = LanguageTree.new(bufnr, lang, opts)

  ---@private
  local function bytes_cb(_, ...)
    self:_on_bytes(...)
  end

  ---@private
  local function detach_cb(_, ...)
    if parsers[bufnr] == self then
      parsers[bufnr] = nil
    end
    self:_on_detach(...)
  end

  ---@private
  local function reload_cb(_, ...)
    self:_on_reload(...)
  end

  a.nvim_buf_attach(self:source(), false, {on_bytes=bytes_cb, on_detach=detach_cb, on_reload=reload_cb, preview=true})

  self:parse()

  return self
end

--- Gets the parser for this bufnr / ft combination.
---
--- If needed this will create the parser.
--- Unconditionnally attach the provided callback
---
---@param bufnr The buffer the parser should be tied to
---@param lang The filetype of this parser
---@param opts Options object to pass to the created language tree
---
---@returns The parser
function M.get_parser(bufnr, lang, opts)
  opts = opts or {}

  if bufnr == nil or bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end
  if lang == nil then
    lang = a.nvim_buf_get_option(bufnr, "filetype")
  end

  if parsers[bufnr] == nil then
    parsers[bufnr] = M._create_parser(bufnr, lang, opts)
  end

  parsers[bufnr]:register_cbs(opts.buf_attach_cbs)

  return parsers[bufnr]
end

--- Gets a string parser
---
---@param str The string to parse
---@param lang The language of this string
---@param opts Options to pass to the created language tree
function M.get_string_parser(str, lang, opts)
  vim.validate {
    str = { str, 'string' },
    lang = { lang, 'string' }
  }
  language.require_language(lang)

  return LanguageTree.new(str, lang, opts)
end

return M
