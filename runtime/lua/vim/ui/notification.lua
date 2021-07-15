local utils = require('vim.ui._utils')

vim.api.nvim_command("hi NotificationInfo guifg=#80ff95")
vim.api.nvim_command("hi NotificationWarning guifg=#fff454")
vim.api.nvim_command("hi NotificationError guifg=#c44323")

local function notification(message, options)
  if type(message) == "string" then
    message = { message }
  end

  if type(message) ~= "table" then
    error("First argument has to be either a table or a string")
  end

  options = options or {}
  options.type = options.type or "info"
  options.delay = options.delay or 2000

  local width = utils.tbl_longest_str(message)
  local height = #message
  local row = options.row
  local col = vim.api.nvim_get_option("columns") - 3

  local buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, message)

  local window = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    anchor = "SE",
    height = height,
    style = "minimal"
  })

  local border_buf = vim.api.nvim_create_buf(false, true)
  local border_buf_lines = {}
  width = width + 2

  table.insert(border_buf_lines, string.format("╭%s╮", string.rep("─", width)))

  for _=1,height do
    table.insert(border_buf_lines, string.format("│%s│", string.rep(" ", width)))
  end

  table.insert(border_buf_lines, string.format("╰%s╯", string.rep("─", width)))

  vim.api.nvim_buf_set_lines(border_buf, 0, -1, false, border_buf_lines)

  local border_win = vim.api.nvim_open_win(border_buf, false, {
    relative = "editor",
    row = row + 1,
    col = col + 3,
    width = width + 3,
    anchor = "SE",
    height = height + 2,
    style = "minimal"
  })

  if options.type == "info" then
    vim.api.nvim_win_set_option(window, "winhl", "Normal:NotificationInfo")
    vim.api.nvim_win_set_option(border_win, "winhl", "Normal:NotificationInfo")
  elseif options.type == "warning" then
    vim.api.nvim_win_set_option(window, "winhl", "Normal:NotificationWarning")
    vim.api.nvim_win_set_option(border_win, "winhl", "Normal:NotificationWarning")
  else
    vim.api.nvim_win_set_option(window, "winhl", "Normal:NotificationError")
    vim.api.nvim_win_set_option(border_win, "winhl", "Normal:NotificationError")
  end

  local timer
  local delete = function()

    if timer:is_active() then
      timer:stop()
    end

    if vim.fn.winbufnr(window) ~= -1 then
      vim.api.nvim_win_close(window, false)
      vim.api.nvim_win_close(border_win, false)
    end
  end

  timer = vim.defer_fn(delete, options.delay)

  return {
    window = window,
    height = height,
    width = width,
    row = row,
    col = col,
    border = {
      window = border_win,
      buffer = border_buf
    },
    content = message,
    delete = delete
  }

end

return notification
