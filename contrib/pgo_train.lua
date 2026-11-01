-- Workload used to collect profile data for a PGO (profile-guided
-- optimization) build.  It must be run with the *instrumented* Nvim binary:
--
--     build/bin/nvim --clean -l contrib/pgo_train.lua
--
-- The functional test suite already covers a lot of code paths but is skewed
-- towards the test harness.  This script complements it with a broad "normal
-- editing session": opening real source files, parsing them with the
-- tree-sitter parser, searching, editing, reading options, etc.
--
-- It does not change the checkout: edits are undone, and the temporary files
-- it creates are deleted again.

local root = vim.fn.getcwd()

local function guarded(fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    io.stderr:write(('pgo_train: %s\n'):format(tostring(err)))
  end
  return ok
end

local function glob(pat, limit)
  local out = {}
  for _, f in ipairs(vim.fn.glob(pat, false, true)) do
    out[#out + 1] = f
    if #out >= limit then
      break
    end
  end
  return out
end

local files = {}
vim.list_extend(files, glob(root .. '/src/nvim/**/*.c', 60))
vim.list_extend(files, glob(root .. '/src/nvim/**/*.h', 40))
vim.list_extend(files, glob(root .. '/runtime/lua/**/*.lua', 50))
vim.list_extend(files, glob(root .. '/runtime/doc/*.txt', 15))
vim.list_extend(files, glob(root .. '/test/functional/**/*_spec.lua', 40))

local searches = {
  'function',
  [[\v<\w+>\ze\s*\(]],
  [[\v<%(const|static|void|int|char)@>]],
  [[\v%(if|for|while|return)@>]],
  [[\C\<nvim_\w+\>]],
  [[{\w\+}]],
  [['\zs[a-z_]\+\ze']],
}

-- Exercise the regex engine, cursor motion and fold computation on the current
-- buffer.
local function exercise_buffer()
  vim.bo.swapfile = false
  for _, pat in ipairs(searches) do
    vim.fn.cursor(1, 1)
    for _ = 1, 60 do
      if vim.fn.search(pat, 'W') == 0 then
        break
      end
    end
    vim.fn.search(pat, 'bW')
  end

  -- Text manipulation through the API.
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  if #lines > 0 then
    vim.api.nvim_buf_set_lines(0, 0, math.min(5, #lines), false, lines)
  end

  -- matchstr / matchbufline paths.
  guarded(vim.fn.matchstr, vim.api.nvim_get_current_line(), [['\w\+']])
  guarded(vim.fn.matchbufline, 0, [[\w\+]], 1, '$')
end

-- tree-sitter highlighting/query paths.
local function exercise_treesitter(lang)
  guarded(function()
    local parser = vim.treesitter.get_parser(0, lang)
    local tree = parser:parse()[1]
    tree:root():child(0)
    vim.treesitter.highlighter.new(parser)
  end)
end

-- Open each collected file and drive it through the workload.
vim.cmd('set nomore shortmess+=F')
local n = 0
for _, f in ipairs(files) do
  guarded(function()
    vim.cmd.edit(vim.fn.fnameescape(f))
    vim.bo.swapfile = false
    exercise_buffer()

    local ext = f:match('%.([^.]+)$')
    if ext == 'c' or ext == 'h' then
      exercise_treesitter('c')
    elseif ext == 'lua' then
      exercise_treesitter('lua')
    end

    -- Substitute engine + undo.
    vim.cmd([[silent! keepjumps %s/\v\w+/x/]])
    vim.cmd('silent! undo')
  end)
  n = n + 1
end

-- A single large buffer, to exercise the buffering/redraw/scrolling code that
-- small files miss.
guarded(function()
  local chunks = {}
  for _, f in ipairs(glob(root .. '/src/nvim/*.c', 500)) do
    vim.list_extend(chunks, vim.fn.readfile(f))
    chunks[#chunks + 1] = ''
  end
  local f = vim.fn.tempname()
  vim.fn.writefile(chunks, f)
  vim.cmd.edit(vim.fn.fnameescape(f))
  vim.bo.swapfile = false
  vim.bo.syntax = 'c'
  exercise_buffer()
  for _ = 1, 40 do
    vim.fn.search([[\v<\w+>\ze\s*\(]], 'W')
  end
  for _ = 1, 20 do
    vim.cmd('normal! ' .. vim.keycode('<C-f>')) -- page down
    vim.cmd('normal! ' .. vim.keycode('<C-y>')) -- scroll up
  end
  vim.cmd('silent! %s/\\v\\s+$//')
  vim.cmd('silent! undo')
  -- Wipe the buffer before removing the file, otherwise Nvim complains (E211).
  vim.cmd('silent! bwipeout!')
  vim.fn.delete(f)
end)

-- Option / vim.fn getters and setters.
guarded(function()
  local opts = {
    'tabstop',
    'shiftwidth',
    'expandtab',
    'number',
    'relativenumber',
    'wrap',
    'colorcolumn',
    'commentstring',
    'listchars',
    'fillchars',
  }
  for i = 1, 200 do
    local o = opts[(i % #opts) + 1]
    vim.api.nvim_set_option_value(o, vim.api.nvim_get_option_value(o, {}), {})
  end
end)

-- Autocommand dispatch.
guarded(function()
  vim.cmd([[
    augroup pgo_train
      autocmd!
      autocmd BufEnter,BufLeave,TextChanged,CursorMoved * let g:pgo_train_hits = get(g:, 'pgo_train_hits', 0) + 1
    augroup END
  ]])
  for _ = 1, 50 do
    vim.cmd('silent! buffer 1')
    vim.cmd('silent! doautocmd CursorMoved')
    vim.cmd('silent! doautocmd TextChanged')
  end
end)

-- Force redraws.  There is usually no grid attached in headless mode, so this
-- is mostly a way to touch the redraw entry points; the functional test suite
-- (test/functional/ui) is what really exercises the screen update code.
guarded(function()
  vim.cmd('redraw!')
  vim.cmd('normal! G')
  vim.cmd('mode')
end)

-- Interactive TUI session.  Headless Nvim has no grid, so the screen update
-- code (screen.c, grid.c, drawline.c) and the terminal UI (tui.c) are barely
-- touched by the rest of this workload.  Spawning Nvim with a pty attaches the
-- real terminal UI; feeding it keys then drives the whole redraw pipeline,
-- including window layout, wrapping and highlighting.
guarded(function()
  local big = vim.fn.tempname()
  local chunks = {}
  for _, f in ipairs(glob(root .. '/src/nvim/*.c', 300)) do
    vim.list_extend(chunks, vim.fn.readfile(f))
    chunks[#chunks + 1] = ''
  end
  vim.fn.writefile(chunks, big)

  local child = vim.fn.jobstart({ vim.v.progpath, '--clean', big }, {
    pty = true,
    env = { TERM = 'xterm-256color' },
    on_stdout = function() end,
    on_stderr = function() end,
  })
  if child <= 0 then
    vim.fn.delete(big)
    return
  end

  local function feed(keys)
    vim.fn.chansend(child, keys)
    vim.wait(25)
  end

  local ok, err = pcall(function()
    vim.wait(300) -- let the TUI attach and paint the first screen
    feed(':set number relativenumber cursorline scrolloff=8\r')
    feed(':set syntax=c\r') -- legacy syntax highlighting on every redraw
    feed(':set hlsearch incsearch\r')
    feed('gg')
    for _ = 1, 30 do
      feed(vim.keycode('<C-e>')) -- scroll down one line
    end
    for _ = 1, 30 do
      feed(vim.keycode('<C-y>')) -- scroll up one line
    end
    feed('G')
    for _ = 1, 20 do
      feed(vim.keycode('<C-f>')) -- page down
    end
    for _ = 1, 20 do
      feed(vim.keycode('<C-b>')) -- page up
    end
    feed('/function\r')
    for _ = 1, 15 do
      feed('n')
    end
    feed(':noswapfile vsplit\r') -- window layout changes
    feed(':noswapfile split\r')
    for _ = 1, 5 do
      feed(vim.keycode('<C-w>=')) -- equalize windows
    end
    feed('G')
    for _ = 1, 15 do
      feed('k')
    end
    feed(':set wrap linebreak\r') -- wrapped-line drawing
    feed('G')
    for _ = 1, 10 do
      feed('k')
    end
    feed(':set nowrap\r')
    feed(':qa!\r')
    vim.wait(300)
  end)
  -- Always clean up, even if feeding the keys failed (e.g. the child exited).
  pcall(vim.fn.jobstop, child)
  vim.fn.delete(big)
  if not ok then
    error(err)
  end
end)

io.stderr:write(('pgo_train: exercised %d files\n'):format(n))
