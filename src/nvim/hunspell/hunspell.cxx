/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * Copyright (C) 2002-2022 Németh László
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
 * Hunspell is based on MySpell which is Copyright (C) 2002 Kevin Hendricks.
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
/*
 * Copyright 2002 Kevin B. Hendricks, Stratford, Ontario, Canada
 * And Contributors.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * 3. All modifications to the source code must be clearly marked as
 *    such.  Binary redistributions based on modified source code
 *    must be clearly marked as modified versions in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY KEVIN B. HENDRICKS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * KEVIN B. HENDRICKS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <cstdlib>
#include <cstring>
#include <cstdio>
#include <ctime>

#include "affixmgr.hxx"
#include "hunspell.hxx"
#include "suggestmgr.hxx"
#include "hunspell.h"
#include "csutil.hxx"

#include <limits>
#include <string>

#define MAXWORDUTF8LEN (MAXWORDLEN * 3)

class HunspellImpl
{
public:
  HunspellImpl(const char* affpath, const char* dpath, const char* key = NULL);
  HunspellImpl(const HunspellImpl&) = delete;
  HunspellImpl& operator=(const HunspellImpl&) = delete;
  ~HunspellImpl();
  int add_dic(const char* dpath, const char* key = NULL);
  std::vector<std::string> suffix_suggest(const std::string& root_word);
  std::vector<std::string> generate(const std::string& word, const std::vector<std::string>& pl);
  std::vector<std::string> generate(const std::string& word, const std::string& pattern);
  std::vector<std::string> stem(const std::string& word);
  std::vector<std::string> stem(const std::vector<std::string>& morph);
  std::vector<std::string> analyze(const std::string& word);
  int get_langnum() const;
  bool input_conv(const std::string& word, std::string& dest);
  bool spell(const std::string& word, std::vector<std::string>& candidate_stack,
             int* info = NULL, std::string* root = NULL);
  std::vector<std::string> suggest(const std::string& word);
  std::vector<std::string> suggest(const std::string& word, std::vector<std::string>& suggest_candidate_stack);
  const std::string& get_wordchars_cpp() const;
  const std::vector<w_char>& get_wordchars_utf16() const;
  const std::string& get_dict_encoding() const;
  int add(const std::string& word);
  int add_with_flags(const std::string& word, const std::string& flags, const std::string& desc = NULL);
  int add_with_affix(const std::string& word, const std::string& example);
  int remove(const std::string& word);
  const std::string& get_version_cpp() const;
  struct cs_info* get_csconv();

  int spell(const char* word, int* info = NULL, char** root = NULL);
  int suggest(char*** slst, const char* word);
  int suffix_suggest(char*** slst, const char* root_word);
  void free_list(char*** slst, int n);
  char* get_dic_encoding();
  int analyze(char*** slst, const char* word);
  int stem(char*** slst, const char* word);
  int stem(char*** slst, char** morph, int n);
  int generate(char*** slst, const char* word, const char* word2);
  int generate(char*** slst, const char* word, char** desc, int n);
  const char* get_wordchars() const;
  const char* get_version() const;
  int input_conv(const char* word, char* dest, size_t destsize);

private:
  AffixMgr* pAMgr;
  std::vector<HashMgr*> m_HMgrs;
  SuggestMgr* pSMgr;
  std::string affixpath;
  std::string encoding;
  struct cs_info* csconv;
  int langnum;
  int utf8;
  int complexprefixes;
  std::vector<std::string> wordbreak;

private:
  std::vector<std::string> analyze_internal(const std::string& word);
  bool spell_internal(const std::string& word, std::vector<std::string>& candidate_stack,
                      int* info = NULL, std::string* root = NULL);
  std::vector<std::string> suggest_internal(const std::string& word,
                                            std::vector<std::string>& spell_candidate_stack,
                                            std::vector<std::string>& suggest_candidate_stack,
                                            bool& capitalized, size_t& abbreviated, int& captype);
  void cleanword(std::string& dest, const std::string&, int* pcaptype, int* pabbrev);
  size_t cleanword2(std::string& dest,
                    std::vector<w_char>& dest_u,
                    const std::string& src,
                    int* pcaptype,
                    size_t* pabbrev);
  void clean_ignore(std::string& dest, const std::string& src);
  void mkinitcap(std::string& u8);
  int mkinitcap2(std::string& u8, std::vector<w_char>& u16);
  int mkinitsmall2(std::string& u8, std::vector<w_char>& u16);
  void mkallcap(std::string& u8);
  int mkallsmall2(std::string& u8, std::vector<w_char>& u16);
  struct hentry* checkword(const std::string& source, int* info, std::string* root);
  std::string sharps_u8_l1(const std::string& source);
  hentry*
  spellsharps(std::string& base, size_t start_pos, int, int, int* info, std::string* root);
  int is_keepcase(const hentry* rv);
  void insert_sug(std::vector<std::string>& slst, const std::string& word);
  void cat_result(std::string& result, const std::string& st);
  std::vector<std::string> spellml(const std::string& word);
  std::string get_xml_par(const std::string& par, std::string::size_type pos);
  std::string::size_type get_xml_pos(const std::string& s, std::string::size_type pos, const char* attr);
  std::vector<std::string> get_xml_list(const std::string& list, std::string::size_type pos, const char* tag);
  int check_xml_par(const std::string& q, std::string::size_type pos, const char* attr, const char* value);
};

HunspellImpl::HunspellImpl(const char* affpath, const char* dpath, const char* key)
  : affixpath(affpath) {
  csconv = NULL;
  utf8 = 0;
  complexprefixes = 0;

  /* first set up the hash manager */
  m_HMgrs.push_back(new HashMgr(dpath, affpath, key));

  /* next set up the affix manager */
  /* it needs access to the hash manager lookup methods */
  pAMgr = new AffixMgr(affpath, m_HMgrs, key);

  /* get the preferred try string and the dictionary */
  /* encoding from the Affix Manager for that dictionary */
  std::string try_string = pAMgr->get_try_string();
  encoding = pAMgr->get_encoding();
  langnum = pAMgr->get_langnum();
  utf8 = pAMgr->get_utf8();
  if (!utf8)
    csconv = get_current_cs(encoding);
  complexprefixes = pAMgr->get_complexprefixes();
  wordbreak = pAMgr->get_breaktable();

  /* and finally set up the suggestion manager */
  pSMgr = new SuggestMgr(try_string, MAXSUGGESTION, pAMgr);
}

HunspellImpl::~HunspellImpl() {
  delete pSMgr;
  delete pAMgr;
  for (auto& m_HMgr : m_HMgrs)
    delete m_HMgr;
  pSMgr = NULL;
  pAMgr = NULL;
#ifdef MOZILLA_CLIENT
  delete[] csconv;
#endif
  csconv = NULL;
}

// load extra dictionaries
int HunspellImpl::add_dic(const char* dpath, const char* key) {
  m_HMgrs.push_back(new HashMgr(dpath, affixpath.c_str(), key));
  return 0;
}


// make a copy of src at dest while removing all characters
// specified in IGNORE rule
void HunspellImpl::clean_ignore(std::string& dest,
                                const std::string& src) {
  dest.clear();
  dest.assign(src);
  const char* ignoredchars = pAMgr ? pAMgr->get_ignore() : NULL;
  if (ignoredchars != NULL) {
    if (utf8) {
      const std::vector<w_char>& ignoredchars_utf16 =
          pAMgr->get_ignore_utf16();
      remove_ignored_chars_utf(dest, ignoredchars_utf16);
    } else {
      remove_ignored_chars(dest, ignoredchars);
    }
  }
}


// make a copy of src at destination while removing all leading
// blanks and removing any trailing periods after recording
// their presence with the abbreviation flag
// also since already going through character by character,
// set the capitalization type
// return the length of the "cleaned" (and UTF-8 encoded) word

size_t HunspellImpl::cleanword2(std::string& dest,
                         std::vector<w_char>& dest_utf,
                         const std::string& src,
                         int* pcaptype,
                         size_t* pabbrev) {
  dest.clear();
  dest_utf.clear();

  // remove IGNORE characters from the string
  std::string w2;
  clean_ignore(w2, src);

  const char* q = w2.c_str();
  int nl = (int)w2.size();

  // first skip over any leading blanks
  while (*q == ' ') {
    ++q;
    nl--;
  }
	
  // now strip off any trailing periods (recording their presence)
  *pabbrev = 0;
  
  while ((nl > 0) && (*(q + nl - 1) == '.')) {
    nl--;
    (*pabbrev)++;
  }

  // if no characters are left it can't be capitalized
  if (nl <= 0) {
    *pcaptype = NOCAP;
    return 0;
  }

  dest.append(q, nl);
  nl = dest.size();
  if (utf8) {
    u8_u16(dest_utf, dest);
    *pcaptype = get_captype_utf8(dest_utf, langnum);
  } else {
    *pcaptype = get_captype(dest, csconv);
  }
  return nl;
}

