--- Default user commands
do
  vim.api.nvim_create_user_command('Inspect', function(cmd)
    if cmd.bang then
      vim.print(vim.inspect_pos())
    else
      vim.show_pos()
    end
  end, { desc = 'Inspect highlights and extmarks at the cursor', bang = true })

  vim.api.nvim_create_user_command('InspectTree', function(cmd)
    if cmd.mods ~= '' or cmd.count ~= 0 then
      local count = cmd.count ~= 0 and cmd.count or ''
      local new = cmd.mods ~= '' and 'new' or 'vnew'

      vim.treesitter.inspect_tree({
        command = ('%s %s%s'):format(cmd.mods, count, new),
      })
    else
      vim.treesitter.inspect_tree()
    end
  end, { desc = 'Inspect treesitter language tree for buffer', count = true })

  vim.api.nvim_create_user_command('EditQuery', function(cmd)
    vim.treesitter.query.edit(cmd.fargs[1])
  end, { desc = 'Edit treesitter query', nargs = '?' })
end

--- Default mappings
do
  --- Default maps for * and # in visual mode.
  ---
  --- See |v_star-default| and |v_#-default|
  do
    local function _visual_search(cmd)
      assert(cmd == '/' or cmd == '?')
      local chunks =
        vim.fn.getregion(vim.fn.getpos('.'), vim.fn.getpos('v'), { type = vim.fn.mode() })
      local esc_chunks = vim
        .iter(chunks)
        :map(function(v)
          return vim.fn.escape(v, cmd == '/' and [[/\]] or [[?\]])
        end)
        :totable()
      local esc_pat = table.concat(esc_chunks, [[\n]])
      local search_cmd = ([[%s\V%s%s]]):format(cmd, esc_pat, '\n')
      return '\27' .. search_cmd
    end

    vim.keymap.set('x', '*', function()
      return _visual_search('/')
    end, { desc = ':help v_star-default', expr = true, silent = true })
    vim.keymap.set('x', '#', function()
      return _visual_search('?')
    end, { desc = ':help v_#-default', expr = true, silent = true })
  end

  --- Map Y to y$. This mimics the behavior of D and C. See |Y-default|
  vim.keymap.set('n', 'Y', 'y$', { desc = ':help Y-default' })

  --- Use normal! <C-L> to prevent inserting raw <C-L> when using i_<C-O>. #17473
  ---
  --- See |CTRL-L-default|
  vim.keymap.set('n', '<C-L>', '<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>', {
    desc = ':help CTRL-L-default',
  })

  --- Set undo points when deleting text in insert mode.
  ---
  --- See |i_CTRL-U-default| and |i_CTRL-W-default|
  vim.keymap.set('i', '<C-U>', '<C-G>u<C-U>', { desc = ':help i_CTRL-U-default' })
  vim.keymap.set('i', '<C-W>', '<C-G>u<C-W>', { desc = ':help i_CTRL-W-default' })

  --- Use the same flags as the previous substitution with &.
  ---
  --- Use : instead of <Cmd> so that ranges are supported. #19365
  ---
  --- See |&-default|
  vim.keymap.set('n', '&', ':&&<CR>', { desc = ':help &-default' })

  --- Use Q in Visual mode to execute a macro on each line of the selection. #21422
  --- This only make sense in linewise Visual mode. #28287
  ---
  --- Applies to @x and includes @@ too.
  vim.keymap.set(
    'x',
    'Q',
    "mode() ==# 'V' ? ':normal! @<C-R>=reg_recorded()<CR><CR>' : 'Q'",
    { silent = true, expr = true, desc = ':help v_Q-default' }
  )
  vim.keymap.set(
    'x',
    '@',
    "mode() ==# 'V' ? ':normal! @'.getcharstr().'<CR>' : '@'",
    { silent = true, expr = true, desc = ':help v_@-default' }
  )

  --- Map |gx| to call |vim.ui.open| on the <cfile> at cursor.
  do
    local function do_open(uri)
      local cmd, err = vim.ui.open(uri)
      local rv = cmd and cmd:wait(1000) or nil
      if cmd and rv and rv.code ~= 0 then
        err = ('vim.ui.open: command %s (%d): %s'):format(
          (rv.code == 124 and 'timeout' or 'failed'),
          rv.code,
          vim.inspect(cmd.cmd)
        )
      end
      return err
    end

    local gx_desc =
      'Opens filepath or URI under cursor with the system handler (file explorer, web browser, …)'
    vim.keymap.set({ 'n' }, 'gx', function()
      for _, url in ipairs(require('vim.ui')._get_urls()) do
        local err = do_open(url)
        if err then
          vim.notify(err, vim.log.levels.ERROR)
        end
      end
    end, { desc = gx_desc })
    vim.keymap.set({ 'x' }, 'gx', function()
      local lines =
        vim.fn.getregion(vim.fn.getpos('.'), vim.fn.getpos('v'), { type = vim.fn.mode() })
      -- Trim whitespace on each line and concatenate.
      local err = do_open(table.concat(vim.iter(lines):map(vim.trim):totable()))
      if err then
        vim.notify(err, vim.log.levels.ERROR)
      end
    end, { desc = gx_desc })
  end

  --- Default maps for built-in commenting.
  ---
  --- See |gc-default| and |gcc-default|.
  do
    local operator_rhs = function()
      return require('vim._comment').operator()
    end
    vim.keymap.set({ 'n', 'x' }, 'gc', operator_rhs, { expr = true, desc = 'Toggle comment' })

    local line_rhs = function()
      return require('vim._comment').operator() .. '_'
    end
    vim.keymap.set('n', 'gcc', line_rhs, { expr = true, desc = 'Toggle comment line' })

    local textobject_rhs = function()
      require('vim._comment').textobject()
    end
    vim.keymap.set({ 'o' }, 'gc', textobject_rhs, { desc = 'Comment textobject' })
  end

  --- Default maps for LSP functions.
  ---
  --- These are mapped unconditionally to avoid different behavior depending on whether an LSP
  --- client is attached. If no client is attached, or if a server does not support a capability, an
  --- error message is displayed rather than exhibiting different behavior.
  ---
  --- See |grr|, |grn|, |gra|, |gri|, |gO|, |i_CTRL-S|.
  do
    vim.keymap.set('n', 'grn', function()
      vim.lsp.buf.rename()
    end, { desc = 'vim.lsp.buf.rename()' })

    vim.keymap.set({ 'n', 'x' }, 'gra', function()
      vim.lsp.buf.code_action()
    end, { desc = 'vim.lsp.buf.code_action()' })

    vim.keymap.set('n', 'grr', function()
      vim.lsp.buf.references()
    end, { desc = 'vim.lsp.buf.references()' })

    vim.keymap.set('n', 'gri', function()
      vim.lsp.buf.implementation()
    end, { desc = 'vim.lsp.buf.implementation()' })

    vim.keymap.set('n', 'gO', function()
      vim.lsp.buf.document_symbol()
    end, { desc = 'vim.lsp.buf.document_symbol()' })

    vim.keymap.set('i', '<C-S>', function()
      vim.lsp.buf.signature_help()
    end, { desc = 'vim.lsp.buf.signature_help()' })
  end

  --- Map [d and ]d to move to the previous/next diagnostic. Map <C-W>d to open a floating window
  --- for the diagnostic under the cursor.
  ---
  --- See |[d-default|, |]d-default|, and |CTRL-W_d-default|.
  do
    vim.keymap.set('n', ']d', function()
      vim.diagnostic.jump({ count = vim.v.count1 })
    end, { desc = 'Jump to the next diagnostic in the current buffer' })

    vim.keymap.set('n', '[d', function()
      vim.diagnostic.jump({ count = -vim.v.count1 })
    end, { desc = 'Jump to the previous diagnostic in the current buffer' })

    vim.keymap.set('n', ']D', function()
      vim.diagnostic.jump({ count = math.huge, wrap = false })
    end, { desc = 'Jump to the last diagnostic in the current buffer' })

    vim.keymap.set('n', '[D', function()
      vim.diagnostic.jump({ count = -math.huge, wrap = false })
    end, { desc = 'Jump to the first diagnostic in the current buffer' })

    vim.keymap.set('n', '<C-W>d', function()
      vim.diagnostic.open_float()
    end, { desc = 'Show diagnostics under the cursor' })

    vim.keymap.set(
      'n',
      '<C-W><C-D>',
      '<C-W>d',
      { remap = true, desc = 'Show diagnostics under the cursor' }
    )
  end

  --- vim-unimpaired style mappings. See: https://github.com/tpope/vim-unimpaired
  do
    --- Execute a command and print errors without a stacktrace.
    --- @param opts table Arguments to |nvim_cmd()|
    local function cmd(opts)
      local _, err = pcall(vim.api.nvim_cmd, opts, {})
      if err then
        vim.api.nvim_err_writeln(err:sub(#'Vim:' + 1))
      end
    end

    -- Quickfix mappings
    vim.keymap.set('n', '[q', function()
      cmd({ cmd = 'cprevious', count = vim.v.count1 })
    end, { desc = ':cprevious' })

    vim.keymap.set('n', ']q', function()
      cmd({ cmd = 'cnext', count = vim.v.count1 })
    end, { desc = ':cnext' })

    vim.keymap.set('n', '[Q', function()
      cmd({ cmd = 'crewind', count = vim.v.count ~= 0 and vim.v.count or nil })
    end, { desc = ':crewind' })

    vim.keymap.set('n', ']Q', function()
      cmd({ cmd = 'clast', count = vim.v.count ~= 0 and vim.v.count or nil })
    end, { desc = ':clast' })

    vim.keymap.set('n', '[<C-Q>', function()
      cmd({ cmd = 'cpfile', count = vim.v.count1 })
    end, { desc = ':cpfile' })

    vim.keymap.set('n', ']<C-Q>', function()
      cmd({ cmd = 'cnfile', count = vim.v.count1 })
    end, { desc = ':cnfile' })

    -- Location list mappings
    vim.keymap.set('n', '[l', function()
      cmd({ cmd = 'lprevious', count = vim.v.count1 })
    end, { desc = ':lprevious' })

    vim.keymap.set('n', ']l', function()
      cmd({ cmd = 'lnext', count = vim.v.count1 })
    end, { desc = ':lnext' })

    vim.keymap.set('n', '[L', function()
      cmd({ cmd = 'lrewind', count = vim.v.count ~= 0 and vim.v.count or nil })
    end, { desc = ':lrewind' })

    vim.keymap.set('n', ']L', function()
      cmd({ cmd = 'llast', count = vim.v.count ~= 0 and vim.v.count or nil })
    end, { desc = ':llast' })

    vim.keymap.set('n', '[<C-L>', function()
      cmd({ cmd = 'lpfile', count = vim.v.count1 })
    end, { desc = ':lpfile' })

    vim.keymap.set('n', ']<C-L>', function()
      cmd({ cmd = 'lnfile', count = vim.v.count1 })
    end, { desc = ':lnfile' })

    -- Argument list
    vim.keymap.set('n', '[a', function()
      cmd({ cmd = 'previous', count = vim.v.count1 })
    end, { desc = ':previous' })

    vim.keymap.set('n', ']a', function()
      -- count doesn't work with :next, must use range. See #30641.
      cmd({ cmd = 'next', range = { vim.v.count1 } })
    end, { desc = ':next' })

    vim.keymap.set('n', '[A', function()
      if vim.v.count ~= 0 then
        cmd({ cmd = 'argument', count = vim.v.count })
      else
        cmd({ cmd = 'rewind' })
      end
    end, { desc = ':rewind' })

    vim.keymap.set('n', ']A', function()
      if vim.v.count ~= 0 then
        cmd({ cmd = 'argument', count = vim.v.count })
      else
        cmd({ cmd = 'last' })
      end
    end, { desc = ':last' })

    -- Tags
    vim.keymap.set('n', '[t', function()
      -- count doesn't work with :tprevious, must use range. See #30641.
      cmd({ cmd = 'tprevious', range = { vim.v.count1 } })
    end, { desc = ':tprevious' })

    vim.keymap.set('n', ']t', function()
      -- count doesn't work with :tnext, must use range. See #30641.
      cmd({ cmd = 'tnext', range = { vim.v.count1 } })
    end, { desc = ':tnext' })

    vim.keymap.set('n', '[T', function()
      -- count doesn't work with :trewind, must use range. See #30641.
      cmd({ cmd = 'trewind', range = vim.v.count ~= 0 and { vim.v.count } or nil })
    end, { desc = ':trewind' })

    vim.keymap.set('n', ']T', function()
      -- :tlast does not accept a count, so use :trewind if count given
      if vim.v.count ~= 0 then
        cmd({ cmd = 'trewind', range = { vim.v.count } })
      else
        cmd({ cmd = 'tlast' })
      end
    end, { desc = ':tlast' })

    vim.keymap.set('n', '[<C-T>', function()
      -- count doesn't work with :ptprevious, must use range. See #30641.
      cmd({ cmd = 'ptprevious', range = { vim.v.count1 } })
    end, { desc = ' :ptprevious' })

    vim.keymap.set('n', ']<C-T>', function()
      -- count doesn't work with :ptnext, must use range. See #30641.
      cmd({ cmd = 'ptnext', range = { vim.v.count1 } })
    end, { desc = ':ptnext' })

    -- Buffers
    vim.keymap.set('n', '[b', function()
      cmd({ cmd = 'bprevious', count = vim.v.count1 })
    end, { desc = ':bprevious' })

    vim.keymap.set('n', ']b', function()
      cmd({ cmd = 'bnext', count = vim.v.count1 })
    end, { desc = ':bnext' })

    vim.keymap.set('n', '[B', function()
      if vim.v.count ~= 0 then
        cmd({ cmd = 'buffer', count = vim.v.count })
      else
        cmd({ cmd = 'brewind' })
      end
    end, { desc = ':brewind' })

    vim.keymap.set('n', ']B', function()
      if vim.v.count ~= 0 then
        cmd({ cmd = 'buffer', count = vim.v.count })
      else
        cmd({ cmd = 'blast' })
      end
    end, { desc = ':blast' })
  end
end

--- Default menus
do
  --- Right click popup menu
  vim.cmd([[
    anoremenu PopUp.Go\ to\ definition      <Cmd>lua vim.lsp.buf.definition()<CR>
    amenu     PopUp.Open\ in\ web\ browser  gx
    anoremenu PopUp.Inspect                 <Cmd>Inspect<CR>
    anoremenu PopUp.-1-                     <Nop>
    vnoremenu PopUp.Cut                     "+x
    vnoremenu PopUp.Copy                    "+y
    anoremenu PopUp.Paste                   "+gP
    vnoremenu PopUp.Paste                   "+P
    vnoremenu PopUp.Delete                  "_x
    nnoremenu PopUp.Select\ All             ggVG
    vnoremenu PopUp.Select\ All             gg0oG$
    inoremenu PopUp.Select\ All             <C-Home><C-O>VG
    anoremenu PopUp.-2-                     <Nop>
    anoremenu PopUp.How-to\ disable\ mouse  <Cmd>help disable-mouse<CR>
  ]])

  local function enable_ctx_menu(ctx)
    vim.cmd([[
      amenu disable PopUp.Go\ to\ definition
      amenu disable PopUp.Open\ in\ web\ browser
    ]])

    if ctx == 'url' then
      vim.cmd([[amenu enable PopUp.Open\ in\ web\ browser]])
    elseif ctx == 'lsp' then
      vim.cmd([[anoremenu enable PopUp.Go\ to\ definition]])
    end
  end

  local nvim_popupmenu_augroup = vim.api.nvim_create_augroup('nvim_popupmenu', {})
  vim.api.nvim_create_autocmd('MenuPopup', {
    pattern = '*',
    group = nvim_popupmenu_augroup,
    desc = 'Mouse popup menu',
    -- nested = true,
    callback = function()
      local urls = require('vim.ui')._get_urls()
      local url = vim.startswith(urls[1], 'http')
      local ctx = url and 'url' or (vim.lsp.get_clients({ bufnr = 0 })[1] and 'lsp' or nil)
      enable_ctx_menu(ctx)
    end,
  })
end

--- Default autocommands. See |default-autocmds|
do
  local nvim_terminal_augroup = vim.api.nvim_create_augroup('nvim_terminal', {})
  vim.api.nvim_create_autocmd('BufReadCmd', {
    pattern = 'term://*',
    group = nvim_terminal_augroup,
    desc = 'Treat term:// buffers as terminal buffers',
    nested = true,
    command = "if !exists('b:term_title')|call termopen(matchstr(expand(\"<amatch>\"), '\\c\\mterm://\\%(.\\{-}//\\%(\\d\\+:\\)\\?\\)\\?\\zs.*'), {'cwd': expand(get(matchlist(expand(\"<amatch>\"), '\\c\\mterm://\\(.\\{-}\\)//'), 1, ''))})",
  })

  vim.api.nvim_create_autocmd({ 'TermClose' }, {
    group = nvim_terminal_augroup,
    nested = true,
    desc = 'Automatically close terminal buffers when started with no arguments and exiting without an error',
    callback = function(args)
      if vim.v.event.status ~= 0 then
        return
      end
      local info = vim.api.nvim_get_chan_info(vim.bo[args.buf].channel)
      local argv = info.argv or {}
      if table.concat(argv, ' ') == vim.o.shell then
        vim.api.nvim_buf_delete(args.buf, { force = true })
      end
    end,
  })

  vim.api.nvim_create_autocmd('TermRequest', {
    group = nvim_terminal_augroup,
    desc = 'Handles OSC foreground/background color requests',
    callback = function(args)
      --- @type integer
      local channel = vim.bo[args.buf].channel
      if channel == 0 then
        return
      end
      local fg_request = args.data == '\027]10;?'
      local bg_request = args.data == '\027]11;?'
      if fg_request or bg_request then
        -- WARN: This does not return the actual foreground/background color,
        -- but rather returns:
        --   - fg=white/bg=black when Nvim option 'background' is 'dark'
        --   - fg=black/bg=white when Nvim option 'background' is 'light'
        local red, green, blue = 0, 0, 0
        local bg_option_dark = vim.o.background == 'dark'
        if (fg_request and bg_option_dark) or (bg_request and not bg_option_dark) then
          red, green, blue = 65535, 65535, 65535
        end
        local command = fg_request and 10 or 11
        local data = string.format('\027]%d;rgb:%04x/%04x/%04x\007', command, red, green, blue)
        vim.api.nvim_chan_send(channel, data)
      end
    end,
  })

  vim.api.nvim_create_autocmd('TermOpen', {
    group = nvim_terminal_augroup,
    desc = 'Default settings for :terminal buffers',
    callback = function()
      vim.bo.modifiable = false
      vim.bo.undolevels = -1
      vim.bo.scrollback = vim.o.scrollback < 0 and 10000 or math.max(1, vim.o.scrollback)
      vim.bo.textwidth = 0
      vim.wo[0][0].wrap = false
      vim.wo[0][0].list = false

      -- This is gross. Proper list options support when?
      local winhl = vim.o.winhighlight
      if winhl ~= '' then
        winhl = winhl .. ','
      end
      vim.wo[0][0].winhighlight = winhl .. 'StatusLine:StatusLineTerm,StatusLineNC:StatusLineTermNC'
    end,
  })

  vim.api.nvim_create_autocmd('CmdwinEnter', {
    pattern = '[:>]',
    desc = 'Limit syntax sync to maxlines=1 in the command window',
    group = vim.api.nvim_create_augroup('nvim_cmdwin', {}),
    command = 'syntax sync minlines=1 maxlines=1',
  })

  vim.api.nvim_create_autocmd('SwapExists', {
    pattern = '*',
    desc = 'Skip the swapfile prompt when the swapfile is owned by a running Nvim process',
    group = vim.api.nvim_create_augroup('nvim_swapfile', {}),
    callback = function()
      local info = vim.fn.swapinfo(vim.v.swapname)
      local user = vim.uv.os_get_passwd().username
      local iswin = 1 == vim.fn.has('win32')
      if info.error or info.pid <= 0 or (not iswin and info.user ~= user) then
        vim.v.swapchoice = '' -- Show the prompt.
        return
      end
      vim.v.swapchoice = 'e' -- Choose "(E)dit".
      vim.notify(
        ('W325: Ignoring swapfile from Nvim process %d'):format(info.pid),
        vim.log.levels.WARN
      )
    end,
  })

  -- Only do the following when the TUI is attached
  local tty = nil
  for _, ui in ipairs(vim.api.nvim_list_uis()) do
    if ui.chan == 1 and ui.stdout_tty then
      tty = ui
      break
    end
  end

  if tty then
    local group = vim.api.nvim_create_augroup('nvim_tty', {})

    --- Set an option after startup (so that OptionSet is fired), but only if not
    --- already set by the user.
    ---
    --- @param option string Option name
    --- @param value any Option value
    local function setoption(option, value)
      if vim.api.nvim_get_option_info2(option, {}).was_set then
        -- Don't do anything if option is already set
        return
      end

      -- Wait until Nvim is finished starting to set the option to ensure the
      -- OptionSet event fires.
      if vim.v.vim_did_enter == 1 then
        --- @diagnostic disable-next-line:no-unknown
        vim.o[option] = value
      else
        vim.api.nvim_create_autocmd('VimEnter', {
          group = group,
          once = true,
          nested = true,
          callback = function()
            setoption(option, value)
          end,
        })
      end
    end

    --- Guess value of 'background' based on terminal color.
    ---
    --- We write Operating System Command (OSC) 11 to the terminal to request the
    --- terminal's background color. We then wait for a response. If the response
    --- matches `rgba:RRRR/GGGG/BBBB/AAAA` where R, G, B, and A are hex digits, then
    --- compute the luminance[1] of the RGB color and classify it as light/dark
    --- accordingly. Note that the color components may have anywhere from one to
    --- four hex digits, and require scaling accordingly as values out of 4, 8, 12,
    --- or 16 bits. Also note the A(lpha) component is optional, and is parsed but
    --- ignored in the calculations.
    ---
    --- [1] https://en.wikipedia.org/wiki/Luma_%28video%29
    do
      --- Parse a string of hex characters as a color.
      ---
      --- The string can contain 1 to 4 hex characters. The returned value is
      --- between 0.0 and 1.0 (inclusive) representing the intensity of the color.
      ---
      --- For instance, if only a single hex char "a" is used, then this function
      --- returns 0.625 (10 / 16), while a value of "aa" would return 0.664 (170 /
      --- 256).
      ---
      --- @param c string Color as a string of hex chars
      --- @return number? Intensity of the color
      local function parsecolor(c)
        if #c == 0 or #c > 4 then
          return nil
        end

        local val = tonumber(c, 16)
        if not val then
          return nil
        end

        local max = tonumber(string.rep('f', #c), 16)
        return val / max
      end

      --- Parse an OSC 11 response
      ---
      --- Either of the two formats below are accepted:
      ---
      ---   OSC 11 ; rgb:<red>/<green>/<blue>
      ---
      --- or
      ---
      ---   OSC 11 ; rgba:<red>/<green>/<blue>/<alpha>
      ---
      --- where
      ---
      ---   <red>, <green>, <blue>, <alpha> := h | hh | hhh | hhhh
      ---
      --- The alpha component is ignored, if present.
      ---
      --- @param resp string OSC 11 response
      --- @return string? Red component
      --- @return string? Green component
      --- @return string? Blue component
      local function parseosc11(resp)
        local r, g, b
        r, g, b = resp:match('^\027%]11;rgb:(%x+)/(%x+)/(%x+)$')
        if not r and not g and not b then
          local a
          r, g, b, a = resp:match('^\027%]11;rgba:(%x+)/(%x+)/(%x+)/(%x+)$')
          if not a or #a > 4 then
            return nil, nil, nil
          end
        end

        if r and g and b and #r <= 4 and #g <= 4 and #b <= 4 then
          return r, g, b
        end

        return nil, nil, nil
      end

      local timer = assert(vim.uv.new_timer())

      local id = vim.api.nvim_create_autocmd('TermResponse', {
        group = group,
        nested = true,
        callback = function(args)
          local resp = args.data ---@type string
          local r, g, b = parseosc11(resp)
          if r and g and b then
            local rr = parsecolor(r)
            local gg = parsecolor(g)
            local bb = parsecolor(b)

            if rr and gg and bb then
              local luminance = (0.299 * rr) + (0.587 * gg) + (0.114 * bb)
              local bg = luminance < 0.5 and 'dark' or 'light'
              setoption('background', bg)
            end

            return true
          end
        end,
      })

      io.stdout:write('\027]11;?\007')

      timer:start(1000, 0, function()
        -- Delete the autocommand if no response was received
        vim.schedule(function()
          -- Suppress error if autocommand has already been deleted
          pcall(vim.api.nvim_del_autocmd, id)
        end)

        if not timer:is_closing() then
          timer:close()
        end
      end)
    end

    --- If the TUI (term_has_truecolor) was able to determine that the host
    --- terminal supports truecolor, enable 'termguicolors'. Otherwise, query the
    --- terminal (using both XTGETTCAP and SGR + DECRQSS). If the terminal's
    --- response indicates that it does support truecolor enable 'termguicolors',
    --- but only if the user has not already disabled it.
    do
      local colorterm = os.getenv('COLORTERM')
      if tty.rgb or colorterm == 'truecolor' or colorterm == '24bit' then
        -- The TUI was able to determine truecolor support or $COLORTERM explicitly indicates
        -- truecolor support
        setoption('termguicolors', true)
      elseif colorterm == nil or colorterm == '' then
        -- Neither the TUI nor $COLORTERM indicate that truecolor is supported, so query the
        -- terminal
        local caps = {} ---@type table<string, boolean>
        require('vim.termcap').query({ 'Tc', 'RGB', 'setrgbf', 'setrgbb' }, function(cap, found)
          if not found then
            return
          end

          caps[cap] = true
          if caps.Tc or caps.RGB or (caps.setrgbf and caps.setrgbb) then
            setoption('termguicolors', true)
          end
        end)

        local timer = assert(vim.uv.new_timer())

        -- Arbitrary colors to set in the SGR sequence
        local r = 1
        local g = 2
        local b = 3

        local id = vim.api.nvim_create_autocmd('TermResponse', {
          group = group,
          nested = true,
          callback = function(args)
            local resp = args.data ---@type string
            local decrqss = resp:match('^\027P1%$r([%d;:]+)m$')

            if decrqss then
              -- The DECRQSS SGR response first contains attributes separated by
              -- semicolons, followed by the SGR itself with parameters separated
              -- by colons. Some terminals include "0" in the attribute list
              -- unconditionally; others do not. Our SGR sequence did not set any
              -- attributes, so there should be no attributes in the list.
              local attrs = vim.split(decrqss, ';')
              if #attrs ~= 1 and (#attrs ~= 2 or attrs[1] ~= '0') then
                return false
              end

              -- The returned SGR sequence should begin with 48:2
              local sgr = attrs[#attrs]:match('^48:2:([%d:]+)$')
              if not sgr then
                return false
              end

              -- The remaining elements of the SGR sequence should be the 3 colors
              -- we set. Some terminals also include an additional parameter
              -- (which can even be empty!), so handle those cases as well
              local params = vim.split(sgr, ':')
              if #params ~= 3 and (#params ~= 4 or (params[1] ~= '' and params[1] ~= '1')) then
                return true
              end

              if
                tonumber(params[#params - 2]) == r
                and tonumber(params[#params - 1]) == g
                and tonumber(params[#params]) == b
              then
                setoption('termguicolors', true)
              end

              return true
            end
          end,
        })

        -- Write SGR followed by DECRQSS. This sets the background color then
        -- immediately asks the terminal what the background color is. If the
        -- terminal responds to the DECRQSS with the same SGR sequence that we
        -- sent then the terminal supports truecolor.
        local decrqss = '\027P$qm\027\\'
        if os.getenv('TMUX') then
          decrqss = string.format('\027Ptmux;%s\027\\', decrqss:gsub('\027', '\027\027'))
        end
        -- Reset attributes first, as other code may have set attributes.
        io.stdout:write(string.format('\027[0m\027[48;2;%d;%d;%dm%s', r, g, b, decrqss))

        timer:start(1000, 0, function()
          -- Delete the autocommand if no response was received
          vim.schedule(function()
            -- Suppress error if autocommand has already been deleted
            pcall(vim.api.nvim_del_autocmd, id)
          end)

          if not timer:is_closing() then
            timer:close()
          end
        end)
      end
    end
  end
end

--- Default options
do
  --- Default 'grepprg' to ripgrep if available.
  if vim.fn.executable('rg') == 1 then
    -- Use -uu to make ripgrep not check ignore files/skip dot-files
    vim.o.grepprg = 'rg --vimgrep -uu '
    vim.o.grepformat = '%f:%l:%c:%m'
  end
end
