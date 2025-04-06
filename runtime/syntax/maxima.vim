" Vim syntax file
" Language:	Maxima (symbolic algebra program)
" Maintainer:	Robert Dodier (robert.dodier@gmail.com)
" Last Change:	April 6, 2006
" Version:	1
" Adapted mostly from xmath.vim
" Number formats adapted from r.vim
"
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn sync lines=1000

" parenthesis sanity checker
syn region maximaZone	matchgroup=Delimiter start="(" matchgroup=Delimiter end=")" transparent contains=ALLBUT,maximaError,maximaBraceError,maximaCurlyError
syn region maximaZone	matchgroup=Delimiter start="{" matchgroup=Delimiter end="}" transparent contains=ALLBUT,maximaError,maximaBraceError,maximaParenError
syn region maximaZone	matchgroup=Delimiter start="\[" matchgroup=Delimiter end="]" transparent contains=ALLBUT,maximaError,maximaCurlyError,maximaParenError
syn match  maximaError	"[)\]}]"
syn match  maximaBraceError	"[)}]"	contained
syn match  maximaCurlyError	"[)\]]"	contained
syn match  maximaParenError	"[\]}]"	contained
syn match  maximaComma	"[\[\](),;]"
syn match  maximaComma	"\.\.\.$"

" A bunch of useful maxima keywords
syn keyword maximaConditional	if then else elseif and or not
syn keyword maximaRepeat	do for thru

