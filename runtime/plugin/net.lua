if not vim.g.lua_net_enable then
  return
end

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
  pattern = {
    'https://*',
    'http://*',
    'ftp://*',
    'scp://*',
    'rcp://*',
    'dav://*',
    'davs://*',
    'rsync://*',
    'sftp://*',
  },
  group = id,
  desc = 'Lua Network Buffer Read Handler',
  ---@param ev _autocmd.Event
  callback = function(ev)
    local view = vim.fn.winsaveview()
    local buf = ev.buf
    local url = ev.file

    local file, credentials = vim.net._get_filename_and_credentials(url)

    vim.net.fetch(file, {
      user = credentials,
      on_exit = function(err, result)
        if err then
          return vim.notify(err, vim.logl.levels.ERROR)
        end

        local text = vim.split(result.text(), '\n')

        vim.api.nvim_buf_set_lines(buf, 0, -1, true, text)

        local ft = vim.filetype.match({
          filename = file,
          contents = text,
        })
        if ft then
          vim.cmd.set(('filetype=%s'):format(ft))
        end

        vim.fn.winrestview(view)
      end,
    })
  end,
})

vim.api.nvim_create_autocmd({ 'FileReadCmd' }, {
  pattern = {
    'https://*',
    'http://*',
    'ftp://*',
    'scp://*',
    'rcp://*',
    'dav://*',
    'davs://*',
    'rsync://*',
    'sftp://*',
  },
  group = id,
  desc = 'Lua Network File Read Handler',
  ---@param ev _autocmd.Event
  callback = function(ev)
    local view = vim.fn.winsaveview()
    local buf = ev.buf

    local file, user_pass = vim.net._get_filename_and_credentials(ev.file)

    vim.net.fetch(file, {
      user = user_pass,
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
  end,
})

vim.api.nvim_create_autocmd({ 'BufWriteCmd' }, {
  pattern = {
    'https://*',
    'http://*',
    'ftp://*',
    'scp://*',
    'rcp://*',
    'dav://*',
    'davs://*',
    'rsync://*',
    'sftp://*',
  },
  group = id,
  desc = 'Lua Network Write Handler',
  ---@param ev _autocmd.Event
  callback = function(ev)
    local buf = ev.buf

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    local path = os.tmpname()

    vim.fn.writefile(lines, path)

    local file, user_pass = vim.net._get_filename_and_credentials(ev.file)

    vim.net.fetch(file, {
      user = user_pass,
      upload_file = path,
      on_exit = function()
        if not vim.o.cpo:find('+') then
          vim.cmd(':set modified&vim')
        end
      end,
    })
  end,
})

vim.api.nvim_create_autocmd({ 'FileWriteCmd' }, {
  pattern = {
    'https://*',
    'http://*',
    'ftp://*',
    'scp://*',
    'rcp://*',
    'dav://*',
    'davs://*',
    'rsync://*',
    'sftp://*',
  },
  group = id,
  desc = 'Lua Network Partial Write Handler',
  ---@param ev _autocmd.Event
  callback = function(ev)
    local buf = ev.buf

    local mark_start = vim.api.nvim_buf_get_mark(buf, '[')
    local mark_end = vim.api.nvim_buf_get_mark(buf, ']')

    local lines = vim.api.nvim_buf_get_lines(buf, mark_start[1] - 1, mark_end[1], true)

    local path = os.tmpname()

    vim.fn.writefile(lines, path)

    local file, user_pass = vim.net._get_filename_and_credentials(ev.file)

    vim.net.fetch(file, {
      user = user_pass,
      upload_file = path,
      on_exit = function() end,
    })
  end,
})
