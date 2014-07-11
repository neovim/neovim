/* ======================================================================= */
/*  Project : VIM							   */
/*  Module  : ccfilter				    Version: 02.01.01	   */
/*  File    : ccfilter.c						   */
/*  Purpose : Filter gmake/cc output into a standardized form		   */
/* ======================================================================= */
/*	   Created On: 12-Sep-95 20:32					   */
/*  Last modification: 03-Feb-98					   */
/*  -e option added by Bernd Feige					   */
/* ======================================================================= */
/*  Copyright :								   */
/*     This source file is copyright (c) to Pablo Ariel Kohan		   */
/* ======================================================================= */
#define __CCFILTER_C__

#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define LINELENGTH 2048

/* Collector(s) */
char	       Line[LINELENGTH];
char	       Line2[LINELENGTH];
/* Components */
char	       FileName[1024];
char	       BasePath[1024];
char	       CWD[1024];
unsigned long  Row;
unsigned long  Col;
char	       Severity;
char	       Reason[LINELENGTH];

#define COMPILER_UNKNOWN    0
#define COMPILER_GCC	    1
#define COMPILER_AIX	    2
#define COMPILER_ATT	    3
#define COMPILER_IRIX	    4
#define COMPILER_SOLARIS    5
#define COMPILER_HPUX	    6

char	*COMPILER_Names[][2] =
    {
      /* Name		 Description */
      { "N/A",		""						},
      { "GCC",		"GCC compiler"					},
      { "AIX",		"AIX's C compiler"				},
      { "ATT",		"AT&T/NCR's High Performance C Compiler"	},
      { "IRIX",		"IRIX's MIPS/MIPSpro C compiler"		},
      { "SOLARIS",	"SOLARIS's SparcWorks C compiler"		},
      { "HPUX",		"HPUX's C compiler"				}
    };
#define COMPILER_QTY (sizeof(COMPILER_Names)/sizeof(COMPILER_Names[0]))

#if   defined(_GCC)
#			define COMPILER_DEFAULT COMPILER_GCC
#elif defined(_AIX)
#			define COMPILER_DEFAULT COMPILER_AIX
#elif defined(_ATT)
#			define COMPILER_DEFAULT COMPILER_ATT
#elif defined(_IRIX)
#			define COMPILER_DEFAULT COMPILER_IRIX
#elif defined(_SOLARIS)
#			define COMPILER_DEFAULT COMPILER_SOLARIS
#elif defined(_HPUX)
#			define COMPILER_DEFAULT COMPILER_HPUX
#else
#			define COMPILER_DEFAULT COMPILER_UNKNOWN
#endif

const char USAGE[] =
"ccfilter  v2.1              (c)1994-1997 by Pablo Ariel Kohan\n"
"Filter Out compiler's output, and converts it to fit VIM\n\n"
"Usage:\n"
"  ccfilter [<options>]\n"
"Where: <options> is one or more of:\n"
"  -c              Decrement column by one\n"
"  -r              Decrement row by one\n"
"  -e              Echo stdin to stderr\n"
"  -v              Verbose (Outputs also invalid lines)\n"
"  -o <COMPILER>   Treat input as <COMPILER>'s output\n"
"                  Note: COMPILER may be preceded by an _\n"
"  -h              This usage.\n";


int ShowUsage( char *szError )
{ int i;

  fprintf( stderr, USAGE );

  fprintf( stderr, "Current default <COMPILER>: %s\n",
		   COMPILER_Names[COMPILER_DEFAULT][0] );

  fprintf( stderr, "Acceptable parameters for <COMPILER> are:\n" );
  for (i=1; i < COMPILER_QTY; i++)
      fprintf( stderr, "     %-15.15s     %s\n",
		       COMPILER_Names[i][0],
		       COMPILER_Names[i][1] );
  fprintf(stderr, szError);
  return 0;
}

char *echogets(char *s, int echo) {
 char * const retval=fgets(s, LINELENGTH, stdin);
 if (echo!=0 && retval!=NULL) {
  fputs(retval, stderr);
 }
 return retval;
}

