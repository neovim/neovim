local M = {}

---@private
--- Reads trust database from $XDG_STATE_HOME/nvim/trust.
---
---@return (table) Contents of trust database, if it exists. Empty table otherwise.
local function read_trust()
  local trust = {}
  local f = io.open(vim.fn.stdpath('state') .. '/trust', 'r')
  if f then
    local contents = f:read('*a')
    if contents then
      for line in vim.gsplit(contents, '\n') do
        local hash, file = string.match(line, '^(%S+) (.+)$')
        if hash and file then
          trust[file] = hash
        end
      end
    end
    f:close()
  end
  return trust
end

---@private
--- Writes provided {trust} table to trust database at
--- $XDG_STATE_HOME/nvim/trust.
---
---@param trust (table) Trust table to write
local function write_trust(trust)
  vim.validate({ trust = { trust, 't' } })
  local f = assert(io.open(vim.fn.stdpath('state') .. '/trust', 'w'))

  local t = {}
  for p, h in pairs(trust) do
    t[#t + 1] = string.format('%s %s\n', h, p)
  end
  f:write(table.concat(t))
  f:close()
end

--- Attempt to read the file at {path} prompting the user if the file should be
--- trusted. The user's choice is persisted in a trust database at
--- $XDG_STATE_HOME/nvim/trust.
---
---@see |vim.secure.trust()|
---@see |:trust|
---
---@param path (string) Path to a file to read.
---
---@return (string|nil) The contents of the given file if it exists and is
---        trusted, or nil otherwise.
function M.read(path)
  vim.validate({ path = { path, 's' } })
  local fullpath = vim.loop.fs_realpath(vim.fs.normalize(path))
  if not fullpath then
    return nil
  end

  local trust = read_trust()

  if trust[fullpath] == '!' then
    -- File is denied
    return nil
  end

  local contents
  do
    local f = io.open(fullpath, 'r')
    if not f then
      return nil
    end
    contents = f:read('*a')
    f:close()
  end

  local hash = vim.fn.sha256(contents)
  if trust[fullpath] == hash then
    -- File already exists in trust database
    return contents
  end

  -- File either does not exist in trust database or the hash does not match
  local choice = vim.fn.confirm(
    string.format('%s is not trusted.', fullpath),
    '&ignore\n&view\n&deny\n&allow',
    1
  )

  if choice == 0 or choice == 1 then
    -- Cancelled or ignored
    return nil
  elseif choice == 2 then
    -- View
    vim.cmd('new')
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.split(string.gsub(contents, '\n$', ''), '\n')
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].bufhidden = 'hide'
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].swapfile = false
    vim.bo[buf].modeline = false
    vim.bo[buf].buflisted = false
    vim.bo[buf].readonly = true
    vim.bo[buf].modifiable = false
    return nil
  elseif choice == 3 then
    -- Deny
    trust[fullpath] = '!'
    contents = nil
  elseif choice == 4 then
    -- Allow
    trust[fullpath] = hash
  end

  write_trust(trust)

  return contents
end

--- Manage the trust database.
---
--- The trust database is located at |$XDG_STATE_HOME|/nvim/trust.
---
---@param opts (table):
---    - action (string): "allow" to add a file to the trust database and trust it,
---      "deny" to add a file to the trust database and deny it,
---      "remove" to remove file from the trust database
---    - path (string|nil): Path to a file to update. Mutually exclusive with {bufnr}.
---      Cannot be used when {action} is "allow".
---    - bufnr (number|nil): Buffer number to update. Mutually exclusive with {path}.
---@return (boolean, string) success, msg:
---    - true and full path of target file if operation was successful
---    - false and error message on failure
function M.trust(opts)
  vim.validate({
    path = { opts.path, 's', true },
    bufnr = { opts.bufnr, 'n', true },
    action = {
      opts.action,
      function(m)
        return m == 'allow' or m == 'deny' or m == 'remove'
      end,
      [["allow" or "deny" or "remove"]],
    },
  })

  local path = opts.path
  local bufnr = opts.bufnr
  local action = opts.action

  if path and bufnr then
    error('path and bufnr are mutually exclusive', 2)
  end

  local fullpath
  if path then
    fullpath = vim.loop.fs_realpath(vim.fs.normalize(path))
  else
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname == '' then
      return false, 'buffer is not associated with a file'
    end
    fullpath = vim.loop.fs_realpath(vim.fs.normalize(bufname))
  end

  if not fullpath then
    return false, string.format('invalid path: %s', path)
  end

  local trust = read_trust()

  if action == 'allow' then
    assert(bufnr, 'bufnr is required when action is "allow"')

    local contents = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
    local hash = vim.fn.sha256(contents)

    trust[fullpath] = hash
  elseif action == 'deny' then
    trust[fullpath] = '!'
  elseif action == 'remove' then
    trust[fullpath] = nil
  end

  write_trust(trust)
  return true, fullpath
end

return M
