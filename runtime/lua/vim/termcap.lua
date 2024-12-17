local M = {}

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
--- @param cb fun(cap:string, found:boolean, seq:string?) Callback function which is called for
---           each capability in {caps}. {found} is set to true if the capability was found or false
---           otherwise. {seq} is the control sequence for the capability if found, or nil for
---           boolean capabilities.
function M.query(caps, cb)
  vim.validate('caps', caps, { 'string', 'table' })
  vim.validate('cb', cb, 'function')

  if type(caps) ~= 'table' then
    caps = { caps }
  end

  local pending = {} ---@type table<string, boolean>
  for _, v in ipairs(caps) do
    pending[v] = true
  end

  local timer = assert(vim.uv.new_timer())

  local id = vim.api.nvim_create_autocmd('TermResponse', {
    nested = true,
    callback = function(args)
      local resp = args.data.sequence ---@type string
      local k, rest = resp:match('^\027P1%+r(%x+)(.*)$')
      if k and rest then
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

        cb(cap, true, seq)

        pending[cap] = nil

        if next(pending) == nil then
          return true
        end
      end
    end,
  })

  local encoded = {} ---@type string[]
  for i = 1, #caps do
    encoded[i] = vim.text.hexencode(caps[i])
  end

  local query = string.format('\027P+q%s\027\\', table.concat(encoded, ';'))

  -- If running in tmux, wrap with the passthrough sequence
  if os.getenv('TMUX') then
    query = string.format('\027Ptmux;%s\027\\', query:gsub('\027', '\027\027'))
  end

  io.stdout:write(query)

  timer:start(1000, 0, function()
    -- Delete the autocommand if no response was received
    vim.schedule(function()
      -- Suppress error if autocommand has already been deleted
      pcall(vim.api.nvim_del_autocmd, id)

      -- Call the callback for all capabilities that were not found
      for k in pairs(pending) do
        cb(k, false, nil)
      end
    end)

    if not timer:is_closing() then
      timer:close()
    end
  end)
end

return M
