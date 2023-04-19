/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is Hunspell, based on MySpell.
 *
 * The Initial Developers of the Original Code are
 * Kevin Hendricks (MySpell) and Németh László (Hunspell).
 * Portions created by the Initial Developers are Copyright (C) 2002-2005
 * the Initial Developers. All Rights Reserved.
 *
 * Contributor(s): David Einstein, Davide Prina, Giuseppe Modugno,
 * Gianluca Turconi, Simon Brouwer, Noll János, Bíró Árpád,
 * Goldman Eleonóra, Sarlós Tamás, Bencsáth Boldizsár, Halácsy Péter,
 * Dvornik László, Gefferth András, Nagy Viktor, Varga Dániel, Chris Halls,
 * Rene Engelhard, Bram Moolenaar, Dafydd Jones, Harri Pitkänen
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

#ifndef MYSPELLMGR_H_
#define MYSPELLMGR_H_

#include "hunvisapi.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct Hunhandle Hunhandle;

LIBHUNSPELL_DLL_EXPORTED Hunhandle* Hunspell_create(const char* affpath,
                                                    const char* dpath);

LIBHUNSPELL_DLL_EXPORTED Hunhandle* Hunspell_create_key(const char* affpath,
                                                        const char* dpath,
                                                        const char* key);

LIBHUNSPELL_DLL_EXPORTED void Hunspell_destroy(Hunhandle* pHunspell);

/* load extra dictionaries (only dic files)
 * output: 0 = additional dictionary slots available, 1 = slots are now full*/
LIBHUNSPELL_DLL_EXPORTED int Hunspell_add_dic(Hunhandle* pHunspell,
                                              const char* dpath);

/* spell(word) - spellcheck word
 * output: 0 = bad word, not 0 = good word
 */
LIBHUNSPELL_DLL_EXPORTED int Hunspell_spell(Hunhandle* pHunspell, const char*);

LIBHUNSPELL_DLL_EXPORTED char* Hunspell_get_dic_encoding(Hunhandle* pHunspell);

/* suggest(suggestions, word) - search suggestions
 * input: pointer to an array of strings pointer and the (bad) word
 *   array of strings pointer (here *slst) may not be initialized
 * output: number of suggestions in string array, and suggestions in
 *   a newly allocated array of strings (*slts will be NULL when number
 *   of suggestion equals 0.)
 */
LIBHUNSPELL_DLL_EXPORTED int Hunspell_suggest(Hunhandle* pHunspell,
                                              char*** slst,
                                              const char* word);

/* Suggest words from suffix rules
 * suffix_suggest(suggestions, root_word)
 * input: pointer to an array of strings pointer and the  word
 *   array of strings pointer (here *slst) may not be initialized
 * output: number of suggestions in string array, and suggestions in
 *   a newly allocated array of strings (*slts will be NULL when number
 *   of suggestion equals 0.)
 */
LIBHUNSPELL_DLL_EXPORTED int Hunspell_suffix_suggest(Hunhandle* pHunspell,
                                                     char*** slst,
                                                     const char* word);

/* morphological functions */

/* analyze(result, word) - morphological analysis of the word */

LIBHUNSPELL_DLL_EXPORTED int Hunspell_analyze(Hunhandle* pHunspell,
                                              char*** slst,
                                              const char* word);

/* stem(result, word) - stemmer function */

LIBHUNSPELL_DLL_EXPORTED int Hunspell_stem(Hunhandle* pHunspell,
                                           char*** slst,
                                           const char* word);

/* stem(result, analysis, n) - get stems from a morph. analysis
 * example:
 * char ** result, result2;
 * int n1 = Hunspell_analyze(result, "words");
 * int n2 = Hunspell_stem2(result2, result, n1);
 */

LIBHUNSPELL_DLL_EXPORTED int Hunspell_stem2(Hunhandle* pHunspell,
                                            char*** slst,
                                            char** desc,
                                            int n);

/* generate(result, word, word2) - morphological generation by example(s) */

LIBHUNSPELL_DLL_EXPORTED int Hunspell_generate(Hunhandle* pHunspell,
                                               char*** slst,
                                               const char* word,
                                               const char* word2);

/* generate(result, word, desc, n) - generation by morph. description(s)
 * example:
 * char ** result;
 * char * affix = "is:plural"; // description depends from dictionaries, too
 * int n = Hunspell_generate2(result, "word", &affix, 1);
 * for (int i = 0; i < n; i++) printf("%s\n", result[i]);
 */

LIBHUNSPELL_DLL_EXPORTED int Hunspell_generate2(Hunhandle* pHunspell,
                                                char*** slst,
                                                const char* word,
                                                char** desc,
                                                int n);

/* functions for run-time modification of the dictionary */

/* add word to the run-time dictionary */

LIBHUNSPELL_DLL_EXPORTED int Hunspell_add(Hunhandle* pHunspell,
                                          const char* word);


LIBHUNSPELL_DLL_EXPORTED int Hunspell_add_with_flags(Hunhandle* pHunspell,
                                          const char* word, const char* flags, const char* desc);

/* add word to the run-time dictionary with affix flags of
 * the example (a dictionary word): Hunspell will recognize
 * affixed forms of the new word, too.
 */

LIBHUNSPELL_DLL_EXPORTED int Hunspell_add_with_affix(Hunhandle* pHunspell,
                                                     const char* word,
                                                     const char* example);

/* remove word from the run-time dictionary */

LIBHUNSPELL_DLL_EXPORTED int Hunspell_remove(Hunhandle* pHunspell,
                                             const char* word);

/* free suggestion lists */

LIBHUNSPELL_DLL_EXPORTED void Hunspell_free_list(Hunhandle* pHunspell,
                                                 char*** slst,
                                                 int n);

#ifdef __cplusplus
}
#endif

#endif
