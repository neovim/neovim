-- LuaLS cannot model the generic annotations used by this vendored implementation.
---@diagnostic disable: no-unknown, undefined-doc-name, luadoc-miss-symbol, missing-return, missing-return-value, param-type-mismatch, return-type-mismatch, redundant-return-value, undefined-field, need-check-nil, await-in-sync

local M = {}

local nil_error = 'error(nil)'

--- @nodoc
function M.normalize(err)
  return err == nil and nil_error or err
end

return M
