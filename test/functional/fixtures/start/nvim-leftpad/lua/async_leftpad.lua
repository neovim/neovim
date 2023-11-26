return function (val, res)
  local handle
  handle = vim.uv.new_async(function() _G[res] = require'leftpad'(val) handle:close() end)
  handle:send()
end
