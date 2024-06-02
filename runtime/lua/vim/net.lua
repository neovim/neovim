local M = {}

---@class HeaderTable
---@field _storage table<string, string[]>
local HeaderTable = {}
HeaderTable.__index = HeaderTable

---@private
---@param input_table table<string, string|string[]>|nil
function HeaderTable.new(input_table)
  local instance = setmetatable({ _storage = {} }, HeaderTable)
  if input_table then
    instance:_from_table(input_table)
  end
  return instance
end

---@private
---@param key string
---@return string
function HeaderTable:_normalize_key(key)
  return key:lower()
end

---@private
---@param input_table table<string, string|string[]>
function HeaderTable:_from_table(input_table)
  for key, value in pairs(input_table) do
    local normalized_key = self:_normalize_key(key)
    if type(value) == 'string' then
      self._storage[normalized_key] = { value }
    elseif type(value) == 'table' then
      self._storage[normalized_key] = value
    else
      vim.notify('Invalid value type for key: ' .. key, vim.log.levels.ERROR)
    end
  end
end

---Set value of header.
---@param self HeaderTable HeaderTable Instance.
---@param value string[] | string Header value.
---@param key string Non case-sensitive header name.
function HeaderTable:set(key, value)
  local normalized_key = self:_normalize_key(key)
  if type(value) == 'string' then
    self._storage[normalized_key] = { value }
  elseif type(value) == 'table' then
    self._storage[normalized_key] = value
  else
    vim.notify('Invalid value type for key: ' .. key, vim.log.levels.ERROR)
  end
end

---Append value to header.
---@param self HeaderTable HeaderTable Instance.
---@param key string Non case-sensitive header name.
function HeaderTable:append(key, value)
  local normalized_key = self:_normalize_key(key)
  if self._storage[normalized_key] then
    table.insert(self._storage[normalized_key], value)
  else
    self._storage[normalized_key] = { value }
  end
end

---Get header value.
---For headers like cookies, use |HeaderTable:get_all|.
---@param self HeaderTable HeaderTable Instance.
---@param key string Non case-sensitive header name.
---@return string | nil
function HeaderTable:get(key)
  local normalized_key = self:_normalize_key(key)
  local value = self._storage[normalized_key]

  if value == nil then
    return nil
  elseif #value == 1 then
    return table.concat(value, ', ')
  end
end

---Get all header values.
---@param self HeaderTable HeaderTable Instance.
---@param key string Non case-sensitive header name.
---@return string[] | nil
function HeaderTable:get_all(key)
  local normalized_key = self:_normalize_key(key)
  local value = self._storage[normalized_key]

  if value == nil then
    return nil
  else
    return value
  end
end

---@param self HeaderTable HeaderTable Instance.
---@param key string Non case-sensitive header name.
---@return boolean has true if the HeaderTable contains key.
function HeaderTable:has(key)
  local normalized_key = self:_normalize_key(key)
  return self._storage[normalized_key] ~= nil
end

---Create a non-case sensitive table of headers that can contain multiple values per header.
---
---@param input_table table<string, string[] | string> | nil Optional input table.
---@return HeaderTable
function M.new_headers(input_table)
  return HeaderTable.new(input_table)
end

---@private
---@param header_table HeaderTable
---@return string[]
local function header_table_to_curl_arg_list(header_table)
  local arg_list = {}
  for key, values in pairs(header_table._storage) do
    for _, value in ipairs(values) do
      vim.list_extend(arg_list, {
        '--header',
        key .. ': ' .. value,
      })
    end
  end
  return arg_list
end

---@alias vim.net.HttpMethod "GET" | "HEAD" | "POST" | "PUT" | "DELETE" | "CONNECT" | "OPTIONS" | "TRACE" | "PATCH"

---@private Method defaults to GET.
---@param method? vim.net.HttpMethod
---@return {[1]: "--request", [2]: vim.net.HttpMethod}
local function createMethodArgs(method)
  method = method and method:upper() or 'GET'

  if method == 'HEAD' then
    return { '--head' }
  elseif method == 'GET' then
    return { '--get' }
  end

  return {
    '--request',
    method,
  }
end

---@class vim.net.createCurlArgs.Opts
---@field method vim.net.HttpMethod|nil
---@field redirect "follow"|"error"|nil
---@field data string|table<string, any>|nil
---@field headers HeaderTable | table<string, string | string[]> | nil
---@field download_location string|nil
---@field upload_file string|nil
---@field user string|nil

