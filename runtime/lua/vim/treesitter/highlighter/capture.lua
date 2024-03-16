local Capture = {}

--- @param match table<integer,TSNode[]>
--- @param bufnr integer
--- @param capture integer
--- @param metadata vim.treesitter.query.TSMetadata
--- @return string?
function Capture.get_url(match, bufnr, capture, metadata)
  ---@type string|number|nil
  local url = metadata[capture] and metadata[capture].url

  if not url or type(url) == 'string' then
    return url
  end

  if not match or not match[url] then
    return
  end

  -- Assume there is only one matching node. If there is more than one, take the URL
  -- from the first.
  local other_node = match[url][1]

  return vim.treesitter.get_node_text(other_node, bufnr, {
    metadata = metadata[url],
  })
end

--- @param capture_name string
--- @return boolean?, integer
function Capture.get_spell(capture_name)
  if capture_name == 'spell' then
    return true, 0
  elseif capture_name == 'nospell' then
    -- Give nospell a higher priority so it always overrides spell captures.
    return false, 1
  end
  return nil, 0
end

return Capture
