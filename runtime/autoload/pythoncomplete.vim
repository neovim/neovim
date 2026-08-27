"pythoncomplete.vim - Omni Completion for python
" Maintainer: <vacancy>
" Previous Maintainer: Aaron Griffin <aaronmgriffin@gmail.com>
" Version: 0.10
" Last Updated: 2026 Jun 21
"
" Changes
" TODO:
" 'info' item output can use some formatting work
" Add an "unsafe eval" mode, to allow for return type evaluation
" Complete basic syntax along with import statements
"   i.e. "import url<c-x,c-o>"
" Continue parsing on invalid line??
"
" v 0.10 by Vim project
"   * disables importing local modules, unless the global Vim variable
"     g:pythoncomplete_allow_import is set to non-zero
"   * strip default values and annotations from function parameter lists
"     before exec(), and whitelist class base lists to dotted names: the
"     previous code passed buffer-supplied expressions to exec() which
"     Python evaluates at definition time, allowing arbitrary code
"     execution via crafted def/class headers
"   * use repr() on doc strings to prevent code execution
"
" v 0.9
"   * Fixed docstring parsing for classes and functions
"   * Fixed parsing of *args and **kwargs type arguments
"   * Better function param parsing to handle things like tuples and
"     lambda defaults args
"
" v 0.8
"   * Fixed an issue where the FIRST assignment was always used instead of
"   using a subsequent assignment for a variable
"   * Fixed a scoping issue when working inside a parameterless function
"
"
" v 0.7
"   * Fixed function list sorting (_ and __ at the bottom)
"   * Removed newline removal from docs.  It appears vim handles these better in
"   recent patches
"
" v 0.6:
"   * Fixed argument completion
"   * Removed the 'kind' completions, as they are better indicated
"   with real syntax
"   * Added tuple assignment parsing (whoops, that was forgotten)
"   * Fixed import handling when flattening scope
"
" v 0.5:
" Yeah, I skipped a version number - 0.4 was never public.
"  It was a bugfix version on top of 0.3.  This is a complete
"  rewrite.
"

if !has('python')
    echo 'Error: Requires python + pynvim.  :help provider-python'
    finish
endif

function! pythoncomplete#Complete(findstart, base)
    "findstart = 1 when we need to get the text length
    if a:findstart == 1
        let line = getline('.')
        let idx = col('.')
        while idx > 0
            let idx -= 1
            let c = line[idx]
            if c =~ '\w'
                continue
            elseif ! c =~ '\.'
                let idx = -1
                break
            else
                break
            endif
        endwhile

        return idx
    "findstart = 0 when we need to return the list of completions
    else
        "vim no longer moves the cursor upon completion... fix that
        let line = getline('.')
        let idx = col('.')
        let cword = ''
        while idx > 0
            let idx -= 1
            let c = line[idx]
            if c =~ '\w' || c =~ '\.'
                let cword = c . cword
                continue
            elseif strlen(cword) > 0 || idx == 0
                break
            endif
        endwhile
        execute "python vimcomplete('" . escape(cword, "'") . "', '" . escape(a:base, "'") . "')"
        return g:pythoncomplete_completions
    endif
endfunction

function! s:DefPython()
python << PYTHONEOF
import sys, tokenize, cStringIO, types
from token import NAME, DEDENT, NEWLINE, STRING
import re

# Used by Class.get_code(): a base class expression is only included in the
# code passed to exec() if it is a pure dotted name (e.g. "Base", "mod.Base",
# "pkg.sub.Cls").  Anything containing calls, subscripts, "=", ":" or other
# operators is dropped, since exec()-ing it would evaluate buffer-supplied
# expressions.  See the security note in the file header.
_DOTTED_NAME_RE = re.compile(r'^[A-Za-z_]\w*(\s*\.\s*[A-Za-z_]\w*)*$')

def _strip_param(p):
    # Return the bare parameter name from a parameter spec harvested by
    # _parenparse(), discarding any default value or annotation.  Default
    # values and annotations would otherwise be evaluated by exec() at
    # function-definition time.  Star prefixes ("*args", "**kw") and bare
    # "*" / "/" are preserved as written.
    p = p.split('=', 1)[0]
    p = p.split(':', 1)[0]
    return p.strip()

debugstmts=[]
def dbg(s): debugstmts.append(s)
def showdbg():
    for d in debugstmts: print "DBG: %s " % d

