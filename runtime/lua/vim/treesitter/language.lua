local a = vim.api

local M = {}

--- Asserts that the provided language is installed, and optionally provide a path for the parser
---
--- Parsers are searched in the `parser` runtime directory.
---
---@param lang string The language the parser should parse
---@param path string|nil Optional path the parser is located at
---@param silent boolean|nil Don't throw an error if language not found
---@param symbol_name string|nil Internal symbol name for the language to load
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
---@param lang The language.
function M.inspect_language(lang)
  M.require_language(lang)
  return vim._ts_inspect_language(lang)
end

return M
