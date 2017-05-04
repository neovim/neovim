local plugin = require('lsp.plugin')
local lsp_util = require('lsp.util')

local lsp_file = {}

local opened_files = {}

lsp_file.open_all = function(filetype)
  filetype = lsp_util.get_filetype(filetype)

  local openBuffers = vim.api.nvim_call_function(
      'getbufinfo',
      {{loaded=true}}
      )

  for buf_info in pairs(openBuffers) do
    if vim.api.nvim_buf_get_option(buf_info.bufnr, 'filetype') == filetype then
      lsp_file.open(filetype, buf_info)
    end
  end
end

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

lsp_file.opened = function(filetype)
  filetype = lsp_util.get_filetype(filetype)

  if opened_files[filetype] == nil then
    return {}
  end

  return opened_files[filetype]
end

-- @param buffer_name The complete file path, not a URI
--      The file path as returned by getbufinfo
lsp_file.is_open = function(filetype, buffer_name)
  return lsp_file.open_all(filetype)[buffer_name]
end

return lsp_file
