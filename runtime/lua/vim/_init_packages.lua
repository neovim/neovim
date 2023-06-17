-- builtin functions which always should be available
require('vim.shared')

vim._submodules = {
  inspect = true,
  version = true,
  fs = true,
  iter = true,
  re = true,
}

-- These are for loading runtime modules in the vim namespace lazily.
setmetatable(vim, {
  __index = function(t, key)
    if vim._submodules[key] then
      t[key] = require('vim.' .. key)
      return t[key]
    elseif key == 'inspect_pos' or key == 'show_pos' then
      require('vim._inspector')
      return t[key]
    elseif vim.startswith(key, 'uri_') then
      local val = require('vim.uri')[key]
      if val ~= nil then
        -- Expose all `vim.uri` functions on the `vim` module.
        t[key] = val
        return t[key]
      end
    end
  end,
})

--- <Docs described in |vim.empty_dict()| >
---@private
--- TODO: should be in vim.shared when vim.shared always uses nvim-lua
function vim.empty_dict()
  return setmetatable({}, vim._empty_dict_mt)
end

-- only on main thread: functions for interacting with editor state
if vim.api and not vim.is_thread() then
  require('vim._editor')
end

-- TODO(bfredl): dedicated state for this?
if vim.api then
  -- load vim.loader last since it depends on other modules
  vim.loader.enable()
end
