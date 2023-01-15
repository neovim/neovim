-- Test "nvim -es -u foo.vim" with a Vimscript error.

local function main()
  error('my pearls!!')
end

main()
