-- Older tmux versions support a max of 256 bytes, and the file part transfer
-- outside of content is 17 bytes. Max for newer tmux/iterm2 is 1,048,576 bytes.
-- We're going to stick with the newer byte maximum as the lower is very restrictive.
local ITERM2_MAX_TRANSFER_SIZE = 1048576

-- Contents sent within an escape sequence make up a portion of the total sequence.
-- This represens the size of the contents section.
local MAX_CONTENTS_SIZE = ITERM2_MAX_TRANSFER_SIZE - 17

---Mapping of placement id -> {image, options}.
---@type table<integer, {img:vim.ui.Image, opts:vim.ui.img.Opts, redraw:boolean}>
local PLACEMENTS = {}

---Indicates whether or not neovim is running within tmux.
---@type boolean
local IS_TMUX = false

local _next_id = 0
local function next_id()
  _next_id = _next_id + 1
  return _next_id
end

local redraw_placements = require('vim.ui.img.utils').debounce(function()
  -- Clear the screen
  vim.cmd.mode()

  ---@type boolean, string|nil
  local ok, err = pcall(function()
    local utils = require('vim.ui.img.utils')

    local writer = utils.new_batch_writer({ use_chan_send = true })
    utils.show_cursor(false, writer.write)
    utils.enable_sync_mode(true, writer.write)

    local redraw_cnt = 0
    local function mark_redraw_done()
      redraw_cnt = redraw_cnt - 1
      if redraw_cnt == 0 then
        utils.enable_sync_mode(false, writer.write)
        utils.show_cursor(true, writer.write)
        writer.flush()
      end
    end

    for _, placement in pairs(PLACEMENTS) do
      if placement.redraw then
        placement.redraw = false
        redraw_cnt = redraw_cnt + 1

        ---@param filename string
        ---@param bytes string
        ---@param opts vim.ui.img.Opts
        local function redraw(filename, bytes, opts)
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
          utils.move_cursor(pos.x, pos.y, writer.write)

          if IS_TMUX then
            writer(string.format('\027]1337;MultipartFile=%s\007', args))

            local i = 1
            while i < string.len(contents) do
              writer(string.format(
                '\027]1337;FilePart=%s\007',
                string.sub(contents, i, i + MAX_CONTENTS_SIZE - 1)
              ))
              i = i + MAX_CONTENTS_SIZE
            end

            writer('\027]1337;FileEnd\007')
          else
            writer(string.format('\027]1337;File=%s:%s\007', args, contents))
          end

          mark_redraw_done()
        end

        local img = placement.img
        if not img.bytes then
          img:reload(function(err)
            if err then
              vim.notify('failed to render image: ' .. err, vim.log.levels.WARN)
            else
              redraw(img.filename, img.bytes, placement.opts)
            end
          end)
        else
          redraw(img.filename, img.bytes, placement.opts)
        end
      end
    end
  end)

  if not ok then
    vim.notify(err or 'iterm2 redraw unknown error', vim.log.levels.WARN)
  end
end, { ms = 5 })

---@param _self vim.ui.img.Provider
local function load(_self)
  if vim.env['TMUX'] ~= nil then
    local res = vim.system({ 'tmux', 'set', '-p', 'allow-passthrough', 'all' }):wait()
    assert(res.code == 0, 'failed to "set -p allow-passthrough all" for tmux')
    IS_TMUX = true
  end

  -- TODO: Check if synchronous mode exists:
  -- https://gist.github.com/christianparpart/d8a62cc1ab659194337d73e399004036
  --
  -- Send ESC[?2026p
  -- Get back ESC[?2026;2$y

  -- TODO: Subscribe autocmd to
  --
  --       CursorMoved, CursorMovedI :: check if cursor on an image, and redraw that image
  --       WinScrolled :: check image lines and refresh if affected
  --       BufWritePost :: snacks.nvim calls update here. Should we??
  vim.api.nvim_create_autocmd({ 'BufWritePost', 'WinScrolled' }, {
    callback = function()
      for _, placement in pairs(PLACEMENTS) do
        placement.redraw = true
      end

      vim.schedule(redraw_placements)
    end,
  })
end

---@param _self vim.ui.img.Provider
---@param img vim.ui.Image
---@param opts? vim.ui.img.Opts|{remote?:boolean}
---@return integer
local function show(_self, img, opts)
  opts = opts or {}
  local id = next_id()

  -- Register the new iterm2 placement and mark it for being drawn
  PLACEMENTS[id] = {
    img = img,
    opts = opts,
    redraw = true,
  }

  vim.schedule(redraw_placements)

  return id
end

---@param _self vim.ui.img.Provider
---@param ids integer[]
local function hide(_self, ids)
  -- For all specified iterm2 placements to be hidden, we just
  -- remove them from our list since they'll be cleared anyway
  for _, id in ipairs(ids) do
    PLACEMENTS[id] = nil
  end

  -- For all remaining iterm2 placements, we need to redraw them
  -- after the screen is cleared
  for _, placement in pairs(PLACEMENTS) do
    placement.redraw = true
  end

  vim.schedule(redraw_placements)
end

return require('vim.ui.img.providers').new({
  on_load = load,
  on_show = show,
  on_hide = hide,
})
