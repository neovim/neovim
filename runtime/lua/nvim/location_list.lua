local FixList = require('nvim._fix_list')

local LocList = setmetatable({}, { __index = FixList })

LocList.new = function(self, title)
  return FixList.new(self, 'setloclist', 'getloclist', 'lopen', 'lclose', title)
end

LocList.set = function(self, action, what)
  if action == nil then
    action = ' '
  end

  FixList.set(self, 0, {}, ' ', self.title)
  FixList.set(self, 0, self.list, action, what)
end

LocList.is_open = function(self)
  error('Not sure how to do this yet', self)
end

return LocList
