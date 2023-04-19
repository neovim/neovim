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

#ifndef AFFIX_HXX_
#define AFFIX_HXX_

#include "atypes.hxx"
#include "baseaffix.hxx"
#include "affixmgr.hxx"

/* A Prefix Entry  */

class PfxEntry : public AffEntry {
 private:
  AffixMgr* pmyMgr;

  PfxEntry* next;
  PfxEntry* nexteq;
  PfxEntry* nextne;
  PfxEntry* flgnxt;

 public:
  explicit PfxEntry(AffixMgr* pmgr);
  PfxEntry(const PfxEntry&) = delete;
  PfxEntry& operator=(const PfxEntry&) = delete;

  bool allowCross() const { return ((opts & aeXPRODUCT) != 0); }
  struct hentry* checkword(const std::string& word,
                           int start,
                           int len,
                           char in_compound,
                           const FLAG needflag = FLAG_NULL);

  struct hentry* check_twosfx(const std::string& word,
                              int start,
                              int len,
                              char in_compound,
                              const FLAG needflag = FLAG_NULL);

  std::string check_morph(const std::string& word,
                          int start,
                          int len,
                          char in_compound,
                          const FLAG needflag = FLAG_NULL);

  std::string check_twosfx_morph(const std::string& word,
                                 int start,
                                 int len,
                                 char in_compound,
                                 const FLAG needflag = FLAG_NULL);

  FLAG getFlag() { return aflag; }
  const char* getKey() { return appnd.c_str(); }
  std::string add(const char* word, size_t len);

  inline int getKeyLen() { return appnd.size(); }

  inline const char* getMorph() { return morphcode; }

  inline const unsigned short* getCont() { return contclass; }
  inline unsigned short getContLen() { return contclasslen; }

  inline PfxEntry* getNext() { return next; }
  inline PfxEntry* getNextNE() { return nextne; }
  inline PfxEntry* getNextEQ() { return nexteq; }
  inline PfxEntry* getFlgNxt() { return flgnxt; }

  inline void setNext(PfxEntry* ptr) { next = ptr; }
  inline void setNextNE(PfxEntry* ptr) { nextne = ptr; }
  inline void setNextEQ(PfxEntry* ptr) { nexteq = ptr; }
  inline void setFlgNxt(PfxEntry* ptr) { flgnxt = ptr; }

  inline char* nextchar(char* p);
  inline int test_condition(const std::string& st);
};

/* A Suffix Entry */

class SfxEntry : public AffEntry {
 private:
  SfxEntry(const SfxEntry&);
  SfxEntry& operator=(const SfxEntry&);

 private:
  AffixMgr* pmyMgr;
  std::string rappnd;

  SfxEntry* next;
  SfxEntry* nexteq;
  SfxEntry* nextne;
  SfxEntry* flgnxt;

  SfxEntry* l_morph;
  SfxEntry* r_morph;
  SfxEntry* eq_morph;

 public:
  explicit SfxEntry(AffixMgr* pmgr);

  bool allowCross() const { return ((opts & aeXPRODUCT) != 0); }
  struct hentry* checkword(const std::string& word,
                           int start,
                           int len,
                           int optflags,
                           PfxEntry* ppfx,
                           const FLAG cclass,
                           const FLAG needflag,
                           const FLAG badflag);

  struct hentry* check_twosfx(const std::string& word,
                              int start,
                              int len,
                              int optflags,
                              PfxEntry* ppfx,
                              const FLAG needflag = FLAG_NULL);

  std::string check_twosfx_morph(const std::string& word,
                                 int start,
                                 int len,
                                 int optflags,
                                 PfxEntry* ppfx,
                                 const FLAG needflag = FLAG_NULL);
  struct hentry* get_next_homonym(struct hentry* he);
  struct hentry* get_next_homonym(struct hentry* word,
                                  int optflags,
                                  PfxEntry* ppfx,
                                  const FLAG cclass,
                                  const FLAG needflag);

  FLAG getFlag() { return aflag; }
  const char* getKey() { return rappnd.c_str(); }
  std::string add(const char* word, size_t len);

  inline const char* getMorph() { return morphcode; }

  inline const unsigned short* getCont() { return contclass; }
  inline unsigned short getContLen() { return contclasslen; }
  inline const char* getAffix() { return appnd.c_str(); }

  inline int getKeyLen() { return appnd.size(); }

  inline SfxEntry* getNext() { return next; }
  inline SfxEntry* getNextNE() { return nextne; }
  inline SfxEntry* getNextEQ() { return nexteq; }

  inline SfxEntry* getLM() { return l_morph; }
  inline SfxEntry* getRM() { return r_morph; }
  inline SfxEntry* getEQM() { return eq_morph; }
  inline SfxEntry* getFlgNxt() { return flgnxt; }

  inline void setNext(SfxEntry* ptr) { next = ptr; }
  inline void setNextNE(SfxEntry* ptr) { nextne = ptr; }
  inline void setNextEQ(SfxEntry* ptr) { nexteq = ptr; }
  inline void setFlgNxt(SfxEntry* ptr) { flgnxt = ptr; }
  void initReverseWord();

  inline char* nextchar(char* p);
  inline int test_condition(const char* st, const char* begin);
};

#endif
