local M = {}

---@private
---Reads version stored in $XDG_CACHE_HOME/nvim/version
---
---@return (table) Contents of version file or empty table.
local function read_version()
  local version = {}
  local f = io.open(vim.fn.stdpath('state') .. '/version', 'r')
  if f then
    local contents = f:read('*a')
    if contents then
      for line in vim.gsplit(contents, '\n') do
        local key, value = string.match(line, '^(%S+) = (.+)$')
        if key and value then
          version[key] = value
        end
      end
    end
    f:close()
  end
  return version
end

---@private
--- Writes provided {version} table to the version file at
--- $XDG_CACHE_HOME/nvim/version.
---
---@params version (table) A version table to write.
local function write_version(version)
  vim.validate({
    api_compatible = { version.api_compatible, 'number' },
    api_level = { version.api_level, 'number' },
    api_prerelease = { version.api_prerelease, 'boolean' },
    major = { version.major, 'number' },
    minor = { version.minor, 'number' },
    patch = { version.patch, 'number' },
    prerelease = { version.prerelease, 'boolean' },
  })
  local f = assert(io.open(vim.fn.stdpath('state') .. '/version', 'w'))

  local v = {}
  for key, value in pairs(version) do
    v[#v + 1] = string.format('%s = %s\n', key, value)
  end
  f:write(table.concat(v))
  f:close()
end

M.check = function(version)
  local current_version = version or vim.version()
  local cached_version = read_version()

  -- nothing in cache case: we write current_version to cache and end
  if vim.tbl_isempty(cached_version) then
      write_version(current_version)
      return
  end

  -- Q: Should we compare version only on major/minor/patch?
  local v1 = { tonumber(cached_version.major), tonumber(cached_version.minor), tonumber(cached_version.patch) }
  local v2 = { current_version.major, current_version.minor, current_version.patch }

  -- if cache version is equal or greater than current, do nothing
  if vim.version.cmp(v1, v2) >= 0 then return end

  write_version(current_version)

  vim.notify_once(
  "New version of Neovim detected! See what's new with `:help news.txt`",
  vim.log.levels.WARN, {})
end

return M
