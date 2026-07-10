-- matchit: Extended "%" matching

-- Allow user to prevent loading and prevent duplicate loading.
if vim.g.loaded_matchit ~= nil then
  return
end

require('nvim.matchit').enable()