void HunspellImpl::cleanword(std::string& dest,
                        const std::string& src,
                        int* pcaptype,
                        int* pabbrev) {
  dest.clear();
  const unsigned char* q = (const unsigned char*)src.c_str();
  int firstcap = 0, nl = (int)src.size();

  // first skip over any leading blanks
  while (*q == ' ') {
    ++q;
    nl--;
  }
  
  // now strip off any trailing periods (recording their presence)
  *pabbrev = 0;
  
  while ((nl > 0) && (*(q + nl - 1) == '.')) {
    nl--;
    (*pabbrev)++;
  }

  // if no characters are left it can't be capitalized
  if (nl <= 0) {
    *pcaptype = NOCAP;
    return;
  }

  // now determine the capitalization type of the first nl letters
  int ncap = 0;
  int nneutral = 0;
  int nc = 0;

  if (!utf8) {
    while (nl > 0) {
      nc++;
      if (csconv[(*q)].ccase)
        ncap++;
      if (csconv[(*q)].cupper == csconv[(*q)].clower)
        nneutral++;
      dest.push_back(*q++);
      nl--;
    }
    // remember to terminate the destination string
    firstcap = csconv[static_cast<unsigned char>(dest[0])].ccase;
  } else {
    std::vector<w_char> t;
    u8_u16(t, src);
    for (auto& wc : t) {
      const auto idx = (unsigned short)wc;
      const auto low = unicodetolower(idx, langnum);
      if (idx != low)
        ncap++;
      if (unicodetoupper(idx, langnum) == low)
        nneutral++;
    }
    u16_u8(dest, t);
    if (ncap) {
      const auto idx = (unsigned short)t[0];
      firstcap = (idx != unicodetolower(idx, langnum));
    }
  }

  // now finally set the captype
  if (ncap == 0) {
    *pcaptype = NOCAP;
  } else if ((ncap == 1) && firstcap) {
    *pcaptype = INITCAP;
  } else if ((ncap == nc) || ((ncap + nneutral) == nc)) {
    *pcaptype = ALLCAP;
  } else if ((ncap > 1) && firstcap) {
    *pcaptype = HUHINITCAP;
  } else {
    *pcaptype = HUHCAP;
  }
}

void HunspellImpl::mkallcap(std::string& u8) {
  if (utf8) {
    std::vector<w_char> u16;
    u8_u16(u16, u8);
    ::mkallcap_utf(u16, langnum);
    u16_u8(u8, u16);
  } else {
    ::mkallcap(u8, csconv);
  }
}

int HunspellImpl::mkallsmall2(std::string& u8, std::vector<w_char>& u16) {
  if (utf8) {
    ::mkallsmall_utf(u16, langnum);
    u16_u8(u8, u16);
  } else {
    ::mkallsmall(u8, csconv);
  }
  return u8.size();
}

// convert UTF-8 sharp S codes to latin 1
std::string HunspellImpl::sharps_u8_l1(const std::string& source) {
  std::string dest(source);
  mystrrep(dest, "\xC3\x9F", "\xDF");
  return dest;
}

// recursive search for right ss - sharp s permutations
hentry* HunspellImpl::spellsharps(std::string& base,
                              size_t n_pos,
                              int n,
                              int repnum,
                              int* info,
                              std::string* root) {
  size_t pos = base.find("ss", n_pos);
  if (pos != std::string::npos && (n < MAXSHARPS)) {
    base[pos] = '\xC3';
    base[pos + 1] = '\x9F';
    hentry* h = spellsharps(base, pos + 2, n + 1, repnum + 1, info, root);
    if (h)
      return h;
    base[pos] = 's';
    base[pos + 1] = 's';
    h = spellsharps(base, pos + 2, n + 1, repnum, info, root);
    if (h)
      return h;
  } else if (repnum > 0) {
    if (utf8)
      return checkword(base, info, root);
    std::string tmp(sharps_u8_l1(base));
    return checkword(tmp, info, root);
  }
  return NULL;
}

int HunspellImpl::is_keepcase(const hentry* rv) {
  return pAMgr && rv->astr && pAMgr->get_keepcase() &&
         TESTAFF(rv->astr, pAMgr->get_keepcase(), rv->alen);
}

/* insert a word to the beginning of the suggestion array */
void HunspellImpl::insert_sug(std::vector<std::string>& slst, const std::string& word) {
  slst.insert(slst.begin(), word);
}

bool HunspellImpl::spell(const std::string& word, std::vector<std::string>& candidate_stack,
                         int* info, std::string* root) {
  // something very broken if spell ends up calling itself with the same word
  if (std::find(candidate_stack.begin(), candidate_stack.end(), word) != candidate_stack.end())
    return false;

  candidate_stack.push_back(word);
  bool r = spell_internal(word, candidate_stack, info, root);
  candidate_stack.pop_back();

  if (r && root) {
    // output conversion
    RepList* rl = (pAMgr) ? pAMgr->get_oconvtable() : NULL;
    if (rl) {
      std::string wspace;
      if (rl->conv(*root, wspace)) {
        *root = wspace;
      }
    }
  }
  return r;
}

