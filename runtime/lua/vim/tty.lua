local M = {}

--- Send `payload` to the host terminal and listen for `TermResponse`, calling `on_response` for
--- each response. Cleans up after `opts.timeout` ms if the callback never returns `true`.
---
--- The autocommand is removed when:
--- - `on_response()` returns `true`
--- - the timeout fires (and `opts.on_timeout` is called, if given)
--- - the caller explicitly deletes the returned autocmd id
---
---@param payload string Sequence to send via nvim_ui_send(). Use empty string ('') to just register
---                      a listener (no sending).
---@param opts? { timeout?: integer, on_timeout?: fun(), group?: integer|string }
---       - `timeout` (default: 1000) ms to wait before giving up, or 0 for never (caller must remove the autocmd).
---       - `on_timeout` optional fn called when the timeout fires.
---       - `group`: augroup for the TermResponse autocmd.
---@param on_response fun(resp:string):boolean? Called for each TermResponse. Return `true` to stop listening.
---@return integer # autocmd id of the TermResponse handler.
function M.request(payload, opts, on_response)
  vim.validate('payload', payload, 'string')
  vim.validate('opts', opts, 'table', true)
  vim.validate('on_response', on_response, 'function')

  opts = opts or {}
  local timeout = opts.timeout or 1000
  local timer ---@type uv.uv_timer_t?
  if timeout > 0 then
    timer = assert(vim.uv.new_timer())
  end

  local id = vim.api.nvim_create_autocmd('TermResponse', {
    group = opts.group,
    nested = true,
    callback = function(ev)
      local stop = on_response(ev.data.sequence)
      -- If on_response is done, cancel the timeout so on_timeout doesn't fire spuriously.
      if stop and timer and not timer:is_closing() then
        timer:close()
      end
      return stop
    end,
  })

  if payload ~= '' then
    vim.api.nvim_ui_send(payload)
  end

  if timer then
    timer:start(timeout, 0, function()
      vim.schedule(function()
        pcall(vim.api.nvim_del_autocmd, id)
        if opts.on_timeout then
          opts.on_timeout()
        end
      end)
      if not timer:is_closing() then
        timer:close()
      end
    end)
  end

  return id
end

--- Query the host terminal emulator for terminfo capabilities.
---
--- This function sends the XTGETTCAP DCS sequence to the host terminal emulator asking the terminal
--- to send us its terminal capabilities. These are strings that are normally taken from a terminfo
--- file, however an up to date terminfo database is not always available (particularly on remote
--- machines), and many terminals continue to misidentify themselves or do not provide their own
--- terminfo file, making the terminfo database unreliable.
---
--- Querying the terminal guarantees that we get a truthful answer, but only if the host terminal
--- emulator supports the XTGETTCAP sequence.
---
--- @param caps string|table A terminal capability or list of capabilities to query
--- @param on_response fun(cap:string, found:boolean, seq:string?) Called for each capability in
---        `caps`. `found` is true if the capability was found, else false. `seq` is the control
---        sequence if found, or nil for boolean capabilities.
function M.query(caps, on_response)
  vim.validate('caps', caps, { 'string', 'table' })
  vim.validate('on_response', on_response, 'function')

  if type(caps) ~= 'table' then
    caps = { caps }
  end

  local pending = {} ---@type table<string, boolean>
  for _, v in ipairs(caps) do
    pending[v] = true
  end

  local encoded = {} ---@type string[]
  for i = 1, #caps do
    encoded[i] = vim.text.hexencode(caps[i])
  end
  local payload = ('\027P+q%s\027\\'):format(table.concat(encoded, ';'))

  M.request(payload, {
    on_timeout = function()
      -- Call the callback for all capabilities that were not found.
      for k in pairs(pending) do
        on_response(k, false, nil)
      end
    end,
  }, function(resp)
    local k, rest = resp:match('^\027P1%+r(%x+)(.*)$')
    if not k or not rest then
      return
    end
    local cap = vim.text.hexdecode(k)
    if not cap or not pending[cap] then
      -- Received a response for a capability we didn't request. This can happen if there are
      -- multiple concurrent XTGETTCAP requests
      return
    end

    local seq ---@type string?
    if rest:match('^=%x+$') then
      seq = vim.text
        .hexdecode(rest:sub(2))
        :gsub('\\E', '\027')
        :gsub('%%p%d', '')
        :gsub('\\(%d+)', string.char)
    end

    on_response(cap, true, seq)
    pending[cap] = nil

    return next(pending) == nil
  end)
end

--- Send an APC sequence to the terminal and call `on_response` for each APC response received.
--- Cleans up after {timeout} milliseconds if no response is received.
---
--- `on_response` receives the full APC sequence including the `\027_` prefix.
--- Return `true` from `on_response` to stop listening.
---
---@param payload string APC sequence to send (full escape sequence including prefix/suffix)
---@param opts {timeout?:integer} Options table (timeout in milliseconds, default 1000)
---@param on_response fun(resp:string):boolean? Callback invoked for each APC TermResponse
---@overload fun(payload:string, on_response:fun(resp:string):boolean?)
function M.query_apc(payload, opts, on_response)
  if type(opts) == 'function' then
    on_response = opts
    opts = {}
  end

  vim.validate('payload', payload, 'string')
  vim.validate('opts', opts, 'table')
  vim.validate('on_response', on_response, 'function')

  M.request(payload, opts, function(resp)
    if resp:match('^\027_') then
      return on_response(resp)
    end
  end)
end

return M
