--- popup.lua
---
--- Wrapper to make the popup api from vim in neovim.

local vim = vim

local Border = require("vim.ui.border")

local popup = {}

popup._pos_map = {
  topleft="NW",
  topright="NE",
  botleft="SW",
  botright="SE",
}

-- Keep track of hidden popups, so we can load them with popup.show()
popup._hidden = {}


local function dict_default(options, key, default)
  if options[key] == nil then
    return default[key]
  else
    return options[key]
  end
end


function popup.popup_create(what, vim_options)
  local bufnr
  if type(what) == 'number' then
    bufnr = what
  else
    bufnr = vim.fn.nvim_create_buf(false, true)
    assert(bufnr, "Failed to create buffer")

    -- TODO: Handle list of lines
    vim.fn.nvim_buf_set_lines(bufnr, 0, -1, true, {what})
  end

  local option_defaults = {
    posinvert = true
  }

  local win_opts = {}

  if vim_options.line then
    -- TODO: Need to handle "cursor", "cursor+1", ...
    win_opts.row = vim_options.line
  else
    -- TODO: It says it needs to be "vertically cenetered"?...
    -- wut is that.
    win_opts.row = 0
  end

  if vim_options.col then
    -- TODO: Need to handle "cursor", "cursor+1", ...
    win_opts.col = vim_options.col
  else
    -- TODO: It says it needs to be "horizontally cenetered"?...
    win_opts.col = 0
  end

  if vim_options.pos then
    if vim_options.pos == 'center' then
      -- TODO: Do centering..
    else
      win_opts.anchor = popup._pos_map[vim_options.pos]
    end
  end

  -- posinvert	When FALSE the value of "pos" is always used.  When
  -- 		TRUE (the default) and the popup does not fit
  -- 		vertically and there is more space on the other side
  -- 		then the popup is placed on the other side of the
  -- 		position indicated by "line".
  if dict_default(vim_options, 'posinvert', option_defaults) then
    -- TODO: handle the invert thing
  end

  -- 	fixed		When FALSE (the default), and:
  -- 			 - "pos" is "botleft" or "topleft", and
  -- 			 - "wrap" is off, and
  -- 			 - the popup would be truncated at the right edge of
  -- 			   the screen, then
  -- 			the popup is moved to the left so as to fit the
  -- 			contents on the screen.  Set to TRUE to disable this.

  win_opts.style = 'minimal'

  -- Feels like maxheigh, minheight, maxwidth, minwidth will all be related
  win_opts.height = 5
  win_opts.width = 25

  -- textprop	When present the popup is positioned next to a text
  -- 		property with this name and will move when the text
  -- 		property moves.  Use an empty string to remove.  See
  -- 		|popup-textprop-pos|.
  -- related:
  --   textpropwin
  --   textpropid

  -- border
  local border_options = {}
  if vim_options.border then
    local b_top, b_rgight, b_bot, b_left, b_topleft, b_topright, b_botright, b_botleft
    if vim_options.borderchars == nil then
      b_top , b_rgight , b_bot , b_left , b_topleft , b_topright , b_botright , b_botleft = {
        '-' , '|'      , '-'   , '|'    , '┌'        , '┐'       , '┘'       , '└'
      }
    elseif #vim_options.borderchars == 1 then
      -- TODO: Unpack 8 times cool to the same vars
      print('...')
    elseif #vim_options.borderchars == 2 then
      -- TODO: Unpack to edges & corners
      print('...')
    elseif #vim_options.borderchars == 8 then
      b_top , b_rgight , b_bot , b_left , b_topleft , b_topright , b_botright , b_botleft = vim_options.borderhighlight
    end
  end

  win_opts.relative = "editor"

  local win_id
  if vim_options.hidden then
    assert(false, "I have not implemented this yet and don't know how")
  else
    win_id = vim.fn.nvim_open_win(bufnr, true, win_opts)
  end


  -- Moved, handled after since we need the window ID
  if vim_options.moved then
    if vim_options.moved == 'any' then
      vim.lsp.util.close_preview_autocmd({'CursorMoved', 'CursorMovedI'}, win_id)
    elseif vim_options.moved == 'word' then
      -- TODO: Handle word, WORD, expr, and the range functions... which seem hard?
    end
  else
    vim.cmd(
      string.format(
        "autocmd BufLeave <buffer=%s> ++once call nvim_win_close(%s, v:false)",
        bufnr,
        win_id
      )
    )
  end

  if vim_options.time then
    local timer = vim.loop.new_timer()
    timer:start(vim_options.time, 0, vim.schedule_wrap(function()
      vim.fn.nvim_close_win(win_id, false)
    end))
  end

  -- Buffer Options
  if vim_options.cursorline then
    vim.fn.nvim_win_set_option(0, 'cursorline', true)
  end

  -- vim.fn.nvim_win_set_option(0, 'wrap', dict_default(vim_options, 'wrap', option_defaults))

  -- ===== Not Implemented Options =====
  -- flip: not implemented at the time of writing
  -- Mouse:
  --    mousemoved: no idea how to do the things with the mouse, so it's an exercise for the reader.
  --    drag: mouses are hard
  --    resize: mouses are hard
  --    close: mouses are hard
  --
  -- scrollbar
  -- scrollbarhighlight
  -- thumbhighlight
  --
  -- tabpage: seems useless

  -- Create border

  -- title
  if vim_options.title then
    border_options.title = vim_options.title

    if vim_options.border == 0 or vim_options.border == nil then
      vim_options.border = 1
      border_options.width = 1
    end
  end

  if vim_options.border then
    Border:new(bufnr, win_id, win_opts, border_options)
  end

  -- TODO: Perhaps there's a way to return an object that looks like a window id,
  --    but actually has some extra metadata about it.
  --
  --    This would make `hidden` a lot easier to manage
  return win_id
end

function popup.show(self, asdf)
end

popup.show = function()
end

return popup

