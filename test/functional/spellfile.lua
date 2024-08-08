local stub = require('luassert.stub')

describe('Setup', function()
  after_each(function()
    package.loaded['spellfile'] = nil
  end)

  it('loads with default config', function()
    local spellfile = require('spellfile')
    assert.are.same(spellfile.config.url, 'https://ftp.nluug.nl/pub/vim/runtime/spell')
  end)

  it('loads with custom config', function()
    local spellfile = require('spellfile')
    spellfile.setup({ url = '42', encoding = 'iso-8859-1' })
    assert.are.same(spellfile.config.url, '42')
    assert.are.same(spellfile.config.encoding, 'iso-8859-1')
  end)
end)

describe('Load file', function()
  before_each(function()
    local spellfile = require('spellfile')
    spellfile.download = function() end
    spellfile.exists = function() end
  end)

  after_each(function()
    package.loaded['spellfile'] = nil
  end)

  it('adds current language to the done table', function()
    local spellfile = require('spellfile')
    spellfile.load_file('en')
    assert.are.same({ ['en.utf-8'] = true }, spellfile.done)
  end)

  it('does not retry a language', function()
    local spellfile = require('spellfile')
    spellfile.done['en.utf-8'] = true

    local notify = stub(vim, 'notify')
    spellfile.load_file('En')
    assert.stub(notify).was_called_with('Already tried this language before: en')
    assert.are.same({ ['en.utf-8'] = true }, spellfile.done)
  end)
end)