int main( int argc, char *argv[] )
{ int   rv, i, j, ok;
  int   stay;
  int   prefetch;
  char *p;
  int   dec_col = 0; /* Decrement column value by 1 */
  int   dec_row = 0; /* Decrement row    value by 1 */
  int   echo = 0;    /* Echo stdin to stderr */
  int   verbose = 0; /* Include Bad Formatted Lines */
  int   CWDlen;
  int   COMPILER = COMPILER_DEFAULT;

  getcwd( CWD, sizeof(CWD) );
  CWDlen = strlen(CWD);

  for (i=1; i<argc; i++)
    {
      if (argv[i][0] != '-')
	return ShowUsage("");
      switch ( argv[i][1] )
	{
	  case 'c':
	    dec_col = 1;
	    break;
	  case 'r':
	    dec_row = 1;
	    break;
	  case 'e':
	    echo = 1;
	    break;
	  case 'v':
	    verbose = 1;
	    break;
	  case 'o':
	      {
		if (i+1 >= argc)
		    return ShowUsage("Error: Missing parameter for -o\n");
		i++;
		COMPILER = -1;
		for (j=1; j<COMPILER_QTY; j++)
		    if (  (strcmp(argv[i], COMPILER_Names[j][0]) == 0) ||
			  ( (argv[i][0] == '_') &&
			    (strcmp(&argv[i][1], COMPILER_Names[j][0]) == 0) )	)
			COMPILER = j;
		if (COMPILER == -1)
		    return ShowUsage("Error: Invalid COMPILER specified\n");
	      }
	    break;
	  case 'h':
	    return ShowUsage("");
	  default:
	    return ShowUsage("Error: Invalid option\n");
	}
    }
  if (COMPILER == 0)
      return ShowUsage("Error: COMPILER must be specified in this system\n");

  stay	   = ( echogets(Line, echo) != NULL );
  prefetch = 0;

  while( stay )
    {
      *FileName = 0;
      Row	= 0;
      Col	= 0;
      Severity	= ' ';
      *Reason	= 0;
      ok	= 0;
      switch (COMPILER)
	{
	  case COMPILER_GCC:
	    Severity = 'e';
#ifdef GOTO_FROM_WHERE_INCLUDED
	    rv = sscanf( Line, "In file included from %[^:]:%u:",
			       FileName, &Row );
	    if ( rv == 2 )
	      {
		ok = (echogets(Reason, echo) != NULL);
	      }
	    else
#endif
	      {
		if ((rv = sscanf( Line, "%[^:]:%u: warning: %[^\n]",
				   FileName, &Row, Reason ))==3) {
		 Severity = 'w';
		} else {
		rv = sscanf( Line, "%[^:]:%u: %[^\n]",
				   FileName, &Row, Reason );
		}
		ok = ( rv == 3 );
	      }
	    Col = (dec_col ? 1 : 0 );
	    break;
	  case COMPILER_AIX:
	    rv = sscanf( Line, "\"%[^\"]\", line %u.%u: %*s (%c) %[^\n]",
			       FileName, &Row, &Col, &Severity, Reason );
	    ok = ( rv == 5 );
	    break;
	  case COMPILER_HPUX:
	    rv = sscanf( Line, "cc: \"%[^\"]\", line %u: %c%*[^:]: %[^\n]",
			       FileName, &Row, &Severity, Reason );
	    ok = ( rv == 4 );
	    Col = (dec_col ? 1 : 0 );
	    break;
	  case COMPILER_SOLARIS:
	    rv = sscanf( Line, "\"%[^\"]\", line %u: warning: %[^\n]",
			       FileName, &Row, Reason );
	    Severity = 'w';
	    ok = ( rv == 3 );
	    if ( rv != 3 )
	      {
		rv = sscanf( Line, "\"%[^\"]\", line %u: %[^\n]",
				   FileName, &Row, Reason );
		Severity = 'e';
		ok = ( rv == 3 );
	      }
	    Col = (dec_col ? 1 : 0 );
	    break;
	  case COMPILER_ATT:
	    rv	 = sscanf( Line, "%c \"%[^\"]\",L%u/C%u%*[^:]:%[^\n]",
				 &Severity, FileName, &Row, &Col, Reason );
	    ok = ( rv == 5 );

	    if (rv != 5)
	      { rv   = sscanf( Line, "%c \"%[^\"]\",L%u/C%u: %[^\n]",
				     &Severity, FileName, &Row, &Col, Reason );
		ok = ( rv == 5 );
	      }

	    if (rv != 5)
	      { rv  = sscanf( Line, "%c \"%[^\"]\",L%u: %[^\n]",
				   &Severity, FileName, &Row, Reason );
		ok = ( rv == 4 );
		Col = (dec_col ? 1 : 0 );
	      }

	    stay = (echogets(Line2, echo) != NULL);
	    while ( stay && (Line2[0] == '|') )
	      { for (p=&Line2[2]; (*p) && (isspace(*p)); p++);
		strcat( Reason, ": " );
		strcat( Reason, p );
		Line2[0] = 0;
		stay = (echogets(Line2, echo) != NULL);
	      }
	    prefetch = 1;
	    strcpy( Line, Line2 );
	    break;
	  case COMPILER_IRIX:
	    Col       = 1;
	    prefetch  = 0;
	    rv	      = 0;
	    ok	      = 0;
	    if ( !strncmp(Line, "cfe: ", 5) )
	      { p = &Line[5];
		Severity = tolower(*p);
		p = strchr( &Line[5], ':' );
		if (p == NULL)
		  { ok = 0;
		  }
		 else
		  {
		    rv = sscanf( p+2, "%[^:]: %u: %[^\n]",
				 FileName, &Row, Reason );
		    if (rv != 3)
		      rv = sscanf( p+2, "%[^,], line %u: %[^\n]",
				   FileName, &Row, Reason );
		    ok = ( rv == 3 );
		  }

		if (ok)
		  { prefetch = 1;
		    stay = (echogets(Line, echo) != NULL);
		    if (Line[0] == ' ')
		      stay = (echogets(Line2, echo) != NULL);
		    if (  (Line2[0] == ' ') &&
			  ( (Line2[1] == '-') || (Line2[1] == '^') )  )
		      { Col = strlen(Line2)-1;
			prefetch = 0;
		      }
		     else
		      { strcat( Line, "\n" );
			strcat( Line, Line2 );
		      }
		  }
	      }
	    break;
	}
      if (dec_col) Col--;
      if (dec_row) Row--;
      if (!ok)
	{
	  if ( Line[0] == 'g' )
	      p = &Line[1];
	  else
	      p = &Line[0];
	  ok = sscanf( p, "make[%*d]: Entering directory `%[^']",
		       BasePath );
	  if (verbose)
	    printf( "[%u]?%s\n", ok, Line );
	}
       else
	{
	  for (p=Reason; (*p) && (isspace(*p)); p++);
	  if ( BasePath[CWDlen] == 0 )
	      printf( "%s:%u:%u:%c:%s\n", FileName, Row, Col, Severity, p );
	  else
	    {
	      printf( "%s/%s:%u:%u:%c:%s\n", &BasePath[CWDlen+1], FileName, Row, Col, Severity, p );
	    }
	}
      if (!prefetch)
	stay = ( echogets(Line, echo) != NULL );
    }
  return 0;
}
