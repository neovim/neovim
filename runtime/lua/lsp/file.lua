local plugin = require('lsp.plugin')
local util = require('lsp.util')

local file = {}

local opened_files = {}

-- @param  filetype  The name of the filetype. Optional
-- @param  buf_info  The dictionary from vim.api.getbufinfo()
file.open = function(filetype, buf_info)
  filetype = util.get_filetype(filetype)

  if opened_files[filetype] == nil then
    opened_files[filetype] = {}
  end

  opened_files[filetype][buf_info.name] = true

  -- Send an open message
  return plugin.client.open(filetype, {textDocument={
      uri = util.get_uri(buf_info.name),
      languageId = filetype,
      text = util.get_buffer_text(buf_info.bufnr),
    }})
end

return file
