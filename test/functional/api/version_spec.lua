local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, setup = t.describe, t.it, t.before_each, t.setup
local clear, fn, eq = n.clear, n.fn, t.eq
local api = n.api
local matches = t.matches
local pcall_err = t.pcall_err

local function read_mpack_file(fname)
  if vim.fn.filereadable(fname) == 0 then
    return nil
  end
  return vim.mpack.Unpacker()(vim.fn.readblob(fname))
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
    assert(build == vim.NIL or type(build) == 'string')
  end)
end)

describe('api metadata', function()
  local function name_table(entries)
    local by_name = {}
    for _, e in ipairs(entries) do
      by_name[e.name] = e
    end
    return by_name
  end

  --- Remove or patch metadata that is not essential to backwards-compatibility.
  --- @param f gen_api_dispatch.Function.Exported
  local function normalize_func_metadata(f)
    -- Dictionary was renamed to Dict. That doesn't break back-compat because it names the
    -- same RPC map type.
    f.return_type = f.return_type:gsub('Dictionary', 'Dict')
    f.return_type = f.return_type:gsub('^ArrayOf%(.*', 'Array')

    f.deprecated_since = nil
    for idx, _ in ipairs(f.parameters) do
      -- Dictionary was renamed to Dict. That doesn't break back-compat because it names the
      -- same RPC map type.
      f.parameters[idx][1] = f.parameters[idx][1]:gsub('Dictionary', 'Dict')
      f.parameters[idx][1] = f.parameters[idx][1]:gsub('ArrayOf%(.*', 'Array')

      f.parameters[idx][2] = '' -- Remove parameter name.
      -- Strip the `optional` flag: `assert_func_backcompat` checks it asymmetrically (relaxing a
      -- param to optional is allowed, the reverse is breaking).
      f.parameters[idx][3] = nil
    end

    if string.sub(f.name, 1, 4) ~= 'nvim' then
      f.method = nil
    end
    return f
  end

  --- Checks that the current signature of a function is backwards-compatible with the previous
  --- version, per ":help api-contract".
  --- @param old_fn gen_api_dispatch.Function.Exported
  --- @param new_fn gen_api_dispatch.Function.Exported
  local function assert_func_backcompat(old_fn, new_fn)
    -- Optional param must stay optional.
    for idx, old_param in ipairs(old_fn.parameters) do
      local new_param = new_fn.parameters[idx]
      if old_param[3] and new_param and not new_param[3] then
        error(('"%s": parameter %d was optional, now required'):format(old_fn.name, idx))
      end
    end
    old_fn = normalize_func_metadata(old_fn)
    new_fn = normalize_func_metadata(new_fn)
    if old_fn.return_type == 'void' then
      old_fn.return_type = new_fn.return_type
    end
    eq(old_fn, new_fn)
  end

  local function check_ui_event_compatible(old_e, new_e)
    -- check types of existing params are the same
    -- adding parameters is ok, but removing params is not (gives nil error)
    eq(old_e.since, new_e.since, old_e.name)
    for i, p in ipairs(old_e.parameters) do
      eq(new_e.parameters[i][1], p[1], old_e.name)
    end
  end

  --- Level 0 represents methods from 0.1.5 and earlier, when 'since' was not
  --- yet defined, and metadata was not filtered of internal keys like 'async'.
  ---
  --- @param metadata { functions: gen_api_dispatch.Function[] }
  local function clean_level_0(metadata)
    for _, f in ipairs(metadata.functions) do
      f.can_fail = nil
      f.async = nil -- XXX: renamed to "fast".
      f.receives_channel_id = nil
      f.since = 0
    end
  end

  local api_info --[[@type table]]
  local compat --[[@type integer]]
  local stable --[[@type integer]]
  local api_level --[[@type integer]]
  local old_api = {} ---@type { functions: gen_api_dispatch.Function[] }[]
  setup(function()
    clear() -- Ensure a session before requesting api_info.
    --[[@type {  functions: gen_api_dispatch.Function[], version: {api_compatible: integer, api_level: integer, api_prerelease: boolean} }]]
    api_info = api.nvim_get_api_info()[2]
    compat = api_info.version.api_compatible
    api_level = api_info.version.api_level
    stable = api_info.version.api_prerelease and api_level - 1 or api_level

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
    -- No Nvim session will be used in the following tests.
    n.check_close()
  end)

  it('preserves ArrayOf type metadata', function()
    local funcs = name_table(api_info.functions)
    eq('ArrayOf(String)', funcs.nvim_list_runtime_paths.return_type)
    eq('ArrayOf(Integer, 2)', funcs.nvim_buf_get_mark.return_type)
    eq('ArrayOf(String)', funcs.nvim_buf_set_lines.parameters[5][1])
  end)

  it('function parameters', function()
    local funcs = name_table(api_info.functions)
    eq({ 'String', 'src', false }, funcs.nvim_exec2.parameters[1])
    eq({ 'Dict', 'opts', true }, funcs.nvim_exec2.parameters[2])
    eq({ 'Dict', 'opts', true }, funcs.nvim_get_context.parameters[1])
    eq({ 'String', 'name', false }, funcs.nvim_get_var.parameters[1])
  end)

  it('functions are compatible with old metadata or have new level', function()
    local funcs_new = name_table(api_info.functions)
    local funcs_compat = {}
    for level = compat, stable do
      for _, f in ipairs(old_api[level].functions) do
        if funcs_new[f.name] == nil then
          if f.since >= compat then
            local msg =
              'function "%s" was removed but exists in level %s which Nvim claims to be compatible with'
            error((msg):format(f.name, f.since))
          end
        else
          assert_func_backcompat(f --[[@as any]], funcs_new[f.name])
        end
      end
      funcs_compat[level] = name_table(old_api[level].functions)
    end

    for _, f in ipairs(api_info.functions) do
      if f.since <= stable then
        local f_old = funcs_compat[f.since][f.name]
        if f_old == nil then
          if string.sub(f.name, 1, 4) == 'nvim' then
            local errstr = ('function "%s" has too low `since` value. For new functions set it to "%s".'):format(
              f.name,
              (stable + 1)
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

  it('param may not change from optional to required', function()
    local function example_fn(opts_optional)
      return {
        name = 'nvim_example',
        method = false,
        since = 1,
        return_type = 'void',
        parameters = { { 'String', 'src', false }, { 'Dict', 'opts', opts_optional } },
      }
    end
    -- "Required -> Optional" is allowed.
    assert_func_backcompat(example_fn(false), example_fn(true))
    -- "Optional -> Required" is breaking.
    matches(
      '"nvim_example": parameter 2 was optional, now required',
      pcall_err(assert_func_backcompat, example_fn(true), example_fn(false))
    )
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

describe('api: optional parameters', function()
  before_each(clear)

  it('may be omitted', function()
    eq('table', type(api.nvim_get_context({})))
    eq('table', type(api.nvim_get_context()))

    api.nvim_exec2('let g:x = 41')
    eq(41, api.nvim_get_var('x'))
    eq({ output = 'hi' }, api.nvim_exec2('echo "hi"', { output = true }))

    -- Lua bridge: vim.api
    n.exec_lua([[vim.api.nvim_exec2('let g:y = 7')]])
    eq(7, api.nvim_get_var('y'))
    eq('table', n.exec_lua('return type(vim.api.nvim_get_context())'))
  end)

  it('omitted is equivalent to empty dict', function()
    eq(n.parse_context(api.nvim_get_context({})), n.parse_context(api.nvim_get_context())) -- RPC path
    eq(
      n.parse_context(n.exec_lua('return vim.api.nvim_get_context({})')),
      n.parse_context(n.exec_lua('return vim.api.nvim_get_context()'))
    ) -- Lua-binding path
  end)

  it('validation', function()
    matches(
      'Wrong number of arguments: expecting 1 to 3 but got 4',
      pcall_err(api.nvim_exec2, 'echo 1', {}, {}, 'surplus')
    )
    matches(
      'Wrong number of arguments: expecting at most 1 but got 2',
      pcall_err(api.nvim_get_context, {}, 'surplus')
    )
    matches('Wrong number of arguments: expecting 1 to 3 but got 0', pcall_err(api.nvim_exec2))

    -- Lua bridge: vim.api
    matches(
      'Expected 1 to 3 arguments',
      pcall_err(n.exec_lua, [[vim.api.nvim_exec2('echo 1', {}, {}, 'surplus')]])
    )
    matches('Expected 1 to 3 arguments', pcall_err(n.exec_lua, [[vim.api.nvim_exec2()]]))
    matches(
      'Expected at most 1 argument',
      pcall_err(n.exec_lua, [[vim.api.nvim_get_context({}, 'surplus')]])
    )
  end)
end)
