if vim.g.loaded_nvim_net_plugin ~= nil then
  return
end
vim.g.loaded_nvim_net_plugin = true

local augroup = vim.api.nvim_create_augroup('nvim.net.remotefile', {})
local url_patterns = { 'http://*', 'https://*' }

local archive_patterns = {
  { suffix = '.tar.gz', kind = 'tar' },
  { suffix = '.tar.bz2', kind = 'tar' },
  { suffix = '.tar.xz', kind = 'tar' },
  { suffix = '.txz', kind = 'tar' },
  { suffix = '.tar', kind = 'tar' },
  { suffix = '.zip', kind = 'zip' },
}

---@param url string
---@return string
local function url_path(url)
  return (url:gsub('[?#].*$', ''))
end

---@param url string
---@return 'zip'|'tar'?
local function archive_type(url)
  local path = url_path(url)
  for _, pattern in ipairs(archive_patterns) do
    if vim.endswith(path, pattern.suffix) then
      return pattern.kind
    end
  end
end

vim.api.nvim_create_autocmd('BufReadCmd', {
  group = augroup,
  pattern = url_patterns,
  desc = 'Edit remote files (:edit https://example.com)',
  callback = function(ev)
    if vim.fn.executable('curl') ~= 1 then
      vim.notify('vim.net.request: curl not found', vim.log.levels.WARN)
      return
    end

    local url = ev.file
    local archive_kind = archive_type(url)

    vim.notify(('Fetching %s …'):format(url), vim.log.levels.INFO)

    if archive_kind then
      -- XXX: zipPlugin.vim, tarPlugin.vim don't work with non-file buffers.
      local tmpfile = vim.fn.tempname()

      vim.net.request(
        url,
        { outpath = tmpfile },
        vim.schedule_wrap(function(err)
          if err then
            vim.notify(('Failed to fetch %s: %s'):format(url, err), vim.log.levels.ERROR)
            return
          end

          if archive_kind == 'zip' then
            vim.fn['zip#Browse'](tmpfile)
          else
            vim.fn['tar#Browse'](tmpfile)
          end

          vim.bo[ev.buf].modified = false
          vim.notify(('Loaded %s'):format(url), vim.log.levels.INFO)
        end)
      )
      return
    end

    vim.net.request(
      url,
      { outbuf = ev.buf },
      vim.schedule_wrap(function(err, _)
        if err then
          vim.notify(('Failed to fetch %s: %s'):format(url, err), vim.log.levels.ERROR)
          return
        end

        vim.api.nvim_exec_autocmds('BufRead', { group = 'filetypedetect', buffer = ev.buf })
        vim.bo[ev.buf].modified = false
        vim.notify(('Loaded %s'):format(url), vim.log.levels.INFO)
      end)
    )
  end,
})

vim.api.nvim_create_autocmd('FileReadCmd', {
  group = augroup,
  pattern = url_patterns,
  desc = 'Read remote files (:read https://example.com)',
  callback = function(ev)
    if vim.fn.executable('curl') ~= 1 then
      vim.notify('vim.net.request: curl not found', vim.log.levels.WARN)
      return
    end

    local url = ev.file
    vim.notify(('Fetching %s …'):format(url), vim.log.levels.INFO)

    vim.net.request(
      url,
      {},
      vim.schedule_wrap(function(err, response)
        if err or not response then
          vim.notify(('Failed to fetch %s: %s'):format(url, err), vim.log.levels.ERROR)
          return
        end

        -- Start inserting the response at the line number given by read (e.g. :10read).
        -- FIXME: Doesn't work for :0read as '[ is set to 1. See #7177 for possible solutions.
        local start = vim.fn.line("'[")
        local lines = vim.split(response.body or '', '\n', { plain = true })
        vim.api.nvim_buf_set_lines(ev.buf, start, start, true, lines)
        vim.notify(('Loaded %s'):format(url), vim.log.levels.INFO)
      end)
    )
  end,
})
