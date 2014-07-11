/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 * X-Windows communication by Flemming Madsen
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 *
 * Client for sending commands to an '+xcmdsrv' enabled vim.
 * This is mostly a de-Vimified version of if_xcmdsrv.c in vim.
 * See that file for a protocol specification.
 *
 * You can make a test program with a Makefile like:
 *  xcmdsrv_client: xcmdsrv_client.c
 *	cc -o $@ -g -DMAIN -I/usr/X11R6/include -L/usr/X11R6/lib $< -lX11
 *
 */

#include <stdio.h>
#include <string.h>
#ifdef HAVE_SELECT
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#else
#include <sys/poll.h>
#endif
#include <X11/Intrinsic.h>
#include <X11/Xatom.h>

#define __ARGS(x) x

/* Client API */
char * sendToVim __ARGS((Display *dpy, char *name, char *cmd, int asKeys, int *code));

#ifdef MAIN
/* A sample program */
main(int argc, char **argv)
{
    char    *res;
    int	    code;

    if (argc == 4)
    {
	if ((res = sendToVim(XOpenDisplay(NULL), argv[2], argv[3],
			     argv[1][0] != 'e', &code)) != NULL)
	{
	    if (code)
		printf("Error code returned: %d\n", code);
	    puts(res);
	}
	exit(0);
    }
    else
	fprintf(stderr, "Usage: %s {k|e} <server> <command>", argv[0]);

    exit(1);
}
#endif

/*
 * Maximum size property that can be read at one time by
 * this module:
 */

#define MAX_PROP_WORDS 100000

/*
 * Forward declarations for procedures defined later in this file:
 */

static int	x_error_check __ARGS((Display *dpy, XErrorEvent *error_event));
static int	AppendPropCarefully __ARGS((Display *display,
		    Window window, Atom property, char *value, int length));
static Window	LookupName __ARGS((Display *dpy, char *name,
		    int delete, char **loose));
static int	SendInit __ARGS((Display *dpy));
static char	*SendEventProc __ARGS((Display *dpy, XEvent *eventPtr,
				      int expect, int *code));
static int	IsSerialName __ARGS((char *name));

/* Private variables */
static Atom	registryProperty = None;
static Atom	commProperty = None;
static Window	commWindow = None;
static int	got_x_error = FALSE;


/*
 * sendToVim --
 *	Send to an instance of Vim via the X display.
 *
 * Results:
 *	A string with the result or NULL. Caller must free if non-NULL
 */

    char *
