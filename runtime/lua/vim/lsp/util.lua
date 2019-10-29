local util = {}

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
  return vim.fn.json_decode(data)
end

util.encode_json = function(data)
  return vim.fn.json_encode(data)
end

util.update_tagstack = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.fn.line('.')
  local col = vim.fn.col('.')
  local tagname = vim.fn.expand('<cWORD>')
  local item = { bufnr = bufnr, from = { bufnr, line, col, 0 }, tagname = tagname }
  local winid = vim.fn.win_getid()
  local tagstack = vim.fn.gettagstack(winid)

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
  local current_file = vim.fn.expand('%')

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

return util
