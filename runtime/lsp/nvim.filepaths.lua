local uv = vim.uv
local protocol = vim.lsp.protocol
local errors = protocol.ErrorCodes
local kinds = protocol.CompletionItemKind
local iswin = vim.fn.has('win32') == 1
local batch_size = 200

---@class vim.lsp.filepaths.Settings
---@field base_dir 'cur_buf'|'cwd'
---@field base_dir_overrides table<string, 'cur_buf'|'cwd'>
---@field sort 'dir_first'|'system'
---@field max_items integer

---@param settings? table
---@return vim.lsp.filepaths.Settings
local function get_settings(settings)
  vim.validate('settings', settings, 'table', true)
  local raw = settings and settings.filepaths
  if raw == nil then
    raw = {}
  end
  vim.validate('settings.filepaths', raw, 'table')
  local result = vim.tbl_extend('force', {
    base_dir = 'cur_buf',
    base_dir_overrides = {},
    sort = 'dir_first',
    max_items = 1000,
  }, raw)
  local function strategy(value)
    return value == 'cur_buf' or value == 'cwd'
  end
  for key in pairs(raw) do
    assert(
      key == 'base_dir' or key == 'base_dir_overrides' or key == 'sort' or key == 'max_items',
      'unknown filepaths setting: ' .. tostring(key)
    )
  end
  vim.validate('base_dir', result.base_dir, strategy, "'cur_buf' or 'cwd'")
  vim.validate('base_dir_overrides', result.base_dir_overrides, 'table')
  for ft, value in pairs(result.base_dir_overrides) do
    vim.validate('filetype', ft, 'string')
    vim.validate('base_dir_overrides.' .. ft, value, strategy, "'cur_buf' or 'cwd'")
  end
  vim.validate('sort', result.sort, function(value)
    return value == 'dir_first' or value == 'system'
  end, "'dir_first' or 'system'")
  vim.validate('max_items', result.max_items, function(value)
    return type(value) == 'number' and value >= 1 and value < math.huge and value % 1 == 0
  end, 'positive integer')
  return vim.deepcopy(result) --[[@as vim.lsp.filepaths.Settings]]
end

---@param text string
---@return string? token
---@return integer? start_byte # Zero-based byte offset
local function path_token(text)
  local quote, start = nil, 1
  for i = 1, #text do
    local char = text:sub(i, i)
    if quote then
      if char == quote then
        quote, start = nil, i + 1
      end
    elseif char == '"' or char == "'" then
      quote, start = char, i + 1
    elseif char:byte() < 128 and not char:match('[%w_%.%-%/~$:\\]') then
      start = i + 1
    end
  end
  local token = text:sub(start)
  if token:match('^%a[%w+.-]*://') or not token:find(iswin and '[/\\]' or '/') then
    return
  end
  return token, start - 1
end

---@param params lsp.CompletionParams
---@param settings vim.lsp.filepaths.Settings
---@return table? context
local function completion_context(params, settings)
  local bufnr
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.uri_from_bufnr(buf) == params.textDocument.uri then
      bufnr = buf
      break
    end
  end
  if not bufnr or vim.bo[bufnr].buftype ~= '' then
    return
  end
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name:match('^%a[%w+.-]*://') then
    return
  end
  local pos = params.position
  if pos.line < 0 or pos.character < 0 or pos.line % 1 ~= 0 or pos.character % 1 ~= 0 then
    return
  end
  local line = vim.api.nvim_buf_get_lines(bufnr, pos.line, pos.line + 1, false)[1]
  if not line then
    return
  end
  local col = vim.str_byteindex(line, 'utf-16', pos.character)
  local token, start = path_token(line:sub(1, col))
  if not token then
    return
  end
  local split = assert(token:match(iswin and '^.*()[/\\]' or '^.*()/'))
  local dir, leaf = token:sub(1, split), token:sub(split + 1)
  local cwd = vim.api.nvim_buf_call(bufnr, vim.fn.getcwd)
  local filetype = vim.bo[bufnr].filetype
  local strategy = filetype and settings.base_dir_overrides[filetype] or settings.base_dir
  local base = strategy == 'cur_buf' and name ~= '' and vim.fs.dirname(name) or cwd
  local expanded = dir
  local env, suffix = dir:match(iswin and '^%$([%a_][%w_]*)([/\\].*)$' or '^%$([%a_][%w_]*)(/.*)$')
  if env then
    local value = vim.env[env]
    if not value or value == '' then
      return
    end
    expanded = value .. suffix
  elseif dir:match(iswin and '^~[/\\]' or '^~/') then
    local home = uv.os_homedir()
    if not home then
      return
    end
    expanded = home .. dir:sub(2)
  end
  local scan_dir = vim.fs.abspath(expanded, { cwd = base, plain = true })
  return {
    bufnr = bufnr,
    name = name,
    tick = vim.api.nvim_buf_get_changedtick(bufnr),
    dir = dir,
    leaf = leaf,
    scan_dir = scan_dir,
    range = {
      start = { line = pos.line, character = vim.str_utfindex(line, 'utf-16', start) },
      ['end'] = { line = pos.line, character = pos.character },
    },
  }