sendToVim(dpy, name, cmd, asKeys, code)
    Display	*dpy;			/* Where to send. */
    char	*name;			/* Where to send. */
    char	*cmd;			/* What to send. */
    int		asKeys;			/* Interpret as keystrokes or expr ? */
    int		*code;			/* Return code. 0 => OK */
{
    Window	    w;
    Atom	    *plist;
    XErrorHandler   old_handler;
#define STATIC_SPACE 500
    char	    *property, staticSpace[STATIC_SPACE];
    int		    length;
    int		    res;
    static int	    serial = 0;	/* Running count of sent commands.
				 * Used to give each command a
				 * different serial number. */
    XEvent	    event;
    XPropertyEvent  *e = (XPropertyEvent *)&event;
    time_t	    start;
    char	    *result;
    char	    *loosename = NULL;

    if (commProperty == None && dpy != NULL)
    {
	if (SendInit(dpy) < 0)
	    return NULL;
    }

    /*
     * Bind the server name to a communication window.
     *
     * Find any survivor with a serialno attached to the name if the
     * original registrant of the wanted name is no longer present.
     *
     * Delete any lingering names from dead editors.
     */

    old_handler = XSetErrorHandler(x_error_check);
    while (TRUE)
    {
	got_x_error = FALSE;
	w = LookupName(dpy, name, 0, &loosename);
	/* Check that the window is hot */
	if (w != None)
	{
	    plist = XListProperties(dpy, w, &res);
	    XSync(dpy, False);
	    if (plist != NULL)
		XFree(plist);
	    if (got_x_error)
	    {
		LookupName(dpy, loosename ? loosename : name,
			   /*DELETE=*/TRUE, NULL);
		continue;
	    }
	}
	break;
    }
    if (w == None)
    {
	fprintf(stderr, "no registered server named %s\n", name);
	return NULL;
    }
    else if (loosename != NULL)
	name = loosename;

    /*
     * Send the command to target interpreter by appending it to the
     * comm window in the communication window.
     */

    length = strlen(name) + strlen(cmd) + 10;
    if (length <= STATIC_SPACE)
	property = staticSpace;
    else
	property = (char *) malloc((unsigned) length);

    serial++;
    sprintf(property, "%c%c%c-n %s%c-s %s",
		      0, asKeys ? 'k' : 'c', 0, name, 0, cmd);
    if (name == loosename)
	free(loosename);
    if (!asKeys)
    {
	/* Add a back reference to our comm window */
	sprintf(property + length, "%c-r %x %d", 0, (uint) commWindow, serial);
	length += strlen(property + length + 1) + 1;
    }

    res = AppendPropCarefully(dpy, w, commProperty, property, length + 1);
    if (length > STATIC_SPACE)
	free(property);
    if (res < 0)
    {
	fprintf(stderr, "Failed to send command to the destination program\n");
	return NULL;
    }

    if (asKeys) /* There is no answer for this - Keys are sent async */
	return NULL;


    /*
     * Enter a loop processing X events & pooling chars until we see the result
     */

#define SEND_MSEC_POLL 50

    time(&start);
    while ((time((time_t *) 0) - start) < 60)
    {
	/* Look out for the answer */
#ifndef HAVE_SELECT
	struct pollfd   fds;

	fds.fd = ConnectionNumber(dpy);
	fds.events = POLLIN;
	if (poll(&fds, 1, SEND_MSEC_POLL) < 0)
	    break;
#else
	fd_set	    fds;
	struct timeval  tv;

	tv.tv_sec = 0;
	tv.tv_usec =  SEND_MSEC_POLL * 1000;
	FD_ZERO(&fds);
	FD_SET(ConnectionNumber(dpy), &fds);
	if (select(ConnectionNumber(dpy) + 1, &fds, NULL, NULL, &tv) < 0)
	    break;
#endif
	while (XEventsQueued(dpy, QueuedAfterReading) > 0)
	{
	    XNextEvent(dpy, &event);
	    if (event.type == PropertyNotify && e->window == commWindow)
		if ((result = SendEventProc(dpy, &event, serial, code)) != NULL)
		    return result;
	}
    }
    return NULL;
}


/*
 * SendInit --
 *	This procedure is called to initialize the
 *	communication channels for sending commands and
 *	receiving results.
 */

    static int
SendInit(dpy)
    Display *dpy;
{
    XErrorHandler old_handler;

    /*
     * Create the window used for communication, and set up an
     * event handler for it.
     */
    old_handler = XSetErrorHandler(x_error_check);
    got_x_error = FALSE;

    commProperty = XInternAtom(dpy, "Comm", False);
    /* Change this back to "InterpRegistry" to talk to tk processes */
    registryProperty = XInternAtom(dpy, "VimRegistry", False);

    if (commWindow == None)
    {
	commWindow =
	    XCreateSimpleWindow(dpy, XDefaultRootWindow(dpy),
				getpid(), 0, 10, 10, 0,
				WhitePixel(dpy, DefaultScreen(dpy)),
				WhitePixel(dpy, DefaultScreen(dpy)));
	XSelectInput(dpy, commWindow, PropertyChangeMask);
    }

    XSync(dpy, False);
    (void) XSetErrorHandler(old_handler);

    return got_x_error ? -1 : 0;
}