bool HunspellImpl::spell_internal(const std::string& word, std::vector<std::string>& candidate_stack,
                                  int* info, std::string* root) {
  struct hentry* rv = NULL;

  int info2 = 0;
  if (!info)
    info = &info2;
  else
    *info = 0;

  // Hunspell supports XML input of the simplified API (see manual)
  if (word == SPELL_XML)
    return true;
  if (utf8) {
    if (word.size() >= MAXWORDUTF8LEN)
      return false;
  } else {
    if (word.size() >= MAXWORDLEN)
      return false;
  }
  int captype = NOCAP;
  size_t abbv = 0;
  size_t wl = 0;

  std::string scw;
  std::vector<w_char> sunicw;

  // input conversion
  RepList* rl = pAMgr ? pAMgr->get_iconvtable() : NULL;
  {
    std::string wspace;

    bool convstatus = rl ? rl->conv(word, wspace) : false;
    if (convstatus)
      wl = cleanword2(scw, sunicw, wspace, &captype, &abbv);
    else
      wl = cleanword2(scw, sunicw, word, &captype, &abbv);
  }

#ifdef MOZILLA_CLIENT
  // accept the abbreviated words without dots
  // workaround for the incomplete tokenization of Mozilla
  abbv = 1;
#endif

  if (wl == 0 || m_HMgrs.empty())
    return true;
  if (root)
    root->clear();

  // allow numbers with dots, dashes and commas (but forbid double separators:
  // "..", "--" etc.)
  enum { NBEGIN, NNUM, NSEP };
  int nstate = NBEGIN;
  size_t i;

  for (i = 0; (i < wl); i++) {
    if ((scw[i] <= '9') && (scw[i] >= '0')) {
      nstate = NNUM;
    } else if ((scw[i] == ',') || (scw[i] == '.') || (scw[i] == '-')) {
      if ((nstate == NSEP) || (i == 0))
        break;
      nstate = NSEP;
    } else
      break;
  }
  if ((i == wl) && (nstate == NNUM))
    return true;

  switch (captype) {
    case HUHCAP:
    /* FALLTHROUGH */
    case HUHINITCAP:
      *info |= SPELL_ORIGCAP;
    /* FALLTHROUGH */
    case NOCAP:
      rv = checkword(scw, info, root);
      if ((abbv) && !(rv)) {
        std::string u8buffer(scw);
        u8buffer.push_back('.');
        rv = checkword(u8buffer, info, root);
      }
      break;
    case ALLCAP: {
      *info |= SPELL_ORIGCAP;
      rv = checkword(scw, info, root);
      if (rv)
        break;
      if (abbv) {
        std::string u8buffer(scw);
        u8buffer.push_back('.');
        rv = checkword(u8buffer, info, root);
        if (rv)
          break;
      }
      // Spec. prefix handling for Catalan, French, Italian:
      // prefixes separated by apostrophe (SANT'ELIA -> Sant'+Elia).
      size_t apos = pAMgr ? scw.find('\'') : std::string::npos;
      if (apos != std::string::npos) {
        mkallsmall2(scw, sunicw);
        //conversion may result in string with different len to pre-mkallsmall2
        //so re-scan
        if (apos != std::string::npos && apos < scw.size() - 1) {
          std::string part1 = scw.substr(0, apos + 1), part2 = scw.substr(apos + 1);
          if (utf8) {
            std::vector<w_char> part1u, part2u;
            u8_u16(part1u, part1);
            u8_u16(part2u, part2);
            mkinitcap2(part2, part2u);
            scw = part1 + part2;
            sunicw = part1u;
            sunicw.insert(sunicw.end(), part2u.begin(), part2u.end());
            rv = checkword(scw, info, root);
            if (rv)
              break;
          } else {
            mkinitcap2(part2, sunicw);
            scw = part1 + part2;
            rv = checkword(scw, info, root);
            if (rv)
              break;
          }
          mkinitcap2(scw, sunicw);
          rv = checkword(scw, info, root);
          if (rv)
            break;
        }
      }
      if (pAMgr && pAMgr->get_checksharps() && scw.find("SS") != std::string::npos) {

        mkallsmall2(scw, sunicw);
        std::string u8buffer(scw);
        rv = spellsharps(u8buffer, 0, 0, 0, info, root);
        if (!rv) {
          mkinitcap2(scw, sunicw);
          rv = spellsharps(scw, 0, 0, 0, info, root);
        }
        if ((abbv) && !(rv)) {
          u8buffer.push_back('.');
          rv = spellsharps(u8buffer, 0, 0, 0, info, root);
          if (!rv) {
            u8buffer = std::string(scw);
            u8buffer.push_back('.');
            rv = spellsharps(u8buffer, 0, 0, 0, info, root);
          }
        }
        if (rv)
          break;
      }
    }
      /* FALLTHROUGH */
    case INITCAP: {
      // handle special capitalization of dotted I
      bool Idot = (utf8 && (unsigned char) scw[0] == 0xc4 && (unsigned char) scw[1] == 0xb0);
      *info |= SPELL_ORIGCAP;
      if (captype == ALLCAP) {
          mkallsmall2(scw, sunicw);
          mkinitcap2(scw, sunicw);
          if (Idot)
             scw.replace(0, 1, "\xc4\xb0");
      }
      if (captype == INITCAP)
        *info |= SPELL_INITCAP;
      rv = checkword(scw, info, root);
      if (captype == INITCAP)
        *info &= ~SPELL_INITCAP;
      // forbid bad capitalization
      // (for example, ijs -> Ijs instead of IJs in Dutch)
      // use explicit forms in dic: Ijs/F (F = FORBIDDENWORD flag)
      if (*info & SPELL_FORBIDDEN) {
        rv = NULL;
        break;
      }
      if (rv && is_keepcase(rv) && (captype == ALLCAP))
        rv = NULL;
      if (rv || (Idot && langnum != LANG_az && langnum != LANG_tr && langnum != LANG_crh))
        break;

      mkallsmall2(scw, sunicw);
      std::string u8buffer(scw);
      mkinitcap2(scw, sunicw);

      rv = checkword(u8buffer, info, root);
      if (abbv && !rv) {
        u8buffer.push_back('.');
        rv = checkword(u8buffer, info, root);
        if (!rv) {
          u8buffer = scw;
          u8buffer.push_back('.');
          if (captype == INITCAP)
            *info |= SPELL_INITCAP;
          rv = checkword(u8buffer, info, root);
          if (captype == INITCAP)
            *info &= ~SPELL_INITCAP;
          if (rv && is_keepcase(rv) && (captype == ALLCAP))
            rv = NULL;
          break;
        }
      }
      if (rv && is_keepcase(rv) &&
          ((captype == ALLCAP) ||
           // if CHECKSHARPS: KEEPCASE words with \xDF  are allowed
           // in INITCAP form, too.
           !(pAMgr->get_checksharps() &&
             ((utf8 && u8buffer.find("\xC3\x9F") != std::string::npos) ||
              (!utf8 && u8buffer.find('\xDF') != std::string::npos)))))
        rv = NULL;
      break;
    }
  }

  if (rv) {
    if (pAMgr && pAMgr->get_warn() && rv->astr &&
        TESTAFF(rv->astr, pAMgr->get_warn(), rv->alen)) {
      *info |= SPELL_WARN;
      if (pAMgr->get_forbidwarn())
        return false;
      return true;
    }
    return true;
  }

  // recursive breaking at break points
  if (!wordbreak.empty() && !(*info & SPELL_FORBIDDEN)) {

    int nbr = 0;
    wl = scw.size();

    // calculate break points for recursion limit
    for (auto& j : wordbreak) {
      size_t pos = 0;
      while ((pos = scw.find(j, pos)) != std::string::npos) {
        ++nbr;
        pos += j.size();
      }
    }
    if (nbr >= 10)
      return false;

    // check boundary patterns (^begin and end$)
    for (auto& j : wordbreak) {
      size_t plen = j.size();
      if (plen == 1 || plen > wl)
        continue;

      if (j[0] == '^' &&
          scw.compare(0, plen - 1, j, 1, plen -1) == 0 && spell(scw.substr(plen - 1), candidate_stack))
      {
        if (info)
          *info |= SPELL_COMPOUND;
        return true;
      }

      if (j[plen - 1] == '$' &&
          scw.compare(wl - plen + 1, plen - 1, j, 0, plen - 1) == 0) {
        std::string suffix(scw.substr(wl - plen + 1));
        scw.resize(wl - plen + 1);
        if (spell(scw, candidate_stack))
        {
          if (info)
            *info |= SPELL_COMPOUND;
          return true;
        }
        scw.append(suffix);
      }
    }

    // other patterns
    for (auto& j : wordbreak) {
      size_t plen = j.size();
      size_t found = scw.find(j);
      if ((found > 0) && (found < wl - plen)) {
        size_t found2 = scw.find(j, found + 1);
        // try to break at the second occurance
        // to recognize dictionary words with wordbreak
        if (found2 > 0 && (found2 < wl - plen))
            found = found2;
        std::string substring(scw.substr(found + plen));
        if (!spell(substring, candidate_stack))
          continue;
        std::string suffix(scw.substr(found));
        scw.resize(found);
        // examine 2 sides of the break point
        if (spell(scw, candidate_stack))
        {
          if (info)
            *info |= SPELL_COMPOUND;
          return true;
        }
        scw.append(suffix);

        // LANG_hu: spec. dash rule
        if (langnum == LANG_hu && j == "-") {
          suffix = scw.substr(found + 1);
          scw.resize(found + 1);
          if (spell(scw, candidate_stack))
          {
            if (info)
              *info |= SPELL_COMPOUND;
            return true;  // check the first part with dash
          }
          scw.append(suffix);
        }
        // end of LANG specific region
      }
    }

    // other patterns (break at first break point)
    for (auto& j : wordbreak) {
      size_t plen = j.size(), found = scw.find(j);
      if ((found > 0) && (found < wl - plen)) {
        if (!spell(scw.substr(found + plen), candidate_stack))
          continue;
        std::string suffix(scw.substr(found));
        scw.resize(found);
        // examine 2 sides of the break point
        if (spell(scw, candidate_stack))
        {
          if (info)
            *info |= SPELL_COMPOUND;
          return true;
        }
        scw.append(suffix);

        // LANG_hu: spec. dash rule
        if (langnum == LANG_hu && j == "-") {
          suffix = scw.substr(found + 1);
          scw.resize(found + 1);
          if (spell(scw, candidate_stack))
          {
            if (info)
              *info |= SPELL_COMPOUND;
            return true;  // check the first part with dash
          }
          scw.append(suffix);
        }
        // end of LANG specific region
      }
    }
  }

  return false;
}

struct hentry* HunspellImpl::checkword(const std::string& w, int* info, std::string* root) {
  std::string word;

  // remove IGNORE characters from the string
  clean_ignore(word, w);

  if (word.empty())
    return NULL;

  // word reversing wrapper for complex prefixes
  if (complexprefixes) {
    if (utf8)
      reverseword_utf(word);
    else
      reverseword(word);
  }

  int len = word.size();

  // look word in hash table
  struct hentry* he = NULL;
  for (size_t i = 0; (i < m_HMgrs.size()) && !he; ++i) {
    he = m_HMgrs[i]->lookup(word.c_str(), word.size());

    // check forbidden and onlyincompound words
    if ((he) && (he->astr) && (pAMgr) &&
        TESTAFF(he->astr, pAMgr->get_forbiddenword(), he->alen)) {
      if (info)
        *info |= SPELL_FORBIDDEN;
      // LANG_hu section: set dash information for suggestions
      if (langnum == LANG_hu) {
        if (pAMgr->get_compoundflag() &&
            TESTAFF(he->astr, pAMgr->get_compoundflag(), he->alen)) {
          if (info)
            *info |= SPELL_COMPOUND;
        }
      }
      return NULL;
    }

    // he = next not needaffix, onlyincompound homonym or onlyupcase word
    while (he && (he->astr) && pAMgr &&
           ((pAMgr->get_needaffix() &&
             TESTAFF(he->astr, pAMgr->get_needaffix(), he->alen)) ||
            (pAMgr->get_onlyincompound() &&
             TESTAFF(he->astr, pAMgr->get_onlyincompound(), he->alen)) ||
            (info && (*info & SPELL_INITCAP) &&
             TESTAFF(he->astr, ONLYUPCASEFLAG, he->alen))))
      he = he->next_homonym;
  }

  // check with affixes
  if (!he && pAMgr) {
    // try stripping off affixes
    he = pAMgr->affix_check(word, 0, len, 0);

    // check compound restriction and onlyupcase
    if (he && he->astr &&
        ((pAMgr->get_onlyincompound() &&
          TESTAFF(he->astr, pAMgr->get_onlyincompound(), he->alen)) ||
         (info && (*info & SPELL_INITCAP) &&
          TESTAFF(he->astr, ONLYUPCASEFLAG, he->alen)))) {
      he = NULL;
    }

    if (he) {
      if ((he->astr) && (pAMgr) &&
          TESTAFF(he->astr, pAMgr->get_forbiddenword(), he->alen)) {
        if (info)
          *info |= SPELL_FORBIDDEN;
        return NULL;
      }
      if (root) {
        root->assign(he->word);
        if (complexprefixes) {
          if (utf8)
            reverseword_utf(*root);
          else
            reverseword(*root);
        }
      }
      // try check compound word
    } else if (pAMgr->get_compound()) {
      struct hentry* rwords[100] = {};  // buffer for COMPOUND pattern checking

      // first allow only 2 words in the compound
      int setinfo = SPELL_COMPOUND_2;
      if (info)
        setinfo |= *info;
      he = pAMgr->compound_check(word, 0, 0, 100, 0, NULL, (hentry**)&rwords, 0, 0, &setinfo);
      if (info)
        *info = setinfo & ~SPELL_COMPOUND_2;
      // if not 2-word compoud word, try with 3 or more words
      // (only if original info didn't forbid it)
      if (!he && info && !(*info & SPELL_COMPOUND_2)) {
        *info &= ~SPELL_COMPOUND_2;
        he = pAMgr->compound_check(word, 0, 0, 100, 0, NULL, (hentry**)&rwords, 0, 0, info);
        // accept the compound with 3 or more words only if it is
        // - not a dictionary word with a typo and
        // - not two words written separately,
        // - or if it's an arbitrary number accepted by compound rules (e.g. 999%)
        if (he && !isdigit(word[0]))
        {
          std::vector<std::string> slst;
          if (pSMgr->suggest(slst, word, NULL, /*test_simplesug=*/true))
            he = NULL;
        }
      }

      // LANG_hu section: `moving rule' with last dash
      if ((!he) && (langnum == LANG_hu) && (word[len - 1] == '-')) {
        std::string dup(word, 0, len - 1);
        he = pAMgr->compound_check(dup, -5, 0, 100, 0, NULL, (hentry**)&rwords, 1, 0, info);
      }
      // end of LANG specific region
      if (he) {
        if (root) {
          root->assign(he->word);
          if (complexprefixes) {
            if (utf8)
              reverseword_utf(*root);
            else
              reverseword(*root);
          }
        }
        if (info)
          *info |= SPELL_COMPOUND;
      }
    }
  }

