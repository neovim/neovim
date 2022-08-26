return function (val, res)
  vim.loop.new_async(function() _G[res] = require'leftpad'(val) end):send()
end