def vimcomplete(context,match):
    global debugstmts
    debugstmts = []
    try:
        import vim
        def complsort(x,y):
            try:
                xa = x['abbr']
                ya = y['abbr']
                if xa[0] == '_':
                    if xa[1] == '_' and ya[0:2] == '__':
                        return xa > ya
                    elif ya[0:2] == '__':
                        return -1
                    elif y[0] == '_':
                        return xa > ya
                    else:
                        return 1
                elif ya[0] == '_':
                    return -1
                else:
                   return xa > ya
            except:
                return 0
        cmpl = Completer()
        cmpl.evalsource('\n'.join(vim.current.buffer),vim.eval("line('.')"))
        all = cmpl.get_completions(context,match)
        all.sort(complsort)
        dictstr = '['
        # have to do this for double quoting
        for cmpl in all:
            dictstr += '{'
            for x in cmpl: dictstr += '"%s":"%s",' % (x,cmpl[x])
            dictstr += '"icase":0},'
        if dictstr[-1] == ',': dictstr = dictstr[:-1]
        dictstr += ']'
        #dbg("dict: %s" % dictstr)
        vim.command("silent let g:pythoncomplete_completions = %s" % dictstr)
        #dbg("Completion dict:\n%s" % all)
    except vim.error:
        dbg("VIM Error: %s" % vim.error)

class Completer(object):
    def __init__(self):
       self.compldict = {}
       self.parser = PyParser()

    def evalsource(self,text,line=0):
        # vim is imported locally in vimcomplete(); re-import here so the
        # vim.eval() below works (otherwise NameError, silently caught).
        import vim
        sc = self.parser.parse(text,line)
        try: allow_imports = int(
          vim.eval("get(g:, 'pythoncomplete_allow_import', 0)"))
        except Exception:
          allow_imports = 0
        src = sc.get_code()
        dbg("source: %s" % src)
        try: exec(src) in self.compldict
        except: dbg("parser: %s, %s" % (sys.exc_info()[0],sys.exc_info()[1]))
        for l in sc.locals:
            # Executing import/from statements harvested from the buffer runs
            # arbitrary package code; only do so when the user opted in.
            if not allow_imports and (l.startswith('import')
                                            or l.startswith('from ')):
                continue
            try: exec(l) in self.compldict
            except: dbg("locals: %s, %s [%s]" % (sys.exc_info()[0],sys.exc_info()[1],l))

    def _cleanstr(self,doc):
        return doc.replace('"',' ').replace("'",' ')

    def get_arguments(self,func_obj):
        def _ctor(obj):
            try: return class_ob.__init__.im_func
            except AttributeError:
                for base in class_ob.__bases__:
                    rc = _find_constructor(base)
                    if rc is not None: return rc
            return None

        arg_offset = 1
        if type(func_obj) == types.ClassType: func_obj = _ctor(func_obj)
        elif type(func_obj) == types.MethodType: func_obj = func_obj.im_func
        else: arg_offset = 0
        
        arg_text=''
        if type(func_obj) in [types.FunctionType, types.LambdaType]:
            try:
                cd = func_obj.func_code
                real_args = cd.co_varnames[arg_offset:cd.co_argcount]
                defaults = func_obj.func_defaults or ''
                defaults = map(lambda name: "=%s" % name, defaults)
                defaults = [""] * (len(real_args)-len(defaults)) + defaults
                items = map(lambda a,d: a+d, real_args, defaults)
                if func_obj.func_code.co_flags & 0x4:
                    items.append("...")
                if func_obj.func_code.co_flags & 0x8:
                    items.append("***")
                arg_text = (','.join(items)) + ')'

            except:
                dbg("arg completion: %s: %s" % (sys.exc_info()[0],sys.exc_info()[1]))
                pass
        if len(arg_text) == 0:
            # The doc string sometimes contains the function signature
            #  this works for a lot of C modules that are part of the
            #  standard library
            doc = func_obj.__doc__
            if doc:
                doc = doc.lstrip()
                pos = doc.find('\n')
                if pos > 0:
                    sigline = doc[:pos]
                    lidx = sigline.find('(')
                    ridx = sigline.find(')')
                    if lidx > 0 and ridx > 0:
                        arg_text = sigline[lidx+1:ridx] + ')'
        if len(arg_text) == 0: arg_text = ')'
        return arg_text

    def get_completions(self,context,match):
        dbg("get_completions('%s','%s')" % (context,match))
        stmt = ''
        if context: stmt += str(context)
        if match: stmt += str(match)
        try:
            result = None
            all = {}
            ridx = stmt.rfind('.')
            if len(stmt) > 0 and stmt[-1] == '(':
                result = eval(_sanitize(stmt[:-1]), self.compldict)
                doc = result.__doc__
                if doc is None: doc = ''
                args = self.get_arguments(result)
                return [{'word':self._cleanstr(args),'info':self._cleanstr(doc)}]
            elif ridx == -1:
                match = stmt
                all = self.compldict
            else:
                match = stmt[ridx+1:]
                stmt = _sanitize(stmt[:ridx])
                result = eval(stmt, self.compldict)
                all = dir(result)

            dbg("completing: stmt:%s" % stmt)
            completions = []

            try: maindoc = result.__doc__
            except: maindoc = ' '
            if maindoc is None: maindoc = ' '
            for m in all:
                if m == "_PyCmplNoType": continue #this is internal
                try:
                    dbg('possible completion: %s' % m)
                    if m.find(match) == 0:
                        if result is None: inst = all[m]
                        else: inst = getattr(result,m)
                        try: doc = inst.__doc__
                        except: doc = maindoc
                        typestr = str(inst)
                        if doc is None or doc == '': doc = maindoc

                        wrd = m[len(match):]
                        c = {'word':wrd, 'abbr':m,  'info':self._cleanstr(doc)}
                        if "function" in typestr:
                            c['word'] += '('
                            c['abbr'] += '(' + self._cleanstr(self.get_arguments(inst))
                        elif "method" in typestr:
                            c['word'] += '('
                            c['abbr'] += '(' + self._cleanstr(self.get_arguments(inst))
                        elif "module" in typestr:
                            c['word'] += '.'
                        elif "class" in typestr:
                            c['word'] += '('
                            c['abbr'] += '('
                        completions.append(c)
                except:
                    i = sys.exc_info()
                    dbg("inner completion: %s,%s [stmt='%s']" % (i[0],i[1],stmt))
            return completions
        except:
            i = sys.exc_info()
            dbg("completion: %s,%s [stmt='%s']" % (i[0],i[1],stmt))
            return []

