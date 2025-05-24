local M = {}

--- Downloads a file from the given URL to a specified location.
---
--- @param url string The URL to download from.
--- @param download_location string The file path where the content should be saved.
--- @param opts? table Optional parameters:
---   - verbose (boolean|nil): Enables verbose curl output.
---   - retry (integer|nil): Number of times to retry on transient failures (default: 3).
--- @param on_exit? fun(err?: string) Optional callback. If omitted, runs synchronously.
---
--- @return boolean|nil, string? True on success (sync); false/nil and error message on failure.
function M.download(url, download_location, opts, on_exit)
  vim.validate({
    url = { url, 'string' },
    download_location = { download_location, 'string' },
    opts = { opts, 'table', true },
    on_exit = { on_exit, 'function', true },
  })

  opts = opts or {}
  local retry = opts.retry or 3

  local args = { 'curl' }

  if opts.verbose then
    table.insert(args, '--verbose')
  else
    vim.list_extend(args, { '--silent', '--show-error', '--fail' })
  end

  vim.list_extend(args, {
    '--retry',
    tostring(retry),
    '--location',
    '--output',
    download_location,
    url,
  })

  if on_exit then
    vim.system(args, { text = true }, function(res)
      if res.code ~= 0 or res.stderr ~= '' then
        on_exit(res.stderr ~= '' and res.stderr or 'Download failed')
      else
        on_exit(nil)
      end
    end)
  else
    local job = vim.system(args, { text = true })
    local result = job:wait()

    if result.code ~= 0 then
      print(vim.inspect(result))
      local err = result.stderr
      if err == '' then
        err = string.format('Download failed (exit code %d)', result.code)
      else
        err = string.format('%s (exit code %d)', err, result.code)
      end
      return false, err
    end

    return true
  end
end

--- Makes an HTTP GET request to the given URL and returns the response body.
---
--- This is a barebones implemenation intended for internal use.
---
--- @param url string The URL to download from.
--- @param opts? table Optional parameters:
---   - verbose (boolean|nil): Enables verbose curl output.
---   - retry (integer|nil): Number of times to retry on transient failures (default: 3).
--- @param on_exit? fun(err?: string, content?: string) Optional callback. If omitted, runs synchronously.
---
--- @return string|nil, string? On success (sync): content; On failure (sync) nil and error message.
function M.request(url, opts, on_exit)
  vim.validate({
    url = { url, 'string' },
    opts = { opts, 'table', true },
    on_exit = { on_exit, 'function', true },
  })

  opts = opts or {}
  local retry = opts.retry or 3

  local args = { 'curl' }

  if opts.verbose then
    table.insert(args, '--verbose')
  else
    vim.list_extend(args, { '--silent', '--show-error', '--fail' })
  end

  vim.list_extend(args, {
    '--retry',
    tostring(retry),
    '--location',
    url,
  })

  if on_exit then
    vim.system(args, { text = true }, function(res)
      if res.code ~= 0 or res.stderr ~= '' then
        on_exit(res.stderr ~= '' and res.stderr or 'Request failed', nil)
      else
        on_exit(nil, res.stdout)
      end
    end)
  else
    local job = vim.system(args, { text = true })
    local result = job:wait()

    if result.code ~= 0 then
      local err = result.stderr
      if err == '' then
        err = string.format('Request failed (exit code %d)', result.code)
      else
        err = string.format('%s (exit code %d)', err, result.code)
      end
      return nil, err
    end
    return result.stdout, nil
  end
end

return M
