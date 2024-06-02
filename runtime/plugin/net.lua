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
  pattern = { 'https://*', 'http://*', 'ftp://*', 'scp://*' },
  group = id,
  desc = 'Lua Network Buffer Read Handler',
  ---@param ev _autocmd.Event
  callback = function(ev)
    local view = vim.fn.winsaveview()
    local buf = ev.buf
    local url = ev.file

    local complete = false
    local err ---@type string[]

    local file, credentials = vim.net._get_filename_and_credentials(url)

    vim.net.fetch(file, {
      user = credentials,
      on_complete = function(result)
        local text = vim.split(result.text(), '\n')

        vim.api.nvim_buf_set_lines(buf, -2, -1, false, text)

        vim.fn.winrestview(view)

        local ft = vim.filetype.match({
          filename = file,
          contents = text,
        })

        if ft then
          vim.cmd(':set ft=' .. ft)
        end

        complete = true
      end,
      on_err = function(data, code)
        complete = true

        if code == 67 then
          return vim.notify(
            'Authentication error (reading buffer): ' .. table.concat(err, '\n'),
            vim.log.levels.ERROR
          )
        end

        err = data
      end,
    })

    local block, code = vim.wait(10000, function()
      return complete
    end)

    if block == false and code == -2 then
      return
    end

    if block == false and code == -1 and err then
      vim.notify(
        'Failed to fetch ' .. file .. ': ' .. table.concat(err, '\n'),
        vim.log.levels.ERROR
      )
    end
  end,
})

vim.api.nvim_create_autocmd({ 'FileReadCmd' }, {
  pattern = { 'https://*', 'http://*', 'ftp://*', 'scp://*' },
  group = id,
  desc = 'Lua Network File Read Handler',
  ---@param ev _autocmd.Event
  callback = function(ev)
    local view = vim.fn.winsaveview()
    local buf = ev.buf

    local complete = false
    local err ---@type string[]

    local file, user_pass = vim.net._get_filename_and_credentials(ev.file)

    vim.net.fetch(file, {
      user = user_pass,
      on_complete = function(result)
        local text = vim.split(result.text(), '\n')

        local pos = vim.api.nvim_win_get_cursor(0)

        vim.api.nvim_buf_set_lines(buf, pos[1], pos[1], false, text)

        vim.fn.winrestview(view)

        complete = true
      end,
      on_err = function(data, code)
        complete = true

        if code == 67 then
          return vim.notify(
            'Authentication error (reading file): ' .. table.concat(err, '\n'),
            vim.log.levels.ERROR
          )
        end

        err = data
      end,
    })

    local block, code = vim.wait(10000, function()
      return complete
    end)

    if block == false and code == -2 then
      return
    end

    if block == false and code == -1 and err then
      vim.notify('Failed to read ' .. file .. ': ' .. table.concat(err, '\n'), vim.log.levels.ERROR)
    end
  end,
})

vim.api.nvim_create_autocmd({ 'BufWriteCmd' }, {
  pattern = { 'scp://*', 'ftp://*' },
  group = id,
  desc = 'Lua Network Write Handler',
  ---@param ev _autocmd.Event
  callback = function(ev)
    local buf = ev.buf

    local complete = false
    local err ---@type string[]

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    local path = os.tmpname()

    vim.fn.writefile(lines, path)

    local file, user_pass = vim.net._get_filename_and_credentials(ev.file)

    vim.net.fetch(file, {
      user = user_pass,
      upload_file = path,
      on_complete = function()
        if not string.find(vim.o.cpo, '+') then
          vim.cmd(':set modified&vim')
        end

        complete = true
      end,
      on_err = function(data, code)
        complete = true
        err = data

        if code == 67 then
          return vim.notify(
            'Authentication error (writing buffer): ' .. table.concat(err, '\n'),
            vim.log.levels.ERROR
          )
        end
      end,
    })

    local block, code = vim.wait(10000, function()
      return complete
    end)

    if block == false and code == -2 then
      return
    end

    if block == false and code == -1 and err then
      vim.notify(
        'Failed to write to ' .. file .. ': ' .. table.concat(err, '\n'),
        vim.log.levels.ERROR
      )
    end
  end,
})

vim.api.nvim_create_autocmd({ 'FileWriteCmd' }, {
  pattern = { 'scp://*' },
  group = id,
  desc = 'Lua Network Partial Write Handler',
  ---@param ev _autocmd.Event
  callback = function(ev)
    local buf = ev.buf

    local complete = false
    local err ---@type string[]

    local mark_start = vim.api.nvim_buf_get_mark(buf, '[')
    local mark_end = vim.api.nvim_buf_get_mark(buf, ']')

    local lines = vim.api.nvim_buf_get_lines(buf, mark_start[1] - 1, mark_end[1], true)

    local path = os.tmpname()

    vim.fn.writefile(lines, path)

    local file, user_pass = vim.net._get_filename_and_credentials(ev.file)

    vim.net.fetch(file, {
      user = user_pass,
      upload_file = path,
      on_complete = function()
        complete = true
      end,
      on_err = function(data, code)
        complete = true

        if code == 67 then
          return vim.notify(
            'Authentication error (writing file): ' .. table.concat(err, '\n'),
            vim.log.levels.ERROR
          )
        end

        err = data
      end,
    })

    local block, code = vim.wait(10000, function()
      return complete
    end)

    if block == false and code == -2 then
      return
    end

    if block == false and code == -1 and err then
      vim.notify(
        'Failed to partially write ' .. file .. ': ' .. table.concat(err, '\n'),
        vim.log.levels.ERROR
      )
    end
  end,
})
