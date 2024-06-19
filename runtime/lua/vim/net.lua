local M = {}

local curl_v ---@type vim.Version
---@return vim.Version
local function _curl_v()
  local out = vim.system({ 'curl', '--version' }, { text = true }):wait().stdout
  assert(out)
  local lines = vim.split(out, '\n')
  local version = vim
    .iter(lines)
    :filter(function(line)
      return line:find '^curl'
    end)
    :map(function(version_line)
      return vim.version.parse(version_line)
    end)
    :next()
  return version
end

--HTTP methods in curl
-- default GET (there is also --get for transforming --data into URL query params)
-- --data (and its variants) or --form POST
-- --head HEAD
-- --upload-file PUT (there is also --method PUT while using --data)

---@class vim.net.Opts
---@inlinedoc
---Path to write the downloaded file to. If not provided, the one inferred form the URL will be used. Defaults to `nil`
---@field as? string
---Whether the `Content-Disposition` response header should be taken into account to decide the name of the downloaded file. Fallbacks to `as`. Defaults to `false`
---@field try_suggested_remote_name? boolean
---Credentials with the format `username:password`. Defaults to `nil`
---@field credentials? string
---Whether the file should be overridden if it already exists. Defaults to `true`
---@field override? boolean
---Whether the file should be removed if an error happens while downloading it. Defaults to `false`
---@field remove_leftover_on_error? boolean
---Whether the file should be requested in a compressed format (and decompressed automatically). Defaults to `false`
---@field compressed? boolean
---Maximum size in bytes of the file to downlaod. The download will fail if the file requested is larger. Defaults to `nil`
---@field max_filesize? integer
---Disables all internal HTTP decoding of content or transfer encodings. Unaltered, raw, data is passed. Defaults to `false`
---@field raw? boolean
---Request headers. Defaults to `nil`
---@field headers? table<string, string[]>
---Whether redirects should be followed. Defaults to `true`
---@field follow_redirects? boolean
---Whether `credentials` should be send to host after a redirect. Defaults to `false`
---@field redirect_credentials? boolean
---Optional callback. Defaults to showing a notification when the file has been downloaded.
---@field on_exit? fun(err: string?)

---@type vim.net.Opts
local global_net_opts = {
  as = nil,
  try_suggested_remote_name = false,
  credentials = nil,
  override = true,
  remove_leftover_on_error = false,
  compressed = false,
  max_filesize = nil,
  raw = false,
  headers = nil,
  follow_redirects = true,
  redirect_credentials = false,
  on_exit = function(err)
    if err then
      return vim.notify(err, vim.log.levels.ERROR)
    end

    vim.notify('The file has been downloaded', vim.log.levels.INFO)
  end,
}

---Configure net options globally
---
---Configuration can be specified globally, or ephemerally (i.e. only for
---a single call to |vim.net.download()|). Ephemeral configuration has highest
---priority, followed by  global configuration.
---
---When omitted or `nil`, retrieve the current configuration. Otherwise,
---a configuration table (see |vim.net.Opts|).
---@param opts vim.net.Opts
---: Current net config if {opts} is omitted.
---@return vim.net.Opts?
function M.config(opts)
  vim.validate({
    opts = { opts, 'table', true },
  })

  if not opts then
    return vim.deepcopy(global_net_opts, true)
  end

  for k, v in
    pairs(opts --[[@as table<any,any>]])
  do
    global_net_opts[k] = v
  end
end

---Asynchronously download a file
---@param url string Request URL
---@param opts? vim.net.Opts Additional options
---
---Example:
--- ```lua
--- -- Download a file
--- -- The file will be saved in the `cwd` with the name `anything`
--- vim.net.download("https://httpbingo.org/anything")
---
--- -- Download a file to a path
--- -- The file will be saved in `/tmp/somefile`
--- vim.net.download("https://httpbingo.org/anything", {
---   as = "tmp/somefile",
--- })
---
--- -- Download a file while following redirects
--- vim.net.download("https://httpbingo.org/anything", {
---   follow_redirects = true,
--- })
---
--- -- Download a file while sending headers
--- vim.net.download("https://httpbingo.org/anything", {
---   headers = {
---     Authorization = { "Bearer foo" },
---   },
--- })
---
--- -- Download a file while handling basic auth
--- vim.net.download("https://httpbingo.org/basic-auth/user/password", {
---   credentials = "user:password",
--- })
---
--- -- Download a file without overriding a previous file with the same name
--- vim.net.download("https://httpbingo.org/anything", {
---   override = false,
--- })
--- ```
function M.download(url, opts)
  vim.validate {
    url = { url, 'string' },
    opts = { opts, 'table', true },
  }
  opts = vim.tbl_extend('force', global_net_opts, opts or {}) --[[@as vim.net.Opts]]

  curl_v = curl_v or _curl_v()

  local cmd = { 'curl' } ---@type string[]

  if vim.version.ge(curl_v, { 7, 67, 0 }) then
    table.insert(cmd, '--no-progress-meter')
  else
    vim.list_extend(cmd, { '--silent', '--show-error' })
  end

  if opts.as then
    vim.list_extend(cmd, { '--output', opts.as, url })
  else
    vim.list_extend(cmd, { '--remote-name', url })
  end

  if opts.try_suggested_remote_name then
    table.insert(cmd, '--remote-header-name')
  end

  if opts.credentials then
    vim.list_extend(cmd, { '--user', opts.credentials })
  end

  if not opts.override and vim.version.ge(curl_v, { 7, 83, 0 }) then
    table.insert(cmd, '--no-clober')
  elseif not opts.override then
    return vim.notify(
      ('Your current curl version is %s and you need at least version 7.83.0 to avoid overriding files'):format(
        tostring(curl_v)
      ),
      vim.log.levels.WARN
    )
  end

  if opts.remove_leftover_on_error and vim.version.ge(curl_v, { 7, 83, 0 }) then
    table.insert(cmd, '--remove-on-error')
  elseif opts.remove_leftover_on_error then
    return vim.notify(
      ('Your current curl version is %s and you need at least version 7.83.0 to remove download leftovers on error'):format(
        tostring(curl_v)
      ),
      vim.log.levels.WARN
    )
  end

  if opts.compressed then
    table.insert(cmd, '--compressed')
  end

  if opts.max_filesize then
    vim.list_extend(cmd, { '--max-filesize', tostring(opts.max_filesize) })
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

  if opts.follow_redirects then
    table.insert(cmd, '--location')
  end

  if opts.redirect_credentials then
    table.insert(cmd, '--location-trusted')
  end

  vim.system(cmd, { text = true }, function(out)
    local err = out.stderr ~= '' and out.stderr or nil

    opts.on_exit(err)
  end)
end

return M