class Scope(object):
    def __init__(self,name,indent,docstr=''):
        self.subscopes = []
        self.docstr = docstr
        self.locals = []
        self.parent = None
        self.name = name
        self.indent = indent

    def add(self,sub):
        #print 'push scope: [%s@%s]' % (sub.name,sub.indent)
        sub.parent = self
        self.subscopes.append(sub)
        return sub

    def doc(self,str):
        """ Clean up a docstring """
        d = str.replace('\n',' ')
        d = d.replace('\t',' ')
        while d.find('  ') > -1: d = d.replace('  ',' ')
        while d[0] in '"\'\t ': d = d[1:]
        while d[-1] in '"\'\t ': d = d[:-1]
        dbg("Scope(%s)::docstr = %s" % (self,d))
        self.docstr = d

    def local(self,loc):
        self._checkexisting(loc)
        self.locals.append(loc)

    def copy_decl(self,indent=0):
        """ Copy a scope's declaration only, at the specified indent level - not local variables """
        return Scope(self.name,indent,self.docstr)

    def _checkexisting(self,test):
        "Convienance function... keep out duplicates"
        if test.find('=') > -1:
            var = test.split('=')[0].strip()
            for l in self.locals:
                if l.find('=') > -1 and var == l.split('=')[0].strip():
                    self.locals.remove(l)

    def get_code(self):
        str = ""
        if len(self.docstr) > 0: str += repr(self.docstr)+'\n'
        str += 'class _PyCmplNoType:\n    def __getattr__(self,name):\n        return None\n'
        for sub in self.subscopes:
            str += sub.get_code()
        for l in self.locals:
            if not l.startswith('import') and not l.startswith('from '): str += l+'\n'

        return str

    def pop(self,indent):
        #print 'pop scope: [%s] to [%s]' % (self.indent,indent)
        outer = self
        while outer.parent != None and outer.indent >= indent:
            outer = outer.parent
        return outer

    def currentindent(self):
        #print 'parse current indent: %s' % self.indent
        return '    '*self.indent

    def childindent(self):
        #print 'parse child indent: [%s]' % (self.indent+1)
        return '    '*(self.indent+1)

