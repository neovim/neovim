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
#include <cctype>

#include "affentry.hxx"
#include "csutil.hxx"

AffEntry::~AffEntry() {
  if (opts & aeLONGCOND)
    delete[] c.l.conds2;
  if (morphcode && !(opts & aeALIASM))
    delete[] morphcode;
  if (contclass && !(opts & aeALIASF))
    delete[] contclass;
}

PfxEntry::PfxEntry(AffixMgr* pmgr)
    // register affix manager
    : pmyMgr(pmgr),
      next(NULL),
      nexteq(NULL),
      nextne(NULL),
      flgnxt(NULL) {
}

// add prefix to this word assuming conditions hold
std::string PfxEntry::add(const char* word, size_t len) {
  std::string result;
  if ((len > strip.size() || (len == 0 && pmyMgr->get_fullstrip())) &&
      (len >= numconds) && test_condition(word) &&
      (strip.empty() ||
      (len >= strip.size() && strncmp(word, strip.c_str(), strip.size()) == 0))) {
    /* we have a match so add prefix */
    result.assign(appnd);
    result.append(word + strip.size());
  }
  return result;
}

inline char* PfxEntry::nextchar(char* p) {
  if (p) {
    p++;
    if (opts & aeLONGCOND) {
      // jump to the 2nd part of the condition
      if (p == c.conds + MAXCONDLEN_1)
        return c.l.conds2;
      // end of the MAXCONDLEN length condition
    } else if (p == c.conds + MAXCONDLEN)
      return NULL;
    return *p ? p : NULL;
  }
  return NULL;
}

inline int PfxEntry::test_condition(const std::string& s) {
  size_t st = 0;
  size_t pos = std::string::npos;  // group with pos input position
  bool neg = false;        // complementer
  bool ingroup = false;    // character in the group
  if (numconds == 0)
    return 1;
  char* p = c.conds;
  while (1) {
    switch (*p) {
      case '\0':
        return 1;
      case '[': {
        neg = false;
        ingroup = false;
        p = nextchar(p);
        pos = st;
        break;
      }
      case '^': {
        p = nextchar(p);
        neg = true;
        break;
      }
      case ']': {
        if (bool(neg) == bool(ingroup))
          return 0;
        pos = std::string::npos;
        p = nextchar(p);
        // skip the next character
        if (!ingroup && st < s.size()) {
          ++st;
          while ((opts & aeUTF8) && st < s.size() && (s[st] & 0xc0) == 0x80)
            ++st;
        }
        if (st == s.size() && p)
          return 0;  // word <= condition
        break;
      }
      case '.':
        if (pos == std::string::npos) {  // dots are not metacharacters in groups: [.]
          p = nextchar(p);
          // skip the next character
          ++st;
          while ((opts & aeUTF8) && st < s.size() && (s[st] & 0xc0) == 0x80)
            ++st;
          if (st == s.size() && p)
            return 0;  // word <= condition
          break;
        }
      /* FALLTHROUGH */
      default: {
        if (st < s.size() && s[st] == *p) {
          ++st;
          p = nextchar(p);
          if ((opts & aeUTF8) && (s[st - 1] & 0x80)) {  // multibyte
            while (p && (*p & 0xc0) == 0x80) {          // character
              if (*p != s[st]) {
                if (pos == std::string::npos)
                  return 0;
                st = pos;
                break;
              }
              p = nextchar(p);
              ++st;
            }
            if (pos != std::string::npos && st != pos) {
              ingroup = true;
              while (p && *p != ']' && ((p = nextchar(p)) != NULL)) {
              }
            }
          } else if (pos != std::string::npos) {
            ingroup = true;
            while (p && *p != ']' && ((p = nextchar(p)) != NULL)) {
            }
          }
        } else if (pos != std::string::npos) {  // group
          p = nextchar(p);
        } else
          return 0;
      }
    }
    if (!p)
      return 1;
  }
}

