-- Test "nvim -l foo.lua …" with a Lua error.

local function main()
  error('my pearls!!')
end

main()
