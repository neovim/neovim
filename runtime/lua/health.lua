local M = {}

function M.report_start(msg)
  vim.fn['health#report_start'](msg)
end

function M.report_info(msg)
  vim.fn['health#report_info'](msg)
end

function M.report_ok(msg)
  vim.fn['health#report_ok'](msg)
end

function M.report_warn(msg, ...)
  vim.fn['health#report_warn'](msg, ...)
end

function M.report_error(msg, ...)
  vim.fn['health#report_error'](msg, ...)
end

return M
