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
import vim
import json

_logger = logging.getLogger( __name__ )


class Channel( object ):
  def __init__( self, send_func ):
    self._Write = send_func
    self._SetState( 'AWAIT_HEADER' )
    self._buffer = ''

  def _SetState( self, state ):
    self._state = state
    if state == 'AWAIT_HEADER':
      self._headers = {}

  def Write( self, data ):
    self._Write( data )

  def OnData( self, data ):
    self._buffer = self._buffer + data

    while True:
      if self._state == 'AWAIT_HEADER':
        vim.command( 'echom "reading headers"' )
        data = self._ReadHeaders()

      if self._state == 'READ_BODY':
        vim.command( 'echom "got headers"' )
        self._ReadBody()
      else:
        break

      if self._state != 'AWAIT_HEADER':
        break


  def _ReadHeaders( self ):
    vim.command( "echom 'Reading from: {0}'".format( json.dumps( str(
      self._buffer ) ) ) )
    headers = self._buffer.split( '\n\n', 1 )

    vim.command( "echom 'Headers: {0}'".format( json.dumps( headers ) ) )

    if len( headers ) > 1:
      for header_line in headers[ 0 ].split( '\n' ):
        if header_line.strip():
          key, value = header_line.split( ':', 1 )
          self._headers[ key ] = value

      # Chomp
      self._buffer = self._buffer[ len( headers[ 0 ] ) + 2 : ]
      self._SetState( 'READ_BODY' )
      return

    # otherwise waiting for more data

  def _ReadBody( self ):
    content_length = int( self._headers[ 'Content-Length' ] )

    vim.command( "echom 'Reading body of len {0} from: {1}'".format(
      content_length,
      json.dumps( str( self._buffer ) ) ) )

    if len( self._buffer ) < content_length:
      # Need more data
      return

    payload = self._buffer[ : content_length  ]
    self._buffer = self._buffer[ content_length : ] # Off by one?

    vim.command( 'echom {0}'.format( json.dumps( str( payload ) ) ) )

    # TODO Handle message

    self._SetState( 'AWAIT_HEADER' )
