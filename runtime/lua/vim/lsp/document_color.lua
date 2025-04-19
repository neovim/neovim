local api = vim.api
local lsp = vim.lsp
local util = lsp.util
local ms = lsp.protocol.Methods

local document_color_ns = api.nvim_create_namespace('nvim.lsp.document_color')
local document_color_augroup = api.nvim_create_augroup('nvim.lsp.document_color', {})

local M = {}

--- @alias vim.lsp.document_color.HighlightInfo { hex_code: string, hl_group?: string, range: Range4 }

--- @class (private) vim.lsp.document_color.GlobalState
--- @field enabled boolean
local global_state = { enabled = false }

--- @class (private) vim.lsp.document_color.BufState : vim.lsp.document_color.GlobalState
--- @field buf_version? integer Buffer version for which the color ranges correspond to.
--- @field applied_version? integer Last buffer version for which we applied color ranges.
--- @field hl_infos? table<integer, vim.lsp.document_color.HighlightInfo[]> client_id -> processed color highlights

--- @type table<integer, vim.lsp.document_color.BufState>
local bufstates = vim.defaulttable(function(_)
  return setmetatable({}, {
    __index = global_state,
    __newindex = function(state, key, value)
      if global_state[key] == value then
        rawset(state, key, nil)
      else
        rawset(state, key, value)
      end
    end,
  })
end)

--- @inlinedoc
--- @class vim.lsp.document_color.enable.Opts
---
--- Highlight style. It can be one of the pre-defined styles or a function that receives the buffer handle,
--- the range (start line, start col, end line, end col) and the resolved hex color.
--- Defaults to 'background'.
--- @field style? 'foreground'|'background'|'virtual'|fun(bufnr: integer, range: Range4, hex_code: string)

-- Default options.
--- @type vim.lsp.document_color.enable.Opts
M._opts = { style = 'background' }

--- @param color string
local function get_contrast_color(color)
  local r_s, g_s, b_s = color:match('^#(%x%x)(%x%x)(%x%x)$')
  local r, g, b = tonumber(r_s, 16), tonumber(g_s, 16), tonumber(b_s, 16)

  local luminance = 0.298912 * r + 0.586611 * g + 0.114478 * b
  local is_bright_color = luminance > 127
  return is_bright_color and '#000000' or '#ffffff'
end

--- Returns the hex string representing the given LSP color.
--- @param color lsp.Color
--- @return string
local function get_hex_code(color)
  -- The RGB values in lsp.Color are in the [0-1] range, but we want them to be in the [0-255] range instead.
  --- @param n number
  color = vim.tbl_map(function(n)
    return math.floor((n * 255) + 0.5)
  end, color)

  return ('#%02x%02x%02x'):format(color.red, color.green, color.blue):lower()
end

--- Cache of the highlight groups that we've already created.
--- @type table<string, true>
local color_cache = {}

--- Gets or creates the highlight group for the given LSP color information.
---
--- @param hex_code string
--- @param style 'foreground'|'background'|'virtual'
--- @return string
local function get_hl_group(hex_code, style)
  local hl_name = ('LspDocumentColor_%s_%s'):format(hex_code:sub(2), style)

  if not color_cache[hl_name] then
    if style == 'foreground' or style == 'virtual' then
      api.nvim_set_hl(0, hl_name, { fg = hex_code })
    elseif style == 'background' then
      api.nvim_set_hl(0, hl_name, { bg = hex_code, fg = get_contrast_color(hex_code) })
    end

    color_cache[hl_name] = true
  end

  return hl_name
end

--- @param bufnr integer
local function buf_clear(bufnr)
  local bufstate = bufstates[bufnr]
  local client_ids = vim.tbl_keys((bufstate or {}).hl_infos) --- @type integer[]

  for _, id in ipairs(client_ids) do
    bufstate.hl_infos[id] = {}
  end

  api.nvim_buf_clear_namespace(bufnr, document_color_ns, 0, -1)
  api.nvim__redraw({ buf = bufnr, valid = true, flush = false })
end

--- @param bufnr integer
--- @param opts? vim.lsp.util._refresh.Opts
local function buf_refresh(bufnr, opts)
  opts = opts or {}
  opts.bufnr = bufnr

  util._refresh(ms.textDocument_documentColor, opts)
end

--- @param bufnr integer
local function buf_disable(bufnr)
  buf_clear(bufnr)

  bufstates[bufnr] = nil
  bufstates[bufnr].enabled = false
end

--- @param bufnr integer
local function buf_enable(bufnr)
  bufstates[bufnr] = nil
  bufstates[bufnr].enabled = true

  api.nvim_create_autocmd('LspNotify', {
    buffer = bufnr,
    group = document_color_augroup,
    callback = function(args)
      local method = args.data.method --- @type string

      if
        (method == ms.textDocument_didChange or method == ms.textDocument_didOpen)
        and bufstates[args.buf].enabled
      then
        buf_refresh(args.buf, { client_id = args.data.client_id })
      end
    end,
  })

  api.nvim_create_autocmd('LspAttach', {
    buffer = bufnr,
    group = document_color_augroup,
    callback = function(args)
      api.nvim_buf_attach(args.buf, false, {
        on_reload = function(_, buf)
          buf_clear(buf)
          if bufstates[buf].enabled then
            buf_refresh(buf)
          end
        end,
        on_detach = function(_, buf)
          buf_disable(buf)
        end,
      })
    end,
  })

  api.nvim_create_autocmd('LspDetach', {
    buffer = bufnr,
    group = document_color_augroup,
    callback = function(args)
      local clients = lsp.get_clients({ bufnr = args.buf, method = ms.textDocument_documentColor })

      if
        not vim.iter(clients):any(function(c)
          return c.id ~= args.data.client_id
        end)
      then
        -- There are no clients left in the buffer that support document color, so turn it off.
        buf_disable(args.buf)
      end
    end,
  })

  buf_refresh(bufnr)
