#!/usr/bin/env python

# vimspector - A multi-language debugging system for Vim
# Copyright 2019 Ben Jackson
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

try:
  import urllib.request as urllib2
except ImportError:
  import urllib2

import argparse
import contextlib
import os
import string
import zipfile
import gzip
import shutil
import subprocess
import traceback
import tarfile
import hashlib
import sys
import json
import functools
import time

try:
  from io import BytesIO # for Python 3
except ImportError:
  from BytesIO import BytesIO

# Include vimspector source, for utils
sys.path.insert( 1, os.path.join( os.path.dirname( __file__ ),
                                  'python3' ) )

from vimspector import install

GADGETS = {
  'vscode-cpptools': {
    'language': 'c',
    'download': {
      'url': 'https://github.com/Microsoft/vscode-cpptools/releases/download/'
             '${version}/${file_name}',
    },
    'do': lambda name, root: InstallCppTools( name, root ),
    'all': {
      'version': '0.26.2',
    },
    'linux': {
      'file_name': 'cpptools-linux.vsix',
      'checksum':
        '767aed01f0c0b5eb9e9eff96aba47b576d153d2b2d9fc28e306722ea45a02ff5'
    },
    'macos': {
      'file_name': 'cpptools-osx.vsix',
      'checksum':
        '6fd52562e1e53287c0e9b94813709c6fab487c16ff3054eda6233d6c0241eb0e',
    },
    'windows': {
      'file_name': 'cpptools-win32.vsix',
      'checksum': None,
    },
    "adapters": {
      "vscode-cpptools": {
        "name": "cppdbg",
        "command": [
          "${gadgetDir}/vscode-cpptools/debugAdapters/OpenDebugAD7"
        ],
        "attach": {
          "pidProperty": "processId",
          "pidSelect": "ask"
        },
      },
    },
  },
  'vscode-python': {
    'language': 'python',
    'download': {
      'url': 'https://github.com/Microsoft/vscode-python/releases/download/'
             '${version}/${file_name}',
    },
    'all': {
      'version': '2019.11.50794',
      'file_name': 'ms-python-release.vsix',
      'checksum':
        '6a9edf9ecabed14aac424e6007858068204a3638bf3bb4f235bd6035d823acc6',
    },
    'adapters': {
      "vscode-python": {
        "name": "vscode-python",
        "command": [
          "node",
          "${gadgetDir}/vscode-python/out/client/debugger/debugAdapter/main.js",
        ],
      }
    },
  },
  'tclpro': {
    'language': 'tcl',
    'repo': {
      'url': 'https://github.com/puremourning/TclProDebug',
      'ref': 'f5c56b7067661ce84e205765060224076569ae0e', # master 26/10/2019
    },
    'do': lambda name, root: InstallTclProDebug( name, root )
  },
  'netcoredbg': {
    'language': 'csharp',
    'enabled': False,
    'download': {
      'url': 'https://github.com/Samsung/netcoredbg/releases/download/latest/'
             '${file_name}',
      'format': 'tar',
    },
    'all': {
      'version': 'master'
    },
    'macos': {
      'file_name': 'netcoredbg-osx-master.tar.gz',
      'checksum': '',
    },
    'linux': {
      'file_name': 'netcoredbg-linux-master.tar.gz',
      'checksum': '',
    },
    'do': lambda name, root: MakeSymlink( gadget_dir,
                                          name,
                                          os.path.join( root, 'netcoredbg' ) ),
    'adapters': {
      'netcoredbg': {
        "name": "netcoredbg",
        "command": [
          "${gadgetDir}/netcoredbg/netcoredbg",
          "--interpreter=vscode"
        ],
        "attach": {
          "pidProperty": "processId",
          "pidSelect": "ask"
        },
      },
    }
  },
  'vscode-mono-debug': {
    'language': 'csharp',
    'enabled': False,
    'download': {
      'url': 'https://marketplace.visualstudio.com/_apis/public/gallery/'
             'publishers/ms-vscode/vsextensions/mono-debug/${version}/'
             'vspackage',
      'target': 'vscode-mono-debug.vsix.gz',
      'format': 'zip.gz',
    },
    'all': {
      'file_name': 'vscode-mono-debug.vsix',
      'version': '0.15.8',
      'checksum':
          '723eb2b621b99d65a24f215cb64b45f5fe694105613a900a03c859a62a810470',
    },
    'adapters': {
      'vscode-mono-debug': {
        "name": "mono-debug",
        "command": [
          "mono",
          "${gadgetDir}/vscode-mono-debug/bin/Release/mono-debug.exe"
        ],
        "attach": {
          "pidSelect": "none"
        },
      },
    }
  },
  'vscode-bash-debug': {
    'language': 'bash',
    'download': {
      'url': 'https://github.com/rogalmic/vscode-bash-debug/releases/'
             'download/${version}/${file_name}',
    },
    'all': {
      'file_name': 'bash-debug-0.3.5.vsix',
      'version': 'v0.3.5',
      'checksum': '',
    }
  },
  'vscode-go': {
    'language': 'go',
    'download': {
      'url': 'https://github.com/microsoft/vscode-go/releases/download/'
             '${version}/${file_name}'
    },
    'all': {
      'version': '0.11.4',
      'file_name': 'Go-0.11.4.vsix',
      'checksum':
        'ff7d7b944da5448974cb3a0086f4a2fd48e2086742d9c013d6964283d416027e'
    },
    'adapters': {
      'vscode-go': {
        'name': 'delve',
        'command': [
          'node',
          '${gadgetDir}/vscode-go/out/src/debugAdapter/goDebug.js'
        ],
      },
    },
  },
  'vscode-node-debug2': {
    'language': 'node',
    'enabled': False,
    'repo': {
      'url': 'https://github.com/microsoft/vscode-node-debug2',
      'ref': 'v1.39.1',
    },
    'do': lambda name, root: InstallNodeDebug( name, root ),
    'adapters': {
      'vscode-node': {
        'name': 'node2',
        'type': 'node2',
        'command': [
          'node',
          '${gadgetDir}/vscode-node-debug2/out/src/nodeDebug.js'
        ]
      },
    },
  },
  'debugger-for-chrome': {
    'language': 'chrome',
    'enabled': False,
    'download': {
      'url': 'https://marketplace.visualstudio.com/_apis/public/gallery/'
             'publishers/msjsdiag/vsextensions/'
             'debugger-for-chrome/${version}/vspackage',
      'target': 'msjsdiag.debugger-for-chrome-4.12.0.vsix.gz',
      'format': 'zip.gz',
    },
    'all': {
      'version': '4.12.0',
      'file_name': 'msjsdiag.debugger-for-chrome-4.12.0.vsix',
      'checksum':
        '0df2fe96d059a002ebb0936b0003e6569e5a5c35260dc3791e1657d27d82ccf5'
    },
    'adapters': {
      'chrome': {
        'name': 'debugger-for-chrome',
        'type': 'chrome',
        'command': [
          'node',
          '${gadgetDir}/debugger-for-chrome/out/src/chromeDebug.js'
        ],
      },
    },
  },
}


