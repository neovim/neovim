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
--- @param cb function(cap:string, seq:string) Function to call when a response is received
function M.query(caps, cb)
  vim.validate({
    caps = { caps, { 'string', 'table' } },
    cb = { cb, 'f' },
  })

  if type(caps) ~= 'table' then
    caps = { caps }
  end

  local count = #caps

  vim.api.nvim_create_autocmd('TermResponse', {
    callback = function(args)
      local resp = args.data ---@type string
      local k, v = resp:match('^\027P1%+r(%x+)=(%x+)$')
      if k and v then
        local cap = vim.text.hexdecode(k)
        local seq =
          vim.text.hexdecode(v):gsub('\\E', '\027'):gsub('%%p%d', ''):gsub('\\(%d+)', string.char)

        cb(cap, seq)

        count = count - 1
        if count == 0 then
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
    query = string.format('\027Ptmux;\027%s\027\\', query)
  end

  io.stdout:write(query)
end

return M
