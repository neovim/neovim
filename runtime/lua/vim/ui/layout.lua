local utils = require('vim.ui._utils')

-- TODO(smolck): Just for testing, don't intend to keep this
local function make_win(text, options)
  options = utils.tbl_apply_defaults(options, {
    relative = 'editor',
    row      = 0,
    col      = 0,
    width    = 5,
    height   = 5,
    style    = 'minimal'
  })
  local win_opts = options

  local bufnr = vim.fn.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { text or 'This is just for testing' })

  local win_id = vim.fn.nvim_open_win(bufnr, true, win_opts)

  return win_id
end

-- TODO(smolck): Is `partition` an accurate/good name?
local function partition(max_height, max_width, starting_row, starting_col, input, is_horizontal)
  for i, win_id in ipairs(input) do
    local row, col
    if is_horizontal then
      row = starting_row + (max_height * (i - 1))
      col = starting_col
    else
      row = starting_row
      col = starting_col + (max_width * (i - 1))
    end

    if type(win_id) == 'table' then
      local horizontal = not is_horizontal
      partition(
        horizontal and math.floor(max_height / #win_id) or max_height,
        horizontal and max_width or math.floor(max_width / #win_id),
        row,
        col,
        win_id,
        horizontal
      )
    else
      vim.api.nvim_win_set_config(win_id, {
        row = row,
        col = col,
        width = max_width,
        height = max_height,
        relative = 'win',
      })
    end
  end
end

-- TODO(smolck): Error on invalid layouts, like:
-- ui.layout {
--     { make_win(),
--         { make_win('col left'), make_win('col right'), { make_win('underneath col right?') } },
--       make_win(),
--     },
--     { make_win() },
-- }
local function layout(input)
  local max_width = math.floor(vim.o.columns / #input)

  for i, tbl in ipairs(input) do
    local col = max_width * (i - 1)
    local max_height = math.floor(vim.o.lines / #tbl)
    partition(max_height, max_width, 0, col, tbl, true, false)
  end
end

return layout
