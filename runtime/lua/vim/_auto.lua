---@class EventContext
---@field _group string|boolean
---@field _buffer integer|boolean
local EventContext = {}

---@class Event
---@field _ctx EventContext
---@field _event string|string[]
---@field _pattern? string|string[]
local Event = {}

---@class Augroup
---@field _ctx EventContext
---@field _group string
local Augroup = {}

local a, validate = vim.api, vim.validate

---@param group? string|boolean
---@param buffer? integer|boolean
---@return EventContext
---@private
function EventContext._new(group, buffer)
  -- use non-nil values to avoid triggering the `__index` metamethod when we access fields on self.
  local self = {
    _group = group or false,
    _buffer = buffer or false,
  }
  return setmetatable(self, EventContext)
end

---@param opts? table API options
---@return table opts
function EventContext:_apply(opts)
  opts = opts or {}
  local g, b = self._group, self._buffer
  b = b == true and 0 or b
  opts.buffer = b or opts.buffer
  opts.group = g or opts.group
  return opts
end

---@param self EventContext
---@param opts? table
---@return table
---@see |nvim_get_autocmds()|
function EventContext:get(opts)
  return a.nvim_get_autocmds(self:_apply(opts))
end

---@param self EventContext
---@param opts? table
---@see |nvim_clear_autocmds()|
function EventContext:clear(opts)
  a.nvim_clear_autocmds(self:_apply(opts))
end

---@param self EventContext
---@private
function EventContext:__index(k)
  -- first, check methods
  if EventContext[k] then
    return EventContext[k]
  end
  -- then, check if we're trying to specify a buffer
  if k == "buf" then
    return self._buffer == false and EventContext._new(self._group, true) or nil
  elseif type(k) == "number" then
    return self._buffer == true and EventContext._new(self._group, k) or nil
  end
  -- nothing else to check; use k as event name
  return Event._new(self, k)
end

---@param ctx EventContext
---@param event string|string[]
---@param pattern? string|string[]
---@return Event
---@private
function Event._new(ctx, event, pattern)
  local self = {
    _ctx = ctx,
    _event = event,
    _pattern = pattern or false,
  }
  return setmetatable(self, Event)
end

---@param self Event
---@param opts? table
---@return table[]
function Event:get(opts)
  opts = self._ctx:_apply(opts)
  opts.event = self._event
  opts.pattern = self._pattern or opts.pattern
  return a.nvim_get_autocmds(opts)
end

---@param self Event
---@param opts? table
function Event:exec(opts)
  opts = self._ctx:_apply(opts)
  opts.pattern = self._pattern or opts.pattern
  a.nvim_exec_autocmds(self._event, opts)
end

---@param self Event
---@param opts? table
function Event:clear(opts)
  opts = self._ctx:_apply(opts)
  opts.event = self._event
  opts.pattern = self._pattern or opts.pattern
  a.nvim_clear_autocmds(opts)
end

--- Create an autocommand for this event
---@param self Event
---@param handler string|function
---@param opts? table
---@return integer
function Event:__call(handler, opts)
  validate {
    handler = { handler, {"s", "f"} },
    opts = { opts, "t", true },
  }
  opts = self._ctx:_apply(opts)
  opts.pattern = self._pattern or opts.pattern
  if type(handler) == "string" and handler:sub(1, 1) == ":" then
    opts.command = handler:sub(2)
  else
    opts.callback = handler
  end
  return a.nvim_create_autocmd(self._event, opts)
end

---@param self Event
---@return function|Event|nil
function Event:__index(k)
  if Event[k] then
    return Event[k]
  elseif not self._pattern and not self._ctx._buffer then
    return Event._new(self._ctx, self._event, k)
  else
    return nil
  end
end

Augroup.__index = Augroup

---@param name string
---@return Augroup
function Augroup._new(name)
  local self = {
    _ctx = EventContext._new(name, nil),
    _group = name,
  }
  return setmetatable(self, Augroup)
end

---@param self Augroup
---@return integer id
function Augroup:create()
  return a.nvim_create_augroup(self._group, { clear = false })
end

---@param self Augroup
---@param opts? table
---@return integer? id
function Augroup:clear(opts)
  if not opts then
    return a.nvim_create_augroup(self._group, { clear = true })
  else
    self._ctx:clear(opts)
  end
end

---@param self Augroup
function Augroup:del()
  return a.nvim_del_augroup_by_name(self._group)
end

---@param self Augroup
---@param opts? table
---@return table[]?
function Augroup:get(opts)
  if not opts then
    local exists, cmds = pcall(a.nvim_get_autocmds, { group = self._group })
    return exists and cmds or nil
  else
    return self._ctx:get(opts)
  end
end

---@param self Augroup
---@param spec fun(au:EventContext):any
---@return integer id 
---@return any
function Augroup:__call(spec)
  local id = self:create()
  local res = spec(self._ctx)
  return id, res
end

--- Use `vim.autocmd` to manage autocommands. Index it by event names to create and execute them.
---
--- To create an autocommand, index `vim.autocmd` with an event name to return a callable table.
--- Then call it with a handler (a Lua function, a Vimscript function name, or Ex command) and
--- and optional table of options to pass to |nvim_create_autocmd()|.
---
--- <pre>lua
---   -- prefix Ex commands with ":" to use as an event handler
---   vim.autocmd.UIEnter(":echo 'Hello!'")
---   -- a Lua callback as an event handler
---   vim.autocmd.UIEnter(function()
---     vim.cmd.echo 'Hello!'
---   end)
---   -- passing in additional options
---   vim.autocmd.UIEnter(":echo 'Hello!'", {
---     desc = "greeting",
---     once = true,
---   })
---   -- specify multiple events
---   vim.autocmd[{ "UIEnter", "TabEnter", "TermEnter" }](":echo 'Hello!'")
--- </pre>
---
--- You may also specify a pattern by indexing the event.
---
--- <pre>lua
---   vim.autocmd.FileType[{ "qf", "help", "man", }](function()
---     vim.opt_local.number = false
---     vim.opt_local.relativenumber = false
---   end)
--- </pre>
---
vim.autocmd = EventContext._new(nil, nil)

vim.autocmd.buf = EventContext._new(nil, 0)

--- Create, delete, and clear autocommand groups with `vim.augroup`.
---
vim.augroup = setmetatable({}, {
  __index = function(_, k) return Augroup._new(k) end,
})
