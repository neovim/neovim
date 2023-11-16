--- Default mappings
do
  --- Default maps for * and # in visual mode.
  ---
  --- See |v_star-default| and |v_#-default|
  do
    local function region_chunks(region)
      local chunks = {}
      local maxcol = vim.v.maxcol
      for line, cols in vim.spairs(region) do
        local endcol = cols[2] == maxcol and -1 or cols[2]
        local chunk = vim.api.nvim_buf_get_text(0, line, cols[1], line, endcol, {})[1]
        table.insert(chunks, chunk)
      end
      return chunks
    end

    local function _visual_search(cmd)
      assert(cmd == '/' or cmd == '?')
      local region = vim.region(
        0,
        '.',
        'v',
        vim.api.nvim_get_mode().mode:sub(1, 1),
        vim.o.selection == 'inclusive'
      )
      local chunks = region_chunks(region)
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

  --- Map |gx| to call |vim.ui.open| on the identifier under the cursor
  do
    -- TODO: use vim.region() when it lands... #13896 #16843
    local function get_visual_selection()
      local save_a = vim.fn.getreginfo('a')
      vim.cmd([[norm! "ay]])
      local selection = vim.fn.getreg('a', 1)
      vim.fn.setreg('a', save_a)
      return selection
    end

    local function do_open(uri)
      local _, err = vim.ui.open(uri)
      if err then
        vim.notify(err, vim.log.levels.ERROR)
      end
    end

    local gx_desc =
      'Opens filepath or URI under cursor with the system handler (file explorer, web browser, …)'
    vim.keymap.set({ 'n' }, 'gx', function()
      do_open(vim.fn.expand('<cfile>'))
    end, { desc = gx_desc })
    vim.keymap.set({ 'x' }, 'gx', function()
      do_open(get_visual_selection())
    end, { desc = gx_desc })
  end
end

--- Default menus
do
  --- Right click popup menu
  -- TODO VimScript, no l10n
  vim.cmd([[
    aunmenu *
    vnoremenu PopUp.Cut                     "+x
    vnoremenu PopUp.Copy                    "+y
    anoremenu PopUp.Paste                   "+gP
    vnoremenu PopUp.Paste                   "+P
    vnoremenu PopUp.Delete                  "_x
    nnoremenu PopUp.Select\ All             ggVG
    vnoremenu PopUp.Select\ All             gg0oG$
    inoremenu PopUp.Select\ All             <C-Home><C-O>VG
    anoremenu PopUp.-1-                     <Nop>
    anoremenu PopUp.How-to\ disable\ mouse  <Cmd>help disable-mouse<CR>
  ]])
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
    desc = 'Automatically close terminal buffers when started with no arguments and exiting without an error',
    callback = function(args)
      if vim.v.event.status == 0 then
        local info = vim.api.nvim_get_chan_info(vim.bo[args.buf].channel)
        local argv = info.argv or {}
        if #argv == 1 and argv[1] == vim.o.shell then
          vim.cmd({ cmd = 'bdelete', args = { args.buf }, bang = true })
        end
      end
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
      vim.notify(('W325: Ignoring swapfile from Nvim process %d'):format(info.pid))
    end,
  })
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

  local tty = false
  for _, ui in ipairs(vim.api.nvim_list_uis()) do
    if ui.chan == 1 and ui.stdout_tty then
      tty = true
      break
    end
  end

  if tty then
    local timer = assert(vim.uv.new_timer())

    local id = vim.api.nvim_create_autocmd('TermResponse', {
      nested = true,
      callback = function(args)
        if vim.api.nvim_get_option_info2('background', {}).was_set then
          -- Don't do anything if 'background' is already set
          return true
        end

        local resp = args.data ---@type string
        local r, g, b = parseosc11(resp)
        if r and g and b then
          local rr = parsecolor(r)
          local gg = parsecolor(g)
          local bb = parsecolor(b)

          if rr and gg and bb then
            local luminance = (0.299 * rr) + (0.587 * gg) + (0.114 * bb)
            local bg = luminance < 0.5 and 'dark' or 'light'
            if bg ~= vim.o.background then
              vim.o.background = bg
            end
          end

          return true
        end
      end,
    })

    io.stdout:write('\027]11;?\027\\')

    timer:start(1000, 0, function()
      -- No response received. Delete the autocommand
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
