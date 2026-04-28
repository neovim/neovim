local select_blocking = require('vim._core.ui').select_blocking
local N_ = vim.fn.gettext

local M = {}

--- @class vim._core.tag.Match
--- @field tag string
--- @field kind? string
--- @field pri string  Priority code, e.g. "FSC" — see `:h tag-priority`.
--- @field file string
--- @field extra? string
--- @field cur boolean True if this is the currently-active tagstack match.

--- Called from `do_tag()` (`:tselect`, ambiguous `:tag`, etc.) to let the user
--- pick from `matches` via |vim.ui.select()|.
---
--- @param items vim._core.tag.Match[] One per matching tag.
--- @return integer? # 1-based index of the chosen tag, or nil if cancelled.
function M.select(items)
  local taglen = 18
  for _, m in ipairs(items) do
    taglen = math.max(taglen, vim.fn.strdisplaywidth(m.tag) + 2)
  end

  return select_blocking(items, {
    prompt = N_('Type number and <Enter> (q or empty cancels):'),
    kind = 'tag',
    format_item = function(m)
      local marker = m.cur and '>' or ' '
      local kind = m.kind or ''
      local extra = m.extra and (' ' .. m.extra) or ''
      return ('%s %s %-4s %-' .. taglen .. 's %s%s'):format(
        marker,
        m.pri,
        kind,
        m.tag,
        m.file,
        extra
      )
    end,
  })
end

return M
