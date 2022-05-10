local M = {}

local initial_config = {
  query_file_ignore = {},
}

local config_buf_var_name = "_treesitter_config"
local config_by_lang = {
  ["*"] = vim.deepcopy(initial_config),
}


local validate_argmap = {
  query_file_ignore = {
    "table",
    true,
  },
}

---@private
local function validate_config(key, value)
  if not validate_argmap[key] then
    error(string.format("invalid treesitter option: %s", key))
    return
  end

  vim.validate({
    [key] = {
      value,
      validate_argmap[key][1],
      validate_argmap[key][2],
    },
  })

  return value
end

---@private
local function get_config_for_buf(bufnr)
  local ok, result = pcall(vim.api.nvim_buf_get_var, bufnr, config_buf_var_name)
  if ok then
    return result or {}
  end
  return {}
end

---@private
local function set_config_for_buf(bufnr, config)
  vim.api.nvim_buf_set_var(bufnr, config_buf_var_name, config)
end

---@private
local function get_config_for_lang(lang)
  if not config_by_lang[lang] then
    config_by_lang[lang] = {}
  end
  return config_by_lang[lang]
end

---@private
local function set_config_for_lang(lang, config)
  config_by_lang[lang] = config
end

---@private
function M.get(lang, bufnr)
  local language = type(lang) == "string" and lang or vim.bo.filetype
  local config = vim.tbl_extend(
    "keep",
    get_config_for_buf(bufnr or 0),
    get_config_for_lang(language),
    get_config_for_lang("*")
  )
  return config
end

---@private
function M.set(options, scope)
  local config

  local bufnr = type(scope) == "number" and scope or nil
  local lang = bufnr and nil or (scope or "*")

  if bufnr then
    config = get_config_for_buf(bufnr)
  else
    config = get_config_for_lang(lang)
  end

  for key, value in pairs(options) do
    local resolved_value

    if type(value) == "function" then
      resolved_value = value(config[key] or vim.deepcopy(initial_config[key]))
    else
      resolved_value = value
    end

    config[key] = validate_config(key, resolved_value)
  end

  if bufnr then
    set_config_for_buf(bufnr, config)
  else
    set_config_for_lang(lang, config)
  end
end

return M