/*
 * LookupName --
 *	Given an interpreter name, see if the name exists in
 *	the interpreter registry for a particular display.
 *
 * Results:
 *	If the given name is registered, return the ID of
 *	the window associated with the name.  If the name
 *	isn't registered, then return 0.
 */

    static Window
LookupName(dpy, name, delete, loose)
    Display *dpy;	/* Display whose registry to check. */
    char *name;		/* Name of an interpreter. */
    int delete;		/* If non-zero, delete info about name. */
    char **loose;	/* Do another search matching -999 if not found
			   Return result here if a match is found */
{
    unsigned char   *regProp, *entry;
    unsigned char   *p;
    int		    result, actualFormat;
    unsigned long   numItems, bytesAfter;
    Atom	    actualType;
    Window	    returnValue;

    /*
     * Read the registry property.
     */

    regProp = NULL;
    result = XGetWindowProperty(dpy, RootWindow(dpy, 0), registryProperty, 0,
				MAX_PROP_WORDS, False, XA_STRING, &actualType,
				&actualFormat, &numItems, &bytesAfter,
				&regProp);

    if (actualType == None)
	return 0;

    /*
     * If the property is improperly formed, then delete it.
     */

    if ((result != Success) || (actualFormat != 8) || (actualType != XA_STRING))
    {
	if (regProp != NULL)
	    XFree(regProp);
	XDeleteProperty(dpy, RootWindow(dpy, 0), registryProperty);
	return 0;
    }

    /*
     * Scan the property for the desired name.
     */

    returnValue = None;
    entry = NULL;	/* Not needed, but eliminates compiler warning. */
    for (p = regProp; (p - regProp) < numItems; )
    {
	entry = p;
	while ((*p != 0) && (!isspace(*p)))
	    p++;
	if ((*p != 0) && (strcasecmp(name, p + 1) == 0))
	{
	    sscanf(entry, "%x", (uint*) &returnValue);
	    break;
	}
	while (*p != 0)
	    p++;
	p++;
    }

    if (loose != NULL && returnValue == None && !IsSerialName(name))
    {
	for (p = regProp; (p - regProp) < numItems; )
	{
	    entry = p;
	    while ((*p != 0) && (!isspace(*p)))
		p++;
	    if ((*p != 0) && IsSerialName(p + 1)
		    && (strncmp(name, p + 1, strlen(name)) == 0))
	    {
		sscanf(entry, "%x", (uint*) &returnValue);
		*loose = strdup(p + 1);
		break;
	    }
	    while (*p != 0)
		p++;
	    p++;
	}
    }

    /*
     * Delete the property, if that is desired (copy down the
     * remainder of the registry property to overlay the deleted
     * info, then rewrite the property).
     */

    if ((delete) && (returnValue != None))
    {
	int count;

	while (*p != 0)
	    p++;
	p++;
	count = numItems - (p-regProp);
	if (count > 0)
	    memcpy(entry, p, count);
	XChangeProperty(dpy, RootWindow(dpy, 0), registryProperty, XA_STRING,
			8, PropModeReplace, regProp,
			(int) (numItems - (p-entry)));
	XSync(dpy, False);
    }

    XFree(regProp);
    return returnValue;
}

    static char *
