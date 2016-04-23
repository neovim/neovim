local helpers = require('test.functional.helpers')(after_each)

local feed = helpers.feed
local clear = helpers.clear
local insert = helpers.insert
local execute = helpers.execute
local expect = helpers.expect

describe('text formatting', function()
  setup(clear)

  it('is working', function()
    -- The control character <C-A> (byte \x01) needs to be put in the buffer
    -- directly.  But the insert function sends the text to nvim in insert
    -- mode so it has to be escaped with <C-V>.
    insert([[
      Results of test68:
      
      
      {
          
      
      }
      
      
      {
      a  b  
      
      a    
      }
      
      
      {
      a 
      }
      
      
      {
      a b
      #a b
      }
      
      
      {
        1 a
      # 1 a
      }
      
      
      {
      
        x a
        b
       c
      
      }
      
      
      {
      # 1 a b
      }
      
      
      {
      # x
      #   a b
      }
      
      
      {
         1aa
         2bb
      }
      
      
      /* abc def ghi jkl 
       *    mno pqr stu
       */
      
      
      # 1 xxxxx
      ]])

    execute('/^{/+1')
    execute('set noai tw=2 fo=t')
    feed('gRa b<esc>')

    execute('/^{/+1')
    execute('set ai tw=2 fo=tw')
    feed('gqgqjjllab<esc>')

    execute('/^{/+1')
    execute('set tw=3 fo=t')
    feed('gqgqo<cr>')
    feed('a <C-V><C-A><esc><esc>')

    execute('/^{/+1')
    execute('set tw=2 fo=tcq1 comments=:#')
    feed('gqgqjgqgqo<cr>')
    feed('a b<cr>')
    feed('#a b<esc>')

    execute('/^{/+1')
    execute('set tw=5 fo=tcn comments=:#')
    feed('A b<esc>jA b<esc>')

    execute('/^{/+3')
    execute('set tw=5 fo=t2a si')
    feed('i  <esc>A_<esc>')

    execute('/^{/+1')
    execute('set tw=5 fo=qn comments=:#')
    feed('gwap<cr>')

    execute('/^{/+1')
    execute('set tw=5 fo=q2 comments=:#')
    feed('gwap<cr>')

    execute('/^{/+2')
    execute('set tw& fo=a')
    feed('I^^<esc><esc>')

    execute('/mno pqr/')
    execute('setl tw=20 fo=an12wcq comments=s1:/*,mb:*,ex:*/')
    feed('A vwx yz<esc>')

    execute('/^#/')
    execute('setl tw=12 fo=tqnc comments=:#')
    feed('A foobar<esc>')

    -- Assert buffer contents.
    expect([[
      Results of test68:
      
      
      {
      a
      b
      }
      
      
      {
      a  
      b  
      
      a  
      b
      }
      
      
      {
      a
      
      
      a
      
      }
      
      
      {
      a b
      #a b
      
      a b
      #a b
      }
      
      
      {
        1 a
          b
      # 1 a
      #   b
      }
      
      
      {
      
        x a
          b_
          c
      
      }
      
      
      {
      # 1 a
      #   b
      }
      
      
      {
      # x a
      #   b
      }
      
      
      { 1aa ^^2bb }
      
      
      /* abc def ghi jkl 
       *    mno pqr stu 
       *    vwx yz
       */
      
      
      # 1 xxxxx
      #   foobar
      ]])
  end)
end)
