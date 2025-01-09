-- Test 'nvim -l foo.lua ..' does not load runtime plugin
local function main()
  print(vim.g.news_check)
end

main()