SendEventProc(dpy, eventPtr, expected, code)
    Display	   *dpy;
    XEvent	    *eventPtr;		/* Information about event. */
    int		    expected;		/* The one were waiting for */
    int		    *code;		/* Return code. 0 => OK */
{
    unsigned char   *propInfo;
    unsigned char   *p;
    int		    result, actualFormat;
    int		    retCode;
    unsigned long   numItems, bytesAfter;
    Atom	    actualType;

    if ((eventPtr->xproperty.atom != commProperty)
	    || (eventPtr->xproperty.state != PropertyNewValue))
    {
	return;
    }

    /*
     * Read the comm property and delete it.
     */

    propInfo = NULL;
    result = XGetWindowProperty(dpy, commWindow, commProperty, 0,
				MAX_PROP_WORDS, True, XA_STRING, &actualType,
				&actualFormat, &numItems, &bytesAfter,
				&propInfo);

    /*
     * If the property doesn't exist or is improperly formed
     * then ignore it.
     */

    if ((result != Success) || (actualType != XA_STRING)
	    || (actualFormat != 8))
    {
	if (propInfo != NULL)
	{
	    XFree(propInfo);
	}
	return;
    }

    /*
     * Several commands and results could arrive in the property at
     * one time;  each iteration through the outer loop handles a
     * single command or result.
     */

    for (p = propInfo; (p - propInfo) < numItems; )
    {
	/*
	 * Ignore leading NULs; each command or result starts with a
	 * NUL so that no matter how badly formed a preceding command
	 * is, we'll be able to tell that a new command/result is
	 * starting.
	 */

	if (*p == 0)
	{
	    p++;
	    continue;
	}

	if ((*p == 'r') && (p[1] == 0))
	{
	    int	    serial, gotSerial;
	    char  *res;

	    /*
	     * This is a reply to some command that we sent out.  Iterate
	     * over all of its options.  Stop when we reach the end of the
	     * property or something that doesn't look like an option.
	     */

	    p += 2;
	    gotSerial = 0;
	    res = "";
	    retCode = 0;
	    while (((p-propInfo) < numItems) && (*p == '-'))
	    {
		switch (p[1])
		{
		    case 'r':
			if (p[2] == ' ')
			    res = p + 3;
			break;
		    case 's':
			if (sscanf(p + 2, " %d", &serial) == 1)
			    gotSerial = 1;
			break;
		    case 'c':
			if (sscanf(p + 2, " %d", &retCode) != 1)
			    retCode = 0;
			break;
		}
		while (*p != 0)
		    p++;
		p++;
	    }

	    if (!gotSerial)
		continue;

	    if (code != NULL)
		*code = retCode;
	    return serial == expected ? strdup(res) : NULL;
	}
	else
	{
	    /*
	     * Didn't recognize this thing.  Just skip through the next
	     * null character and try again.
	     * Also, throw away commands that we cant process anyway.
	     */

	    while (*p != 0)
		p++;
	    p++;
	}
    }
    XFree(propInfo);
}

/*
 * AppendPropCarefully --
 *
 *	Append a given property to a given window, but set up
 *	an X error handler so that if the append fails this
 *	procedure can return an error code rather than having
 *	Xlib panic.
 *
 *  Return:
 *	0 on OK - -1 on error
 *--------------------------------------------------------------
 */

    static int
AppendPropCarefully(dpy, window, property, value, length)
    Display *dpy;		/* Display on which to operate. */
    Window window;		/* Window whose property is to
				 * be modified. */
    Atom property;		/* Name of property. */
    char *value;		/* Characters  to append to property. */
    int  length;		/* How much to append */
{
    XErrorHandler old_handler;

    old_handler = XSetErrorHandler(x_error_check);
    got_x_error = FALSE;
    XChangeProperty(dpy, window, property, XA_STRING, 8,
		    PropModeAppend, value, length);
    XSync(dpy, False);
    (void) XSetErrorHandler(old_handler);
    return got_x_error ? -1 : 0;
}


/*
 * Another X Error handler, just used to check for errors.
 */
/* ARGSUSED */
    static int
x_error_check(dpy, error_event)
    Display *dpy;
    XErrorEvent	*error_event;
{
    got_x_error = TRUE;
    return 0;
}

/*
 * Check if "str" looks like it had a serial number appended.
 * Actually just checks if the name ends in a digit.
 */
    static int
IsSerialName(str)
    char   *str;
{
    int len = strlen(str);

    return (len > 1 && isdigit(str[len - 1]));
}
