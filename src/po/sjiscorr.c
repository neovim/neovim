/*
 * Simplistic program to correct SJIS inside strings.  When a trail byte is a
 * backslash it needs to be doubled.
 * Public domain.
 */
#include <stdio.h>
#include <string.h>

	int
main(argc, argv)
	int	argc;
	char	**argv;
{
	char buffer[BUFSIZ];
	char *p;

	while (fgets(buffer, BUFSIZ, stdin) != NULL)
	{
		for (p = buffer; *p != 0; p++)
		{
			if (strncmp(p, "charset=utf-8", 13) == 0)
			{
				fputs("charset=cp932", stdout);
				p += 12;
			}
			else if (strncmp(p, "ja.po - Japanese message file", 29) == 0)
			{
				fputs("ja.sjis.po - Japanese message file for Vim (version 6.x)\n", stdout);
				fputs("# generated from ja.po, DO NOT EDIT", stdout);
				while (p[1] != '\n')
					++p;
			}
			else if (*(unsigned char *)p == 0x81 && p[1] == '_')
			{
				putchar('\\');
				++p;
			}
			else
			{
				if (*p & 0x80)
				{
					putchar(*p++);
					if (*p == '\\')
						putchar(*p);
				}
				putchar(*p);
			}
		}
	}
}
