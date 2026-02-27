-- local function counter(start)
--     local i = start
--     return function()
--         i = i + 1
--         return i
--     end
-- end
--
-- for i in counter(100000000) do
--     vim.print(i)
-- end

local function isdir(f)
  return (vim.uv.fs_stat(f) or {}).type == 'directory'
end

---@diagnostic disable
local function parents(startdir)
  local dir = startdir
  ---@return string?
  return function()
    if dir == vim.fs.dirname(dir) then
      return nil
    end
    dir = vim.fs.dirname(dir)
    return dir
  end
end

---@diagnostic disable
local function children(startdir)
  local alldirs = { startdir }
  return function()
    if #alldirs == 0 then
      return nil
    end
    local dirs = {}
    local dir = table.remove(alldirs, 1)
    for d in vim.fs.dir(dir) do
      local d = vim.fs.joinpath(dir, d)
      if isdir(d) then
        dirs[#dirs + 1] = d
      end
    end
    vim.list_extend(alldirs, dirs)
    return dir
  end
end

-- local file_custom = io.open('custom', 'a')
-- local file_builtin = io.open('builtin', 'a')
--
-- local startpath = vim.uv.cwd()
--
-- local custom_dirs = {}
-- for d in children(startpath) do
--   custom_dirs[#custom_dirs+1]= d
-- end
-- for _, d in vim.spairs(custom_dirs) do
--   file_custom:write(d .. '\n')
-- end
--
-- local builtin_dirs = {}
-- for d in vim.fs.dir(startpath, { depth = math.huge }) do
--   if isdir(d) then
--     builtin_dirs[#builtin_dirs+1]= vim.fs.abspath(d)
--   end
-- end
-- for _, d in vim.spairs(builtin_dirs) do
--   file_builtin:write(d .. '\n')
-- end
--
-- file_custom:close()
-- file_builtin:close()