end

--- |lsp-handler| for the `textDocument/documentColor` method.
---
--- @param err? lsp.ResponseError
--- @param result? lsp.ColorInformation[]
--- @param ctx lsp.HandlerContext
--- @nodoc
function M.on_document_color(err, result, ctx)
  if err then
    lsp.log.error('document_color', err)
    return
  end

  local bufnr = assert(ctx.bufnr)
  local bufstate = bufstates[bufnr]
  local client_id = ctx.client_id

  if
    util.buf_versions[bufnr] ~= ctx.version
    or not result
    or not api.nvim_buf_is_loaded(bufnr)
    or not bufstate.enabled
  then
    return
  end

  if not bufstate.hl_infos or not bufstate.buf_version then
    bufstate.hl_infos = {}
    bufstate.buf_version = ctx.version
  end

  local hl_infos = {}
  for _, res in ipairs(result) do
    local range = {
      res.range.start.line,
      res.range.start.character,
      res.range['end'].line,
      res.range['end'].character,
    }
    local hex_code = get_hex_code(res.color)
    local hl_info = { range = range, hex_code = hex_code }

    if type(M._opts.style) == 'string' then
      hl_info.hl_group = get_hl_group(hex_code, M._opts.style --[[@as string]])
    end

    table.insert(hl_infos, hl_info)
  end
  bufstate.hl_infos[client_id] = hl_infos

  bufstate.buf_version = ctx.version
  api.nvim__redraw({ buf = bufnr, valid = true, flush = false })
end

--- Query whether document colors are enabled in the filtered scope.
---
--- @param filter? vim.lsp.document_color.enable.Filter
--- @return boolean
function M.is_enabled(filter)
  vim.validate('filter', filter, 'table', true)

  filter = filter or {}
  local bufnr = filter.bufnr

  if bufnr == nil then
    return global_state.enabled
  else
    return bufstates[vim._resolve_bufnr(bufnr)].enabled
  end
end

--- Optional filters |kwargs|, or `nil` for all.
--- @inlinedoc
--- @class vim.lsp.document_color.enable.Filter
---
--- Buffer number, or 0 for current buffer, or nil for all.
--- @field bufnr? integer

--- Enables document highlighting from the given language client in the given buffer.
---
--- You can enable document highlighting from a supporting client as follows:
--- ```lua
--- vim.api.nvim_create_autocmd('LspAttach', {
---   callback = function(args)
---     local client = vim.lsp.get_client_by_id(args.data.client_id)
---
---     if client:supports_method('textDocument/documentColor')
---       vim.lsp.document_color.enable(true, { bufnr = args.buf })
---     end
---   end
--- })
--- ```
---
--- To "toggle", pass the inverse of `is_enabled()`:
---
--- ```lua
--- vim.lsp.document_color.enable(not vim.lsp.document_color.is_enabled())
--- ```
---
--- @param enable? boolean True to enable, false to disable. Defaults to true.
--- @param filter? vim.lsp.document_color.enable.Filter
--- @param opts? vim.lsp.document_color.enable.Opts
function M.enable(enable, filter, opts)
  vim.validate('enable', enable, 'boolean', true)
  vim.validate('filter', filter, 'table', true)
  vim.validate('opts', opts, 'table', true)

  enable = enable == nil or enable
  filter = filter or {}
  M._opts = vim.tbl_extend('keep', opts or {}, M._opts)

  if filter.bufnr == nil then
    global_state.enabled = enable
    for _, bufnr in ipairs(api.nvim_list_bufs()) do
      if api.nvim_buf_is_loaded(bufnr) then
        if enable then
          buf_enable(bufnr)
        else
          buf_disable(bufnr)
        end
      else
        bufstates[bufnr] = nil
      end
    end
  else
    local bufnr = vim._resolve_bufnr(filter.bufnr)
    if enable then
      buf_enable(bufnr)
    else
      buf_disable(bufnr)
    end
  end
end

api.nvim_set_decoration_provider(document_color_ns, {
  on_win = function(_, _, bufnr)
    local bufstate = rawget(bufstates, bufnr) --- @type vim.lsp.document_color.BufState

    if
      not bufstate
      or not bufstate.hl_infos
      or bufstate.buf_version ~= util.buf_versions[bufnr]
      or bufstate.applied_version == bufstate.buf_version
    then
      return
    end

    api.nvim_buf_clear_namespace(bufnr, document_color_ns, 0, -1)

    local style = M._opts.style

    for _, client_hls in pairs(bufstate.hl_infos) do
      for _, hl in ipairs(client_hls) do
        if type(style) == 'function' then
          style(bufnr, hl.range, hl.hex_code)
        elseif style == 'virtual' then
          api.nvim_buf_set_extmark(bufnr, document_color_ns, hl.range[1], hl.range[2], {
            virt_text = { { ' ', hl.hl_group } },
            virt_text_pos = 'inline',
          })
        else
          api.nvim_buf_set_extmark(bufnr, document_color_ns, hl.range[1], hl.range[2], {
            end_row = hl.range[3],
            end_col = hl.range[4],
            hl_group = hl.hl_group,
            strict = false,
          })
        end
      end

      bufstate.applied_version = bufstate.buf_version
    end
  end,
})

return M
