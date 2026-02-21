local M = {}

function M.get_code()
  local chan_id = vim.bo.channel
  if chan_id == 0 or vim.bo.buftype ~= 'terminal' then
    return ''
  end

  local info = vim.api.nvim_get_chan_info(chan_id)
  if info.code and info.code >= 0 then
    return string.format('[Exit: %d]', info.code)
  end
  return ''
end

return M