---@private --- Creates a table of curl command arguments based on the provided URL and options.
---@param url string The request URL.
---@param opts vim.net.createCurlArgs.Opts
---@return string[] args Curl command.
local function createCurlArgs(url, opts)
  vim.validate({
    opts = { opts, 'table', true },
  })

  local args = {
    'curl',

    -- Blocks progress bars and other non-parsable things
    '--no-progress-meter',
  }

  -- Set http method.
  vim.list_extend(args, createMethodArgs(opts.method))

  -- redirect mode
  if opts.redirect == 'follow' or opts.redirect == nil then
    table.insert(args, '--location')
  end

  -- upload_file
  if opts.upload_file then
    vim.list_extend(args, {
      '--upload-file',
      vim.fn.fnameescape(vim.fn.fnamemodify(opts.upload_file, ':p')),
    })
  end

  if opts.data ~= nil then
    if type(opts.data) == 'table' then
      vim.list_extend(args, {
        -- Let curl do some extra stuff for JSON
        '--json',
        vim.json.encode(opts.data),
      })
    else
      vim.list_extend(args, {
        -- Otherwise, just pass the string as data
        -- --data-raw does not give @ any special meaning
        '--data-raw',
        opts.data,
      })
    end
  end

  if opts.headers ~= nil then
    local headers = opts.headers

    if opts.headers._storage == nil then
      headers = HeaderTable.new(opts.headers) ---@cast headers HeaderTable
    end

    vim.list_extend(args, header_table_to_curl_arg_list(headers))
  end

  if opts.download_location == nil then
    -- Write additonal request metadata after the body.
    vim.list_extend(args, {
      '--write-out',
      '\\nBEGIN_HEADERS\\n%{header_json}\\n%{json}',
    })
  else
    -- Write body contents to file.
    vim.list_extend(args, {
      '--output',
      opts.download_location,
    })
  end

  if opts.user ~= nil then
    vim.list_extend(args, {
      '--user',
      opts.user,
    })
  end

  -- Finally, insert the request url.
  table.insert(args, url)

  return args
end