  return he;
}

std::vector<std::string> HunspellImpl::suggest(const std::string& word, std::vector<std::string>& suggest_candidate_stack) {

  if (suggest_candidate_stack.size() > 2048 || // apply a fairly arbitrary depth limit
      // something very broken if suggest ends up calling itself with the same word
      std::find(suggest_candidate_stack.begin(), suggest_candidate_stack.end(), word) != suggest_candidate_stack.end()) {
    return { };
  }

  bool capwords;
  size_t abbv;
  int captype;
  std::vector<std::string> spell_candidate_stack;
  suggest_candidate_stack.push_back(word);
  std::vector<std::string> slst = suggest_internal(word, spell_candidate_stack, suggest_candidate_stack,
		                                   capwords, abbv, captype);
  suggest_candidate_stack.pop_back();
  // word reversing wrapper for complex prefixes
  if (complexprefixes) {
    for (auto& j : slst) {
      if (utf8)
        reverseword_utf(j);
      else
        reverseword(j);
    }
  }

  // capitalize
  if (capwords)
    for (auto& j : slst) {
      mkinitcap(j);
    }

  // expand suggestions with dot(s)
  if (abbv && pAMgr && pAMgr->get_sugswithdots() && word.size() >= abbv) {
    for (auto& j : slst) {
	    j.append(word.substr(word.size() - abbv));
    }
  }

  // remove bad capitalized and forbidden forms
  if (pAMgr && (pAMgr->get_keepcase() || pAMgr->get_forbiddenword())) {
    switch (captype) {
      case INITCAP:
      case ALLCAP: {
        size_t l = 0;
        for (size_t j = 0; j < slst.size(); ++j) {
          if (slst[j].find(' ') == std::string::npos && !spell(slst[j], spell_candidate_stack)) {
            std::string s;
            std::vector<w_char> w;
            if (utf8) {
              u8_u16(w, slst[j]);
            } else {
              s = slst[j];
            }
            mkallsmall2(s, w);
            if (spell(s, spell_candidate_stack)) {
              slst[l] = s;
              ++l;
            } else {
              mkinitcap2(s, w);
              if (spell(s, spell_candidate_stack)) {
                slst[l] = s;
                ++l;
              }
            }
          } else {
            slst[l] = slst[j];
            ++l;
          }
        }
        slst.resize(l);
      }
    }
  }

  // remove duplications
  size_t l = 0;
  for (size_t j = 0; j < slst.size(); ++j) {
    slst[l] = slst[j];
    for (size_t k = 0; k < l; ++k) {
      if (slst[k] == slst[j]) {
        --l;
        break;
      }
    }
    ++l;
  }
  slst.resize(l);

  // output conversion
  RepList* rl = (pAMgr) ? pAMgr->get_oconvtable() : NULL;
  if (rl) {
    for (size_t i = 0; rl && i < slst.size(); ++i) {
      std::string wspace;
      if (rl->conv(slst[i], wspace)) {
        slst[i] = wspace;
      }
    }
  }
  return slst;
}

std::vector<std::string> HunspellImpl::suggest(const std::string& word) {
  std::vector<std::string> suggest_candidate_stack;
  return suggest(word, suggest_candidate_stack);
}