// check if this prefix entry matches
struct hentry* PfxEntry::checkword(const std::string& word,
                                   int start,
                                   int len,
                                   char in_compound,
                                   const FLAG needflag) {
  struct hentry* he;  // hash entry of root word or NULL

  // on entry prefix is 0 length or already matches the beginning of the word.
  // So if the remaining root word has positive length
  // and if there are enough chars in root word and added back strip chars
  // to meet the number of characters conditions, then test it

  int tmpl = len - appnd.size(); // length of tmpword

  if (tmpl > 0 || (tmpl == 0 && pmyMgr->get_fullstrip())) {
    // generate new root word by removing prefix and adding
    // back any characters that would have been stripped

    std::string tmpword(strip);
    tmpword.append(word, start + appnd.size(), tmpl);

    // now make sure all of the conditions on characters
    // are met.  Please see the appendix at the end of
    // this file for more info on exactly what is being
    // tested

    // if all conditions are met then check if resulting
    // root word in the dictionary

    if (test_condition(tmpword)) {
      tmpl += strip.size();
      if ((he = pmyMgr->lookup(tmpword.c_str(), tmpword.size())) != NULL) {
        do {
          if (TESTAFF(he->astr, aflag, he->alen) &&
              // forbid single prefixes with needaffix flag
              !TESTAFF(contclass, pmyMgr->get_needaffix(), contclasslen) &&
              // needflag
              ((!needflag) || TESTAFF(he->astr, needflag, he->alen) ||
               (contclass && TESTAFF(contclass, needflag, contclasslen))))
            return he;
          he = he->next_homonym;  // check homonyms
        } while (he);
      }

      // prefix matched but no root word was found
      // if aeXPRODUCT is allowed, try again but now
      // ross checked combined with a suffix

      // if ((opts & aeXPRODUCT) && in_compound) {
      if ((opts & aeXPRODUCT)) {
        he = pmyMgr->suffix_check(tmpword, 0, tmpl, aeXPRODUCT, this,
                                  FLAG_NULL, needflag, in_compound);
        if (he)
          return he;
      }
    }
  }
  return NULL;
}

// check if this prefix entry matches
struct hentry* PfxEntry::check_twosfx(const std::string& word,
                                      int start,
                                      int len,
                                      char in_compound,
                                      const FLAG needflag) {
  // on entry prefix is 0 length or already matches the beginning of the word.
  // So if the remaining root word has positive length
  // and if there are enough chars in root word and added back strip chars
  // to meet the number of characters conditions, then test it

  int tmpl = len - appnd.size(); // length of tmpword

  if ((tmpl > 0 || (tmpl == 0 && pmyMgr->get_fullstrip())) &&
      (tmpl + strip.size() >= numconds)) {
    // generate new root word by removing prefix and adding
    // back any characters that would have been stripped

    std::string tmpword(strip);
    tmpword.append(word, start + appnd.size(), tmpl);

    // now make sure all of the conditions on characters
    // are met.  Please see the appendix at the end of
    // this file for more info on exactly what is being
    // tested

    // if all conditions are met then check if resulting
    // root word in the dictionary

    if (test_condition(tmpword)) {
      tmpl += strip.size();

      // prefix matched but no root word was found
      // if aeXPRODUCT is allowed, try again but now
      // cross checked combined with a suffix

      if ((opts & aeXPRODUCT) && (in_compound != IN_CPD_BEGIN)) {
        // hash entry of root word or NULL
        struct hentry* he = pmyMgr->suffix_check_twosfx(tmpword, 0, tmpl, aeXPRODUCT, this,
                                                        needflag);
        if (he)
          return he;
      }
    }
  }
  return NULL;
}

// check if this prefix entry matches
std::string PfxEntry::check_twosfx_morph(const std::string& word,
                                         int start,
                                         int len,
                                         char in_compound,
                                         const FLAG needflag) {
  std::string result;
  // on entry prefix is 0 length or already matches the beginning of the word.
  // So if the remaining root word has positive length
  // and if there are enough chars in root word and added back strip chars
  // to meet the number of characters conditions, then test it
  int tmpl = len - appnd.size(); // length of tmpword

  if ((tmpl > 0 || (tmpl == 0 && pmyMgr->get_fullstrip())) &&
      (tmpl + strip.size() >= numconds)) {
    // generate new root word by removing prefix and adding
    // back any characters that would have been stripped

    std::string tmpword(strip);
    tmpword.append(word, start + appnd.size(), tmpl);

    // now make sure all of the conditions on characters
    // are met.  Please see the appendix at the end of
    // this file for more info on exactly what is being
    // tested

    // if all conditions are met then check if resulting
    // root word in the dictionary

    if (test_condition(tmpword)) {
      tmpl += strip.size();

      // prefix matched but no root word was found
      // if aeXPRODUCT is allowed, try again but now
      // ross checked combined with a suffix

      if ((opts & aeXPRODUCT) && (in_compound != IN_CPD_BEGIN)) {
        result = pmyMgr->suffix_check_twosfx_morph(tmpword, 0, tmpl,
                                                   aeXPRODUCT,
                                                   this, needflag);
      }
    }
  }
  return result;
}

