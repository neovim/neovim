local n = require('test.functional.testnvim')()

local exec_lua = n.exec_lua

local M = {}

---@param language string
---@param query_string string
function M.run_query(language, query_string)
  return exec_lua(function(lang, query_str)
    local query = vim.treesitter.query.parse(lang, query_str)
    local parser = vim.treesitter.get_parser()
    local tree = parser:parse()[1]
    local res = {}
    for id, node, metadata in query:iter_captures(tree:root(), 0) do
      table.insert(
        res,
        { query.captures[id], metadata[id] and metadata[id].range or { node:range() } }
      )
    end
    return res
  end, language, query_string)
end

return M
