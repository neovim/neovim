local function clear()
  nvim_command('call BeforeEachTest()')
end

local function feed(...)
  for _, v in ipairs({...}) do
    nvim_feed(nvim_replace_termcodes(dedent(v)))
  end
end

local function rawfeed(...)
  for _, v in ipairs({...}) do
    nvim_feed(dedent(v), 'nt')
  end
end

local function insert(...)
  nvim_feed('i', 'nt')
  rawfeed(...)
  nvim_feed(nvim_replace_termcodes('<ESC>'), 'nt')
end

local function execute(...)
  for _, v in ipairs({...}) do
    if v:sub(1, 1) ~= '/' then
      -- not a search command, prefix with colon
      nvim_feed(':', 'nt')
    end
    nvim_feed(v, 'nt')
    nvim_feed(nvim_replace_termcodes('<CR>'), 'nt')
  end
end

local  function eval(expr)
  local status, result = pcall(function() return nvim_eval(expr) end)
  if not status then
    error('Failed to evaluate expression "' .. expr .. '"')
  end
  return result
end

local function eq(expected, actual)
  return assert.are.same(expected, actual)
end

local function neq(expected, actual)
  return assert.are_not.same(expected, actual)
end

local function expect(contents, first, last, buffer_index)
  return eq(dedent(contents), buffer_slice(first, last, buffer_idx))
end

rawfeed([[:function BeforeEachTest()
  set all&
  redir => groups
  silent augroup
  redir END
  for group in split(groups)
    exe 'augroup '.group
    autocmd!
    augroup END
  endfor
  autocmd!
  tabnew
  let curbufnum = eval(bufnr('%'))
  redir => buflist
  silent ls!
  redir END
  let bufnums = []
  for buf in split(buflist, '\n')
    let bufnum = eval(split(buf, '[ u]')[0])
    if bufnum != curbufnum
      call add(bufnums, bufnum)
    endif
  endfor
  if len(bufnums) > 0
    exe 'silent bwipeout! '.join(bufnums, ' ')
  endif
  silent tabonly
  for k in keys(g:)
    exe 'unlet g:'.k
  endfor
  filetype plugin indent off
  mapclear
  mapclear!
  abclear
  comclear
endfunction
]])

return {
  clear = clear,
  rawfeed = rawfeed,
  insert = insert,
  feed = feed,
  execute = execute,
  eval = eval,
  eq = eq,
  neq = neq,
  expect = expect 
}