end

---@param path string
---@param leaf string
---@param on_batch fun(entries: table[])
---@param callback fun(err?: string)
---@return fun() cancel
local function scan(path, leaf, on_batch, callback)
  local dir, busy, stopped = nil, true, false
  local function close(done)
    if dir and not busy then
      local handle = dir
      dir = nil
      uv.fs_closedir(
        handle,
        vim.schedule_wrap(function()
          if done then
            done()
          end
        end)
      )
    elseif done then
      done()
    end
  end
  local function finish(err)
    stopped = true
    close(function()
      callback(err)
    end)
  end
  local read
  read = function()
    busy = true
    uv.fs_readdir(
      dir,
      vim.schedule_wrap(function(err, entries)
        busy = false
        if stopped then
          close()
          return
        end
        if err or not entries then
          finish(err)
          return
        end
        local batch, index = {}, 0
        local advance
        advance = function()
          if stopped then
            close()
            return
          end
          index = index + 1
          local entry = entries[index]
          if not entry then
            on_batch(batch)
            read()
            return
          end
          if not vim.startswith(entry.name, leaf) then
            advance()
            return
          end
          local function retain(typ, link)
            entry.type, entry.link = typ, link
            batch[#batch + 1] = entry
            advance()
          end
          if entry.type == 'file' or entry.type == 'directory' then
            retain(entry.type, false)
            return
          end
          local abs = vim.fs.joinpath(path, entry.name)
          local function stat(link)
            busy = true
            uv.fs_stat(
              abs,
              vim.schedule_wrap(function(_, info)
                busy = false
                retain(info and info.type or 'file', link)
              end)
            )
          end
          if entry.type == 'link' then
            stat(true)
          else
            busy = true
            uv.fs_lstat(
              abs,
              vim.schedule_wrap(function(_, info)
                busy = false
                if stopped then
                  close()
                elseif info and info.type == 'link' then
                  stat(true)
                else
                  retain(info and info.type or 'file', false)
                end
              end)
            )
          end
        end
        advance()
      end)
    )
  end
  uv.fs_opendir(
    path,
    vim.schedule_wrap(function(err, handle)
      dir, busy = handle, false
      if stopped then
        close()
      elseif err or not dir then
        finish(err)
      else
        read()
      end
    end),
    batch_size
  )
  return function()
    stopped = true
    close()
  end
end

---@param context table
---@param settings vim.lsp.filepaths.Settings
---@param callback fun(err: lsp.ResponseError?, result?: lsp.CompletionList)
---@return fun()
local function complete(context, settings, callback)
  local entries, matches = {}, 0
  local function precedes(a, b)
    if settings.sort == 'dir_first' and (a.type == 'directory') ~= (b.type == 'directory') then
      return a.type == 'directory'
    end
    local al, bl = a.name:lower(), b.name:lower()
    return al == bl and a.name < b.name or al < bl
  end
  return scan(context.scan_dir, context.leaf, function(batch)
    matches = matches + #batch
    vim.list_extend(entries, batch)
    table.sort(entries, precedes)
    for i = #entries, settings.max_items + 1, -1 do
      entries[i] = nil
    end
  end, function(err)
    if
      not vim.api.nvim_buf_is_loaded(context.bufnr)
      or vim.api.nvim_buf_get_changedtick(context.bufnr) ~= context.tick
      or vim.api.nvim_buf_get_name(context.bufnr) ~= context.name
    then
      callback({ code = errors.ContentModified, message = 'Document changed during completion' })
      return
    end
    local items = {}
    if not err then
      for i, entry in ipairs(entries) do
        local folder = entry.type == 'directory'
        local replacement = context.dir .. entry.name
        items[i] = {
          label = entry.name,
          kind = folder and kinds.Folder or kinds.File,
          sortText = string.format('%010d', i),
          filterText = replacement,
          textEdit = { range = context.range, newText = replacement },
        }
      end
    end
    callback(nil, { isIncomplete = not err and matches > settings.max_items, items = items })
  end)
end

---@param dispatchers vim.lsp.rpc.Dispatchers
---@param config vim.lsp.ClientConfig
---@return vim.lsp.rpc.Client
local function cmd(dispatchers, config)
  local settings = get_settings(config.settings)
  local closing, exited, next_id = false, false, 0
  local requests = {}
  local function finish(id, err, result)
    local request = requests[id]
    if not request then
      return
    end
    requests[id] = nil
    if request.reply then
      request.reply(id)
    end
    -- Match the RPC transport: acknowledge cancellation without invoking the handler.
    if not err or err.code ~= errors.RequestCancelled then
      request.callback(err, result, id)
    end
  end
  local function cancel(id)
    local request = requests[id]
    if request then
      if request.cancel then
        request.cancel()
      end
      finish(id, { code = errors.RequestCancelled, message = 'Request cancelled' })
    end
  end
  local function cancel_all(except)
    for id in pairs(requests) do
      if id ~= except then
        cancel(id)
      end
    end
  end
  local function exit(signal)
    if not exited then
      closing, exited = true, true
      cancel_all()
      dispatchers.on_exit(0, signal)
    end
  end
  ---@diagnostic disable-next-line: return-type-mismatch
  return {
    request = function(method, params, callback, reply)
      if closing then
        return false
      end
      next_id = next_id + 1
      local id = next_id
      local request = { callback = callback, reply = reply }
      local snapshot = settings
      requests[id] = request
      vim.schedule(function()
        if not requests[id] then
          return
        end
        if method == 'initialize' then
          finish(id, nil, {
            capabilities = {
              positionEncoding = 'utf-16',
              textDocumentSync = protocol.TextDocumentSyncKind.None,
              completionProvider = { triggerCharacters = iswin and { '/', '\\' } or { '/' } },
            },
            serverInfo = { name = 'nvim.filepaths' },
          })
        elseif method == 'shutdown' then
          closing = true
          cancel_all(id)
          finish(id, nil, nil)
        elseif method == 'textDocument/completion' then
          local ok, context = pcall(completion_context, params, snapshot)
          if not ok then
            finish(id, { code = errors.InvalidParams, message = tostring(context) })
          elseif not context then
            finish(id, nil, { isIncomplete = false, items = {} })
          else
            request.cancel = complete(context, snapshot, function(err, result)
              finish(id, err, result)
            end)
          end
        else
          finish(id, { code = errors.MethodNotFound, message = 'Unsupported method: ' .. method })
        end
      end)
      return true, id
    end,
    notify = function(method, params)
      if method == 'exit' then
        exit(0)
        return true
      elseif closing then
        return false
      elseif method == '$/cancelRequest' then
        cancel(params.id)
      elseif method == 'workspace/didChangeConfiguration' then
        local ok, value = pcall(get_settings, params.settings)
        if not ok then
          vim.notify('nvim.filepaths: ' .. tostring(value), vim.log.levels.WARN)
          return false
        end
        settings = value
      end
      return true
    end,
    is_closing = function()
      return closing
    end,
    terminate = function()
      exit(15)
    end,
  }
end

---@type vim.lsp.Config
return { cmd = cmd, workspace_required = false }