class Class(Scope):
    def __init__(self, name, supers, indent, docstr=''):
        Scope.__init__(self,name,indent, docstr)
        self.supers = supers
    def copy_decl(self,indent=0):
        c = Class(self.name,self.supers,indent, self.docstr)
        for s in self.subscopes:
            c.add(s.copy_decl(indent+1))
        return c
    def get_code(self):
        str = '%sclass %s' % (self.currentindent(),self.name)
        # Only include base class expressions that are pure dotted names.
        # Anything else (calls, subscripts, conditionals, ...) is dropped
        # because exec() would evaluate it at class-definition time.  See
        # the security note in the file header.
        safe_supers = [s.strip() for s in self.supers
                       if _DOTTED_NAME_RE.match(s.strip())]
        if len(safe_supers) > 0: str += '(%s)' % ','.join(safe_supers)
        str += ':\n'
        if len(self.docstr) > 0: str += self.childindent()+repr(self.docstr)+'\n'
        if len(self.subscopes) > 0:
            for s in self.subscopes: str += s.get_code()
        else:
            str += '%spass\n' % self.childindent()
        return str


class Function(Scope):
    def __init__(self, name, params, indent, docstr=''):
        Scope.__init__(self,name,indent, docstr)
        self.params = params
    def copy_decl(self,indent=0):
        return Function(self.name,self.params,indent, self.docstr)
    def get_code(self):
        # Strip default values and annotations from each parameter before
        # joining: exec() evaluates these at definition time and a hostile
        # buffer could otherwise execute arbitrary code via crafted def
        # headers.  See file header for details.
        safe_params = [_strip_param(p) for p in self.params]
        safe_params = [p for p in safe_params if p]
        str = "%sdef %s(%s):\n" % \
            (self.currentindent(),self.name,','.join(safe_params))
        if len(self.docstr) > 0: str += self.childindent()+repr(self.docstr)+'\n'
        str += "%spass\n" % self.childindent()
        return str