std::vector<std::string> HunspellImpl::suggest_internal(const std::string& word,
        std::vector<std::string>& spell_candidate_stack,
        std::vector<std::string>& suggest_candidate_stack,
        bool& capwords, size_t& abbv, int& captype) {
  captype = NOCAP;
  abbv = 0;
  capwords = false;

  std::vector<std::string> slst;

  int onlycmpdsug = 0;
  if (!pSMgr || m_HMgrs.empty())
    return slst;

  // process XML input of the simplified API (see manual)
  if (word.compare(0, sizeof(SPELL_XML) - 3, SPELL_XML, sizeof(SPELL_XML) - 3) == 0) {
    return spellml(word);
  }
  if (utf8) {
    if (word.size() >= MAXWORDUTF8LEN)
      return slst;
  } else {
    if (word.size() >= MAXWORDLEN)
      return slst;
  }
  size_t wl = 0;

  std::string scw;
  std::vector<w_char> sunicw;

  // input conversion
  RepList* rl = (pAMgr) ? pAMgr->get_iconvtable() : NULL;
  {
    std::string wspace;

    bool convstatus = rl ? rl->conv(word, wspace) : false;
    if (convstatus)
      wl = cleanword2(scw, sunicw, wspace, &captype, &abbv);
    else
      wl = cleanword2(scw, sunicw, word, &captype, &abbv);

    if (wl == 0)
      return slst;

#if defined(FUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION)
    if (wl > 32768)
      return slst;
#endif
  }

  bool good = false;

  clock_t timelimit;
  // initialize in every suggestion call
  timelimit = clock();

  // check capitalized form for FORCEUCASE
  if (pAMgr && captype == NOCAP && pAMgr->get_forceucase()) {
    int info = SPELL_ORIGCAP;
    if (checkword(scw, &info, NULL)) {
      std::string form(scw);
      mkinitcap(form);
      slst.push_back(form);
      return slst;
    }
  }

  switch (captype) {
    case NOCAP: {
      good |= pSMgr->suggest(slst, scw, &onlycmpdsug);
      if (clock() > timelimit + TIMELIMIT_GLOBAL)
          return slst;
      if (abbv) {
        std::string wspace(scw);
        wspace.push_back('.');
        good |= pSMgr->suggest(slst, wspace, &onlycmpdsug);
        if (clock() > timelimit + TIMELIMIT_GLOBAL)
            return slst;
      }
      break;
    }

    case INITCAP: {
      capwords = true;
      good |= pSMgr->suggest(slst, scw, &onlycmpdsug);
      if (clock() > timelimit + TIMELIMIT_GLOBAL)
          return slst;
      std::string wspace(scw);
      mkallsmall2(wspace, sunicw);
      good |= pSMgr->suggest(slst, wspace, &onlycmpdsug);
      if (clock() > timelimit + TIMELIMIT_GLOBAL)
          return slst;
      break;
    }
    case HUHINITCAP:
      capwords = true;
      /* FALLTHROUGH */
    case HUHCAP: {
      good |= pSMgr->suggest(slst, scw, &onlycmpdsug);
      if (clock() > timelimit + TIMELIMIT_GLOBAL)
          return slst;
      // something.The -> something. The
      size_t dot_pos = scw.find('.');
      if (dot_pos != std::string::npos) {
        std::string postdot = scw.substr(dot_pos + 1);
        int captype_;
        if (utf8) {
          std::vector<w_char> postdotu;
          u8_u16(postdotu, postdot);
          captype_ = get_captype_utf8(postdotu, langnum);
        } else {
          captype_ = get_captype(postdot, csconv);
        }
        if (captype_ == INITCAP) {
          std::string str(scw);
          str.insert(dot_pos + 1, 1, ' ');
          insert_sug(slst, str);
        }
      }

      std::string wspace;

      if (captype == HUHINITCAP) {
        // TheOpenOffice.org -> The OpenOffice.org
        wspace = scw;
        mkinitsmall2(wspace, sunicw);
        good |= pSMgr->suggest(slst, wspace, &onlycmpdsug);
        if (clock() > timelimit + TIMELIMIT_GLOBAL)
            return slst;
      }
      wspace = scw;
      mkallsmall2(wspace, sunicw);
      if (spell(wspace, spell_candidate_stack))
        insert_sug(slst, wspace);
      size_t prevns = slst.size();
      good |= pSMgr->suggest(slst, wspace, &onlycmpdsug);
      if (clock() > timelimit + TIMELIMIT_GLOBAL)
          return slst;
      if (captype == HUHINITCAP) {
        mkinitcap2(wspace, sunicw);
        if (spell(wspace, spell_candidate_stack))
          insert_sug(slst, wspace);
        good |= pSMgr->suggest(slst, wspace, &onlycmpdsug);
        if (clock() > timelimit + TIMELIMIT_GLOBAL)
            return slst;
      }
      // aNew -> "a New" (instead of "a new")
      for (size_t j = prevns; j < slst.size(); ++j) {
        const char* space = strchr(slst[j].c_str(), ' ');
        if (space) {
          size_t slen = strlen(space + 1);
          // different case after space (need capitalisation)
          if ((slen < wl) && strcmp(scw.c_str() + wl - slen, space + 1)) {
            std::string first(slst[j].c_str(), space + 1);
            std::string second(space + 1);
            std::vector<w_char> w;
            if (utf8)
              u8_u16(w, second);
            mkinitcap2(second, w);
            // set as first suggestion
            slst.erase(slst.begin() + j);
            slst.insert(slst.begin(), first + second);
          }
        }
      }
      break;
    }

    case ALLCAP: {
      std::string wspace(scw);
      mkallsmall2(wspace, sunicw);
      good |= pSMgr->suggest(slst, wspace, &onlycmpdsug);
      if (clock() > timelimit + TIMELIMIT_GLOBAL)
          return slst;
      if (pAMgr && pAMgr->get_keepcase() && spell(wspace, spell_candidate_stack))
        insert_sug(slst, wspace);
      mkinitcap2(wspace, sunicw);
      good |= pSMgr->suggest(slst, wspace, &onlycmpdsug);
      if (clock() > timelimit + TIMELIMIT_GLOBAL)
          return slst;
      for (auto& j : slst) {
        mkallcap(j);
        if (pAMgr && pAMgr->get_checksharps()) {
          if (utf8) {
            mystrrep(j, "\xC3\x9F", "SS");
          } else {
            mystrrep(j, "\xDF", "SS");
          }
        }
      }
      break;
    }
  }

  // LANG_hu section: replace '-' with ' ' in Hungarian
  if (langnum == LANG_hu) {
    for (auto& j : slst) {
      size_t pos = j.find('-');
      if (pos != std::string::npos) {
        int info;
        std::string w(j.substr(0, pos));
        w.append(j.substr(pos + 1));
        (void)spell(w, spell_candidate_stack, &info, NULL);
        if ((info & SPELL_COMPOUND) && (info & SPELL_FORBIDDEN)) {
	        j[pos] = ' ';
        } else
	        j[pos] = '-';
      }
    }
  }
  // END OF LANG_hu section
  // try ngram approach since found nothing good suggestion
  if (!good && pAMgr && (slst.empty() || onlycmpdsug) && (pAMgr->get_maxngramsugs() != 0)) {
    switch (captype) {
      case NOCAP: {
        pSMgr->ngsuggest(slst, scw.c_str(), m_HMgrs, NOCAP);
        if (clock() > timelimit + TIMELIMIT_GLOBAL)
            return slst;
        break;
      }
      /* FALLTHROUGH */
      case HUHINITCAP:
        capwords = true;
      /* FALLTHROUGH */
      case HUHCAP: {
        std::string wspace(scw);
        mkallsmall2(wspace, sunicw);
        pSMgr->ngsuggest(slst, wspace.c_str(), m_HMgrs, HUHCAP);
        if (clock() > timelimit + TIMELIMIT_GLOBAL)
            return slst;
        break;
      }
      case INITCAP: {
        capwords = true;
        std::string wspace(scw);
        mkallsmall2(wspace, sunicw);
        pSMgr->ngsuggest(slst, wspace.c_str(), m_HMgrs, INITCAP);
        if (clock() > timelimit + TIMELIMIT_GLOBAL)
            return slst;
        break;
      }
      case ALLCAP: {
        std::string wspace(scw);
        mkallsmall2(wspace, sunicw);
        size_t oldns = slst.size();
        pSMgr->ngsuggest(slst, wspace.c_str(), m_HMgrs, ALLCAP);
        if (clock() > timelimit + TIMELIMIT_GLOBAL)
            return slst;
        for (size_t j = oldns; j < slst.size(); ++j) {
          mkallcap(slst[j]);
        }
        break;
      }
    }
  }

  // try dash suggestion (Afo-American -> Afro-American)
  // Note: LibreOffice was modified to treat dashes as word
  // characters to check "scot-free" etc. word forms, but
  // we need to handle suggestions for "Afo-American", etc.,
  // while "Afro-American" is missing from the dictionary.
  // TODO avoid possible overgeneration
  size_t dash_pos = scw.find('-');
  if (dash_pos != std::string::npos) {
    int nodashsug = 1;
    for (size_t j = 0; j < slst.size() && nodashsug == 1; ++j) {
      if (slst[j].find('-') != std::string::npos)
        nodashsug = 0;
    }

    size_t prev_pos = 0;
    bool last = false;

    while (!good && nodashsug && !last) {
      if (dash_pos == scw.size())
        last = 1;
      std::string chunk = scw.substr(prev_pos, dash_pos - prev_pos);
      if (chunk != word && !spell(chunk, spell_candidate_stack)) {
        std::vector<std::string> nlst = suggest(chunk, suggest_candidate_stack);
        if (clock() > timelimit + TIMELIMIT_GLOBAL)
            return slst;
        for (auto j = nlst.rbegin(); j != nlst.rend(); ++j) {
          std::string wspace = scw.substr(0, prev_pos);
          wspace.append(*j);
          if (!last) {
            wspace.append("-");
            wspace.append(scw.substr(dash_pos + 1));
          }
          int info = 0;
          if (pAMgr && pAMgr->get_forbiddenword())
            checkword(wspace, &info, NULL);
          if (!(info & SPELL_FORBIDDEN))
            insert_sug(slst, wspace);
        }
        nodashsug = 0;
      }
      if (!last) {
        prev_pos = dash_pos + 1;
        dash_pos = scw.find('-', prev_pos);
      }
      if (dash_pos == std::string::npos)
        dash_pos = scw.size();
    }
  }
  return slst;
}

const std::string& HunspellImpl::get_dict_encoding() const {
  return encoding;
}

std::vector<std::string> HunspellImpl::stem(const std::vector<std::string>& desc) {
  std::vector<std::string> slst;

  std::string result2;
  if (desc.empty())
    return slst;
  for (const auto& i : desc) {
    std::string result;

    // add compound word parts (except the last one)
    const char* s = i.c_str();
    const char* part = strstr(s, MORPH_PART);
    if (part) {
      const char* nextpart = strstr(part + 1, MORPH_PART);
      while (nextpart) {
        std::string field;
        copy_field(field, part, MORPH_PART);
        result.append(field);
        part = nextpart;
        nextpart = strstr(part + 1, MORPH_PART);
      }
      s = part;
    }

    std::string tok(s);
    size_t alt = 0;
    while ((alt = tok.find(" | ", alt)) != std::string::npos) {
      tok[alt + 1] = MSEP_ALT;
    }
    std::vector<std::string> pl = line_tok(tok, MSEP_ALT);
    for (auto& k : pl) {
      // add derivational suffixes
      if (k.find(MORPH_DERI_SFX) != std::string::npos) {
        // remove inflectional suffixes
        const size_t is = k.find(MORPH_INFL_SFX);
        if (is != std::string::npos)
	        k.resize(is);
        std::vector<std::string> singlepl;
        singlepl.push_back(k);
        std::string sg = pSMgr->suggest_gen(singlepl, k);
        if (!sg.empty()) {
          std::vector<std::string> gen = line_tok(sg, MSEP_REC);
          for (auto& j : gen) {
            result2.push_back(MSEP_REC);
            result2.append(result);
            result2.append(j);
          }
        }
      } else {
        result2.push_back(MSEP_REC);
        result2.append(result);
        if (k.find(MORPH_SURF_PFX) != std::string::npos) {
          std::string field;
          copy_field(field, k, MORPH_SURF_PFX);
          result2.append(field);
        }
        std::string field;
        copy_field(field, k, MORPH_STEM);
        result2.append(field);
      }
    }
  }
  slst = line_tok(result2, MSEP_REC);
  uniqlist(slst);
  return slst;
}

std::vector<std::string> HunspellImpl::stem(const std::string& word) {
  return stem(analyze(word));
}

const std::string& HunspellImpl::get_wordchars_cpp() const {
  return pAMgr->get_wordchars();
}

const std::vector<w_char>& HunspellImpl::get_wordchars_utf16() const {
  return pAMgr->get_wordchars_utf16();
}

void HunspellImpl::mkinitcap(std::string& u8) {
  if (utf8) {
    std::vector<w_char> u16;
    u8_u16(u16, u8);
    ::mkinitcap_utf(u16, langnum);
    u16_u8(u8, u16);
  } else {
    ::mkinitcap(u8, csconv);
  }
}

int HunspellImpl::mkinitcap2(std::string& u8, std::vector<w_char>& u16) {
  if (utf8) {
    ::mkinitcap_utf(u16, langnum);
    u16_u8(u8, u16);
  } else {
    ::mkinitcap(u8, csconv);
  }
  return u8.size();
}

int HunspellImpl::mkinitsmall2(std::string& u8, std::vector<w_char>& u16) {
  if (utf8) {
    ::mkinitsmall_utf(u16, langnum);
    u16_u8(u8, u16);
  } else {
    ::mkinitsmall(u8, csconv);
  }
  return u8.size();
}

