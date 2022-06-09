local api = vim.api

local M = {}

---@private
local function starsetf(ft, opts)
  return {
    function(path, bufnr)
      local f = type(ft) == 'function' and ft(path, bufnr) or ft
      if not vim.g.ft_ignore_pat then
        return f
      end

      local re = vim.regex(vim.g.ft_ignore_pat)
      if not re:match_str(path) then
        return f
      end
    end,
    {
      -- Starset matches should always have lowest priority
      priority = (opts and opts.priority) or -math.huge,
    },
  }
end

---@private
local function getline(bufnr, start_lnum, end_lnum)
  end_lnum = end_lnum or start_lnum
  local lines = api.nvim_buf_get_lines(bufnr, start_lnum - 1, end_lnum, false)
  return table.concat(lines) or ''
end

---@private
--- Get a single line or line-range from the buffer.
---
---@param bufnr number|nil The buffer to get the lines from
---@param start_lnum number The line number of the first line (inclusive, 1-based)
---@param end_lnum number|nil The line number of the last line (inclusive, 1-based)
---@return table<string>|string Array of lines, or string when end_lnum is omitted
function M.getlines(bufnr, start_lnum, end_lnum)
  if not end_lnum then
    -- Return a single line as a string
    return api.nvim_buf_get_lines(bufnr, start_lnum - 1, start_lnum, false)[1]
  end
  return api.nvim_buf_get_lines(bufnr, start_lnum - 1, end_lnum, false)
end

---@private
--- Check whether a string matches any of the given Lua patterns.
---
---@param s string The string to check
---@param patterns table<string> A list of Lua patterns
---@return boolean `true` if s matched a pattern, else `false`
function M.findany(s, patterns)
  if s == nil then
    return false
  end
  for _, v in ipairs(patterns) do
    if s:find(v) then
      return true
    end
  end
  return false
end

---@private
--- Get the next non-whitespace line in the buffer.
---
---@param bufnr number The buffer to get the line from
---@param start_lnum number The line number of the first line to start from (inclusive, 1-based)
---@return string|nil The first non-blank line if found or `nil` otherwise
function M.nextnonblank(bufnr, start_lnum)
  for _, line in ipairs(M.getlines(bufnr, start_lnum, -1)) do
    if not line:find('^%s*$') then
      return line
    end
  end
  return nil
end

---@private
--- Check whether the given string matches the Vim regex pattern.
M.matchregex = (function()
  local cache = {}
  return function(s, pattern)
    if s == nil then
      return nil
    end
    if not cache[pattern] then
      cache[pattern] = vim.regex(pattern)
    end
    return cache[pattern]:match_str(s)
  end
end)()

-- luacheck: push no unused args
-- luacheck: push ignore 122

