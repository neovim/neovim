local select_blocking = require('vim._core.ui').select_blocking
local N_ = vim.fn.gettext

local M = {}

--- @class vim._core.spell.Suggestion
--- @field word string The suggested replacement.
--- @field extra? string Text replaced when wider than the bad span.
--- @field score integer Primary score.
--- @field altscore? integer Secondary score (only set when 'spellsuggest' contains "double" or "best").
--- @field salscore? boolean True if the score came from sound-alike comparison (only set alongside `altscore`).

--- Called from `spell_suggest()` (`z=`) to let the user pick from `items` via
--- |vim.ui.select()|.
---
--- @param items vim._core.spell.Suggestion[]
--- @param bad string The misspelled word being replaced.
--- @return integer? # 1-based index of the chosen suggestion, or nil if cancelled.
function M.suggest_select(items, bad)
  return select_blocking(items, {
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
  })
end

return M