// check if this prefix entry matches
std::string PfxEntry::check_morph(const std::string& word,
                                  int start,
                                  int len,
                                  char in_compound,
                                  const FLAG needflag) {
  std::string result;

  // on entry prefix is 0 length or already matches the beginning of the word.
  // So if the remaining root word has positive length
  // and if there are enough chars in root word and added back strip chars
  // to meet the number of characters conditions, then test it

  int tmpl = len - appnd.size(); // length of tmpword

  if ((tmpl > 0 || (tmpl == 0 && pmyMgr->get_fullstrip())) &&
      (tmpl + strip.size() >= numconds)) {
    // generate new root word by removing prefix and adding
    // back any characters that would have been stripped

    std::string tmpword(strip);
    tmpword.append(word, start + appnd.size(), tmpl);

    // now make sure all of the conditions on characters
    // are met.  Please see the appendix at the end of
    // this file for more info on exactly what is being
    // tested

    // if all conditions are met then check if resulting
    // root word in the dictionary

    if (test_condition(tmpword)) {
      tmpl += strip.size();
      struct hentry* he;  // hash entry of root word or NULL
      if ((he = pmyMgr->lookup(tmpword.c_str(), tmpword.size())) != NULL) {
        do {
          if (TESTAFF(he->astr, aflag, he->alen) &&
              // forbid single prefixes with needaffix flag
              !TESTAFF(contclass, pmyMgr->get_needaffix(), contclasslen) &&
              // needflag
              ((!needflag) || TESTAFF(he->astr, needflag, he->alen) ||
               (contclass && TESTAFF(contclass, needflag, contclasslen)))) {
            if (morphcode) {
              result.push_back(MSEP_FLD);
              result.append(morphcode);
            } else
              result.append(getKey());
            if (!HENTRY_FIND(he, MORPH_STEM)) {
              result.push_back(MSEP_FLD);
              result.append(MORPH_STEM);
              result.append(HENTRY_WORD(he));
            }
            // store the pointer of the hash entry
            if (HENTRY_DATA(he)) {
              result.push_back(MSEP_FLD);
              result.append(HENTRY_DATA2(he));
            } else {
              // return with debug information
              std::string flag = pmyMgr->encode_flag(getFlag());
              result.push_back(MSEP_FLD);
              result.append(MORPH_FLAG);
              result.append(flag);
            }
            result.push_back(MSEP_REC);
          }
          he = he->next_homonym;
        } while (he);
      }

      // prefix matched but no root word was found
      // if aeXPRODUCT is allowed, try again but now
      // ross checked combined with a suffix

      if ((opts & aeXPRODUCT) && (in_compound != IN_CPD_BEGIN)) {
        std::string st = pmyMgr->suffix_check_morph(tmpword, 0, tmpl, aeXPRODUCT, this,
                                                    FLAG_NULL, needflag);
        if (!st.empty()) {
          result.append(st);
        }
      }
    }
  }

  return result;
}

SfxEntry::SfxEntry(AffixMgr* pmgr)
    : pmyMgr(pmgr)  // register affix manager
      ,
      next(NULL),
      nexteq(NULL),
      nextne(NULL),
      flgnxt(NULL),
      l_morph(NULL),
      r_morph(NULL),
      eq_morph(NULL) {
}