@contextlib.contextmanager
def CurrentWorkingDir( d ):
  cur_d = os.getcwd()
  try:
    os.chdir( d )
    yield
  finally:
    os.chdir( cur_d )


def MakeExecutable( file_path ):
  # TODO: import stat and use them by _just_ adding the X bit.
  print( 'Making executable: {}'.format( file_path ) )
  os.chmod( file_path, 0o755 )


def InstallCppTools( name, root ):
  extension = os.path.join( root, 'extension' )

  # It's hilarious, but the execute bits aren't set in the vsix. So they
  # actually have javascript code which does this. It's just a horrible horrible
  # hack that really is not funny.
  MakeExecutable( os.path.join( extension, 'debugAdapters', 'OpenDebugAD7' ) )
  with open( os.path.join( extension, 'package.json' ) ) as f:
    package = json.load( f )
    runtime_dependencies = package[ 'runtimeDependencies' ]
    for dependency in runtime_dependencies:
      for binary in dependency.get( 'binaries' ):
        file_path = os.path.abspath( os.path.join( extension, binary ) )
        if os.path.exists( file_path ):
          MakeExecutable( os.path.join( extension, binary ) )

  MakeExtensionSymlink( name, root )


def InstallTclProDebug( name, root ):
  configure = [ './configure' ]

  if OS == 'macos':
    # Apple removed the headers from system frameworks because they are
    # determined to make life difficult. And the TCL configure scripts are super
    # old so don't know about this. So we do their job for them and try and find
    # a tclConfig.sh.
    #
    # NOTE however that in Apple's infinite wisdom, installing the "headers" in
    # the other location is actually broken because the paths in the
    # tclConfig.sh are pointing at the _old_ location. You actually do have to
    # run the package installation which puts the headers back in order to work.
    # This is why the below list is does not contain stuff from
    # /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform
    #  '/Applications/Xcode.app/Contents/Developer/Platforms'
    #    '/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System'
    #    '/Library/Frameworks/Tcl.framework',
    #  '/Applications/Xcode.app/Contents/Developer/Platforms'
    #    '/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System'
    #    '/Library/Frameworks/Tcl.framework/Versions'
    #    '/Current',
    for p in [ '/usr/local/opt/tcl-tk/lib' ]:
      if os.path.exists( os.path.join( p, 'tclConfig.sh' ) ):
        configure.append( '--with-tcl=' + p )
        break


  with CurrentWorkingDir( os.path.join( root, 'lib', 'tclparser' ) ):
    subprocess.check_call( configure )
    subprocess.check_call( [ 'make' ] )

  MakeSymlink( gadget_dir, name, root )


