describe('nvim_buf_delete()', function()
  before_each(function()
    clear()
  end)
  
  it('preserves marks with wipeout=false', function()
    local bufnr = exec_lua([[
      local buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_lines(buf, 0, -1, true, {'line1', 'line2', 'line3'})
      vim.api.nvim_buf_set_mark(buf, 'a', 1, 0, {})
      return buf
    ]])
    
    exec_lua([[
      vim.api.nvim_buf_delete(..., {wipeout=false})
    ]], bufnr)
    
    local mark_exists = exec_lua([[
      local buf = vim.api.nvim_create_buf(true, false)
      local pos = vim.api.nvim_buf_get_mark(buf, 'a')
      return pos[1] > 0
    ]])
    
    assert.is_true(mark_exists)
  end)
  
  it('removes marks with default behavior (wipeout=true)', function()
    local bufnr = exec_lua([[
      local buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_lines(buf, 0, -1, true, {'line1', 'line2', 'line3'})
      vim.api.nvim_buf_set_mark(buf, 'a', 1, 0, {})
      return buf
    ]])
    
    exec_lua([[
      vim.api.nvim_buf_delete(..., {})
    ]], bufnr)
    
    local mark_exists = exec_lua([[
      local buf = vim.api.nvim_create_buf(true, false)
      local pos = vim.api.nvim_buf_get_mark(buf, 'a')
      return pos[1] > 0
    ]])
    
    assert.is_false(mark_exists)
  end)
end)