// add suffix to this word assuming conditions hold
std::string SfxEntry::add(const char* word, size_t len) {
  std::string result;
  /* make sure all conditions match */
  if ((len > strip.size() || (len == 0 && pmyMgr->get_fullstrip())) &&
      (len >= numconds) && test_condition(word + len, word) &&
      (strip.empty() ||
       (len >= strip.size() && strcmp(word + len - strip.size(), strip.c_str()) == 0))) {
    result.assign(word, len);
    /* we have a match so add suffix */
    result.replace(len - strip.size(), std::string::npos, appnd);
  }
  return result;
}

inline char* SfxEntry::nextchar(char* p) {
  if (p) {
    p++;
    if (opts & aeLONGCOND) {
      // jump to the 2nd part of the condition
      if (p == c.l.conds1 + MAXCONDLEN_1)
        return c.l.conds2;
      // end of the MAXCONDLEN length condition
    } else if (p == c.conds + MAXCONDLEN)
      return NULL;
    return *p ? p : NULL;
  }
  return NULL;
}

inline int SfxEntry::test_condition(const char* st, const char* beg) {
  const char* pos = NULL;  // group with pos input position
  bool neg = false;        // complementer
  bool ingroup = false;    // character in the group
  if (numconds == 0)
    return 1;
  char* p = c.conds;
  st--;
  int i = 1;
  while (1) {
    switch (*p) {
      case '\0':
        return 1;
      case '[':
        p = nextchar(p);
        pos = st;
        break;
      case '^':
        p = nextchar(p);
        neg = true;
        break;
      case ']':
        if (!neg && !ingroup)
          return 0;
        i++;
        // skip the next character
        if (!ingroup) {
          for (; (opts & aeUTF8) && (st >= beg) && (*st & 0xc0) == 0x80; st--)
            ;
          st--;
        }
        pos = NULL;
        neg = false;
        ingroup = false;
        p = nextchar(p);
        if (st < beg && p)
          return 0;  // word <= condition
        break;
      case '.':
        if (!pos) {
          // dots are not metacharacters in groups: [.]
          p = nextchar(p);
          // skip the next character
          for (st--; (opts & aeUTF8) && (st >= beg) && (*st & 0xc0) == 0x80;
               st--)
            ;
          if (st < beg) {  // word <= condition
            if (p)
              return 0;
            else
              return 1;
          }
          if ((opts & aeUTF8) && (*st & 0x80)) {  // head of the UTF-8 character
            st--;
            if (st < beg) {  // word <= condition
              if (p)
                return 0;
              else
                return 1;
            }
          }
          break;
        }
      /* FALLTHROUGH */
      default: {
        if (*st == *p) {
          p = nextchar(p);
          if ((opts & aeUTF8) && (*st & 0x80)) {
            st--;
            while (p && (st >= beg)) {
              if (*p != *st) {
                if (!pos)
                  return 0;
                st = pos;
                break;
              }
              // first byte of the UTF-8 multibyte character
              if ((*p & 0xc0) != 0x80)
                break;
              p = nextchar(p);
              st--;
            }
            if (pos && st != pos) {
              if (neg)
                return 0;
              else if (i == numconds)
                return 1;
              ingroup = true;
              while (p && *p != ']' && ((p = nextchar(p)) != NULL)) {
              }
              st--;
            }
            if (p && *p != ']')
              p = nextchar(p);
          } else if (pos) {
            if (neg)
              return 0;
            else if (i == numconds)
              return 1;
            ingroup = true;
            while (p && *p != ']' && ((p = nextchar(p)) != NULL)) {
            }
            //			if (p && *p != ']') p = nextchar(p);
            st--;
          }
          if (!pos) {
            i++;
            st--;
          }
          if (st < beg && p && *p != ']')
            return 0;      // word <= condition
        } else if (pos) {  // group
          p = nextchar(p);
        } else
          return 0;
      }
    }
    if (!p)
      return 1;
  }
}