" ---------------------- BEGIN LIST OF ALL FUNCTIONS (EXCEPT KEYWORDS)  ----------------------
syn keyword maximaFunc abasep  abs  absboxchar  absint  acos  acosh  acot  acoth  acsc  
syn keyword maximaFunc acsch  activate  activecontexts  addcol  additive  addrow  adim  
syn keyword maximaFunc adjoint  af  aform  airy  algebraic  algepsilon  algexact  algsys  
syn keyword maximaFunc alg_type  alias  aliases  allbut  all_dotsimp_denoms  allroots  allsym  
syn keyword maximaFunc alphabetic  antid  antidiff  antisymmetric  append  appendfile  
syn keyword maximaFunc apply  apply1  apply2  applyb1  apropos  args  array  arrayapply  
syn keyword maximaFunc arrayinfo  arraymake  arrays  asec  asech  asin  asinh  askexp  
syn keyword maximaFunc askinteger  asksign  assoc  assoc_legendre_p  assoc_legendre_q  assume  
syn keyword maximaFunc assume_pos  assume_pos_pred  assumescalar  asymbol  asympa  at  atan  
syn keyword maximaFunc atan2  atanh  atensimp  atom  atomgrad  atrig1  atvalue  augcoefmatrix  
syn keyword maximaFunc av  backsubst  backtrace  bashindices  batch  batchload  bc2  bdvac  
syn keyword maximaFunc berlefact  bern  bernpoly  bessel  besselexpand  bessel_i  bessel_j  
syn keyword maximaFunc bessel_k  bessel_y  beta  bezout  bffac  bfhzeta  bfloat  bfloatp  
syn keyword maximaFunc bfpsi  bfpsi0  bftorat  bftrunc  bfzeta  bimetric  binomial  block  
syn keyword maximaFunc bothcoef  box  boxchar  break  breakup  bug_report  build_info  buildq  
syn keyword maximaFunc burn  cabs  canform  canten  carg  cartan  catch  cauchysum  cbffac  
syn keyword maximaFunc cdisplay  cf  cfdisrep  cfexpand  cflength  cframe_flag  cgeodesic  
syn keyword maximaFunc changename  changevar  charpoly  checkdiv  check_overlaps  christof  
syn keyword maximaFunc clear_rules  closefile  closeps  cmetric  cnonmet_flag  coeff  
syn keyword maximaFunc coefmatrix  cograd  col  collapse  columnvector  combine  commutative  
syn keyword maximaFunc comp2pui  compfile  compile  compile_file  components  concan  concat  
syn keyword maximaFunc conj  conjugate  conmetderiv  cons  constant  constantp  cont2part  
syn keyword maximaFunc content  context  contexts  contortion  contract  contragrad  coord  
syn keyword maximaFunc copylist  copymatrix  cos  cosh  cosnpiflag  cot  coth  covdiff  
syn keyword maximaFunc covect  create_list  csc  csch  csetup  ctaylor  ctaypov  ctaypt  
syn keyword maximaFunc ctayswitch  ctayvar  ct_coords  ct_coordsys  ctorsion_flag  ctransform  
syn keyword maximaFunc ctrgsimp  current_let_rule_package  dblint  deactivate  debugmode  
syn keyword maximaFunc declare  declare_translated  declare_weight  decsym  
syn keyword maximaFunc default_let_rule_package  defcon  define  define_variable  defint  
syn keyword maximaFunc defmatch  defrule  deftaylor  del  delete  deleten  delta  demo  
syn keyword maximaFunc demoivre  denom  dependencies  depends  derivabbrev  derivdegree  
syn keyword maximaFunc derivlist  derivsubst  describe  desolve  determinant  detout  
syn keyword maximaFunc diagmatrix  diagmatrixp  diagmetric  diff  dim  dimension  direct  
syn keyword maximaFunc disolate  disp  dispcon  dispflag  dispform  dispfun  display  
syn keyword maximaFunc display2d  display_format_internal  disprule  dispterms  distrib  
syn keyword maximaFunc divide  divsum  doallmxops  domain  domxexpt  domxmxops  domxnctimes  
syn keyword maximaFunc dontfactor  doscmxops  doscmxplus  dot0nscsimp  dot0simp  dot1simp  
syn keyword maximaFunc dotassoc  dotconstrules  dotdistrib  dotexptsimp  dotident  dotscrules  
syn keyword maximaFunc dotsimp  dpart  dscalar  %e  echelon  %edispflag  eigenvalues  
syn keyword maximaFunc eigenvectors  eighth  einstein  eivals  eivects  ele2comp  
syn keyword maximaFunc ele2polynome  ele2pui  elem  eliminate  elliptic_e  elliptic_ec  
syn keyword maximaFunc elliptic_eu  elliptic_f  elliptic_kc  elliptic_pi  ematrix  %emode  
syn keyword maximaFunc endcons  entermatrix  entertensor  entier  %enumer  equal  equalp  erf  
syn keyword maximaFunc erfflag  errcatch  error  errormsg  error_size  error_syms  
syn keyword maximaFunc %e_to_numlog  euler  ev  eval  evenp  every  evflag  evfun  evundiff  
syn keyword maximaFunc example  exp  expand  expandwrt  expandwrt_denom  expandwrt_factored  
syn keyword maximaFunc explose  expon  exponentialize  expop  express  expt  exptdispflag  
syn keyword maximaFunc exptisolate  exptsubst  extdiff  extract_linear_equations  ezgcd  
syn keyword maximaFunc facexpand  factcomb  factlim  factor  factorflag  factorial  factorout  
syn keyword maximaFunc factorsum  facts  false  fast_central_elements  fast_linsolve  
syn keyword maximaFunc fasttimes  fb  feature  featurep  features  fft  fib  fibtophi  fifth  
syn keyword maximaFunc filename_merge  file_search  file_search_demo  file_search_lisp  
syn keyword maximaFunc file_search_maxima  file_type  fillarray  findde  first  fix  flatten  
syn keyword maximaFunc flipflag  float  float2bf  floatnump  flush  flush1deriv  flushd  
syn keyword maximaFunc flushnd  forget  fortindent  fortran  fortspaces  fourcos  fourexpand  
syn keyword maximaFunc fourier  fourint  fourintcos  fourintsin  foursimp  foursin  fourth  
syn keyword maximaFunc fpprec  fpprintprec  frame_bracket  freeof  fullmap  fullmapl  
syn keyword maximaFunc fullratsimp  fullratsubst  funcsolve  functions  fundef  funmake  funp  
syn keyword maximaFunc gamma  %gamma  gammalim  gauss  gcd  gcdex  gcfactor  gdet  genfact  
syn keyword maximaFunc genindex  genmatrix  gensumnum  get  getchar  gfactor  gfactorsum  
syn keyword maximaFunc globalsolve  go  gradef  gradefs  gramschmidt  grind  grobner_basis  
syn keyword maximaFunc gschmit  hach  halfangles  hermite  hipow  hodge  horner  i0  i1  
syn keyword maximaFunc *read-base*  ic1  ic2  icc1  icc2  ic_convert  ichr1  ichr2  icounter  
syn keyword maximaFunc icurvature  ident  idiff  idim  idummy  idummyx  ieqn  ieqnprint  ifb  
syn keyword maximaFunc ifc1  ifc2  ifg  ifgi  ifr  iframe_bracket_form  iframes  ifri  ift  
syn keyword maximaFunc igeodesic_coords  igeowedge_flag  ikt1  ikt2  ilt  imagpart  imetric  
syn keyword maximaFunc inchar  indexed_tensor  indices  inf  %inf  infeval  infinity  infix  
syn keyword maximaFunc inflag  infolists  init_atensor  init_ctensor  inm  inmc1  inmc2  
syn keyword maximaFunc innerproduct  in_netmath  inpart  inprod  inrt  integerp  integrate  
syn keyword maximaFunc integrate_use_rootsof  integration_constant_counter  interpolate  
syn keyword maximaFunc intfaclim  intopois  intosum  intpolabs  intpolerror  intpolrel  
syn keyword maximaFunc invariant1  invariant2  inverse_jacobi_cd  inverse_jacobi_cn  
syn keyword maximaFunc inverse_jacobi_cs  inverse_jacobi_dc  inverse_jacobi_dn  
syn keyword maximaFunc inverse_jacobi_ds  inverse_jacobi_nc  inverse_jacobi_nd  
syn keyword maximaFunc inverse_jacobi_ns  inverse_jacobi_sc  inverse_jacobi_sd  
syn keyword maximaFunc inverse_jacobi_sn  invert  is  ishow  isolate  isolate_wrt_times  
syn keyword maximaFunc isqrt  itr  j0  j1  jacobi  jacobi_cd  jacobi_cn  jacobi_cs  jacobi_dc  
syn keyword maximaFunc jacobi_dn  jacobi_ds  jacobi_nc  jacobi_nd  jacobi_ns  jacobi_sc  
syn keyword maximaFunc jacobi_sd  jacobi_sn  jn  kdels  kdelta  keepfloat  kill  killcontext  
syn keyword maximaFunc kinvariant  kostka  kt  labels  lambda  laplace  lassociative  last  
syn keyword maximaFunc lc2kdt  lc_l  lcm  lc_u  ldefint  ldisp  ldisplay  leinstein  length  
syn keyword maximaFunc let  letrat  let_rule_packages  letrules  letsimp  levi_civita  lfg  
syn keyword maximaFunc lfreeof  lg  lgtreillis  lhospitallim  lhs  liediff  limit  limsubst  
syn keyword maximaFunc linear  linechar  linel  linenum  linsolve  linsolve_params  
syn keyword maximaFunc linsolvewarn  listarith  listarray  listconstvars  listdummyvars  
syn keyword maximaFunc list_nc_monomials  listoftens  listofvars  listp  lmxchar  load  
syn keyword maximaFunc loadfile  loadprint  local  log  logabs  logarc  logconcoeffp  
syn keyword maximaFunc logcontract  logexpand  lognegint  lognumer  logsimp  lopow  
syn keyword maximaFunc lorentz_gauge  lpart  lratsubst  lriem  lriemann  lsum  ltreillis  
syn keyword maximaFunc m1pbranch  macroexpansion  mainvar  make_array  makebox  makefact  
syn keyword maximaFunc makegamma  makelist  make_random_state  make_transform  map  mapatom  
syn keyword maximaFunc maperror  maplist  matchdeclare  matchfix  matrix  matrix_element_add  
syn keyword maximaFunc matrix_element_mult  matrix_element_transpose  matrixmap  matrixp  
syn keyword maximaFunc mattrace  max  maxapplydepth  maxapplyheight  maxnegex  maxposex  
syn keyword maximaFunc maxtayorder  member  min  %minf  minfactorial  minor  mod  
syn keyword maximaFunc mode_check_errorp  mode_checkp  mode_check_warnp  mode_declare  
syn keyword maximaFunc mode_identity  modulus  mon2schur  mono  monomial_dimensions  
syn keyword maximaFunc multi_elem  multinomial  multi_orbit  multiplicative  multiplicities  
syn keyword maximaFunc multi_pui  multsym  multthru  myoptions  nc_degree  ncexpt  ncharpoly  
syn keyword maximaFunc negdistrib  negsumdispflag  newcontext  newdet  newton  niceindices  
syn keyword maximaFunc niceindicespref  ninth  nm  nmc  noeval  nolabels  nonmetricity  
syn keyword maximaFunc nonscalar  nonscalarp  noun  noundisp  nounify  nouns  np  npi  
syn keyword maximaFunc nptetrad  nroots  nterms  ntermst  nthroot  ntrig  num  numberp  numer  
syn keyword maximaFunc numerval  numfactor  nusum  obase  oddp  ode2  op  openplot_curves  
syn keyword maximaFunc operatorp  opproperties  opsubst  optimize  optimprefix  optionset
syn keyword maximaFunc orbit  ordergreat  ordergreatp  orderless  orderlessp  outative  
syn keyword maximaFunc outchar  outermap  outofpois  packagefile  pade  part  part2cont  
syn keyword maximaFunc partfrac  partition  partpol  partswitch  permanent  permut  petrov  
syn keyword maximaFunc pfeformat  pi  pickapart  piece  playback  plog  plot2d  plot2d_ps  
syn keyword maximaFunc plot3d  plot_options  poisdiff  poisexpt  poisint  poislim  poismap  
syn keyword maximaFunc poisplus  poissimp  poisson  poissubst  poistimes  poistrim  polarform  
syn keyword maximaFunc polartorect  polynome2ele  posfun  potential  powerdisp  powers  
syn keyword maximaFunc powerseries  pred  prederror  primep  print  printpois  printprops  
syn keyword maximaFunc prodhack  prodrac  product  programmode  prompt  properties  props  
syn keyword maximaFunc propvars  pscom  psdraw_curve  psexpand  psi  pui  pui2comp  pui2ele  
syn keyword maximaFunc pui2polynome  pui_direct  puireduc  put  qput  qq  quad_qag  quad_qagi  
syn keyword maximaFunc quad_qags  quad_qawc  quad_qawf  quad_qawo  quad_qaws  quanc8  quit  
syn keyword maximaFunc qunit  quotient  radcan  radexpand  radsubstflag  random  rank  
syn keyword maximaFunc rassociative  rat  ratalgdenom  ratchristof  ratcoef  ratdenom  
syn keyword maximaFunc ratdenomdivide  ratdiff  ratdisrep  rateinstein  ratepsilon  ratexpand  
syn keyword maximaFunc ratfac  ratmx  ratnumer  ratnump  ratp  ratprint  ratriemann  ratsimp  
syn keyword maximaFunc ratsimpexpons  ratsubst  ratvars  ratweight  ratweights  ratweyl  
syn keyword maximaFunc ratwtlvl  read  readonly  realonly  realpart  realroots  rearray  
syn keyword maximaFunc rectform  recttopolar  rediff  refcheck  rem  remainder  remarray  
syn keyword maximaFunc rembox  remcomps  remcon  remcoord  remfun  remfunction  remlet  
syn keyword maximaFunc remove  remrule  remsym  remvalue  rename  reset  residue  resolvante  
syn keyword maximaFunc resolvante_alternee1  resolvante_bipartite  resolvante_diedrale  
syn keyword maximaFunc resolvante_klein  resolvante_klein3  resolvante_produit_sym  
syn keyword maximaFunc resolvante_unitaire  resolvante_vierer  rest  resultant  return  
syn keyword maximaFunc reveal  reverse  revert  revert2  rhs  ric  ricci  riem  riemann  
syn keyword maximaFunc rinvariant  risch  rmxchar  rncombine  %rnum_list  romberg  rombergabs  
syn keyword maximaFunc rombergit  rombergmin  rombergtol  room  rootsconmode  rootscontract  
syn keyword maximaFunc rootsepsilon  round  row  run_testsuite  save  savedef  savefactors  
syn keyword maximaFunc scalarmatrixp  scalarp  scalefactors  scanmap  schur2comp  sconcat  
syn keyword maximaFunc scsimp  scurvature  sec  sech  second  setcheck  setcheckbreak  
syn keyword maximaFunc setelmx  set_plot_option  set_random_state  setup_autoload  
syn keyword maximaFunc set_up_dot_simplifications  setval  seventh  sf  show  showcomps  
syn keyword maximaFunc showratvars  showtime  sign  signum  similaritytransform  simpsum  
syn keyword maximaFunc simtran  sin  sinh  sinnpiflag  sixth  solve  solvedecomposes  
syn keyword maximaFunc solveexplicit  solvefactors  solve_inconsistent_error  solvenullwarn  
syn keyword maximaFunc solveradcan  solvetrigwarn  somrac  sort  sparse  spherical_bessel_j  
syn keyword maximaFunc spherical_bessel_y  spherical_hankel1  spherical_hankel2  
syn keyword maximaFunc spherical_harmonic  splice  sqfr  sqrt  sqrtdispflag  sstatus  
syn keyword maximaFunc stardisp  status  string  stringout  sublis  sublis_apply_lambda  
syn keyword maximaFunc sublist  submatrix  subst  substinpart  substpart  subvarp  sum  
syn keyword maximaFunc sumcontract  sumexpand  sumhack  sumsplitfact  supcontext  symbolp  
syn keyword maximaFunc symmetric  symmetricp  system  tan  tanh  taylor  taylordepth  
syn keyword maximaFunc taylorinfo  taylor_logexpand  taylor_order_coefficients  taylorp  
syn keyword maximaFunc taylor_simplifier  taylor_truncate_polynomials  taytorat  tcl_output  
syn keyword maximaFunc tcontract  tellrat  tellsimp  tellsimpafter  tensorkill  tentex  tenth  
syn keyword maximaFunc tex  %th  third  throw  time  timer  timer_devalue  timer_info  
syn keyword maximaFunc tldefint  tlimit  tlimswitch  todd_coxeter  to_lisp  totaldisrep  
syn keyword maximaFunc totalfourier  totient  tpartpol  tr  trace  trace_options  
syn keyword maximaFunc transcompile  translate  translate_file  transpose  transrun  
syn keyword maximaFunc tr_array_as_ref  tr_bound_function_applyp  treillis  treinat  
syn keyword maximaFunc tr_file_tty_messagesp  tr_float_can_branch_complex  
syn keyword maximaFunc tr_function_call_default  triangularize  trigexpand  trigexpandplus  
syn keyword maximaFunc trigexpandtimes  triginverses  trigrat  trigreduce  trigsign  trigsimp  
syn keyword maximaFunc tr_numer  tr_optimize_max_loop  tr_semicompile  tr_state_vars  true  
syn keyword maximaFunc trunc  truncate  tr_warn_bad_function_calls  tr_warn_fexpr  
syn keyword maximaFunc tr_warnings_get  tr_warn_meval  tr_warn_mode  tr_warn_undeclared  
syn keyword maximaFunc tr_warn_undefined_variable  tr_windy  ttyoff  ueivects  ufg  ug  
syn keyword maximaFunc ultraspherical  undiff  uniteigenvectors  unitvector  unknown  unorder  
syn keyword maximaFunc unsum  untellrat  untimer  untrace  uric  uricci  uriem  uriemann  
syn keyword maximaFunc use_fast_arrays  uvect  values  vect_cross  vectorpotential  
syn keyword maximaFunc vectorsimp  verb  verbify  verbose  weyl  with_stdout  writefile  
syn keyword maximaFunc xgraph_curves  xthru  zerobern  zeroequiv  zeromatrix  zeta  zeta%pi
syn match maximaOp "[\*\/\+\-\#\!\~\^\=\:\<\>\@]"
" ---------------------- END LIST OF ALL FUNCTIONS (EXCEPT KEYWORDS)  ----------------------


