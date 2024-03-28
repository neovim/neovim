if not jit then
  error('X11 requires that Neovim is compiled with LuaJIT')
end
local x11 = require 'x11.x11'
local M = {}
---@type table<string,{buf:number,conf:table,win:number,focus:boolean}>
local windows = {}

M.config = {
  ---@diagnostic disable-next-line: unused-local
  on_win_open = function(buf, xwin)
    vim.cmd.vsplit()
    vim.api.nvim_set_current_buf(buf)
  end,
  ---@diagnostic disable-next-line: unused-local
  on_win_get_conf = function(conf, xwin)
    return conf
  end,
  ---@diagnostic disable-next-line: unused-local
  on_multiple_win_open = function(vwins, buf, xwin)
    for k, vwin in
      ipairs(vwins --[[@as (number[])]])
    do
      if k ~= 1 then
        local scratchbuf = vim.api.nvim_create_buf(false, true)
        vim.bo[scratchbuf].bufhidden = 'wipe'
        vim.api.nvim_win_set_buf(vwin, scratchbuf)
      end
    end
  end,
  verbose = false,
  unfocus_map = '<C-\\>',
  maps = {},
  autofocus = false,
  delhidden = true,
  clickgoto = true,
}

local function key_convert(keymap)
  if vim.api.nvim_strwidth(keymap) ~= #keymap then
    error("Doesn't support utf8 keymap")
  end
  keymap = vim.fn.keytrans(vim.api.nvim_replace_termcodes(keymap, true, true, true))
  ---@type string[]
  local match
  if keymap:sub(1, 1) == '<' then
    ---@type number
    local spec_end = keymap:find('>', 1, true)
    if not spec_end then
      error('Invalid keymap: ' .. keymap)
    elseif #keymap > spec_end then
      error('More than one key based keymaps are not supported yet')
    end
    match = { '' }
    for i in
      (keymap:gmatch('[^<>]') --[[@as fun():string]])
    do
      if i == '-' and match[#match] ~= '' then
        table.insert(match, '')
      else
        match[#match] = match[#match] .. i
      end
    end
  else
    if #keymap > 1 then
      error('More than one key based keymaps are not supported yet')
    end
    match = { keymap }
  end
  local function isupper(c)
    return #c == 1 and c:upper() == c and c:lower() ~= c or nil
  end
  local key = table.remove(match)
  ---@type table<string,boolean?>
  local mods = {}
  for _, mod in ipairs(match) do
    mods[mod] = true
  end
  if not mods.C then
    mods.S = mods.S or isupper(key)
  end
  local vim_mod_to_mod = {
    S = 'shift',
    C = 'control',
    M = 'mod1',
    T = 'mod1',
    D = 'mod4',
  }
  local vim_key_to_key = {
    [' '] = 'space',
    ['!'] = 'exclam',
    ['"'] = 'quotedbl',
    ['#'] = 'numbersign',
    ['$'] = 'dollar',
    ['%'] = 'percent',
    ['&'] = 'ampersand',
    ["'"] = 'apostrophe',
    ['('] = 'parenleft',
    [')'] = 'parenright',
    ['*'] = 'asterisk',
    ['+'] = 'plus',
    [','] = 'comma',
    ['-'] = 'minus',
    ['.'] = 'period',
    ['/'] = 'slash',
    [':'] = 'colon',
    [';'] = 'semicolon',
    ['lt'] = 'less',
    ['='] = 'equal',
    ['>'] = 'greater',
    ['?'] = 'question',
    ['@'] = 'at',
    ['['] = 'bracketleft',
    ['\\'] = 'backslash',
    ['Bslash'] = 'backslash',
    [']'] = 'bracketright',
    ['^'] = 'asciicircum',
    ['_'] = 'underscore',
    ['`'] = 'grave',
    ['{'] = 'braceleft',
    ['Bar'] = 'bar',
    ['}'] = 'braceright',
    ['~'] = 'asciitilde',
    BS = 'BackSpace',
    NL = 'Linefeed',
    CR = 'Return',
    Esc = 'Escape',
    Space = 'space',
    Del = 'Delete',
    PageUp = 'Page_Up',
    PageDown = 'Page_Down',
    kUp = 'KP_Up',
    kDown = 'KP_Down',
    kLeft = 'KP_Left',
    kRight = 'KP_Right',
    kHome = 'KP_Home',
    kEnd = 'KP_End',
    kOrigin = 'KP_Begin',
    kPageUp = 'KP_Page_Up',
    kPageDown = 'KP_Page_Down',
    kDel = 'KP_Delete',
    kPlus = 'KP_Add',
    kMinus = 'KP_Subtract',
    kMultiply = 'KP_Multiply',
    kDivide = 'KP_Divide',
    kPoint = 'KP_Decimal',
    kComma = 'KP_Separator',
    kEqual = 'KP_Equal',
    kEnter = 'KP_Enter',
    k0 = 'KP_0',
    k1 = 'KP_1',
    k2 = 'KP_2',
    k3 = 'KP_3',
    k4 = 'KP_4',
    k5 = 'KP_5',
    k6 = 'KP_6',
    k7 = 'KP_7',
    k8 = 'KP_8',
    k9 = 'KP_9',
  }
  local ret = { mods = {}, key = assert(vim_key_to_key[key] or #key == 1 and key:upper() or key) }
  for i in pairs(mods) do
    table.insert(ret.mods, vim_mod_to_mod[i])
  end
  return ret
end
function M.term_supported()
  local info = x11.term_get_info()
  return info.xpixel ~= 0 and info.ypixel ~= 0
end
local function term_set_size(width, height)
  x11.win_position(x11.term_root, 0, 0, width, height)
end

local function win_del_win(win)
  x11.win_send_del_signal(win)
end
local function win_set_button(win, conf)
  if not conf.clickgoto then
    return
  end
  x11.win_grab_all_button(win)
end
local function win_del_buf(win)
  if not windows[tostring(win)] then
    return
  end
  local buf = windows[tostring(win)].buf
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  windows[tostring(win)] = nil
end
local function win_del(win)
  win_del_buf(win)
  win_del_win(win)
end
local function win_unfocus(win)
  local opt = windows[tostring(win)]
  opt.focus = false
  if vim.api.nvim_get_current_buf() == windows[tostring(win)].buf then
    vim.cmd.stopinsert()
    x11.term_focus()
  end
end
local function win_update(hash, event)
  hash = type(hash) == 'string' and hash or tostring(hash)
  local opt = windows[hash]
  if not opt then
    return true
  end
  local win = opt.win
  if not vim.api.nvim_buf_is_valid(opt.buf) then
    win_del_win(win)
    return
  end
  if opt.conf.delhidden then
    if not vim.fn.win_findbuf(opt.buf)[1] then
      win_del(win)
      return
    end
  end
  ---@type number[]
  local vwins = {}
  local _repeat = 0
  while true do
    for _, vwin in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_buf(vwin) == opt.buf then
        table.insert(vwins, vwin)
      end
    end
    if #vwins <= 1 then
      break
    end
    opt.conf.on_multiple_win_open(vwins, opt.buf, win)
    vwins = {}
    _repeat = _repeat + 1
    if _repeat > 100 then
      error()
    end
  end
  if #vwins == 0 then
    x11.win_unmap(win)
    return
  end
  local vwin = vwins[1]
  x11.win_map(win)
  local terminfo = x11.term_get_info()
  local xpx = math.floor(terminfo.xpixel / vim.o.columns)
  local ypx = math.floor(terminfo.ypixel / vim.o.lines)
  local height = vim.api.nvim_win_get_height(vwin)
  local width = vim.api.nvim_win_get_width(vwin)
  ---@type number,number
  local row, col = unpack(vim.api.nvim_win_get_position(vwin))
  x11.win_position(win, col * xpx, row * ypx, width * xpx, height * ypx)
  if vim.api.nvim_get_current_buf() == opt.buf then
    if opt.conf.autofocus and event == 'enter' then
      opt.focus = true
    end
    if opt.focus then
      vim.cmd.startinsert()
      x11.win_focus(win)
    else
      win_unfocus(win)
    end
  end
end
local function win_update_all(event)
  if event == 'enter' then
    x11.term_focus()
  end
  for win, _ in pairs(windows) do
    win_update(win, event)
  end
end
local function win_set_keys(win, conf)
  for _, map in ipairs({ { conf.unfocus_map }, unpack(conf.maps) }) do
    ---@type table
    map = map[1]
    if type(map) ~= 'table' then
      map = key_convert(map)
    end
    x11.win_set_key(win, map.key, map.mods)
  end
end
---@param conf table
local function win_init(win, conf)
  if windows[tostring(win)] then
    return
  end
  local opt = {
    win = win,
    conf = conf.on_win_get_conf(conf, win) --[[@as table]],
    focus = false,
  }
  opt.buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_open_term(opt.buf, {})
  windows[tostring(win)] = opt
  vim.api.nvim_buf_set_name(opt.buf, 'x11://' .. tonumber(win))
  vim.api.nvim_create_autocmd('TermEnter', {
    callback = function()
      opt.focus = true
      win_update(win)
    end,
    buffer = opt.buf,
  })
  vim.api.nvim_create_autocmd('TermLeave', {
    callback = function()
      opt.focus = false
      win_update(win)
    end,
    buffer = opt.buf,
  })
  win_set_button(win, conf)
  win_set_keys(win, conf)
  conf.on_win_open(opt.buf, win)
end
local function win_goto(win)
  win_update_all()
  local opt = windows[tostring(win)]
  if not opt then
    return
  end
  for _, vwin in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(vwin) == opt.buf then
      vim.api.nvim_set_current_win(vwin)
      break
    end
  end
end

local function key_handle(win, key, mod, config)
  local conf = windows[tostring(win)].conf
  local function run(map, callback)
    if type(map) ~= 'table' then
      map = key_convert(map)
    end
    local key_ = map.key
    local mod_ = map.mods
    if mod == x11.key_get_mods(mod_) and key == x11.key_get_key(key_) then
      callback()
      return true
    end
  end
  if run(conf.unfocus_map, function()
    win_unfocus(win)
  end) then
    return
  end
  for _, map in
    (ipairs(conf.maps) --[[@as fun():number,table]])
  do
    if run(map[1], map[2]) then
      return
    end
  end
  if config.verbose then
    vim.notify('key not handled ' .. key .. ' ' .. mod)
  end
end

local function step()
  local ev = x11.step()
  if not ev then
    return
  end
  if ev.type == 'map' then
    win_init(ev.win, M.config)
  elseif ev.type == 'unmap' then
    --TODO: close window
  elseif ev.type == 'key' then
    key_handle(ev.win, ev.key, ev.mod, M.config)
  elseif ev.type == 'destroy' then
    win_del_buf(ev.win)
  elseif ev.type == 'focus' then
    win_goto(ev.win)
  elseif ev.type == 'resize' then
    if ev.win == x11.true_root then
      term_set_size(ev.width, ev.height)
    end
    win_update_all()
  elseif ev.type == 'other' then
    if M.config.verbose then
      vim.notify('event not handled ' .. x11.code_to_name[ev.type_id], vim.log.levels.INFO)
    end
  else
    error()
  end
end

function M.start()
  x11.start()
  local augroup = vim.api.nvim_create_augroup('x11', {})
  vim.api.nvim_create_autocmd('VimLeave', { callback = M.stop, group = augroup })
  vim.api.nvim_create_autocmd({ 'WinResized', 'WinNew', 'TermOpen', 'BufDelete' }, {
    callback = function()
      vim.schedule(win_update_all)
    end,
    group = augroup,
  })
  vim.api.nvim_create_autocmd({ 'WinEnter', 'BufWinEnter', 'TabEnter' }, {
    callback = function()
      vim.schedule_wrap(win_update_all)('enter')
    end,
    group = augroup,
  })
  term_set_size(x11.screen_get_size())
  x11.term_focus()
  local function t()
    if not x11.display then
      return
    end
    step()
    vim.defer_fn(t, 1)
  end
  t()
end
function M.stop()
  vim.api.nvim_create_augroup('x11', { clear = true })
  x11.stop()
end
return M
