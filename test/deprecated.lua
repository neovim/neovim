-- Island of Misfit Toys

local M = {}

function M.redir_exec()
  error('redir_exec is deprecated, use nvim_exec() or helpers.exec_capture()')
end

return M
