local api = vim.api

local M = {}

--- Table with default priorities used for highlighting:
--- - `syntax`: `50`, used for standard syntax highlighting
--- - `treesitter`: `100`, used for treesitter-based highlighting
--- - `semantic_tokens`: `125`, used for LSP semantic token highlighting
--- - `diagnostics`: `150`, used for code analysis such as diagnostics
--- - `user`: `200`, used for user-triggered highlights such as LSP document
---   symbols or `on_yank` autocommands
M.priorities = {
  syntax = 50,
  treesitter = 100,
  semantic_tokens = 125,
  diagnostics = 150,
  user = 200,
}

--- @class vim.highlight.range.Opts
--- @inlinedoc
---
--- Type of range. See [getregtype()]
--- (default: `'v'` i.e. charwise)
--- @field regtype? string
---
--- Indicates whether the range is end-inclusive
--- (default: `false`)
--- @field inclusive? boolean
---
--- Indicates priority of highlight
--- (default: `vim.highlight.priorities.user`)
--- @field priority? integer
---
--- @field package _scoped? boolean

--- Apply highlight group to range of text.
---
---@param bufnr integer Buffer number to apply highlighting to
---@param ns integer Namespace to add highlight to
---@param higroup string Highlight group to use for highlighting
---@param start integer[]|string Start of region as a (line, column) tuple or string accepted by |getpos()|
---@param finish integer[]|string End of region as a (line, column) tuple or string accepted by |getpos()|
---@param opts? vim.highlight.range.Opts
function M.range(bufnr, ns, higroup, start, finish, opts)
  opts = opts or {}
  local regtype = opts.regtype or 'v'
  local inclusive = opts.inclusive or false
  local priority = opts.priority or M.priorities.user
  local scoped = opts._scoped or false

  local pos1 = type(start) == 'string' and vim.fn.getpos(start)
    or { bufnr, start[1] + 1, start[2] + 1, 0 }
  local pos2 = type(finish) == 'string' and vim.fn.getpos(finish)
    or { bufnr, finish[1] + 1, finish[2] + 1, 0 }

  local buf_line_count = vim.api.nvim_buf_line_count(bufnr)
  pos1[2] = math.min(pos1[2], buf_line_count)
  pos2[2] = math.min(pos2[2], buf_line_count)

  if pos1[2] <= 0 or pos1[3] <= 0 or pos2[2] <= 0 or pos2[3] <= 0 then
    return
  end

  vim.api.nvim_buf_call(bufnr, function()
    local max_col1 = vim.fn.col({ pos1[2], '$' })
    pos1[3] = math.min(pos1[3], max_col1)
    local max_col2 = vim.fn.col({ pos2[2], '$' })
    pos2[3] = math.min(pos2[3], max_col2)
  end)

  local region = vim.fn.getregionpos(pos1, pos2, {
    type = regtype,
    exclusive = not inclusive,
    eol = true,
  })
  -- For non-blockwise selection, use a single extmark.
  if regtype == 'v' or regtype == 'V' then
    region = { { region[1][1], region[#region][2] } }
  end

  for _, res in ipairs(region) do
    local start_row = res[1][2] - 1
    local start_col = res[1][3] - 1
    local end_row = res[2][2] - 1
    local end_col = res[2][3]
    if regtype == 'V' then
      end_row = end_row + 1
      end_col = 0
    end
    api.nvim_buf_set_extmark(bufnr, ns, start_row, start_col, {
      hl_group = higroup,
      end_row = end_row,
      end_col = end_col,
      priority = priority,
      strict = false,
      scoped = scoped,
    })
  end
end

local yank_ns = api.nvim_create_namespace('hlyank')
local yank_timer --- @type uv.uv_timer_t?
local yank_cancel --- @type fun()?

--- Highlight the yanked text during a |TextYankPost| event.
---
--- Add the following to your `init.vim`:
---
--- ```vim
--- autocmd TextYankPost * silent! lua vim.highlight.on_yank {higroup='Visual', timeout=300}
--- ```
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

  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()
  if yank_timer then
    yank_timer:close()
    assert(yank_cancel)
    yank_cancel()
  end

  vim.api.nvim__win_add_ns(winid, yank_ns)
  M.range(bufnr, yank_ns, higroup, "'[", "']", {
    regtype = event.regtype,
    inclusive = event.inclusive,
    priority = opts.priority or M.priorities.user,
    _scoped = true,
  })

  yank_cancel = function()
    yank_timer = nil
    yank_cancel = nil
    pcall(vim.api.nvim_buf_clear_namespace, bufnr, yank_ns, 0, -1)
    pcall(vim.api.nvim__win_del_ns, winid, yank_ns)
  end

  yank_timer = vim.defer_fn(yank_cancel, timeout)
end

return M
