local M = {}

--- Performs a healthcheck for LSP
function M.check()
  local report_info = vim.health.report_info
  local report_warn = vim.health.report_warn

  local log = require('vim.lsp.log')
  local current_log_level = log.get_level()
  local log_level_string = log.levels[current_log_level]
  report_info(string.format('LSP log level : %s', log_level_string))

  if current_log_level < log.levels.WARN then
    report_warn(
      string.format(
        'Log level %s will cause degraded performance and high disk usage',
        log_level_string
      )
    )
  end

  local log_path = vim.lsp.get_log_path()
  report_info(string.format('Log path: %s', log_path))

  local log_file = vim.loop.fs_stat(log_path)
  local log_size = log_file and log_file.size or 0

  local report_fn = (log_size / 1000000 > 100 and report_warn or report_info)
  report_fn(string.format('Log size: %d KB', log_size / 1000))

  local clients = vim.lsp.get_active_clients()
  vim.health.report_start('vim.lsp: Active Clients')
  if next(clients) then
    for _, client in pairs(clients) do
      report_info(
        string.format('%s (id=%s, root_dir=%s)', client.name, client.id, client.config.root_dir)
      )
    end
  else
    report_info('No active clients')
  end
end

return M
