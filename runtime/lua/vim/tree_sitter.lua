local a = vim.api

function parse_tree(tsstate, force)
  if tsstate.valid and not force then
    return tsstate.tree
  end
  tsstate.tree = tsstate.parser:parse_buf(tsstate.bufnr)
  tsstate.valid = true
  return tsstate.tree
end

local function change_cb(tsstate, ev, bufnr, tick, start_row, oldstopline, stop_row)
  local start_byte = a.nvim_buf_get_offset(bufnr,start_row)
  -- a bit messy, should we expose edited but not reparsed tree?
  -- are multiple edits safe in general?
  local root = tsstate.parser:tree():root()
  -- TODO: add proper lookup function!
  local inode = root:descendant_for_point_range(oldstopline+9000,0, oldstopline,0)
  if inode == nil then
    local stop_byte = a.nvim_buf_get_offset(bufnr,stop_row)
    tsstate.parser:edit(start_byte,stop_byte,stop_byte,start_row,0,stop_row,0,stop_row,0)
  else
    local fakeoldstoprow, fakeoldstopcol, fakebyteoldstop = inode:start()
    local fake_rows = fakeoldstoprow-oldstopline
    local fakestop = stop_row+fake_rows
    local fakebytestop = a.nvim_buf_get_offset(bufnr,fakestop)+fakeoldstopcol
    tsstate.parser:edit(start_byte,fakebyteoldstop,fakebytestop,start_row,0,fakeoldstoprow,fakeoldstopcol,fakestop,fakeoldstopcol)
  end
  tsstate.valid = false
end

function create_parser(bufnr)
  if bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end
  local ft = a.nvim_buf_get_option(bufnr, "filetype")
  local tsstate = {}
  tsstate.bufnr = bufnr
  tsstate.parser = vim.ts_parser(ft.."_parser.so", ft)
  parse_tree(tsstate)
  local function cb(ev, ...)
    return change_cb(tsstate, ev, ...)
  end
  a.nvim_buf_attach(tsstate.bufnr, false, {on_lines=cb})
  return tsstate
end

