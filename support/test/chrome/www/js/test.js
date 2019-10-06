$( document ).ready( function() {
  var getMessage = function() {
    var msg = 'this is ';
    msg += 'a test';
    msg += ' message';
    return msg;
  };

  alert( 'test: ' + getMessage() );
} );
