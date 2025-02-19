begin
  require 'neovim/ruby_provider'
rescue LoadError
  warn('Your neovim RubyGem is missing or out of date.',
       'Install the latest version using `gem install neovim`.')
end
