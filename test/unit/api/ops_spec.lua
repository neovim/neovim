-- Test matrix for vim.op (Cancelable Operations)

local t = require('test.unit.testutil')
local itp = t.gen_itp(it)

local eq = t.eq
local neq = t.neq

-- Note: vim.op is provided by the built-in Lua module
-- Make sure it's available before running tests

describe('vim.op: Cancelable Operations', function()
  
  -- Lifecycle and State Transitions
  
  describe('lifecycle', function()
    itp('starts in running state', function()
      local op = vim.op.start { title = 'test' }
      eq(op:state(), 'running')
    end)
    
    itp('transitions to finished', function()
      local op = vim.op.start { title = 'test' }
      op:finish('result_value')
      eq(op:state(), 'finished')
      eq(op:result(), 'result_value')
    end)
    
    itp('transitions to failed', function()
      local op = vim.op.start { title = 'test' }
      op:fail('error_message')
      eq(op:state(), 'failed')
      eq(op:error(), 'error_message')
    end)
    
    itp('transitions to canceled', function()
      local op = vim.op.start { title = 'test' }
      op:cancel()
      eq(op:state(), 'canceled')
    end)
    
    itp('holds exactly one terminal state', function()
      local op = vim.op.start { title = 'test' }
      op:finish('done')
      
      -- Further transitions are no-ops
      op:fail('should be ignored')
      op:cancel()
      
      eq(op:state(), 'finished')
      eq(op:result(), 'done')
      eq(op:error(), nil)
    end)
  end)
  
  -- Cancellation Semantics
  
  describe('cancellation', function()
    itp('is idempotent', function()
      local op = vim.op.start { title = 'test' }
      op:cancel()
      op:cancel()
      op:cancel()
      eq(op:state(), 'canceled')
    end)
    
    itp('is detected via is_canceled()', function()
      local op = vim.op.start { title = 'test' }
      eq(op:is_canceled(), false)
      op:cancel()
      eq(op:is_canceled(), true)
    end)
    
    itp('is_canceled() remains true after terminal state', function()
      local op = vim.op.start { title = 'test' }
      op:cancel()
      -- After cancel, state is already canceled
      eq(op:state(), 'canceled')
      eq(op:is_canceled(), true)
    end)
  end)
  
  -- Progress Semantics
  
  describe('progress', function()
    itp('is optional', function()
      local op = vim.op.start { title = 'test' }
      eq(op:progress(), nil)
      op:finish('done')
      eq(op:progress(), nil)
    end)
    
    itp('clamps to [0.0, 1.0]', function()
      local op = vim.op.start { title = 'test' }
      op:progress(-0.5)
      eq(op:progress(), 0.0)
      op:progress(1.5)
      eq(op:progress(), 1.0)
      op:progress(0.5)
      eq(op:progress(), 0.5)
    end)
    
    itp('may move backward', function()
      local op = vim.op.start { title = 'test' }
      op:progress(0.8)
      op:progress(0.3)
      eq(op:progress(), 0.3)
    end)
    
    itp('does not auto-finish at 1.0', function()
      local op = vim.op.start { title = 'test' }
      op:progress(1.0)
      eq(op:state(), 'running')
      op:finish('done')
      eq(op:state(), 'finished')
    end)
    
    itp('is ignored after terminal state', function()
      local op = vim.op.start { title = 'test' }
      op:progress(0.5)
      op:finish('done')
      op:progress(0.9)
      eq(op:progress(), 0.5)  -- unchanged
    end)
  end)
  
  -- Result and Error Visibility
  
  describe('result and error', function()
    itp('result() returns nil until finished', function()
      local op = vim.op.start { title = 'test' }
      eq(op:result(), nil)
      op:finish('value')
      eq(op:result(), 'value')
    end)
    
    itp('error() returns nil unless failed', function()
      local op = vim.op.start { title = 'test' }
      eq(op:error(), nil)
      op:fail('oops')
      eq(op:error(), 'oops')
    end)
    
    itp('result() is nil when failed', function()
      local op = vim.op.start { title = 'test' }
      op:fail('error')
      eq(op:result(), nil)
    end)
    
    itp('result() is stable after finish', function()
      local op = vim.op.start { title = 'test' }
      op:finish { key = 'value' }
      local r1 = op:result()
      local r2 = op:result()
      eq(r1.key, r2.key)
    end)
  end)
  
  -- Global Registry
  
  describe('vim.op.list()', function()
    itp('returns snapshot of running ops only', function()
      local op1 = vim.op.start { title = 'op1' }
      local op2 = vim.op.start { title = 'op2' }
      local op3 = vim.op.start { title = 'op3' }
      op2:finish('done')
      
      local active = vim.op.list()
      eq(#active, 2)
      
      local titles = {}
      for _, op in ipairs(active) do
        table.insert(titles, op:title())
      end
      table.sort(titles)
      eq(titles[1], 'op1')
      eq(titles[2], 'op3')
      
      op1:cancel()
      op3:cancel()
    end)
    
    itp('returns snapshot (not live view)', function()
      local op1 = vim.op.start { title = 'op1' }
      local snapshot = vim.op.list()
      eq(#snapshot, 1)
      
      -- Create new op after snapshot
      vim.op.start { title = 'op2' }
      eq(#snapshot, 1)  -- snapshot unchanged
      eq(#vim.op.list(), 2)
      
      for _, op in ipairs(snapshot) do
        op:cancel()
      end
      for _, op in ipairs(vim.op.list()) do
        op:cancel()
      end
    end)
  end)
  
  describe('op:title()', function()
    itp('returns the title string', function()
      local op = vim.op.start { title = 'Indexing src/' }
      eq(op:title(), 'Indexing src/')
      op:cancel()
    end)
    
    itp('is stable across calls', function()
      local op = vim.op.start { title = 'work' }
      eq(op:title(), op:title())
      op:cancel()
    end)
  end)
  
  -- Pull-Based Observation Only
  
  describe('observation model', function()
    itp('provides no callbacks', function()
      local op = vim.op.start { title = 'test' }
      -- If this test compiles and passes, no callbacks exist
      -- (This is more of a design validation test)
      eq(type(op.on_finish), 'nil')
      eq(type(op.on_progress), 'nil')
      op:cancel()
    end)
    
    itp('is deterministic (no async surprises)', function()
      local op = vim.op.start { title = 'test' }
      op:progress(0.5)
      eq(op:progress(), 0.5)
      op:progress(0.5)
      eq(op:progress(), 0.5)
      -- Repeated calls return same value
      op:cancel()
    end)
  end)
  
end)
