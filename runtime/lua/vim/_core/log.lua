local M = {}

--- Checks that the logfile is accessible.
function M.check_log_file()
  if vim.fn.mode() == 'c' then -- Ex mode
    return
  end

  local wanted = vim.fn.getenv('__NVIM_LOG_FILE_WANT')
  if not wanted or wanted == vim.NIL then
    return
  end

  local actual = vim.fn.getenv('NVIM_LOG_FILE')

  local msg --[[@type string]]
  if not actual or actual == vim.NIL or actual == '' then
    msg = ('log: %q not accessible, logging disabled (stderr)'):format(wanted)
  elseif actual ~= wanted then
    msg = ('log: %q not accessible, logging to: %q'):format(wanted, actual)
  else
    return
  end

  vim.defer_fn(function()
    vim.notify(msg, vim.log.levels.WARN)
  end, 100)
end

return M
