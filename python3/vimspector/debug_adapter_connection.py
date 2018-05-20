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
import json
import vim

_logger = logging.getLogger( __name__ )


class DebugAdapterConnection( object ):
  def __init__( self, handler, send_func ):
    self._Write = send_func
    self._SetState( 'READ_HEADER' )
    self._buffer = bytes()
    self._handler = handler
    self._next_message_id = 0
    self._outstanding_requests = dict()

  def DoRequest( self, handler, msg ):
    this_id = self._next_message_id
    self._next_message_id += 1

    msg[ 'seq' ] = this_id
    msg[ 'type' ] = 'request'

    self._outstanding_requests[ this_id ] = handler
    self._SendMessage( msg )

  def OnData( self, data ):
    data = bytes( data, 'utf-8' )
    _logger.debug( 'Received ({0}/{1}): {2},'.format( type( data ),
                                                      len( data ),
                                                      data ) )

    self._buffer += data

    while True:
      if self._state == 'READ_HEADER':
        data = self._ReadHeaders()

      if self._state == 'READ_BODY':
        self._ReadBody()
      else:
        break

      if self._state != 'READ_HEADER':
        # We ran out of data whilst reading the body. Await more data.
        break

  def _SetState( self, state ):
    self._state = state
    if state == 'READ_HEADER':
      self._headers = {}

  def _SendMessage( self, msg ):
    msg = json.dumps( msg )
    data = 'Content-Length: {0}\r\n\r\n{1}'.format( len( msg ), msg )

    _logger.debug( 'Sending: {0}'.format( data ) )
    self._Write( data )

  def _ReadHeaders( self ):
    headers = self._buffer.split( bytes( '\r\n\r\n', 'utf-8' ), 1 )

    if len( headers ) > 1:
      for header_line in headers[ 0 ].split( bytes( '\r\n', 'utf-8' ) ):
        if header_line.strip():
          key, value = str( header_line, 'utf-8' ).split( ':', 1 )
          self._headers[ key ] = value

      # Chomp (+4 for the 2 newlines which were the separator)
      # self._buffer = self._buffer[ len( headers[ 0 ] ) + 4 : ]
      self._buffer = headers[ 1 ]
      self._SetState( 'READ_BODY' )
      return

    # otherwise waiting for more data

  def _ReadBody( self ):
    content_length = int( self._headers[ 'Content-Length' ] )

    if len( self._buffer ) < content_length:
      # Need more data
      assert self._state == 'READ_BODY'
      return

    payload = str( self._buffer[ : content_length  ], 'utf-8' )
    self._buffer = self._buffer[ content_length : ]

    message = json.loads( payload )

    _logger.debug( 'Message received: {0}'.format( message ) )

    self._OnMessageReceived( message )

    self._SetState( 'READ_HEADER' )

  def _OnMessageReceived( self, message ):
    if message[ 'type' ] == 'response':
      handler = self._outstanding_requests.pop( message[ 'request_seq' ] )

      if message[ 'success' ]:
        if handler:
          handler( message )
      else:
        _logger.error( 'Request failed: {0}'.format( message[ 'message' ] ) )
        vim.command( "echom 'Request failed: {0}'".format(
          message[ 'message' ] ) )

    elif message[ 'type' ] == 'event':
      method = 'OnEvent_' + message[ 'event' ]
      if method in dir( self._handler ) and getattr( self._handler, method ):
        getattr( self._handler, method )( message )
