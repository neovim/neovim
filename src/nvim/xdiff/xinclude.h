/*
 *  LibXDiff by Davide Libenzi ( File Differential Library )
 *  Copyright (C) 2003  Davide Libenzi
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, see
 *  <http://www.gnu.org/licenses/>.
 *
 *  Davide Libenzi <davidel@xmailserver.org>
 *
 */

/* defines HAVE_ATTRIBUTE_UNUSED */
#ifdef HAVE_CONFIG_H
# include "../auto/config.h"
#endif

/* Mark unused function arguments with UNUSED, so that gcc -Wunused-parameter
 * can be used to check for mistakes. */
#ifdef HAVE_ATTRIBUTE_UNUSED
# define UNUSED __attribute__((unused))
#else
# define UNUSED
#endif

#if defined(_MSC_VER)
# define inline __inline
#endif

#if !defined(XINCLUDE_H)
#define XINCLUDE_H

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#if !defined(_WIN32)
#include <unistd.h>
#endif
#include <string.h>
#include <limits.h>

#include "xmacros.h"
#include "xdiff.h"
#include "xtypes.h"
#include "xutils.h"
#include "xprepare.h"
#include "xdiffi.h"
#include "xemit.h"


#endif /* #if !defined(XINCLUDE_H) */