def InstallNodeDebug( name, root ):
  node_version = subprocess.check_output( [ 'node', '--version' ],
                                          universal_newlines=True ).strip()
  print( "Node.js version: {}".format( node_version ) )
  if list( map( int, node_version[ 1: ].split( '.' ) ) ) >= [ 12, 0, 0 ]:
    print( "Can't install vscode-debug-node2:" )
    print( "Sorry, you appear to be running node 12 or later. That's not "
           "compatible with the build system for this extension, and as far as "
           "we know, there isn't a pre-built independent package." )
    print( "My advice is to install nvm, then do:" )
    print( "  $ nvm install --lts 10" )
    print( "  $ nvm use --lts 10" )
    print( "  $ ./install_gadget.py --enable-node ..." )
    raise RuntimeError( 'Invalid node environent for node debugger' )

  with CurrentWorkingDir( root ):
    subprocess.check_call( [ 'npm', 'install' ] )
    subprocess.check_call( [ 'npm', 'run', 'build' ] )
  MakeSymlink( gadget_dir, name, root )


def WithRetry( f ):
  retries = 5
  timeout = 1 # seconds

  @functools.wraps( f )
  def wrapper( *args, **kwargs ):
    thrown = None
    for _ in range( retries ):
      try:
        return f( *args, **kwargs )
      except Exception as e:
        thrown = e
        print( "Failed - {}, will retry in {} seconds".format( e, timeout ) )
        time.sleep( timeout )
    raise thrown

  return wrapper


@WithRetry
def UrlOpen( *args, **kwargs ):
  return urllib2.urlopen( *args, **kwargs )


