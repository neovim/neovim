local M = {}

---@class vim.net.request.Opts
---@inlinedoc
---
---Enables verbose output.
---@field verbose? boolean
---
---Number of retries on transient failures (default: 3).
---@field retry? integer
---
---File path to save the response body to.
---@field outpath? string
---
---Buffer to save the response body to.
---@field outbuf? integer

---@class vim.net.request.Response
---
---The HTTP body of the request
---@field body string

--- Makes an HTTP GET request to the given URL, asynchronously passing the result to the specified
--- `on_response`, `outpath` or `outbuf`.
---
--- Examples:
--- ```lua
--- -- Write response body to file
--- vim.net.request('https://neovim.io/charter/', {
---   outpath = 'vision.html',
--- })
---
--- -- Process the response
--- vim.net.request(
---   'https://api.github.com/repos/neovim/neovim',
---   {},
---   function (err, res)
---     if err then return end
---     local stars = vim.json.decode(res.body).stargazers_count
---     vim.print(('Neovim currently has %d stars'):format(stars))
---   end
--- )
---
--- -- Write to both file and current buffer, but cancel it
--- local job = vim.net.request('https://neovim.io/charter/', {
---   outpath = 'vision.html',
---   outbuf = 0,
--- })
--- job:close()
--- ```
---
--- @param url string The URL for the request.
--- @param opts? vim.net.request.Opts
--- @param on_response? fun(err: string?, response: vim.net.request.Response?)
--- Callback invoked on request completion. The `body` field in the response
--- parameter contains the raw response data (text or binary).
--- @return { close: fun() } # Table with method to cancel, similar to [vim.SystemObj].
function M.request(url, opts, on_response)
  vim.validate('url', url, 'string')
  vim.validate('opts', opts, 'table', true)
  vim.validate('on_response', on_response, 'function', true)

  opts = opts or {}
  local retry = opts.retry or 3

  -- Build curl command
  local args = { 'curl' }
  if opts.verbose then
    table.insert(args, '--verbose')
  else
    vim.list_extend(args, { '--silent', '--show-error', '--fail' })
  end
  vim.list_extend(args, { '--location', '--retry', tostring(retry) })

  if opts.outpath then
    vim.list_extend(args, { '--output', opts.outpath })
  end

  table.insert(args, url)

  local job = vim.system(args, {}, function(res)
    ---@type string?, vim.net.request.Response?
    local err, response = nil, nil
    if res.signal ~= 0 then
      err = ('Request killed with signal %d'):format(res.signal)
    elseif res.code ~= 0 then
      err = res.stderr ~= '' and res.stderr or ('Request failed with exit code %d'):format(res.code)
    else
      if on_response then
        response = { body = res.stdout or '' }
      end
    end

    -- nvim_buf_is_loaded and nvim_buf_set_lines are not allowed in fast context
    vim.schedule(function()
      if res.code == 0 and opts.outbuf and vim.api.nvim_buf_is_loaded(opts.outbuf) then
        local lines = vim.split(res.stdout, '\n', { plain = true })
        vim.api.nvim_buf_set_lines(opts.outbuf, 0, -1, true, lines)
      end
    end)

    if on_response then
      on_response(err, response)
    end
  end)

  return {
    close = function()
      job:kill('sigint')
    end,
  }
end

return M
