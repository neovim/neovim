local id = vim.api.nvim_create_augroup('LuaNetwork', {
        clear = true,
    })

local namespace = vim.api.nvim_create_namespace('LuaNetwork')

vim.api.nvim_create_autocmd({ 'BufReadCmd' }, {
    pattern = { 'https://*', 'http://*' },
    group = id,
    desc = 'Lua Network File Handler',
    callback = function(ev)
      local view = vim.fn.winsaveview()
      local buf = ev.buf
      local file = ev.file

      local complete = false
      local err

      local mark = vim.api.nvim_buf_set_extmark(buf, namespace, 0, 0, {
              virt_text = {
                  { 'Loading ' .. file .. '...', 'Comment' },
              },
          })

      vim.net.fetch(file, {
          on_complete = function(result)
            local text = vim.split(result.text(), '\n')

            vim.api.nvim_buf_set_lines(buf, -2, -1, false, text)

            vim.fn.winrestview(view)

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

      -- Block timed out
      if block == false and code == -1 then
        vim.notify(
            'Failed to fetch ' .. file .. ': ' .. table.concat(err, '\n'),
            vim.log.levels.ERROR
        )
      end

      vim.api.nvim_buf_del_extmark(buf, namespace, mark)
    end,
})
