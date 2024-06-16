local M = {}

local curl_v ---@type vim.Version
---@return vim.Version
local function _curl_v()
  local out = vim.system({ 'curl', '--version' }, { text = true }):wait().stdout
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

local separator = '__SEPARATOR__'

--HTTP methods in curl
-- default GET (there is also --get for transforming --data into URL query params)
-- --data (and its variants) or --form POST
-- --head HEAD
-- --upload-file PUT (there is also --method PUT while using --data)

---@class vim.net.Proxy
---Proxy URL in the format `scheme ":" ["//" authority] path ["?" query]` where authority follows the format `[userinfo "@"] host [":" port]`
---@field url? string
---Proxy credentials with the format `username:password`
---@field credentials? string

---@class vim.net.download.Opts
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
---Proxy information. Defaults to `nil`
---@field proxy? vim.net.Proxy
---Whether redirects should be followed. Defaults to `true`
---@field follow_redirects? boolean
---Whether `credentials` should be send to host after a redirect. Defaults to `false`
---@field redirect_credentials? boolean
---Optional callback. Defaults to showing a notification when the file has been downloaded.
---@field on_exit? fun(err: string?, metadata: vim.net.curl.Metadata?)

---See the `--write-out` section in  `man curl`
---@class vim.net.curl.Metadata
---@field certs? string (Added in 7.88.0)
---@field conn_id? number (Added in 8.2.0)
---@field content_type? string
---@field errormsg? string (Added in 7.75.0)
---@field exitcode? number (Added in 7.75.0)
---@field filename_effective? string (Added in 7.26.0)
---@field ftp_entry_path? string
---@field headers? table<string, string[]> (Added in 7.83.0) parsed result of ${header_json}
---@field http_code? number
---@field http_connect? number
---@field http_version? string (Added in 7.50.0)
---@field local_ip? string
---@field local_port? number
---@field method? string (Added in 7.72.0)
---@field num_certs? number (Added in 7.88.0)
---@field num_connects? number
---@field num_headers? number (Added in 7.73.0)
---@field num_redirects? number
---@field num_retries? number (Added in 8.9.0)
---@field proxy_ssl_verify_result? number (Added in 7.52.0)
---@field proxy_used? number (Added in 8.7.0)
---@field redirect_url? string
---@field referer? string (Added in 7.76.0)
---@field remote_ip? string
---@field remote_port? number
---@field response_code? number
---@field scheme? string (Added in 7.52.0)
---@field size_download? number
---@field size_header? number
---@field size_request? number
---@field size_upload? number
---@field speed_download? number
---@field speed_upload? number
---@field ssl_verify_result? number
---@field time_appconnect? number
---@field time_connect? number
---@field time_namelookup? number
---@field time_pretransfer? number
---@field time_redirect? number
---@field time_starttransfer? number
---@field time_total? number
---@field url? string (Added in 7.75.0)
---@field url.scheme? string (Added in 8.1.0)
---@field url.user? string (Added in 8.1.0)
---@field url.password? string (Added in 8.1.0)
---@field url.options? string (Added in 8.1.0)
---@field url.host? string (Added in 8.1.0)
---@field url.port? string (Added in 8.1.0)
---@field url.path? string (Added in 8.1.0)
---@field url.query? string (Added in 8.1.0)
---@field url.fragment? string (Added in 8.1.0)
---@field url.zoneid? string (Added in 8.1.0)
---@field urle.scheme? string (Added in 8.1.0)
---@field urle.user? string (Added in 8.1.0)
---@field urle.password? string (Added in 8.1.0)
---@field urle.options? string (Added in 8.1.0)
---@field urle.host? string (Added in 8.1.0)
---@field urle.port? string (Added in 8.1.0)
---@field urle.path? string (Added in 8.1.0)
---@field urle.query? string (Added in 8.1.0)
---@field urle.fragment? string (Added in 8.1.0)
---@field urle.zoneid? string (Added in 8.1.0)
---@field urlnum? number (Added in 7.75.0)
---@field url_effective? string
---@field xfer_id? number (Added in 8.2.0)

---@type vim.net.download.Opts
local download_defaults = {
  as = nil,
  try_suggested_remote_name = false,
  credentials = nil,
  override = true,
  remove_leftover_on_error = false,
  compressed = false,
  max_filesize = nil,
  raw = false,
  headers = nil,
  proxy = nil,
  proxy_credentials = nil,
  follow_redirects = true,
  redirect_credentials = false,
  on_exit = function(err, metadata)
    if err then
      return vim.notify(err, vim.log.levels.ERROR)
    end

    if not metadata or not metadata.filename_effective then
      return vim.notify('The file has been downloaded', vim.log.levels.INFO)
    end
    vim.notify(
      ('The file `%s` has been downloaded'):format(metadata.filename_effective),
      vim.log.levels.INFO
    )
  end,
}

---Asynchronously download a file
---@param url string Request URL
---@param opts? vim.net.download.Opts Additional options
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
  opts = vim.tbl_extend('force', download_defaults, opts or {}) --[[@as vim.net.download.Opts]]

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

  if opts.proxy then
    vim.list_extend(cmd, { '--proxy', opts.proxy })
  end

  if opts.proxy_credentials then
    vim.list_extend(cmd, { '--proxy-user', opts.proxy_credentials })
  end

  if opts.follow_redirects then
    table.insert(cmd, '--location')
  end

  if opts.redirect_credentials then
    table.insert(cmd, '--location-trusted')
  end

  -- stdout will contain the following:
  if vim.version.ge(curl_v, { 7, 83, 0 }) then
    -- (json) A JSON object with all available keys.
    -- (header_json) A JSON object with all HTTP response headers from the recent transfer.
    -- (`%` is duplicated in order to escape it from `format`)
    vim.list_extend(cmd, { '--write-out', ('%%{json}%s%%{header_json}'):format(separator) })
  elseif vim.version.ge(curl_v, { 7, 70, 0 }) then
    -- (json) A JSON object with all available keys.
    vim.list_extend(cmd, { '--write-out', '%{json}' })
  end

  vim.system(cmd, { text = true }, function(out)
    local err = out.stderr ~= '' and out.stderr or nil

    local lines = vim.split(out.stdout, separator)
    local json_string = lines[1]
    local header_json_string = lines[2]

    local ok, metadata = pcall(vim.json.decode, json_string)
    local ok2, headers = pcall(vim.json.decode, header_json_string)
    if ok then
      if ok2 then
        metadata.headers = headers
      end
      opts.on_exit(err, metadata)
    else
      opts.on_exit(err)
    end
  end)
end

return M
