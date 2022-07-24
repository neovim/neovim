local api = vim.api

local M = {}

M.priorities = {
  syntax = 50,
  treesitter = 100,
  diagnostics = 150,
  user = 200,
}

---@private
function M.create(higroup, hi_info, default)
  vim.deprecate('vim.highlight.create', 'vim.api.nvim_set_hl', '0.9')
  local options = {}
  -- TODO: Add validation
  for k, v in pairs(hi_info) do
    table.insert(options, string.format('%s=%s', k, v))
  end
  vim.cmd(
    string.format(
      [[highlight %s %s %s]],
      default and 'default' or '',
      higroup,
      table.concat(options, ' ')
    )
  )
end

---@private
function M.link(higroup, link_to, force)
  vim.deprecate('vim.highlight.link', 'vim.api.nvim_set_hl', '0.9')
  vim.cmd(string.format([[highlight%s link %s %s]], force and '!' or ' default', higroup, link_to))
end

--- Highlight range between two positions
---
---@param bufnr (integer) buffer to apply highlighting to
---@param ns (integer) namespace to add highlight to
---@param hlgroup (string) highlight group to use for highlighting
---@param start (table|string) beginning of region
---        - table: tuple `{line, col}`
---        - string: `{expr}` (|line()|)
---@param finish (table|string) end of region
---@param opts (table) containing
---            - regtype (string) type of range (|setreg|, default charwise)
---            - inclusive (boolean) whether the range is end-inclusive (default false)
---            - priority (number) priority of highlight (default `priorities.user`)
function M.range(bufnr, ns, hlgroup, start, finish, opts)
  opts = opts or {}
  local regtype = opts.regtype or 'v'
  local inclusive = opts.inclusive or false
  local priority = opts.priority or M.priorities.user

  -- sanity check
  if
    (type(start) == 'table' and start[2] < 0)
    or (type(start) == 'table' and type(finish) == 'table' and finish[1] < start[1])
  then
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
      hl_group = hlgroup,
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
---@param opts (table) options controlling the highlight:
--              - hlgroup (string)    highlight group for yanked region (default "IncSearch")
--              - timeout (number)    time in ms before highlight is cleared (default 150)
--              - on_macro (boolean)  highlight when executing macro (default false)
--              - on_visual (boolean) highlight when yanking visual selection (default true)
--              - event (table)       event structure (default vim.v.event)
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

  local hlgroup = opts.higroup or 'IncSearch'
  local timeout = opts.timeout or 150

  local bufnr = api.nvim_get_current_buf()
  api.nvim_buf_clear_namespace(bufnr, yank_ns, 0, -1)
  if yank_timer then
    yank_timer:close()
  end

  M.range(
    bufnr,
    yank_ns,
    hlgroup,
    "'[",
    "']",
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