-- Filetypes based on file extension
---@diagnostic disable: unused-local
local extension = {
  -- BEGIN EXTENSION
  ['8th'] = '8th',
  ['a65'] = 'a65',
  aap = 'aap',
  abap = 'abap',
  abc = 'abc',
  abl = 'abel',
  wrm = 'acedb',
  ads = 'ada',
  ada = 'ada',
  gpr = 'ada',
  adb = 'ada',
  tdf = 'ahdl',
  aidl = 'aidl',
  aml = 'aml',
  run = 'ampl',
  scpt = 'applescript',
  ino = 'arduino',
  pde = 'arduino',
  art = 'art',
  asciidoc = 'asciidoc',
  adoc = 'asciidoc',
  asa = function(path, bufnr)
    if vim.g.filetype_asa then
      return vim.g.filetype_asa
    end
    return 'aspvbs'
  end,
  ['asn1'] = 'asn',
  asn = 'asn',
  asp = function(path, bufnr)
    return require('vim.filetype.detect').asp(bufnr)
  end,
  atl = 'atlas',
  as = 'atlas',
  ahk = 'autohotkey',
  ['au3'] = 'autoit',
  ave = 'ave',
  gawk = 'awk',
  awk = 'awk',
  ref = 'b',
  imp = 'b',
  mch = 'b',
  bc = 'bc',
  bdf = 'bdf',
  beancount = 'beancount',
  bib = 'bib',
  bicep = 'bicep',
  bl = 'blank',
  bsdl = 'bsdl',
  bst = 'bst',
  bzl = 'bzl',
  bazel = 'bzl',
  BUILD = 'bzl',
  qc = 'c',
  cabal = 'cabal',
  cdl = 'cdl',
  toc = 'cdrtoc',
  cfc = 'cf',
  cfm = 'cf',
  cfi = 'cf',
  hgrc = 'cfg',
  chf = 'ch',
  chai = 'chaiscript',
  chs = 'chaskell',
  chopro = 'chordpro',
  crd = 'chordpro',
  crdpro = 'chordpro',
  cho = 'chordpro',
  chordpro = 'chordpro',
  eni = 'cl',
  icl = 'clean',
  cljx = 'clojure',
  clj = 'clojure',
  cljc = 'clojure',
  cljs = 'clojure',
  cook = 'cook',
  cmake = 'cmake',
  cmod = 'cmod',
  lib = 'cobol',
  cob = 'cobol',
  cbl = 'cobol',
  atg = 'coco',
  recipe = 'conaryrecipe',
  hook = function(path, bufnr)
    if getline(bufnr, 1) == '[Trigger]' then
      return 'conf'
    end
  end,
  mklx = 'context',
  mkiv = 'context',
  mkii = 'context',
  mkxl = 'context',
  mkvi = 'context',
  moc = 'cpp',
  hh = 'cpp',
  tlh = 'cpp',
  inl = 'cpp',
  ipp = 'cpp',
  ['c++'] = 'cpp',
  C = 'cpp',
  cxx = 'cpp',
  H = 'cpp',
  tcc = 'cpp',
  hxx = 'cpp',
  hpp = 'cpp',
  cpp = function(path, bufnr)
    if vim.g.cynlib_syntax_for_cpp then
      return 'cynlib'
    end
    return 'cpp'
  end,
  cc = function(path, bufnr)
    if vim.g.cynlib_syntax_for_cc then
      return 'cynlib'
    end
    return 'cpp'
  end,
  crm = 'crm',
  csx = 'cs',
  cs = 'cs',
  csc = 'csc',
  csdl = 'csdl',
  cshtml = 'html',
  fdr = 'csp',
  csp = 'csp',
  css = 'css',
  con = 'cterm',
  feature = 'cucumber',
  cuh = 'cuda',
  cu = 'cuda',
  pld = 'cupl',
  si = 'cuplsim',
  cyn = 'cynpp',
  dart = 'dart',
  drt = 'dart',
  ds = 'datascript',
  dcd = 'dcd',
  def = 'def',
  desc = 'desc',
  directory = 'desktop',
  desktop = 'desktop',
  diff = 'diff',
  rej = 'diff',
  Dockerfile = 'dockerfile',
  dockerfile = 'dockerfile',
  bat = 'dosbatch',
  wrap = 'dosini',
  ini = 'dosini',
  dot = 'dot',
  gv = 'dot',
  drac = 'dracula',
  drc = 'dracula',
  dtd = 'dtd',
  dts = 'dts',
  dtsi = 'dts',
  dylan = 'dylan',
  intr = 'dylanintr',
  lid = 'dylanlid',
  ecd = 'ecd',
  eex = 'eelixir',
  leex = 'eelixir',
  exs = 'elixir',
  elm = 'elm',
  elv = 'elvish',
  epp = 'epuppet',
  erl = 'erlang',
  hrl = 'erlang',
  yaws = 'erlang',
  erb = 'eruby',
  rhtml = 'eruby',
  ec = 'esqlc',
  EC = 'esqlc',
  strl = 'esterel',
  exp = 'expect',
  factor = 'factor',
  fal = 'falcon',
  fan = 'fan',
  fwt = 'fan',
  fnl = 'fennel',
  ['m4gl'] = 'fgl',
  ['4gl'] = 'fgl',
  ['4gh'] = 'fgl',
  fish = 'fish',
  focexec = 'focexec',
  fex = 'focexec',
  fth = 'forth',
  ft = 'forth',
  FOR = 'fortran',
  ['f77'] = 'fortran',
  ['f03'] = 'fortran',
  fortran = 'fortran',
  ['F95'] = 'fortran',
  ['f90'] = 'fortran',
  ['F03'] = 'fortran',
  fpp = 'fortran',
  FTN = 'fortran',
  ftn = 'fortran',
  ['for'] = 'fortran',
  ['F90'] = 'fortran',
  ['F77'] = 'fortran',
  ['f95'] = 'fortran',
  FPP = 'fortran',
  f = 'fortran',
  F = 'fortran',
  ['F08'] = 'fortran',
  ['f08'] = 'fortran',
  fpc = 'fpcmake',
  fsl = 'framescript',
  fb = 'freebasic',
  fsi = 'fsharp',
  fsx = 'fsharp',
  fusion = 'fusion',
  gdb = 'gdb',
  gdmo = 'gdmo',
  mo = 'gdmo',
  tres = 'gdresource',
  tscn = 'gdresource',
  gd = 'gdscript',
  ged = 'gedcom',
  gmi = 'gemtext',
  gemini = 'gemtext',
  gift = 'gift',
  gleam = 'gleam',
  glsl = 'glsl',
  gpi = 'gnuplot',
  gnuplot = 'gnuplot',
  go = 'go',
  gp = 'gp',
  gs = 'grads',
  gql = 'graphql',
  graphql = 'graphql',
  graphqls = 'graphql',
  gretl = 'gretl',
  gradle = 'groovy',
  groovy = 'groovy',
  gsp = 'gsp',
  gjs = 'javascript.glimmer',
  gts = 'typescript.glimmer',
  hack = 'hack',
  hackpartial = 'hack',
  haml = 'haml',
  hsm = 'hamster',
  hbs = 'handlebars',
  ['hs-boot'] = 'haskell',
  hsig = 'haskell',
  hsc = 'haskell',
  hs = 'haskell',
  ht = 'haste',
  htpp = 'hastepreproc',
  hb = 'hb',
  sum = 'hercules',
  errsum = 'hercules',
  ev = 'hercules',
  vc = 'hercules',
  hcl = 'hcl',
  heex = 'heex',
  hex = 'hex',
  ['h32'] = 'hex',
  hjson = 'hjson',
  hog = 'hog',
  hws = 'hollywood',
  hoon = 'hoon',
  htt = 'httest',
  htb = 'httest',
  iba = 'ibasic',
  ibi = 'ibasic',
  icn = 'icon',
  inf = 'inform',
  INF = 'inform',
  ii = 'initng',
  iss = 'iss',
  mst = 'ist',
  ist = 'ist',
  ijs = 'j',
  JAL = 'jal',
  jal = 'jal',
  jpr = 'jam',
  jpl = 'jam',
  jav = 'java',
  java = 'java',
  jj = 'javacc',
  jjt = 'javacc',
  es = 'javascript',
  mjs = 'javascript',
  javascript = 'javascript',
  js = 'javascript',
  cjs = 'javascript',
  jsx = 'javascriptreact',
  clp = 'jess',
  jgr = 'jgraph',
  ['j73'] = 'jovial',
  jov = 'jovial',
  jovial = 'jovial',
  properties = 'jproperties',
  slnf = 'json',
  json = 'json',
  jsonp = 'json',
  webmanifest = 'json',
  ipynb = 'json',
  ['json-patch'] = 'json',
  json5 = 'json5',
  jsonc = 'jsonc',
  jsp = 'jsp',
  jl = 'julia',
  kv = 'kivy',
  kix = 'kix',
  kts = 'kotlin',
  kt = 'kotlin',
  ktm = 'kotlin',
  ks = 'kscript',
  k = 'kwt',
  ACE = 'lace',
  ace = 'lace',
  latte = 'latte',
  lte = 'latte',
  ld = 'ld',
  ldif = 'ldif',
  journal = 'ledger',
  ldg = 'ledger',
  ledger = 'ledger',
  less = 'less',
  lex = 'lex',
  lxx = 'lex',
  ['l++'] = 'lex',
  l = 'lex',
  lhs = 'lhaskell',
  ll = 'lifelines',
  ly = 'lilypond',
  ily = 'lilypond',
  liquid = 'liquid',
  cl = 'lisp',
  L = 'lisp',
  lisp = 'lisp',
  el = 'lisp',
  lsp = 'lisp',
  asd = 'lisp',
  lt = 'lite',
  lite = 'lite',
  lgt = 'logtalk',
  lotos = 'lotos',
  lot = 'lotos',
  lout = 'lout',
  lou = 'lout',
  ulpc = 'lpc',
  lpc = 'lpc',
  sig = 'lprolog',
  lsl = 'lsl',
  lss = 'lss',
  nse = 'lua',
  rockspec = 'lua',
  lua = 'lua',
  quake = 'm3quake',
  at = 'm4',
  eml = 'mail',
  mk = 'make',
  mak = 'make',
  dsp = 'make',
  page = 'mallard',
  map = 'map',
  mws = 'maple',
  mpl = 'maple',
  mv = 'maple',
  mkdn = 'markdown',
  md = 'markdown',
  mdwn = 'markdown',
  mkd = 'markdown',
  markdown = 'markdown',
  mdown = 'markdown',
  mhtml = 'mason',
  comp = 'mason',
  mason = 'mason',
  master = 'master',
  mas = 'master',
  demo = 'maxima',
  dm1 = 'maxima',
  dm2 = 'maxima',
  dm3 = 'maxima',
  dmt = 'maxima',
  wxm = 'maxima',
  mel = 'mel',
  mf = 'mf',
  mgl = 'mgl',
  mgp = 'mgp',
  my = 'mib',
  mib = 'mib',
  mix = 'mix',
  mixal = 'mix',
  nb = 'mma',
  mmp = 'mmp',
  DEF = 'modula2',
  ['m2'] = 'modula2',
  mi = 'modula2',
  ssc = 'monk',
  monk = 'monk',
  tsc = 'monk',
  isc = 'monk',
  moo = 'moo',
  moon = 'moonscript',
  mp = 'mp',
  mof = 'msidl',
  odl = 'msidl',
  msql = 'msql',
  mu = 'mupad',
  mush = 'mush',
  mysql = 'mysql',
  ['n1ql'] = 'n1ql',
  nql = 'n1ql',
  nanorc = 'nanorc',
  ncf = 'ncf',
  nginx = 'nginx',
  ninja = 'ninja',
  nix = 'nix',
  nqc = 'nqc',
  roff = 'nroff',
  tmac = 'nroff',
  man = 'nroff',
  mom = 'nroff',
  nr = 'nroff',
  tr = 'nroff',
  nsi = 'nsis',
  nsh = 'nsis',
  obj = 'obj',
  mlt = 'ocaml',
  mly = 'ocaml',
  mll = 'ocaml',
  mlp = 'ocaml',
  mlip = 'ocaml',
  mli = 'ocaml',
  ml = 'ocaml',
  occ = 'occam',
  xom = 'omnimark',
  xin = 'omnimark',
  opam = 'opam',
  ['or'] = 'openroad',
  scad = 'openscad',
  ora = 'ora',
  org = 'org',
  org_archive = 'org',
  pxsl = 'papp',
  papp = 'papp',
  pxml = 'papp',
  pas = 'pascal',
  lpr = 'pascal',
  dpr = 'pascal',
  pbtxt = 'pbtxt',
  g = 'pccts',
  pcmk = 'pcmk',
  pdf = 'pdf',
  plx = 'perl',
  prisma = 'prisma',
  psgi = 'perl',
  al = 'perl',
  ctp = 'php',
  php = 'php',
  phpt = 'php',
  phtml = 'php',
  pike = 'pike',
  pmod = 'pike',
  rcp = 'pilrc',
  pli = 'pli',
  ['pl1'] = 'pli',
  ['p36'] = 'plm',
  plm = 'plm',
  pac = 'plm',
  plp = 'plp',
  pls = 'plsql',
  plsql = 'plsql',
  po = 'po',
  pot = 'po',
  pod = 'pod',
  pk = 'poke',
  ps = 'postscr',
  epsi = 'postscr',
  afm = 'postscr',
  epsf = 'postscr',
  eps = 'postscr',
  pfa = 'postscr',
  ai = 'postscr',
  pov = 'pov',
  ppd = 'ppd',
  it = 'ppwiz',
  ih = 'ppwiz',
  action = 'privoxy',
  pc = 'proc',
  pdb = 'prolog',
  pml = 'promela',
  proto = 'proto',
  ['psd1'] = 'ps1',
  ['psm1'] = 'ps1',
  ['ps1'] = 'ps1',
  pssc = 'ps1',
  ['ps1xml'] = 'ps1xml',
  psf = 'psf',
  psl = 'psl',
  pug = 'pug',
  arr = 'pyret',
  pxd = 'pyrex',
  pyx = 'pyrex',
  pyw = 'python',
  py = 'python',
  pyi = 'python',
  ptl = 'python',
  ql = 'ql',
  qll = 'ql',
  rad = 'radiance',
  mat = 'radiance',
  ['pod6'] = 'raku',
  rakudoc = 'raku',
  rakutest = 'raku',
  rakumod = 'raku',
  ['pm6'] = 'raku',
  raku = 'raku',
  ['t6'] = 'raku',
  ['p6'] = 'raku',
  raml = 'raml',
  rbs = 'rbs',
  rego = 'rego',
  rem = 'remind',
  remind = 'remind',
  res = 'rescript',
  resi = 'rescript',
  frt = 'reva',
  testUnit = 'rexx',
  rex = 'rexx',
  orx = 'rexx',
  rexx = 'rexx',
  jrexx = 'rexx',
  rxj = 'rexx',
  rexxj = 'rexx',
  testGroup = 'rexx',
  rxo = 'rexx',
  Rd = 'rhelp',
  rd = 'rhelp',
  rib = 'rib',
  Rmd = 'rmd',
  rmd = 'rmd',
  smd = 'rmd',
  Smd = 'rmd',
  rnc = 'rnc',
  rng = 'rng',
  rnw = 'rnoweb',
  snw = 'rnoweb',
  Rnw = 'rnoweb',
  Snw = 'rnoweb',
  robot = 'robot',
  resource = 'robot',
  rsc = 'routeros',
  x = 'rpcgen',
  rpl = 'rpl',
  Srst = 'rrst',
  srst = 'rrst',
  Rrst = 'rrst',
  rrst = 'rrst',
  rst = 'rst',
  rtf = 'rtf',
  rjs = 'ruby',
  rxml = 'ruby',
  rb = 'ruby',
  rant = 'ruby',
  ru = 'ruby',
  rbw = 'ruby',
  gemspec = 'ruby',
  builder = 'ruby',
  rake = 'ruby',
  rs = 'rust',
  sas = 'sas',
  sass = 'sass',
  sa = 'sather',
  sbt = 'sbt',
  scala = 'scala',
  ss = 'scheme',
  scm = 'scheme',
  sld = 'scheme',
  rkt = 'scheme',
  rktd = 'scheme',
  rktl = 'scheme',
  sce = 'scilab',
  sci = 'scilab',
  scss = 'scss',
  sd = 'sd',
  sdc = 'sdc',
  pr = 'sdl',
  sdl = 'sdl',
  sed = 'sed',
  sexp = 'sexplib',
  sieve = 'sieve',
  siv = 'sieve',
  sil = 'sil',
  sim = 'simula',
  ['s85'] = 'sinda',
  sin = 'sinda',
  ssm = 'sisu',
  sst = 'sisu',
  ssi = 'sisu',
  ['_sst'] = 'sisu',
  ['-sst'] = 'sisu',
  il = 'skill',
  ils = 'skill',
  cdf = 'skill',
  sl = 'slang',
  ice = 'slice',
  score = 'slrnsc',
  sol = 'solidity',
  tpl = 'smarty',
  ihlp = 'smcl',
  smcl = 'smcl',
  hlp = 'smcl',
  smith = 'smith',
  smt = 'smith',
  sml = 'sml',
  spt = 'snobol4',
  sno = 'snobol4',
  sln = 'solution',
  sparql = 'sparql',
  rq = 'sparql',
  spec = 'spec',
  spice = 'spice',
  sp = 'spice',
  spd = 'spup',
  spdata = 'spup',
  speedup = 'spup',
  spi = 'spyce',
  spy = 'spyce',
  tyc = 'sql',
  typ = 'sql',
  pkb = 'sql',
  tyb = 'sql',
  pks = 'sql',
  sqlj = 'sqlj',
  sqi = 'sqr',
  sqr = 'sqr',
  nut = 'squirrel',
  ['s28'] = 'srec',
  ['s37'] = 'srec',
  srec = 'srec',
  mot = 'srec',
  ['s19'] = 'srec',
  st = 'st',
  imata = 'stata',
  ['do'] = 'stata',
  mata = 'stata',
  ado = 'stata',
  stp = 'stp',
  quark = 'supercollider',
  sface = 'surface',
  svelte = 'svelte',
  svg = 'svg',
  swift = 'swift',
  svh = 'systemverilog',
  sv = 'systemverilog',
  tak = 'tak',
  task = 'taskedit',
  tm = 'tcl',
  tcl = 'tcl',
  itk = 'tcl',
  itcl = 'tcl',
  tk = 'tcl',
  jacl = 'tcl',
  tl = 'teal',
  tmpl = 'template',
  ti = 'terminfo',
  dtx = 'tex',
  ltx = 'tex',
  bbl = 'tex',
  latex = 'tex',
  sty = 'tex',
  cls = function(path, bufnr)
    local line = getline(bufnr, 1)
    if line:find('^%%') then
      return 'tex'
    elseif line:find('^#') and line:lower():find('rexx') then
      return 'rexx'
    else
      return 'st'
    end
  end,
  texi = 'texinfo',
  txi = 'texinfo',
  texinfo = 'texinfo',
  text = 'text',
  tfvars = 'terraform',
  tla = 'tla',
  tli = 'tli',
  toml = 'toml',
  tpp = 'tpp',
  treetop = 'treetop',
  slt = 'tsalt',
  tsscl = 'tsscl',
  tssgm = 'tssgm',
  tssop = 'tssop',
  tutor = 'tutor',
  twig = 'twig',
  ts = function(path, bufnr)
    if getline(bufnr, 1):find('<%?xml') then
      return 'xml'
    else
      return 'typescript'
    end
  end,
  tsx = 'typescriptreact',
  uc = 'uc',
  uit = 'uil',
  uil = 'uil',
  sba = 'vb',
  vb = 'vb',
  dsm = 'vb',
  ctl = 'vb',
  vbs = 'vb',
  vr = 'vera',
  vri = 'vera',
  vrh = 'vera',
  v = 'verilog',
  va = 'verilogams',
  vams = 'verilogams',
  vhdl = 'vhdl',
  vst = 'vhdl',
  vhd = 'vhdl',
  hdl = 'vhdl',
  vho = 'vhdl',
  vbe = 'vhdl',
  vim = 'vim',
  vba = 'vim',
  mar = 'vmasm',
  cm = 'voscm',
  wrl = 'vrml',
  vroom = 'vroom',
  vue = 'vue',
  wat = 'wast',
  wast = 'wast',
  wm = 'webmacro',
  wbt = 'winbatch',
  wml = 'wml',
  wsml = 'wsml',
  ad = 'xdefaults',
  xhtml = 'xhtml',
  xht = 'xhtml',
  msc = 'xmath',
  msf = 'xmath',
  ['psc1'] = 'xml',
  tpm = 'xml',
  xliff = 'xml',
  atom = 'xml',
  xul = 'xml',
  cdxml = 'xml',
  mpd = 'xml',
  rss = 'xml',
  fsproj = 'xml',
  ui = 'xml',
  vbproj = 'xml',
  xlf = 'xml',
  wsdl = 'xml',
  csproj = 'xml',
  wpl = 'xml',
  xmi = 'xml',
  xpm = function(path, bufnr)
    if getline(bufnr, 1):find('XPM2') then
      return 'xpm2'
    end
    return 'xpm'
  end,
  ['xpm2'] = 'xpm2',
  xqy = 'xquery',
  xqm = 'xquery',
  xquery = 'xquery',
  xq = 'xquery',
  xql = 'xquery',
  xs = 'xs',
  xsd = 'xsd',
  xsl = 'xslt',
  xslt = 'xslt',
  yy = 'yacc',
  ['y++'] = 'yacc',
  yxx = 'yacc',
  yml = 'yaml',
  yaml = 'yaml',
  yang = 'yang',
  ['z8a'] = 'z8a',
  zig = 'zig',
  zu = 'zimbu',
  zut = 'zimbutempl',
  zsh = 'zsh',
  vala = 'vala',
  E = function(path, bufnr)
    return require('vim.filetype.detect').e(bufnr)
  end,
  EU = function(path, bufnr)
    return require('vim.filetype.detect').euphoria(bufnr)
  end,
  EW = function(path, bufnr)
    return require('vim.filetype.detect').euphoria(bufnr)
  end,
  EX = function(path, bufnr)
    return require('vim.filetype.detect').euphoria(bufnr)
  end,
  EXU = function(path, bufnr)
    return require('vim.filetype.detect').euphoria(bufnr)
  end,
  EXW = function(path, bufnr)
    return require('vim.filetype.detect').euphoria(bufnr)
  end,
  PL = function(path, bufnr)
    return require('vim.filetype.detect').pl(bufnr)
  end,
  R = function(path, bufnr)
    return require('vim.filetype.detect').r(bufnr)
  end,
  asm = function(path, bufnr)
    return require('vim.filetype.detect').asm(bufnr)
  end,
  bas = function(path, bufnr)
    return require('vim.filetype.detect').bas(bufnr)
  end,
  bi = function(path, bufnr)
    return require('vim.filetype.detect').bas(bufnr)
  end,
  bm = function(path, bufnr)
    return require('vim.filetype.detect').bas(bufnr)
  end,
  bash = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, 'bash')
  end,
  btm = function(path, bufnr)
    return require('vim.filetype.detect').btm(bufnr)
  end,
  c = function(path, bufnr)
    return require('vim.filetype.detect').lpc(bufnr)
  end,
  ch = function(path, bufnr)
    return require('vim.filetype.detect').change(bufnr)
  end,
  com = function(path, bufnr)
    return require('vim.filetype.detect').bindzone(bufnr, 'dcl')
  end,
  cpt = function(path, bufnr)
    return require('vim.filetype.detect').html(bufnr)
  end,
  csh = function(path, bufnr)
    return require('vim.filetype.detect').csh(path, bufnr)
  end,
  d = function(path, bufnr)
    return require('vim.filetype.detect').dtrace(bufnr)
  end,
  db = function(path, bufnr)
    return require('vim.filetype.detect').bindzone(bufnr, '')
  end,
  dtml = function(path, bufnr)
    return require('vim.filetype.detect').html(bufnr)
  end,
  e = function(path, bufnr)
    return require('vim.filetype.detect').e(bufnr)
  end,
  ebuild = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, 'bash')
  end,
  eclass = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, 'bash')
  end,
  ent = function(path, bufnr)
    return require('vim.filetype.detect').ent(bufnr)
  end,
  env = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, getline(bufnr, 1))
  end,
  eu = function(path, bufnr)
    return require('vim.filetype.detect').euphoria(bufnr)
  end,
  ew = function(path, bufnr)
    return require('vim.filetype.detect').euphoria(bufnr)
  end,
  ex = function(path, bufnr)
    return require('vim.filetype.detect').ex(bufnr)
  end,
  exu = function(path, bufnr)
    return require('vim.filetype.detect').euphoria(bufnr)
  end,
  exw = function(path, bufnr)
    return require('vim.filetype.detect').euphoria(bufnr)
  end,
  frm = function(path, bufnr)
    return require('vim.filetype.detect').frm(bufnr)
  end,
  fs = function(path, bufnr)
    return require('vim.filetype.detect').fs(bufnr)
  end,
  h = function(path, bufnr)
    return require('vim.filetype.detect').header(bufnr)
  end,
  htm = function(path, bufnr)
    return require('vim.filetype.detect').html(bufnr)
  end,
  html = function(path, bufnr)
    return require('vim.filetype.detect').html(bufnr)
  end,
  i = function(path, bufnr)
    return require('vim.filetype.detect').progress_asm(bufnr)
  end,
  idl = function(path, bufnr)
    return require('vim.filetype.detect').idl(bufnr)
  end,
  inc = function(path, bufnr)
    return require('vim.filetype.detect').inc(bufnr)
  end,
  inp = function(path, bufnr)
    return require('vim.filetype.detect').inp(bufnr)
  end,
  ksh = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, 'ksh')
  end,
  lst = function(path, bufnr)
    return require('vim.filetype.detect').asm(bufnr)
  end,
  m = function(path, bufnr)
    return require('vim.filetype.detect').m(bufnr)
  end,
  mac = function(path, bufnr)
    return require('vim.filetype.detect').asm(bufnr)
  end,
  mc = function(path, bufnr)
    return require('vim.filetype.detect').mc(bufnr)
  end,
  mm = function(path, bufnr)
    return require('vim.filetype.detect').mm(bufnr)
  end,
  mms = function(path, bufnr)
    return require('vim.filetype.detect').mms(bufnr)
  end,
  p = function(path, bufnr)
    return require('vim.filetype.detect').progress_pascal(bufnr)
  end,
  patch = function(path, bufnr)
    local firstline = getline(bufnr, 1)
    if string.find(firstline, '^From ' .. string.rep('%x', 40) .. '+ Mon Sep 17 00:00:00 2001$') then
      return 'gitsendemail'
    else
      return 'diff'
    end
  end,
  pl = function(path, bufnr)
    return require('vim.filetype.detect').pl(bufnr)
  end,
  pp = function(path, bufnr)
    return require('vim.filetype.detect').pp(bufnr)
  end,
  pro = function(path, bufnr)
    return require('vim.filetype.detect').proto(bufnr, 'idlang')
  end,
  pt = function(path, bufnr)
    return require('vim.filetype.detect').html('idlang')
  end,
  r = function(path, bufnr)
    return require('vim.filetype.detect').r(bufnr)
  end,
  rdf = function(path, bufnr)
    return require('vim.filetype.detect').redif(bufnr)
  end,
  rules = function(path, bufnr)
    return require('vim.filetype.detect').rules(path, bufnr)
  end,
  sc = function(path, bufnr)
    return require('vim.filetype.detect').sc(bufnr)
  end,
  scd = function(path, bufnr)
    return require('vim.filetype.detect').scd(bufnr)
  end,
  sh = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, getline(bufnr, 1))
  end,
  shtml = function(path, bufnr)
    return require('vim.filetype.detect').html(bufnr)
  end,
  sql = function(path, bufnr)
    return require('vim.filetype.detect').sql(bufnr)
  end,
  stm = function(path, bufnr)
    return require('vim.filetype.detect').html(bufnr)
  end,
  tcsh = function(path, bufnr)
    return require('vim.filetype.detect').shell(path, bufnr, 'tcsh')
  end,
  tex = function(path, bufnr)
    return require('vim.filetype.detect').tex(path, bufnr)
  end,
  tf = function(path, bufnr)
    return require('vim.filetype.detect').tf(bufnr)
  end,
  w = function(path, bufnr)
    return require('vim.filetype.detect').progress_cweb(bufnr)
  end,
  xml = function(path, bufnr)
    return require('vim.filetype.detect').xml(bufnr)
  end,
  y = function(path, bufnr)
    return require('vim.filetype.detect').y(bufnr)
  end,
  zsql = function(path, bufnr)
    return require('vim.filetype.detect').sql(bufnr)
  end,
  txt = function(path, bufnr)
    --helpfiles match *.txt, but should have a modeline as last line
    if not getline(bufnr, -1):find('vim:.*ft=help') then
      return 'text'
    end
  end,
  cmd = function(path, bufnr)
    if getline(bufnr, 1):find('^/%*') then
      return 'rexx'
    end
    return 'dosbatch'
  end,
  rul = function(path, bufnr)
    return require('vim.filetype.detect').rul(bufnr)
  end,
  cpy = function(path, bufnr)
    if getline(bufnr, 1):find('^##') then
      return 'python'
    end
    return 'cobol'
  end,
  dsl = function(path, bufnr)
    if getline(bufnr, 1):find('^%s*<!') then
      return 'dsl'
    end
    return 'structurizr'
  end,
  edf = 'edif',
  edfi = 'edif',
  edo = 'edif',
  edn = function(path, bufnr)
    return require('vim.filetype.detect').edn(bufnr)
  end,
  smil = function(path, bufnr)
    if getline(bufnr, 1):find('<%?%s*xml.*%?>') then
      return 'xml'
    end
    return 'smil'
  end,
  smi = function(path, bufnr)
    return require('vim.filetype.detect').smi(bufnr)
  end,
  install = function(path, bufnr)
    if getline(bufnr, 1):lower():find('<%?php') then
      return 'php'
    end
    return require('vim.filetype.detect').sh(path, bufnr, 'bash')
  end,
  pm = function(path, bufnr)
    local line = getline(bufnr, 1)
    if line:find('XPM2') then
      return 'xpm2'
    elseif line:find('XPM') then
      return 'xpm'
    else
      return 'perl'
    end
  end,
  me = function(path, bufnr)
    local filename = vim.fn.fnamemodify(path, ':t'):lower()
    if filename ~= 'read.me' and filename ~= 'click.me' then
      return 'nroff'
    end
  end,
  reg = function(path, bufnr)
    local line = getline(bufnr, 1):lower()
    if line:find('^regedit[0-9]*%s*$') or line:find('^windows registry editor version %d*%.%d*%s*$') then
      return 'registry'
    end
  end,
  decl = function(path, bufnr)
    return require('vim.filetype.detect').decl(bufnr)
  end,
  dec = function(path, bufnr)
    return require('vim.filetype.detect').decl(bufnr)
  end,
  dcl = function(path, bufnr)
    local decl = require('vim.filetype.detect').decl(bufnr)
    if decl then
      return decl
    end
    return 'clean'
  end,
  web = function(path, bufnr)
    return require('vim.filetype.detect').web(bufnr)
  end,
  ttl = function(path, bufnr)
    local line = getline(bufnr, 1):lower()
    if line:find('^@?prefix') or line:find('^@?base') then
      return 'turtle'
    end
    return 'teraterm'
  end,
  am = function(path, bufnr)
    if not path:lower():find('makefile%.am$') then
      return 'elf'
    end
  end,
  ['m4'] = function(path, bufnr)
    local path_lower = path:lower()
    if not path_lower:find('html%.m4$') and not path_lower:find('fvwm2rc') then
      return 'm4'
    end
  end,
  hw = function(path, bufnr)
    return require('vim.filetype.detect').hw(bufnr)
  end,
  module = function(path, bufnr)
    return require('vim.filetype.detect').hw(bufnr)
  end,
  pkg = function(path, bufnr)
    return require('vim.filetype.detect').hw(bufnr)
  end,
  ms = function(path, bufnr)
    if not require('vim.filetype.detect').nroff(bufnr) then
      return 'xmath'
    end
  end,
  t = function(path, bufnr)
    if not require('vim.filetype.detect').nroff(bufnr) and not require('vim.filetype.detect').perl(path, bufnr) then
      return 'tads'
    end
  end,
  class = function(path, bufnr)
    -- Check if not a Java class (starts with '\xca\xfe\xba\xbe')
    if not getline(bufnr, 1):find('^\202\254\186\190') then
      return 'stata'
    end
  end,
  sgml = function(path, bufnr)
    return require('vim.filetype.detect').sgml(bufnr)
  end,
  sgm = function(path, bufnr)
    return require('vim.filetype.detect').sgml(bufnr)
  end,
  rc = function(path, bufnr)
    if not path:find('/etc/Muttrc%.d/') then
      return 'rc'
    end
  end,
  rch = function(path, bufnr)
    if not path:find('/etc/Muttrc%.d/') then
      return 'rc'
    end
  end,
  control = function(path, bufnr)
    return require('vim.filetype.detect').control(bufnr)
  end,
  copyright = function(path, bufnr)
    return require('vim.filetype.detect').copyright(bufnr)
  end,
  -- Ignored extensions
  bak = function(path, bufnr)
    local root = vim.fn.fnamemodify(path, ':r')
    return M.match(root, bufnr)
  end,
  ['dpkg-dist'] = function(path, bufnr)
    local root = vim.fn.fnamemodify(path, ':r')
    return M.match(root, bufnr)
  end,
  ['dpkg-old'] = function(path, bufnr)
    local root = vim.fn.fnamemodify(path, ':r')
    return M.match(root, bufnr)
  end,
  ['dpkg-new'] = function(path, bufnr)
    local root = vim.fn.fnamemodify(path, ':r')
    return M.match(root, bufnr)
  end,
  ['dpkg-bak'] = function(path, bufnr)
    local root = vim.fn.fnamemodify(path, ':r')
    return M.match(root, bufnr)
  end,
  new = function(path, bufnr)
    local root = vim.fn.fnamemodify(path, ':r')
    return M.match(root, bufnr)
  end,
  old = function(path, bufnr)
    local root = vim.fn.fnamemodify(path, ':r')
    return M.match(root, bufnr)
  end,
  orig = function(path, bufnr)
    local root = vim.fn.fnamemodify(path, ':r')
    return M.match(root, bufnr)
  end,
  pacsave = function(path, bufnr)
    local root = vim.fn.fnamemodify(path, ':r')
    return M.match(root, bufnr)
  end,
  pacnew = function(path, bufnr)
    local root = vim.fn.fnamemodify(path, ':r')
    return M.match(root, bufnr)
  end,
  rpmsave = function(path, bufnr)
    local root = vim.fn.fnamemodify(path, ':r')
    return M.match(root, bufnr)
  end,
  rmpnew = function(path, bufnr)
    local root = vim.fn.fnamemodify(path, ':r')
    return M.match(root, bufnr)
  end,
  ['in'] = function(path, bufnr)
    if vim.fs.basename(path) ~= 'configure.in' then
      local root = vim.fn.fnamemodify(path, ':r')
      return M.match(root, bufnr)
    end
  end,
  -- END EXTENSION
}

