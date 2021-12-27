local uv = vim.loop

local Path = {}
Path.__index = Path

function Path:__tostring()
  return self.path
end

function Path:exists()
  return uv.fs_realpath(self.path) and true
end

function Path:expanduser()
  if self.path == '/' or self.path:match '^~/' then
    return os.getenv('HOME') .. self.path:sub(2)
  else
    return self.path
  end
end

function Path:home()
  return os.getenv('HOME')
end

function Path:parts()
  if self.is_windows then
    return vim.split(self.path, '/')
  else
    local parts = vim.split(self.path, '/')
    if self.path:sub(1, 1) == '/' then
      parts[1] = '/'
    end
    return parts
  end
end

function Path:is_dir()
  local stat = uv.fs_realpath(self.path)
  return stat and stat == 'directory'
end

function Path:is_file()
  local stat = uv.fs_realpath(self.path)
  return stat and stat == 'file'
end

function Path:is_absolute()
  if self.is_windows then
    return (self.path:match '^%a:' or self.path:match '^\\\\') or false
  else
    return self.path:match '^/' or false
  end
end

function Path:is_relative_to(root)
  local path_parts = self:parts()
  local root_parts = Path.new(root):parts()

  local root_parts_len = #root_parts
  local path_parts_len = #path_parts

  if root_parts_len > path_parts_len then
    return false
  end

  for i = 1,math.min(root_parts_len, path_parts_len) do
    if root_parts[i] ~= path_parts[i] then
      return false
      end
  end
  return true
end

function Path:is_fs_root()
  if self.is_windows then
    return self.path:match '^%a:$'
  else
    return self.path == '/'
  end
end

function Path:as_uri()
  if self.is_windows then
    return 'file:///' .. self.path
  else
    return 'file://' .. self.path
  end
end

function Path:as_posix()
  return self.path
end

function Path:as_windows()
  return self.path:gsub('/', '\\')
end

function Path:parent()
  local strip_dir_pat = '/([^/]+)$'
  local strip_sep_pat = '/$'
  if not self.path or #self.path == 0 then
    return
  end
  local result = self.path:gsub(strip_sep_pat, ''):gsub(strip_dir_pat, '')
  if #result == 0 then
    if self.is_windows then
      return Path.new(self.path:sub(1, 2))
    else
      return Path.new('/')
    end
  end
  return Path.new(result)
end

function Path.new(path)
  local path_obj = {
    is_windows = uv.os_uname().version:match('Windows')
  }
  local self = setmetatable(path_obj, Path)

  self.path = path

  if path_obj.is_windows then
    if self.is_absolute() then
      path = path:sub(1, 1):upper() .. path:sub(2)
    end
    self.path = path:gsub('\\', '/')
  end

  return path_obj
end

setmetatable(Path, {
  __call = function(_, path)
    return Path.new(path)
  end
})

local function join(...)
  local to_join = vim.map(tostring, vim.tbl_flatten(...))
  return Path.new(table.concat(to_join, '/'))
end

return {
  Path=Path,
  join=join
}
