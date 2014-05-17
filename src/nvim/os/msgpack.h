#ifndef NVIM_OS_MSGPACK_H
#define NVIM_OS_MSGPACK_H

// XXX msgpack.h includes some inline function definitions which means that any 
// *.c file including directly or indirectly msgpack.h will add declarations 
// from that file.
#ifdef INCLUDE_GENERATED_DECLARATIONS
# include <msgpack.h>
#endif

#endif  // NVIM_OS_MSGPACK_H
