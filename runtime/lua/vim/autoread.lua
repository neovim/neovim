--[[
  Create a file watcher, each watcher is identified by the name of the file that it
  watches. We can use a lua table to store all watchers indexed by their filenames
  so that we can close the required watcher during the callback to on_change to
  debounce the watcher.
--]]

local uv = vim.loop

local Watcher = {
  fname = '',
  ffname = '',
  handle = nil,
  paused = false,
  pending_notifs = false,
}
local WatcherList = {}

-- idle handle to check for any pending notifications in a watcher.
-- Only displays the notifications if neovim is in focus, and the buffer
-- is the current buffer.

-- Callback for the idle handle
function check_notifications()
  for f, watcher in pairs(WatcherList) do
    if watcher.pending_notifs and watcher.paused == false then
      if uv.fs_stat(watcher.ffname) ~= nil then
        vim.api.nvim_command('call PromptReload()')
      else
        print("ERR: File "..watcher.fname.." removed")
      end
      watcher.pending_notifs = false
    end
  end
end

local check_handle = uv.new_check()
check_handle:start(vim.schedule_wrap(check_notifications))

function Watcher:new(fname)
  assert(fname ~= '', 'Watcher.new: Error: fname is an empty string')
  -- get full path name for the file
  local ffname = vim.api.nvim_call_function('fnamemodify', {fname, ':p'})
  w = {fname = fname, ffname = ffname, handle = nil}
  setmetatable(w, self)
  self.__index = self
  return w
end

function Watcher:start()
  assert(self.fname ~= '', 'Watcher.start: Error: no file to watch')
  assert(self.ffname ~= '', 'Watcher.start: Error: full path for file not available')
  -- get a new handle
  self.handle = uv.new_fs_event()
  self.handle:start(self.ffname, {}, self.on_change)
end

function Watcher:stop()
  assert(self.fname ~= '', 'Watcher.stop: Error: no file being watched')
  assert(self.handle ~= nil, 'Watcher.stop: Error: no handle watching the file')
  self.handle:stop()
  -- close the handle altogether, for windows.
  if self.handle:is_closing() then
    return
  end
  self.handle:close()
end

function Watcher.on_change(err, fname, event)
  WatcherList[fname].pending_notifs = true

  WatcherList[fname]:stop()
  WatcherList[fname]:start()
end

function Watcher.watch(fname)
  -- since we can only get file name from callback, use only the file
  -- name for storing in table. (Without the rest of the path.)
  local f = vim.api.nvim_call_function('fnamemodify', {fname, ':t'})

  -- if a watcher already exists, close it.
  if WatcherList[f] ~= nil then
    WatcherList[f]:stop()
  end

  -- create a new watcher and it to the watcher list.
  local w = Watcher:new(fname)
  WatcherList[f] = w
  w:start()
end

function Watcher.stop_watch(fname)
  -- Do nothing if we opened a doc file. For some reason doc files never
  -- trigger any event that could start a watcher, and trigger both BufDelete
  -- and BufUnload. This causes us to close watchers that weren't even there
  -- in the first place. We ignore help files here.
  -- TODO: Is there way of getting buftype from the nvim api?
  if starts_with(fname, '/usr/local/share/nvim/runtime/doc') then
    return
  end
  local f = vim.api.nvim_call_function('fnamemodify', {fname, ':t'})

  if WatcherList[f] == nil then
    print("No watcher for "..fname)
    return
  end

  WatcherList[f]:stop()
end

function Watcher:pause_notif()
  self.paused = true
end

function Watcher:resume_notif()
  self.paused = false
end

function Watcher.pause_notif_all()
  check_handle:stop()
end

function Watcher.resume_notif_all()
  check_handle:start(vim.schedule_wrap(check_notifications))
end

function starts_with(str, start)
  assert(type(str) == 'string' and type(start) == 'string',
         'starts_with:Err: string arguments expected')
  return str:sub(1, #start) == start
end

function Watcher.print_all()
  print('Printing all watchers:')
  for i, watcher in pairs(WatcherList) do
    print(i..' '..watcher.fname, watcher.pending_notifs)
  end
end

return Watcher
