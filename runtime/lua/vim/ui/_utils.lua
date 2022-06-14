local utils = {}

function utils.tbl_apply_defaults(original, defaults)
  if original == nil then
    original = {}
  end

  original = vim.deepcopy(original)

  for k, v in pairs(defaults) do
    if original[k] == nil then
      original[k] = v
    end
  end

  return original
end

function utils.tbl_longest_str(tbl)
  local len = 0

  for _,str in pairs(tbl) do
    local str_len = #str
    if str_len > len then
      len = str_len
    end
  end

  return len
end

return utils