def DownloadFileTo( url, destination, file_name = None, checksum = None ):
  if not file_name:
    file_name = url.split( '/' )[ -1 ]

  file_path = os.path.abspath( os.path.join( destination, file_name ) )

  if not os.path.isdir( destination ):
    os.makedirs( destination )

  if os.path.exists( file_path ):
    if checksum:
      if ValidateCheckSumSHA256( file_path, checksum ):
        print( "Checksum matches for {}, using it".format( file_path ) )
        return file_path
      else:
        print( "Checksum doesn't match for {}, removing it".format(
          file_path ) )

    print( "Removing existing {}".format( file_path ) )
    os.remove( file_path )

  r = urllib2.Request( url, headers = { 'User-Agent': 'Vimspector' } )

  print( "Downloading {} to {}/{}".format( url, destination, file_name ) )

  with contextlib.closing( UrlOpen( r ) ) as u:
    with open( file_path, 'wb' ) as f:
      f.write( u.read() )

  if checksum:
    if not ValidateCheckSumSHA256( file_path, checksum ):
      raise RuntimeError(
        'Checksum for {} ({}) does not match expected {}'.format(
          file_path,
          GetChecksumSHA254( file_path ),
          checksum ) )
  else:
    print( "Checksum for {}: {}".format( file_path,
                                         GetChecksumSHA254( file_path ) ) )

  return file_path


def GetChecksumSHA254( file_path ):
  with open( file_path, 'rb' ) as existing_file:
    return hashlib.sha256( existing_file.read() ).hexdigest()


def ValidateCheckSumSHA256( file_path, checksum ):
  existing_sha256 = GetChecksumSHA254( file_path )
  return existing_sha256 == checksum


def RemoveIfExists( destination ):
  if os.path.exists( destination ) or os.path.islink( destination ):
    if os.path.islink( destination ):
      print( "Removing file {}".format( destination ) )
      os.remove( destination )
    else:
      print( "Removing dir {}".format( destination ) )
      shutil.rmtree( destination )


# Python's ZipFile module strips execute bits from files, for no good reason
# other than crappy code. Let's do it's job for it.
class ModePreservingZipFile( zipfile.ZipFile ):
  def extract( self, member, path = None, pwd = None ):
    if not isinstance( member, zipfile.ZipInfo ):
      member = self.getinfo( member )

    if path is None:
      path = os.getcwd()

    ret_val = self._extract_member( member, path, pwd )
    attr = member.external_attr >> 16
    os.chmod( ret_val, attr )
    return ret_val


def ExtractZipTo( file_path, destination, format ):
  print( "Extracting {} to {}".format( file_path, destination ) )
  RemoveIfExists( destination )

  if format == 'zip':
    with ModePreservingZipFile( file_path ) as f:
      f.extractall( path = destination )
  elif format == 'zip.gz':
    with gzip.open( file_path, 'rb' ) as f:
      file_contents = f.read()

    with ModePreservingZipFile( BytesIO( file_contents ) ) as f:
      f.extractall( path = destination )

  elif format == 'tar':
    try:
      with tarfile.open( file_path ) as f:
        f.extractall( path = destination )
    except Exception:
      # There seems to a bug in python's tarfile that means it can't read some
      # windows-generated tar files
      os.makedirs( destination )
      with CurrentWorkingDir( destination ):
        subprocess.check_call( [ 'tar', 'zxvf', file_path ] )


def MakeExtensionSymlink( name, root ):
  MakeSymlink( gadget_dir, name, os.path.join( root, 'extension' ) ),


def MakeSymlink( in_folder, link, pointing_to ):
  RemoveIfExists( os.path.join( in_folder, link ) )

  in_folder = os.path.abspath( in_folder )
  pointing_to = os.path.relpath( os.path.abspath( pointing_to ),
                                 in_folder )
  os.symlink( pointing_to, os.path.join( in_folder, link ) )


def CloneRepoTo( url, ref, destination ):
  RemoveIfExists( destination )
  subprocess.check_call( [ 'git', 'clone', url, destination ] )
  subprocess.check_call( [ 'git', '-C', destination, 'checkout', ref ] )
  subprocess.check_call( [ 'git', 'submodule', 'sync', '--recursive' ] )
  subprocess.check_call( [ 'git',
                           'submodule',
                           'update',
                           '--init',
                           '--recursive' ] )


