local helpers = require('test.functional.helpers')(after_each)
local eq, clear = helpers.eq, helpers.clear
local missing_provider = helpers.missing_provider
local command = helpers.command
local write_file = helpers.write_file
local eval = helpers.eval
local retry = helpers.retry

do
  clear()
  local reason = missing_provider('perl')
  if reason then
    pending(string.format("Missing perl host, or perl version is too old (%s)", reason), function() end)
    return
  end
end

before_each(function()
  clear()
end)

describe('perl host', function()
  if helpers.pending_win32(pending) then return end
  teardown(function ()
    os.remove('Xtest-perl-hello.pl')
    os.remove('Xtest-perl-hello-plugin.pl')
  end)

  it('works', function()
    local fname = 'Xtest-perl-hello.pl'
    write_file(fname, [[
      package main;
      use strict;
      use warnings;
      use Neovim::Ext;
      use Neovim::Ext::MsgPack::RPC;

      my $session = Neovim::Ext::MsgPack::RPC::socket_session($ENV{NVIM_LISTEN_ADDRESS});
      my $nvim = Neovim::Ext::from_session($session);
      $nvim->command('let g:job_out = "hello"');
      1;
    ]])
    command('let g:job_id = jobstart(["perl", "'..fname..'"])')
    retry(nil, 3000, function() eq('hello', eval('g:job_out')) end)
  end)

  it('plugin works', function()
    local fname = 'Xtest-perl-hello-plugin.pl'
    write_file(fname, [[
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

      my $session = Neovim::Ext::MsgPack::RPC::socket_session($ENV{NVIM_LISTEN_ADDRESS});
      my $nvim = Neovim::Ext::from_session($session);
      my $plugin = TestPlugin->new($nvim);
      $plugin->test_command();
      1;
    ]])
    command('let g:job_id = jobstart(["perl", "'..fname..'"])')
    retry(nil, 3000, function() eq('hello-plugin', eval('g:job_out')) end)
  end)
end)