syn case match

" Labels (supports maxima's goto)
syn match   maximaLabel	 "^\s*<[a-zA-Z_][a-zA-Z0-9%_]*>"

" String and Character constants
" Highlight special characters (those which have a backslash) differently
syn match   maximaSpecial	contained "\\\d\d\d\|\\."
syn region  maximaString	start=+"+  skip=+\\\\\|\\"+  end=+"+ contains=maximaSpecial
syn match   maximaCharacter	"'[^\\]'"
syn match   maximaSpecialChar	"'\\.'"

" number with no fractional part or exponent
syn match maximaNumber /\<\d\+\>/
" floating point number with integer and fractional parts and optional exponent
syn match maximaFloat /\<\d\+\.\d*\([BbDdEeSs][-+]\=\d\+\)\=\>/
" floating point number with no integer part and optional exponent
syn match maximaFloat /\<\.\d\+\([BbDdEeSs][-+]\=\d\+\)\=\>/
" floating point number with no fractional part and optional exponent
syn match maximaFloat /\<\d\+[BbDdEeSs][-+]\=\d\+\>/

" Comments:
" maxima supports /* ... */ (like C)
syn keyword maximaTodo contained	TODO Todo DEBUG
syn region  maximaCommentBlock	start="/\*" end="\*/"	contains=maximaString,maximaTodo,maximaCommentBlock

" synchronizing
syn sync match maximaSyncComment	grouphere maximaCommentBlock "/*"
syn sync match maximaSyncComment	groupthere NONE "*/"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link maximaBraceError	maximaError
hi def link maximaCmd	maximaStatement
hi def link maximaCurlyError	maximaError
hi def link maximaFuncCmd	maximaStatement
hi def link maximaParenError	maximaError

" The default methods for highlighting.  Can be overridden later
hi def link maximaCharacter	Character
hi def link maximaComma	Function
hi def link maximaCommentBlock	Comment
hi def link maximaConditional	Conditional
hi def link maximaError	Error
hi def link maximaFunc	Delimiter
hi def link maximaOp                 Delimiter
hi def link maximaLabel	PreProc
hi def link maximaNumber	Number
hi def link maximaFloat	Float
hi def link maximaRepeat	Repeat
hi def link maximaSpecial	Type
hi def link maximaSpecialChar	SpecialChar
hi def link maximaStatement	Statement
hi def link maximaString	String
hi def link maximaTodo	Todo


let b:current_syntax = "maxima"
