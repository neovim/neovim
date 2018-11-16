# Converts Vim/Nvim documentation to HTML.
#
# Adapted from https://github.com/c4rlo/vimhelp/
# License: MIT
#
# Copyright (c) 2016 Carlo Teubner
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import re, urllib.parse
from itertools import chain

HEAD = """\
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
    "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<meta http-equiv="Content-type" content="text/html; charset={encoding}"/>
<title>Nvim: {filename}</title>
"""

HEAD_END = '</head>\n<body>\n'

INTRO = """
<h1>Nvim help files</h1>
<p>HTML export of the <a href="https://neovim.io/">Nvim</a> help pages{vers-note}.
Updated <a href="https://github.com/neovim/bot-ci" class="d">automatically</a> from the <a
href="https://github.com/vim/vim/tree/master/runtime/doc" class="d">Nvim source repository</a>.
Also includes the <a href="vim_faq.txt.html">Vim FAQ</a>, pulled from its
<a href="https://github.com/chrisbra/vim_faq" class="d">source repository</a>.</p>
"""

VERSION_NOTE = ", current as of Vim {version}"

SITENAVI_LINKS = """
Quick links:
<a href="/">help overview</a> &middot;
<a href="quickref.txt.html">quick reference</a> &middot;
<a href="usr_toc.txt.html">user manual toc</a> &middot;
<a href="{helptxt}#reference_toc">reference manual toc</a> &middot;
<a href="vim_faq.txt.html">faq</a>
"""

SITENAVI_LINKS_PLAIN = SITENAVI_LINKS.format(helptxt='help.txt.html')
SITENAVI_LINKS_WEB = SITENAVI_LINKS.format(helptxt='/')

SITENAVI_PLAIN = '<p>' + SITENAVI_LINKS_PLAIN + '</p>'
SITENAVI_WEB = '<p>' + SITENAVI_LINKS_WEB + '</p>'

SITENAVI_SEARCH = '<table width="100%"><tbody><tr><td>' + SITENAVI_LINKS_WEB + \
'</td><td style="text-align: right; max-width: 25vw"><div class="gcse-searchbox">' \
'</div></td></tr></tbody></table><div class="gcse-searchresults"></div>'

TEXTSTART = """
<div id="d1">
<pre id="sp">                                                                                </pre>
<div id="d2">
<pre>
"""

FOOTER = '</pre>'

FOOTER2 = """
<p id="footer">This site is maintained by Carlo Teubner (<i>(my first name) dot (my last name) at gmail dot com</i>).</p>
</div>
</div>
</body>
</html>
"""

VIM_FAQ_LINE = '<a href="vim_faq.txt.html#vim_faq.txt" class="l">' \
               'vim_faq.txt</a>   Frequently Asked Questions\n'

RE_TAGLINE = re.compile(r'(\S+)\s+(\S+)')

PAT_WORDCHAR = '[!#-)+-{}~\xC0-\xFF]'

PAT_HEADER   = r'(^.*~$)'
PAT_GRAPHIC  = r'(^.* `$)'
PAT_PIPEWORD = r'(?<!\\)\|([#-)!+-~]+)\|'
PAT_STARWORD = r'\*([#-)!+-~]+)\*(?:(?=\s)|$)'
PAT_COMMAND  = r'`([^` ]+)`'
PAT_OPTWORD  = r"('(?:[a-z]{2,}|t_..)')"
PAT_CTRL     = r'(CTRL-(?:W_)?(?:\{char\}|<[A-Za-z]+?>|.)?)'
PAT_SPECIAL  = r'(<.+?>|\{.+?}|' \
               r'\[(?:range|line|count|offset|\+?cmd|[-+]?num|\+\+opt|' \
               r'arg|arguments|ident|addr|group)]|' \
               r'(?<=\s)\[[-a-z^A-Z0-9_]{2,}])'
PAT_TITLE    = r'(Vim version [0-9.a-z]+|VIM REFERENCE.*)'
PAT_NOTE     = r'((?<!' + PAT_WORDCHAR + r')(?:note|NOTE|Notes?):?' \
                 r'(?!' + PAT_WORDCHAR + r'))'
PAT_URL      = r'((?:https?|ftp)://[^\'"<> \t]+[a-zA-Z0-9/])'
PAT_WORD     = r'((?<!' + PAT_WORDCHAR + r')' + PAT_WORDCHAR + r'+' \
                 r'(?!' + PAT_WORDCHAR + r'))'

RE_LINKWORD = re.compile(
        PAT_OPTWORD  + '|' +
        PAT_CTRL     + '|' +
        PAT_SPECIAL)
