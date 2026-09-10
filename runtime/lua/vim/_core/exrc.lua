-- For 'exrc' and related functionality.

local M = {}

-- Whether exrc files were already loaded in this session. Exrc files are loaded
-- at most once per session, whether triggered by |vim.exrc.load()| or at startup.
local did_load = false

--- Execute ".nvim.lua", ".nvimrc", or ".exrc" files found in the current
--- directory and all parent directories (ordered upwards), for files which are
--- in the |trust| list. See 'exrc'.
---
--- Does nothing if exrc files were already loaded in this session.
---
--- @private
function M.load()
  if did_load then
    return
  end
  did_load = true

  local files = vim.fs.find({ '.nvim.lua', '.nvimrc', '.exrc' }, {
    type = 'file',
    upward = true,
    limit = math.huge,
  })
  for _, file in ipairs(files) do
    local trusted = vim.secure.read(file) --[[@as string|nil]]
    if trusted then
      if vim.endswith(file, '.lua') then
        assert(loadstring(trusted, '@' .. file))()
      else
        vim.api.nvim_exec2(trusted)
      end
    end
    -- If the user unset 'exrc' in the current exrc then stop searching
    if not vim.o.exrc then
      break
    end
  end
end

return M
