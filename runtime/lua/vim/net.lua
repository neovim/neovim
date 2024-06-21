local M = {}

---@class vim.net.Request
---@field private _system vim.SystemObj
---@field wait fun(self: vim.net.Request, timeout?: integer): string?
---@field kill fun(self: vim.net.Request, signal: integer|string)
local Request = {}

--- @param system vim.SystemObj
--- @return vim.net.Request
local function new_request(system)
  return setmetatable({
    _system = system,
  }, { __index = Request })
end

--- @param timeout? integer
function Request:wait(timeout)
  self._system:wait(timeout)
end

--- @param signal integer|string
function Request:kill(signal)
  self._system:kill(signal)
end

--HTTP methods in curl
-- default GET (there is also --get for transforming --data into URL query params)
-- --data (and its variants) or --form POST
-- --head HEAD
-- --upload-file PUT (there is also --method PUT while using --data)

---@class vim.net.Opts
---@inlinedoc
---Path to write the downloaded file to. If not provided, the one inferred from the URL will be used. Defaults to `nil`
---@field file? string
---Credentials with the format `username:password`. Defaults to `nil`
---@field user? string
---Disables all internal HTTP decoding of content or transfer encodings. Unaltered, raw, data is passed. Defaults to `false`
---@field raw? boolean
---Request headers. Defaults to `nil`
---@field headers? table<string, string[]>
---Whether `user` should be send to host after a redirect. Defaults to `false`
---@field location_trusted? boolean
---Optional callback. Defaults to `nil`
---@field on_exit? fun(err: string?)

---@type vim.net.Opts
local global_net_opts = {
  file = nil,
  user = nil,
  raw = false,
  headers = nil,
  location_trusted = false,
}

---Download a file
---@param url string Request URL
---@param opts? vim.net.Opts Additional options
---@return vim.net.Request request
---
---Example:
--- ```lua
--- -- Download a file (async)
--- -- The file will be saved in the `cwd` with the name `anything`
--- vim.net.request("https://httpbingo.org/anything")
---
--- -- Download a file (sync)
--- -- The file will be saved in the `cwd` with the name `anything`
--- vim.net.request("https://httpbingo.org/anything"):wait(500)
---
--- -- Download a file to a path (async)
--- -- The file will be saved in `/tmp/somefile`
--- vim.net.request("https://httpbingo.org/anything", {
---   file = "/tmp/somefile",
--- })
---
--- -- Download a file while sending headers (async)
--- vim.net.request("https://httpbingo.org/anything", {
---   headers = {
---     Authorization = { "Bearer foo" },
---   },
--- })
---
--- -- Download a file while handling basic auth (async)
--- vim.net.request("https://httpbingo.org/basic-auth/user/password", {
---   user = "user:password",
--- })
---
--- ```
function M.request(url, opts)
  vim.validate {
    url = { url, 'string' },
    opts = { opts, 'table', true },
  }
  opts = vim.tbl_extend('force', global_net_opts, opts or {}) --[[@as vim.net.Opts]]

  local cmd = { 'curl' } ---@type string[]

  -- Don't output progress. Do output errors
  vim.list_extend(cmd, { '--silent', '--show-error' })

  if opts.file then
    vim.list_extend(cmd, { '--output', opts.file, url })
  else
    vim.list_extend(cmd, { '--remote-name', url })
  end

  if opts.user then
    vim.list_extend(cmd, { '--user', opts.user })
  end

  if opts.raw then
    table.insert(cmd, '--raw')
  end

  if opts.headers then
    for header, values in pairs(opts.headers) do
      for _, value in ipairs(values) do
        table.insert(cmd, '--header')
        table.insert(cmd, ('%s:%s'):format(header, value))
      end
    end
  end

  -- always follow redirects
  table.insert(cmd, '--location')

  if opts.location_trusted then
    table.insert(cmd, '--location-trusted')
  end

  local request = new_request(vim.system(cmd, { text = true }, function(out)
    if opts.on_exit then
      local err = out.stderr ~= '' and out.stderr or nil
      opts.on_exit(err)
    end
  end))
  return request
end

return M
