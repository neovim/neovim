#!/usr/bin/env python

try:
  import urllib.request as urllib2
except ImportError:
  import urllib2

import contextlib
import os
import collections
import platform
import string
import zipfile
import shutil
import subprocess
import traceback
import tarfile
import hashlib

GADGETS = {
  'vscode-cpptools': {
    'download': {
      'url': ( 'https://github.com/Microsoft/vscode-cpptools/releases/download/'
               '${version}/${file_name}' ),
    },
    'all': {
      'version': '0.21.0',
    },
    'linux': {
      'file_name': 'cpptools-linux.vsix',
      'checksum': None,
    },
    'macos': {
      'file_name': 'cpptools-osx.vsix',
      'checksum': '4c149df241f8a548f928d824565aa9bb3ccaaa426c07aac3b47db3a51ebbb1f4',
    },
    'windows': {
      'file_name': 'cpptools-win32.vsix',
      'checksum': None,
    },
  },
  'vscode-python': {
    'download': {
      'url': ( 'https://github.com/Microsoft/vscode-python/releases/download/'
               '${version}/${file_name}' ),
    },
    'all': {
      'version': '2018.12.1',
      'file_name': 'ms-python-release.vsix',
      'checksum': '0406028b7d2fbb86ffd6cda18a36638a95111fd35b19cc198d343a2828f5c3b1',
    },
  },
  'tclpro': {
    'repo': {
      'url': 'https://github.com/puremourning/TclProDebug',
      'ref': 'master',
    },
    'do': lambda root: InstallTclProDebug( root )
  },
  'vscode-mono-debug': {
    'download': {
      'url': 'https://marketplace.visualstudio.com/_apis/public/gallery/'
             'publishers/ms-vscode/vsextensions/mono-debug/${version}/'
             'vspackage',
      'target': 'vscode-mono-debug.tar.gz',
      'format': 'tar',
    },
    'all': {
      'file_name': 'vscode-mono-debug.vsix',
      'version': '0.15.8',
      'checksum': '723eb2b621b99d65a24f215cb64b45f5fe694105613a900a03c859a62a810470',
    }
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

def InstallTclProDebug( root ):
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
    for p in [ '/System/Library/Frameworks/Tcl.framework/',
               '/usr/local/opt/tcl-tk/lib' ]:
      if os.path.exists( os.path.join( p, 'tclConfig.sh' ) ):
        configure.append( '--with-tcl=' + p )
        break


  with CurrentWorkingDir( os.path.join( root, 'lib', 'tclparser' ) ):
    subprocess.check_call( configure  )
    subprocess.check_call( [ 'make' ] )

  MakeSymlink( gadget_dir, 'tclpro', root )


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

  with contextlib.closing( urllib2.urlopen( r ) ) as u:
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
                                          ) )

  return file_path


def GetChecksumSHA254( file_path ):
  with open( file_path, 'rb' ) as existing_file:
    return hashlib.sha256( existing_file.read() ).hexdigest()


def ValidateCheckSumSHA256( file_path, checksum ):
  existing_sha256 = GetChecksumSHA254( file_path )
  return existing_sha256 == checksum


def RemoveIfExists( destination ):
  if os.path.exists( destination ) or os.path.islink( destination ):
    print( "Removing existing {}".format( destination ) )
    if os.path.isdir( destination ):
      shutil.rmtree( destination )
    else:
      os.remove( destination )


def ExtractZipTo( file_path, destination, format ):
  print( "Extracting {} to {}".format( file_path, destination ) )
  RemoveIfExists( destination )

  if format == 'zip':
    with zipfile.ZipFile( file_path ) as f:
      f.extractall( path = destination )
    return
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


def MakeSymlink( in_folder, link, pointing_to ):
  RemoveIfExists( os.path.join( in_folder, link ) )
  os.symlink( pointing_to, os.path.join( in_folder, link ) )


def CloneRepoTo( url, ref, destination ):
  RemoveIfExists( destination )
  subprocess.check_call( [ 'git', 'clone', url, destination ] )
  subprocess.check_call( [ 'git', '-C', destination, 'checkout', ref ] )

if platform.system() == 'Darwin':
  OS = 'macos'
elif platform.system() == 'Winwdows':
  OS = 'windows'
else:
  OS = 'linux'

gadget_dir = os.path.join( os.path.dirname( __file__ ), 'gadgets', OS )

for name, gadget in GADGETS.items():
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
                    format = gadget[ 'download' ].get( 'format', 'zip' )  )
    elif 'repo' in gadget:
      url = string.Template( gadget[ 'repo' ][ 'url' ] ).substitute( v )
      ref = string.Template( gadget[ 'repo' ][ 'ref' ] ).substitute( v )

      destination = os.path.join( gadget_dir, 'download', name )
      CloneRepoTo( url, ref, destination )
      root = destination

    if 'do' in gadget:
      gadget[ 'do' ]( root )
    else:
      MakeSymlink( gadget_dir, name, os.path.join( root, 'extenstion') ),

    print( "Done installing {}".format( name ) )
  except Exception as e:
    traceback.print_exc()
    print( "FAILED installing {}: {}".format( name, e ) )
