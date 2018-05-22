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


def SetUpLogging( logger ):
  handler = logging.FileHandler( os.path.expanduser( '~/.vimspector.log' ) )
  logger.setLevel( logging.DEBUG )
  handler.setFormatter(
    logging.Formatter( '%(asctime)s - %(levelname)s - %(message)s' ) )
  logger.addHandler( handler )


def SetUpScratchBuffer( buf ):
  buf.options[ 'buftype' ] = 'nofile'
  buf.options[ 'swapfile' ] = False
  buf.options[ 'modifiable' ] = False
  buf.options[ 'modified' ] = False
  buf.options[ 'readonly' ] = True
  buf.options[ 'buflisted' ] = False
  buf.options[ 'bufhidden' ] = 'wipe'


@contextlib.contextmanager
def ModifiableScratchBuffer( buf ):
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
    vim.current.window.cursor = current_pos


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


def SelectFromList( prompt, options ):
  vim.eval( 'inputsave()' )
  display_options = [ prompt ]
  display_options.extend( [ '{0}: {1}'.format( i + 1, v )
                            for i, v in enumerate( options ) ] )
  try:
    selection = int( vim.eval(
      'inputlist( ' + json.dumps( display_options ) + ' )' ) ) - 1
    if selection < 0 or selection >= len( options ):
      return None
    return options[ selection ]
  finally:
    vim.eval( 'inputrestore()' )
