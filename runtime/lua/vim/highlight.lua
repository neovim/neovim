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
---   au TextYankPost * lua vim.highlight.on_yank()
--- customize highlight group and timeout via
---   au TextYankPost * lua vim.highlight.on_yank {higroup="IncSearch", timeout=150}
--- customize conditions (here: do not highlight a visual selection) via
---   au TextYankPost * lua vim.highlight.on_yank {on_visual=false}
---
-- @param opts dictionary with options controlling the highlight:
--              - higroup   highlight group for yanked region (default "IncSearch")
--              - timeout   time in ms before highlight is cleared (default 150)
--              - on_macro  highlight when executing macro (default false)
--              - on_visual highlight when yanking visual selection (default true)
--              - event     event structure (default vim.v.event)
function highlight.on_yank(opts)
  vim.validate {
    opts = { opts,
    function(t) if t == nil then return true else return type(t) == 'table' end end,
    'a table or nil to configure options (see `:h highlight.on_yank`)',
  }}
  opts = opts or {}
  local event = opts.event or vim.v.event
  local on_macro = opts.on_macro or false
  local on_visual = (opts.on_visual ~= false)

  if (not on_macro) and vim.fn.reg_executing() ~= '' then return end
  if event.operator ~= 'y' or event.regtype == '' then return end
  if (not on_visual) and event.visual then return end

  local higroup = opts.higroup or "IncSearch"
  local timeout = opts.timeout or 150

  local bufnr = api.nvim_get_current_buf()
  local yank_ns = api.nvim_create_namespace('hlyank')
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
