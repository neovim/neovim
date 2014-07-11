To run the maze macros with Vim:

	vim -u maze_mac maze_5.78
	press "g"

The "-u maze.mac" loads the maze macros and skips loading your .vimrc, which
may contain settings and mappings that get in the way.


The original README:

To prove that you can do anything in vi, I wrote a couple of macros that
allows vi to solve mazes. It will solve any maze produced by maze.c
that was posted to the net recently.

Just follow this recipe and SEE FOR YOURSELF.
	1. run uudecode on the file "maze.vi.macros.uu" to
		produce the file "maze.vi.macros"
	(If you can't wait to see the action, jump to step 4)
	2. compile maze.c with "cc -o maze maze.c"
	3. run maze > maze.out and input a small number (for example 10 if
		you are on a fast machine, 3-5 if slow) which
		is the size of the maze to produce
	4. edit the maze (vi maze.out)
	5. include the macros with the vi command:
		:so maze.vi.macros
	6. type the letter "g" (for "go") and watch vi solve the maze
	7. when vi solves the maze, you will see why it lies
	8. now look at maze.vi.macros and all will be revealed

Tested on a sparc, a sun and a pyramid (although maze.c will not compile
on the pyramid).

Anyone who can't get the maze.c file to compile, get a new compiler,
try maze.ansi.c which was also posted to the net.
If you can get it to compile but the maze comes out looking like a fence
and not a maze and you are using SysV or DOS replace the "27" on the
last line of maze.c by "11"
Thanks to John Tromp (tromp@piring.cwi.nl) for maze.c.
Thanks to antonyc@nntp-server.caltech.edu (Bill T. Cat) for maze.ansi.c.

Any donations should be in unmarked small denomination bills :^)=.

		   ACSnet:  gregm@otc.otca.oz.au
Greg McFarlane	     UUCP:  {uunet,mcvax}!otc.otca.oz.au!gregm
|||| OTC ||	    Snail:  OTC R&D GPO Box 7000, Sydney 2001, Australia
		    Phone:  +61 2 287 3139    Fax: +61 2 287 3299


