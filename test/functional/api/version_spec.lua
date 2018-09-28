local helpers = require('test.functional.helpers')(after_each)
local mpack = require('mpack')
local clear, funcs, eq = helpers.clear, helpers.funcs, helpers.eq
local call = helpers.call

local function read_mpack_file(fname)
  local fd = io.open(fname, 'rb')
  if fd == nil then
    return nil
  end

  local data = fd:read('*a')
  fd:close()
  local unpack = mpack.Unpacker()
  return unpack(data)
end

describe("api_info()['version']", function()
  before_each(clear)

  it("returns API level", function()
    local version = call('api_info')['version']
    local current = version['api_level']
    local compat  = version['api_compatible']
    eq("number", type(current))
    eq("number", type(compat))
    assert(current >= compat)
  end)

  it("returns Nvim version", function()
    local version = call('api_info')['version']
    local major   = version['major']
    local minor   = version['minor']
    local patch   = version['patch']
    eq("number", type(major))
    eq("number", type(minor))
    eq("number", type(patch))
    eq(1, funcs.has("nvim-"..major.."."..minor.."."..patch))
    eq(0, funcs.has("nvim-"..major.."."..minor.."."..(patch + 1)))
    eq(0, funcs.has("nvim-"..major.."."..(minor + 1).."."..patch))
    eq(0, funcs.has("nvim-"..(major + 1).."."..minor.."."..patch))
  end)
end)


describe("api functions", function()
  before_each(clear)

  local function func_table(metadata)
    local functions = {}
    for _,f in ipairs(metadata.functions) do
      functions[f.name] = f
    end
    return functions
  end

  -- Remove metadata that is not essential to backwards-compatibility.
  local function filter_function_metadata(f)
    f.deprecated_since = nil
    for idx, _ in ipairs(f.parameters) do
      f.parameters[idx][2] = ''  -- Remove parameter name.
    end

    if string.sub(f.name, 1, 4) ~= "nvim" then
      f.method = nil
    end
    return f
  end

  -- Level 0 represents methods from 0.1.5 and earlier, when 'since' was not
  -- yet defined, and metadata was not filtered of internal keys like 'async'.
  local function clean_level_0(metadata)
    for _, f in ipairs(metadata.functions) do
      f.can_fail = nil
      f.async = nil
      f.receives_channel_id = nil
      f.since = 0
    end
  end

  it("are compatible with old metadata or have new level", function()
    local api = helpers.call('api_info')
    local compat  = api.version.api_compatible
    local api_level = api.version.api_level
    local stable
    if api.version.api_prerelease then
      stable = api_level-1
    else
      stable = api_level
    end

    local funcs_new = func_table(api)
    local funcs_compat = {}
    for level = compat, stable do
      local path = ('test/functional/fixtures/api_level_'..
                   tostring(level)..'.mpack')
      local old_api = read_mpack_file(path)
      if old_api == nil then
        local errstr = "missing metadata fixture for stable level "..level..". "
        if level == api_level and not api.version.api_prerelease then
          errstr = (errstr.."If NVIM_API_CURRENT was bumped, "..
                    "don't forget to set NVIM_API_PRERELEASE to true.")
        end
        error(errstr)
      end

      if level == 0 then
        clean_level_0(old_api)
      end

      for _,f in ipairs(old_api.functions) do
        if funcs_new[f.name] == nil then
          if f.since >= compat then
            error('function '..f.name..' was removed but exists in level '..
                  f.since..' which nvim should be compatible with')
          end
        else
          eq(filter_function_metadata(f),
             filter_function_metadata(funcs_new[f.name]))
        end
      end

      funcs_compat[level] = func_table(old_api)
    end

    for _,f in ipairs(api.functions) do
      if f.since <= stable then
        local f_old = funcs_compat[f.since][f.name]
        if f_old == nil then
          if string.sub(f.name, 1, 4) == "nvim" then
            local errstr = ("function "..f.name.." has too low since value. "..
                            "For new functions set it to "..(stable+1)..".")
            if not api.version.api_prerelease then
              errstr = (errstr.." Also bump NVIM_API_CURRENT and set "..
                        "NVIM_API_PRERELEASE to true in CMakeLists.txt.")
            end
            error(errstr)
          else
            error("function name '"..f.name.."' doesn't begin with 'nvim_'")
          end
        end
      elseif f.since > api_level then
        error("function "..f.name.." has since value > api_level. "..
             "Please bump NVIM_API_CURRENT and set "..
             "NVIM_API_PRERELEASE to true in CMakeLists.txt.")
      end
    end
  end)

end)

describe("ui_options in metadata", function()
  it('are correct', function()
    -- TODO(bfredl) once a release freezes this into metadata,
    -- instead check that all old options are present
    local api = helpers.call('api_info')
    local options = api.ui_options
    eq({'rgb', 'ext_cmdline', 'ext_popupmenu',
        'ext_tabline', 'ext_wildmenu', 'ext_linegrid', 'ext_hlstate'}, options)
  end)
end)
