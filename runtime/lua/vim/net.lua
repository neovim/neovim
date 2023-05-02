local M = {}

---@private Function to create method arguments. Method defaults to GET.
---@param method string|nil Http method.
---@return string[]
local function createMethodArgs(method)
  method = method and method:lower() or 'get'

  if method == 'head' then
    return { '--head' }
  elseif method == 'get' then
    return { '--get' }
  end

  return {
    '--request',
    method,
  }
end

---@private Create curl args for a given request.
---
---@param url string Request URL.
---@param opts table Keyword arguments:
---             - method string|nil Http method.
---             - follow_redirects boolean|nil Follow redirects.
---             - data string|table|nil Data to send with the request. If a table, it will be json
---             encoded.
---             - headers table<string, string>|nil Headers to set on the request
---             - download_location string|nil
---
---@return string[] args Curl command.
local function createCurlArgs(url, opts)
  vim.validate({
    opts = { opts, 'table', true },
  })

  local args = {
    'curl',

    -- Blocks progress bars and other non-parsable things
    -- TODO: Allow stderr
    '--no-progress-meter',
  }

  if opts.download_location == nil then
    -- Include header information when not downloading
    table.insert(args, '--include')
  end

  -- Set http method.
  vim.list_extend(args, createMethodArgs(opts.method))

  -- Follow redirects by default.
  if opts.follow_redirects or opts.follow_redirects == nil then
    table.insert(args, '--location')
  end

  if opts.data ~= nil then
    if type(opts.data) == 'table' then
      vim.list_extend(args, {
        -- Let curl do some extra stuff for json
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
      '\\n%{json}',
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

--- @private Process a stdout_buffered list of data into a response
--- @param data string[] Data recieved from stdout
local function process_stdout(data)
  local cache = {}

  -- Parse status string
  local status_string = data[1]
  -- Ignore these in favor of --write-out output i think
  local _, _, status_text = status_string:match('(%S+)%s(%d+)%s(.+)\r')

  local extra = {}

  extra = vim.json.decode(data[#data])

  ---@private
  local function read_headers()
    if cache.headers == nil then
      local headers = {}

      -- Plus one to account for status line
      for i = 2, extra.num_headers + 1 do
        local header_line = data[i]
        local header_key, header_value = header_line:match('^(.-):%s*(.*)$')
        headers[header_key] = header_value
      end

      cache.headers = headers
    end

    return cache.headers
  end

  ---@private
  local function read_body()
    if cache.body == nil then
      local body_start = extra.num_headers + 2
      local body_end = #data - 1
      local body = table.concat(data, '\n', body_start, body_end)
      cache.body = body
    end

    return cache.body
  end

  local status = extra.http_code and tonumber(extra.http_code) or nil

  return {
    headers = read_headers,
    body = read_body,
    json = function(opts)
      return vim.json.decode(read_body(), opts and opts or {})
    end,
    method = extra.method,
    status = status,
    status_text = status_text,
    ok = status and (status >= 200 and status <= 299) or false,
    size = extra.size_download and tonumber(extra.size_download) or nil,
    http_version = extra.http_version and tonumber(extra.http_version) or nil,
    _raw_write_out = extra,
  }
end

--- Asynchronously make HTTP requests.
---
---@param url string url
---@param opts table|nil Optional keyword arguments:
---             - method string|nil HTTP method to use. Defaults to GET.
---             - headers table|nil A table of key-value headers.
---             - follow_redirects boolean|nil Will follow redirects by default.
---             - data string|table|nil Data to send with the request. If a table, it will be json
---             encoded.
---
---             - on_complete nil|fun(response: table) Callback function when request is
---             successfully completed. The response has the following keys:
---                 - ok boolean Convience field showing whether or not the request
---                 was successful (status within 2XX range).
---                 - headers fun(): table<string, string> Function returning a table of response headers.
---                 - body fun(): string|nil Function returning response body. If method was HEAD,
---                 this is likely nil.
---                 - json fun(opts: table|nil): table Read the body as json. Optionally accepts
---                 opts from |vim.json.decode|. Will throw errors if body is not json-decodable.
---                 - method string The http method used in the most recent HTTP request.
---                 - status number The numerical response code. See https://developer.mozilla.org/en-US/docs/Web/HTTP/Status
---                 - status_text string The status text returned with the response.
---                 - size number The total amount of bytes that were downloaded. This
---                 is the size of the body/data that was transferred, excluding headers.
---                 - http_version number HTTP version used in the request.
---             - on_err nil|fun(errr: string[]) An optional function recieving a `stderr_buffered` string[] of curl
---             stderr. Without providing this function, fetch() will automatically raise an error
---             to the user. See |on_stderr| and `stderr_buffered`.
---@return number jobid A job id. See |job-control|.
---
--- Example:
--- <pre>lua
--- -- GET a url
--- vim.net.fetch("https://example.com/api/data", {
---   on_complete = function (response)
---     -- Lets read the response!
---
---     if response.ok then
---       -- Read response body
---       local body = response.body()
---     else
---   end
--- })
---
--- -- POST to a url, sending json and providing an authorization header
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
---       -- Read json response
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

  local job = vim.fn.jobstart(args, {
    on_stdout = function(_, data)
      out = data
    end,
    on_stderr = function(_, data)
      if opts.on_err ~= nil then
        return opts.on_err(data)
      end

      vim.notify('Failed to fetch: ' .. table.concat(data, '\n'), vim.log.levels.ERROR)
    end,
    on_exit = function(_, code)
      if opts.on_complete and code == 0 then
        local res = process_stdout(data)

        -- Since we use stdout_buffered, it is actually most safe to call on_compete from on_stdout.
        opts.on_complete(res)
      end
    end,
    stdout_buffered = true,
    stderr_buffered = true,
  })

  return job
end

--- Asynchronously download a file.
--- To read the response metadata, such as headers and body, use |fetch()|.
--- Accepts shares a few options with |vim.net.fetch()|, but not all of them.
---
---@param url string url
---@param path string A FULL download path. This function does not modify the path, you should use
---|fnnamemodify| with relative paths.
---@param opts table|nil Optional keyword arguments:
---             - method string|nil HTTP method to use. Defaults to GET.
---             - headers table|nil A table of key-value headers.
---             - follow_redirects boolean|nil Will follow redirects by default.
---             - data string|table|nil Data to send with the request. If a table, it will be json
---             encoded.
---             - on_complete nil|fun() Callback function when download successfully completed.
---             - on_err nil|fun(errr: string[]) An optional function recieving a `stderr_buffered` string[] of curl
---             stderr. Without providing this function, fetch() will automatically raise an error
---             to the user. See |on_stderr| and `stderr_buffered`.
---
--- Example:
--- <pre>lua
---
--- vim.net.download("https://raw.githubusercontent.com/neovim/neovim/master/README.md",
--- ".cache/download/location/readme.md", {
---   on_complete = function ()
---     vim.notify("File Downloaded", vim.log.levels.INFO)
---   end
--- })
---
--- </pre>
function M.download(url, path, opts)
  vim.validate({
    opts = { opts, 'table', true },
  })

  opts = opts or {}

  opts.download_location = path

  local args = createCurlArgs(url, opts)

  local job = vim.fn.jobstart(args, {
    on_exit = function(_, code)
      if opts.on_complete and code == 0 then
        opts.on_complete()
      end
    end,
    on_stderr = function(_, data)
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
