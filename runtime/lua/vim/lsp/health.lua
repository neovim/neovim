local M = {}

local report_info = vim.health.info
local report_warn = vim.health.warn

local function check_log()
  local log = vim.lsp.log
  local current_log_level = log.get_level()
  local log_level_string = log.levels[current_log_level] ---@type string
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

  local log_file = vim.uv.fs_stat(log_path)
  local log_size = log_file and log_file.size or 0

  local report_fn = (log_size / 1000000 > 100 and report_warn or report_info)
  report_fn(string.format('Log size: %d KB', log_size / 1000))
end

local function check_active_clients()
  vim.health.start('vim.lsp: Active Clients')
  local clients = vim.lsp.get_clients()
  if next(clients) then
    for _, client in pairs(clients) do
      local attached_to = table.concat(vim.tbl_keys(client.attached_buffers or {}), ',')
      report_info(
        string.format(
          '%s (id=%s, root_dir=%s, attached_to=[%s])',
          client.name,
          client.id,
          vim.fn.fnamemodify(client.root_dir, ':~'),
          attached_to
        )
      )
    end
  else
    report_info('No active clients')
  end
end

local function check_watcher()
  vim.health.start('vim.lsp: File watcher')

  -- Only run the check if file watching has been enabled by a client.
  local clients = vim.lsp.get_clients()
  if
    --- @param client vim.lsp.Client
    vim.iter(clients):all(function(client)
      local has_capability = vim.tbl_get(
        client.capabilities,
        'workspace',
        'didChangeWatchedFiles',
        'dynamicRegistration'
      )
      local has_dynamic_capability =
        client.dynamic_capabilities:get(vim.lsp.protocol.Methods.workspace_didChangeWatchedFiles)
      return has_capability == nil
        or has_dynamic_capability == nil
        or client.workspace_folders == nil
    end)
  then
    report_info('file watching "(workspace/didChangeWatchedFiles)" disabled on all clients')
    return
  end

  local watchfunc = vim.lsp._watchfiles._watchfunc
  assert(watchfunc)
  local watchfunc_name --- @type string
  if watchfunc == vim._watch.watch then
    watchfunc_name = 'libuv-watch'
  elseif watchfunc == vim._watch.watchdirs then
    watchfunc_name = 'libuv-watchdirs'
  elseif watchfunc == vim._watch.fswatch then
    watchfunc_name = 'fswatch'
  else
    local nm = debug.getinfo(watchfunc, 'S').source
    watchfunc_name = string.format('Custom (%s)', nm)
  end

  report_info('File watch backend: ' .. watchfunc_name)
  if watchfunc_name == 'libuv-watchdirs' then
    report_warn('libuv-watchdirs has known performance issues. Consider installing fswatch.')
  end
end

--- Performs a healthcheck for LSP
function M.check()
  check_log()
  check_active_clients()
  check_watcher()
end

return M
