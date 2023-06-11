local bit = require('bit')
local lpeg = require('lpeg')
local watch = require('vim._watch')
local protocol = require('vim.lsp.protocol')

local M = {}

---@private
--- Parses the raw pattern into an |lpeg| pattern. LPeg patterns natively support the "this" or "that"
--- alternative constructions described in the LSP spec that cannot be expressed in a standard Lua pattern.
---
---@param pattern string The raw glob pattern
---@return userdata An |lpeg| representation of the pattern, or nil if the pattern is invalid.
local function parse(pattern)
  local l = lpeg

  local P, S, V = lpeg.P, lpeg.S, lpeg.V
  local C, Cc, Ct, Cf = lpeg.C, lpeg.Cc, lpeg.Ct, lpeg.Cf

  local pathsep = '/'

  local function class(inv, ranges)
    for i, r in ipairs(ranges) do
      ranges[i] = r[1] .. r[2]
    end
    local patt = l.R(unpack(ranges))
    if inv == '!' then
      patt = P(1) - patt
    end
    return patt
  end

  local function add(acc, a)
    return acc + a
  end

  local function mul(acc, m)
    return acc * m
  end

  local function star(stars, after)
    return (-after * (l.P(1) - pathsep)) ^ #stars * after
  end

  local function dstar(after)
    return (-after * l.P(1)) ^ 0 * after
  end

  local p = P({
    'Pattern',
    Pattern = V('Elem') ^ -1 * V('End'),
    Elem = Cf(
      (V('DStar') + V('Star') + V('Ques') + V('Class') + V('CondList') + V('Literal'))
        * (V('Elem') + V('End')),
      mul
    ),
    DStar = P('**') * (P(pathsep) * (V('Elem') + V('End')) + V('End')) / dstar,
    Star = C(P('*') ^ 1) * (V('Elem') + V('End')) / star,
    Ques = P('?') * Cc(l.P(1) - pathsep),
    Class = P('[') * C(P('!') ^ -1) * Ct(Ct(C(1) * '-' * C(P(1) - ']')) ^ 1 * ']') / class,
    CondList = P('{') * Cf(V('Cond') * (P(',') * V('Cond')) ^ 0, add) * '}',
    -- TODO: '*' inside a {} condition is interpreted literally but should probably have the same
    -- wildcard semantics it usually has.
    -- Fixing this is non-trivial because '*' should match non-greedily up to "the rest of the
    -- pattern" which in all other cases is the entire succeeding part of the pattern, but at the end of a {}
    -- condition means "everything after the {}" where several other options separated by ',' may
    -- exist in between that should not be matched by '*'.
    Cond = Cf((V('Ques') + V('Class') + V('CondList') + (V('Literal') - S(',}'))) ^ 1, mul)
      + Cc(l.P(0)),
    Literal = P(1) / l.P,
    End = P(-1) * Cc(l.P(-1)),
  })

  return p:match(pattern)
end

---@private
--- Implementation of LSP 3.17.0's pattern matching: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#pattern
---
---@param pattern string|table The glob pattern (raw or parsed) to match.
---@param s string The string to match against pattern.
---@return boolean Whether or not pattern matches s.
function M._match(pattern, s)
  if type(pattern) == 'string' then
    pattern = parse(pattern)
  end
  return pattern:match(s) ~= nil
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
  if
    -- Ill-behaved servers may not honor the client capability and try to register
    -- anyway, so ignore requests when the user has opted out of the feature.
    not client.config.capabilities.workspace.didChangeWatchedFiles.dynamicRegistration
    or not client.workspace_folders
  then
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

      local pattern = parse(glob_pattern.pattern)
      assert(pattern, 'invalid pattern: ' .. glob_pattern.pattern)
      if relative_pattern then
        pattern = lpeg.P(base_dir .. '/') * pattern
      end

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
