/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * message_test.c: Unittests for message.c
 */

#undef NDEBUG
#include <assert.h>

/* Must include main.c because it contains much more than just main() */
#define NO_VIM_MAIN
#include "main.c"

/* This file has to be included because some of the tested functions are
 * static. */
#include "message.c"

/*
 * Test trunc_string().
 */
    static void
test_trunc_string(void)
{
    char_u  buf[40];

    /* in place */
    STRCPY(buf, "text");
    trunc_string(buf, buf, 20, 40);
    assert(STRCMP(buf, "text") == 0);

    STRCPY(buf, "a short text");
    trunc_string(buf, buf, 20, 40);
    assert(STRCMP(buf, "a short text") == 0);

    STRCPY(buf, "a text tha just fits");
    trunc_string(buf, buf, 20, 40);
    assert(STRCMP(buf, "a text tha just fits") == 0);

    STRCPY(buf, "a text that nott fits");
    trunc_string(buf, buf, 20, 40);
    assert(STRCMP(buf, "a text t...nott fits") == 0);

    /* copy from string to buf */
    trunc_string((char_u *)"text", buf, 20, 40);
    assert(STRCMP(buf, "text") == 0);

    trunc_string((char_u *)"a short text", buf, 20, 40);
    assert(STRCMP(buf, "a short text") == 0);

    trunc_string((char_u *)"a text tha just fits", buf, 20, 40);
    assert(STRCMP(buf, "a text tha just fits") == 0);

    trunc_string((char_u *)"a text that nott fits", buf, 20, 40);
    assert(STRCMP(buf, "a text t...nott fits") == 0);
}

    int
main(int argc, char **argv)
{
    mparm_T params;

    vim_memset(&params, 0, sizeof(params));
    params.argc = argc;
    params.argv = argv;
    common_init(&params);
    init_chartab();

    test_trunc_string();
    return 0;
}