int HunspellImpl::add(const std::string& word) {
  if (!m_HMgrs.empty())
    return m_HMgrs[0]->add(word);
  return 0;
}

int HunspellImpl::add_with_flags(const std::string& word, const std::string& flags, const std::string& desc) {
  if (!m_HMgrs.empty())
    return m_HMgrs[0]->add_with_flags(word, flags, desc);
  return 0;
}

int HunspellImpl::add_with_affix(const std::string& word, const std::string& example) {
  if (!m_HMgrs.empty())
    return m_HMgrs[0]->add_with_affix(word, example);
  return 0;
}

int HunspellImpl::remove(const std::string& word) {
  if (!m_HMgrs.empty())
    return m_HMgrs[0]->remove(word);
  return 0;
}

const std::string& HunspellImpl::get_version_cpp() const {
  return pAMgr->get_version();
}

struct cs_info* HunspellImpl::get_csconv() {
  return csconv;
}

void HunspellImpl::cat_result(std::string& result, const std::string& st) {
  if (!st.empty()) {
    if (!result.empty())
      result.append("\n");
    result.append(st);
  }
}

std::vector<std::string> HunspellImpl::analyze(const std::string& word) {
  std::vector<std::string> slst = analyze_internal(word);
  // output conversion
  RepList* rl = (pAMgr) ? pAMgr->get_oconvtable() : NULL;
  if (rl) {
    for (size_t i = 0; rl && i < slst.size(); ++i) {
      std::string wspace;
      if (rl->conv(slst[i], wspace)) {
        slst[i] = wspace;
      }
    }
  }
  return slst;
}

std::vector<std::string> HunspellImpl::analyze_internal(const std::string& word) {
  std::vector<std::string> candidate_stack, slst;
  if (!pSMgr || m_HMgrs.empty())
    return slst;
  if (utf8) {
    if (word.size() >= MAXWORDUTF8LEN)
      return slst;
  } else {
    if (word.size() >= MAXWORDLEN)
      return slst;
  }
  int captype = NOCAP;
  size_t abbv = 0;
  size_t wl = 0;

  std::string scw;
  std::vector<w_char> sunicw;

  // input conversion
  RepList* rl = (pAMgr) ? pAMgr->get_iconvtable() : NULL;
  {
    std::string wspace;

    bool convstatus = rl ? rl->conv(word, wspace) : false;
    if (convstatus)
      wl = cleanword2(scw, sunicw, wspace, &captype, &abbv);
    else
      wl = cleanword2(scw, sunicw, word, &captype, &abbv);
  }

  if (wl == 0) {
    if (abbv) {
      scw.clear();
      for (wl = 0; wl < abbv; wl++)
        scw.push_back('.');
      abbv = 0;
    } else
      return slst;
  }

  std::string result;

  size_t n = 0;
  // test numbers
  // LANG_hu section: set dash information for suggestions
  if (langnum == LANG_hu) {
    size_t n2 = 0;
    size_t n3 = 0;

    while ((n < wl) && (((scw[n] <= '9') && (scw[n] >= '0')) ||
                        (((scw[n] == '.') || (scw[n] == ',')) && (n > 0)))) {
      n++;
      if ((scw[n] == '.') || (scw[n] == ',')) {
        if (((n2 == 0) && (n > 3)) ||
            ((n2 > 0) && ((scw[n - 1] == '.') || (scw[n - 1] == ','))))
          break;
        n2++;
        n3 = n;
      }
    }

    if ((n == wl) && (n3 > 0) && (n - n3 > 3))
      return slst;
    if ((n == wl) || ((n > 0) && ((scw[n] == '%') || (scw[n] == '\xB0')) &&
                      checkword(scw.substr(n), NULL, NULL))) {
      result.append(scw);
      result.resize(n - 1);
      if (n == wl)
        cat_result(result, pSMgr->suggest_morph(scw.substr(n - 1)));
      else {
        std::string chunk = scw.substr(n - 1, 1);
        cat_result(result, pSMgr->suggest_morph(chunk));
        result.push_back('+');  // XXX SPEC. MORPHCODE
        cat_result(result, pSMgr->suggest_morph(scw.substr(n)));
      }
      return line_tok(result, MSEP_REC);
    }
  }
  // END OF LANG_hu section

  switch (captype) {
    case HUHCAP:
    case HUHINITCAP:
    case NOCAP: {
      cat_result(result, pSMgr->suggest_morph(scw));
      if (abbv) {
        std::string u8buffer(scw);
        u8buffer.push_back('.');
        cat_result(result, pSMgr->suggest_morph(u8buffer));
      }
      break;
    }
    case INITCAP: {
      mkallsmall2(scw, sunicw);
      std::string u8buffer(scw);
      mkinitcap2(scw, sunicw);
      cat_result(result, pSMgr->suggest_morph(u8buffer));
      cat_result(result, pSMgr->suggest_morph(scw));
      if (abbv) {
        u8buffer.push_back('.');
        cat_result(result, pSMgr->suggest_morph(u8buffer));

        u8buffer = scw;
        u8buffer.push_back('.');

        cat_result(result, pSMgr->suggest_morph(u8buffer));
      }
      break;
    }
    case ALLCAP: {
      cat_result(result, pSMgr->suggest_morph(scw));
      if (abbv) {
        std::string u8buffer(scw);
        u8buffer.push_back('.');
        cat_result(result, pSMgr->suggest_morph(u8buffer));
      }
      mkallsmall2(scw, sunicw);
      std::string u8buffer(scw);
      mkinitcap2(scw, sunicw);

      cat_result(result, pSMgr->suggest_morph(u8buffer));
      cat_result(result, pSMgr->suggest_morph(scw));
      if (abbv) {
        u8buffer.push_back('.');
        cat_result(result, pSMgr->suggest_morph(u8buffer));

        u8buffer = scw;
        u8buffer.push_back('.');

        cat_result(result, pSMgr->suggest_morph(u8buffer));
      }
      break;
    }
  }

  if (!result.empty()) {
    // word reversing wrapper for complex prefixes
    if (complexprefixes) {
      if (utf8)
        reverseword_utf(result);
      else
        reverseword(result);
    }
    return line_tok(result, MSEP_REC);
  }

  // compound word with dash (HU) I18n
  // LANG_hu section: set dash information for suggestions

  size_t dash_pos = langnum == LANG_hu ? scw.find('-') : std::string::npos;
  if (dash_pos != std::string::npos) {
    int nresult = 0;

    std::string part1 = scw.substr(0, dash_pos), part2 = scw.substr(dash_pos + 1);

    // examine 2 sides of the dash
    if (part2.empty()) {  // base word ending with dash
      if (spell(part1, candidate_stack)) {
        std::string p = pSMgr->suggest_morph(part1);
        if (!p.empty()) {
          slst = line_tok(p, MSEP_REC);
          return slst;
        }
      }
    } else if (part2.size() == 1 && part2[0] == 'e') {  // XXX (HU) -e hat.
      if (spell(part1, candidate_stack) && (spell("-e", candidate_stack))) {
        std::string st = pSMgr->suggest_morph(part1);
        if (!st.empty()) {
          result.append(st);
        }
        result.push_back('+');  // XXX spec. separator in MORPHCODE
        st = pSMgr->suggest_morph("-e");
        if (!st.empty()) {
          result.append(st);
        }
        return line_tok(result, MSEP_REC);
      }
    } else {
      // first word ending with dash: word- XXX ???
      part1.push_back(' ');
      nresult = spell(part1, candidate_stack);
      part1.erase(part1.size() - 1);
      if (nresult && spell(part2, candidate_stack) &&
          ((part2.size() > 1) || ((part2[0] > '0') && (part2[0] < '9')))) {
        std::string st = pSMgr->suggest_morph(part1);
        if (!st.empty()) {
          result.append(st);
          result.push_back('+');  // XXX spec. separator in MORPHCODE
        }
        st = pSMgr->suggest_morph(part2);
        if (!st.empty()) {
          result.append(st);
        }
        return line_tok(result, MSEP_REC);
      }
    }
    // affixed number in correct word
    if (nresult && (dash_pos > 0) &&
        (((scw[dash_pos - 1] <= '9') && (scw[dash_pos - 1] >= '0')) ||
         (scw[dash_pos - 1] == '.'))) {
      n = 1;
      if (scw[dash_pos - n] == '.')
        n++;
      // search first not a number character to left from dash
      while ((dash_pos >= n) && ((scw[dash_pos - n] == '0') || (n < 3)) &&
             (n < 6)) {
        n++;
      }
      if (dash_pos < n)
        n--;
      // numbers: valami1000000-hoz
      // examine 100000-hoz, 10000-hoz 1000-hoz, 10-hoz,
      // 56-hoz, 6-hoz
      for (; n >= 1; n--) {
        if (scw[dash_pos - n] < '0' || scw[dash_pos - n] > '9') {
            continue;
        }
        std::string chunk = scw.substr(dash_pos - n);
        if (checkword(chunk, NULL, NULL)) {
          result.append(chunk);
          std::string st = pSMgr->suggest_morph(chunk);
          if (!st.empty()) {
            result.append(st);
          }
          return line_tok(result, MSEP_REC);
        }
      }
    }
  }
  return slst;
}

