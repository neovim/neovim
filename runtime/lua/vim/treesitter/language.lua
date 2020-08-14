local a = vim.api

local M = {}

--- Asserts that the provided language is installed, and optionnaly provide a path for the parser
--
-- Parsers are searched in the `parser` runtime directory.
--
-- @param lang The language the parser should parse
-- @param path Optionnal path the parser is located at
function M.require_language(lang, path)
  if vim._ts_has_language(lang) then
    return true
  end
  if path == nil then
    local fname = 'parser/' .. lang .. '.*'
    local paths = a.nvim_get_runtime_file(fname, false)
    if #paths == 0 then
      -- TODO(bfredl): help tag?
      error("no parser for '"..lang.."' language, see :help treesitter-parsers")
    end
    path = paths[1]
  end
  vim._ts_add_language(path, lang)
end

--- Inspects the provided language.
--
-- Inspecting provides some useful informations on the language like node names, ...
--
-- @param lang The language.
function M.inspect_language(lang)
  M.require_language(lang)
  return vim._ts_inspect_language(lang)
end

return M
