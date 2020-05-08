local api = vim.api
local namespace = api.nvim_create_namespace('hlyank')

-- highlight the yanked region with highlight group higroup for timeout ms 
-- use from init.vim via
--   au TextYankPost * lua require'hl_yank'(vim.v.event, 'IncSearch', 500)
-- TODO: edge case if end of block is at end of line, left of starting col
return function(event, higroup, timeout)
    if event.operator ~= 'y' or event.regtype == '' then return end
    local event = event or vim.v.event
    local higroup = higroup or 'IncSearch'
    local timeout = timeout or 500

    local bufnr = api.nvim_get_current_buf()
    api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

    local pos1 = vim.fn.getpos("'[")
    local lin1, col1, off1 = pos1[2] - 1, pos1[3] - 1, pos1[4]
    local pos2 = vim.fn.getpos("']")
    local lin2, col2, off2 = pos2[2] - 1, pos2[3] - (event.inclusive and 0 or 1), pos2[4]
    for l = lin1, lin2 do
        local c1 = (l == lin1 or event.regtype:byte() == 22) and (col1 + off1) or 0
        local c2 = (l == lin2 or event.regtype:byte() == 22) and (col2 + off2) or -1
        api.nvim_buf_add_highlight(bufnr, namespace, higroup, l, c1, c2)
    end

    vim.loop.new_timer():start(timeout, 0, vim.schedule_wrap(function() 
        api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1) 
        timer:stop(); timer:close()
    end))
end
