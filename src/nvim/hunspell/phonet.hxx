/*  phonetic.c - generic replacement aglogithms for phonetic transformation
    Copyright (C) 2000 Bjoern Jacke

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License version 2.1 as published by the Free Software Foundation;

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; If not, see
    <http://www.gnu.org/licenses/>.

    Changelog:

    2000-01-05  Bjoern Jacke <bjoern at j3e.de>
                Initial Release insprired by the article about phonetic
                transformations out of c't 25/1999

    2007-07-26  Bjoern Jacke <bjoern at j3e.de>
                Released under MPL/GPL/LGPL tri-license for Hunspell

    2007-08-23  Laszlo Nemeth <nemeth at OOo>
                Porting from Aspell to Hunspell using C-like structs
*/

#ifndef PHONET_HXX_
#define PHONET_HXX_

#define HASHSIZE 256
#define MAXPHONETLEN 256
#define MAXPHONETUTF8LEN (MAXPHONETLEN * 4)

#include "hunvisapi.h"

struct phonetable {
  char utf8;
  std::vector<std::string> rules;
  int hash[HASHSIZE];
};

LIBHUNSPELL_DLL_EXPORTED void init_phonet_hash(phonetable& parms);

LIBHUNSPELL_DLL_EXPORTED std::string phonet(const std::string& inword,
                                            phonetable& phone);

#endif
