local api = vim.api

local highlight = {}

--- Highlight the yanked region
--
--- use from init.vim via
---   au TextYankPost * lua require'vim.highlight'.on_yank()
--- customize highlight group and timeout via
---   au TextYankPost * lua require'vim.highlight'.on_yank("IncSearch", 500)
-- @param higroup highlight group for yanked region
-- @param timeout time in ms before highlight is cleared
-- @param event event structure
function highlight.on_yank(higroup, timeout, event)
  event = event or vim.v.event
  if event.operator ~= 'y' or event.regtype == '' then return end
  higroup = higroup or "IncSearch"
  timeout = timeout or 500

  local bufnr = api.nvim_get_current_buf()
  local yank_ns = api.nvim_create_namespace('')
  api.nvim_buf_clear_namespace(bufnr, yank_ns, 0, -1)

  local pos1 = vim.fn.getpos("'[")
  local pos2 = vim.fn.getpos("']")

  pos1 = {pos1[2] - 1, pos1[3] - 1 + pos1[4]}
  pos2 = {pos2[2] - 1, pos2[3] - 1 + pos2[4]}

  local region = vim.region(bufnr, pos1, pos2, event.regtype, event.inclusive)
  for linenr, cols in pairs(region) do
    api.nvim_buf_add_highlight(bufnr, yank_ns, higroup, linenr, cols[1], cols[2])
  end

  vim.defer_fn(
    function() api.nvim_buf_clear_namespace(bufnr, yank_ns, 0, -1) end,
    timeout
  )
end

return highlight
