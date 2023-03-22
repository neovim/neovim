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
---@see |:vim.version|
---
---@params version (table) A version table to write.
--- See vim.version() for table details.
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

-- so user can opt-out of being notified
if vim.g.NVIM_NO_NEWS then return end

local cached_version = read_version()
local current_version = vim.version()

-- branch 1: if nothing was stored in cache, we write current_version and end here
if vim.tbl_isempty(cached_version) then
    write_version(current_version)
    return
end

-- Skip prereleases or make another option for it? Probably annoying on HEAD!
-- if current_version.prerelease == true then return end

-- Should we compare on anything else?
local v1 = { tonumber(cached_version.major), tonumber(cached_version.minor), tonumber(cached_version.patch) }
local v2 = { current_version.major, current_version.minor, current_version.patch }

-- if cache version is equal or greater than current, do nothing
if vim.version.cmp(v1, v2) >= 0 then return end

write_version(current_version)

-- use vim.notify to tell user how to see news.txt for the updates
vim.api.nvim_create_autocmd('CursorHold', {
  group = vim.api.nvim_create_augroup('NvimVersionCheck', {}),
  desc = 'Tells user how to see changes when a new nvim version is detected.',
  callback = function()
    vim.notify_once("New version of Neovim detected! See what's new with `:help news.txt`",
                    vim.log.levels.WARN, {})
  end,
})

