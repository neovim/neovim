---@class _autocmd.Event
---@field id number
---@field event string
---@field group number|nil
---@field match string
---@field buf number
---@field file string
---@field data any

local id = vim.api.nvim_create_augroup('LuaNetwork', {
  clear = true,
})

vim.api.nvim_create_autocmd({ 'BufReadCmd' }, {
  pattern = '*',
  group = id,
  desc = 'Lua Network Buffer Read Handler',
  ---@param ev _autocmd.Event
  callback = function(ev)
    local view = vim.fn.winsaveview()
    local buf = ev.buf

    local protocol, url, credentials = vim.net._parse_filename(ev.file)
    if not vim.list_contains(vim.net.supported_protocols(), protocol) then
      return vim.notify(
        ("The protocol %s isn't supported by vim.net or your curl version. Run `:checkhealth vim.net` for more info"):format(
          protocol
        )
      )
    end

    if protocol == 'http' or protocol == 'https' or protocol == 'ftp' or protocol == 'scp' then
      vim.net.fetch(url, {
        credentials = credentials,
        on_exit = vim.schedule_wrap(function(err, result)
          if err then
            return vim.notify(err, vim.logl.levels.ERROR)
          end

          local text = vim.split(result.text(), '\n')

          vim.api.nvim_buf_set_lines(buf, 0, -1, true, text)

          local ft = vim.filetype.match({
            filename = url,
            contents = text,
          })
          if ft then
            vim.cmd.set(('filetype=%s'):format(ft))
          end

          vim.fn.winrestview(view)
        end),
      })
    end
  end,
})

vim.api.nvim_create_autocmd({ 'BufWriteCmd' }, {
  pattern = '*',
  group = id,
  desc = 'Lua Network Write Handler',
  ---@param ev _autocmd.Event
  callback = function(ev)
    local buf = ev.buf

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local path = os.tmpname()
    vim.fn.writefile(lines, path)

    local protocol, url, credentials = vim.net._parse_filename(ev.file)
    if not vim.list_contains(vim.net.supported_protocols(), protocol) then
      return vim.notify(
        ("The protocol %s isn't supported by your curl version. Run `:checkhealth vim.net` for more info"):format(
          protocol
        )
      )
    end

    if protocol == 'ftp' or protocol == 'scp' then
      vim.net.fetch(url, {
        credentials = credentials,
        upload_file = path,
        on_exit = vim.schedule_wrap(function()
          if not vim.o.cpo:find('+') then
            vim.cmd(':set modified&vim')
          end
        end),
      })
    end
  end,
})

vim.api.nvim_create_autocmd({ 'FileReadCmd' }, {
  pattern = '*',
  group = id,
  desc = 'Lua Network File Read Handler',
  ---@param ev _autocmd.Event
  callback = function(ev)
    local view = vim.fn.winsaveview()
    local buf = ev.buf
    local protocol, url, credentials = vim.net._parse_filename(ev.file)
    if not vim.list_contains(vim.net.supported_protocols(), protocol) then
      return vim.notify(
        ("The protocol %s isn't supported by your curl version. Run `:checkhealth vim.net` for more info"):format(
          protocol
        )
      )
    end

    if protocol == 'http' or protocol == 'https' or protocol == 'ftp' or protocol == 'scp' then
      vim.net.fetch(url, {
        credentials = credentials,
        on_complete = function(err, result)
          if err then
            return vim.notify(err, vim.log.levels.ERROR)
          end

          local text = vim.split(result.text(), '\n')

          local cursor_row = vim.api.nvim_win_get_cursor(0)[1]

          vim.api.nvim_buf_set_lines(buf, cursor_row, cursor_row, true, text)

          vim.fn.winrestview(view)
        end,
      })
    end
  end,
})

vim.api.nvim_create_autocmd({ 'FileWriteCmd' }, {
  pattern = '*',
  group = id,
  desc = 'Lua Network Partial Write Handler',
  ---@param ev _autocmd.Event
  callback = function(ev)
    local buf = ev.buf

    local start_row = vim.api.nvim_buf_get_mark(buf, '[')[1]
    local end_row = vim.api.nvim_buf_get_mark(buf, ']')[1]

    local lines = vim.api.nvim_buf_get_lines(buf, start_row - 1, end_row, true)
    local path = os.tmpname()
    vim.fn.writefile(lines, path)

    local protocol, url, credentials = vim.net._parse_filename(ev.file)
    if not vim.list_contains(vim.net.supported_protocols(), protocol) then
      return vim.notify(
        ("The protocol %s isn't supported by your curl version. Run `:checkhealth vim.net` for more info"):format(
          protocol
        )
      )
    end
    if protocol == 'scp' or protocol == 'ftp' then
      vim.net.fetch(url, {
        credentials = credentials,
        upload_file = path,
        on_exit = function() end,
      })
    end
  end,
})
