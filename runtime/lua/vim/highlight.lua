local api = vim.api

local M = {}

M.priorities = {
  syntax = 50,
  treesitter = 100,
  semantic_tokens = 125,
  diagnostics = 150,
  user = 200,
}

--- Highlight range between two positions
---
---@param bufnr integer Buffer number to apply highlighting to
---@param ns integer Namespace to add highlight to
---@param higroup string Highlight group to use for highlighting
---@param start { [1]: integer, [2]: integer } Start position {line, col}
---@param finish { [1]: integer, [2]: integer } Finish position {line, col}
---@param opts table|nil Optional parameters
--             - regtype type of range (see |setreg()|, default charwise)
--             - inclusive boolean indicating whether the range is end-inclusive (default false)
--             - priority number indicating priority of highlight (default priorities.user)
function M.range(bufnr, ns, higroup, start, finish, opts)
  opts = opts or {}
  local regtype = opts.regtype or 'v'
  local inclusive = opts.inclusive or false
  local priority = opts.priority or M.priorities.user

  -- sanity check
  if start[2] < 0 or finish[1] < start[1] then
    return
  end

  local region = vim.region(bufnr, start, finish, regtype, inclusive)
  for linenr, cols in pairs(region) do
    local end_row
    if cols[2] == -1 then
      end_row = linenr + 1
      cols[2] = 0
    end
    api.nvim_buf_set_extmark(bufnr, ns, linenr, cols[1], {
      hl_group = higroup,
      end_row = end_row,
      end_col = cols[2],
      priority = priority,
      strict = false,
    })
  end
end

local yank_ns = api.nvim_create_namespace('hlyank')
local yank_timer
--- Highlight the yanked region
---
--- use from init.vim via
---   au TextYankPost * lua vim.highlight.on_yank()
--- customize highlight group and timeout via
---   au TextYankPost * lua vim.highlight.on_yank {higroup="IncSearch", timeout=150}
--- customize conditions (here: do not highlight a visual selection) via
---   au TextYankPost * lua vim.highlight.on_yank {on_visual=false}
---
-- @param opts table|nil Optional parameters
--              - higroup   highlight group for yanked region (default "IncSearch")
--              - timeout   time in ms before highlight is cleared (default 150)
--              - on_macro  highlight when executing macro (default false)
--              - on_visual highlight when yanking visual selection (default true)
--              - event     event structure (default vim.v.event)
function M.on_yank(opts)
  vim.validate({
    opts = {
      opts,
      function(t)
        if t == nil then
          return true
        else
          return type(t) == 'table'
        end
      end,
      'a table or nil to configure options (see `:h highlight.on_yank`)',
    },
  })
  opts = opts or {}
  local event = opts.event or vim.v.event
  local on_macro = opts.on_macro or false
  local on_visual = (opts.on_visual ~= false)

  if not on_macro and vim.fn.reg_executing() ~= '' then
    return
  end
  if event.operator ~= 'y' or event.regtype == '' then
    return
  end
  if not on_visual and event.visual then
    return
  end

  local higroup = opts.higroup or 'IncSearch'
  local timeout = opts.timeout or 150

  local bufnr = api.nvim_get_current_buf()
  api.nvim_buf_clear_namespace(bufnr, yank_ns, 0, -1)
  if yank_timer then
    yank_timer:close()
  end

  local pos1 = vim.fn.getpos("'[")
  local pos2 = vim.fn.getpos("']")

  pos1 = { pos1[2] - 1, pos1[3] - 1 + pos1[4] }
  pos2 = { pos2[2] - 1, pos2[3] - 1 + pos2[4] }

  M.range(
    bufnr,
    yank_ns,
    higroup,
    pos1,
    pos2,
    { regtype = event.regtype, inclusive = event.inclusive, priority = M.priorities.user }
  )

  yank_timer = vim.defer_fn(function()
    yank_timer = nil
    if api.nvim_buf_is_valid(bufnr) then
      api.nvim_buf_clear_namespace(bufnr, yank_ns, 0, -1)
    end
  end, timeout)
end

return M
