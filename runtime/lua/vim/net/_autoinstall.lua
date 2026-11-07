-- Code for autoinstalling Nvim. Used by remote-ssh. Independent of the "transport".

local M = {}

--- GitHub API URL of a Nvim release, by tag (see `fetch_sha256s()`). Tests replace it with a file.
M.release_api = 'https://api.github.com/repos/neovim/neovim/releases/tags/%s'

--- |$NVIM_APPNAME| of the remote Nvim. Remote-ssh owns its dirs, e.g. `push_config()`
--- (`vim.net._ssh`) replaces the config dir.
M.appname = 'nvim-remote'

--- Data dir, relative to the remote `$HOME`.
M.data_dir = ('.local/share/%s'):format(M.appname)

--- Gets the release tag of the local version.
---
---@return string tag E.g. `v0.12.0`, or `nightly` for a prerelease.
---@return string base Version without prerelease, e.g. `v0.12.0`.
local function release_tag()
  local ver = vim.version()
  local base = ('v%d.%d.%d'):format(ver.major, ver.minor, ver.patch)
  return ver.prerelease and 'nightly' or base, base
end

--- Starts fetching the release of the local version from `M.release_api`, for the SHA-256 of its
--- assets, as published by GitHub (the asset `digest`).
---
---@return fun(name: string): string?, string? get_sha256 Waits for the fetch, then gets the SHA-256
---   (hex) of asset `name` (e.g. `nvim-linux-x86_64.tar.gz`), or nil and an error if unavailable
---   (e.g. offline or rate-limited). Fails with "interrupted" on CTRL-C.
function M.fetch_sha256s()
  local task = vim.async.run(function()
    return vim.async.await(3, vim.net.request, M.release_api:format((release_tag())), {})
  end)
  return function(name)
    local ok, err, res = task:pwait(30000)
    if not ok then
      task:close() -- Timed out, or CTRL-C.
    end
    if err == 'interrupted' then
      error(err, 0)
    end
    local decoded, json = pcall(vim.json.decode, res and res.body or '')
    ---@type { name: string, digest: string? }[]
    local assets = decoded and type(json) == 'table' and json.assets or {}
    local asset = vim.iter(assets):find(function(a)
      return a.name == name
    end) or {}
    local sha256 = type(asset.digest) == 'string' and asset.digest:match('^sha256:(%x+)$')
    if not sha256 then
      return nil, ('No digest of %s: %s'):format(name, err or 'not in the release')
    end
    return sha256
  end
end

--- Gets the Nvim release URL/dir/version based on the local version + remote platform.
---
---@param os string
---@param arch string
---@return string dir Install dir, relative to the remote `$HOME`, e.g.
---   `.local/share/nvim-remote/releases/v0.12.0-linux-x86_64`. Per platform too: a shared `$HOME`
---   may be mounted on remote hosts of different platforms.
---@return string url Release archive, or `-` if the platform has none (e.g. FreeBSD): the remote
---   can only use an `nvim` on its `$PATH`.
---@return string version Minimum version of an `nvim` on the remote `$PATH` to use instead, e.g.
---   `v0.12.0`, or `v0.13.0-dev` (any build) for a prerelease.
function M.get_release(os, arch)
  local tag, base = release_tag()
  local prerelease = vim.version().prerelease
  local version = prerelease and ('%s-%s'):format(base, prerelease) or base
  -- Prerelease: installs the current nightly once per version, until "Update" (see
  -- `vim.net._ssh.connect()`).
  local install_name = prerelease and ('nightly-%s'):format(base) or base

  local os_map = { linux = 'linux', darwin = 'macos' }
  local arch_map = { x86_64 = 'x86_64', aarch64 = 'arm64', arm64 = 'arm64' }

  local target_os = os_map[os]
  local target_arch = arch_map[arch]
  if not target_os or not target_arch then
    return '-', '-', version
  end

  local release_name = ('nvim-%s-%s'):format(target_os, target_arch)
  local release_url = ('https://github.com/neovim/neovim/releases/download/%s/%s.tar.gz'):format(
    tag,
    release_name
  )
  local dir = ('%s/releases/%s-%s-%s'):format(M.data_dir, install_name, target_os, target_arch)
  return dir, release_url, version
end

return M
