if not vim.g.lua_net_enable then
  return
end

local function url_safe_encode_byte(byte)
  local char_map = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'
  return char_map:sub(byte % 64 + 1, byte % 64 + 1)
end

-- The main function to generate a path-safe string
local function generate_path_safe_string(len)
  local path_safe_string = ''
  local bytes = vim.loop.random(len)

  for i = 1, len do
    local encoded_byte = url_safe_encode_byte(bytes:byte(i))
    path_safe_string = path_safe_string .. encoded_byte
  end

  return path_safe_string
end

local function get_buf_tmp_path()
  if vim.b.lua_net_buf_id == nil then
    vim.b.lua_net_buf_id = generate_path_safe_string(8)
  end

  local username = vim.fn.expand('$USER')
  local root = '/tmp/nvim.' .. username

  if vim.fn.isdirectory(root) == 0 then
    vim.fn.mkdir(root)
  end

  return root .. '/' .. vim.b.lua_net_buf_id
end

local id = vim.api.nvim_create_augroup('LuaNetwork', {
  clear = true,
})

vim.api.nvim_create_autocmd({ 'BufReadCmd' }, {
  pattern = { 'https://*', 'http://*', 'ftp://*', 'scp://*' },
  group = id,
  desc = 'Lua Network Buffer Read Handler',
  callback = function(ev)
    local view = vim.fn.winsaveview()
    local buf = ev.buf
    local file = ev.file

    local complete = false
    local err

    vim.b.lua_net_buf_id = generate_path_safe_string(8)

    vim.net.fetch(file, {
      on_complete = function(result)
        local text = vim.split(result.text(), '\n')

        vim.api.nvim_buf_set_lines(buf, -2, -1, false, text)

        vim.fn.winrestview(view)

        local ft = vim.filetype.match({
          filename = file,
          contents = vim.g.lua_net_ft_full and text or nil,
        })

        if ft then
          vim.cmd(':set ft=' .. ft)
        end

        complete = true
      end,
      on_err = function(data)
        err = data
        complete = true
      end,
    })

    -- block until complete
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
  callback = function(ev)
    local view = vim.fn.winsaveview()
    local buf = ev.buf
    local file = ev.file

    local complete = false
    local err

    vim.net.fetch(file, {
      on_complete = function(result)
        local text = vim.split(result.text(), '\n')

        local pos = vim.api.nvim_win_get_cursor(0)

        vim.api.nvim_buf_set_lines(buf, pos[1], pos[1], false, text)

        vim.fn.winrestview(view)

        complete = true
      end,
      on_err = function(data)
        err = data
        complete = true
      end,
    })

    -- block until complete
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
  pattern = { 'scp://*' },
  group = id,
  desc = 'Lua Network Write Handler',
  callback = function(ev)
    local buf = ev.buf
    local file = ev.file

    local complete = false
    local err

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    local path = get_buf_tmp_path()

    vim.fn.writefile(lines, path)

    vim.net.fetch(file, {
      upload_file = path,
      on_complete = function()
        if not string.find(vim.o.cpo, '+') then
          vim.cmd(':set modified&vim')
        end

        complete = true
      end,
      on_err = function(data)
        err = data
      end,
    })

    -- block until complete
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
  callback = function(ev)
    local buf = ev.buf
    local file = ev.file

    local complete = false
    local err

    local mark_start = vim.api.nvim_buf_get_mark(buf, '[')
    local mark_end = vim.api.nvim_buf_get_mark(buf, ']')

    local lines = vim.api.nvim_buf_get_lines(buf, mark_start[1] - 1, mark_end[1], true)

    local path = get_buf_tmp_path()

    vim.fn.writefile(lines, path)

    vim.net.fetch(file, {
      upload_file = path,
      on_complete = function()
        complete = true
      end,
      on_err = function(data)
        err = data
      end,
    })

    -- block until complete
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
