local plugin = require('lsp.plugin')
local lsp_util = require('lsp.util')

local lsp_file = {}

local opened_files = {}

-- @param  filetype  The name of the filetype. Optional
-- @param  buf_info  The dictionary from vim.api.getbufinfo()
lsp_file.open = function(filetype, buf_info)
  filetype = lsp_util.get_filetype(filetype)

  if opened_files[filetype] == nil then
    opened_files[filetype] = {}
  end

  opened_files[filetype][buf_info.name] = true

  -- Send an open message
  return plugin.client.open(filetype, {textDocument={
      uri=lsp_util.get_uri(buf_info.name),
      languageId=filetype,
      text=lsp_util.get_buffer_text(buf_info.bufnr),
    }})
end

return lsp_file
