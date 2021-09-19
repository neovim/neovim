-- Island of Misfit Toys

local M = {}

function M.redir_exec()
  error('redir_exec is deprecated, use nvim_exec() or pcall_err()')
end

return M