RE_TAGWORD = re.compile(
        PAT_HEADER   + '|' +
        PAT_GRAPHIC  + '|' +
        PAT_PIPEWORD + '|' +
        PAT_STARWORD + '|' +
        PAT_COMMAND  + '|' +
        PAT_OPTWORD  + '|' +
        PAT_CTRL     + '|' +
        PAT_SPECIAL  + '|' +
        PAT_TITLE    + '|' +
        PAT_NOTE     + '|' +
        PAT_URL      + '|' +
        PAT_WORD)
RE_NEWLINE   = re.compile(r'[\r\n]')
RE_HRULE     = re.compile(r'[-=]{3,}.*[-=]{3,3}$')
RE_EG_START  = re.compile(r'(?:.* )?>$')
RE_EG_END    = re.compile(r'\S')
RE_SECTION   = re.compile(r'[-A-Z .][-A-Z0-9 .()]*(?=\s+\*)')
RE_STARTAG   = re.compile(r'\s\*([^ \t|]+)\*(?:\s|$)')
RE_LOCAL_ADD = re.compile(r'LOCAL ADDITIONS:\s+\*local-additions\*$')

class Link(object):
    __slots__ = 'link_plain_same',    'link_pipe_same', \
                'link_plain_foreign', 'link_pipe_foreign', \
                'filename'

    def __init__(self, link_plain_same, link_plain_foreign,
                       link_pipe_same,  link_pipe_foreign, filename):
        self.link_plain_same    = link_plain_same
        self.link_plain_foreign = link_plain_foreign
        self.link_pipe_same     = link_pipe_same
        self.link_pipe_foreign  = link_pipe_foreign
        self.filename           = filename

