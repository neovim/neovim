local M = {}

---@private Function to create method arguments. Method defaults to GET.
---@param method string|nil Http method.
---@return string[]
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

---@private --- Creates a table of curl command arguments based on the provided URL and options.
---@param url string The request URL.
---@param opts table Keyword arguments:
---             - method string|nil Http method.
---             - redirect string|nil Redirect mode.
---             - data string|table|nil Data to send with the request. If a table, it will be JSON
---             encoded.
---             - headers table<string, string>|nil Headers to set on the request
---             - download_location string|nil Where to download a file if applicable.
---
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
    for key, value in pairs(opts.headers) do
      vim.list_extend(args, {
        '--header',
        key .. ': ' .. value,
      })
    end
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

  -- Finally, insert the request url.
  table.insert(args, url)

  return args
end

--- @private Processes a list of data received from buffered stdout and returns a table with response data.
--- @param data string[] Data recieved from stdout.
--- @return table Response A table containing processed response data.
local function process_stdout(data)
  local cache = {}

  local extra = {}

  extra = vim.json.decode(data[#data])

  -- Remove `json`
  table.remove(data, #data)

  -- This makes our life so much easier
  local began_headers_at

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
  extra.method = extra.method:upper()

  ---@private
  local function read_headers()
    if began_headers_at ~= nil and cache.headers == nil then
      local header_string = table.concat(data, nil, began_headers_at, #data)

      cache.headers = vim.json.decode(header_string)
    end

    return cache.headers
  end

  ---@private
  local function read_text()
    -- check cache, return nil if method is HEAD
    if cache.body == nil and extra.method ~= 'HEAD' then
      local body = table.concat(data, '\n', 1, began_headers_at - 1)

      cache.body = body
    end

    return cache.body
  end

  return {
    headers = read_headers,
    text = read_text,
    json = function(opts)
      return vim.json.decode(read_text(), opts and opts or {})
    end,
    method = extra.method,
    status = status,
    ok = status and (status >= 200 and status <= 299) or false,
    size = extra.size_download and tonumber(extra.size_download) or nil,
    http_version = extra.http_version and tonumber(extra.http_version) or nil,
    _raw_write_out = extra,
  }
end

--- Asynchronously make HTTP requests.
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
---@param opts table|nil Optional keyword arguments:
---             - method string|nil HTTP method to use. Defaults to GET.
---             - headers table|nil A table of key-value headers.
---             - redirect string|nil Redirect mode. Defaults to "follow". Possible values are:
---                 - "follow": Follow all redirects incurred when fetching a resource.
---                 - "error": Throw an error using on_err or vim.notify when status is 3XX.
---             - data string|table|nil Data to send with the request. If a table, it will be
---             JSON-encoded. vim.net does not currently support form encoding.
---
---             - on_complete fun(response: table)|nil Callback function when request is
---             completed successfully. The response has the following keys:
---                 - ok boolean Whether the request was successful (status within 2XX range).
---                 - headers fun(): table<string, string[]> Function returning a table of response headers.
---                 - text fun(): string|nil Function returning response body. If method was HEAD,
---                 this is nil.
---                 - json fun(opts: table|nil): table Read the body as JSON. Optionally accepts
---                 opts from |vim.json.decode|. Will throw errors if body is not JSON-decodable.
---                 - method string The http method used in the most recent HTTP request.
---                 - status number The numerical response code.
---                 - size number The total amount of bytes that were downloaded. This
---                 is the size of the body/data that was transferred, excluding headers.
---                 - http_version number HTTP version used in the request.
---             - on_err fun(err: string[])|nil Function recieving a `stderr_buffered` string[] of error. 
---             err is either curl stderr or internal fetch() error. Without providing this
---             function, |vim.net.fetch()| will automatically raise the error to the user.
---             See |on_stderr| and `stderr_buffered`.
---@return number jobid A job id.
---
--- Example:
--- <pre>lua
--- -- GET a url
--- vim.net.fetch("https://example.com/api/data", {
---   on_complete = function (response)
---     -- Lets read the response!
---
---     if response.ok then
---       -- Read response text
---       local body = response.text()
---     else
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
--- </pre>
function M.fetch(url, opts)
  vim.validate({
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  -- Ensure that we dont download to a file in fetch()
  opts.download_location = nil

  local args = createCurlArgs(url, opts)

  local out = {}

  if opts._dry then
    return args
  end

  local job = vim.fn.jobstart(args, {
    on_stdout = function(_, data)
      out = data
    end,
    on_stderr = function(_, data)
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

      vim.notify('Failed to fetch: ' .. table.concat(data, '\n'), vim.log.levels.ERROR)
    end,
    on_exit = function(_, code)
      local res

      if opts.redirect == 'error' then
        res = process_stdout(out)

        if res.status >= 300 and res.status <= 399 then
          local str = 'Fetch redirected to ' .. res._raw_write_out.redirect_url

          if opts.on_err ~= nil then
            return vim.notify(str, vim.log.levels.ERROR)
          end

          return opts.on_err({ str })
        end
      end

      if opts.on_complete and code == 0 then
        res = res == nil and process_stdout(out) or res

        opts.on_complete(res)
      end
    end,
    stdout_buffered = true,
    stderr_buffered = true,
  })

  return job
end

--- Asynchronously download a file.
--- To read the response metadata, such as headers and body, use |vim.net.fetch()|.
---
--- Please carefully note the option differences with |vim.net.fetch()|, notably
--- `redirect`.
---
---@see |vim.net.fetch()|
---@see |job-control|
---@see man://curl
---
---@param url string url
---@param path string A download path, can be relative.
---@param opts table|nil Optional keyword arguments:
---             - method string|nil HTTP method to use. Defaults to GET.
---             - headers table<string, string>|nil A table of key-value headers.
---             - redirect string|nil Redirect mode. Defaults to "follow". Possible values are:
---                 - "follow": Follow all redirects incurred when fetching a resource.
---                 - "none": Ignores redirect status.
---             - data string|table|nil Data to send with the request. If a table, it will be JSON
---             encoded. vim.net does not currently support form encoding.
---             - on_complete fun()|nil Callback function when download successfully completed.
---             - on_err fun(err: string[])|nil An optional function recieving a `stderr_buffered` string[] of curl
---             stderr. Without providing this function, |vim.net.download()| will automatically raise an error
---             to the user. See |on_stderr| and `stderr_buffered`.
---@return number jobid A job id. See |job-control|.
---
--- Example:
--- <pre>lua
--- vim.net.download("https://.../path/file", "~/.cache/download/location", {
---   on_complete = function ()
---     vim.notify("File Downloaded", vim.log.levels.INFO)
---   end
--- })
--- </pre>
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

  local job = vim.fn.jobstart(args, {
    on_exit = function(_, code)
      if opts.on_complete and code == 0 then
        opts.on_complete()
      end
    end,
    on_stderr = function(_, data)
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

      vim.notify('Failed to download file: ' .. table.concat(data, '\n'), vim.log.levels.ERROR)
    end,
    stderr_buffered = true,
  })

  return job
end

return M
