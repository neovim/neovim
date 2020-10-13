-- Create a file watcher, each watcher is identified by the name of the file that it
-- watches.

local uv = vim.loop
local Watcher = {}
Watcher.__index = Watcher
local WatcherList = {}
local check_handle = nil

-- Callback for the check handle, checks if there are pending notifications
-- for any watcher, and handles them as per the value of the `fcnotify`
-- option.
local function check_notifications()
  for _, watcher in pairs(WatcherList) do
    if watcher.pending_notifs == true then
      vim.api.nvim_command('checktime '..watcher.bufnr)
      watcher.pending_notifs = false
    end
  end
end

local function fs_event_start(bufnr)
  WatcherList[bufnr].handle = uv.new_fs_event()
  WatcherList[bufnr].handle:start(WatcherList[bufnr].fpath, {}, vim.schedule_wrap(function(...)
    WatcherList[bufnr]:on_change(...)
  end))
end

local function check_handle_start()
  check_handle = uv.new_check()
  check_handle:start(vim.schedule_wrap(check_notifications))
end

local function set_mechanism(option_type, bufnr)
  if option_type == 'global' then
    local option = vim.api.nvim_get_option('filechangenotify')
    if option:find('watcher') then
      for _, watcher in pairs(WatcherList) do
        watcher._start_handle = fs_event_start
      end
      Watcher.start_notifications = check_handle_start
    else
      for _, watcher in pairs(WatcherList) do
        watcher._start_handle = nil
      end
      Watcher.start_notifications = nil
    end
  elseif option_type == 'local' then
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local status, option = pcall(vim.api.nvim_buf_get_option, bufnr, 'filechangenotify')
    if not status then
      option = vim.api.nvim_get_option('filechangenotify')
    end
    if option:find('watcher') then
      WatcherList[bufnr]._start_handle = fs_event_start
      Watcher.start_notifications = check_handle_start
    else
      WatcherList[bufnr]._start_handle = nil
    end
  end
  Watcher.stop_notifications()
  Watcher.start_notifications()
end

-- Checks if a buffer should have a watcher attached to it.
local function valid_buf(bufnr)
  if bufnr < 0 then
    return false
  end

  local fname = vim.api.nvim_buf_get_name(bufnr)
  local buflisted = vim.api.nvim_buf_get_option(bufnr, 'buflisted')
  local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')

  return buflisted or buftype == '' or buftype == 'acwrite'
end

--- Creates and initializes a new watcher object with the given filename.
---
--@param bufnr: (required, number) The buffer number of the buffer that
--- is to be watched.
function Watcher:new(bufnr)
  vim.validate{bufnr = {bufnr, 'number', false}}
  -- get full path name for the file
  local fname = vim.api.nvim_buf_get_name(bufnr)
  local fpath = vim.api.nvim_call_function('fnamemodify', {fname, ':p'})
  local w = {bufnr = bufnr, fname = fname, fpath = fpath,
       handle = nil, pending_notifs = false}
  w._start_handle = nil
  setmetatable(w, self)
  return w
end

--- Starts the watcher
---
--@param self: (required, table) The watcher which should be started.
function Watcher:start()
  set_mechanism('local', self.bufnr)
  if self._start_handle then
    self._start_handle(self.bufnr)
  end
end

--- Stops the watcher and closes the handle.
---
--@param self: (required, table) The watcher which should be stopped.
function Watcher:stop()
  if self.handle == nil then
    return
  end

  self.handle:stop()

  -- close the handle altogether, for windows.
  if self.handle:is_closing() then
    return
  end
  self.handle:close()
end

--- Debounces the watcher. Completely closes the handle and starts again with a new
--- handle. Necessary for cases when the file being monitored is edited via editors
--- like vim, which, depending on the value of `backupcopy`, move the original file
--- for backing it up.
---
--@param self:(required, table) The watcher object which should be debounced.
function Watcher:debounce()
  self:stop()
  self:start()
end

--- Callback for watcher handle. Marks a watcher as having pending
--- notifications. The nature of notification is determined while
--- responding to the notification.
---
--@param err: (string) Error if any occured during the execution of the callback.
---
function Watcher:on_change(err)
  if err ~= nil then
    error(err)
  end

  self.pending_notifs = true

  self:debounce()
end

--- Starts and initializes a watcher for the given path. A thin wrapper around
--- Watcher:start() that can be called from vimscript.
---
--@param bufnr: (required, string) The path that the watcher should watch.
function Watcher.start_watch(bufnr)
  bufnr = tonumber(bufnr)
  if not valid_buf(bufnr) then
    return
  end

  if WatcherList[bufnr] ~= nil then
    return
  end

  WatcherList[bufnr] = Watcher:new(bufnr)
  WatcherList[bufnr]:start()
end

--- Stops the watcher watching a given file and closes it's handle. A
--- thin wrapper around Watcher:stop() that can be called from vimscript.
---
--@param bufnr: (required, string) The buffer number of the buffer
--- that was being watched.
function Watcher.stop_watch(bufnr)
  bufnr = tonumber(bufnr)
  -- can't close watchers for certain buffers
  if not valid_buf(bufnr) then
    return
  end

  -- shouldn't happen
  if WatcherList[bufnr] == nil then
    return
  end

  WatcherList[bufnr]:stop()
end

--- Stop reacting to notifications for all the watchers until we are
--- asked to start reacting again.
function Watcher.stop_notifications()
  if check_handle == nil then
    return
  end
  check_handle:stop()
  if not check_handle:is_closing() then
    check_handle:close()
  end
  check_handle = nil
end

--- Start reacting to notifications for all watcher.
--- A stub that calls the correct function depending upon
--- the option value for `fcnotify`.
function Watcher.start_notifications()
end

--- Function for checking which option was set and
--- setting the respective backend mechanism for the
--- watchers.
---
--@param: (required, string) option_type 'global' or 'local'
function Watcher.check_option(option_type)
  set_mechanism(option_type)
  if option_type == 'global' then
    for _, watcher in pairs(WatcherList) do
      watcher:debounce()
    end
  elseif option_type == 'local' then
    local bufnr = vim.api.nvim_get_current_buf()
    WatcherList[bufnr]:debounce()
  end
end

return Watcher
