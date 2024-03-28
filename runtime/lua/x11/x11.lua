if not jit then
  error('X11 requires that Neovim is compiled with LuaJIT')
end
local bit = require 'bit'
local ffi = require 'ffi'
local xlib = require 'x11.c.xlib'
local clib = require 'x11.c.clib'
local M = {}

function M.dpyerr()
  error('X display not open')
end
M.code_to_name = {
  [xlib.KeyPress] = 'KeyPress',
  [xlib.KeyRelease] = 'KeyRelease',
  [xlib.ButtonPress] = 'ButtonPress',
  [xlib.ButtonRelease] = 'ButtonRelease',
  [xlib.MotionNotify] = 'MotionNotify',
  [xlib.EnterNotify] = 'EnterNotify',
  [xlib.LeaveNotify] = 'LeaveNotify',
  [xlib.FocusIn] = 'FocusIn',
  [xlib.FocusOut] = 'FocusOut',
  [xlib.KeymapNotify] = 'KeymapNotify',
  [xlib.Expose] = 'Expose',
  [xlib.GraphicsExpose] = 'GraphicsExpose',
  [xlib.NoExpose] = 'NoExpose',
  [xlib.VisibilityNotify] = 'VisibilityNotify',
  [xlib.CreateNotify] = 'CreateNotify',
  [xlib.DestroyNotify] = 'DestroyNotify',
  [xlib.UnmapNotify] = 'UnmapNotify',
  [xlib.MapNotify] = 'MapNotify',
  [xlib.MapRequest] = 'MapRequest',
  [xlib.ReparentNotify] = 'ReparentNotify',
  [xlib.ConfigureNotify] = 'ConfigureNotify',
  [xlib.ConfigureRequest] = 'ConfigureRequest',
  [xlib.GravityNotify] = 'GravityNotify',
  [xlib.ResizeRequest] = 'ResizeRequest',
  [xlib.CirculateNotify] = 'CirculateNotify',
  [xlib.CirculateRequest] = 'CirculateRequest',
  [xlib.PropertyNotify] = 'PropertyNotify',
  [xlib.SelectionClear] = 'SelectionClear',
  [xlib.SelectionRequest] = 'SelectionRequest',
  [xlib.SelectionNotify] = 'SelectionNotify',
  [xlib.ColormapNotify] = 'ColormapNotify',
  [xlib.ClientMessage] = 'ClientMessage',
  [xlib.MappingNotify] = 'MappingNotify',
  [xlib.GenericEvent] = 'GenericEvent',
  [xlib.LASTEvent] = 'LASTEvent',
}
---@help: https://wiki.archlinux.org/title/Xmodmap#Modifier_keys
M.mod_to_number = {
  shift = xlib.ShiftMask,
  lock = xlib.LockMask, --Caps_Lock
  control = xlib.ControlMask,
  mod1 = xlib.Mod1Mask, --Alt/Meta
  mod2 = xlib.Mod2Mask, --Num_Lock
  mod3 = xlib.Mod3Mask,
  mod4 = xlib.Mod4Mask, --Super/Hyper
  mod5 = xlib.Mod5Mask, --ISO_Level3_Shift(AltGr),Mode_switch
}
function M.screen_get_size()
  local screen = xlib.XDefaultScreenOfDisplay(M.display)
  return screen[0].width, screen[0].height
end

function M.term_get_info()
  local sz = ffi.new 'struct winsize[1]'
  clib.ioctl(0, clib.TIOCGWINSZ, sz)
  return {
    row = sz[0].ws_row,
    col = sz[0].ws_col,
    xpixel = sz[0].ws_xpixel,
    ypixel = sz[0].ws_ypixel,
  }
end
function M._term_get_id()
  if not M.display then
    M.dpyerr()
  end
  --Some terminals auto focus {{
  local n = ffi.new 'int[1]'
  local winptr = ffi.new 'Window[1]'
  xlib.XGetInputFocus(M.display, winptr, n)
  if winptr[0] ~= 1 and winptr[0] ~= M.true_root then
    return winptr[0]
  end
  --}}
  local children = ffi.new 'Window*[1]'
  local nchildren = ffi.new 'unsigned int[1]'
  if
    xlib.XQueryTree(
      M.display,
      M.true_root,
      ffi.new 'Window[1]',
      ffi.new 'Window[1]',
      children,
      nchildren
    ) == 0
  then
    error()
  end
  for i = 0, nchildren[0] - 1 do
    local attr = ffi.new 'XWindowAttributes[1]'
    xlib.XGetWindowAttributes(M.display, children[0][i], attr)
    if attr[0].map_state == xlib.IsViewable then
      local ret = children[0][i]
      xlib.XFree(children[0])
      return ret
    end
  end
  xlib.XFree(children[0])
  error('term window not found')
end
function M.term_focus()
  M.win_focus(M.term_root)
end

