-- luacheck: globals unpack vim.api
local nvim = vim.api
local command = nvim.nvim_command

local functions = {}

local function register_fn(ns, keys, shortmode, fn)
  if not functions[ns] then
    functions[ns] = {}
  end

  for sshortmode in shortmode:gmatch"." do
    if not functions[ns][sshortmode] then
      functions[ns][sshortmode] = {}
    else
      assert(functions[ns][sshortmode][keys] == nil,
             "Keys already mapped from namespace "..tostring(ns))
    end
    functions[ns][sshortmode][keys] = fn
  end
end

local function map_to_ns(keys, ns, opts, mapcmd, is_cmd, shortmode)
  local keys_rhs = keys:gsub("<", "<lt>")
  local sshortmode = shortmode:sub(1,1)
  local rhs = "lua require('helpers.plugin.map').functions["..
                  tostring(ns).."]['"..sshortmode.."']['"..keys_rhs.."']()"
  rhs = (is_cmd and " <Cmd>"..rhs) or rhs
  opts = (opts and opts.." ") or ""
  mapcmd = (mapcmd and mapcmd.." ") or ""

  command(mapcmd..opts..keys..rhs.."<CR>")
end

local shortmode_cmds = {
  [true] = {
      n = "nmap",
      vs = "vmap",
      s = "smap",
      v = "xmap",
      o = "omap",
      ic = "map!",
      i = "imap",
      l = "lmap",
      c = "cmap",
      t = "tmap",
    },
    [false] = {
      n = "nnoremap",
      vs = "vnoremap",
      s = "snoremap",
      v = "xnoremap",
      o = "onoremap",
      ic = "noremap!",
      i = "inoremap",
      l = "lnoremap",
      c = "cnoremap",
      t = "tnoremap",
    }
  }

local function try_get_shortmode(mode)
  local shortmode

  mode = mode and mode:lower()

  if mode == "normal" then
    shortmode = "n"
  elseif mode:find("vis") then
    shortmode = "v"
  elseif mode:find("ins") then
    shortmode = "i"
  elseif mode:find("com") then
    shortmode = "c"
  elseif mode:find("sel") then
    shortmode = "s"
  elseif mode:find("op") then
    shortmode = "o"
  elseif mode:find("lang") then
    shortmode = "l"
  elseif mode:find("term") then
    shortmode = "t"
  else
    shortmode = mode
  end

  return shortmode
end

local function get_mapcmd(mode, recursive)
  local mapcmd, shortmode

  if mode == nil and recursive then
    mapcmd, shortmode = "map", "nvos"
  elseif mode == nil and not recursive then
    mapcmd, shortmode = "noremap", "nvos"
  else
    shortmode = try_get_shortmode(mode)
    mapcmd = shortmode_cmds[recursive][shortmode] 
  end
  assert(mapcmd ~= nil,
         "Can't find mapping command for mode '"..tostring(mode).."'")

  return mapcmd, shortmode
end

local allowed_map_opts = { buffer = true, nowait = true, silent = true,
                           unique = true }
local function destructure_map_args(table)
  for k, _ in pairs(table) do
    assert(allowed_map_opts[k] or k == "fn" or k == "keys" or k == "mode"
           or k == "is_cmd" or k == "recursive",
           "Key "..tostring(k).." not allowed in function map!")
  end

  assert(type(table.fn) == "function", "'fn' mandatory funtion argument to map")
  assert(type(table.keys) == "string", "'keys' mandatory string argument to map")
  if table.is_cmd ~= nil then
    assert(type(table.is_cmd) == "boolean",
           "'is_cmd' optional boolean argument to map")
  end
  if table.mode ~= nil then
    assert(type(table.mode) == "string",
           "'mode' optional string argument to map")
  end
  if table.recursive ~= nil then
    assert(type(table.recursive) == "boolean",
           "'recursive' optional boolean argument to map")
  end

  local opts = ""
  for opt, _ in pairs(allowed_map_opts) do
    if table[opt] then
      opts = opts.."<"..opt..">"
    end
  end

  local is_cmd
  -- Assume if is_cmd isn't explicitely false, then a cmd mapping was requested
  if table.is_cmd == nil or table.is_cmd == true then
    is_cmd = true
  else
    is_cmd = false
  end

  local recursive
  if table.recursive == nil or table.recursive == false then
    recursive = false
  else
    recursive = true
  end

  local mapcmd, shortmode = get_mapcmd(table.mode, recursive)

  return table.keys, table.fn, opts, mapcmd, is_cmd, shortmode
end

local function map(self, arg1, arg2)
  local firststring = (type(arg1) == "string")
  local secondfun = (type(arg2) == "function")
  local two_args = firststring and secondfun
  local one_arg = (type(arg1) == "table")
  assert(two_args or one_arg, "Must pass (string, function) or (table) as args")

  -- we need that table[ns] is the same as luaeval "table["..tostring(ns).."]"
  -- Not sure how to ascertain that, so let's just throw out an error if the
  -- returned type of nvim_create_namespace changes
  assert(type(self.ns) == "number", "Namespace must be a number")

  local ns = self.ns
  local name = self.name
  local keys, fn, opts, mapcmd, is_cmd

  if one_arg then
    keys, fn, opts, mapcmd, is_cmd, shortmode = destructure_map_args(arg1)
  else
    keys, fn, opts, mapcmd, is_cmd, shortmode = arg1, arg2, nil, "map", true, "nvos"
  end

  register_fn(ns, keys, shortmode, fn)

  map_to_ns(keys, ns, opts, mapcmd, is_cmd, shortmode)
end

local function unmap(self, keys, mode)
  assert(type(keys) == "string", "'keys' mandatory string argument to unmap")

  if mode ~= nil then 
    assert(type(mode) == "string", "'mode' string argument to unmap")
  end
  
  local mapcmd, shortmode = get_mapcmd(mode, true)
  local unmapcmd = mapcmd:gsub("map", "unmap").." "
  local mapped_fns = {}

  for sshortmode in shortmode:gmatch"." do
    local f = functions[self.ns][sshortmode][keys]
    functions[self.ns][sshortmode][keys] = nil
    if f then
      table.insert(mapped_fns, { sshortmode, f })
    end
  end

  if #mapped_fns == 0 then
    return nil
  else
    command(unmapcmd..keys)
    return mapped_fns
  end
end

return {
  unmap = unmap,
  map = map,
  functions = functions,
}
