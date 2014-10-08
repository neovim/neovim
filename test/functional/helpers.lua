local Loop = require('nvim.loop')
local MsgpackStream = require('nvim.msgpack_stream')
local AsyncSession = require('nvim.async_session')
local Session = require('nvim.session')

local nvim_prog = os.getenv('NVIM_PROG') or 'build/bin/nvim'
local nvim_argv = {nvim_prog, '-u', 'NONE', '-N', '--embed'}

if os.getenv('VALGRIND') then
  local log_file = os.getenv('VALGRIND_LOG') or 'valgrind-%p.log'
  local valgrind_argv = {'valgrind', '-q', '--tool=memcheck',
                         '--leak-check=yes', '--track-origins=yes',
                         '--suppressions=.valgrind.supp',
                         '--log-file='..log_file}
  if os.getenv('VALGRIND_GDB') then
    table.insert(valgrind_argv, '--vgdb=yes')
    table.insert(valgrind_argv, '--vgdb-error=0')
  end
  local len = #valgrind_argv
  for i = 1, #nvim_argv do
    valgrind_argv[i + len] = nvim_argv[i]
  end
  nvim_argv = valgrind_argv
end

local session

local function restart()
  local loop = Loop.new()
  local msgpack_stream = MsgpackStream.new(loop)
  local async_session = AsyncSession.new(msgpack_stream)
  session = Session.new(async_session)
  loop:spawn(nvim_argv)
end
restart()

local function request(method, ...)
  local status, rv = session:request(method, ...)
  if not status then
    error(rv[2])
  end
  return rv
end

local function next_message()
  return session:next_message()
end

local function run(request_cb, notification_cb, setup_cb)
  session:run(request_cb, notification_cb, setup_cb)
end

local function stop()
  session:stop()
end

local function nvim_command(cmd)
  request('vim_command', cmd)
end

local function nvim_eval(expr)
  return request('vim_eval', expr)
end

local function nvim_feed(input, mode)
  mode = mode or ''
  request('vim_feedkeys', input, mode)
end

local function buffer_slice(start, stop, buffer_idx)
  local include_end = false
  if not stop then
    stop = -1
    include_end = true
  end
  local buffer = request('vim_get_buffers')[buffer_idx or 1]
  local slice = request('buffer_get_line_slice', buffer, start or 0, stop,
                        true, include_end)
  return table.concat(slice, '\n')
end

local function nvim_replace_termcodes(input)
  return request('vim_replace_termcodes', input, false, true, true )
end

local function dedent(str)
  -- find minimum common indent across lines
  local indent = nil
  for line in str:gmatch('[^\n]+') do
    local line_indent = line:match('^%s+') or ''
    if indent == nil or #line_indent < #indent then
      indent = line_indent
    end
  end
  if #indent == 0 then
    -- no minimum common indent
    return str
  end
  -- create a pattern for the indent
  indent = indent:gsub('%s', '%%s')
  -- strip it from the first line
  str = str:gsub('^'..indent, '')
  -- strip it from the remaining lines
  str = str:gsub('[\n]'..indent, '\n')
  return str
end

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
  return eq(dedent(contents), buffer_slice(first, last, buffer_index))
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


local function ok(expr)
  assert.is_true(expr)
end

local function nvim(method, ...)
  return request('vim_'..method, ...)
end

local function buffer(method, ...)
  return request('buffer_'..method, ...)
end

local function window(method, ...)
  return request('window_'..method, ...)
end

local function tabpage(method, ...)
  return request('tabpage_'..method, ...)
end

local function curbuf(method, ...)
  local buf = nvim('get_current_buffer')
  if not method then
    return buf
  end
  return buffer(method, buf, ...)
end

local function curbuf_contents()
  return table.concat(curbuf('get_line_slice', 0, -1, true, true), '\n')
end

local function curwin(method, ...)
  local win = nvim('get_current_window')
  if not method then
    return win
  end
  return window(method, win, ...)
end

local function curtab(method, ...)
  local tab = nvim('get_current_tabpage')
  if not method then
    return tab
  end
  return tabpage(method, tab, ...)
end

return {
  clear = clear,
  restart = restart,
  rawfeed = rawfeed,
  insert = insert,
  feed = feed,
  execute = execute,
  eval = eval,
  request = request,
  next_message = next_message,
  run = run,
  stop = stop,
  eq = eq,
  neq = neq,
  expect = expect,
  ok = ok,
  nvim = nvim,
  buffer = buffer,
  window = window,
  tabpage = tabpage,
  curbuf = curbuf,
  curwin = curwin,
  curtab = curtab,
  curbuf_contents = curbuf_contents
}
