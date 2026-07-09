if vim.g.loaded_matchit ~= nil then
  return
end

require('nvim.matchit').enable()
