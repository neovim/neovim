$( document ).ready( function() {
  var getMessage = function() {
    var msg = 'this is ';
    msg += 'a test';
    return msg;
  };

  alert( 'test: ' + getMessage() );
} );
