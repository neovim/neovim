local Border = require('vim.ui.border')
local utils = require('vim.ui._utils')

_NvimUI_AssociatedBufs = {}


local clear_buf_on_leave = function(bufnr)
  vim.cmd(
    string.format(
      "autocmd WinLeave,BufLeave,BufDelete <buffer=%s> ++once ++nested lua require('vim.ui.float').clear(%s)",
      bufnr,
      bufnr
    )
  )
end

local win_float = {}

win_float.default_options = {
  winblend = 15,
  percentage = 0.9,
}

function win_float.default_opts(options)
  options = utils.tbl_apply_defaults(options, win_float.default_options)

  local width = math.floor(vim.o.columns * options.percentage)
  local height = math.floor(vim.o.lines * options.percentage)

  local top = math.floor(((vim.o.lines - height) / 2) - 1)
  local left = math.floor((vim.o.columns - width) / 2)

  local opts = {
    relative = 'editor',
    row      = top,
    col      = left,
    width    = width,
    height   = height,
    style    = 'minimal'
  }

  return opts
end

function win_float.centered(options)
  options = utils.tbl_apply_defaults(options, win_float.default_options)

  local win_opts = win_float.default_opts(options)

  local bufnr = vim.fn.nvim_create_buf(false, true)
  local win_id = vim.fn.nvim_open_win(bufnr, true, win_opts)

  vim.cmd('setlocal nocursorcolumn')
  vim.fn.nvim_win_set_option(win_id, 'winblend', options.winblend)

  vim.cmd(
    string.format(
      "autocmd WinLeave <buffer> silent! execute 'bdelete! %s'",
      bufnr
    )
  )

  return {
    bufnr=bufnr,
    win_id=win_id,
  }
end

function win_float.centered_with_top_win(top_text, options)
  options = utils.tbl_apply_defaults(options, win_float.default_options)

  table.insert(top_text, 1, string.rep("=", 80))
  table.insert(top_text, string.rep("=", 80))

  local primary_win_opts = win_float.default_opts(nil, nil, options)
  local minor_win_opts = vim.deepcopy(primary_win_opts)

  primary_win_opts.height = primary_win_opts.height - #top_text - 1
  primary_win_opts.row = primary_win_opts.row + #top_text + 1

  minor_win_opts.height = #top_text

  local minor_bufnr = vim.api.nvim_create_buf(false, true)
  local minor_win_id = vim.api.nvim_open_win(minor_bufnr, true, minor_win_opts)

  vim.cmd('setlocal nocursorcolumn')
  vim.fn.nvim_win_set_option(minor_win_id, 'winblend', options.winblend)

  vim.api.nvim_buf_set_lines(minor_bufnr, 0, -1, false, top_text)

  local primary_bufnr = vim.fn.nvim_create_buf(false, true)
  local primary_win_id = vim.fn.nvim_open_win(primary_bufnr, true, primary_win_opts)

  vim.cmd('setlocal nocursorcolumn')
  vim.fn.nvim_win_set_option(primary_win_id, 'winblend', options.winblend)

  -- vim.cmd(
  --   string.format(
  --     "autocmd WinLeave,BufDelete,BufLeave <buffer=%s> ++once ++nested silent! execute 'bdelete! %s'",
  --     primary_buf,
  --     minor_buf
  --   )
  -- )

  -- vim.cmd(
  --   string.format(
  --     "autocmd WinLeave,BufDelete,BufLeave <buffer> ++once ++nested silent! execute 'bdelete! %s'",
  --     primary_buf
  --   )
  -- )


  local primary_border = Border:new(primary_bufnr, primary_win_id, primary_win_opts, {})
  local minor_border = Border:new(minor_bufnr, minor_win_id, minor_win_opts, {})

  _NvimUI_AssociatedBufs[primary_bufnr] = {
    primary_win_id, minor_win_id, primary_border.win_id, minor_border.win_id
  }

  clear_buf_on_leave(primary_bufnr)

  return {
    bufnr = primary_bufnr,
    win_id = primary_win_id,

    minor_bufnr = minor_bufnr,
    minor_win_id = minor_win_id,
  }
end

--- Create window that takes up certain percentags of the current screen.
---
--- Works regardless of current buffers, tabs, splits, etc.
--@param col_range number | Table:
--                  If number, then center the window taking up this percentage of the screen.
--                  If table, first index should be start, second_index should be end
--@param row_range number | Table:
--                  If number, then center the window taking up this percentage of the screen.
--                  If table, first index should be start, second_index should be end
function win_float.percentage_range_window(col_range, row_range, options)
  options = utils.tbl_apply_defaults(options, win_float.default_options)

  local win_opts = win_float.default_opts(options)
  win_opts.relative = "editor"

  local height_percentage, row_start_percentage
  if type(row_range) == 'number' then
    assert(row_range <= 1)
    assert(row_range > 0)
    height_percentage = row_range
    row_start_percentage = (1 - height_percentage) / 2
  elseif type(row_range) == 'table' then
    height_percentage = row_range[2] - row_range[1]
    row_start_percentage = row_range[1]
  else
    error(string.format("Invalid type for 'row_range': %p", row_range))
  end

  win_opts.height = math.ceil(vim.o.lines * height_percentage)
  win_opts.row = math.ceil(vim.o.lines *  row_start_percentage)

  local width_percentage, col_start_percentage
  if type(col_range) == 'number' then
    assert(col_range <= 1)
    assert(col_range > 0)
    width_percentage = col_range
    col_start_percentage = (1 - width_percentage) / 2
  elseif type(col_range) == 'table' then
    width_percentage = col_range[2] - col_range[1]
    col_start_percentage = col_range[1]
  else
    error(string.format("Invalid type for 'col_range': %p", col_range))
  end

  win_opts.col = math.floor(vim.o.columns * col_start_percentage)
  win_opts.width = math.floor(vim.o.columns * width_percentage)

  local bufnr = options.bufnr or vim.fn.nvim_create_buf(false, true)
  local win_id = vim.fn.nvim_open_win(bufnr, true, win_opts)
  vim.api.nvim_win_set_buf(win_id, bufnr)

  vim.cmd('setlocal nocursorcolumn')
  vim.fn.nvim_win_set_option(win_id, 'winblend', options.winblend)

  local border = Border:new(bufnr, win_id, win_opts, {})

  _NvimUI_AssociatedBufs[bufnr] = { win_id, border.win_id, }

  clear_buf_on_leave(bufnr)

  return {
    bufnr = bufnr,
    win_id = win_id,

    border_bufnr = border.bufnr,
    border_win_id = border.win_id,
  }
end

function win_float.clear(bufnr)
  if _NvimUI_AssociatedBufs[bufnr] == nil then
    return
  end

  for _, win_id in ipairs(_NvimUI_AssociatedBufs[bufnr]) do
    if vim.api.nvim_win_is_valid(win_id) then
      vim.fn.nvim_win_close(win_id, true)
    end
  end

  _NvimUI_AssociatedBufs[bufnr] = nil
end

return win_float