local filename = {
  -- BEGIN FILENAME
  ['a2psrc'] = 'a2ps',
  ['/etc/a2ps.cfg'] = 'a2ps',
  ['.a2psrc'] = 'a2ps',
  ['.asoundrc'] = 'alsaconf',
  ['/usr/share/alsa/alsa.conf'] = 'alsaconf',
  ['/etc/asound.conf'] = 'alsaconf',
  ['build.xml'] = 'ant',
  ['.htaccess'] = 'apache',
  ['apt.conf'] = 'aptconf',
  ['/.aptitude/config'] = 'aptconf',
  ['=tagging-method'] = 'arch',
  ['.arch-inventory'] = 'arch',
  ['GNUmakefile.am'] = 'automake',
  ['named.root'] = 'bindzone',
  WORKSPACE = 'bzl',
  BUILD = 'bzl',
  ['cabal.project'] = 'cabalproject',
  [vim.env.HOME .. '/cabal.config'] = 'cabalconfig',
  ['cabal.config'] = 'cabalconfig',
  calendar = 'calendar',
  catalog = 'catalog',
  ['/etc/cdrdao.conf'] = 'cdrdaoconf',
  ['.cdrdao'] = 'cdrdaoconf',
  ['/etc/default/cdrdao'] = 'cdrdaoconf',
  ['/etc/defaults/cdrdao'] = 'cdrdaoconf',
  ['cfengine.conf'] = 'cfengine',
  ['CMakeLists.txt'] = 'cmake',
  ['auto.master'] = 'conf',
  ['configure.in'] = 'config',
  ['configure.ac'] = 'config',
  ['.cvsrc'] = 'cvsrc',
  ['/debian/changelog'] = 'debchangelog',
  ['changelog.dch'] = 'debchangelog',
  ['changelog.Debian'] = 'debchangelog',
  ['NEWS.dch'] = 'debchangelog',
  ['NEWS.Debian'] = 'debchangelog',
  ['/debian/control'] = 'debcontrol',
  ['/debian/copyright'] = 'debcopyright',
  ['/etc/apt/sources.list'] = 'debsources',
  ['denyhosts.conf'] = 'denyhosts',
  ['dict.conf'] = 'dictconf',
  ['.dictrc'] = 'dictconf',
  ['/etc/DIR_COLORS'] = 'dircolors',
  ['.dir_colors'] = 'dircolors',
  ['.dircolors'] = 'dircolors',
  ['/etc/dnsmasq.conf'] = 'dnsmasq',
  Containerfile = 'dockerfile',
  dockerfile = 'dockerfile',
  Dockerfile = 'dockerfile',
  npmrc = 'dosini',
  ['/etc/yum.conf'] = 'dosini',
  ['.npmrc'] = 'dosini',
  ['.editorconfig'] = 'dosini',
  ['/etc/pacman.conf'] = 'confini',
  ['mpv.conf'] = 'confini',
  dune = 'dune',
  jbuild = 'dune',
  ['dune-workspace'] = 'dune',
  ['dune-project'] = 'dune',
  ['elinks.conf'] = 'elinks',
  ['mix.lock'] = 'elixir',
  ['filter-rules'] = 'elmfilt',
  ['exim.conf'] = 'exim',
  exports = 'exports',
  ['.fetchmailrc'] = 'fetchmail',
  fvSchemes = function(path, bufnr)
    return require('vim.filetype.detect').foam(bufnr)
  end,
  fvSolution = function(path, bufnr)
    return require('vim.filetype.detect').foam(bufnr)
  end,
  fvConstraints = function(path, bufnr)
    return require('vim.filetype.detect').foam(bufnr)
  end,
  fvModels = function(path, bufnr)
    return require('vim.filetype.detect').foam(bufnr)
  end,
  fstab = 'fstab',
  mtab = 'fstab',
  ['.gdbinit'] = 'gdb',
  gdbinit = 'gdb',
  ['.gdbearlyinit'] = 'gdb',
  gdbearlyinit = 'gdb',
  ['lltxxxxx.txt'] = 'gedcom',
  ['TAG_EDITMSG'] = 'gitcommit',
  ['MERGE_MSG'] = 'gitcommit',
  ['COMMIT_EDITMSG'] = 'gitcommit',
  ['NOTES_EDITMSG'] = 'gitcommit',
  ['EDIT_DESCRIPTION'] = 'gitcommit',
  ['.gitconfig'] = 'gitconfig',
  ['.gitmodules'] = 'gitconfig',
  ['gitolite.conf'] = 'gitolite',
  ['git-rebase-todo'] = 'gitrebase',
  gkrellmrc = 'gkrellmrc',
  ['.gnashrc'] = 'gnash',
  ['.gnashpluginrc'] = 'gnash',
  gnashpluginrc = 'gnash',
  gnashrc = 'gnash',
  ['go.work'] = 'gowork',
  ['.gprc'] = 'gp',
  ['/.gnupg/gpg.conf'] = 'gpg',
  ['/.gnupg/options'] = 'gpg',
  ['/var/backups/gshadow.bak'] = 'group',
  ['/etc/gshadow'] = 'group',
  ['/etc/group-'] = 'group',
  ['/etc/gshadow.edit'] = 'group',
  ['/etc/gshadow-'] = 'group',
  ['/etc/group'] = 'group',
  ['/var/backups/group.bak'] = 'group',
  ['/etc/group.edit'] = 'group',
  ['/boot/grub/menu.lst'] = 'grub',
  ['/etc/grub.conf'] = 'grub',
  ['/boot/grub/grub.conf'] = 'grub',
  ['.gtkrc'] = 'gtkrc',
  gtkrc = 'gtkrc',
  ['snort.conf'] = 'hog',
  ['vision.conf'] = 'hog',
  ['/etc/host.conf'] = 'hostconf',
  ['/etc/hosts.allow'] = 'hostsaccess',
  ['/etc/hosts.deny'] = 'hostsaccess',
  ['/i3/config'] = 'i3config',
  ['/sway/config'] = 'i3config',
  ['/.sway/config'] = 'i3config',
  ['/.i3/config'] = 'i3config',
  ['/.icewm/menu'] = 'icemenu',
  ['.indent.pro'] = 'indent',
  indentrc = 'indent',
  inittab = 'inittab',
  ['ipf.conf'] = 'ipfilter',
  ['ipf6.conf'] = 'ipfilter',
  ['ipf.rules'] = 'ipfilter',
  ['.eslintrc'] = 'json',
  ['.babelrc'] = 'json',
  ['Pipfile.lock'] = 'json',
  ['.firebaserc'] = 'json',
  ['.prettierrc'] = 'json',
  Kconfig = 'kconfig',
  ['Kconfig.debug'] = 'kconfig',
  ['lftp.conf'] = 'lftp',
  ['.lftprc'] = 'lftp',
  ['/.libao'] = 'libao',
  ['/etc/libao.conf'] = 'libao',
  ['lilo.conf'] = 'lilo',
  ['/etc/limits'] = 'limits',
  ['.emacs'] = 'lisp',
  sbclrc = 'lisp',
  ['.sbclrc'] = 'lisp',
  ['.sawfishrc'] = 'lisp',
  ['/etc/login.access'] = 'loginaccess',
  ['/etc/login.defs'] = 'logindefs',
  ['lynx.cfg'] = 'lynx',
  ['m3overrides'] = 'm3build',
  ['m3makefile'] = 'm3build',
  ['cm3.cfg'] = 'm3quake',
  ['.followup'] = 'mail',
  ['.article'] = 'mail',
  ['.letter'] = 'mail',
  ['/etc/aliases'] = 'mailaliases',
  ['/etc/mail/aliases'] = 'mailaliases',
  mailcap = 'mailcap',
  ['.mailcap'] = 'mailcap',
  ['/etc/man.conf'] = 'manconf',
  ['man.config'] = 'manconf',
  ['maxima-init.mac'] = 'maxima',
  ['meson.build'] = 'meson',
  ['meson_options.txt'] = 'meson',
  ['/etc/conf.modules'] = 'modconf',
  ['/etc/modules'] = 'modconf',
  ['/etc/modules.conf'] = 'modconf',
  ['/.mplayer/config'] = 'mplayerconf',
  ['mplayer.conf'] = 'mplayerconf',
  mrxvtrc = 'mrxvtrc',
  ['.mrxvtrc'] = 'mrxvtrc',
  ['/etc/nanorc'] = 'nanorc',
  Neomuttrc = 'neomuttrc',
  ['.netrc'] = 'netrc',
  NEWS = function(path, bufnr)
    return require('vim.filetype.detect').news(bufnr)
  end,
  ['.ocamlinit'] = 'ocaml',
  ['.octaverc'] = 'octave',
  octaverc = 'octave',
  ['octave.conf'] = 'octave',
  opam = 'opam',
  ['/etc/pam.conf'] = 'pamconf',
  ['pam_env.conf'] = 'pamenv',
  ['.pam_environment'] = 'pamenv',
  ['/var/backups/passwd.bak'] = 'passwd',
  ['/var/backups/shadow.bak'] = 'passwd',
  ['/etc/passwd'] = 'passwd',
  ['/etc/passwd-'] = 'passwd',
  ['/etc/shadow.edit'] = 'passwd',
  ['/etc/shadow-'] = 'passwd',
  ['/etc/shadow'] = 'passwd',
  ['/etc/passwd.edit'] = 'passwd',
  ['pf.conf'] = 'pf',
  ['main.cf'] = 'pfmain',
  pinerc = 'pine',
  ['.pinercex'] = 'pine',
  ['.pinerc'] = 'pine',
  pinercex = 'pine',
  ['/etc/pinforc'] = 'pinfo',
  ['/.pinforc'] = 'pinfo',
  ['.povrayrc'] = 'povini',
  ['printcap'] = function(path, bufnr)
    return 'ptcap', function(b)
      vim.b[b].ptcap_type = 'print'
    end
  end,
  ['termcap'] = function(path, bufnr)
    return 'ptcap', function(b)
      vim.b[b].ptcap_type = 'term'
    end
  end,
  ['.procmailrc'] = 'procmail',
  ['.procmail'] = 'procmail',
  ['/etc/protocols'] = 'protocols',
  ['INDEX'] = function(path, bufnr)
    return require('vim.filetype.detect').psf(bufnr)
  end,
  ['INFO'] = function(path, bufnr)
    return require('vim.filetype.detect').psf(bufnr)
  end,
  ['.pythonstartup'] = 'python',
  ['.pythonrc'] = 'python',
  SConstruct = 'python',
  ratpoisonrc = 'ratpoison',
  ['.ratpoisonrc'] = 'ratpoison',
  inputrc = 'readline',
  ['.inputrc'] = 'readline',
  ['.reminders'] = 'remind',
  ['resolv.conf'] = 'resolv',
  ['robots.txt'] = 'robots',
  Gemfile = 'ruby',
  Puppetfile = 'ruby',
  ['.irbrc'] = 'ruby',
  irbrc = 'ruby',
  Vagrantfile = 'ruby',
  ['smb.conf'] = 'samba',
  screenrc = 'screen',
  ['.screenrc'] = 'screen',
  ['/etc/sensors3.conf'] = 'sensors',
  ['/etc/sensors.conf'] = 'sensors',
  ['/etc/services'] = 'services',
  ['/etc/serial.conf'] = 'setserial',
  ['/etc/udev/cdsymlinks.conf'] = 'sh',
  ['/etc/slp.conf'] = 'slpconf',
  ['/etc/slp.reg'] = 'slpreg',
  ['/etc/slp.spi'] = 'slpspi',
  ['.slrnrc'] = 'slrnrc',
  ['sendmail.cf'] = 'sm',
  ['squid.conf'] = 'squid',
  ['/.ssh/config'] = 'sshconfig',
  ['ssh_config'] = 'sshconfig',
  ['sshd_config'] = 'sshdconfig',
  ['/etc/sudoers'] = 'sudoers',
  ['sudoers.tmp'] = 'sudoers',
  ['/etc/sysctl.conf'] = 'sysctl',
  tags = 'tags',
  ['.tclshrc'] = 'tcl',
  ['.wishrc'] = 'tcl',
  ['tclsh.rc'] = 'tcl',
  ['texmf.cnf'] = 'texmf',
  COPYING = 'text',
  README = 'text',
  LICENSE = 'text',
  AUTHORS = 'text',
  tfrc = 'tf',
  ['.tfrc'] = 'tf',
  ['tidy.conf'] = 'tidy',
  tidyrc = 'tidy',
  ['.tidyrc'] = 'tidy',
  ['.tmux.conf'] = 'tmux',
  ['/.cargo/config'] = 'toml',
  Pipfile = 'toml',
  ['Gopkg.lock'] = 'toml',
  ['/.cargo/credentials'] = 'toml',
  ['Cargo.lock'] = 'toml',
  ['trustees.conf'] = 'trustees',
  ['/etc/udev/udev.conf'] = 'udevconf',
  ['/etc/updatedb.conf'] = 'updatedb',
  ['fdrupstream.log'] = 'upstreamlog',
  vgrindefs = 'vgrindefs',
  ['.exrc'] = 'vim',
  ['_exrc'] = 'vim',
  ['_viminfo'] = 'viminfo',
  ['.viminfo'] = 'viminfo',
  ['.wgetrc'] = 'wget',
  ['.wget2rc'] = 'wget2',
  wgetrc = 'wget',
  wget2rc = 'wget2',
  ['.wvdialrc'] = 'wvdial',
  ['wvdial.conf'] = 'wvdial',
  ['.Xresources'] = 'xdefaults',
  ['.Xpdefaults'] = 'xdefaults',
  ['xdm-config'] = 'xdefaults',
  ['.Xdefaults'] = 'xdefaults',
  ['xorg.conf'] = function(path, bufnr)
    return 'xf86conf', function(b)
      vim.b[b].xf86conf_xfree86_version = 4
    end
  end,
  ['xorg.conf-4'] = function(path, bufnr)
    return 'xf86conf', function(b)
      vim.b[b].xf86conf_xfree86_version = 4
    end
  end,
  ['/etc/xinetd.conf'] = 'xinetd',
  fglrxrc = 'xml',
  ['/etc/blkid.tab'] = 'xml',
  ['/etc/blkid.tab.old'] = 'xml',
  ['/etc/zprofile'] = 'zsh',
  ['.zlogin'] = 'zsh',
  ['.zlogout'] = 'zsh',
  ['.zshrc'] = 'zsh',
  ['.zprofile'] = 'zsh',
  ['.zcompdump'] = 'zsh',
  ['.zshenv'] = 'zsh',
  ['.zfbfmarks'] = 'zsh',
  ['.alias'] = function(path, bufnr)
    return require('vim.filetype.detect').csh(path, bufnr)
  end,
  ['.bashrc'] = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, 'bash')
  end,
  ['.cshrc'] = function(path, bufnr)
    return require('vim.filetype.detect').csh(path, bufnr)
  end,
  ['.env'] = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, getline(bufnr, 1))
  end,
  ['.kshrc'] = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, 'ksh')
  end,
  ['.login'] = function(path, bufnr)
    return require('vim.filetype.detect').csh(path, bufnr)
  end,
  ['.profile'] = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, getline(bufnr, 1))
  end,
  ['.tcshrc'] = function(path, bufnr)
    return require('vim.filetype.detect').shell(path, bufnr, 'tcsh')
  end,
  ['/etc/profile'] = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, getline(bufnr, 1))
  end,
  APKBUILD = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, 'bash')
  end,
  PKGBUILD = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, 'bash')
  end,
  ['bash.bashrc'] = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, 'bash')
  end,
  bashrc = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, 'bash')
  end,
  crontab = 'crontab',
  ['csh.cshrc'] = function(path, bufnr)
    return require('vim.filetype.detect').csh(path, bufnr)
  end,
  ['csh.login'] = function(path, bufnr)
    return require('vim.filetype.detect').csh(path, bufnr)
  end,
  ['csh.logout'] = function(path, bufnr)
    return require('vim.filetype.detect').csh(path, bufnr)
  end,
  ['indent.pro'] = function(path, bufnr)
    return require('vim.filetype.detect').proto(bufnr, 'indent')
  end,
  ['tcsh.login'] = function(path, bufnr)
    return require('vim.filetype.detect').shell(path, bufnr, 'tcsh')
  end,
  ['tcsh.tcshrc'] = function(path, bufnr)
    return require('vim.filetype.detect').shell(path, bufnr, 'tcsh')
  end,
  ['XF86Config'] = function(path, bufnr)
    return require('vim.filetype.detect').xfree86(bufnr)
  end,
  -- END FILENAME
}