describe('Directory choices function', function()
  before_each(function()
    local spellfile = require('spellfile')
    spellfile.config.rtp = { '/tmp' }
  end)

  it('returns at least one directory', function()
    local spellfile = require('spellfile')
    vim.fn.isdirectory = function()
      return 1
    end

    local choices = spellfile.directory_choices()
    assert.is_true(#choices >= 1)
  end)
end)

describe('Parse', function()
  before_each(function()
    local spellfile = require('spellfile')
    spellfile.config.rtp = { '/tmp' }
    vim.loop.fs_stat = function(pth)
      if pth == '/tmp/spell/en.utf-8.sug' then
        return { type = 'file' }
      end
      return nil
    end
  end)

  it('returns the correct encoding', function()
    local spellfile = require('spellfile')
    local data = spellfile.parse('en')
    assert.are.same('utf-8', data.encoding)
  end)

  it('returns the correct language code', function()
    local spellfile = require('spellfile')
    local data = spellfile.parse('EN')
    assert.are.same('en', data.lang)
  end)

  it('returns the correct file name', function()
    local spellfile = require('spellfile')
    local data = spellfile.parse('en')
    assert.are.same({ 'en.utf-8.spl' }, data.files)
  end)

  it('discards variation/region keeping only the language code', function()
    local spellfile = require('spellfile')
    local data = spellfile.parse('en_US')
    assert.are.same('en', data.lang)
    assert.are.same({ 'en.utf-8.spl' }, data.files)
  end)
end)

describe('Exists function', function()
  before_each(function()
    local spellfile = require('spellfile')

    spellfile.config.rtp = { '/tmp' }
    vim.loop.fs_stat = function(pth)
      if pth == '/tmp/spell/en.utf-8.spl' then
        return { type = 'file' }
      end
      return nil
    end
  end)

  it('returns true when the spell file exists', function()
    local spellfile = require('spellfile')
    vim.loop.fs_stat = function()
      return { type = 'file' }
    end
    assert.is_true(spellfile.exists('en.utf-8.spl'))
  end)

  it('returns false when the spell file exists', function()
    local spellfile = require('spellfile')
    vim.loop.fs_stat = function()
      return nil
    end
    assert.is_false(spellfile.exists('en.utf-42.spl'))
  end)
end)

describe('Download', function()
  before_each(function()
    local spellfile = require('spellfile')
    spellfile.config.rtp = { '/tmp' }
    vim.fn.input = function()
      return 'y'
    end
  end)

  it('downloads the file using curl', function()
    local spellfile = require('spellfile')

    local notify = stub(vim, 'notify')
    local system = stub(vim.fn, 'system')
    vim.fn.executable = function(name)
      if name == 'curl' then
        return 1
      end
      return 0
    end

    local data = {
      files = { 'en.utf-8.spl' },
      lang = 'en',
      encoding = 'utf-8',
    }
    spellfile.download(data)
    assert.stub(notify).was_called_with('\nDownloading en.utf-8.spl...')
    assert
      .stub(system)
      .was_called_with('curl -fLo /tmp/spell/en.utf-8.spl https://ftp.nluug.nl/pub/vim/runtime/spell/en.utf-8.spl')
  end)

  it('downloads the file using wget', function()
    local spellfile = require('spellfile')

    local notify = stub(vim, 'notify')
    local system = stub(vim.fn, 'system')
    vim.fn.executable = function(name)
      if name == 'wget' then
        return 1
      end
      return 0
    end

    local data = {
      files = { 'en.utf-8.spl' },
      lang = 'en',
      encoding = 'utf-8',
    }
    spellfile.download(data)
    assert.stub(notify).was_called_with('\nDownloading en.utf-8.spl...')
    assert
      .stub(system)
      .was_called_with('wget -O /tmp/spell/en.utf-8.spl https://ftp.nluug.nl/pub/vim/runtime/spell/en.utf-8.spl')
  end)

  it('shows error when there is no curl or wget', function()
    local spellfile = require('spellfile')

    local notify = stub(vim, 'notify')
    local system = stub(vim.fn, 'system')
    vim.fn.executable = function(name)
      return 0
    end

    local data = {
      files = { 'en.utf-8.spl' },
      lang = 'en',
      encoding = 'utf-8',
    }
    spellfile.download(data)
    assert.stub(notify).was_called_with('No curl or wget found. Please install one of them.')
    assert.stub(system).was_not_called()
  end)

  it('asks for confirmation and cancels if user does not confirm', function()
    local spellfile = require('spellfile')

    local notify = stub(vim, 'notify')
    local system = stub(vim.fn, 'system')
    vim.fn.input = function()
      return 'n'
    end

    local data = {
      files = { 'en.utf-8.spl' },
      lang = 'en',
      encoding = 'utf-8',
    }
    spellfile.download(data)
    assert.stub(notify).was_not_called()
    assert.stub(system).was_not_called()
  end)

  it('asks for confirmation and proceeds if user confirms', function()
    local spellfile = require('spellfile')

    local notify = stub(vim, 'notify')
    local system = stub(vim.fn, 'system')
    vim.fn.executable = function(name)
      return 0
    end

    local data = {
      files = { 'en.utf-8.spl' },
      lang = 'en',
      encoding = 'utf-8',
    }
    spellfile.download(data)
    assert.stub(notify).was_called_with('No curl or wget found. Please install one of them.')
    assert.stub(system).was_not_called()
  end)
end)

describe('Choose directory', function()
  it('shows notification when there are no directories', function()
    local notify = stub(vim, 'notify')
    local spellfile = require('spellfile')
    spellfile.config.rtp = {}

    assert.is_nil(spellfile.choose_directory())
    assert.stub(notify).was_called_with('No spell directory found in the runtimepath')
  end)

  it('returns the first directory when there is only one', function()
    local spellfile = require('spellfile')
    spellfile.config.rtp = { '/tmp' }

    local choice = spellfile.choose_directory()
    assert.are.same('/tmp/spell', choice)
  end)

  it('asks for user input when there are multiple directories', function()
    local spellfile = require('spellfile')
    spellfile.config.rtp = { '/tmp/1', '/tmp2' }
    vim.fn.inputlist = function()
      return 1
    end

    assert.are.same('/tmp/1/spell', spellfile.choose_directory())
  end)

  it('returns nil when user chooses a non-existent option', function()
    local spellfile = require('spellfile')
    spellfile.config.rtp = { '/tmp/1', '/tmp2' }
    vim.fn.inputlist = function()
      return 42
    end

    assert.is_nil(spellfile.choose_directory())
  end)
end)
