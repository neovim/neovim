return setmetatable({}, {
  __index = function(_, k)
    vim.deprecate("require('health')", 'vim.health', '0.9', false)
    return vim.health[k]
  end,
})
