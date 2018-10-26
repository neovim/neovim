local util = require('nvim.util')
local FixList = require('nvim._fix_list')

local QuickFix = setmetatable({}, { __index = FixList })

QuickFix.new = function(self, title)
  return FixList.new(self, 'setqflist', 'getqflist', 'copen', 'cclose', title)
end

QuickFix.set = function(self, action, what)
  if action == nil then
    action = ' '
  end

  FixList.set(self, {}, ' ', self.title)
  FixList.set(self, self.list, action, what)
end

QuickFix.is_open = function(_)
  return util.is_filtetype_open_in_tab('qf', function(buffer_id)
    return (#vim.api.nvim_call_function('getloclist', { buffer_id }) == 0)
  end)
end

return QuickFix
