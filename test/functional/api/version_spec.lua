local helpers = require('test.functional.helpers')(after_each)
local mpack = require('mpack')
local clear, funcs, eq = helpers.clear, helpers.funcs, helpers.eq

local function read_mpack_file(fname)
  local fd = io.open(fname, 'rb')
  local data = fd:read('*a')
  fd:close()
  local unpack = mpack.Unpacker()
  return unpack(data)
end

-- Remove metadata that is not essential to backwards-compatibility.
local function remove_function_metadata(fspec)
  fspec['can_fail'] = nil
  fspec['async'] = nil
  fspec['method'] = nil
  fspec['since'] = nil
  fspec['deprecated_since'] = nil
  fspec['receives_channel_id'] = nil
  for idx, _ in ipairs(fspec['parameters']) do
    fspec['parameters'][idx][2] = ''  -- Remove parameter name.
  end
  return fspec
end

describe("api_info()['version']", function()
  before_each(clear)

  it("returns API level", function()
    local version = helpers.call('api_info')['version']
    local current = version['api_level']
    local compat  = version['api_compatible']
    eq("number", type(current))
    eq("number", type(compat))
    assert(current >= compat)
  end)

  it("returns Nvim version", function()
    local version = helpers.call('api_info')['version']
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

  it("api_compatible level is valid", function()
    local api     = helpers.call('api_info')
    local compat  = api['version']['api_compatible']
    local path    = 'test/functional/fixtures/api_level_'
                    ..tostring(compat)..'.mpack'

    -- Verify that the current API function signatures match those of the API
    -- level for which we claim compatibility.
    local old_api = read_mpack_file(path)
    for _, fn_old in ipairs(old_api['functions']) do
      for _, fn_new in ipairs(api['functions']) do
        if fn_old['name'] == fn_new['name'] then
          eq(remove_function_metadata(fn_old),
             remove_function_metadata(fn_new))
        end
      end
    end
  end)
end)
