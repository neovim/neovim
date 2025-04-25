--- Deletes a buffer.
---@param buffer integer Buffer handle, or 0 for current buffer
---@param opts? table Optional parameters. Keys:
---       - force: Force deletion of the buffer, discarding unsaved changes (defaults to false)
---       - wipeout: Wipe out the buffer (like :bwipeout) instead of just deleting it (like :bdelete)
---         Defaults to true for backward compatibility. When false, buffer marks are preserved.
---         WARNING: Setting wipeout=true can cause data loss for marks stored in shada.
---
function vim.api.nvim_buf_delete(buffer, opts) end`