local pattern = {
  -- BEGIN PATTERN
  ['.*/etc/a2ps/.*%.cfg'] = 'a2ps',
  ['.*/etc/a2ps%.cfg'] = 'a2ps',
  ['.*/usr/share/alsa/alsa%.conf'] = 'alsaconf',
  ['.*/etc/asound%.conf'] = 'alsaconf',
  ['.*/etc/apache2/sites%-.*/.*%.com'] = 'apache',
  ['.*/etc/httpd/.*%.conf'] = 'apache',
  ['.*/%.aptitude/config'] = 'aptconf',
  ['[mM]akefile%.am'] = 'automake',
  ['.*bsd'] = 'bsdl',
  ['bzr_log%..*'] = 'bzr',
  ['.*enlightenment/.*%.cfg'] = 'c',
  ['.*/%.calendar/.*'] = starsetf('calendar'),
  ['.*/share/calendar/.*/calendar%..*'] = starsetf('calendar'),
  ['.*/share/calendar/calendar%..*'] = starsetf('calendar'),
  ['.*/etc/defaults/cdrdao'] = 'cdrdaoconf',
  ['.*/etc/cdrdao%.conf'] = 'cdrdaoconf',
  ['.*/etc/default/cdrdao'] = 'cdrdaoconf',
  ['.*hgrc'] = 'cfg',
  ['.*%.%.ch'] = 'chill',
  ['.*%.cmake%.in'] = 'cmake',
  -- */cmus/rc and */.cmus/rc
  ['.*/%.?cmus/rc'] = 'cmusrc',
  -- */cmus/*.theme and */.cmus/*.theme
  ['.*/%.?cmus/.*%.theme'] = 'cmusrc',
  ['.*/%.cmus/autosave'] = 'cmusrc',
  ['.*/%.cmus/command%-history'] = 'cmusrc',
  ['cvs%d+'] = 'cvs',
  ['.*/debian/changelog'] = 'debchangelog',
  ['.*/debian/control'] = 'debcontrol',
  ['.*/debian/copyright'] = 'debcopyright',
  ['.*/etc/apt/sources%.list%.d/.*%.list'] = 'debsources',
  ['.*/etc/apt/sources%.list'] = 'debsources',
  ['dictd.*%.conf'] = 'dictdconf',
  ['.*/etc/DIR_COLORS'] = 'dircolors',
  ['.*/etc/dnsmasq%.conf'] = 'dnsmasq',
  ['php%.ini%-.*'] = 'dosini',
  ['.*/etc/pacman%.conf'] = 'confini',
  ['.*/etc/yum%.conf'] = 'dosini',
  ['.*lvs'] = 'dracula',
  ['.*lpe'] = 'dracula',
  ['.*/dtrace/.*%.d'] = 'dtrace',
  ['.*esmtprc'] = 'esmtprc',
  ['.*Eterm/.*%.cfg'] = 'eterm',
  ['.*%.git/modules/.*/config'] = 'gitconfig',
  ['.*%.git/config'] = 'gitconfig',
  ['.*/etc/gitconfig'] = 'gitconfig',
  ['.*/%.config/git/config'] = 'gitconfig',
  ['.*%.git/config%.worktree'] = 'gitconfig',
  ['.*%.git/worktrees/.*/config%.worktree'] = 'gitconfig',
  ['.*/git/config'] = function(path, bufnr)
    if vim.env.XDG_CONFIG_HOME and path:find(vim.env.XDG_CONFIG_HOME .. '/git/config') then
      return 'gitconfig'
    end
  end,
  ['%.gitsendemail%.msg%.......'] = 'gitsendemail',
  ['gkrellmrc_.'] = 'gkrellmrc',
  ['.*/usr/.*/gnupg/options%.skel'] = 'gpg',
  ['.*/%.gnupg/options'] = 'gpg',
  ['.*/%.gnupg/gpg%.conf'] = 'gpg',
  ['.*/options'] = function(path, bufnr)
    if vim.env.GNUPGHOME and path:find(vim.env.GNUPGHOME .. '/options') then
      return 'gpg'
    end
  end,
  ['.*/gpg%.conf'] = function(path, bufnr)
    if vim.env.GNUPGHOME and path:find(vim.env.GNUPGHOME .. '/gpg%.conf') then
      return 'gpg'
    end
  end,
  ['.*/etc/group'] = 'group',
  ['.*/etc/gshadow'] = 'group',
  ['.*/etc/group%.edit'] = 'group',
  ['.*/var/backups/gshadow%.bak'] = 'group',
  ['.*/etc/group-'] = 'group',
  ['.*/etc/gshadow-'] = 'group',
  ['.*/var/backups/group%.bak'] = 'group',
  ['.*/etc/gshadow%.edit'] = 'group',
  ['.*/boot/grub/grub%.conf'] = 'grub',
  ['.*/boot/grub/menu%.lst'] = 'grub',
  ['.*/etc/grub%.conf'] = 'grub',
  [vim.env.VIMRUNTIME .. '/doc/.*%.txt'] = 'help',
  ['hg%-editor%-.*%.txt'] = 'hgcommit',
  ['.*/etc/host%.conf'] = 'hostconf',
  ['.*/etc/hosts%.deny'] = 'hostsaccess',
  ['.*/etc/hosts%.allow'] = 'hostsaccess',
  ['.*%.html%.m4'] = 'htmlm4',
  ['.*/%.i3/config'] = 'i3config',
  ['.*/sway/config'] = 'i3config',
  ['.*/i3/config'] = 'i3config',
  ['.*/%.sway/config'] = 'i3config',
  ['.*/%.icewm/menu'] = 'icemenu',
  ['.*/etc/initng/.*/.*%.i'] = 'initng',
  ['.*%.properties_..'] = 'jproperties',
  ['.*%.properties_.._..'] = 'jproperties',
  ['.*lftp/rc'] = 'lftp',
  ['.*/%.libao'] = 'libao',
  ['.*/etc/libao%.conf'] = 'libao',
  ['.*/etc/.*limits%.conf'] = 'limits',
  ['.*/etc/limits'] = 'limits',
  ['.*/etc/.*limits%.d/.*%.conf'] = 'limits',
  ['.*/LiteStep/.*/.*%.rc'] = 'litestep',
  ['.*/etc/login%.access'] = 'loginaccess',
  ['.*/etc/login%.defs'] = 'logindefs',
  ['.*/etc/mail/aliases'] = 'mailaliases',
  ['.*/etc/aliases'] = 'mailaliases',
  ['.*[mM]akefile'] = 'make',
  ['.*/etc/man%.conf'] = 'manconf',
  ['.*/etc/modules%.conf'] = 'modconf',
  ['.*/etc/conf%.modules'] = 'modconf',
  ['.*/etc/modules'] = 'modconf',
  ['.*%.[mi][3g]'] = 'modula3',
  ['.*/%.mplayer/config'] = 'mplayerconf',
  ['rndc.*%.conf'] = 'named',
  ['rndc.*%.key'] = 'named',
  ['named.*%.conf'] = 'named',
  ['.*/etc/nanorc'] = 'nanorc',
  ['.*%.NS[ACGLMNPS]'] = 'natural',
  ['nginx.*%.conf'] = 'nginx',
  ['.*/etc/nginx/.*'] = 'nginx',
  ['.*nginx%.conf'] = 'nginx',
  ['.*/nginx/.*%.conf'] = 'nginx',
  ['.*/usr/local/nginx/conf/.*'] = 'nginx',
  ['.*%.ml%.cppo'] = 'ocaml',
  ['.*%.mli%.cppo'] = 'ocaml',
  ['.*%.opam%.template'] = 'opam',
  ['.*%.[Oo][Pp][Ll]'] = 'opl',
  ['.*/etc/pam%.conf'] = 'pamconf',
  ['.*/etc/passwd-'] = 'passwd',
  ['.*/etc/shadow'] = 'passwd',
  ['.*/etc/shadow%.edit'] = 'passwd',
  ['.*/var/backups/shadow%.bak'] = 'passwd',
  ['.*/var/backups/passwd%.bak'] = 'passwd',
  ['.*/etc/passwd'] = 'passwd',
  ['.*/etc/passwd%.edit'] = 'passwd',
  ['.*/etc/shadow-'] = 'passwd',
  ['.*%.php%d'] = 'php',
  ['.*/%.pinforc'] = 'pinfo',
  ['.*/etc/pinforc'] = 'pinfo',
  ['.*/etc/protocols'] = 'protocols',
  ['.*printcap.*'] = starsetf(function(path, bufnr)
    if vim.fn.did_filetype() == 0 then
      return 'ptcap', function(b)
        vim.b[b].ptcap_type = 'print'
      end
    end
  end),
  ['.*baseq[2-3]/.*%.cfg'] = 'quake',
  ['.*quake[1-3]/.*%.cfg'] = 'quake',
  ['.*id1/.*%.cfg'] = 'quake',
  ['[rR]antfile'] = 'ruby',
  ['[rR]akefile'] = 'ruby',
  ['.*/etc/sensors%.conf'] = 'sensors',
  ['.*/etc/sensors3%.conf'] = 'sensors',
  ['.*/etc/services'] = 'services',
  ['.*/etc/serial%.conf'] = 'setserial',
  ['.*/etc/udev/cdsymlinks%.conf'] = 'sh',
  ['.*%._sst%.meta'] = 'sisu',
  ['.*%.%-sst%.meta'] = 'sisu',
  ['.*%.sst%.meta'] = 'sisu',
  ['.*/etc/slp%.conf'] = 'slpconf',
  ['.*/etc/slp%.reg'] = 'slpreg',
  ['.*/etc/slp%.spi'] = 'slpspi',
  ['.*/etc/ssh/ssh_config%.d/.*%.conf'] = 'sshconfig',
  ['.*/%.ssh/config'] = 'sshconfig',
  ['.*/etc/ssh/sshd_config%.d/.*%.conf'] = 'sshdconfig',
  ['.*/etc/sudoers'] = 'sudoers',
  ['svn%-commit.*%.tmp'] = 'svn',
  ['.*%.swift%.gyb'] = 'swiftgyb',
  ['.*/etc/sysctl%.conf'] = 'sysctl',
  ['.*/etc/sysctl%.d/.*%.conf'] = 'sysctl',
  ['.*/systemd/.*%.automount'] = 'systemd',
  ['.*/systemd/.*%.dnssd'] = 'systemd',
  ['.*/systemd/.*%.link'] = 'systemd',
  ['.*/systemd/.*%.mount'] = 'systemd',
  ['.*/systemd/.*%.netdev'] = 'systemd',
  ['.*/systemd/.*%.network'] = 'systemd',
  ['.*/systemd/.*%.nspawn'] = 'systemd',
  ['.*/systemd/.*%.path'] = 'systemd',
  ['.*/systemd/.*%.service'] = 'systemd',
  ['.*/systemd/.*%.slice'] = 'systemd',
  ['.*/systemd/.*%.socket'] = 'systemd',
  ['.*/systemd/.*%.swap'] = 'systemd',
  ['.*/systemd/.*%.target'] = 'systemd',
  ['.*/systemd/.*%.timer'] = 'systemd',
  ['.*/etc/systemd/.*%.conf%.d/.*%.conf'] = 'systemd',
  ['.*/%.config/systemd/user/.*%.d/.*%.conf'] = 'systemd',
  ['.*/etc/systemd/system/.*%.d/.*%.conf'] = 'systemd',
  ['.*/etc/systemd/system/.*%.d/%.#.*'] = 'systemd',
  ['.*/etc/systemd/system/%.#.*'] = 'systemd',
  ['.*/%.config/systemd/user/.*%.d/%.#.*'] = 'systemd',
  ['.*/%.config/systemd/user/%.#.*'] = 'systemd',
  ['.*termcap.*'] = starsetf(function(path, bufnr)
    if vim.fn.did_filetype() == 0 then
      return 'ptcap', function(b)
        vim.b[b].ptcap_type = 'term'
      end
    end
  end),
  ['.*%.t%.html'] = 'tilde',
  ['%.?tmux.*%.conf'] = 'tmux',
  ['%.?tmux.*%.conf.*'] = { 'tmux', { priority = -1 } },
  ['.*/%.cargo/config'] = 'toml',
  ['.*/%.cargo/credentials'] = 'toml',
  ['.*/etc/udev/udev%.conf'] = 'udevconf',
  ['.*/etc/udev/permissions%.d/.*%.permissions'] = 'udevperm',
  ['.*/etc/updatedb%.conf'] = 'updatedb',
  ['.*/%.init/.*%.override'] = 'upstart',
  ['.*/usr/share/upstart/.*%.conf'] = 'upstart',
  ['.*/%.config/upstart/.*%.override'] = 'upstart',
  ['.*/etc/init/.*%.conf'] = 'upstart',
  ['.*/etc/init/.*%.override'] = 'upstart',
  ['.*/%.config/upstart/.*%.conf'] = 'upstart',
  ['.*/%.init/.*%.conf'] = 'upstart',
  ['.*/usr/share/upstart/.*%.override'] = 'upstart',
  ['.*%.ws[fc]'] = 'wsh',
  ['.*/etc/xinetd%.conf'] = 'xinetd',
  ['.*/etc/blkid%.tab'] = 'xml',
  ['.*/etc/blkid%.tab%.old'] = 'xml',
  ['.*%.vbproj%.user'] = 'xml',
  ['.*%.fsproj%.user'] = 'xml',
  ['.*%.csproj%.user'] = 'xml',
  ['.*/etc/xdg/menus/.*%.menu'] = 'xml',
  ['.*Xmodmap'] = 'xmodmap',
  ['.*/etc/zprofile'] = 'zsh',
  ['%.bash[_-]aliases'] = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, 'bash')
  end,
  ['%.bash[_-]logout'] = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, 'bash')
  end,
  ['%.bash[_-]profile'] = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, 'bash')
  end,
  ['%.cshrc.*'] = function(path, bufnr)
    return require('vim.filetype.detect').csh(path, bufnr)
  end,
  ['%.gtkrc.*'] = starsetf('gtkrc'),
  ['%.kshrc.*'] = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, 'ksh')
  end,
  ['%.login.*'] = function(path, bufnr)
    return require('vim.filetype.detect').csh(path, bufnr)
  end,
  ['Muttrc.*'] = starsetf('muttrc'),
  ['Muttngrc.*'] = starsetf('muttrc'),
  -- muttrc* and .muttrc*
  ['%.?muttrc.*'] = starsetf('muttrc'),
  -- muttngrc* and .muttngrc*
  ['%.?muttngrc.*'] = starsetf('muttrc'),
  ['.*/%.mutt/muttrc.*'] = starsetf('muttrc'),
  ['.*/%.muttng/muttrc.*'] = starsetf('muttrc'),
  ['.*/%.muttng/muttngrc.*'] = starsetf('muttrc'),
  ['Neomuttrc.*'] = starsetf('neomuttrc'),
  -- neomuttrc* and .neomuttrc*
  ['%.?neomuttrc.*'] = starsetf('neomuttrc'),
  ['.*/%.neomutt/neomuttrc.*'] = starsetf('neomuttrc'),
  ['%.profile.*'] = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, getline(bufnr, 1))
  end,
  ['%.reminders.*'] = starsetf('remind'),
  ['%.tcshrc.*'] = function(path, bufnr)
    return require('vim.filetype.detect').shell(path, bufnr, 'tcsh')
  end,
  ['%.zcompdump.*'] = starsetf('zsh'),
  ['%.zlog.*'] = starsetf('zsh'),
  ['%.zsh.*'] = starsetf('zsh'),
  ['.*%.[1-9]'] = function(path, bufnr)
    return require('vim.filetype.detect').nroff(bufnr)
  end,
  ['.*%.[aA]'] = function(path, bufnr)
    return require('vim.filetype.detect').asm(bufnr)
  end,
  ['.*%.[sS]'] = function(path, bufnr)
    return require('vim.filetype.detect').asm(bufnr)
  end,
  ['.*%.properties_.._.._.*'] = starsetf('jproperties'),
  ['.*%.vhdl_[0-9].*'] = starsetf('vhdl'),
  ['.*/%.fvwm/.*'] = starsetf('fvwm'),
  ['.*fvwmrc.*'] = starsetf(function(path, bufnr)
    return 'fvwm', function(b)
      vim.b[b].fvwm_version = 1
    end
  end),
  ['.*fvwm95.*%.hook'] = starsetf(function(path, bufnr)
    return 'fvwm', function(b)
      vim.b[b].fvwm_version = 1
    end
  end),
  ['.*/%.gitconfig%.d/.*'] = starsetf('gitconfig'),
  ['.*/Xresources/.*'] = starsetf('xdefaults'),
  ['.*/app%-defaults/.*'] = starsetf('xdefaults'),
  ['.*/bind/db%..*'] = starsetf('bindzone'),
  ['.*/debian/patches/.*'] = function(path, bufnr)
    return require('vim.filetype.detect').dep3patch(path, bufnr)
  end,
  ['.*/etc/Muttrc%.d/.*'] = starsetf('muttrc'),
  ['.*/etc/apache2/.*%.conf.*'] = starsetf('apache'),
  ['.*/etc/apache2/conf%..*/.*'] = starsetf('apache'),
  ['.*/etc/apache2/mods%-.*/.*'] = starsetf('apache'),
  ['.*/etc/apache2/sites%-.*/.*'] = starsetf('apache'),
  ['.*/etc/cron%.d/.*'] = starsetf('crontab'),
  ['.*/etc/dnsmasq%.d/.*'] = starsetf('dnsmasq'),
  ['.*/etc/httpd/conf%..*/.*'] = starsetf('apache'),
  ['.*/etc/httpd/conf%.d/.*%.conf.*'] = starsetf('apache'),
  ['.*/etc/httpd/mods%-.*/.*'] = starsetf('apache'),
  ['.*/etc/httpd/sites%-.*/.*'] = starsetf('apache'),
  ['.*/etc/logcheck/.*%.d.*/.*'] = starsetf('logcheck'),
  ['.*/etc/modprobe%..*'] = starsetf('modconf'),
  ['.*/etc/modutils/.*'] = starsetf(function(path, bufnr)
    if vim.fn.executable(vim.fn.expand(path)) ~= 1 then
      return 'modconf'
    end
  end),
  ['.*/etc/pam%.d/.*'] = starsetf('pamconf'),
  ['.*/etc/profile'] = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, getline(bufnr, 1))
  end,
  ['.*/etc/proftpd/.*%.conf.*'] = starsetf('apachestyle'),
  ['.*/etc/proftpd/conf%..*/.*'] = starsetf('apachestyle'),
  ['.*/etc/sudoers%.d/.*'] = starsetf('sudoers'),
  ['.*/etc/xinetd%.d/.*'] = starsetf('xinetd'),
  ['.*/etc/yum%.repos%.d/.*'] = starsetf('dosini'),
  ['.*/gitolite%-admin/conf/.*'] = starsetf('gitolite'),
  ['.*/named/db%..*'] = starsetf('bindzone'),
  ['.*/tmp/lltmp.*'] = starsetf('gedcom'),
  ['.*asterisk.*/.*voicemail%.conf.*'] = starsetf('asteriskvm'),
  ['.*asterisk/.*%.conf.*'] = starsetf('asterisk'),
  ['.*vimrc.*'] = starsetf('vim'),
  ['.*xmodmap.*'] = starsetf('xmodmap'),
  ['/etc/gitconfig%.d/.*'] = starsetf('gitconfig'),
  ['/etc/hostname%..*'] = starsetf('config'),
  ['Containerfile%..*'] = starsetf('dockerfile'),
  ['Dockerfile%..*'] = starsetf('dockerfile'),
  ['JAM.*%..*'] = starsetf('jam'),
  ['Kconfig%..*'] = starsetf('kconfig'),
  ['Prl.*%..*'] = starsetf('jam'),
  ['Xresources.*'] = starsetf('xdefaults'),
  ['[mM]akefile.*'] = starsetf('make'),
  ['[rR]akefile.*'] = starsetf('ruby'),
  ['access%.conf.*'] = starsetf('apache'),
  ['apache%.conf.*'] = starsetf('apache'),
  ['apache2%.conf.*'] = starsetf('apache'),
  ['bash%-fc[-%.]'] = function(path, bufnr)
    return require('vim.filetype.detect').sh(path, bufnr, 'bash')
  end,
  ['cabal%.project%..*'] = starsetf('cabalproject'),
  ['crontab%..*'] = starsetf('crontab'),
  ['drac%..*'] = starsetf('dracula'),
  ['gtkrc.*'] = starsetf('gtkrc'),
  ['httpd%.conf.*'] = starsetf('apache'),
  ['lilo%.conf.*'] = starsetf('lilo'),
  ['Muttrc'] = 'muttrc',
  ['Muttngrc'] = 'muttrc',
  ['proftpd%.conf.*'] = starsetf('apachestyle'),
  ['reportbug%-.*'] = starsetf('mail'),
  ['sgml%.catalog.*'] = starsetf('catalog'),
  ['srm%.conf.*'] = starsetf('apache'),
  ['tmac%..*'] = starsetf('nroff'),
  ['zlog.*'] = starsetf('zsh'),
  ['zsh.*'] = starsetf('zsh'),
  ['ae%d+%.txt'] = 'mail',
  ['snd%.%d+'] = 'mail',
  ['%.letter%.%d+'] = 'mail',
  ['%.article%.%d+'] = 'mail',
  ['pico%.%d+'] = 'mail',
  ['mutt%-.*%-%w+'] = 'mail',
  ['muttng%-.*%-%w+'] = 'mail',
  ['neomutt%-.*%-%w+'] = 'mail',
  ['mutt' .. string.rep('[%w_-]', 6)] = 'mail',
  ['neomutt' .. string.rep('[%w_-]', 6)] = 'mail',
  ['/tmp/SLRN[0-9A-Z.]+'] = 'mail',
  ['[a-zA-Z0-9].*Dict'] = function(path, bufnr)
    return require('vim.filetype.detect').foam(bufnr)
  end,
  ['[a-zA-Z0-9].*Dict%..*'] = function(path, bufnr)
    return require('vim.filetype.detect').foam(bufnr)
  end,
  ['[a-zA-Z].*Properties'] = function(path, bufnr)
    return require('vim.filetype.detect').foam(bufnr)
  end,
  ['[a-zA-Z].*Properties%..*'] = function(path, bufnr)
    return require('vim.filetype.detect').foam(bufnr)
  end,
  ['.*Transport%..*'] = function(path, bufnr)
    return require('vim.filetype.detect').foam(bufnr)
  end,
  ['.*/constant/g'] = function(path, bufnr)
    return require('vim.filetype.detect').foam(bufnr)
  end,
  ['.*/0/.*'] = function(path, bufnr)
    return require('vim.filetype.detect').foam(bufnr)
  end,
  ['.*/0%.orig/.*'] = function(path, bufnr)
    return require('vim.filetype.detect').foam(bufnr)
  end,
  ['.*/etc/sensors%.d/[^.].*'] = starsetf('sensors'),
  ['.*%.git/.*'] = function(path, bufnr)
    local firstline = getline(bufnr, 1)
    if firstline:find('^' .. string.rep('%x', 40) .. '+ ') or firstline:sub(1, 5) == 'ref: ' then
      return 'git'
    end
  end,
  ['.*%.[Cc][Ff][Gg]'] = {
    function(path, bufnr)
      return require('vim.filetype.detect').cfg(bufnr)
    end,
    -- Decrease the priority to avoid conflicts with more specific patterns
    -- such as '.*/etc/a2ps/.*%.cfg', '.*enlightenment/.*%.cfg', etc.
    { priority = -1 },
  },
  ['.*%.[Dd][Aa][Tt]'] = function(path, bufnr)
    return require('vim.filetype.detect').dat(path, bufnr)
  end,
  ['.*%.[Mm][Oo][Dd]'] = function(path, bufnr)
    return require('vim.filetype.detect').mod(path, bufnr)
  end,
  ['.*%.[Ss][Rr][Cc]'] = function(path, bufnr)
    return require('vim.filetype.detect').src(bufnr)
  end,
  ['.*%.[Ss][Uu][Bb]'] = 'krl',
  ['.*%.[Pp][Rr][Gg]'] = function(path, bufnr)
    return require('vim.filetype.detect').prg(bufnr)
  end,
  ['.*%.[Ss][Yy][Ss]'] = function(path, bufnr)
    return require('vim.filetype.detect').sys(bufnr)
  end,
  ['%.?gitolite%.rc'] = 'perl',
  ['example%.gitolite%.rc'] = 'perl',
  -- Neovim only
  ['.*/queries/.*%.scm'] = 'query', -- tree-sitter queries
  ['.*,v'] = 'rcs',
  ['.*/xorg%.conf%.d/.*%.conf'] = function(path, bufnr)
    return 'xf86config', function(b)
      vim.b[b].xf86conf_xfree86_version = 4
    end
  end,
  -- Increase priority to run before the pattern below
  ['XF86Config%-4.*'] = starsetf(function(path, bufnr)
    return 'xf86conf', function(b)
      vim.b[b].xf86conf_xfree86_version = 4
    end
  end, { priority = -math.huge + 1 }),
  ['XF86Config.*'] = starsetf(function(path, bufnr)
    return require('vim.filetype.detect').xfree86(bufnr)
  end),
  ['[cC]hange[lL]og.*'] = starsetf(function(path, bufnr)
    local line = getline(bufnr, 1):lower()
    if line:find('; urgency=') then
      return 'debchangelog'
    else
      return 'changelog'
    end
  end),
  ['.*fvwm2rc.*'] = starsetf(function(path, bufnr)
    if vim.fn.fnamemodify(path, ':e') == 'm4' then
      return 'fvwm2m4'
    else
      return 'fvwm', function(b)
        vim.b[b].fvwm_version = 2
      end
    end
  end),
  ['.*%.[Ll][Oo][Gg]'] = function(path, bufnr)
    -- Innovation Data Processing
    -- (refactor of filetype.vim since the patterns are case-insensitive)
    path = path:lower()
    if M.findany(path, { 'upstream%.log', 'upstream%..*%.log', '.*%.upstream%.log', 'upstream%-.*%.log' }) then
      return 'upstreamlog'
    elseif M.findany(path, { 'upstreaminstall%.log', 'upstreaminstall%..*%.log', '.*%.upstreaminstall%.log' }) then
      return 'upstreaminstalllog'
    elseif M.findany(path, { 'usserver%.log', 'usserver%..*%.log', '.*%.usserver%.log' }) then
      return 'usserverlog'
    elseif M.findany(path, { 'usw2kagt%.log', 'usws2kagt%..*%.log', '.*%.usws2kagt%.log' }) then
      return 'usw2kagtlog'
    end
  end,
  -- Ignored extension
  ['.*~'] = function(path, bufnr)
    local short = path:gsub('~$', '', 1)
    if path ~= short and short ~= '' then
      return M.match(vim.fn.fnameescape(short), bufnr)
    end
  end,
  -- END PATTERN
}
-- luacheck: pop
-- luacheck: pop

