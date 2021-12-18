
local nvimsrcdir = arg[1]
local shared_file = arg[2]
local funcs_file = arg[3]
local defs_file = arg[4]

_G.vim = loadfile(shared_file)()

if nvimsrcdir == '--help' then
  print([[
Usage:
  lua gen_keyset.lua TODOFIXUPDATETHIS

Will generate build/src/nvim/auto/keyset.generated.h with definition of functions
static const array.
]])
  os.exit(0)
end


package.path = nvimsrcdir .. '/?.lua;' .. package.path
local hashy = require'generators.hashy'

local funcspipe = io.open(funcs_file, 'wb')
local defspipe = io.open(defs_file, 'wb')

local keysets = require'api.keysets'

for name, keys in pairs(keysets) do
  local neworder, hashfun = hashy.hashy_hash(name, keys, function (idx)
    return name.."_table["..idx.."].str"
  end)

  defspipe:write("typedef struct {\n")
  for _, key in ipairs(neworder) do
    defspipe:write("  Object "..key..";\n")
  end
  defspipe:write("} KeyDict_"..name..";\n\n")

  defspipe:write("extern KeySetLink "..name.."_table[];\n")

  funcspipe:write("KeySetLink "..name.."_table[] = {\n")
  for _, key in ipairs(neworder) do
    funcspipe:write('  {"'..key..'", offsetof(KeyDict_'..name..", "..key..")},\n")
  end
    funcspipe:write('  {NULL, 0},\n')
  funcspipe:write("};\n\n")

  funcspipe:write(hashfun)

  funcspipe:write([[
Object *KeyDict_]]..name..[[_get_field(void *retval, const char *str, size_t len)
{
  int hash = ]]..name..[[_hash(str, len);
  if (hash == -1) {
    return NULL;
  }

  return (Object *)((char *)retval + ]]..name..[[_table[hash].ptr_off);
}

]])
  defspipe:write("#define api_free_keydict_"..name.."(x) api_free_keydict(x, "..name.."_table)\n")
end

funcspipe:close()
defspipe:close()
