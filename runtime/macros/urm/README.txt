This is another proof that Vim is perfectly compatible with Vi.
The URM macro package was written by Rudolf Koenig ("Rudi")
(rudolf@koeniglich.de) for hpux-vi in August 1991.

Getting started:

type
in your shell:	 vim urm<RETURN>
in vim:		 :so urm.vim<RETURN>
in vim:		 *	(to load the registers and boot the URM-machine :-)
in vim:		 g	(for 'go') and watch the fun. Per default, 3 and 4
			are multiplied. Watch the Program counter, it is
			visible as a komma moving around.

This is a "standard URM" (Universal register machine)  interpreter. The URM
concept is used in theoretical computer science to aid in theorem proving.
Here it proves that vim is a general problem solver (if you bring enough
patience).

The interpreter begins with register 1 (not 0), without macros and more-lines
capability.  A dot marks the end of a program. (Bug: there must be a space
after the dot.)

The registers are the first few lines, beginning with a '>' .
The program is the first line after the registers.
You should always initialize the registers required by the program.

Output register:	line 2
Input registers:	line 2 to ...

Commands:
a<n>		increment register <n>
s<n>		decrement register <n>
<x>;<y>		execute command <x> and then <y>
(<x>)<n>	execute command <x> while register <n> is nonzero
. 		("dot blank")  halt the machine.

Examples:

Add register 2 to register 3:
	(a2;s3)3.
Multiply register 2 with register 3:
	(a4;a5;s2)2; ((a2;s4)4; s3; (a1;a4;s5)5; (a5;s1)1)3.

There are more (complicated) examples in the file examples.
Note, undo may take a while after a division.

