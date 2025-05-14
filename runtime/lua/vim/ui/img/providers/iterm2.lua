-- Older tmux versions support a max of 256 bytes, and the file part transfer
-- outside of content is 17 bytes. Max for newer tmux/iterm2 is 1,048,576 bytes.
-- We're going to stick with the newer byte maximum as the lower is very restrictive.
local ITERM2_MAX_TRANSFER_SIZE = 1048576

-- Contents sent within an escape sequence make up a portion of the total sequence.
-- This represens the size of the contents section.
local MAX_CONTENTS_SIZE = ITERM2_MAX_TRANSFER_SIZE - 17

---Amount of time to wait between a refresh of neovim's TUI screen and redrawing
---all images managed by the iterm2 provider.
---@type integer
local REDRAW_DELAY_MS = 30

---@class vim.ui.img.providers.Iterm2
---@field private __debug_write? fun(...:string)
---@field private __id_cnt integer
---@field private __is_drawing boolean
---@field private __is_tmux boolean
---@field private __placements table<integer, {img:vim.ui.Image, opts:vim.ui.img.Opts, clear:boolean, redraw:boolean}>
---@field private __redraw_autocmds integer[]
---@field private __redraw_timer? uv.uv_timer_t
local M = {
  __debug_write = nil,
  __id_cnt = 0,
  __is_drawing = false,
  __is_tmux = false,
  __placements = {},
  __redraw_autocmds = {},
  __redraw_timer = nil,
}

---@param ... any
function M:load(...)
  -- Check if tmux exists, and if so configure it for passthrough of our images
  if vim.env['TMUX'] ~= nil then
    local res = vim.system({ 'tmux', 'set', '-p', 'allow-passthrough', 'all' }):wait()
    assert(res.code == 0, 'failed to "set -p allow-passthrough all" for tmux')
    self.__is_tmux = true
  end

  -- If debug write function provided, we set it to use globally
  for _, arg in ipairs({ ... }) do
    if type(arg) == 'table' then
      ---@type function
      local debug_write = arg.debug_write
      if type(debug_write) == 'function' then
        self.__debug_write = debug_write
      end
    end
  end

  -- Start the engine that will redraw images on a schedule
  self.__redraw_timer = assert(vim.uv.new_timer())
  self.__redraw_timer:start(REDRAW_DELAY_MS, REDRAW_DELAY_MS, vim.schedule_wrap(function()
    self:__redraw()
  end))

  -- For these autocommands, we only need to redraw the images as the images themselves
  -- should not have moved from their position
  table.insert(
    self.__redraw_autocmds,
    vim.api.nvim_create_autocmd({
      'BufEnter', 'BufWritePost',
      'CursorMoved', 'CursorMovedI',
      'TextChanged', 'TextChangedI',
      'VimResized', 'VimResume',
      'WinEnter', 'WinNew',
    }, {
      callback = function()
        for _, placement in pairs(self.__placements) do
          placement.redraw = true
        end
      end,
    })
  )

  -- For these autocommands, we need to both clear the screen and redraw all images
  -- as the images may have moved (visually) from their positions
  table.insert(
    self.__redraw_autocmds,
    vim.api.nvim_create_autocmd({ 'WinScrolled' }, {
      callback = function()
        for _, placement in pairs(self.__placements) do
          placement.clear = true
          placement.redraw = true
        end
      end,
    })
  )
end

function M:unload()
  for _, id in ipairs(self.__redraw_autocmds) do
    vim.api.nvim_del_autocmd(id)
  end

  if self.__redraw_timer then
    self.__redraw_timer:stop()
  end

  self.__debug_write = nil
  self.__is_drawing = false
  self.__is_tmux = false
  self.__placements = {}
  self.__redraw_autocmds = {}
  self.__redraw_timer = nil
end

---@param img vim.ui.Image
---@param opts? vim.ui.img.Opts|{remote?:boolean}
---@return integer
function M:show(img, opts)
  opts = opts or {}
  local id = self:__next_id()

  -- Register the new iterm2 placement and mark it for being drawn
  self.__placements[id] = {
    img = img,
    opts = opts,
    clear = false,
    redraw = true,
  }

  return id
end

---@param ids integer[]
function M:hide(ids)
  -- For all specified iterm2 placements to be hidden, we just
  -- remove them from our list since they'll be cleared anyway
  for _, id in ipairs(ids) do
    self.__placements[id] = nil
  end

  -- For all remaining iterm2 placements, we need to redraw them
  -- after the screen is cleared
  for _, placement in pairs(self.__placements) do
    placement.clear = true
    placement.redraw = true
  end
end

---@private
---@return integer
function M:__next_id()
  self.__id_cnt = self.__id_cnt + 1
  return self.__id_cnt
end

---@private
---@return integer
function M:__get_redraw_cnt()
  local cnt = 0
  for _, placement in pairs(self.__placements) do
    if placement.redraw then
      cnt = cnt + 1
    end
  end
  return cnt
