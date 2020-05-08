local api = vim.api
local namespace = api.nvim_create_namespace('hlyank')

-- get table of lines with start, end columns for given marks
-- TODO: edge case if regtype==b where block ends at end of line
local function region(mark1, mark2, regtype, inclusive)
    local pos1 = vim.fn.getpos("'[")
    local buf1, lin1, col1, off1 = pos1[1], pos1[2] - 1, pos1[3] - 1, pos1[4]
    local pos2 = vim.fn.getpos("']")
    local buf2, lin2, col2, off2 = pos2[1], pos2[2] - 1, pos2[3] - (inclusive and 0 or 1), pos2[4]
    local region = {}
    for l = lin1, lin2 do
        local c1 = (l == lin1 or regtype:byte() == 22) and (col1 + off1) or 0
        local c2 = (l == lin2 or regtype:byte() == 22) and (col2 + off2) or -1
        table.insert(region,l,{c1,c2})
    end
    return region
end

-- highlight the yanked region with highlight group higroup for timeout ms 
-- use from init.vim via
--   au TextYankPost * lua require'hl_yank'(vim.v.event, 'IncSearch', 500)
return function(event, higroup, timeout)
    if event.operator ~= 'y' or event.regtype == '' then return end
    local event = event or vim.v.event
    local higroup = higroup or 'IncSearch'
    local timeout = timeout or 500

    local bufnr = api.nvim_get_current_buf()
    api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

    for linenr, cols in pairs(region("'[", "']", event.regtype, event.inclusive)) do
        api.nvim_buf_add_highlight(bufnr, namespace, higroup, linenr, cols[1], cols[2])
    end

    local timer = vim.loop.new_timer()
    timer:start(timeout, 0, vim.schedule_wrap(function() 
        timer:stop(); timer:close()
        api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1) 
    end))
end
