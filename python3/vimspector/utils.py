# vimspector - A multi-language debugging system for Vim
# Copyright 2018 Ben Jackson
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


import logging
import os
import contextlib
import vim
import json
import string

_log_handler = logging.FileHandler( os.path.expanduser( '~/.vimspector.log' ) )
_log_handler.setFormatter(
    logging.Formatter( '%(asctime)s - %(levelname)s - %(message)s' ) )


def SetUpLogging( logger ):
  logger.setLevel( logging.DEBUG )
  if _log_handler not in logger.handlers:
      logger.addHandler( _log_handler )


def SetUpScratchBuffer( buf, name ):
  buf.options[ 'buftype' ] = 'nofile'
  buf.options[ 'swapfile' ] = False
  buf.options[ 'modifiable' ] = False
  buf.options[ 'modified' ] = False
  buf.options[ 'readonly' ] = True
  buf.options[ 'buflisted' ] = False
  buf.options[ 'bufhidden' ] = 'wipe'
  buf.name = name


def SetUpHiddenBuffer( buf, name ):
  buf.options[ 'buftype' ] = 'nofile'
  buf.options[ 'swapfile' ] = False
  buf.options[ 'modifiable' ] = False
  buf.options[ 'modified' ] = False
  buf.options[ 'readonly' ] = True
  buf.options[ 'buflisted' ] = False
  buf.options[ 'bufhidden' ] = 'hide'
  buf.name = name

def SetUpPromptBuffer( buf, name, prompt, callback, hidden=False ):
  # This feature is _super_ new, so only enable when available
  if not int( vim.eval( "exists( '*prompt_setprompt' )" ) ):
    return SetUpScratchBuffer( buf, name )

  buf.options[ 'buftype' ] = 'prompt'
  buf.options[ 'swapfile' ] = False
  buf.options[ 'modifiable' ] = True
  buf.options[ 'modified' ] = False
  buf.options[ 'readonly' ] = False
  buf.options[ 'buflisted' ] = False
  buf.options[ 'bufhidden' ] = 'wipe' if not hidden else 'hide'
  buf.name = name

  vim.eval( "prompt_setprompt( {0}, '{1}' )".format( buf.number,
                                                     Escape( prompt ) ) )
  vim.eval( "prompt_setcallback( {0}, function( '{1}' ) )".format(
    buf.number,
    Escape( callback ) ) )



@contextlib.contextmanager
def ModifiableScratchBuffer( buf ):
  if buf.options[ 'modifiable' ]:
    yield
    return

  buf.options[ 'modifiable' ] = True
  buf.options[ 'readonly' ] = False
  try:
    yield
  finally:
    buf.options[ 'modifiable' ] = False
    buf.options[ 'readonly' ] = True


@contextlib.contextmanager
def RestoreCursorPosition():
  current_pos = vim.current.window.cursor
  try:
    yield
  finally:
    vim.current.window.cursor = (
      min( current_pos[ 0 ], len( vim.current.buffer ) ),
      current_pos[ 1 ] )


@contextlib.contextmanager
def RestoreCurrentWindow():
  # TODO: Don't trigger autoccommands when shifting windows
  old_window = vim.current.window
  try:
    yield
  finally:
    vim.current.window = old_window


@contextlib.contextmanager
def RestoreCurrentBuffer( window ):
  # TODO: Don't trigger autoccommands when shifting buffers
  old_buffer = window.buffer
  try:
    yield
  finally:
    with RestoreCurrentWindow():
      vim.current.window = window
      vim.current.buffer = old_buffer


@contextlib.contextmanager
def TemporaryVimOptions( opts ):
  old_value = {}
  try:
    for option, value in opts.items():
      old_value[ option ] = vim.options[ option ]
      vim.options[ option ] = value

    yield
  finally:
    for option, value in old_value.items():
      vim.options[ option ] = value


@contextlib.contextmanager
def TemporaryVimOption( opt, value ):
  old_value = vim.options[ opt ]
  vim.options[ opt ] = value
  try:
    yield
  finally:
    vim.options[ opt ] = old_value


def PathToConfigFile( file_name ):
  p = os.getcwd()
  while True:
    candidate = os.path.join( p, file_name )
    if os.path.exists( candidate ):
      return candidate

    parent = os.path.dirname( p )
    if parent == p:
      return None
    p = parent


def Escape( msg ):
  return msg.replace( "'", "''" )


def UserMessage( msg, persist=False ):
  vim.command( 'redraw' )
  cmd = 'echom' if persist else 'echo'
  for line in msg.split( '\n' ):
    vim.command( "{0} '{1}'".format( cmd, Escape( line ) ) )


@contextlib.contextmanager
def InputSave():
  vim.eval( 'inputsave()' )
  try:
    yield
  except:
    vim.eval( 'inputrestore()' )


def SelectFromList( prompt, options ):
  with InputSave():
    display_options = [ prompt ]
    display_options.extend( [ '{0}: {1}'.format( i + 1, v )
                              for i, v in enumerate( options ) ] )
    try:
      selection = int( vim.eval(
        'inputlist( ' + json.dumps( display_options ) + ' )' ) ) - 1
      if selection < 0 or selection >= len( options ):
        return None
      return options[ selection ]
    except KeyboardInterrupt:
      return None


def AskForInput( prompt ):
  with InputSave():
    return vim.eval( "input( '{0}' )".format( Escape( prompt ) ) )


def AppendToBuffer( buf, line_or_lines ):
  # After clearing the buffer (using buf[:] = None) there is always a single
  # empty line in the buffer object and no "is empty" method.
  if len( buf ) > 1 or buf[ 0 ]:
    line = len( buf ) + 1
    buf.append( line_or_lines )
  elif isinstance( line_or_lines, str ):
    line = 1
    buf[-1] = line_or_lines
  else:
    line = 1
    buf[:] = line_or_lines

  # Return the first Vim line number (1-based) that we just set.
  return line


def ClearBuffer( buf ):
  buf[:] = None


def IsCurrent( window, buf ):
  return vim.current.window == window and vim.current.window.buffer == buf


def ExpandReferencesInDict( obj, mapping, **kwargs ):
  def expand_refs( s ):
    s = string.Template( s ).safe_substitute( mapping, **kwargs )
    s = os.path.expanduser( s )
    s = os.path.expandvars( s )
    return s

  for k in obj.keys():
    if isinstance( obj[ k ], dict ):
      ExpandReferencesInDict( obj[ k ], mapping, **kwargs )
    elif isinstance( obj[ k ], list ):
      for i, _ in enumerate( obj[ k ] ):
        obj[ k ][ i ] = expand_refs( obj[ k ][ i ] )
    elif isinstance( obj[ k ], str ):
      obj[ k ] = expand_refs( obj[ k ] )
