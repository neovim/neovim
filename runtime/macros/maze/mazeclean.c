/*
 * Cleaned-up version of the maze program.
 * Doesn't look as nice, but should work with all C compilers.
 * Sascha Wilde, October 2003
 */
#include <stdio.h>
#include <stdlib.h>

char *M, A, Z, E = 40, line[80], T[3];
int
main (C)
{
  for (M = line + E, *line = A = scanf ("%d", &C); --E; line[E] = M[E] = E)
    printf ("._");
  for (; (A -= Z = !Z) || (printf ("\n|"), A = 39, C--); Z || printf (T))
    T[Z] = Z[A - (E = A[line - Z]) && !C
	     & A == M[A]
	     | RAND_MAX/3 < rand ()
	     || !C & !Z ? line[M[E] = M[A]] = E, line[M[A] = A - Z] =
	     A, "_." : " |"];
  return 0;
}