function M.key_get_mods(mod)
  mod = type(mod) == 'table' and mod or { mod }
  local ret = 0
  for _, v in ipairs(mod) do
    ret = bit.bor(ret, M.mod_to_number[v:lower()])
  end
  return ret
end
function M.key_get_key(key)
  return xlib.XKeysymToKeycode(M.display, xlib['XK_' .. key])
end

function M.win_position(win, col, row, width, height)
  if not M.display then
    M.dpyerr()
  end
  xlib.XMoveResizeWindow(M.display, win, col, row, width, height)
end
function M.win_send_del_signal(win)
  if not M.display then
    M.dpyerr()
  end
  local msg = ffi.new 'XEvent[1]'
  msg[0].xclient.type = xlib.ClientMessage
  msg[0].xclient.message_type = xlib.XInternAtom(M.display, 'WM_PROTOCOLS', 0)
  msg[0].xclient.window = win
  msg[0].xclient.format = 32
  msg[0].xclient.data.l[0] = xlib.XInternAtom(M.display, 'WM_DELETE_WINDOW', 0)
  xlib.XSendEvent(M.display, win, 0, 0, msg)
end
function M.win_focus(win)
  if not M.display then
    M.dpyerr()
  end
  xlib.XSetInputFocus(M.display, win, xlib.RevertToParent, xlib.CurrentTime)
end
function M.win_set_key(win, key, mods)
  if not M.display then
    M.dpyerr()
  end
  xlib.XGrabKey(
    M.display,
    M.key_get_key(key),
    M.key_get_mods(mods),
    win,
    0,
    xlib.GrabModeAsync,
    xlib.GrabModeAsync
  )
end
function M.win_map(win)
  if not M.display then
    M.dpyerr()
  end
  xlib.XMapWindow(M.display, win)
end
function M.win_unmap(win)
  if not M.display then
    M.dpyerr()
  end
  xlib.XUnmapWindow(M.display, win)
end
function M.win_grab_all_button(win)
  if not M.display then
    M.dpyerr()
  end
  xlib.XGrabButton(
    M.display,
    xlib.AnyButton,
    xlib.AnyModifier,
    win,
    0,
    xlib.ButtonPressMask,
    xlib.GrabModeSync,
    xlib.GrabModeSync,
    ffi.new('long', 0),
    ffi.new('long', 0)
  )
end

function M.start()
  if M.display then
    return
  end
  local display = xlib.XOpenDisplay(nil)
  if display == nil then
    error('X display open error')
  end
  local root = xlib.XRootWindow(display, xlib.XDefaultScreen(display))
  if root == nil then
    xlib.XCloseDisplay(display)
    error('X root window error')
  end
  M.display = display
  M.true_root = root
  xlib.XSelectInput(
    M.display,
    root,
    bit.bor(xlib.SubstructureRedirectMask, xlib.SubstructureNotifyMask, xlib.StructureNotifyMask)
  )
  xlib.XSync(M.display, 0)
  M.term_root = M._term_get_id()
end
function M.stop()
  if not M.display then
    return
  end
  xlib.XCloseDisplay(M.display)
  M.display = nil
end

function M.step()
  if not M.display then
    M.dpyerr()
  end
  if xlib.XPending(M.display) == 0 then
    return
  end
  local evptr = ffi.new 'XEvent[1]'
  xlib.XNextEvent(M.display, evptr)
  local ev = evptr[0]
  if ev.type == xlib.MapRequest then
    return { win = ev.xmaprequest.window, type = 'map' }
  elseif ev.type == xlib.UnmapNotify then
    return { win = ev.xunmap.window, type = 'unmap' }
  elseif ev.type == xlib.ConfigureRequest then
    ---HACK: this is only here so that specific guis work (like xterm)
    ---Will be removed when a proper configuration system is implemented
    local cev = ev.xconfigurerequest
    local changes = ffi.new 'XWindowChanges[1]'
    changes[0].x = cev.x
    changes[0].y = cev.y
    changes[0].width = cev.width
    changes[0].height = cev.height
    xlib.XConfigureWindow(M.display, cev.window, cev.value_mask, changes)
    return
  elseif ev.type == xlib.KeyRelease then
    return { type = 'key', mod = ev.xkey.state, key = ev.xkey.keycode, win = ev.xkey.window }
  elseif ev.type == xlib.DestroyNotify then
    return { type = 'destroy', win = ev.xdestroywindow.window }
  elseif ev.type == xlib.ConfigureNotify then
    return {
      type = 'resize',
      win = ev.xconfigure.window,
      width = ev.xconfigure.width,
      height = ev.xconfigure.height,
    }
  elseif ev.type == xlib.ButtonPress then
    xlib.XAllowEvents(M.display, xlib.ReplayPointer, xlib.CurrentTime)
    return { type = 'focus', win = ev.xbutton.window }
  else
    return { type = 'other', type_id = ev.type }
  end
end
return M
