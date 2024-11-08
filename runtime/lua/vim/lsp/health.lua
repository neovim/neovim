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
      local cmd ---@type string
      if type(client.config.cmd) == 'table' then
        cmd = table.concat(client.config.cmd --[[@as table]], ' ')
      elseif type(client.config.cmd) == 'function' then
        cmd = tostring(client.config.cmd)
      end
      local dirs_info ---@type string
      if client.workspace_folders and #client.workspace_folders > 1 then
        dirs_info = string.format(
          '  Workspace folders:\n    %s',
          vim
            .iter(client.workspace_folders)
            ---@param folder lsp.WorkspaceFolder
            :map(function(folder)
              return folder.name
            end)
            :join('\n    ')
        )
      else
        dirs_info = string.format(
          '  Root directory: %s',
          client.root_dir and vim.fn.fnamemodify(client.root_dir, ':~')
        ) or nil
      end
      report_info(table.concat({
        string.format('%s (id: %d)', client.name, client.id),
        dirs_info,
        string.format('  Command: %s', cmd),
        string.format('  Settings: %s', vim.inspect(client.settings, { newline = '\n  ' })),
        string.format(
          '  Attached buffers: %s',
          vim.iter(pairs(client.attached_buffers)):map(tostring):join(', ')
        ),
      }, '\n'))
    end
  else
    report_info('No active clients')
  end
end

local function check_watcher()
  vim.health.start('vim.lsp: File Watcher')

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
  elseif watchfunc == vim._watch.inotifywait then
    watchfunc_name = 'inotifywait'
  else
    local nm = debug.getinfo(watchfunc, 'S').source
    watchfunc_name = string.format('Custom (%s)', nm)
  end

  report_info('File watch backend: ' .. watchfunc_name)
  if watchfunc_name == 'libuv-watchdirs' then
    report_warn('libuv-watchdirs has known performance issues. Consider installing inotify-tools.')
  end
end

local function check_position_encodings()
  vim.health.start('vim.lsp: Position Encodings')
  local clients = vim.lsp.get_clients()
  if next(clients) then
    local position_encodings = {} ---@type table<integer, table<string, integer[]>>
    for _, client in pairs(clients) do
      for bufnr in pairs(client.attached_buffers) do
        if not position_encodings[bufnr] then
          position_encodings[bufnr] = {}
        end
        if not position_encodings[bufnr][client.offset_encoding] then
          position_encodings[bufnr][client.offset_encoding] = {}
        end
        table.insert(position_encodings[bufnr][client.offset_encoding], client.id)
      end
    end

    -- Check if any buffers are attached to multiple clients with different position encodings
    local buffers = {} ---@type integer[]
    for bufnr, encodings in pairs(position_encodings) do
      local list = {} ---@type string[]
      for k in pairs(encodings) do
        list[#list + 1] = k
      end

      if #list > 1 then
        buffers[#buffers + 1] = bufnr
      end
    end

    if #buffers > 0 then
      local lines =
        { 'Found buffers attached to multiple clients with different position encodings.' }
      for _, bufnr in ipairs(buffers) do
        local encodings = position_encodings[bufnr]
        local parts = {}
        for encoding, client_ids in pairs(encodings) do
          table.insert(
            parts,
            string.format('%s (client id(s): %s)', encoding:upper(), table.concat(client_ids, ', '))
          )
        end
        table.insert(lines, string.format('- Buffer %d: %s', bufnr, table.concat(parts, ', ')))
      end
      report_warn(
        table.concat(lines, '\n'),
        'Use the positionEncodings client capability to ensure all clients use the same position encoding'
      )
    else
      report_info('No buffers contain mixed position encodings')
    end
  else
    report_info('No active clients')
  end
end

--- Performs a healthcheck for LSP
function M.check()
  check_log()
  check_active_clients()
  check_watcher()
  check_position_encodings()
end

return M
