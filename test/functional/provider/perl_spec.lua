local t = require('test.functional.testutil')()
local eq, clear = t.eq, t.clear
local missing_provider = t.missing_provider
local command = t.command
local write_file = t.write_file
local eval = t.eval
local retry = t.retry
local api = t.api
local insert = t.insert
local expect = t.expect
local feed = t.feed

do
  clear()
  local reason = missing_provider('perl')
  if reason then
    pending(
      string.format('Missing perl host, or perl version is too old (%s)', reason),
      function() end
    )
    return
  end
end

before_each(function()
  clear()
end)

describe('legacy perl provider', function()
  it('feature test', function()
    eq(1, eval('has("perl")'))
  end)

  it(':perl command', function()
    command('perl $vim->vars->{set_by_perl} = [100, 0];')
    eq({ 100, 0 }, eval('g:set_by_perl'))
  end)

  it(':perlfile command', function()
    local fname = 'perlfile.pl'
    write_file(fname, '$vim->command("let set_by_perlfile = 123")')
    command('perlfile perlfile.pl')
    eq(123, eval('g:set_by_perlfile'))
    os.remove(fname)
  end)

  it(':perldo command', function()
    -- :perldo 1; doesn't change $_,
    -- the buffer should not be changed
    command('normal :perldo 1;')
    eq(false, api.nvim_get_option_value('modified', {}))
    -- insert some text
    insert('abc\ndef\nghi')
    expect([[
      abc
      def
      ghi]])
    -- go to top and select and replace the first two lines
    feed('ggvj:perldo $_ = reverse ($_)."$linenr"<CR>')
    expect([[
      cba1
      fed2
      ghi]])
  end)

  it('perleval()', function()
    eq({ 1, 2, { ['key'] = 'val' } }, eval([[perleval('[1, 2, {"key" => "val"}]')]]))
  end)
end)

describe('perl provider', function()
  teardown(function()
    os.remove('Xtest-perl-hello.pl')
    os.remove('Xtest-perl-hello-plugin.pl')
  end)

  it('works', function()
    local fname = 'Xtest-perl-hello.pl'
    write_file(
      fname,
      [[
      package main;
      use strict;
      use warnings;
      use Neovim::Ext;
      use Neovim::Ext::MsgPack::RPC;

      my $session = Neovim::Ext::MsgPack::RPC::socket_session($ENV{NVIM});
      my $nvim = Neovim::Ext::from_session($session);
      $nvim->command('let g:job_out = "hello"');
      1;
    ]]
    )
    command('let g:job_id = jobstart(["perl", "' .. fname .. '"])')
    retry(nil, 3000, function()
      eq('hello', eval('g:job_out'))
    end)
  end)

  it('plugin works', function()
    local fname = 'Xtest-perl-hello-plugin.pl'
    write_file(
      fname,
      [[
      package TestPlugin;
      use strict;
      use warnings;
      use parent qw(Neovim::Ext::Plugin);

      __PACKAGE__->register;

      @{TestPlugin::commands} = ();
      @{TestPlugin::specs} = ();
      sub test_command :nvim_command('TestCommand')
      {
        my ($this) = @_;
        $this->nvim->command('let g:job_out = "hello-plugin"');
      }

      package main;
      use strict;
      use warnings;
      use Neovim::Ext;
      use Neovim::Ext::MsgPack::RPC;

      my $session = Neovim::Ext::MsgPack::RPC::socket_session($ENV{NVIM});
      my $nvim = Neovim::Ext::from_session($session);
      my $plugin = TestPlugin->new($nvim);
      $plugin->test_command();
      1;
    ]]
    )
    command('let g:job_id = jobstart(["perl", "' .. fname .. '"])')
    retry(nil, 3000, function()
      eq('hello-plugin', eval('g:job_out'))
    end)
  end)
end)