class PyParser:
    def __init__(self):
        self.top = Scope('global',0)
        self.scope = self.top
        self.parserline = 0

    def _parsedotname(self,pre=None):
        #returns (dottedname, nexttoken)
        name = []
        if pre is None:
            tokentype, token, indent = self.next()
            if tokentype != NAME and token != '*':
                return ('', token)
        else: token = pre
        name.append(token)
        while True:
            tokentype, token, indent = self.next()
            if token != '.': break
            tokentype, token, indent = self.next()
            if tokentype != NAME: break
            name.append(token)
        return (".".join(name), token)

    def _parseimportlist(self):
        imports = []
        while True:
            name, token = self._parsedotname()
            if not name: break
            name2 = ''
            if token == 'as': name2, token = self._parsedotname()
            imports.append((name, name2))
            while token != "," and "\n" not in token:
                tokentype, token, indent = self.next()
            if token != ",": break
        return imports

    def _parenparse(self):
        name = ''
        names = []
        level = 1
        while True:
            tokentype, token, indent = self.next()
            if token in (')', ',') and level == 1:
                if '=' not in name: name = name.replace(' ', '')
                names.append(name.strip())
                name = ''
            if token == '(':
                level += 1
                name += "("
            elif token == ')':
                level -= 1
                if level == 0: break
                else: name += ")"
            elif token == ',' and level == 1:
                pass
            else:
                name += "%s " % str(token)
        return names

    def _parsefunction(self,indent):
        self.scope=self.scope.pop(indent)
        tokentype, fname, ind = self.next()
        if tokentype != NAME: return None

        tokentype, open, ind = self.next()
        if open != '(': return None
        params=self._parenparse()

        tokentype, colon, ind = self.next()
        if colon != ':': return None

        return Function(fname,params,indent)

    def _parseclass(self,indent):
        self.scope=self.scope.pop(indent)
        tokentype, cname, ind = self.next()
        if tokentype != NAME: return None

        super = []
        tokentype, next, ind = self.next()
        if next == '(':
            super=self._parenparse()
        elif next != ':': return None

        return Class(cname,super,indent)

    def _parseassignment(self):
        assign=''
        tokentype, token, indent = self.next()
        if tokentype == tokenize.STRING or token == 'str':  
            return '""'
        elif token == '(' or token == 'tuple':
            return '()'
        elif token == '[' or token == 'list':
            return '[]'
        elif token == '{' or token == 'dict':
            return '{}'
        elif tokentype == tokenize.NUMBER:
            return '0'
        elif token == 'open' or token == 'file':
            return 'file'
        elif token == 'None':
            return '_PyCmplNoType()'
        elif token == 'type':
            return 'type(_PyCmplNoType)' #only for method resolution
        else:
            assign += token
            level = 0
            while True:
                tokentype, token, indent = self.next()
                if token in ('(','{','['):
                    level += 1
                elif token in (']','}',')'):
                    level -= 1
                    if level == 0: break
                elif level == 0:
                    if token in (';','\n'): break
                    assign += token
        return "%s" % assign

    def next(self):
        type, token, (lineno, indent), end, self.parserline = self.gen.next()
        if lineno == self.curline:
            #print 'line found [%s] scope=%s' % (line.replace('\n',''),self.scope.name)
            self.currentscope = self.scope
        return (type, token, indent)

    def _adjustvisibility(self):
        newscope = Scope('result',0)
        scp = self.currentscope
        while scp != None:
            if type(scp) == Function:
                slice = 0
                #Handle 'self' params
                if scp.parent != None and type(scp.parent) == Class:
                    slice = 1
                    newscope.local('%s = %s' % (scp.params[0],scp.parent.name))
                for p in scp.params[slice:]:
                    i = p.find('=')
                    if len(p) == 0: continue
                    pvar = ''
                    ptype = ''
                    if i == -1:
                        pvar = p
                        ptype = '_PyCmplNoType()'
                    else:
                        pvar = p[:i]
                        ptype = _sanitize(p[i+1:])
                    if pvar.startswith('**'):
                        pvar = pvar[2:]
                        ptype = '{}'
                    elif pvar.startswith('*'):
                        pvar = pvar[1:]
                        ptype = '[]'

                    newscope.local('%s = %s' % (pvar,ptype))

            for s in scp.subscopes:
                ns = s.copy_decl(0)
                newscope.add(ns)
            for l in scp.locals: newscope.local(l)
            scp = scp.parent

        self.currentscope = newscope
        return self.currentscope

    #p.parse(vim.current.buffer[:],vim.eval("line('.')"))
    def parse(self,text,curline=0):
        self.curline = int(curline)
        buf = cStringIO.StringIO(''.join(text) + '\n')
        self.gen = tokenize.generate_tokens(buf.readline)
        self.currentscope = self.scope

        try:
            freshscope=True
            while True:
                tokentype, token, indent = self.next()
                #dbg( 'main: token=[%s] indent=[%s]' % (token,indent))

                if tokentype == DEDENT or token == "pass":
                    self.scope = self.scope.pop(indent)
                elif token == 'def':
                    func = self._parsefunction(indent)
                    if func is None:
                        print "function: syntax error..."
                        continue
                    dbg("new scope: function")
                    freshscope = True
                    self.scope = self.scope.add(func)
                elif token == 'class':
                    cls = self._parseclass(indent)
                    if cls is None:
                        print "class: syntax error..."
                        continue
                    freshscope = True
                    dbg("new scope: class")
                    self.scope = self.scope.add(cls)
                    
                elif token == 'import':
                    imports = self._parseimportlist()
                    for mod, alias in imports:
                        loc = "import %s" % mod
                        if len(alias) > 0: loc += " as %s" % alias
                        self.scope.local(loc)
                    freshscope = False
                elif token == 'from':
                    mod, token = self._parsedotname()
                    if not mod or token != "import":
                        print "from: syntax error..."
                        continue
                    names = self._parseimportlist()
                    for name, alias in names:
                        loc = "from %s import %s" % (mod,name)
                        if len(alias) > 0: loc += " as %s" % alias
                        self.scope.local(loc)
                    freshscope = False
                elif tokentype == STRING:
                    if freshscope: self.scope.doc(token)
                elif tokentype == NAME:
                    name,token = self._parsedotname(token) 
                    if token == '=':
                        stmt = self._parseassignment()
                        dbg("parseassignment: %s = %s" % (name, stmt))
                        if stmt != None:
                            self.scope.local("%s = %s" % (name,stmt))
                    freshscope = False
        except StopIteration: #thrown on EOF
            pass
        except:
            dbg("parse error: %s, %s @ %s" %
                (sys.exc_info()[0], sys.exc_info()[1], self.parserline))
        return self._adjustvisibility()

def _sanitize(str):
    val = ''
    level = 0
    for c in str:
        if c in ('(','{','['):
            level += 1
        elif c in (']','}',')'):
            level -= 1
        elif level == 0:
            val += c
    return val

sys.path.extend(['.','..'])
PYTHONEOF
endfunction

call s:DefPython()
" vim: set et ts=4:
