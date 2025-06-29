local M = {}

--- Makes an HTTP GET request to the given URL.
---
--- This function operates in two modes:
---   - Synchronous (blocking): If `on_response` is omitted, it waits for the
---   request to complete and returns the result.
---   - Asynchronous (non-blocking): If `on_response` is provided, it returns
---   immediately and invokes the callback with the result later.
---
--- @param url string The URL for the request.
--- @param opts? table Optional parameters:
---   - `verbose` (boolean|nil): Enables curl verbose output.
---   - `retry`   (integer|nil): Number of retries on transient failures (default: 3).
---   - `output`  (string|nil): A file path to save the response body to. If set, the success value will be `true` instead of the response body.
--- @param on_response? fun(err?: string, content?: string|boolean) Optional callback for async execution.
---   It is invoked with `(err, nil)` on failure or `(nil, content)` on success.
--- @return string|boolean|nil In sync mode, returns the response body or `true` on success; otherwise `nil`
--- @return string|nil In sync mode, returns an error message on failure.
function M.request(url, opts, on_response)
  vim.validate({
    url = { url, 'string' },
    opts = { opts, 'table', true },
    on_response = { on_response, 'function', true },
  })

  opts = opts or {}
  local retry = opts.retry or 3

  -- Build curl command
  local args = { 'curl' }
  if opts.verbose then
    table.insert(args, '--verbose')
  else
    vim.list_extend(args, { '--silent', '--show-error', '--fail' })
  end
  table.insert(args, '--location')
  table.insert(args, '--retry')
  table.insert(args, tostring(retry))

  if opts.output then
    table.insert(args, '--output')
    table.insert(args, opts.output)
  end

  table.insert(args, url)

  local job_result = {}

  local function on_exit(res)
    if res.code ~= 0 then
      job_result.err = (res.stderr ~= '' and res.stderr)
        or string.format('Request failed with exit code %d', res.code)
    else
      job_result.content = opts.output and true or res.stdout
    end

    if on_response then
      on_response(job_result.err, job_result.content)
    end
  end

  local job = vim.system(args, { text = true }, on_exit)

  if not on_response then
    job:wait()
    return job_result.content, job_result.err
  end
end

return M