OS = install.GetOS()
gadget_dir = install.GetGadgetDir( os.path.dirname( __file__ ), OS )

print( 'OS = ' + OS )
print( 'gadget_dir = ' + gadget_dir )

parser = argparse.ArgumentParser()
parser.add_argument( '--all',
                     action = 'store_true',
                     help = 'Enable all supported completers' )

parser.add_argument( '--force-all',
                     action = 'store_true',
                     help = 'Enable all unsupported completers' )

parser.add_argument( '--no-gadget-config',
                     action = 'store_true',
                     help = "Don't write the .gagets.json, just install" )

done_languages = set()
for name, gadget in GADGETS.items():
  lang = gadget[ 'language' ]
  if lang in done_languages:
    continue

  done_languages.add( lang )
  if not gadget.get( 'enabled', True ):
    parser.add_argument(
      '--force-enable-' + lang,
      action = 'store_true',
      help = 'Install the unsupported {} debug adapter for {} support'.format(
        name,
        lang ) )
    continue

  parser.add_argument(
    '--enable-' + lang,
    action = 'store_true',
    help = 'Install the {} debug adapter for {} support'.format(
      name,
      lang ) )

  parser.add_argument(
    '--disable-' + lang,
    action = 'store_true',
    help = "Don't install the {} debug adapter for {} support "
           '(when supplying --all)'.format( name, lang ) )

args = parser.parse_args()

if args.force_all and not args.all:
  args.all = True

failed = []
all_adapters = {}
for name, gadget in GADGETS.items():
  if not gadget.get( 'enabled', True ):
    if ( not args.force_all
         and not getattr( args, 'force_enable_' + gadget[ 'language' ] ) ):
      continue
  else:
    if not args.all and not getattr( args, 'enable_' + gadget[ 'language' ] ):
      continue
    if getattr( args, 'disable_' + gadget[ 'language' ] ):
      continue

  try:
    v = {}
    v.update( gadget.get( 'all', {} ) )
    v.update( gadget.get( OS, {} ) )

    if 'download' in gadget:
      if 'file_name' not in v:
        raise RuntimeError( "Unsupported OS {} for gadget {}".format( OS,
                                                                      name ) )

      destination = os.path.join( gadget_dir, 'download', name, v[ 'version' ] )

      url = string.Template( gadget[ 'download' ][ 'url' ] ).substitute( v )

      file_path = DownloadFileTo(
        url,
        destination,
        file_name = gadget[ 'download' ].get( 'target' ),
        checksum = v.get( 'checksum' ) )
      root = os.path.join( destination, 'root' )
      ExtractZipTo( file_path,
                    root,
                    format = gadget[ 'download' ].get( 'format', 'zip' ) )
    elif 'repo' in gadget:
      url = string.Template( gadget[ 'repo' ][ 'url' ] ).substitute( v )
      ref = string.Template( gadget[ 'repo' ][ 'ref' ] ).substitute( v )

      destination = os.path.join( gadget_dir, 'download', name )
      CloneRepoTo( url, ref, destination )
      root = destination

    if 'do' in gadget:
      gadget[ 'do' ]( name, root )
    else:
      MakeExtensionSymlink( name, root )

    all_adapters.update( gadget.get( 'adapters', {} ) )


    print( "Done installing {}".format( name ) )
  except Exception as e:
    traceback.print_exc()
    failed.append( name )
    print( "FAILED installing {}: {}".format( name, e ) )


adapter_config = json.dumps ( { 'adapters': all_adapters },
                              indent=2,
                              sort_keys=True )

if args.no_gadget_config:
  print( "" )
  print( "Would write the following gadgets: " )
  print( adapter_config )
else:
  with open( install.GetGadgetConfigFile( os.path.dirname( __file__ ) ),
             'w' ) as f:
    f.write( adapter_config )

if failed:
  raise RuntimeError( 'Failed to install gadgets: {}'.format(
    ','.join( failed ) ) )
