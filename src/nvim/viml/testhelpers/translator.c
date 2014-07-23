#include <stdio.h>

#include "nvim/vim.h"
#include "nvim/types.h"

#include "nvim/viml/parser/ex_commands.h"
#include "nvim/viml/testhelpers/fgetline.h"
#include "nvim/viml/translator/translator.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/testhelpers/translator.c.generated.h"
#endif

static Writer write_file = (Writer) &fwrite;

/// Translate given sequence of nodes as a .vim script and dump result to stdout
///
/// @param[in]  node  Pointer to the first command inside this script.
///
/// @return OK in case of success, FAIL otherwise.
static int translate_script_stdout(const ParserResult *const node)
{
  return translate(kTransScript, node, write_file, (void *) stdout);
}

/// Translate script passed through stdin to stdout
///
/// @return OK in case of success, FAIL otherwise.
int translate_script_std(void)
{
  ParserResult *pres;
  CommandParserOptions o = { 0, false };
  int ret;

  if ((pres = parse_string(o, "<test input>", (VimlLineGetter) &fgetline_file,
                           stdin)) == NULL) {
    return FAIL;
  }

  ret = translate_script_stdout(pres);

  free_parser_result(pres);

  return ret;
}

/// Translate script passed as a single string to given file
///
/// @param[in]  str    Translated script.
/// @param[in]  fname  Target filename.
///
/// @return OK in case of success, FAIL otherwise.
int translate_script_str_to_file(const char *str,
                                 const char *const fname)
{
  ParserResult *pres;
  CommandParserOptions o = { 0, false };
  int ret;
  const char **pp;
  FILE *f;

  pp = &str;

  if ((pres = parse_string(o, "<test input>", (VimlLineGetter) &fgetline_string,
                           pp)) == NULL) {
    return FAIL;
  }

  if ((f = fopen(fname, "w")) == NULL) {
    free_parser_result(pres);
    return FAIL;
  }

  ret = translate(kTransScript, pres, write_file, (void *) f);

  free_parser_result(pres);

  fclose(f);

  return ret;
}