---@private
local function sort_by_priority(t)
  local sorted = {}
  for k, v in pairs(t) do
    local ft = type(v) == 'table' and v[1] or v
    assert(type(ft) == 'string' or type(ft) == 'function', 'Expected string or function for filetype')

    local opts = (type(v) == 'table' and type(v[2]) == 'table') and v[2] or {}
    if not opts.priority then
      opts.priority = 0
    end
    table.insert(sorted, { [k] = { ft, opts } })
  end
  table.sort(sorted, function(a, b)
    return a[next(a)][2].priority > b[next(b)][2].priority
  end)
  return sorted
end

local pattern_sorted = sort_by_priority(pattern)

---@private
local function normalize_path(path, as_pattern)
  local normal = path:gsub('\\', '/')
  if normal:find('^~') then
    if as_pattern then
      -- Escape Lua's metacharacters when $HOME is used in a pattern.
      -- The rest of path should already be properly escaped.
      normal = vim.pesc(vim.env.HOME) .. normal:sub(2)
    else
      normal = vim.env.HOME .. normal:sub(2)
    end
  end
  return normal
end

--- Add new filetype mappings.
---
--- Filetype mappings can be added either by extension or by filename (either
--- the "tail" or the full file path). The full file path is checked first,
--- followed by the file name. If a match is not found using the filename, then
--- the filename is matched against the list of |lua-patterns| (sorted by priority)
--- until a match is found. Lastly, if pattern matching does not find a
--- filetype, then the file extension is used.
---
--- The filetype can be either a string (in which case it is used as the
--- filetype directly) or a function. If a function, it takes the full path and
--- buffer number of the file as arguments (along with captures from the matched
--- pattern, if any) and should return a string that will be used as the
--- buffer's filetype. Optionally, the function can return a second function
--- value which, when called, modifies the state of the buffer. This can be used
--- to, for example, set filetype-specific buffer variables.
---
--- Filename patterns can specify an optional priority to resolve cases when a
--- file path matches multiple patterns. Higher priorities are matched first.
--- When omitted, the priority defaults to 0.
---
--- See $VIMRUNTIME/lua/vim/filetype.lua for more examples.
---
--- Note that Lua filetype detection is only enabled when |g:do_filetype_lua| is
--- set to 1.
---
--- Example:
--- <pre>
---  vim.filetype.add({
---    extension = {
---      foo = "fooscript",
---      bar = function(path, bufnr)
---        if some_condition() then
---          return "barscript", function(bufnr)
---            -- Set a buffer variable
---            vim.b[bufnr].barscript_version = 2
---          end
---        end
---        return "bar"
---      end,
---    },
---    filename = {
---      [".foorc"] = "toml",
---      ["/etc/foo/config"] = "toml",
---    },
---    pattern = {
---      [".*/etc/foo/.*"] = "fooscript",
---      -- Using an optional priority
---      [".*/etc/foo/.*%.conf"] = { "dosini", { priority = 10 } },
---      ["README.(%a+)$"] = function(path, bufnr, ext)
---        if ext == "md" then
---          return "markdown"
---        elseif ext == "rst" then
---          return "rst"
---        end
---      end,
---    },
---  })
--- </pre>
---
---@param filetypes table A table containing new filetype maps (see example).
function M.add(filetypes)
  for k, v in pairs(filetypes.extension or {}) do
    extension[k] = v
  end

  for k, v in pairs(filetypes.filename or {}) do
    filename[normalize_path(k)] = v
  end

  for k, v in pairs(filetypes.pattern or {}) do
    pattern[normalize_path(k, true)] = v
  end

  if filetypes.pattern then
    pattern_sorted = sort_by_priority(pattern)
  end