--- @private Processes a list of data received from buffered stdout and returns a table with response data.
--- @param data string Data recieved from stdout.
--- @return vim.net.Response Response A table containing processed response data.
local function process_stdout(data)
  data = vim.split(data, '\n')
  local cache = {}

  local extra = vim.json.decode(data[#data])

  -- Remove `json`
  table.remove(data, #data)

  -- This makes our life so much easier
  local began_headers_at ---@type integer

  -- In the vast majority of cases, BEGAN_HEADERS is near the end of the list.
  -- We can loop backwards to gain some perf
  for i = #data, 1, -1 do
    if data[i] == 'BEGIN_HEADERS' then
      began_headers_at = i
      break
    end
  end

  table.remove(data, began_headers_at)

  local status = extra.http_code and tonumber(extra.http_code) or nil
  if extra.method and type(extra.method) == 'string' then
    ---@cast extra {method: string}
    extra.method = extra.method:upper()
  end

  ---@private
  local function read_headers()
    if began_headers_at ~= nil and cache.headers == nil then
      local header_string = table.concat(data, nil, began_headers_at, #data)

      cache.headers = HeaderTable.new(vim.json.decode(header_string))
    end

    return cache.headers
  end

  ---@private
  local function read_text()
    -- check cache, return nil if method is HEAD
    if cache.body == nil and extra.method ~= 'HEAD' then
      -- Fix a strange case where it seems anything but HTTP will return with an extra
      -- "" item on the end.
      local extra_skip = (extra.scheme == 'SCP' or extra.scheme == 'FTP') and 1 or 0

      local body = table.concat(data, '\n', 1, began_headers_at - 1 - extra_skip)

      cache.body = body
    end

    return cache.body
  end

  return {
    headers = read_headers,
    text = read_text,
    json = function(opts)
      local text = read_text()
      return text and vim.json.decode(text, opts or {}) or nil
    end,
    method = extra.method,
    status = status,
    ok = status and (status >= 200 and status <= 299) or false,
    size = extra.size_download and tonumber(extra.size_download) or nil,
    http_version = extra.http_version and tonumber(extra.http_version) or nil,
    _raw_write_out = extra,
  }
end

---@class vim.net.Response
---@inlinedoc
---Whether the request was successful (status within 2XX range).
---@field ok boolean
---Response headers.
---@field headers fun(): HeaderTable
---Response body. Nil if method is HEAD.
---@field text fun(): string|nil
---Response body as JSON. Optionally accepts opts from |vim.json.decode|.
---Will throw errors if body is not JSON-decodable. Nil if method is HEAD.
---@field json fun(opts: table<string, any>|nil): any
---The http method used in the most recent HTTP request.
---@field method string
---The numerical response code.
---@field status number
---The total amount of bytes that were downloaded. This is the size of the
---body/data that was transferred, excluding headers.
---@field size number
---HTTP version used in the request.
---@field http_version number
---@field _raw_write_out any result from vim.json.decode

---@class vim.net.fetch.Opts
---@inlinedoc
---HTTP method to use. Defaults to GET.
---@field method vim.net.HttpMethod|nil
---Headers to set on the request
---@field headers HeaderTable | table<string, string | string[]> | nil
---Redirect mode. Defaults to "follow". Possible values are:
---  - "follow": Follow all redirects incurred when fetching a resource.
---  - "error": Throw an error using on_err or vim.notify when status is 3XX.
---@field redirect "follow"|"error"|nil
---Path to an upload_file. Can be relative.
---@field upload_file string|nil
---String in "username:password" format. Prefer over passing in url.
---@field user string|nil
---Data to send with the request. If a table, it will be JSON-encoded. vim.net
---does not currently support form encoding.
---@field data string|table<string, any>|nil
---Callback when request is completed successfully.
---@field on_complete fun(response: vim.net.Response)|nil
---Callback recieving a `stderr_buffered` string[] of error. err is either curl
---stderr or internal fetch() error. Without providing this function, |vim.net.fetch()|
---will automatically raise the error to the user. See |on_stderr| and `stderr_buffered`.
---@field on_err fun(err: string[]|nil, exit_code: number|nil)|nil
---@field _dry boolean|nil

--- Asynchronously make network requests.
---
--- See man://curl for supported protocols. Not all protocols are fully tested.
---
--- Please carefully note the option differences with |vim.net.download()|, notably
--- `redirect`.
---
---@see |vim.net.download()|
---@see https://developer.mozilla.org/en-US/docs/Web/HTTP/Status
---@see |job-control|
---@see man://curl
---
---@param url string The request URL.
---@param opts vim.net.fetch.Opts|nil Optional keyword arguments:
---
--- Example:
--- ```lua
--- -- GET a url
--- vim.net.fetch("https://example.com/api/data", {
---   on_complete = function (response)
---     -- Lets read the response!
---
---     if response.ok then
---       -- Read response text
---       local body = response.text()
---     end
---   end
--- })
---
--- -- POST to a url, sending a table as JSON and providing an authorization header
--- vim.net.fetch("https://example.com/api/data", {
---   method = "POST",
---   data = {
---     key = value
---   },
---   headers = {
---     Authorization = "Bearer " .. token
---   },
---   on_complete = function (response)
---     -- Lets read the response!
---
---     if response.ok then
---       -- Read JSON response
---       local table = response.json()
---     else
---
---     -- What went wrong?
---     vim.print(response.status)
---   end
--- })
--- ```
function M.fetch(url, opts)
  vim.validate({
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  -- TODO(TheLeoP): should a different validation be used?
  -- Ensure that we dont download to a file in fetch()
  if opts.download_location then
    opts.download_location = nil
  end

  local args = createCurlArgs(url, opts)

  if opts._dry then
    return args
  end

  vim.system(args, { text = true }, function(result)
    if result.stdout then
      local code = result.code
      local res = process_stdout(result.stdout)

      if opts.redirect == 'error' and res.status >= 300 and res.status <= 399 then
        ---@cast res +{_raw_write_out: {redirect_url: string}}
        local str = 'Fetch redirected to ' .. res._raw_write_out.redirect_url

        if opts.on_err ~= nil then
          return vim.notify(str, vim.log.levels.ERROR)
        end

        return opts.on_err({ str }, code)
      end

      if code ~= 0 then
        return opts.on_err(nil, code)
      end

      if opts.on_complete and code == 0 then
        opts.on_complete(res)
      end
    elseif result.stderr then
      local data = vim.split(result.stderr, '\n')
      if data[#data] == '' then
        -- strip EOL
        table.remove(data, #data)
      end

      if vim.tbl_isempty(data) then
        -- Data was nothing but a EOL
        return
      end

      if opts.on_err ~= nil then
        return opts.on_err(data)
      end

      vim.notify('Failed to fetch: ' .. result.stderr, vim.log.levels.ERROR)
    end
  end)
end

---@class vim.net.download.Opts
---@inlinedoc
---HTTP method to use. Defaults to GET.
---@field method vim.net.HttpMethod|nil
---Headers to set on the request
---@field headers HeaderTable | table<string, string | string[]> | nil
---Redirect mode. Defaults to "follow". Possible values are:
---  - "follow": Follow all redirects incurred when fetching a resource.
---  - "none": Ignores redirect status.
---@field redirect "follow"|"none"|nil
---String in "username:password" format. Prefer over passing in url.
---@field user string|nil
---Data to send with the request. If a table, it will be JSON-encoded. vim.net
---does not currently support form encoding.
---@field data string|table<string, any>|nil
---Callback when request is completed successfully.
---@field on_complete fun()|nil
---Callback recieving a `stderr_buffered` string[] of error. err is either curl
---stderr or internal fetch() error. Without providing this function, |vim.net.fetch()|
---will automatically raise the error to the user. See |on_stderr| and `stderr_buffered`.
---@field on_err fun(err: string[]|nil, exit_code: number|nil)|nil
---Path to where the file will be downloaded
---@field download_location string|nil
---@field _dry boolean|nil

--- Asynchronously download a file.
--- To read the response metadata, such as headers and body, use |vim.net.fetch()|.
---
--- See man://curl for supported protocols. Not all protocols are fully tested.
---
--- Please carefully note the option differences with |vim.net.fetch()|, notably
--- `redirect`.
---
---@see |vim.net.fetch()|
---@see man://curl
---
---@param url string url
---@param path string A download path, can be relative.
---@param opts vim.net.download.Opts|nil
--- Example:
--- ```lua
--- vim.net.download("https://.../path/file", "~/.cache/download/location", {
---   on_complete = function ()
---     vim.notify("File Downloaded", vim.log.levels.INFO)
---   end
--- })
--- ```
function M.download(url, path, opts)
  vim.validate({
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  path = vim.fn.fnameescape(vim.fn.fnamemodify(path, ':p'))

  opts.download_location = path

  local args = createCurlArgs(url, opts)

  if opts._dry then
    return args
  end

  vim.system(args, { text = true }, function(result)
    local code = result.code
    if code ~= 0 then
      return opts.on_err(nil, code)
    end

    if opts.on_complete and code == 0 then
      opts.on_complete()
    end

    if result.stderr then
      local data = vim.split(result.stderr, '\n')
      if data[#data] == '' then
        -- strip EOL
        table.remove(data, #data)
      end

      if vim.tbl_isempty(data) then
        -- Data was nothing but a EOL
        return
      end

      if opts.on_err ~= nil then
        return opts.on_err(data)
      end

      vim.notify('Failed to download file: ' .. result.stderr, vim.log.levels.ERROR)
    end
  end)
end

---@param url string
---@return string
---@return string
function M._get_filename_and_credentials(url)
  if vim.b.lua_net_credentials ~= nil then
    return url, vim.b.lua_net_credentials
  end

  local scheme, credentials, path = url:match('^([^:]+://)([^/@]*)@?(.*)') --[[@as string, string, string]]

  if credentials then
    local non_credentials_url = scheme .. path

    if not credentials:find(':') then
      local password = vim.fn.inputsecret({
        prompt = 'password (return for none): ',
        cancelreturn = nil,
      }) --[[@as string]]

      if password ~= '' then
        credentials = credentials .. ':' .. password
      end
    end

    vim.b.lua_net_credentials = credentials

    return non_credentials_url, vim.b.lua_net_credentials
  elseif scheme ~= 'http' and scheme ~= 'https' then
    local username = vim.fn.input({
      prompt = 'username (return for none): ',
    })

    if username == '' then
      vim.b.lua_net_credentials = username
      return path, vim.b.lua_net_credentials
    end

    local password = vim.fn.inputsecret({
      prompt = 'password (return for none): ',
    })

    if password ~= '' then
      vim.b.lua_net_credentials = username .. ':' .. password
    else
      vim.b.lua_net_credentials = username
    end

    return url, vim.b.lua_net_credentials
  end
  return url, ''
end

return M