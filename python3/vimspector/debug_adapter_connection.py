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

from vimspector import utils


class DebugAdapterConnection( object ):
  def __init__( self, handler, send_func ):
    self._logger = logging.getLogger( __name__ )
    utils.SetUpLogging( self._logger )

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

  def Reset( self ):
    self._Write = None
    self._handler = None

  def OnData( self, data ):
    data = bytes( data, 'utf-8' )
    # self._logger.debug( 'Received ({0}/{1}): {2},'.format( type( data ),
    #                                                   len( data ),
    #                                                   data ) )

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
    self._logger.debug( 'Sending Message: {0}'.format( msg ) )

    data = 'Content-Length: {0}\r\n\r\n{1}'.format( len( msg ), msg )
    # self._logger.debug( 'Sending: {0}'.format( data ) )
    self._Write( data )

  def _ReadHeaders( self ):
    parts = self._buffer.split( bytes( '\r\n\r\n', 'utf-8' ), 1 )

    if len( parts ) > 1:
      headers = parts[ 0 ]
      for header_line in headers.split( bytes( '\r\n', 'utf-8' ) ):
        if header_line.strip():
          key, value = str( header_line, 'utf-8' ).split( ':', 1 )
          self._headers[ key ] = value

      # Chomp (+4 for the 2 newlines which were the separator)
      # self._buffer = self._buffer[ len( headers[ 0 ] ) + 4 : ]
      self._buffer = parts[ 1 ]
      self._SetState( 'READ_BODY' )
      return

    # otherwise waiting for more data

  def _ReadBody( self ):
    try:
      content_length = int( self._headers[ 'Content-Length' ] )
    except KeyError:
      # Ug oh. We seem to have all the headers, but no Content-Length
      # Skip to reading headers. Because, what else can we do.
      self._logger.error( 'Missing Content-Length header in: {0}'.format(
        json.dumps( self._headers ) ) )
      self._buffer = bytes( '', 'utf-8' )
      self._SetState( 'READ_HEADER' )
      return

    if len( self._buffer ) < content_length:
      # Need more data
      assert self._state == 'READ_BODY'
      return

    payload = str( self._buffer[ : content_length  ], 'utf-8' )
    self._buffer = self._buffer[ content_length : ]

    message = json.loads( payload )

    self._logger.debug( 'Message received: {0}'.format( message ) )

    try:
      self._OnMessageReceived( message )
    finally:
      # Don't allow exceptions to break message reading
      self._SetState( 'READ_HEADER' )

  def _OnMessageReceived( self, message ):
    if not self._handler:
      return

    if message[ 'type' ] == 'response':
      handler = self._outstanding_requests.pop( message[ 'request_seq' ] )

      if message[ 'success' ]:
        if handler:
          handler( message )
      else:
        reason = message.get( 'message' )
        if not message:
          fmt = message.get( 'body', {} ).get( 'error', {} ).get( 'format' )
          if fmt:
            # TODO: Actually make this work
            reason = fmt
          else:
            message = 'No reason'

        self._logger.error( 'Request failed: {0}'.format( reason ) )
        utils.UserMessage( 'Request failed: {0}'.format( reason ) )
                           

    elif message[ 'type' ] == 'event':
      method = 'OnEvent_' + message[ 'event' ]
      if method in dir( self._handler ):
        getattr( self._handler, method )( message )
      else:
        utils.UserMessage( 'Unhandled event: {0}'.format( message[ 'event' ] ),
                           persist = True )