std::vector<std::string> HunspellImpl::generate(const std::string& word, const std::vector<std::string>& pl) {
  std::vector<std::string> slst;
  if (!pSMgr || pl.empty())
    return slst;
  std::vector<std::string> pl2 = analyze(word);
  int captype = NOCAP, abbv = 0;
  std::string cw;
  cleanword(cw, word, &captype, &abbv);
  std::string result;

  for (const auto& i : pl) {
    cat_result(result, pSMgr->suggest_gen(pl2, i));
  }

  if (!result.empty()) {
    // allcap
    if (captype == ALLCAP)
      mkallcap(result);

    // line split
    slst = line_tok(result, MSEP_REC);

    // capitalize
    if (captype == INITCAP || captype == HUHINITCAP) {
      for (auto& str : slst) {
        mkinitcap(str);
      }
    }

    // temporary filtering of prefix related errors (eg.
    // generate("undrinkable", "eats") --> "undrinkables" and "*undrinks")
    auto it = slst.begin();
    while (it != slst.end()) {
      std::vector<std::string> candidate_stack;
      if (!spell(*it, candidate_stack)) {
        it = slst.erase(it);
      } else  {
        ++it;
      }
    }
  }
  return slst;
}

std::vector<std::string> HunspellImpl::generate(const std::string& word, const std::string& pattern) {
  std::vector<std::string> pl = analyze(pattern);
  std::vector<std::string> slst = generate(word, pl);
  uniqlist(slst);
  return slst;
}

// minimal XML parser functions
std::string HunspellImpl::get_xml_par(const std::string& in_par, std::string::size_type pos) {
  std::string dest;
  if (pos == std::string::npos)
    return dest;
  const char* par = in_par.c_str() + pos;
  char end = *par;
  if (end == '>')
    end = '<';
  else if (end != '\'' && end != '"')
    return dest;  // bad XML
  for (par++; *par != '\0' && *par != end; ++par) {
    dest.push_back(*par);
  }
  mystrrep(dest, "&lt;", "<");
  mystrrep(dest, "&amp;", "&");
  return dest;
}

int HunspellImpl::get_langnum() const {
  return langnum;
}

bool HunspellImpl::input_conv(const std::string& word, std::string& dest) {
  RepList* rl = pAMgr ? pAMgr->get_iconvtable() : NULL;
  if (rl) {
    return rl->conv(word, dest);
  }
  dest.assign(word);
  return false;
}

// return the beginning of the element (attr == NULL) or the attribute
std::string::size_type HunspellImpl::get_xml_pos(const std::string& s, std::string::size_type pos, const char* attr) {
  if (pos == std::string::npos)
    return std::string::npos;

  std::string::size_type endpos = s.find('>', pos);
  if (attr == NULL)
    return endpos;
  while (true) {
    pos = s.find(attr, pos);
    if (pos == std::string::npos || pos >= endpos)
      return std::string::npos;
    if (s[pos - 1] == ' ' || s[pos - 1] == '\n')
      break;
    pos += strlen(attr);
  }
  return pos + strlen(attr);
}

int HunspellImpl::check_xml_par(const std::string& q, std::string::size_type pos,
                                const char* attr,
                                const char* value) {
  const std::string cw = get_xml_par(q, get_xml_pos(q, pos, attr));
  return cw == value ? 1 : 0;
}

std::vector<std::string> HunspellImpl::get_xml_list(const std::string& list, std::string::size_type pos, const char* tag) {
  std::vector<std::string> slst;
  if (pos == std::string::npos)
    return slst;
  while (true) {
    pos = list.find(tag, pos);
    if (pos == std::string::npos)
        break;
    std::string cw = get_xml_par(list, pos + strlen(tag) - 1);
    if (cw.empty()) {
      break;
    }
    slst.push_back(cw);
    ++pos;
  }
  return slst;
}

std::vector<std::string> HunspellImpl::spellml(const std::string& in_word) {
  std::vector<std::string> slst;

  std::string::size_type qpos = in_word.find("<query");
  if (qpos == std::string::npos)
    return slst;  // bad XML input

  std::string::size_type q2pos = in_word.find('>', qpos);
  if (q2pos == std::string::npos)
    return slst;  // bad XML input

  q2pos = in_word.find("<word", q2pos);
  if (q2pos == std::string::npos)
    return slst;  // bad XML input

  if (check_xml_par(in_word, qpos, "type=", "analyze")) {
    std::string cw = get_xml_par(in_word, in_word.find('>', q2pos));
    if (!cw.empty())
      slst = analyze(cw);
    if (slst.empty())
      return slst;
    // convert the result to <code><a>ana1</a><a>ana2</a></code> format
    std::string r;
    r.append("<code>");
    for (auto entry : slst) {
      r.append("<a>");

      mystrrep(entry, "\t", " ");
      mystrrep(entry, "&", "&amp;");
      mystrrep(entry, "<", "&lt;");
      r.append(entry);

      r.append("</a>");
    }
    r.append("</code>");
    slst.clear();
    slst.push_back(r);
    return slst;
  } else if (check_xml_par(in_word, qpos, "type=", "stem")) {
    std::string cw = get_xml_par(in_word, in_word.find('>', q2pos));
    if (!cw.empty())
      return stem(cw);
  } else if (check_xml_par(in_word, qpos, "type=", "generate")) {
    std::string cw = get_xml_par(in_word, in_word.find('>', q2pos));
    if (cw.empty())
      return slst;
    std::string::size_type q3pos = in_word.find("<word", q2pos + 1);
    if (q3pos != std::string::npos) {
      std::string cw2 = get_xml_par(in_word, in_word.find('>', q3pos));
      if (!cw2.empty()) {
        return generate(cw, cw2);
      }
    } else {
      q2pos = in_word.find("<code", q2pos + 1);
      if (q2pos != std::string::npos) {
        std::vector<std::string> slst2 = get_xml_list(in_word, in_word.find('>', q2pos), "<a>");
        if (!slst2.empty()) {
          slst = generate(cw, slst2);
          uniqlist(slst);
          return slst;
        }
      }
    }
  } else if (check_xml_par(in_word, qpos, "type=", "add")) {
    std::string cw = get_xml_par(in_word, in_word.find('>', q2pos));
    if (cw.empty())
      return slst;
    std::string::size_type q3pos = in_word.find("<word", q2pos + 1);
    if (q3pos != std::string::npos) {
      std::string cw2 = get_xml_par(in_word, in_word.find('>', q3pos));
      if (!cw2.empty()) {
        add_with_affix(cw, cw2);
      } else {
        add(cw);
      }
    } else {
        add(cw);
    }
  }
  return slst;
}

std::vector<std::string> HunspellImpl::suffix_suggest(const std::string& root_word) {
  std::vector<std::string> slst;
  struct hentry* he = NULL;
  int len;
  std::string w2;
  const char* word;
  const char* ignoredchars = pAMgr->get_ignore();
  if (ignoredchars != NULL) {
    w2.assign(root_word);
    if (utf8) {
      const std::vector<w_char>& ignoredchars_utf16 =
          pAMgr->get_ignore_utf16();
      remove_ignored_chars_utf(w2, ignoredchars_utf16);
    } else {
      remove_ignored_chars(w2, ignoredchars);
    }
    word = w2.c_str();
    len = (int)w2.size();
  } else {
    word = root_word.c_str();
    len = (int)root_word.size();
  }

  if (!len)
    return slst;

  for (size_t i = 0; (i < m_HMgrs.size()) && !he; ++i) {
    he = m_HMgrs[i]->lookup(word, len);
  }
  if (he) {
    slst = pAMgr->get_suffix_words(he->astr, he->alen, root_word);
  }
  return slst;
}

namespace {
  // using malloc because this is for the c-api where the callers
  // expect to be able to use free
  char* stringdup(const std::string& s) {
    size_t sl = s.size() + 1;
    char* d = (char*)malloc(sl);
    if (d)
      memcpy(d, s.c_str(), sl);
    return d;
  }

  int munge_vector(char*** slst, const std::vector<std::string>& items) {
    if (items.empty()) {
      *slst = NULL;
      return 0;
    } else {
      *slst = new char*[items.size()];
      for (size_t i = 0; i < items.size(); ++i)
        (*slst)[i] = stringdup(items[i]);
    }
    return items.size();
  }
}

int HunspellImpl::spell(const char* word, int* info, char** root) {
  std::string sroot;
  std::vector<std::string> candidate_stack;
  bool ret = spell(word, candidate_stack, info, root ? &sroot : NULL);
  if (root) {
    if (sroot.empty()) {
      *root = NULL;
    } else {
      *root = stringdup(sroot);
    }
  }
  return ret;
}

int HunspellImpl::suggest(char*** slst, const char* word) {
  std::vector<std::string> suggests = suggest(word);
  return munge_vector(slst, suggests);
}

int HunspellImpl::suffix_suggest(char*** slst, const char* root_word) {
  std::vector<std::string> stems = suffix_suggest(root_word);
  return munge_vector(slst, stems);
}

void HunspellImpl::free_list(char*** slst, int n) {
  if (slst && *slst) {
    for (int i = 0; i < n; i++)
      free((*slst)[i]);
    delete[] *slst;
    *slst = NULL;
  }
}

char* HunspellImpl::get_dic_encoding() {
  return &encoding[0];
}

int HunspellImpl::analyze(char*** slst, const char* word) {
  std::vector<std::string> stems = analyze(word);
  return munge_vector(slst, stems);
}

