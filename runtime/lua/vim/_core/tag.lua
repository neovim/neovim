local N_ = vim.fn.gettext

local M = {}

--- @class vim._core.tag.Match
--- @field tag string
--- @field kind? string
--- @field pri string  Priority code, e.g. "FSC" — see `:h tag-priority`.
--- @field file string
--- @field extra? string
--- @field cur boolean True if this is the currently-active tagstack match.

--- Implements `do_tag()` (`:tselect`, ambiguous `:tag`, …) via vim.ui.select().
---
--- async: returns immediately, the chosen tag is applied later by re-running
--- `:[mods] [idx]tag {tagname}` (or `stag`) from `on_choice`.
---
--- @param eap vim._core.ExCmdArgs Original :tselect/:stselect/… invocation.
--- @param extra { items: vim._core.tag.Match[], tagname: string }
function M.select_tag(eap, extra)
  local items, tagname = extra.items, extra.tagname
  -- :stag/:stselect/:stjump need a split when re-invoked.
  local stag = eap.name:sub(1, 1) == 's'
  -- `eap.mods` is the raw modifier string (e.g. ":vert silent").
  local mods_str = eap.mods ~= '' and (eap.mods .. ' ') or ''

  local taglen = 18
  for _, m in ipairs(items) do
    taglen = math.max(taglen, vim.fn.strdisplaywidth(m.tag) + 2)
  end

  vim.ui.select(items, {
    prompt = N_('Select a tag:'),
    kind = 'tag',
    format_item = function(m)
      local marker = m.cur and '>' or ' '
      local kind = m.kind or ''
      return ('%s %s %-4s %-' .. taglen .. 's %s%s'):format(
        marker,
        m.pri,
        kind,
        m.tag,
        m.file,
        m.extra and (' ' .. m.extra) or ''
      )
    end,
  }, function(_, idx)
    if not idx then
      return
    end
    -- Queue ":[mods] [idx](s)tag {tagname}" as user input, so the recursive do_tag runs via the
    -- normal input-dispatch loop. Using vim.schedule + vim.cmd can hang bc of "Press ENTER".
    local cmd = stag and 'stag' or 'tag'
    vim.fn.feedkeys(vim.keycode(('<Cmd>%s%d%s %s<CR>'):format(mods_str, idx, cmd, tagname)), 'in')
  end)
end

return M