end

---@private
---Redraws all images managed by iterm2 provider.
function M:__redraw()
  if self.__is_drawing then
    return
  end

  -- Get how much we need to redraw, and exit early
  -- if there is nothing to redraw at all
  local redraw_cnt = self:__get_redraw_cnt()
  if redraw_cnt == 0 then
    return
  end

  -- At this point, we can be considered drawing
  self.__is_drawing = true

  local utils = require('vim.ui.img.utils')
  local writer = utils.new_batch_writer({
    use_chan_send = true,
    map = function(s)
      if self.__is_tmux then
        s = utils.codes.escape_tmux_passthrough(s)
      end
      return s
    end,
    write = self.__debug_write,
  })

  -- Save the current state of termsync before we force it off in order
  -- to manually leverage synchronized mode to combine neovim rendering
  -- with our image rendering for a smooth experience
  ---@type boolean
  local old_termsync = vim.o.termsync
  local function restore_state()
    writer.write_fast(utils.codes.SYNC_MODE_DISABLE)
    vim.o.termsync = old_termsync
    self.__is_drawing = false
  end

  ---@type boolean, string|nil
  local ok, err = pcall(function()
    -- Disable termsync and manually start sync mode
    vim.o.termsync = false
    writer.write_fast(utils.codes.SYNC_MODE_ENABLE)

    -- Hide the cursor and save where it is to be restored
    writer.write(
      utils.codes.CURSOR_HIDE,
      utils.codes.CURSOR_SAVE
    )

    local need_clear = false
    local function mark_redraw_done()
      redraw_cnt = redraw_cnt - 1

      if redraw_cnt <= 0 then
        writer.write(
          utils.codes.CURSOR_RESTORE,
          utils.codes.CURSOR_SHOW
        )

        -- Clear the screen of all iterm2 images only if needed
        if need_clear then
          vim.cmd.mode()
        end

        -- Schedule the output with enough time for the screen clear to finish
        vim.defer_fn(function()
          writer.flush()
          restore_state()
        end, REDRAW_DELAY_MS)
      end
    end

    for _, placement in pairs(self.__placements) do
      -- Check if we need to clear the screen for this placement, which
      -- should only be the case if it's both flagged for clearing and redrawing
      need_clear = need_clear or (placement.clear and placement.redraw)
      placement.clear = false

      -- Now handle the actual scheduling of a redraw, which may be async if
      -- we have not loaded the image's data before now
      if placement.redraw then
        placement.redraw = false

        ---@param filename string
        ---@param bytes string
        ---@param opts vim.ui.img.Opts
        local function do_draw(filename, bytes, opts)
          local name = vim.base64.encode(vim.fn.fnamemodify(filename, ':t:r'))
          local contents = vim.base64.encode(bytes)
          local args = {
            string.format('name=%s', name),
            string.format('size=%s', string.len(bytes)),
            'preserveAspectRatio=0',
            'inline=1',
          }

          if opts.size then
            table.insert(args, string.format(
              'width=%s' .. (opts.size.unit == 'pixel' and 'px' or ''),
              opts.size.width
            ))
            table.insert(args, string.format(
              'height=%s' .. (opts.size.unit == 'pixel' and 'px' or ''),
              opts.size.height
            ))
          end

          local args = table.concat(args, ';')
          local pos = opts:position():to_cells()
          writer.write(utils.codes.move_cursor({ col = pos.x, row = pos.y }))

          if self.__is_tmux then
            writer.write_format('\027]1337;MultipartFile=%s\007', args)

            local i = 1
            while i < string.len(contents) do
              writer.write_format(
                '\027]1337;FilePart=%s\007',
                string.sub(contents, i, i + MAX_CONTENTS_SIZE - 1)
              )
              i = i + MAX_CONTENTS_SIZE
            end

            writer.write('\027]1337;FileEnd\007')
          else
            writer.write_format('\027]1337;File=%s:%s\007', args, contents)
          end

          mark_redraw_done()
        end

        local img = placement.img
        if not img.bytes then
          img:reload(function(err)
            if err then
              vim.notify('failed to render image: ' .. err, vim.log.levels.WARN)
            else
              do_draw(img.filename, img.bytes, placement.opts)
            end
          end)
        else
          do_draw(img.filename, img.bytes, placement.opts)
        end
      end
    end
  end)

  if not ok then
    vim.notify(err or 'iterm2 redraw unknown error', vim.log.levels.WARN)
    restore_state()
  end
end

return require('vim.ui.img.providers').new({
  on_load = function(_, ...)
    return M:load(...)
  end,
  on_show = function(_, img, opts)
    return M:show(img, opts)
  end,
  on_hide = function(_, ids)
    return M:hide(ids)
  end,
  on_unload = function()
    return M:unload()
  end,
})