// see if this suffix is present in the word
struct hentry* SfxEntry::checkword(const std::string& word,
                                   int start,
                                   int len,
                                   int optflags,
                                   PfxEntry* ppfx,
                                   const FLAG cclass,
                                   const FLAG needflag,
                                   const FLAG badflag) {
  struct hentry* he;  // hash entry pointer
  PfxEntry* ep = ppfx;

  // if this suffix is being cross checked with a prefix
  // but it does not support cross products skip it

  if (((optflags & aeXPRODUCT) != 0) && ((opts & aeXPRODUCT) == 0))
    return NULL;

  // upon entry suffix is 0 length or already matches the end of the word.
  // So if the remaining root word has positive length
  // and if there are enough chars in root word and added back strip chars
  // to meet the number of characters conditions, then test it

  int tmpl = len - appnd.size(); // length of tmpword
  // the second condition is not enough for UTF-8 strings
  // it checked in test_condition()

  if ((tmpl > 0 || (tmpl == 0 && pmyMgr->get_fullstrip())) &&
      (tmpl + strip.size() >= numconds)) {
    // generate new root word by removing suffix and adding
    // back any characters that would have been stripped or
    // or null terminating the shorter string

    std::string tmpstring(word, start, tmpl);
    if (!strip.empty()) {
      tmpstring.append(strip);
    }

    const char* tmpword = tmpstring.c_str();
    const char* endword = tmpword + tmpstring.size();

    // now make sure all of the conditions on characters
    // are met.  Please see the appendix at the end of
    // this file for more info on exactly what is being
    // tested

    // if all conditions are met then check if resulting
    // root word in the dictionary

    if (test_condition(endword, tmpword)) {
#ifdef SZOSZABLYA_POSSIBLE_ROOTS
      fprintf(stdout, "%s %s %c\n", word.c_str() + start, tmpword, aflag);
#endif
      if ((he = pmyMgr->lookup(tmpstring.c_str(), tmpstring.size())) != NULL) {
        do {
          // check conditional suffix (enabled by prefix)
          if ((TESTAFF(he->astr, aflag, he->alen) ||
               (ep && ep->getCont() &&
                TESTAFF(ep->getCont(), aflag, ep->getContLen()))) &&
              (((optflags & aeXPRODUCT) == 0) ||
               (ep && TESTAFF(he->astr, ep->getFlag(), he->alen)) ||
               // enabled by prefix
               ((contclass) &&
                (ep && TESTAFF(contclass, ep->getFlag(), contclasslen)))) &&
              // handle cont. class
              ((!cclass) ||
               ((contclass) && TESTAFF(contclass, cclass, contclasslen))) &&
              // check only in compound homonyms (bad flags)
              (!badflag || !TESTAFF(he->astr, badflag, he->alen)) &&
              // handle required flag
              ((!needflag) ||
               (TESTAFF(he->astr, needflag, he->alen) ||
                ((contclass) && TESTAFF(contclass, needflag, contclasslen)))))
            return he;
          he = he->next_homonym;  // check homonyms
        } while (he);
      }
    }
  }
  return NULL;
}

// see if two-level suffix is present in the word
struct hentry* SfxEntry::check_twosfx(const std::string& word,
                                      int start,
                                      int len,
                                      int optflags,
                                      PfxEntry* ppfx,
                                      const FLAG needflag) {
  PfxEntry* ep = ppfx;

  // if this suffix is being cross checked with a prefix
  // but it does not support cross products skip it

  if ((optflags & aeXPRODUCT) != 0 && (opts & aeXPRODUCT) == 0)
    return NULL;

  // upon entry suffix is 0 length or already matches the end of the word.
  // So if the remaining root word has positive length
  // and if there are enough chars in root word and added back strip chars
  // to meet the number of characters conditions, then test it

  int tmpl = len - appnd.size(); // length of tmpword

  if ((tmpl > 0 || (tmpl == 0 && pmyMgr->get_fullstrip())) &&
      (tmpl + strip.size() >= numconds)) {
    // generate new root word by removing suffix and adding
    // back any characters that would have been stripped or
    // or null terminating the shorter string

    std::string tmpword(word, start);
    tmpword.resize(tmpl);
    tmpword.append(strip);
    tmpl += strip.size();

    const char* beg = tmpword.c_str();
    const char* end = beg + tmpl;

    // now make sure all of the conditions on characters
    // are met.  Please see the appendix at the end of
    // this file for more info on exactly what is being
    // tested

    // if all conditions are met then recall suffix_check

    if (test_condition(end, beg)) {
      struct hentry* he;  // hash entry pointer
      if (ppfx) {
        // handle conditional suffix
        if ((contclass) && TESTAFF(contclass, ep->getFlag(), contclasslen))
          he = pmyMgr->suffix_check(tmpword, 0, tmpl, 0, NULL,
                                    (FLAG)aflag, needflag, IN_CPD_NOT);
        else
          he = pmyMgr->suffix_check(tmpword, 0, tmpl, optflags, ppfx,
                                    (FLAG)aflag, needflag, IN_CPD_NOT);
      } else {
        he = pmyMgr->suffix_check(tmpword, 0, tmpl, 0, NULL,
                                  (FLAG)aflag, needflag, IN_CPD_NOT);
      }
      if (he)
        return he;
    }
  }
  return NULL;
}

