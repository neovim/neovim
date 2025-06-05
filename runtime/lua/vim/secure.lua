local M = {}

--- Reads trust database from $XDG_STATE_HOME/nvim/trust.
---
---@return table<string, string> Contents of trust database, if it exists. Empty table otherwise.
local function read_trust()
  local trust = {} ---@type table<string, string>
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

--- If {fullpath} is a file, read the contents of {fullpath} (or the contents of {bufnr}
--- if given) and returns the contents and a hash of the contents.
---
--- If {fullpath} is a directory, then nothing is read from the filesystem, and
--- `contents = true` and `hash = "directory"` is returned instead.
---
---@param fullpath string Path to a file or directory to read.
---@param bufnr integer? The number of the buffer.
---@return string|boolean? contents the contents of the file, or true if it's a directory
---@return string? hash the hash of the contents, or "directory" if it's a directory
local function compute_hash(fullpath, bufnr)
  local contents ---@type string|boolean?
  local hash ---@type string
  if vim.fn.isdirectory(fullpath) == 1 then
    return true, 'directory'
  end

  if bufnr then
    local newline = vim.bo[bufnr].fileformat == 'unix' and '\n' or '\r\n'
    contents =
      table.concat(vim.api.nvim_buf_get_lines(bufnr --[[@as integer]], 0, -1, false), newline)
    if vim.bo[bufnr].endofline then
      contents = contents .. newline
    end
  else
    do
      local f = io.open(fullpath, 'r')
      if not f then
        return nil, nil
      end
      contents = f:read('*a')
      f:close()
    end

    if not contents then
      return nil, nil
    end
  end

  hash = vim.fn.sha256(contents)

  return contents, hash
end

--- Writes provided {trust} table to trust database at
--- $XDG_STATE_HOME/nvim/trust.
---
---@param trust table<string, string> Trust table to write
local function write_trust(trust)
  vim.validate('trust', trust, 'table')
  local f = assert(io.open(vim.fn.stdpath('state') .. '/trust', 'w'))

  local t = {} ---@type string[]
  for p, h in pairs(trust) do
    t[#t + 1] = string.format('%s %s\n', h, p)
  end
  f:write(table.concat(t))
  f:close()
end

--- If {path} is a file: attempt to read the file, prompting the user if the file should be
--- trusted.
---
--- If {path} is a directory: return true if the directory is trusted (non-recursive), prompting
--- the user as necessary.
---
--- The user's choice is persisted in a trust database at
--- $XDG_STATE_HOME/nvim/trust.
---
---@since 11
---@see |:trust|
---
---@param path (string) Path to a file or directory to read.
---
---@return (boolean|string|nil) If {path} is not trusted or does not exist, returns `nil`. Otherwise,
---        returns the contents of {path} if it is a file, or true if {path} is a directory.
function M.read(path)
  vim.validate('path', path, 'string')
  local fullpath = vim.uv.fs_realpath(vim.fs.normalize(path))
  if not fullpath then
    return nil
  end

  local trust = read_trust()

  if trust[fullpath] == '!' then
    -- File is denied
    return nil
  end

  local contents, hash = compute_hash(fullpath, nil)
  if not contents then
    return nil
  end

  if trust[fullpath] == hash then
    -- File already exists in trust database
    return contents
  end

  local dir_msg = ''
  if hash == 'directory' then
    dir_msg = ' DIRECTORY trust is decided only by its name, not its contents.'
  end

  -- File either does not exist in trust database or the hash does not match
  local ok, result = pcall(
    vim.fn.confirm,
    string.format('%s is not trusted.%s', fullpath, dir_msg),
    '&ignore\n&view\n&deny\n&allow',
    1
  )

  if not ok and result ~= 'Keyboard interrupt' then
    error(result)
  elseif not ok or result == 0 or result == 1 then
    -- Cancelled or ignored
    return nil
  elseif result == 2 then
    -- View
    vim.cmd('sview ' .. fullpath)
    return nil
  elseif result == 3 then
    -- Deny
    trust[fullpath] = '!'
    contents = nil
  elseif result == 4 then
    -- Allow
    trust[fullpath] = hash
  end

  write_trust(trust)

  return contents
end

--- @class vim.trust.opts
--- @inlinedoc
---
--- - `'allow'` to add a file to the trust database and trust it,
--- - `'deny'` to add a file to the trust database and deny it,
--- - `'remove'` to remove file from the trust database
--- @field action 'allow'|'deny'|'remove'
---
--- Path to a file to update. Mutually exclusive with {bufnr}.
--- Cannot be used when {action} is "allow".
--- @field path? string
--- Buffer number to update. Mutually exclusive with {path}.
--- @field bufnr? integer

--- Manage the trust database.
---
--- The trust database is located at |$XDG_STATE_HOME|/nvim/trust.
---
---@since 11
---@param opts vim.trust.opts
---@return boolean success true if operation was successful
---@return string msg full path if operation was successful, else error message
function M.trust(opts)
  vim.validate('path', opts.path, 'string', true)
  vim.validate('bufnr', opts.bufnr, 'number', true)
  vim.validate('action', opts.action, function(m)
    return m == 'allow' or m == 'deny' or m == 'remove'
  end, [["allow" or "deny" or "remove"]])

  ---@cast opts vim.trust.opts
  local path = opts.path
  local bufnr = opts.bufnr
  local action = opts.action

  assert(not path or not bufnr, '"path" and "bufnr" are mutually exclusive')

  if action == 'allow' then
    assert(not path, '"path" is not valid when action is "allow"')
  end

  local fullpath ---@type string?
  if path then
    fullpath = vim.uv.fs_realpath(vim.fs.normalize(path))
  elseif bufnr then
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname == '' then
      return false, 'buffer is not associated with a file'
    end
    fullpath = vim.uv.fs_realpath(vim.fs.normalize(bufname))
  else
    error('one of "path" or "bufnr" is required')
  end

  if not fullpath then
    return false, string.format('invalid path: %s', path)
  end

  local trust = read_trust()

  if action == 'allow' then
    local contents, hash = compute_hash(fullpath, bufnr)
    if not contents then
      return false, string.format('could not read path: %s', fullpath)
    end

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