class VimH2H(object):
    def __init__(self, tags, version=None, is_web_version=True):
        self._urls = { }
        self._version = version
        self._is_web_version = is_web_version
        for line in RE_NEWLINE.split(tags):
            m = RE_TAGLINE.match(line)
            if m:
                tag, filename = m.group(1, 2)
                self.do_add_tag(filename, tag)

    def add_tags(self, filename, contents):
        for match in RE_STARTAG.finditer(contents):
            tag = match.group(1).replace('\\', '\\\\').replace('/', '\\/')
            self.do_add_tag(str(filename), tag)

    def do_add_tag(self, filename, tag):
        tag_quoted = urllib.parse.quote_plus(tag)
        def mkpart1(doc):
            return '<a href="' + doc + '#' + tag_quoted + '" class="'
        part1_same = mkpart1('')
        if self._is_web_version and filename == 'help.txt':
            doc = '/'
        else:
            doc = filename + '.html'
        part1_foreign = mkpart1(doc)
        part2 = '">' + html_escape[tag] + '</a>'
        def mklinks(cssclass):
            return (part1_same    + cssclass + part2,
                    part1_foreign + cssclass + part2)
        cssclass_plain = 'd'
        m = RE_LINKWORD.match(tag)
        if m:
            opt, ctrl, special = m.groups()
            if opt       is not None: cssclass_plain = 'o'
            elif ctrl    is not None: cssclass_plain = 'k'
            elif special is not None: cssclass_plain = 's'
        links_plain = mklinks(cssclass_plain)
        links_pipe = mklinks('l')
        self._urls[tag] = Link(
            links_plain[0], links_plain[1],
            links_pipe[0],  links_pipe[1],
            filename)

    def maplink(self, tag, curr_filename, css_class=None):
        links = self._urls.get(tag)
        if links is not None:
            if links.filename == curr_filename:
                if css_class == 'l': return links.link_pipe_same
                else:                return links.link_plain_same
            else:
                if css_class == 'l': return links.link_pipe_foreign
                else:                return links.link_plain_foreign
        elif css_class is not None:
            return '<span class="' + css_class + '">' + html_escape[tag] + \
                    '</span>'
        else: return html_escape[tag]

    def to_html(self, filename, contents, encoding):
        out = [ ]

        inexample = 0
        filename = str(filename)
        is_help_txt = (filename == 'help.txt')
        faq_line = False
        for line in RE_NEWLINE.split(contents):
            line = line.rstrip('\r\n')
            line_tabs = line
            line = line.expandtabs()
            if RE_HRULE.match(line):
                out.extend(('<span class="h">', line, '</span>\n'))
                continue
            if inexample == 2:
                if RE_EG_END.match(line):
                    inexample = 0
                    if line[0] == '<': line = line[1:]
                else:
                    out.extend(('<span class="e">', html_escape[line],
                               '</span>\n'))
                    continue
            if RE_EG_START.match(line_tabs):
                inexample = 1
                line = line[0:-1]
            if RE_SECTION.match(line_tabs):
                m = RE_SECTION.match(line)
                out.extend((r'<span class="c">', m.group(0), r'</span>'))
                line = line[m.end():]
            if is_help_txt and RE_LOCAL_ADD.match(line_tabs):
                faq_line = True
            lastpos = 0
            for match in RE_TAGWORD.finditer(line):
                pos = match.start()
                if pos > lastpos:
                    out.append(html_escape[line[lastpos:pos]])
                lastpos = match.end()
                header, graphic, pipeword, starword, command, opt, ctrl, \
                        special, title, note, url, word = match.groups()
                if pipeword is not None:
                    out.append(self.maplink(pipeword, filename, 'l'))
                elif starword is not None:
                    out.extend(('<a name="', urllib.parse.quote_plus(starword),
                            '" class="t">', html_escape[starword], '</a>'))
                elif command is not None:
                    out.extend(('<span class="e">', html_escape[command],
                                '</span>'))
                elif opt is not None:
                    out.append(self.maplink(opt, filename, 'o'))
                elif ctrl is not None:
                    out.append(self.maplink(ctrl, filename, 'k'))
                elif special is not None:
                    out.append(self.maplink(special, filename, 's'))
                elif title is not None:
                    out.extend(('<span class="i">', html_escape[title],
                                '</span>'))
                elif note is not None:
                    out.extend(('<span class="n">', html_escape[note],
                                '</span>'))
                elif header is not None:
                    out.extend(('<span class="h">', html_escape[header[:-1]],
                                '</span>'))
                elif graphic is not None:
                    out.append(html_escape[graphic[:-2]])
                elif url is not None:
                    out.extend(('<a class="u" href="', url, '">' +
                                html_escape[url], '</a>'))
                elif word is not None:
                    out.append(self.maplink(word, filename))
            if lastpos < len(line):
                out.append(html_escape[line[lastpos:]])
            out.append('\n')
            if inexample == 1: inexample = 2
            if faq_line:
                out.append(VIM_FAQ_LINE)
                faq_line = False

        header = []
        header.append(HEAD.format(encoding=encoding, filename=filename))
        header.append(HEAD_END)
        if self._is_web_version and is_help_txt:
            vers_note = VERSION_NOTE.replace('{version}', self._version) \
                    if self._version else ''
            header.append(INTRO.replace('{vers-note}', vers_note))
        if self._is_web_version:
            header.append(SITENAVI_SEARCH)
            sitenavi_footer = SITENAVI_WEB
        else:
            header.append(SITENAVI_PLAIN)
            sitenavi_footer = SITENAVI_PLAIN
        header.append(TEXTSTART)
        return ''.join(chain(header, out, (FOOTER, sitenavi_footer, FOOTER2)))

class HtmlEscCache(dict):
    def __missing__(self, key):
        r = key.replace('&', '&amp;') \
               .replace('<', '&lt;') \
               .replace('>', '&gt;')
        self[key] = r
        return r

html_escape = HtmlEscCache()



import sys, os, os.path
#import cProfile
sys.path.append('.')

def slurp(filename):
    try:
        with open(filename, encoding='UTF-8') as f:
            return f.read(), 'UTF-8'
    except UnicodeError:
        # 'ISO-8859-1' ?
        with open(filename, encoding='latin-1') as f:
            return f.read(), 'latin-1'

def usage():
    return "usage: " + sys.argv[0] + " IN_DIR OUT_DIR [BASENAMES...]"

def main():
    if len(sys.argv) < 3: sys.exit(usage())

    in_dir = sys.argv[1]
    out_dir = sys.argv[2]
    basenames = sys.argv[3:]

    print( "Processing tags...")
    h2h = VimH2H(slurp(os.path.join(in_dir, 'tags'))[0], is_web_version=False)

    if len(basenames) == 0:
        basenames = os.listdir(in_dir)

    for basename in basenames:
        if os.path.splitext(basename)[1] != '.txt' and basename != 'tags':
            print( "Ignoring " + basename)
            continue
        print( "Processing " + basename + "...")
        path = os.path.join(in_dir, basename)
        text, encoding = slurp(path)
        outpath = os.path.join(out_dir, basename + '.html')
        of = open(outpath, 'w')
        of.write(h2h.to_html(basename, text, encoding))
        of.close()

main()
#cProfile.run('main()')
