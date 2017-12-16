const neovim = require('neovim');

class TestPlugin {
    setFooBar() {
        this.nvim.command('let g:foobar = "foobar"')
    }
}

neovim.Command('SetFooBar')(TestPlugin.prototype, 'setFooBar');
module.exports = neovim.Plugin(TestPlugin);
