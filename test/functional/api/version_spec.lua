local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear, fn, eq = n.clear, n.fn, t.eq
local api = n.api

local function read_mpack_file(fname)
  local fd = io.open(fname, 'rb')
  if fd == nil then
    return nil
  end

  local data = fd:read('*a')
  fd:close()
  local unpack = vim.mpack.Unpacker()
  return unpack(data)
end

describe("api_info()['version']", function()
  before_each(clear)

  it('returns API level', function()
    local version = fn.api_info()['version']
    local current = version['api_level']
    local compat = version['api_compatible']
    eq('number', type(current))
    eq('number', type(compat))
    assert(current >= compat)
  end)

  it('returns Nvim version', function()
    local version = fn.api_info()['version']
    local major = version['major']
    local minor = version['minor']
    local patch = version['patch']
    local prerelease = version['prerelease']
    local build = version['build']
    eq('number', type(major))
    eq('number', type(minor))
    eq('number', type(patch))
    eq('boolean', type(prerelease))
    eq(1, fn.has('nvim-' .. major .. '.' .. minor .. '.' .. patch))
    eq(0, fn.has('nvim-' .. major .. '.' .. minor .. '.' .. (patch + 1)))
    eq(0, fn.has('nvim-' .. major .. '.' .. (minor + 1) .. '.' .. patch))
    eq(0, fn.has('nvim-' .. (major + 1) .. '.' .. minor .. '.' .. patch))
    assert(build == nil or type(build) == 'string')
  end)
end)

describe('api metadata', function()
  before_each(clear)

  local function name_table(entries)
    local by_name = {}
    for _, e in ipairs(entries) do
      by_name[e.name] = e
    end
    return by_name
  end

  -- Remove metadata that is not essential to backwards-compatibility.
  local function filter_function_metadata(f)
    f.deprecated_since = nil
    for idx, _ in ipairs(f.parameters) do
      f.parameters[idx][2] = '' -- Remove parameter name.
    end

    if string.sub(f.name, 1, 4) ~= 'nvim' then
      f.method = nil
    end
    return f
  end

  local function check_ui_event_compatible(old_e, new_e)
    -- check types of existing params are the same
    -- adding parameters is ok, but removing params is not (gives nil error)
    eq(old_e.since, new_e.since, old_e.name)
    for i, p in ipairs(old_e.parameters) do
      eq(new_e.parameters[i][1], p[1], old_e.name)
    end
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

  local api_info, compat, stable, api_level
  local old_api = {}
  setup(function()
    clear() -- Ensure a session before requesting api_info.
    api_info = api.nvim_get_api_info()[2]
    compat = api_info.version.api_compatible
    api_level = api_info.version.api_level
    if api_info.version.api_prerelease then
      stable = api_level - 1
    else
      stable = api_level
    end

    for level = compat, stable do
      local path = ('test/functional/fixtures/api_level_' .. tostring(level) .. '.mpack')
      old_api[level] = read_mpack_file(path)
      if old_api[level] == nil then
        local errstr = 'missing metadata fixture for stable level ' .. level .. '. '
        if level == api_level and not api_info.version.api_prerelease then
          errstr = (
            errstr
            .. 'If NVIM_API_CURRENT was bumped, '
            .. "don't forget to set NVIM_API_PRERELEASE to true."
          )
        end
        error(errstr)
      end

      if level == 0 then
        clean_level_0(old_api[level])
      end
    end
  end)

  it('functions are compatible with old metadata or have new level', function()
    local funcs_new = name_table(api_info.functions)
    local funcs_compat = {}
    for level = compat, stable do
      for _, f in ipairs(old_api[level].functions) do
        if funcs_new[f.name] == nil then
          if f.since >= compat then
            error(
              'function '
                .. f.name
                .. ' was removed but exists in level '
                .. f.since
                .. ' which nvim should be compatible with'
            )
          end
        else
          eq(filter_function_metadata(f), filter_function_metadata(funcs_new[f.name]))
        end
      end
      funcs_compat[level] = name_table(old_api[level].functions)
    end

    for _, f in ipairs(api_info.functions) do
      if f.since <= stable then
        local f_old = funcs_compat[f.since][f.name]
        if f_old == nil then
          if string.sub(f.name, 1, 4) == 'nvim' then
            local errstr = (
              'function '
              .. f.name
              .. ' has too low since value. '
              .. 'For new functions set it to '
              .. (stable + 1)
              .. '.'
            )
            if not api_info.version.api_prerelease then
              errstr = (
                errstr
                .. ' Also bump NVIM_API_CURRENT and set '
                .. 'NVIM_API_PRERELEASE to true in CMakeLists.txt.'
              )
            end
            error(errstr)
          else
            error("function name '" .. f.name .. "' doesn't begin with 'nvim_'")
          end
        end
      elseif f.since > api_level then
        if api_info.version.api_prerelease then
          error('New function ' .. f.name .. ' should use since value ' .. api_level)
        else
          error(
            'function '
              .. f.name
              .. ' has since value > api_level. '
              .. 'Bump NVIM_API_CURRENT and set '
              .. 'NVIM_API_PRERELEASE to true in CMakeLists.txt.'
          )
        end
      end
    end
  end)

  it('UI events are compatible with old metadata or have new level', function()
    local ui_events_new = name_table(api_info.ui_events)
    local ui_events_compat = {}

    -- UI events were formalized in level 3
    for level = 3, stable do
      for _, e in ipairs(old_api[level].ui_events) do
        local new_e = ui_events_new[e.name]
        if new_e ~= nil then
          check_ui_event_compatible(e, new_e)
        end
      end
      ui_events_compat[level] = name_table(old_api[level].ui_events)
    end

    for _, e in ipairs(api_info.ui_events) do
      if e.since <= stable then
        local e_old = ui_events_compat[e.since][e.name]
        if e_old == nil then
          local errstr = (
            'UI event '
            .. e.name
            .. ' has too low since value. '
            .. 'For new events set it to '
            .. (stable + 1)
            .. '.'
          )
          if not api_info.version.api_prerelease then
            errstr = (
              errstr
              .. ' Also bump NVIM_API_CURRENT and set '
              .. 'NVIM_API_PRERELEASE to true in CMakeLists.txt.'
            )
          end
          error(errstr)
        end
      elseif e.since > api_level then
        if api_info.version.api_prerelease then
          error('New UI event ' .. e.name .. ' should use since value ' .. api_level)
        else
          error(
            'UI event '
              .. e.name
              .. ' has since value > api_level. '
              .. 'Bump NVIM_API_CURRENT and set '
              .. 'NVIM_API_PRERELEASE to true in CMakeLists.txt.'
          )
        end
      end
    end
  end)

  it('ui_options are preserved from older levels', function()
    local available_options = {}
    for _, option in ipairs(api_info.ui_options) do
      available_options[option] = true
    end
    -- UI options were versioned from level 4
    for level = 4, stable do
      for _, option in ipairs(old_api[level].ui_options) do
        if not available_options[option] then
          error('UI option ' .. option .. ' from stable metadata is missing')
        end
      end
    end
  end)
end)
