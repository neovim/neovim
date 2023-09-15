local api = vim.api

---@class TSLanguageModule
local M = {}

---@type table<string,string>
local ft_to_lang = {
  help = 'vimdoc',
}

--- Get the filetypes associated with the parser named {lang}.
--- @param lang string Name of parser
--- @return string[] filetypes
function M.get_filetypes(lang)
  local r = {} ---@type string[]
  for ft, p in pairs(ft_to_lang) do
    if p == lang then
      r[#r + 1] = ft
    end
  end
  return r
end

--- @param filetype string
--- @return string|nil
function M.get_lang(filetype)
  if filetype == '' then
    return
  end
  return ft_to_lang[filetype]
end

---@deprecated
function M.require_language(lang, path, silent, symbol_name)
  local opts = {
    silent = silent,
    path = path,
    symbol_name = symbol_name,
  }

  if silent then
    local installed = pcall(M.add, lang, opts)
    return installed
  end

  M.add(lang, opts)
  return true
end

---@class treesitter.RequireLangOpts
---@field path? string
---@field silent? boolean
---@field filetype? string|string[]
---@field symbol_name? string

--- Load parser with name {lang}
---
--- Parsers are searched in the `parser` runtime directory, or the provided {path}
---
---@param lang string Name of the parser (alphanumerical and `_` only)
---@param opts (table|nil) Options:
---                        - filetype (string|string[]) Default filetype the parser should be associated with.
---                          Defaults to {lang}.
---                        - path (string|nil) Optional path the parser is located at
---                        - symbol_name (string|nil) Internal symbol name for the language to load
function M.add(lang, opts)
  ---@cast opts treesitter.RequireLangOpts
  opts = opts or {}
  local path = opts.path
  local filetype = opts.filetype or lang
  local symbol_name = opts.symbol_name

  vim.validate({
    lang = { lang, 'string' },
    path = { path, 'string', true },
    symbol_name = { symbol_name, 'string', true },
    filetype = { filetype, { 'string', 'table' }, true },
  })

  if vim._ts_has_language(lang) then
    M.register(lang, filetype)
    return
  end

  if path == nil then
    if not (lang and lang:match('[%w_]+') == lang) then
      error("'" .. lang .. "' is not a valid language name")
    end

    local fname = 'parser/' .. lang .. '.*'
    local paths = api.nvim_get_runtime_file(fname, false)
    if #paths == 0 then
      error("no parser for '" .. lang .. "' language, see :help treesitter-parsers")
    end
    path = paths[1]
  end

  vim._ts_add_language(path, lang, symbol_name)
  M.register(lang, filetype)
end

--- @private
--- @param x string|string[]
--- @return string[]
local function ensure_list(x)
  if type(x) == 'table' then
    return x
  end
  return { x }
end

--- Register a parser named {lang} to be used for {filetype}(s).
--- @param lang string Name of parser
--- @param filetype string|string[] Filetype(s) to associate with lang
function M.register(lang, filetype)
  vim.validate({
    lang = { lang, 'string' },
    filetype = { filetype, { 'string', 'table' } },
  })

  for _, f in ipairs(ensure_list(filetype)) do
    if f ~= '' then
      ft_to_lang[f] = lang
    end
  end
end

--- Inspects the provided language.
---
--- Inspecting provides some useful information on the language like node names, ...
---
---@param lang string Language
---@return table
function M.inspect(lang)
  M.add(lang)
  return vim._ts_inspect_language(lang)
end

---@deprecated
function M.inspect_language(...)
  vim.deprecate(
    'vim.treesitter.language.inspect_language()',
    'vim.treesitter.language.inspect()',
    '0.10'
  )
  return M.inspect(...)
end

return M
