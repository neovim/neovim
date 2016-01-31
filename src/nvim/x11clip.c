/// TEMP: this should be a separate build target
//
#include "x11clip.h"
#include "nvim/memory.h"
#include <stdio.h>
#include <time.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/Intrinsic.h>
#include <X11/Shell.h>
#include <X11/StringDefs.h>

typedef struct cbd {
    char* val;
    size_t len;
    int type; //FIXME do the enum on this branch
    bool done;
} cbd_t;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "x11clip.c.generated.h"
#endif



// FIXME: this might not be the save as kMotionType
#define MCHAR   0               /* character-wise movement/register */
#define MLINE   1               /* line-wise movement/register */
#define MBLOCK  2               /* block-wise register */
#define MAUTO   0xff            /* Decide between MLINE/MCHAR */

/* Our X Display and Window */
static Display * display;
static Window root;

Widget appshell = (Widget)0, shell = (Widget)0;

struct {
  int typename;
  char* data;
  size_t len;
} sel[2] = {0};

#define LIST_OF_ATOMS \
    X(TIMESTAMP) \
    X(TARGETS) \
    X(TEXT) \
    X(CLIPBOARD) \
    X(_VIMENC_TEXT) \
    X(COMPOUND_TEXT) \
    X(UTF8_STRING) \


char* atom_names[] = {
#define X(name) #name ,
  LIST_OF_ATOMS
#undef X
};

#define X(name) static Atom name##_ATOM;
LIST_OF_ATOMS
#undef X

#define X(name) +1
const int n_atoms = 0 LIST_OF_ATOMS;
#undef X


static bool x11clip_init(void) {
  XtToolkitInitialize();
  XtAppContext app_context = XtCreateApplicationContext();
  int argc = 0;
  char** argv = NULL;
  display = XtOpenDisplay (app_context, NULL, "nvim", "Nvim", NULL, 0, &argc, argv);
  if (display==NULL) {
    fprintf(stderr, "Can't open display: \n");
    exit(1);
  }
  root = XDefaultRootWindow (display);
  /* Create an unmapped window for receiving events */

  appshell = XtVaAppCreateShell("nvim", "Nvim",
      applicationShellWidgetClass, display, NULL);

  if (appshell == (Widget)0)
    return false;

  shell = XtVaCreatePopupShell("VIM",
      topLevelShellWidgetClass, appshell,
      XtNmappedWhenManaged, 0,
      XtNwidth, 1,
      XtNheight, 1,
      NULL);

  if (shell == (Widget)0)
    return false;

    //XtAddEventHandler(w, PropertyChangeMask, False,
    //  /*(XtEventHandler)*/clip_x11_timestamp_cb, (XtPointer)NULL);
  XtRealizeWidget(shell);
  XSync(display, False);

  Atom ret[32];
  XInternAtoms(display, atom_names, n_atoms, false, ret);
  int i = 0;
#define X(name) name##_ATOM = ret[i++];
  LIST_OF_ATOMS
#undef X
  return true;
}

static bool try_get(Atom sel, Atom type, cbd_t* data, time_t timeout_time) {
  data->done = false;
  XtGetSelectionValue(shell, sel, type,
      clip_x11_request_selection_cb, (XtPointer)data, CurrentTime);

  /* Make sure the request for the selection goes out before waiting for
   * a response. */
  XFlush(display);

  // Wait for result of selection request, otherwise if we type more
  // characters, then they will appear before the one that requested the
  // paste!  Don't worry, we will catch up with any other events later.
  while (!data->done)
  {
    XEvent event;
    if (XCheckTypedEvent(display, SelectionNotify, &event)
        || XCheckTypedEvent(display, SelectionRequest, &event)
        || XCheckTypedEvent(display, PropertyNotify, &event))
    {
      /* This is where clip_x11_request_selection_cb() should be
       * called.  It may actually happen a bit later, so we loop
       * until "success" changes.
       * We may get a SelectionRequest here and if we don't handle
       * it we hang.  KDE klipper does this, for example.
       * We need to handle a PropertyNotify for large selections. */
      XtDispatchEvent(&event);
      continue;
    }

    /* Time out after 2 to 3 seconds to avoid that we hang when the
     * other process doesn't respond.  Note that the SelectionNotify
     * event may still come later when the selection owner comes back
     * to life and the text gets inserted unexpectedly.  Don't know
     * why that happens or how to avoid that :-(. */
    // FIXME(nvim) we should add a request serial id to avoid that
    if (time(NULL) > timeout_time)
    {
      return true;
    }

    /* Do we need this?  Probably not. */
    XSync(display, False);

    /* Wait for 1 msec to avoid that we eat up all CPU time. */
    usleep(1000);
  }

  return data->val != NULL;

}

static void clip_x11_request_selection_cb(
    Widget w,
    XtPointer userdata,
    Atom *sel_atom,
    Atom *type,
    XtPointer value,
    unsigned long *length,
    int  *format)
{
  cbd_t *cbd = (cbd_t *)userdata;

  cbd->type = MAUTO;
  cbd->val = NULL;
  cbd->len = 0;
  cbd->done = true;

  if (value == NULL || *length == 0)
  {
    return;
  }
  char *p = (char *)value;
  size_t len = (size_t)*length;

  if (*type == _VIMENC_TEXT_ATOM) {
    int motion_type = *p++;

    // FIXME: won't be valid once we enum
    cbd->type = motion_type;
    --len;

    char* enc = p;
    p += strlen(enc) + 1;
    len -= (size_t)(p - enc);

  } else if (*type == COMPOUND_TEXT_ATOM
             || *type == UTF8_STRING_ATOM
             || *type == TEXT_ATOM
             || *type == XA_STRING)
  {
    if (*format != 8) {
      goto cleanup_return;
    }
  } else {
    // data was not text
    goto cleanup_return;
  }

  cbd->val = xmemdupz(p, len);
  cbd->len = len; // exclusive NUL

cleanup_return:
  XtFree((char *)value);
}


static Atom sel_atom(int name) {
  return (name == '*') ? XA_PRIMARY : CLIPBOARD_ATOM;
}

bool x11clip_set(int name, int typename, char* data, size_t len) {
  int which = (name == '*') ? 1 : 0;
  sel[which].typename = typename;
  sel[which].data = data;
  sel[which].len = len;
  return true;
}

char* x11clip_get(int name, int* type, size_t* len) {
  static cbd_t cbd;
  if (display == NULL && !x11clip_init()) {
    return NULL;
  }

  // TODO: we owned the clipboard
  if (false) {
    int which = (name == '*') ? 1 : 0;
    *type = sel[which].typename;
    *len = sel[which].len;
    return sel[which].data;
  }


  Atom sel = sel_atom(name);

  time_t timeout = time(NULL) + 2;

  bool done = try_get(sel, _VIMENC_TEXT_ATOM, &cbd, timeout)
              || try_get(sel, UTF8_STRING_ATOM, &cbd, timeout)
              || try_get(sel, XA_STRING, &cbd, timeout);

  if (done && cbd.val != NULL) {
      *len = cbd.len;
      *type = cbd.type;
      return cbd.val;
  }
  return NULL;
}

