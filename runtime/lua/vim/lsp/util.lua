local util = {
  ui = require('vim.lsp.util.ui'),
}

local get_buffer_lines = function(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

util.get_buffer_text = function(bufnr)
  return table.concat(get_buffer_lines(bufnr), '\n')
end

util.get_filetype = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return vim.api.nvim_buf_get_option(bufnr, 'filetype')
end

util.decode_json = function(data)
  return vim.api.nvim_call_function('json_decode', {data})
end

util.encode_json = function(data)
  return vim.api.nvim_call_function('json_encode', {data})
end

util.update_tagstack = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_call_function('line', {'.'})
  local col = vim.api.nvim_call_function('col', {'.'})
  local tagname = vim.api.nvim_call_function('expand', { '<cWORD>' })
  local item = { bufnr = bufnr, from = { bufnr, line, col, 0 }, tagname = tagname }
  local winid = vim.api.nvim_call_function('win_getid', {})
  local tagstack = vim.api.nvim_call_function('gettagstack', { winid })

  local action

  if tagstack.length == tagstack.curidx then
    action = 'r'
    tagstack.items[tagstack.curidx] = item
  elseif tagstack.length > tagstack.curidx then
    action = 'r'
    if tagstack.curidx > 1 then
      tagstack.items = table.insert(tagstack.items[tagstack.curidx - 1], item)
    else
      tagstack.items = { item }
    end
  else
    action = 'a'
    tagstack.items = { item }
  end

  tagstack.curidx = tagstack.curidx + 1
  vim.api.nvim_call_function('settagstack', { winid, tagstack, action })
end

util.handle_location = function(result)
  local current_file = vim.api.nvim_call_function('expand', {'%'})

  -- We can sometimes get a list of locations,
  -- so set the first value as the only value we want to handle
  if result[1] ~= nil then
    result = result[1]
  end

  if result.uri == nil then
    vim.api.nvim_err_writeln('[LSP] Could not find a valid location')
    return
  end

  if type(result.uri) ~= 'string' then
    vim.api.nvim_err_writeln('Invalid uri')
    return
  end

  local result_file = vim.uri_to_fname(result.uri)

  util.update_tagstack()
  if result_file ~= vim.uri_from_fname(current_file) then
    vim.api.nvim_command('silent edit ' .. result_file)
  end

  vim.api.nvim_command(
    string.format('normal! %sG%s|'
      , result.range.start.line + 1
      , result.range.start.character + 1
    )
  )
end

util.get_HoverContents_type = function(contents)
  if vim.tbl_islist(contents) == true then
    return 'MarkedString[]'
  elseif type(contents) == 'table' then
    if contents.kind then
      return 'MarkupContent'
    elseif contents.language then
      return 'MarkedString'
    end
  elseif type(contents) == 'string' then
    return 'MarkedString'
  else
    return nil
  end
end

util.is_CompletionList = function(result)
  if type(result) == 'table' then
    if result.items then
      return true
    end
  end
  return false
end

return util
