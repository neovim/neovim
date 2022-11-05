local M = {}

--- Attempt to read the file at {path} prompting the user if the file should be
--- trusted. The user's choice is persisted in a trust database at
--- $XDG_STATE_HOME/nvim/trust.
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

  local trust = {}
  do
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
  end

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

  do
    local f, err = io.open(vim.fn.stdpath('state') .. '/trust', 'w')
    if not f then
      error(err)
    end

    local t = {}
    for p, h in pairs(trust) do
      t[#t + 1] = string.format('%s %s\n', h, p)
    end
    f:write(table.concat(t))
    f:close()
  end

  return contents
end

return M
