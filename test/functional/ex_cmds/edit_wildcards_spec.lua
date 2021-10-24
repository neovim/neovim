local helpers = require('test.functional.helpers')(after_each)
local write_file, eq, clear = helpers.write_file, helpers.eq, helpers.clear
local redir_exec = helpers.redir_exec

describe(':edit *[.[*]]', function()
    local function cleanup()
        os.remove('dummy_f_0.txt')
        os.remove('dummy_f_1.txt')
        os.remove('dummy_f_2.txt')
        os.remove('dummy_f.txt')
        os.remove('dummy_f.v')
        os.remove('dummy_f.js')
    end
    before_each(function()
        clear()
        cleanup()
    end)
    after_each(function()
        cleanup()
    end)

    it('try to edit many files using wildcards as *.ext', function()
        write_file('dummy_f_0.txt', 'dummy 0')
        write_file('dummy_f_1.txt', 'dummy 1')
        write_file('dummy_f_2.txt', 'dummy 2')
        eq(('\nE77: Too many file names (use :next instead of :edit with wildcards)'),
        redir_exec('edit *.txt'))
    end)

    it('try to edit many files using wildcards as filename.*', function()
        write_file('dummy_f.txt', 'dummy 0')
        write_file('dummy_f.v', 'dummy 1')
        write_file('dummy_f.js', 'dummy 2')
        eq(('\nE77: Too many file names (use :next instead of :edit with wildcards)'),
            redir_exec('edit dummy_f.*'))
    end)

    it('try to edit many files using *.*', function()
        write_file('dummy_f.txt', 'dummy 0')
        write_file('dummy_f.v', 'dummy 1')
        write_file('dummy_f.js', 'dummy 2')
        eq(('\nE77: Too many file names (use :next instead of :edit with wildcards)'),
            redir_exec('edit *.*'))
    end)
end)
