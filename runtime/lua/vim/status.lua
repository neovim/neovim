local M = {}

do
  ---@class ProgressMessage
  ---@field title string   Title of the progress message
  ---@field status string  Status: "running" | "success" | "failed" | "cancel"
  ---@field percent integer Percent complete (0–100)

  ---Cache of active progress messages, keyed by msg_id
  ---@type table<integer, ProgressMessage>
  local progress = {}

  -- store progress events
  local progress_group = vim.api.nvim_create_augroup('nvim.status.progress', { clear = true })
  vim.api.nvim_create_autocmd('Progress', {
    group = progress_group,
    desc = 'Track progress messages for statusline',
    ---@param ev {data: {msg_id: integer, title: string, status: string, percent: integer}}
    callback = function(ev)
      if not ev.data or not ev.data.msg_id then
        return
      end
      progress[ev.data.msg_id] = {
        title = ev.data.title,
        status = ev.data.status,
        percent = ev.data.percent or 0,
      }

      -- Clear finished items
      if
        ev.data.status == 'success'
        or ev.data.percent == 100
        or ev.data.status == 'failed'
        or ev.data.status == 'cancel'
      then
        progress[ev.data.msg_id] = nil
      end
    end,
  })

  ---Return statusline text summarizing progress messages.
  --- - If none: returns empty string
  --- - If one running item: "title: 42%"
  --- - If multiple running items: "Progress: N items AVG%"
  ---@return string
  function M.get_progress_status()
    local running = {} ---@type ProgressMessage[]
    for _, msg in pairs(progress) do
      if msg.status == 'running' then
        table.insert(running, msg)
      end
    end

    local count = #running
    if count == 0 then
      return '' -- nothing to show
    elseif count == 1 then
      local progress_item = running[1]
      return string.format('%s: %d%%%% ', progress_item.title, progress_item.percent or 0)
    else
      local sum = 0
      for _, progress_item in ipairs(running) do
        sum = sum + (progress_item.percent or 0)
      end
      local avg = math.floor(sum / count)
      return string.format('Progress: %d items %d%%%% ', count, avg)
    end
  end
end

return M