// see if two-level suffix is present in the word
std::string SfxEntry::check_twosfx_morph(const std::string& word,
                                         int start,
                                         int len,
                                         int optflags,
                                         PfxEntry* ppfx,
                                         const FLAG needflag) {
  PfxEntry* ep = ppfx;

  std::string result;

  // if this suffix is being cross checked with a prefix
  // but it does not support cross products skip it

  if ((optflags & aeXPRODUCT) != 0 && (opts & aeXPRODUCT) == 0)
    return result;

  // upon entry suffix is 0 length or already matches the end of the word.
  // So if the remaining root word has positive length
  // and if there are enough chars in root word and added back strip chars
  // to meet the number of characters conditions, then test it

  int tmpl = len - appnd.size(); // length of tmpword

  if ((tmpl > 0 || (tmpl == 0 && pmyMgr->get_fullstrip())) &&
      (tmpl + strip.size() >= numconds)) {
    // generate new root word by removing suffix and adding
    // back any characters that would have been stripped or
    // or null terminating the shorter string

    std::string tmpword(word, start);
    tmpword.resize(tmpl);
    tmpword.append(strip);
    tmpl += strip.size();

    const char* beg = tmpword.c_str();
    const char* end = beg + tmpl;

    // now make sure all of the conditions on characters
    // are met.  Please see the appendix at the end of
    // this file for more info on exactly what is being
    // tested

    // if all conditions are met then recall suffix_check

    if (test_condition(end, beg)) {
      if (ppfx) {
        // handle conditional suffix
        if ((contclass) && TESTAFF(contclass, ep->getFlag(), contclasslen)) {
          std::string st = pmyMgr->suffix_check_morph(tmpword, 0, tmpl, 0, NULL, aflag,
                                                      needflag);
          if (!st.empty()) {
            if (ppfx->getMorph()) {
              result.append(ppfx->getMorph());
              result.push_back(MSEP_FLD);
            }
            result.append(st);
            mychomp(result);
          }
        } else {
          std::string st = pmyMgr->suffix_check_morph(tmpword, 0, tmpl, optflags, ppfx, aflag,
                                                      needflag);
          if (!st.empty()) {
            result.append(st);
            mychomp(result);
          }
        }
      } else {
        std::string st = pmyMgr->suffix_check_morph(tmpword, 0, tmpl, 0, NULL, aflag, needflag);
        if (!st.empty()) {
          result.append(st);
          mychomp(result);
        }
      }
    }
  }
  return result;
}

// get next homonym with same affix
struct hentry* SfxEntry::get_next_homonym(struct hentry* he,
                                          int optflags,
                                          PfxEntry* ppfx,
                                          const FLAG cclass,
                                          const FLAG needflag) {
  PfxEntry* ep = ppfx;
  FLAG eFlag = ep ? ep->getFlag() : FLAG_NULL;

  while (he->next_homonym) {
    he = he->next_homonym;
    if ((TESTAFF(he->astr, aflag, he->alen) ||
         (ep && ep->getCont() &&
          TESTAFF(ep->getCont(), aflag, ep->getContLen()))) &&
        ((optflags & aeXPRODUCT) == 0 || TESTAFF(he->astr, eFlag, he->alen) ||
         // handle conditional suffix
         ((contclass) && TESTAFF(contclass, eFlag, contclasslen))) &&
        // handle cont. class
        ((!cclass) ||
         ((contclass) && TESTAFF(contclass, cclass, contclasslen))) &&
        // handle required flag
        ((!needflag) ||
         (TESTAFF(he->astr, needflag, he->alen) ||
          ((contclass) && TESTAFF(contclass, needflag, contclasslen)))))
      return he;
  }
  return NULL;
}

