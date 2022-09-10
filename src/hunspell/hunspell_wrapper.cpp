#include <hunspell/hunspell.hxx>
#include <hunspell/hunspell.h>
#include <cstring>

using std::string;
using std::vector;

#include "hunspell_wrapper.h"

hunspell_T * hunspell_create(const char *affpath, const char *dpath) {
  return reinterpret_cast<hunspell_T *>(new Hunspell(affpath, dpath));
}


void hunspell_destroy(hunspell_T *pHunspell) {
  delete reinterpret_cast<Hunspell *>(pHunspell);
}

void hunspell_add_dic(hunspell_T *pHunspell, const char *dicpath)
{
  reinterpret_cast<Hunspell*>(pHunspell)->add_dic(dicpath);
}

bool hunspell_is_wordchar(hunspell_T *handle, const char *p)
{
  if (!handle || !p) {
    return false;
  }

  Hunspell * h = reinterpret_cast<Hunspell*>(handle);
  const string &wordchars = h->get_wordchars_cpp();

  return wordchars.find(*p) != string::npos;
}

bool hunspell_spell_flags(hunspell_T* handle, const char *p, size_t len, int *flags)
{
  string tospell(p, len);
  Hunspell *h = reinterpret_cast<Hunspell*>(handle);

  return h->spell(tospell, flags);
}

size_t hunspell_suggest(hunspell_T *handle, const char *word, size_t len, char ***ret)
{
  string tosugg(word, len);
  Hunspell *h = reinterpret_cast<Hunspell*>(handle);

  char ** suggtab = NULL;
  size_t suglen = 0;

  if (ret == NULL) {
    return 0;
  }

  vector<string> suggestions = h->suggest(tosugg);
  suglen = suggestions.size();
  if (suglen == 0) {
    goto theend;
  }

  suggtab = (char **)calloc(suglen, sizeof(char *));

  for (size_t i = 0; i < suglen; i++) {
    suggtab[i] = strdup(suggestions[i].c_str());
  }

theend:
  if (ret != NULL) {
    *ret = suggtab;
  }
  return suglen;
}
