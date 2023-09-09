-- Test "nvim -l foo.lua …"

local function printbufs()
  local bufs = ''
  for _, v in ipairs(vim.api.nvim_list_bufs()) do
    local b = vim.fn.bufname(v)
    if b:len() > 0 then
      bufs = ('%s %s'):format(bufs, b)
    end
  end
  print(('bufs:%s'):format(bufs))
end

local function parseargs(args)
  local exitcode = nil
  for i = 1, #args do
    if args[i] == '--exitcode' then
      exitcode = tonumber(args[i + 1])
    end
  end
  return exitcode
end

local function main()
  printbufs()
  print('nvim args:', #vim.v.argv)
  print('lua args:', vim.inspect(_G.arg))

  local exitcode = parseargs(_G.arg)
  if type(exitcode) == 'number' then
    os.exit(exitcode)
  end
end

main()