void SfxEntry::initReverseWord() {
  rappnd = appnd;
  reverseword(rappnd);
}

#if 0

Appendix:  Understanding Affix Code


An affix is either a  prefix or a suffix attached to root words to make 
other words.

Basically a Prefix or a Suffix is set of AffEntry objects
which store information about the prefix or suffix along 
with supporting routines to check if a word has a particular 
prefix or suffix or a combination.

The structure affentry is defined as follows:

struct affentry
{
   unsigned short aflag;    // ID used to represent the affix
   std::string strip;       // string to strip before adding affix
   std::string appnd;       // the affix string to add
   char numconds;           // the number of conditions that must be met
   char opts;               // flag: aeXPRODUCT- combine both prefix and suffix 
   char   conds[SETSIZE];   // array which encodes the conditions to be met
};


Here is a suffix borrowed from the en_US.aff file.  This file 
is whitespace delimited.

SFX D Y 4 
SFX D   0     e          d
SFX D   y     ied        [^aeiou]y
SFX D   0     ed         [^ey]
SFX D   0     ed         [aeiou]y

This information can be interpreted as follows:

In the first line has 4 fields

Field
-----
1     SFX - indicates this is a suffix
2     D   - is the name of the character flag which represents this suffix
3     Y   - indicates it can be combined with prefixes (cross product)
4     4   - indicates that sequence of 4 affentry structures are needed to
               properly store the affix information

The remaining lines describe the unique information for the 4 SfxEntry 
objects that make up this affix.  Each line can be interpreted
as follows: (note fields 1 and 2 are as a check against line 1 info)

Field
-----
1     SFX         - indicates this is a suffix
2     D           - is the name of the character flag for this affix
3     y           - the string of chars to strip off before adding affix
                         (a 0 here indicates the NULL string)
4     ied         - the string of affix characters to add
5     [^aeiou]y   - the conditions which must be met before the affix
                    can be applied

Field 5 is interesting.  Since this is a suffix, field 5 tells us that
there are 2 conditions that must be met.  The first condition is that 
the next to the last character in the word must *NOT* be any of the 
following "a", "e", "i", "o" or "u".  The second condition is that
the last character of the word must end in "y".

So how can we encode this information concisely and be able to 
test for both conditions in a fast manner?  The answer is found
but studying the wonderful ispell code of Geoff Kuenning, et.al. 
(now available under a normal BSD license).

If we set up a conds array of 256 bytes indexed (0 to 255) and access it
using a character (cast to an unsigned char) of a string, we have 8 bits
of information we can store about that character.  Specifically we
could use each bit to say if that character is allowed in any of the 
last (or first for prefixes) 8 characters of the word.

Basically, each character at one end of the word (up to the number 
of conditions) is used to index into the conds array and the resulting 
value found there says whether the that character is valid for a 
specific character position in the word.  

For prefixes, it does this by setting bit 0 if that char is valid 
in the first position, bit 1 if valid in the second position, and so on. 

If a bit is not set, then that char is not valid for that postion in the
word.

If working with suffixes bit 0 is used for the character closest 
to the front, bit 1 for the next character towards the end, ..., 
with bit numconds-1 representing the last char at the end of the string. 

Note: since entries in the conds[] are 8 bits, only 8 conditions 
(read that only 8 character positions) can be examined at one
end of a word (the beginning for prefixes and the end for suffixes.

So to make this clearer, lets encode the conds array values for the 
first two affentries for the suffix D described earlier.


  For the first affentry:    
     numconds = 1             (only examine the last character)

     conds['e'] =  (1 << 0)   (the word must end in an E)
     all others are all 0

  For the second affentry:
     numconds = 2             (only examine the last two characters)     

     conds[X] = conds[X] | (1 << 0)     (aeiou are not allowed)
         where X is all characters *but* a, e, i, o, or u
         

     conds['y'] = (1 << 1)     (the last char must be a y)
     all other bits for all other entries in the conds array are zero

#endif
