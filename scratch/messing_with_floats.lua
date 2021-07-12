package.loaded['plenary.window.float'] = nil

MyTable = MyTable or {}

local p_float = require('plenary.window.float')
local log = require('train._log')

function CreateFloatingWin(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local floatwin = p_float.percentage_range_window(
    {0.1, 0.8},
    0.8,
    { bufnr = bufnr }
  )

  return floatwin.win
end

function SetFloatingStuff(win_id, cursor, motion)
  log.info(" win_id: %s", win_id)
  log.info(" win_id: %s", vim.fn.win_getid())

  log.info(" inserting motion: %s / %s", motion.movement, vim.inspect(cursor))
  local row = cursor[1] - 1
  local col = cursor[2]

  local win_position = vim.api.nvim_win_get_position(win_id)
  log.info(" win_position: %s", vim.inspect(win_position))

  local use_buf_position = true
  local window_opts
  if use_buf_position then
    window_opts = {
      relative = 'win',
      win = win_id,
      bufpos = {row, col},
      width = string.len(motion.movement),
      height = 1,
      row = win_position[1],
      col = win_position[2],
      focusable = false,
      style = 'minimal',
    }
  else
    window_opts = {
      relative = 'editor',
      width = string.len(motion.movement),
      height = 1,
      row = win_position[1] + row,
      col = win_position[2] + col,
      focusable = false,
      style = 'minimal',
    }
  end
  log.info(" resulting window_opts: %s", vim.inspect(window_opts))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, {motion.movement})

  local new_win_id = vim.api.nvim_open_win(buf, false, window_opts)
  -- TODO: Instead of just using error, you should do random ones
  vim.api.nvim_win_set_option(new_win_id, 'winhl', 'Normal:Error')

  table.insert(MyTable, new_win_id)

  return win_id
end

function ClearWindows()
  table.foreach(MyTable, function(k, v)
    if vim.api.nvim_win_is_valid(v) then
      vim.api.nvim_win_close(v, true)
    end
  end)
end

--[[
lua my_win = CreateFloatingWin()
lua SetFloatingStuff(my_win, {4, 4}, {movement="ASDF"})
lua ClearWindows()
--]]
