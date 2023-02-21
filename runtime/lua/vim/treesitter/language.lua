local a = vim.api

local M = {}

---@type table<string,string>
local ft_to_lang = {}

---@param filetype string
---@return string|nil
function M.get_lang(filetype)
  return ft_to_lang[filetype]
end

---@deprecated
function M.require_language(lang, path, silent, symbol_name)
  return M.add(lang, {
    silent = silent,
    path = path,
    symbol_name = symbol_name,
  })
end

---@class treesitter.RequireLangOpts
---@field path? string
---@field silent? boolean
---@field filetype? string|string[]
---@field symbol_name? string

--- Asserts that a parser for the language {lang} is installed.
---
--- Parsers are searched in the `parser` runtime directory, or the provided {path}
---
---@param lang string Language the parser should parse (alphanumerical and `_` only)
---@param opts (table|nil) Options:
---                        - filetype (string|string[]) Filetype(s) that lang can be parsed with.
---                          Note this is not strictly the same as lang since a single lang can
---                          parse multiple filetypes.
---                          Defaults to lang.
---                        - path (string|nil) Optional path the parser is located at
---                        - symbol_name (string|nil) Internal symbol name for the language to load
---                        - silent (boolean|nil) Don't throw an error if language not found
---@return boolean If the specified language is installed
function M.add(lang, opts)
  ---@cast opts treesitter.RequireLangOpts
  opts = opts or {}
  local path = opts.path
  local silent = opts.silent
  local filetype = opts.filetype or lang
  local symbol_name = opts.symbol_name

  vim.validate({
    lang = { lang, 'string' },
    path = { path, 'string', true },
    silent = { silent, 'boolean', true },
    symbol_name = { symbol_name, 'string', true },
    filetype = { filetype, { 'string', 'table' }, true },
  })

  M.register(lang, filetype or lang)

  if vim._ts_has_language(lang) then
    return true
  end

  if path == nil then
    if not (lang and lang:match('[%w_]+') == lang) then
      if silent then
        return false
      end
      error("'" .. lang .. "' is not a valid language name")
    end

    local fname = 'parser/' .. lang .. '.*'
    local paths = a.nvim_get_runtime_file(fname, false)
    if #paths == 0 then
      if silent then
        return false
      end
      error("no parser for '" .. lang .. "' language, see :help treesitter-parsers")
    end
    path = paths[1]
  end

  if silent then
    if not pcall(vim._ts_add_language, path, lang, symbol_name) then
      return false
    end
  else
    vim._ts_add_language(path, lang, symbol_name)
  end

  return true
end

--- Register a lang to be used for a filetype (or list of filetypes).
---@param lang string Language to register
---@param filetype string|string[] Filetype(s) to associate with lang
function M.register(lang, filetype)
  vim.validate({
    lang = { lang, 'string' },
    filetype = { filetype, { 'string', 'table' } },
  })

  local filetypes ---@type string[]
  if type(filetype) == 'string' then
    filetypes = { filetype }
  else
    filetypes = filetype
  end

  for _, f in ipairs(filetypes) do
    ft_to_lang[f] = lang
  end
end

--- Inspects the provided language.
---
--- Inspecting provides some useful information on the language like node names, ...
---
---@param lang string Language
---@return table
function M.inspect_language(lang)
  M.add(lang)
  return vim._ts_inspect_language(lang)
end

return M
