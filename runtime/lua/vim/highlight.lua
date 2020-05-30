local api = vim.api

local highlight = {}

--- Highlight range between two positions
---
--@param bufnr number of buffer to apply highlighting to
--@param ns namespace to add highlight to
--@param higroup highlight group to use for highlighting
--@param rtype type of range (:help setreg, default charwise)
--@param inclusive boolean indicating whether the range is end-inclusive (default false)
function highlight.range(bufnr, ns, higroup, start, finish, rtype, inclusive)
  rtype = rtype or 'v'
  inclusive = inclusive or false

  -- sanity check
  if start[2] < 0 or finish[2] < start[2] then return end

  local region = vim.region(bufnr, start, finish, rtype, inclusive)
  for linenr, cols in pairs(region) do
    api.nvim_buf_add_highlight(bufnr, ns, higroup, linenr, cols[1], cols[2])
  end

end

--- Highlight the yanked region
---
--- use from init.vim via
---   au TextYankPost * lua require'vim.highlight'.on_yank()
--- customize highlight group and timeout via
---   au TextYankPost * lua require'vim.highlight'.on_yank("IncSearch", 500)
---
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

  highlight.range(bufnr, yank_ns, higroup, pos1, pos2, event.regtype, event.inclusive)

  vim.defer_fn(
    function() api.nvim_buf_clear_namespace(bufnr, yank_ns, 0, -1) end,
    timeout
  )
end

return highlight
