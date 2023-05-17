local M = {}

--- Perform an asyncronous network request.
---
--- Example:
--- <pre>lua
--- vim.net.fetch("https://example.com/api/get", {
---   on_complete = function (response)
---     -- Lets read the response!
---
---     if response.ok then
---       -- Read response text
---       local body = response.text
---     else
---   end,
--- })
---
--- -- POST to a url, sending a table as JSON and providing an authorization header
--- vim.net.fetch("https://example.com/api/post", {
---   method = "POST",
---   data ={
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
---
--- @note `opts.multipart_form`, `opts.upload_file`, and `opts.data` are mutually exclusive.
--- @see man://libcurl-errors
---
--- @param url string
--- @param opts table|nil Optional keyword arguments:
---   - multipart_form table<string,string>|nil Key-Value form data. Implies a `multipart/form-data`
---   request.
---   - data string|table|nil Data to send with the request. A table implies a JSON request.
---   - upload_file string|nil A file to upload. Can be relative.
---   - headers table<string, string | string[]>|nil Headers to send. A header can have
---   multiple values.
---   - method string|nil HTTP method to use. Defaults to GET.
---   - user string|nil User-password authentication in `user:pass` format.
---   - redirect string|nil Control redirect follow behavior. Defaults to `follow`.
---   Posible values include:
---     - `follow`: Follow all redirects when fetching a resource.
---     - `none`: Do not follow redirects.
---   - on_complete fun(response: table)|nil Optional callback when response completes. The
---   `response` table has the following values:
---     - ok: bool Response status was within 200-299 range.
---     - text: string Response body. Empty if `method` was HEAD.
---     - lines: string[] Response in lines. Empty if `method` was HEAD.
---     - json: fun(): table JSON response as a table. Only use if you expect a JSON response.
---     - headers: table<string, string> Header key-values. Multiple values are sperated by `,`.
---     - status: number HTTP status.
---   - on_err fun(code: number, err: string)|nil Used when request fails to be performed.
---   Returned values are:
---     - `code`: `CURLcode`, see man://libcurl-errors for possible error codes. Report errors you
---     feel neovim itself caused to the issue tracker!
---     - `err`: Human readable error string, may or may not be empty.
function M.fetch(url, opts)
  opts = opts and opts or {}
  opts.headers = opts.headers and opts.headers or {}

  opts._on_complete = opts.on_complete

  opts.on_complete = function(response)
    local cache = {}

    if not opts._on_complete then
      return
    end

    response.lines = function()
      if not cache.lines then
        cache.lines = vim.split(response.text, '\n')
      end

      return cache.lines
    end

    response.json = function()
      if not cache.json then
        cache.json = vim.json.decode(response.text)
      end

      return cache.json
    end

    response.ok = response.status >= 200 and response.status <= 299

    return opts._on_complete(response)
  end

  local on_err = function(code, err)
    if not opts.on_err then
      vim.notify('(vim.net.fetch) Error fetching resource: ' .. err, vim.log.levels.ERROR)
      return
    end

    return opts.on_err(code, err)
  end

  if type(opts.data) == 'table' then
    opts.data = vim.json.encode(opts.data)
    opts.headers['Content-Type'] = 'application/json'
  end

  if opts.upload_file ~= nil then
    opts.upload_file = vim.fn.fnameescape(vim.fn.fnamemodify(opts.upload_file, ':p'))
  end

  return vim._fetch(url, on_err, opts)
end

return M
