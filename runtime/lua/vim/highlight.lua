---@defgroup vim.highlight
---
---@brief
---Nvim includes a function for highlighting a selection on yank.
---
---To enable it, add the following to your `init.vim`:
---<pre>vim
---    au TextYankPost * silent! lua vim.highlight.on_yank()
---</pre>
---
---You can customize the highlight group and the duration of
---the highlight via:
---<pre>vim
---    au TextYankPost * silent! lua vim.highlight.on_yank {higroup="IncSearch", timeout=150}
---</pre>
---
---If you want to exclude visual selections from highlighting on yank, use:
---<pre>vim
---    au TextYankPost * silent! lua vim.highlight.on_yank {on_visual=false}
---</pre>

local api = vim.api

local M = {}

--- Table with default priorities used for highlighting:
---     - `syntax`: `50`, used for standard syntax highlighting
---     - `treesitter`: `100`, used for tree-sitter-based highlighting
---     - `semantic_tokens`: `125`, used for LSP semantic token highlighting
---     - `diagnostics`: `150`, used for code analysis such as diagnostics
---     - `user`: `200`, used for user-triggered highlights such as LSP document
---       symbols or `on_yank` autocommands
M.priorities = {
  syntax = 50,
  treesitter = 100,
  semantic_tokens = 125,
  diagnostics = 150,
  user = 200,
}

--- Apply highlight group to range of text.
---
---@param bufnr integer Buffer number to apply highlighting to
---@param ns integer Namespace to add highlight to
---@param higroup string Highlight group to use for highlighting
---@param start integer[]|string Start of region as a (line, column) tuple or string accepted by |getpos()|
---@param finish integer[]|string End of region as a (line, column) tuple or string accepted by |getpos()|
---@param opts table|nil Optional parameters
---            - regtype type of range (see |setreg()|, default charwise)
---            - inclusive boolean indicating whether the range is end-inclusive (default false)
---            - priority number indicating priority of highlight (default priorities.user)
function M.range(bufnr, ns, higroup, start, finish, opts)
  opts = opts or {}
  local regtype = opts.regtype or 'v'
  local inclusive = opts.inclusive or false
  local priority = opts.priority or M.priorities.user

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

--- Highlight the yanked text
---
--- @param opts table|nil Optional parameters
---              - higroup   highlight group for yanked region (default "IncSearch")
---              - timeout   time in ms before highlight is cleared (default 150)
---              - on_macro  highlight when executing macro (default false)
---              - on_visual highlight when yanking visual selection (default true)
---              - event     event structure (default vim.v.event)
---              - priority  integer priority (default |vim.highlight.priorities|`.user`)
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

  M.range(bufnr, yank_ns, higroup, "'[", "']", {
    regtype = event.regtype,
    inclusive = event.inclusive,
    priority = opts.priority or M.priorities.user,
  })

  yank_timer = vim.defer_fn(function()
    yank_timer = nil
    if api.nvim_buf_is_valid(bufnr) then
      api.nvim_buf_clear_namespace(bufnr, yank_ns, 0, -1)
    end
  end, timeout)
end

return M