end

---@private
local function dispatch(ft, path, bufnr, ...)
  local on_detect
  if type(ft) == 'function' then
    ft, on_detect = ft(path, bufnr, ...)
  end

  if type(ft) == 'string' then
    return ft, on_detect
  end

  -- Any non-falsey value (that is, anything other than 'nil' or 'false') will
  -- end filetype matching. This is useful for e.g. the dist#ft functions that
  -- return 0, but set the buffer's filetype themselves
  return ft
end

---@private
local function match_pattern(name, path, tail, pat)
  -- If the pattern contains a / match against the full path, otherwise just the tail
  local fullpat = '^' .. pat .. '$'
  local matches
  if pat:find('/') then
    -- Similar to |autocmd-pattern|, if the pattern contains a '/' then check for a match against
    -- both the short file name (as typed) and the full file name (after expanding to full path
    -- and resolving symlinks)
    matches = name:match(fullpat) or path:match(fullpat)
  else
    matches = tail:match(fullpat)
  end
  return matches
end

--- Find the filetype for the given filename and buffer.
---
---@param name string File name (can be an absolute or relative path)
---@param bufnr number|nil The buffer to set the filetype for. Defaults to the current buffer.
---@return string|nil If a match was found, the matched filetype.
---@return function|nil A function that modifies buffer state when called (for example, to set some
---                     filetype specific buffer variables). The function accepts a buffer number as
---                     its only argument.
function M.match(name, bufnr)
  vim.validate({
    name = { name, 's' },
    bufnr = { bufnr, 'n', true },
  })

  -- When fired from the main filetypedetect autocommand the {bufnr} argument is omitted, so we use
  -- the current buffer. The {bufnr} argument is provided to allow extensibility in case callers
  -- wish to perform filetype detection on buffers other than the current one.
  bufnr = bufnr or api.nvim_get_current_buf()

  name = normalize_path(name)

  local ft, on_detect

  -- First check for the simple case where the full path exists as a key
  local path = vim.fn.resolve(vim.fn.fnamemodify(name, ':p'))
  ft, on_detect = dispatch(filename[path], path, bufnr)
  if ft then
    return ft, on_detect
  end

  -- Next check against just the file name
  local tail = vim.fn.fnamemodify(name, ':t')
  ft, on_detect = dispatch(filename[tail], path, bufnr)
  if ft then
    return ft, on_detect
  end

  -- Next, check the file path against available patterns with non-negative priority
  local j = 1
  for i, v in ipairs(pattern_sorted) do
    local k = next(v)
    local opts = v[k][2]
    if opts.priority < 0 then
      j = i
      break
    end

    local filetype = v[k][1]
    local matches = match_pattern(name, path, tail, k)
    if matches then
      ft, on_detect = dispatch(filetype, path, bufnr, matches)
      if ft then
        return ft, on_detect
      end
    end
  end

  -- Next, check file extension
  local ext = vim.fn.fnamemodify(name, ':e')
  ft, on_detect = dispatch(extension[ext], path, bufnr)
  if ft then
    return ft, on_detect
  end

  -- Finally, check patterns with negative priority
  for i = j, #pattern_sorted do
    local v = pattern_sorted[i]
    local k = next(v)

    local filetype = v[k][1]
    local matches = match_pattern(name, path, tail, k)
    if matches then
      ft, on_detect = dispatch(filetype, path, bufnr, matches)
      if ft then
        return ft, on_detect
      end
    end
  end
end

return M
