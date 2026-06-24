if vim.g.loaded_matchparen ~= nil then
  return
end

require('nvim.matchparen').enable()
