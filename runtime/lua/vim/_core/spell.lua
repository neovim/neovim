local N_ = vim.fn.gettext
local api = vim.api

local M = {}

--- @class vim._core.spell.Suggestion
--- @field word string The suggested replacement.
--- @field extra? string Text replaced when wider than the bad span.
--- @field score integer Primary score.
--- @field altscore? integer Secondary score (only set when 'spellsuggest' contains "double" or "best").
--- @field salscore? boolean True if the score came from sound-alike comparison (only set alongside `altscore`).

--- Implements `spell_suggest()` (`z=`) via vim.ui.select().
---
--- async: returns immediately, the chosen suggestion is applied later
--- by re-running `:normal! [idx]z=` from `on_choice`.
---
--- @param items vim._core.spell.Suggestion[]
--- @param bad string The misspelled word being replaced.
function M.select_suggest(items, bad)
  local win = api.nvim_get_current_win()
  local buf = api.nvim_get_current_buf()

  vim.ui.select(items, {
    prompt = N_('Change "%s" to:'):format(bad),
    kind = 'spell',
    format_item = function(s)
      local extra = s.extra and (' < "' .. s.extra .. '"') or ''
      local score = ''
      if vim.o.verbose > 0 then
        score = s.altscore
            and (' (%s%d - %d)'):format(s.salscore and 's ' or '', s.score, s.altscore)
          or (' (%d)'):format(s.score)
      end
      return ('"%s"%s%s'):format(s.word, extra, score)
    end,
  }, function(_, idx)
    if not idx then
      return
    end
    -- Queue ":normal! [idx]z=" as user input, so the recursive spell_suggest runs via the normal
    -- input-dispatch loop. Using vim.schedule + vim.cmd can hang bc of "Press ENTER".
    vim.fn.feedkeys(
      vim.keycode(
        ('<Cmd>lua require("vim._core.spell")._apply_suggest(%d, %d, %d)<CR>'):format(win, buf, idx)
      ),
      'in'
    )
  end)
end

--- Applies a queued spell suggestion in the original window, if it still shows the original buffer.
---
--- @param win integer
--- @param buf integer
--- @param idx integer
function M._apply_suggest(win, buf, idx)
  if not api.nvim_win_is_valid(win) or api.nvim_win_get_buf(win) ~= buf then
    return
  end

  api.nvim_win_call(win, function()
    vim.cmd.normal({ ('%dz='):format(idx), bang = true })
  end)
end

return M
