-- Does the same as `nvim -c "helptags ++t doc" -c quit`
-- without needing to run a "nvim" binary, which is needed for cross-compiling.
local out = arg[1]
local dir = arg[2]

local dirfd = vim.uv.fs_opendir(dir, nil, 1)
local files = {}
while true do
  local file = dirfd:readdir()
  if file == nil then
    break
  end
  if file[1].type == 'file' and vim.endswith(file[1].name, '.txt') then
    table.insert(files, file[1].name)
  end
end

local tags = {}
for _, fn in ipairs(files) do
  local in_example = false
  for line in io.lines(dir .. '/' .. fn) do
    if in_example then
      local first = string.sub(line, 1, 1)
      if first ~= ' ' and first ~= '\t' and first ~= '' then
        in_example = false
      end
    end
    local chunks = vim.split(line, '*', { plain = true })
    local next_valid = false
    local n_chunks = #chunks
    for i, chunk in ipairs(chunks) do
      if next_valid and not in_example then
        if #chunk > 0 and string.find(chunk, '[ \t|]') == nil then
          local next = string.sub(chunks[i + 1], 1, 1)
          if next == ' ' or next == '\t' or (i == n_chunks - 1 and next == '') then
            table.insert(tags, { chunk, fn })
          end
        end
      end

      if i == n_chunks - 1 then
        break
      end
      next_valid = false
      local lastend = string.sub(chunk, -1) -- "" for empty string
      if lastend == ' ' or lastend == '\t' or (i == 1 and lastend == '') then
        next_valid = true
      end
    end

    if line:find('^>[a-z0-9]*$') or line:find(' >[a-z0-9]*$') then
      in_example = true
    end
  end
end

table.insert(tags, { 'help-tags', 'tags' })
table.sort(tags, function(a, b)
  return a[1] < b[1]
end)

local f = io.open(out, 'w')
local lasttagname, lastfn = nil
for _, tag in ipairs(tags) do
  local tagname, fn = unpack(tag)
  if tagname == lasttagname then
    error('duplicate tags in ' .. fn .. (lastfn ~= fn and (' and ' .. lastfn) or ''))
  end
  lasttagname, lastfn = tagname, fn

  if tagname == 'help-tags' then
    f:write(tagname .. '\t' .. fn .. '\t1\n')
  else
    local escaped = string.gsub(tagname, '[\\/]', '\\%0')
    f:write(tagname .. '\t' .. fn .. '\t/*' .. escaped .. '*\n')
  end
end
f:close()
