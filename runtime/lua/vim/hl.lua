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

local range_timer --- @type uv.uv_timer_t?
local range_hl_clear --- @type fun()?

--- @class vim.hl.range.Opts
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
--- Highlight priority
--- (default: `vim.hl.priorities.user`)
--- @field priority? integer
---
--- Time in ms before highlight is cleared
--- (default: -1 no timeout)
--- @field timeout? integer

--- Apply highlight group to range of text.
---
---@param bufnr integer Buffer number to apply highlighting to
---@param ns integer Namespace to add highlight to
---@param higroup string Highlight group to use for highlighting
---@param start integer[]|string Start of region as a (line, column) tuple or string accepted by |getpos()|
---@param finish integer[]|string End of region as a (line, column) tuple or string accepted by |getpos()|
---@param opts? vim.hl.range.Opts
function M.range(bufnr, ns, higroup, start, finish, opts)
  opts = opts or {}
  local regtype = opts.regtype or 'v'
  local inclusive = opts.inclusive or false
  local priority = opts.priority or M.priorities.user
  local timeout = opts.timeout or -1

  local v_maxcol = vim.v.maxcol

  local pos1 = type(start) == 'string' and vim.fn.getpos(start)
    or {
      bufnr,
      start[1] + 1,
      start[2] ~= -1 and start[2] ~= v_maxcol and start[2] + 1 or v_maxcol,
      0,
    }
  local pos2 = type(finish) == 'string' and vim.fn.getpos(finish)
    or {
      bufnr,
      finish[1] + 1,
      finish[2] ~= -1 and start[2] ~= v_maxcol and finish[2] + 1 or v_maxcol,
      0,
    }

  local buf_line_count = vim.api.nvim_buf_line_count(bufnr)
  pos1[2] = math.min(pos1[2], buf_line_count)
  pos2[2] = math.min(pos2[2], buf_line_count)

  if pos1[2] <= 0 or pos1[3] <= 0 or pos2[2] <= 0 or pos2[3] <= 0 then
    return
  end

  vim._with({ buf = bufnr }, function()
    if pos1[3] ~= v_maxcol then
      local max_col1 = vim.fn.col({ pos1[2], '$' })
      pos1[3] = math.min(pos1[3], max_col1)
    end
    if pos2[3] ~= v_maxcol then
      local max_col2 = vim.fn.col({ pos2[2], '$' })
      pos2[3] = math.min(pos2[3], max_col2)
    end
  end)

  local region = vim.fn.getregionpos(pos1, pos2, {
    type = regtype,
    exclusive = not inclusive,
    eol = true,
  })
  -- For non-blockwise selection, use a single extmark.
  if regtype == 'v' or regtype == 'V' then
    region = { { region[1][1], region[#region][2] } }
    if
      regtype == 'V'
      or region[1][2][2] == pos1[2] and pos1[3] == v_maxcol
      or region[1][2][2] == pos2[2] and pos2[3] == v_maxcol
    then
      region[1][2][2] = region[1][2][2] + 1
      region[1][2][3] = 0
    end
  end

  if range_timer and not range_timer:is_closing() then
    range_timer:close()
    assert(range_hl_clear)
    range_hl_clear()
  end

  range_hl_clear = function()
    range_timer = nil
    range_hl_clear = nil
    pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns, 0, -1)
    pcall(vim.api.nvim__ns_set, { wins = {} })
  end

  for _, res in ipairs(region) do
    local start_row = res[1][2] - 1
    local start_col = res[1][3] - 1
    local end_row = res[2][2] - 1
    local end_col = res[2][3]
    api.nvim_buf_set_extmark(bufnr, ns, start_row, start_col, {
      hl_group = higroup,
      end_row = end_row,
      end_col = end_col,
      priority = priority,
      strict = false,
    })
  end

  if timeout ~= -1 then
    range_timer = vim.defer_fn(range_hl_clear, timeout)
  end
end

local yank_ns = api.nvim_create_namespace('nvim.hlyank')

--- Highlight the yanked text during a |TextYankPost| event.
---
--- Add the following to your `init.vim`:
---
--- ```vim
--- autocmd TextYankPost * silent! lua vim.hl.on_yank {higroup='Visual', timeout=300}
--- ```
---
--- @param opts table|nil Optional parameters
---              - higroup   highlight group for yanked region (default "IncSearch")
---              - timeout   time in ms before highlight is cleared (default 150)
---              - on_macro  highlight when executing macro (default false)
---              - on_visual highlight when yanking visual selection (default true)
---              - event     event structure (default vim.v.event)
---              - priority  integer priority (default |vim.hl.priorities|`.user`)
function M.on_yank(opts)
  vim.validate('opts', opts, 'table', true)
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

  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()

  vim.api.nvim__ns_set(yank_ns, { wins = { winid } })
  M.range(bufnr, yank_ns, higroup, "'[", "']", {
    regtype = event.regtype,
    inclusive = true,
    priority = opts.priority or M.priorities.user,
    timeout = opts.timeout or 150,
  })
end

return M
