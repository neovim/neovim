// Test file to trigger all ERROR_CATEGORIES in clint.lua
// This file contains intentional errors to test the linter

#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// build/endif_comment: Uncommented text after #endif
#ifdef SOME_CONDITION
# define TEST 1
#endif SOME_CONDITION

// build/include_defs: Non-defs header included (but this is a .c file, so might not trigger)

// build/printf_format: %q format specifier
void test_printf_format()
{
  printf("%q", "test");  // Should trigger runtime/printf_format
}

// build/storage_class: Storage class not first
const static int x = 5;  // Should trigger build/storage_class

// readability/bool: Use TRUE/FALSE instead of true/false
#define TRUE 1
#define FALSE 0
#define MAYBE 2

void test_bool()
{
  int flag = TRUE;  // Should trigger readability/bool
  if (flag == FALSE) {  // Should trigger readability/bool
    printf("false\n");
  }
  int maybe_val = MAYBE;  // Should trigger readability/bool
}

// readability/multiline_comment: Complex multi-line comment
void test_multiline_comment()
{
  /* This is a multi-line
     comment that spans
     multiple lines and doesn't close properly on the same line */
}

// readability/nul: NUL byte in file (can't easily test this in text)

// readability/utf8: Invalid UTF-8 (can't easily test)

// readability/increment: Pre-increment in statements
void test_increment()
{
  int i = 0;
  ++i;  // Should trigger readability/increment
  for (int j = 0; j < 10; ++j) {  // Should trigger readability/increment
    printf("%d\n", j);
  }
}

// runtime/arrays: Variable-length arrays
void test_arrays(int size)
{
  int arr[size];  // Should trigger runtime/arrays
}

// runtime/int: Use C basic types instead of fixed-width
void test_int_types()
{
  short x = 1;        // Should trigger runtime/int
  long long y = 2;    // Should trigger runtime/int
}

// runtime/memset: memset with wrong arguments
void test_memset()
{
  char buf[100];
  memset(buf, sizeof(buf), 0);  // Should trigger runtime/memset
}

// runtime/printf: Use sprintf instead of snprintf
void test_printf()
{
  char buf[100];
  sprintf(buf, "test");  // Should trigger runtime/printf
}

// runtime/printf_format: %N$ formats
void test_printf_format2()
{
  printf("%1$d", 42);  // Should trigger runtime/printf_format
}

// runtime/threadsafe_fn: Use non-thread-safe functions
void test_threading()
{
  time_t t;
  char *time_str = ctime(&t);  // Should trigger runtime/threadsafe_fn
  asctime(localtime(&t));      // Should trigger runtime/threadsafe_fn
}

// runtime/deprecated: (This might be Neovim-specific)

// whitespace/comments: Missing space after //
void test_comments()
{
  int x = 5;  // This is a comment  // Should trigger whitespace/comments
}

// whitespace/indent: (Hard to test in this format)

// whitespace/operators: (Hard to test)

// whitespace/cast: (Hard to test)

// build/init_macro: INIT() macro in non-header (but this is a .c file)

// build/header_guard: No #pragma once (but this is a .c file)

// build/defs_header: extern variables in _defs.h (but this is a .c file)

// readability/old_style_comment: Old-style /* */ comment
void test_old_style_comment()
{
  int x = 5; /* This is an old-style comment */  // Should trigger readability/old_style_comment
}

// Try to trigger more categories
void test_more()
{
  // Try strcpy and strncpy
  char dest[100];
  char src[] = "test";
  strcpy(dest, src);   // Should trigger runtime/printf
  strncpy(dest, src, sizeof(dest));  // Should trigger runtime/printf

  // Try malloc and free (should trigger runtime/memory_fn)
  int *ptr = malloc(sizeof(int));  // Should trigger runtime/memory_fn
  free(ptr);  // Should trigger runtime/memory_fn

  // Try getenv and setenv
  char *env = getenv("HOME");  // Should trigger runtime/os_fn
  setenv("TEST", "value", 1);   // Should trigger runtime/os_fn
}

int main()
{
  test_printf_format();
  test_bool();
  test_multiline_comment();
  test_multiline_string();
  test_increment();
  test_arrays(10);
  test_int_types();
  test_memset();
  test_printf();
  test_printf_format2();
  test_threading();
  test_comments();
  test_old_style_comment();
  test_more();

  return 0;
}