int HunspellImpl::stem(char*** slst, const char* word) {
  std::vector<std::string> stems = stem(word);
  return munge_vector(slst, stems);
}

int HunspellImpl::stem(char*** slst, char** desc, int n) {
  std::vector<std::string> morph;
  morph.reserve(n);
  for (int i = 0; i < n; ++i) morph.emplace_back(desc[i]);

  std::vector<std::string> stems = stem(morph);
  return munge_vector(slst, stems);
}

int HunspellImpl::generate(char*** slst, const char* word, const char* pattern) {
  std::vector<std::string> stems = generate(word, pattern);
  return munge_vector(slst, stems);
}

int HunspellImpl::generate(char*** slst, const char* word, char** pl, int pln) {
  std::vector<std::string> morph;
  morph.reserve(pln);
  for (int i = 0; i < pln; ++i) morph.emplace_back(pl[i]);

  std::vector<std::string> stems = generate(word, morph);
  return munge_vector(slst, stems);
}

const char* HunspellImpl::get_wordchars() const {
  return get_wordchars_cpp().c_str();
}

const char* HunspellImpl::get_version() const {
  return get_version_cpp().c_str();
}

int HunspellImpl::input_conv(const char* word, char* dest, size_t destsize) {
  std::string d;
  bool ret = input_conv(word, d);
  if (ret && d.size() < destsize) {
    strncpy(dest, d.c_str(), destsize);
    return 1;
  }
  return 0;
}

Hunspell::Hunspell(const char* affpath, const char* dpath, const char* key)
  : m_Impl(new HunspellImpl(affpath, dpath, key)) {
}

Hunspell::~Hunspell() {
  delete m_Impl;
}

// load extra dictionaries
int Hunspell::add_dic(const char* dpath, const char* key) {
  return m_Impl->add_dic(dpath, key);
}

bool Hunspell::spell(const std::string& word, int* info, std::string* root) {
  std::vector<std::string> candidate_stack;
  return m_Impl->spell(word, candidate_stack, info, root);
}

std::vector<std::string> Hunspell::suggest(const std::string& word) {
  return m_Impl->suggest(word);
}

std::vector<std::string> Hunspell::suffix_suggest(const std::string& root_word) {
  return m_Impl->suffix_suggest(root_word);
}

const std::string& Hunspell::get_dict_encoding() const {
  return m_Impl->get_dict_encoding();
}

std::vector<std::string> Hunspell::stem(const std::vector<std::string>& desc) {
  return m_Impl->stem(desc);
}

std::vector<std::string> Hunspell::stem(const std::string& word) {
  return m_Impl->stem(word);
}

const std::string& Hunspell::get_wordchars_cpp() const {
  return m_Impl->get_wordchars_cpp();
}

const std::vector<w_char>& Hunspell::get_wordchars_utf16() const {
  return m_Impl->get_wordchars_utf16();
}

int Hunspell::add(const std::string& word) {
  return m_Impl->add(word);
}

int Hunspell::add_with_flags(const std::string& word, const std::string& flags, const std::string& desc) {
  return m_Impl->add_with_flags(word, flags, desc);
}

int Hunspell::add_with_affix(const std::string& word, const std::string& example) {
  return m_Impl->add_with_affix(word, example);
}

int Hunspell::remove(const std::string& word) {
  return m_Impl->remove(word);
}

const std::string& Hunspell::get_version_cpp() const {
  return m_Impl->get_version_cpp();
}

struct cs_info* Hunspell::get_csconv() {
  return m_Impl->get_csconv();
}

std::vector<std::string> Hunspell::analyze(const std::string& word) {
  return m_Impl->analyze(word);
}

std::vector<std::string> Hunspell::generate(const std::string& word, const std::vector<std::string>& pl) {
  return m_Impl->generate(word, pl);
}

std::vector<std::string> Hunspell::generate(const std::string& word, const std::string& pattern) {
  return m_Impl->generate(word, pattern);
}

int Hunspell::get_langnum() const {
  return m_Impl->get_langnum();
}

bool Hunspell::input_conv(const std::string& word, std::string& dest) {
  return m_Impl->input_conv(word, dest);
}

int Hunspell::spell(const char* word, int* info, char** root) {
  return m_Impl->spell(word, info, root);
}

int Hunspell::suggest(char*** slst, const char* word) {
  return m_Impl->suggest(slst, word);
}

int Hunspell::suffix_suggest(char*** slst, const char* root_word) {
  return m_Impl->suffix_suggest(slst, root_word);
}

void Hunspell::free_list(char*** slst, int n) {
  m_Impl->free_list(slst, n);
}

char* Hunspell::get_dic_encoding() {
  return m_Impl->get_dic_encoding();
}

int Hunspell::analyze(char*** slst, const char* word) {
  return m_Impl->analyze(slst, word);
}

int Hunspell::stem(char*** slst, const char* word) {
  return m_Impl->stem(slst, word);
}

int Hunspell::stem(char*** slst, char** desc, int n) {
  return m_Impl->stem(slst, desc, n);
}

int Hunspell::generate(char*** slst, const char* word, const char* pattern) {
  return m_Impl->generate(slst, word, pattern);
}

int Hunspell::generate(char*** slst, const char* word, char** pl, int pln) {
  return m_Impl->generate(slst, word, pl, pln);
}

const char* Hunspell::get_wordchars() const {
  return m_Impl->get_wordchars();
}

const char* Hunspell::get_version() const {
  return m_Impl->get_version();
}

int Hunspell::input_conv(const char* word, char* dest, size_t destsize) {
  return m_Impl->input_conv(word, dest, destsize);
}

Hunhandle* Hunspell_create(const char* affpath, const char* dpath) {
  return reinterpret_cast<Hunhandle*>(new HunspellImpl(affpath, dpath));
}

Hunhandle* Hunspell_create_key(const char* affpath,
                               const char* dpath,
                               const char* key) {
  return reinterpret_cast<Hunhandle*>(new HunspellImpl(affpath, dpath, key));
}

void Hunspell_destroy(Hunhandle* pHunspell) {
  delete reinterpret_cast<HunspellImpl*>(pHunspell);
}

int Hunspell_add_dic(Hunhandle* pHunspell, const char* dpath) {
  return reinterpret_cast<HunspellImpl*>(pHunspell)->add_dic(dpath);
}

int Hunspell_spell(Hunhandle* pHunspell, const char* word) {
  return reinterpret_cast<HunspellImpl*>(pHunspell)->spell(word);
}

char* Hunspell_get_dic_encoding(Hunhandle* pHunspell) {
  return reinterpret_cast<HunspellImpl*>(pHunspell)->get_dic_encoding();
}

int Hunspell_suggest(Hunhandle* pHunspell, char*** slst, const char* word) {
  return reinterpret_cast<HunspellImpl*>(pHunspell)->suggest(slst, word);
}

int Hunspell_suffix_suggest(Hunhandle* pHunspell, char*** slst, const char* root_word) {
  return reinterpret_cast<HunspellImpl*>(pHunspell)->suffix_suggest(slst, root_word);
}

int Hunspell_analyze(Hunhandle* pHunspell, char*** slst, const char* word) {
  return reinterpret_cast<HunspellImpl*>(pHunspell)->analyze(slst, word);
}

int Hunspell_stem(Hunhandle* pHunspell, char*** slst, const char* word) {
  return reinterpret_cast<HunspellImpl*>(pHunspell)->stem(slst, word);
}

int Hunspell_stem2(Hunhandle* pHunspell, char*** slst, char** desc, int n) {
  return reinterpret_cast<HunspellImpl*>(pHunspell)->stem(slst, desc, n);
}

int Hunspell_generate(Hunhandle* pHunspell,
                      char*** slst,
                      const char* word,
                      const char* pattern)
{
  return reinterpret_cast<HunspellImpl*>(pHunspell)->generate(slst, word, pattern);
}

int Hunspell_generate2(Hunhandle* pHunspell,
                       char*** slst,
                       const char* word,
                       char** desc,
                       int n)
{
  return reinterpret_cast<HunspellImpl*>(pHunspell)->generate(slst, word, desc, n);
}

/* functions for run-time modification of the dictionary */

/* add word to the run-time dictionary */

int Hunspell_add(Hunhandle* pHunspell, const char* word) {
  return reinterpret_cast<HunspellImpl*>(pHunspell)->add(word);
}

int Hunspell_add_with_flags(Hunhandle* pHunspell, const char* word, const char* flags, const char* desc) {
  return reinterpret_cast<HunspellImpl*>(pHunspell)->add_with_flags(word, flags, desc);
}

/* add word to the run-time dictionary with affix flags of
 * the example (a dictionary word): Hunspell will recognize
 * affixed forms of the new word, too.
 */

int Hunspell_add_with_affix(Hunhandle* pHunspell,
                            const char* word,
                            const char* example) {
  return reinterpret_cast<HunspellImpl*>(pHunspell)->add_with_affix(word, example);
}

/* remove word from the run-time dictionary */

int Hunspell_remove(Hunhandle* pHunspell, const char* word) {
  return reinterpret_cast<HunspellImpl*>(pHunspell)->remove(word);
}

void Hunspell_free_list(Hunhandle* pHunspell, char*** list, int n) {
  reinterpret_cast<HunspellImpl*>(pHunspell)->free_list(list, n);
}
