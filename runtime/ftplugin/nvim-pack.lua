local ns = vim.api.nvim_create_namespace('nvim.pack.confirm')
vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)

local priority = 100
local hi_range = function(lnum, start_col, end_col, hl, pr)
  --- @type vim.api.keyset.set_extmark
  local opts = { end_row = lnum - 1, end_col = end_col, hl_group = hl, priority = pr or priority }
  vim.api.nvim_buf_set_extmark(0, ns, lnum - 1, start_col, opts)
end

local header_hl_groups =
  { Error = 'DiagnosticError', Update = 'DiagnosticWarn', Same = 'DiagnosticHint' }
local cur_header_hl_group = nil

local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
for i, l in ipairs(lines) do
  local cur_group = l:match('^# (%S+)')
  local cur_info = l:match('^Path: +') or l:match('^Source: +') or l:match('^State[^:]*: +')
  if cur_group ~= nil then
    --- @cast cur_group string
    -- Header 1
    cur_header_hl_group = header_hl_groups[cur_group]
    hi_range(i, 0, l:len(), cur_header_hl_group)
  elseif l:find('^## (.+)$') ~= nil then
    -- Header 2
    hi_range(i, 0, l:len(), cur_header_hl_group)
  elseif cur_info ~= nil then
    -- Plugin info
    local end_col = l:match('(). +%b()$') or l:len()
    hi_range(i, cur_info:len(), end_col, 'DiagnosticInfo')

    -- Plugin state after update
    local col = l:match('() %b()$') or l:len()
    hi_range(i, col, l:len(), 'DiagnosticHint')
  elseif l:match('^> ') then
    -- Added change with possibly "breaking message"
    hi_range(i, 0, l:len(), 'Added')
    local col = l:match('│() %S+!:') or l:match('│() %S+%b()!:') or l:len()
    hi_range(i, col, l:len(), 'DiagnosticWarn', priority + 1)
  elseif l:match('^< ') then
    -- Removed change
    hi_range(i, 0, l:len(), 'Removed')
  elseif l:match('^• ') then
    -- Available newer tags
    hi_range(i, 4, l:len(), 'DiagnosticHint')
  end
end
