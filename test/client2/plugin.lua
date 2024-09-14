local Host = {}
Host.__index = Host

local Plugin = {}
Plugin.__index = Plugin

local metas = {
  ['function'] = {
    func = {type = "function", required = true},
    name = {type = "string", required = true},
    async = {type = "boolean"},
    eval = {type = "string"},
  },
  autocmd = {
    func = {type = "function", required = true},
    name = {type = "string", required = true},
    pattern = {type = "string"},
    async = {type = "boolean"},
    group = {type = "string"},
    nested = {type = "boolean"},
    eval = {type = "string"},
  },
  command = {
    func = {type = "function", required = true},
    name = {type = "string", required = true},
    async = {type = "boolean"},
    nargs = {type = "string"},
    range = {type = "string"},
    count = {type = "string"},
    addr = {type = "string"},
    bang = {type = "boolean"},
    register = {type = "boolean"},
    eval = {type = "string"},
    bar = {type = "boolean"},
    complete = {type = "string"},
  }
}

local not_spec_opt = { func = true, name = true, async = true }

local function define(specs, handlers, stype, opts)
  local meta = metas[stype]
  local sopts = { x = 0 } -- add dummy value to force msgpack dict
  for k, v in pairs(opts) do
    local m = meta[k]
    if m == nil then
      error('invalid option: ' .. k)
    end
    if type(v) ~= m.type then
      error('invalid option value: ' .. k)
    end
    if not not_spec_opt[k] then
      sopts[k] = v
    end
  end
  for k, v in pairs(meta) do
    if v.required and opts[k] == nil then
      error('missing required option: ' .. k)
    end
  end
  local method = ':' .. stype .. ':' ..  opts.name
  if stype == 'autocmd' then
    method = method .. ':' .. (opts.pattern or '*')
  end
  handlers[method] = opts.func
  specs[#specs+1] = {
    type = stype,
    opts = sopts,
    name = opts.name,
    sync = not opts.async,
  }
end


local function new_plugin(dir, nvim)
  local plugin = setmetatable({
    loaded = {},
    dir = dir,
  }, Plugin)
  plugin.env = setmetatable({
    nvim = nvim,
    require = function(name) return plugin:require(name) end,
  }, {__index = _G})
  return plugin
end

function Plugin:load_script(path)
  if string.find(path, '_spec%.lua$') then
    return nil
  end
  local specs = {}
  local handlers = {}
  self.env.plugin = {
    func = function(opts) define(specs, handlers, 'function', opts) end,
    command = function(opts) define(specs, handlers, 'command', opts) end,
    autocmd = function(opts) define(specs, handlers, 'autocmd', opts) end,
  }
  assert(pcall(setfenv(assert(loadfile(path)), self.env)))
  if not #specs then
    return nil
  end
  return specs, handlers
end

function Plugin:require(name)
  local m = self.loaded[name]
  if m ~= nil then
    return m
  end
  local path = self.dir .. string.gsub(name, '%.', '/') .. '.lua'
  local f = loadfile(path)
  if f == nil then
    return require(name)
  end
  setfenv(f, self.env)
  m = f()
  self.loaded[name] = m
  return m
end

local function new_host(nvim)
  local host = setmetatable({
    nvim = nvim,
    plugins = {}
  }, Host)
  nvim.handlers = setmetatable({
    specs = function(scriptfile) return host:get_specs(scriptfile) end,
  }, {__index = function(_, method) return host:get_handler(method) end})
  return host
end

--function Host.run()
--  Host.new(Nvim.new_stdio())
--  uv.run()
--end

function Host:get_plugin(path)
  local dir = string.match(path, '.*/')
  local plugin = self.plugins[dir]
  if plugin == nil then
    plugin = new_plugin(dir, self.nvim)
    self.plugins[dir] = plugin
  end
  return plugin
end

function Host:get_handler(method)
  local i = string.find(method, '.lua:', 1, true)
  if not i then
    return nil
  end
  local path = method:sub(1, i + 3)
  local _, handlers  = self:get_plugin(path):load_script(path)
  if handlers == nil then
    return nil
  end
  for m, h in pairs(handlers) do
    self.nvim.handlers[path .. m] = h
  end
  return handlers[method:sub(i + 4)]
end

function Host:get_specs(path)
  local specs, _ = self:get_plugin(path):load_script(path)
  return specs
end

return {
  new_host = new_host,
  new_plugin = new_plugin,
  Host = Host,
  Plugin = Plugin,
}
