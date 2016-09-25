
local helpers = require('test.functional.helpers')(after_each)
local lfs = require('lfs')
local mpack = require('mpack')
local clear, eq, neq = helpers.clear, helpers.eq, helpers.neq

local read_mpack_file = function(fname)
  local fd = io.open(fname, 'rb')
  local data = fd:read('*a')
  fd:close()
  local unpack = mpack.Unpacker()
  return unpack(data)
end

-- ignore metadata in API function spec
local remove_function_metadata = function(fspec)
  fspec['can_fail'] = nil
  fspec['async'] = nil
  fspec['method'] = nil
  fspec['since'] = nil
  fspec['deprecated_since'] = nil
  fspec['receives_channel_id'] = nil
  for idx,_  in ipairs(fspec['parameters']) do
    fspec['parameters'][idx][2] = ''
  end
end

clear()
local api_level = helpers.call('api_info')['api_level']

describe('api compatibility', function()
  before_each(clear)

  it("version metadata is sane", function()
    local info = helpers.call('api_info')
    local current = info['api_level']['current']
    local compatibility = info['api_level']['compatibility']
    neq(current, nil)
    neq(compatibility, nil)
    assert(current >= compatibility)
  end)

  for ver = api_level['compatibility'], api_level['current'] do
    local path = 'test/functional/fixtures/api-info/' .. tostring(ver) .. '.mpack'
    it('are backwards compatible with api level '..ver, function()
      if lfs.attributes(path,"mode") ~= "file" then
        pending("No fixture found, skipping test")
        return
      end

      local old_api = read_mpack_file(path)
      local api = helpers.call('api_info')

      for _, fspec in ipairs(old_api['functions']) do
        remove_function_metadata(fspec)
        for _, fspec_new in ipairs(api['functions']) do
          if fspec['name'] == fspec_new['name'] then
            remove_function_metadata(fspec_new)
            eq(fspec, fspec_new)
          end
        end
      end
    end)
  end
end)
