-- For 'exrc' and related functionality.

local files = vim.fs.find({ '.nvim.lua', '.nvimrc', '.exrc' }, {
  type = 'file',
  upward = true,
  limit = math.huge,
})
for _, file in ipairs(files) do
  local trusted = vim.secure.read(file) --[[@as string|nil]]
  if trusted then
    if vim.endswith(file, '.lua') then
      assert(loadstring(trusted, '@' .. file))()
    else
      vim.api.nvim_exec2(trusted, {})
    end
  end
  -- If the user unset 'exrc' in the current exrc then stop searching
  if not vim.o.exrc then
    break
  end
end
