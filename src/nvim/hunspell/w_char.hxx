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

#ifndef W_CHAR_HXX_
#define W_CHAR_HXX_

#include <string>

#if __cplusplus >= 202002L
#include <bit>
#else
#include <cstring>
#endif

#ifndef GCC
struct w_char {
#else
struct __attribute__((packed)) w_char {
#endif
  unsigned char l;
  unsigned char h;

  operator unsigned short() const
  {
#if defined(__i386__) || defined(_M_IX86) || defined(_M_X64)
    //use little-endian optimized version
#if __cplusplus >= 202002L
    return std::bit_cast<unsigned short>(*this);
#else
    unsigned short u;
    memcpy(&u, this, sizeof(unsigned short));
    return u;
#endif

#else
    return ((unsigned short)h << 8) | (unsigned short)l;
#endif
  }

  friend bool operator<(const w_char a, const w_char b) {
    return (unsigned short)a < (unsigned short)b;
  }

  friend bool operator==(const w_char a, const w_char b) {
    return (unsigned short)a == (unsigned short)b;
  }

  friend bool operator!=(const w_char a, const w_char b) {
    return !(a == b);
  }
};

// two character arrays
struct replentry {
  std::string pattern;
  std::string outstrings[4]; // med, ini, fin, isol
};

#endif
