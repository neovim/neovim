local a = vim.api

local M = {}

--- Asserts that a parser for the language {lang} is installed.
---
--- Parsers are searched in the `parser` runtime directory, or the provided {path}
---
---@param lang string Language the parser should parse
---@param path (string|nil) Optional path the parser is located at
---@param silent (boolean|nil) Don't throw an error if language not found
---@param symbol_name (string|nil) Internal symbol name for the language to load
---@return boolean If the specified language is installed
function M.require_language(lang, path, silent, symbol_name)
  if vim._ts_has_language(lang) then
    return true
  end
  if path == nil then
    local fname = 'parser/' .. vim.fn.fnameescape(lang) .. '.*'
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
    return pcall(function()
      vim._ts_add_language(path, lang, symbol_name)
    end)
  else
    vim._ts_add_language(path, lang, symbol_name)
  end

  return true
end

--- Inspects the provided language.
---
--- Inspecting provides some useful information on the language like node names, ...
---
---@param lang string Language
---@return table
function M.inspect_language(lang)
  M.require_language(lang)
  return vim._ts_inspect_language(lang)
end

return M
