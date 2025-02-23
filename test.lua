vim.keymap.set("n", "<C-h>", function()
    local bufnr = vim.api.nvim_get_current_buf()
    local bufInfo = vim.fn.getbufinfo(bufnr)
    local winid = bufInfo[1].windows[1]
    local wininfo = vim.fn.getwininfo(winid)
    print(wininfo[1].lastused)
  end,
  { silent = true, noremap = true })
