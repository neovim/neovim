--- Highlight the yanked region
--
--- use from init.vim via
---   au TextYankPost * lua require'hl_yank'()
--- customize highlight group and timeout via
---   au TextYankPost * lua require'hl_yank'("IncSearch", 500)
-- @param higroup highlight group for yanked region
-- @param timeout time in ms before highlight is cleared
-- @param event event structure
return function(higroup, timeout, event)
    local event = event or vim.v.event
    if event.operator ~= 'y' or event.regtype == '' then return end
    local higroup = higroup or "IncSearch"
    local timeout = timeout or 500

    local bufnr = vim.api.nvim_get_current_buf()
    local yank_ns = vim.api.nvim_create_namespace('')
    vim.api.nvim_buf_clear_namespace(bufnr, yank_ns, 0, -1)

    local region = vim.marks_to_region("'[", "']", event.regtype, event.inclusive)
    for linenr, cols in pairs(region) do
        vim.api.nvim_buf_add_highlight(bufnr, yank_ns, higroup, linenr, cols[1], cols[2])
    end

    vim.schedule_fn(
        function() vim.api.nvim_buf_clear_namespace(bufnr, yank_ns, 0, -1) end,
        timeout
    )
end
