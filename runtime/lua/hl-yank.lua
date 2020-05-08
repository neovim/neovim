local api = vim.api
local namespace = api.nvim_create_namespace('hlyank')

--- Get table of lines with start, end columns for given marks
---
--- TODO: edge case if regtype==b where block ends at end of line
-- @param mark1 mark of beginning of range
-- @param mark2 mark of end of range
-- @param regtype type of selection that is yanked (:help setreg)
-- @param boolean indicating whether the selection is end-inclusive
local function marks_to_region(mark1, mark2, regtype, inclusive)
    local pos1 = vim.fn.getpos(mark1)
    local buf1, lin1, col1, off1 = pos1[1], pos1[2] - 1, pos1[3] - 1, pos1[4]
    local pos2 = vim.fn.getpos(mark2)
    local buf2, lin2, col2, off2 = pos2[1], pos2[2] - 1, pos2[3] - (inclusive and 0 or 1), pos2[4]
    local region = {}
    for l = lin1, lin2 do
        local c1 = (l == lin1 or regtype:byte() == 22) and (col1 + off1) or 0
        local c2 = (l == lin2 or regtype:byte() == 22) and (col2 + off2) or -1
        table.insert(region,l,{c1,c2})
    end
    return region
end

--- Defers calling `fn` until `timeout` ms passes.
---
--- Use to do a one-shot timer that calls `fn`
--@param fn Callback to call once `timeout` expires
--@param timeout Number of milliseconds to wait before calling `fn`
local function schedule_fn(fn, timeout)
    vim.validate { fn = { fn, 'f', true}; }
    local timer = vim.loop.new_timer()
    timer:start(timeout, 0, vim.schedule_wrap(function()
        timer:stop()
        timer:close()

        fn()
    end))

    return timer
end

--- Highlight the yanked region
--
--- use from init.vim via
---   au TextYankPost * lua require'hl_yank'(vim.v.event, 'IncSearch', 500)
-- @param event event structure
-- @param higroup highlight group for yanked region
-- @param timeout time in ms before highlight is cleared
return function(event, higroup, timeout)
    if event.operator ~= 'y' or event.regtype == '' then return end
    local event = event or vim.v.event
    local higroup = higroup or 'IncSearch'
    local timeout = timeout or 500

    local bufnr = api.nvim_get_current_buf()
    api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

    for linenr, cols in pairs(marks_to_region("'[", "']", event.regtype, event.inclusive)) do
        api.nvim_buf_add_highlight(bufnr, namespace, higroup, linenr, cols[1], cols[2])
    end

    schedule_fn(
        function() api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1) end,
        timeout
    )
end
