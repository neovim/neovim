local api = vim.api
local errcodes_c = api.nvim_call_function('systemlist', {[[git grep -E 'E[0-9]{3,4}' -- '*.c']]})
local errcodes_help = api.nvim_call_function('systemlist', {[[git grep -E '\*E[0-9]{3,4}\*' -- 'runtime/doc/*.txt']]})
local errcodes_help_map = {}
local errcodes = {}
local nrerrcodes = 0
local dups = 0
local not_in_help = 0
for i,v in ipairs(errcodes_help) do
  local key = string.match(v, 'E%d%d%d%d?')
  if not key then
    error('failed to match: '..v)
  end
  errcodes_help_map[key] = true
  print('xxx '..key)
end
for i,v in ipairs(errcodes_c) do
  local errcode = string.match(v, 'E%d%d%d%d?')
  if errcode then
    local comment = string.find(v, '//')
    local in_comment = comment and (comment < string.find(v, 'E%d%d%d%d?'))
    if not in_comment then
      if not errcodes_help_map[errcode] then
        errcodes_help_map[errcode] = false
      end
      if errcodes[errcode] ~= nil then
        table.insert(errcodes[errcode], v)
        dups = dups + 1
      else
        errcodes[errcode] = { v }
        nrerrcodes = nrerrcodes + 1
      end
    end
  end
end
for k,v in pairs(errcodes_help_map) do
  if not v then
    not_in_help = not_in_help + 1
    print('not in help: '..k)
  else
    print('in help: '..k)
  end
end
print(string.format("errcodes=%d, dups=%d missing-help=%d",
      nrerrcodes, dups, not_in_help))
