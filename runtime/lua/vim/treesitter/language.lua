local api = vim.api

local M = {}

---@type table<string,string>
local ft_to_lang = {
  help = 'vimdoc',
}

--- Returns the filetypes for which a parser named {lang} is used.
---
--- The list includes {lang} itself plus all filetypes registered via
--- |vim.treesitter.language.register()|.
---
--- @param lang string Name of parser
--- @return string[] filetypes
function M.get_filetypes(lang)
  local r = { lang } ---@type string[]
  for ft, p in pairs(ft_to_lang) do
    if p == lang then
      r[#r + 1] = ft
    end
  end
  return r
end

--- Returns the language name to be used when loading a parser for {filetype}.
---
--- If no language has been explicitly registered via |vim.treesitter.language.register()|,
--- default to {filetype}. For composite filetypes like `html.glimmer`, only the main filetype is
--- returned.
---
--- @param filetype string
--- @return string|nil
function M.get_lang(filetype)
  if filetype == '' then
    return
  end
  if ft_to_lang[filetype] then
    return ft_to_lang[filetype]
  end
  -- for subfiletypes like html.glimmer use only "main" filetype
  filetype = vim.split(filetype, '.', { plain = true })[1]
  return ft_to_lang[filetype] or filetype
end

---@deprecated
function M.require_language(lang, path, silent, symbol_name)
  vim.deprecate(
    'vim.treesitter.language.require_language()',
    'vim.treesitter.language.add()',
    '0.12'
  )
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

---@class vim.treesitter.language.add.Opts
---@inlinedoc
---
---Optional path the parser is located at
---@field path? string
---
---Internal symbol name for the language to load
---@field symbol_name? string

--- Load parser with name {lang}
---
--- Parsers are searched in the `parser` runtime directory, or the provided {path}
---
---@param lang string Name of the parser (alphanumerical and `_` only)
---@param opts? vim.treesitter.language.add.Opts Options:
function M.add(lang, opts)
  opts = opts or {}
  local path = opts.path
  local symbol_name = opts.symbol_name

  vim.validate({
    lang = { lang, 'string' },
    path = { path, 'string', true },
    symbol_name = { symbol_name, 'string', true },
  })

  -- parser names are assumed to be lowercase (consistent behavior on case-insensitive file systems)
  lang = lang:lower()

  if vim._ts_has_language(lang) then
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

  if vim.endswith(path, '.wasm') then
    if not vim._ts_add_language_from_wasm then
      error(string.format("Unable to load wasm parser '%s': not built with ENABLE_WASMTIME ", path))
    end
    vim._ts_add_language_from_wasm(path, lang)
  else
    vim._ts_add_language_from_object(path, lang, symbol_name)
  end
end

--- @param x string|string[]
--- @return string[]
local function ensure_list(x)
  if type(x) == 'table' then
    return x
  end
  return { x }
end

--- Register a parser named {lang} to be used for {filetype}(s).
---
--- Note: this adds or overrides the mapping for {filetype}, any existing mappings from other
--- filetypes to {lang} will be preserved.
---
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

return M
