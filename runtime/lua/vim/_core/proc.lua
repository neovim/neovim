-- OS/process utils.

local M = {}

--- Counts (approximate) open file descriptors for this process. Works on Linux/macOS/BSD.
---@return integer? # Number of open fds, or nil if `/dev/fd` failed (fds exhausted, or unavailable/Windows).
function M.count_open_fds()
  local n = 0
  for _, _, err in vim.fs.dir('/dev/fd', { err = true }) do
    -- If `/dev/fd` scan failed (e.g. EMFILE when fds exhausted), count would be misleading.
    if err then
      return nil
    end
    n = n + 1
  end
  -- Discount the scan's own descriptor.
  return math.max(0, n - 1)
end

return M
