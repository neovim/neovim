-- Create a file watcher, each watcher is identified by the buffer number of the file it is watching.

local uv = vim.loop

local Watcher = {}
Watcher.__index = Watcher
local WatcherList = {}

local in_focus = true

-- Checks if a buffer should have a watcher attached to it.
local function buf_isvalid(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local buflisted = vim.api.nvim_buf_get_option(bufnr, 'buflisted')
  local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')

  return buflisted or buftype == '' or buftype == 'acwrite'
end

-- Checks for pending notifications and reacts if notifications are pending.
-- Only called when neovim is in focus.
local function handle_pending_notifications()
  for _, watcher in pairs(WatcherList) do
    if watcher.pending_notifs and buf_isvalid(watcher.bufnr) then
      vim.api.nvim_command(string.format('checktime %d', watcher.bufnr))
      watcher.pending_notifs = false
    end
  end
end

--- Set in_focus to true and handle pending notifications.
---
--@param none
local function handle_focus_gained()
  in_focus = true
  if in_focus then
    handle_pending_notifications()
  end
end

--- Set in_focus to false
---
--@param none
local function handle_focus_lost()
    in_focus = false
end

-- Start the libuv fs_event handle
local function fs_event_start_buf(bufnr)
  local watcher = WatcherList[bufnr]
  if watcher.handle and not watcher.handle:is_closing() then watcher.handle:close() end
  watcher.handle = uv.new_fs_event()
  watcher.handle:start(watcher.fpath, {}, vim.schedule_wrap(function(...)
    watcher:on_change(...)
  end))
end

--- Creates and initializes a new watcher object with the given filename.
---
--@param bufnr: (required, number) The buffer number of the buffer that
--- is to be watched.
function Watcher:new(bufnr)
  vim.validate{bufnr = {bufnr, 'number', false}}
  -- get full path name for the file
  local fname = vim.api.nvim_buf_get_name(bufnr)
  local fpath = vim.fn.fnamemodify(fname, ':p')
  local w = {
    bufnr = bufnr,
    fname = fname,
    fpath = fpath,
    handle = nil,
    pending_notifs = false,
    _start_handle = nil
  }
  setmetatable(w, self)
  return w
end

--- Starts the watcher
---
--@param self: (required, table) The watcher which should be started.
function Watcher:start_handle()
  if self._start_handle then
    self._start_handle(self.bufnr)
  end
end

--- Stops the watcher and closes the handle.
---
--@param self: (required, table) The watcher which should be stopped.
function Watcher:stop_handle()
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
  self:stop_handle()
  self:start_handle()
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
  if in_focus then
    handle_pending_notifications()
  end

  self:debounce()
end

--- Starts and initializes a watcher for the given path. A thin wrapper around
--- Watcher:start() that can be called from vimscript.
---
--@param bufnr: (required, string) The path that the watcher should watch.
local function start_watching_buf(bufnr)
  bufnr = tonumber(bufnr)
  if not buf_isvalid(bufnr) then
    return
  end

  if WatcherList[bufnr] ~= nil then
    WatcherList[bufnr]:debounce()
    return
  end

  WatcherList[bufnr] = Watcher:new(bufnr)
  WatcherList[bufnr]:start_handle()
end

--- Stops the watcher watching a given file and closes it's handle. A
--- thin wrapper around Watcher:stop() that can be called from vimscript.
---
--@param bufnr: (required, string) The buffer number of the buffer
--- that was being watched.
local function stop_watching_buf(bufnr)
  bufnr = tonumber(bufnr)
  -- can't close watchers for certain buffers
  if not buf_isvalid(bufnr) then
    return
  end

  -- shouldn't happen
  if WatcherList[bufnr] == nil then
    return
  end

  WatcherList[bufnr]:stop_handle()
end

-- Get the backend for a watcher depending upon the value of filechangenotify option
local function get_watcher_backend(option_value)
  if vim.tbl_contains(vim.split(option_value, ','), 'watcher') then
    return fs_event_start_buf
  else
    return nil
  end
end

local function update_watcher_backend(bufnr, option_value)
  local watcher = WatcherList[bufnr]
  watcher._start_handle = get_watcher_backend(option_value)
  watcher:debounce()
end

local function init_watcher_list()
  local bufnr = vim.api.nvim_get_current_buf()
  WatcherList[bufnr] = Watcher:new(bufnr)
end

--- Function for checking which option was set and
--- setting the respective backend mechanism for the
--- watchers.
---
--@param: (required, string) option_type 'global' or 'local'
local function handle_option_set(option_type, option_value)
  if vim.tbl_isempty(WatcherList) then init_watcher_list() end
  if option_type == 'global' then
    for bufnr, _ in pairs(WatcherList) do
      update_watcher_backend(bufnr, option_value)
    end
  elseif option_type == 'local' then
    local bufnr = vim.api.nvim_get_current_buf()
    update_watcher_backend(bufnr, option_value)
  end
  vim.api.nvim_command(':runtime plugin/fcnotify.vim')
end

return {
  handle_focus_gained = handle_focus_gained,
  handle_focus_lost = handle_focus_lost,
  start_watching_buf = start_watching_buf,
  stop_watching_buf = stop_watching_buf,
  handle_option_set = handle_option_set,
}
