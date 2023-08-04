local bit = require('bit')
local watch = require('vim._watch')
local protocol = require('vim.lsp.protocol')

local M = {}

---@private
---Parses the raw pattern into a number of Lua-native patterns.
---
---@param pattern string The raw glob pattern
---@return table A list of Lua patterns. A match with any of them matches the input glob pattern.
local function parse(pattern)
  local patterns = { '' }

  local path_sep = '[/\\]'
  local non_path_sep = '[^/\\]'

  local function append(chunks)
    local new_patterns = {}
    for _, p in ipairs(patterns) do
      for _, chunk in ipairs(chunks) do
        table.insert(new_patterns, p .. chunk)
      end
    end
    patterns = new_patterns
  end

  local function split(s, sep)
    local segments = {}
    local segment = ''
    local in_braces = false
    local in_brackets = false
    for i = 1, #s do
      local c = string.sub(s, i, i)
      if c == sep and not in_braces and not in_brackets then
        table.insert(segments, segment)
        segment = ''
      else
        if c == '{' then
          in_braces = true
        elseif c == '}' then
          in_braces = false
        elseif c == '[' then
          in_brackets = true
        elseif c == ']' then
          in_brackets = false
        end
        segment = segment .. c
      end
    end
    if segment ~= '' then
      table.insert(segments, segment)
    end
    return segments
  end

  local function escape(c)
    if
      c == '?'
      or c == '.'
      or c == '('
      or c == ')'
      or c == '%'
      or c == '['
      or c == ']'
      or c == '*'
      or c == '+'
      or c == '-'
    then
      return '%' .. c
    end
    return c
  end

  local segments = split(pattern, '/')
  for i, segment in ipairs(segments) do
    local last_seg = i == #segments
    if segment == '**' then
      local chunks = {
        path_sep .. '-',
        '.-' .. path_sep,
      }
      if last_seg then
        chunks = { '.-' }
      end
      append(chunks)
    else
      local in_braces = false
      local brace_val = ''
      local in_brackets = false
      local bracket_val = ''
      for j = 1, #segment do
        local char = string.sub(segment, j, j)
        if char ~= '}' and in_braces then
          brace_val = brace_val .. char
        else
          if in_brackets and (char ~= ']' or bracket_val == '') then
            local res
            if char == '-' then
              res = char
            elseif bracket_val == '' and char == '!' then
              res = '^'
            elseif char == '/' then
              res = ''
            else
              res = escape(char)
            end
            bracket_val = bracket_val .. res
          else
            if char == '{' then
              in_braces = true
            elseif char == '[' then
              in_brackets = true
            elseif char == '}' then
              local choices = split(brace_val, ',')
              local parsed_choices = {}
              for _, choice in ipairs(choices) do
                table.insert(parsed_choices, parse(choice))
              end
              append(vim.tbl_flatten(parsed_choices))
              in_braces = false
              brace_val = ''
            elseif char == ']' then
              append({ '[' .. bracket_val .. ']' })
              in_brackets = false
              bracket_val = ''
            elseif char == '?' then
              append({ non_path_sep })
            elseif char == '*' then
              append({ non_path_sep .. '-' })
            else
              append({ escape(char) })
            end
          end
        end
      end

      if not last_seg and (segments[i + 1] ~= '**' or i + 1 < #segments) then
        append({ path_sep })
      end
    end
  end

  return patterns
end

---@private
--- Implementation of LSP 3.17.0's pattern matching: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#pattern
--- Modeled after VSCode's implementation: https://github.com/microsoft/vscode/blob/0319eed971719ad48e9093daba9d65a5013ec5ab/src/vs/base/common/glob.ts#L509
---
---@param pattern string|table The glob pattern (raw or parsed) to match.
---@param s string The string to match against pattern.
---@return boolean Whether or not pattern matches s.
function M._match(pattern, s)
  if type(pattern) == 'string' then
    pattern = parse(pattern)
  end
  -- Since Lua's built-in string pattern matching does not have an alternate
  -- operator like '|', `parse` will construct one pattern for each possible
  -- alternative. Any pattern that matches thus matches the glob.
  for _, p in ipairs(pattern) do
    if s:match('^' .. p .. '$') then
      return true
    end
  end
  return false
end

M._watchfunc = (vim.fn.has('win32') == 1 or vim.fn.has('mac') == 1) and watch.watch or watch.poll

---@type table<number, table<number, function[]>> client id -> registration id -> cancel function
local cancels = vim.defaulttable()

local queue_timeout_ms = 100
---@type table<number, uv.uv_timer_t> client id -> libuv timer which will send queued changes at its timeout
local queue_timers = {}
---@type table<number, lsp.FileEvent[]> client id -> set of queued changes to send in a single LSP notification
local change_queues = {}
---@type table<number, table<string, lsp.FileChangeType>> client id -> URI -> last type of change processed
--- Used to prune consecutive events of the same type for the same file
local change_cache = vim.defaulttable()

local to_lsp_change_type = {
  [watch.FileChangeType.Created] = protocol.FileChangeType.Created,
  [watch.FileChangeType.Changed] = protocol.FileChangeType.Changed,
  [watch.FileChangeType.Deleted] = protocol.FileChangeType.Deleted,
}

--- Registers the workspace/didChangeWatchedFiles capability dynamically.
---
---@param reg table LSP Registration object.
---@param ctx table Context from the |lsp-handler|.
function M.register(reg, ctx)
  local client_id = ctx.client_id
  local client = vim.lsp.get_client_by_id(client_id)
  -- Ill-behaved servers may not honor the client capability and try to register
  -- anyway, so ignore requests when the user has opted out of the feature.
  local has_capability = vim.tbl_get(
    client.config.capabilities or {},
    'workspace',
    'didChangeWatchedFiles',
    'dynamicRegistration'
  )
  if not has_capability or not client.workspace_folders then
    return
  end
  local watch_regs = {}
  for _, w in ipairs(reg.registerOptions.watchers) do
    local relative_pattern = false
    local glob_patterns = {}
    if type(w.globPattern) == 'string' then
      for _, folder in ipairs(client.workspace_folders) do
        table.insert(glob_patterns, { baseUri = folder.uri, pattern = w.globPattern })
      end
    else
      relative_pattern = true
      table.insert(glob_patterns, w.globPattern)
    end
    for _, glob_pattern in ipairs(glob_patterns) do
      local base_dir = nil
      if type(glob_pattern.baseUri) == 'string' then
        base_dir = glob_pattern.baseUri
      elseif type(glob_pattern.baseUri) == 'table' then
        base_dir = glob_pattern.baseUri.uri
      end
      assert(base_dir, "couldn't identify root of watch")
      base_dir = vim.uri_to_fname(base_dir)

      local kind = w.kind
        or protocol.WatchKind.Create + protocol.WatchKind.Change + protocol.WatchKind.Delete

      local pattern = glob_pattern.pattern
      if relative_pattern then
        pattern = base_dir .. '/' .. pattern
      end
      pattern = parse(pattern)

      table.insert(watch_regs, {
        base_dir = base_dir,
        pattern = pattern,
        kind = kind,
      })
    end
  end

  local callback = function(base_dir)
    return function(fullpath, change_type)
      for _, w in ipairs(watch_regs) do
        change_type = to_lsp_change_type[change_type]
        -- e.g. match kind with Delete bit (0b0100) to Delete change_type (3)
        local kind_mask = bit.lshift(1, change_type - 1)
        local change_type_match = bit.band(w.kind, kind_mask) == kind_mask
        if base_dir == w.base_dir and M._match(w.pattern, fullpath) and change_type_match then
          local change = {
            uri = vim.uri_from_fname(fullpath),
            type = change_type,
          }

          local last_type = change_cache[client_id][change.uri]
          if last_type ~= change.type then
            change_queues[client_id] = change_queues[client_id] or {}
            table.insert(change_queues[client_id], change)
            change_cache[client_id][change.uri] = change.type
          end

          if not queue_timers[client_id] then
            queue_timers[client_id] = vim.defer_fn(function()
              client.notify('workspace/didChangeWatchedFiles', {
                changes = change_queues[client_id],
              })
              queue_timers[client_id] = nil
              change_queues[client_id] = nil
              change_cache[client_id] = nil
            end, queue_timeout_ms)
          end

          break -- if an event matches multiple watchers, only send one notification
        end
      end
    end
  end

  local watching = {}
  for _, w in ipairs(watch_regs) do
    if not watching[w.base_dir] then
      watching[w.base_dir] = true
      table.insert(
        cancels[client_id][reg.id],
        M._watchfunc(w.base_dir, { uvflags = { recursive = true } }, callback(w.base_dir))
      )
    end
  end
end

--- Unregisters the workspace/didChangeWatchedFiles capability dynamically.
---
---@param unreg table LSP Unregistration object.
---@param ctx table Context from the |lsp-handler|.
function M.unregister(unreg, ctx)
  local client_id = ctx.client_id
  local client_cancels = cancels[client_id]
  local reg_cancels = client_cancels[unreg.id]
  while #reg_cancels > 0 do
    table.remove(reg_cancels)()
  end
  client_cancels[unreg.id] = nil
  if not next(cancels[client_id]) then
    cancels[client_id] = nil
  end
end

return M
