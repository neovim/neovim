local ui = {}

ui.open_floating_preview = function(self, contents, filetype)
  local pos = vim.api.nvim_call_function('getpos', { '.' })

  local width = 0
  local height = 0

  for _, line in pairs(contents) do
    local line_width = vim.api.nvim_call_function('strdisplaywidth', { line })
    if line_width > width then width = line_width end
    height = height + 1
  end

  -- Add right margin
  width = width + 1

  local floating_bufnr = vim.api.nvim_create_buf(false, true)

  local float_option = self.get_floating_window_option(pos, width, height)
  local floating_winnr = vim.api.nvim_open_win(floating_bufnr, true, float_option)

  vim.api.nvim_buf_set_lines(floating_bufnr, 0, -1, true, contents)

  if filetype ~= nil then
    vim.api.nvim_buf_set_var(floating_bufnr, 'filetype', filetype)
  end

  local floating_win = vim.api.nvim_call_function("win_id2win", { floating_winnr })

  vim.api.nvim_command("wincmd p")
  vim.api.nvim_command("autocmd CursorMoved <buffer> ++once :"..floating_win.."wincmd c")
end

ui.get_floating_window_option = function(position, width, height)
  local bottom_line = vim.api.nvim_call_function('line', { 'w0' }) + vim.api.nvim_win_get_height(0) - 1
  local anchor = ''
  local row, col

  if position[1] + height <= bottom_line then
    anchor = anchor..'N'
    row = 1
  else
    anchor = anchor..'S'
    row = 0
  end

  if position[2] + width <= vim.api.nvim_get_option('columns') then
      anchor = anchor..'W'
      col = 0
  else
    anchor = anchor..'E'
    col = 1
  end

  return {
    relative = 'cursor',
    anchor = anchor,
    row = row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
  }
end

return ui
