local mpack = vim.mpack

assert(#arg == 7)
local funcs_metadata_inputf = arg[1] -- exported functions metadata
local ui_metadata_inputf = arg[2] -- ui events metadata
local ui_options_inputf = arg[3] -- for ui options
local git_version_inputf = arg[4] -- git version header
local nvim_version_inputf = arg[5] -- nvim version
local dump_bin_array_inputf = arg[6]
local api_metadata_outputf = arg[7]

local version = loadfile(nvim_version_inputf)()
local git_version = io.open(git_version_inputf):read '*a'
local version_build = git_version:match('#define NVIM_VERSION_BUILD "([^"]+)"') or vim.NIL

local text = io.open(ui_options_inputf):read '*a'
local ui_options_text = text:match('ui_ext_names%[][^{]+{([^}]+)}')
local ui_options = { 'rgb' }
for x in ui_options_text:gmatch('"([a-z][a-z_]+)"') do
  table.insert(ui_options, x)
end

local pieces = {} --- @type string[]

-- Naively using mpack.encode({foo=x, bar=y}) will make the build
-- "non-reproducible". Emit maps directly as FIXDICT(2) "foo" x "bar" y instead
local function fixdict(num)
  if num > 15 then
    error 'implement more dict codes'
  end
  pieces[#pieces + 1] = string.char(128 + num)
end

local function put(item, item2)
  table.insert(pieces, mpack.encode(item))
  if item2 ~= nil then
    table.insert(pieces, mpack.encode(item2))
  end
end

fixdict(6)

put('version')
fixdict(1 + #version)
for _, item in ipairs(version) do
  -- NB: all items are mandatory. But any error will be less confusing
  -- with placeholder vim.NIL (than invalid mpack data)
  local val = item[2] == nil and vim.NIL or item[2]
  put(item[1], val)
end
put('build', version_build)

put('functions')
table.insert(pieces, io.open(funcs_metadata_inputf, 'rb'):read('*all'))
put('ui_events')
table.insert(pieces, io.open(ui_metadata_inputf, 'rb'):read('*all'))
put('ui_options', ui_options)

put('error_types')
fixdict(2)
put('Exception', { id = 0 })
put('Validation', { id = 1 })

put('types')
local types =
  { { 'Buffer', 'nvim_buf_' }, { 'Window', 'nvim_win_' }, { 'Tabpage', 'nvim_tabpage_' } }
fixdict(#types)
for i, item in ipairs(types) do
  put(item[1])
  fixdict(2)
  put('id', i - 1)
  put('prefix', item[2])
end

local packed = table.concat(pieces)
--- @type fun(api_metadata: file*, name: string, packed: string)
local dump_bin_array = loadfile(dump_bin_array_inputf)()

-- serialize the API metadata using msgpack and embed into the resulting
-- binary for easy querying by clients
local api_metadata_output = assert(io.open(api_metadata_outputf, 'wb'))
dump_bin_array(api_metadata_output, 'packed_api_metadata', packed)
api_metadata_output:close()
