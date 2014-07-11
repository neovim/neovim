" Vim syntax file
" Language:	AML (ARC/INFO Arc Macro Language)
" Written By:	Nikki Knuit <Nikki.Knuit@gems3.gov.bc.ca>
" Maintainer:	Todd Glover <todd.glover@gems9.gov.bc.ca>
" Last Change:	2001 May 10

" FUTURE CODING:  Bold application commands after &sys, &tty
"		  Only highlight aml Functions at the beginning
"		    of [], in order to avoid -read highlighted,
"		    or [quote] strings highlighted

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case ignore

" ARC, ARCEDIT, ARCPLOT, LIBRARIAN, GRID, SCHEMAEDIT reserved words,
" defined as keywords.

syn keyword amlArcCmd contained  2button abb abb[reviations] abs ac acos acosh add addc[ogoatt] addcogoatt addf[eatureclass] addh[istory] addi addim[age] addindexatt addit[em] additem addressb[uild] addressc[reate] addresse[rrors] addressedit addressm[atch] addressp[arse] addresst[est] addro[utemeasure] addroutemeasure addte[xt] addto[stack] addw[orktable] addx[y] adj[ust] adm[inlicense] adr[ggrid] ads adsa[rc] ae af ag[gregate] ai ai[request] airequest al alia[s] alig[n] alt[erarchive] am[sarc] and annoa[lignment] annoadd annocapture annocl[ip] annoco[verage] annocurve annoe[dit] annoedit annof annofeature annofit annoitem annola[yer] annole[vel] annolevel annoline annooffset annop[osition] annoplace annos[ize] annoselectfeatur annoset annosum annosymbol annot annot[ext] annotext annotype ao ap apm[ode] app[end] arc arcad[s] arcar[rows] arcc[ogo] arcdf[ad] arcdi[me] arcdl[g] arcdx[f] arced[it] arcedit arcen[dtext] arcf[ont] arcigd[s] arcige[s] arcla[bel] arcli[nes] arcma[rkers] arcmo[ss]
syn keyword amlArcCmd contained  arcpl[ot] arcplot arcpo[int] arcr[oute] arcs arcsc[itex] arcse[ction] arcsh[ape] arcsl[f] arcsn[ap] arcsp[ot] arcte[xt] arctig[er] arctin arcto[ols] arctools arcty[pe] area areaq[uery] arm arrow arrows[ize] arrowt[ype] as asc asciig[rid] asciih[elp] asciihelp asco[nnect] asconnect asd asda[tabase] asdi[sconnect] asdisconnect asel[ect] asex[ecute] asf asin asinh asp[ect] asr[eadlocks] ast[race] at atan atan2 atanh atusage aud[ittrail] autoi[ncrement] autol[ink] axis axish[atch] axisl[abels] axisr[uler] axist[ext] bac[klocksymbol] backcoverage backenvironment backnodeangleite backsymbolitem backtextitem base[select] basi[n] bat[ch] bc be be[lls] blackout blockmaj[ority] blockmax blockmea[n] blockmed[ian] blockmin blockmino[rity] blockr[ange] blockst[d] blocksu[m] blockv[ariety] bnai bou[ndaryclean] box br[ief] bsi bti buf[fer] bug[form] bugform build builds[ta] buildv[at] calco[mp] calcomp calcu[late] cali[brateroutes] calibrateroutes can[d] cartr[ead] cartread
syn keyword amlArcCmd contained  cartw[rite] cartwrite cei[l] cel[lvalue] cen[troidlabels] cgm cgme[scape] cha[nge] checkin checkinrel checkout checkoutrel chm[od] chown chownt[ransaction] chowntran chowntransaction ci ci[rcle] cir class classp[rob] classs[ig] classsample clean clear clears[elect] clip clipg[raphextent] clipm[apextent] clo[sedatabase] cntvrt co cod[efind] cog[oinverse] cogocom cogoenv cogomenu coll[ocate] color color2b[lue] color2g[reen] color2h[ue] color2r[ed] color2s[at] color2v[al] colorchart coloredit colorh[cbs] colorhcbs colu[mns] comb[ine] comm[ands] commands con connect connectu[ser] cons[ist] conto[ur] contr[olpoints] convertd[oc] convertdoc converti[mage] convertla[yer] convertli[brary] convertr[emap] convertw[orkspace] coo[rdinate] coordinate coordinates copy copyf[eatures] copyi[nfo] copyl[ayer] copyo copyo[ut] copyout copys[tack] copyw[orkspace] copyworkspace cor corr[idor] correlation cos cosh costa[llocation] costb[acklink] costd[istance] costp[ath] cou[ntvertices]
syn keyword amlArcCmd contained  countvertices cpw cr create create2[dindex] createa[ttributes] createca[talog] createco[go] createcogo createf[eature] createind[ex] createinf[otable] createlab[els] createlay[er] createli[brary] createn[etindex] creater[emap] creates[ystables] createta[blespace] createti[n] createw[orkspace] createworkspace cs culdesac curs[or] curv[ature] curve3pt cut[fill] cutoff cw cx[or] da dar[cyflow] dat[aset] dba[seinfo] dbmsc dbmsc[ursor] dbmscursor dbmse[xecute] dbmsi[nfo] dbmss[et] de delete deletea[rrows] deletet[ic] deletew[orkspace] deleteworkspace demg[rid] deml[attice] dend[rogram] densify densifya[rc] describe describea[rchive] describel[attice] describeti[n] describetr[ans] describetrans dev df[adarc] dg dif[f] digi[tizer] digt[est] dim[earc] dir dir[ectory] directory disa[blepanzoom] disconnect disconnectu[ser] disp disp[lay] display dissolve dissolvee[vents] dissolveevents dista[nce] distr[ibutebuild] div dl[garc] do doce[ll] docu[ment] document dogroup drag
syn keyword amlArcCmd contained  draw drawenvironment draworder draws[ig] drawselect drawt[raverses] drawz[oneshape] drop2[dindex] dropa[rchive] dropfeaturec[lass] dropfeatures dropfr[omstack] dropgroup droph[istory] dropind[ex] dropinf[otable] dropit[em] dropla[yer] droplib[rary] droplin[e] dropline dropn[etindex] dropt[ablespace] dropw[orktable] ds dt[edgrid] dtrans du[plicate] duplicatearcs dw dxf dxfa[rc] dxfi[nfo] dynamicpan dynpan ebe ec ed edg[esnap] edgematch editboundaryerro edit[coverage]  editdistance editf editfeature editp[lot] editplot edits[ig] editsymbol ef el[iminate] em[f] en[d] envrst envsav ep[s] eq equ[alto] er[ase] es et et[akarc] euca[llocation] eucdir[ection] eucdis[tance] eval eventa[rc] evente[nds] eventh[atch] eventi[nfo] eventlinee[ndtext] eventlines eventlinet[ext] eventlis[t] eventma[rkers] eventme[nu] eventmenu eventpoint eventpointt[ext] eventse[ction] eventso[urce] eventt[ransform] eventtransform exi[t] exp exp1[0] exp2 expa[nd] expo[rt] exten[d] external externala[ll]
syn keyword amlArcCmd contained  fd[convert] featuregroup fg fie[lddata] file fill filt[er] fix[ownership] flip flipa[ngle] float floatg[rid] floo[r] flowa[ccumulation] flowd[irection] flowl[ength] fm[od] focalf[low] focalmaj[ority] focalmax focalmea[n] focalmed[ian] focalmin focalmino[rity] focalr[ange] focalst[d] focalsu[m] focalv[ariety] fonta[rc] fontco[py] fontcr[eate] fontd[elete] fontdump fontl[oad] fontload forc[e] form[edit] formedit forms fr[equency] ge geary general[ize] generat[e] gerbera[rc] gerberr[ead] gerberread gerberw[rite] gerberwrite get getz[factor] gi gi[rasarc] gnds grai[n] graphb[ar] graphe[xtent] graphi[cs] graphicimage graphicview graphlim[its] graphlin[e] graphp[oint] graphs[hade] gray[shade] gre[aterthan] grid grida[scii] gridcl[ip] gridclip gridco[mposite] griddesk[ew] griddesp[eckle] griddi[rection] gride[dit] gridfli[p] gridflo[at] gridim[age] gridin[sert] gridl[ine] gridma[jority] gridmi[rror] gridmo[ss] gridn[et] gridnodatasymbol gridpa[int] gridpoi[nt] gridpol[y]
syn keyword amlArcCmd contained  gridq[uery] gridr[otate] gridshad[es] gridshap[e] gridshi[ft] gridw[arp] group groupb[y] gt gv gv[tolerance] ha[rdcopy] he[lp] help hid[densymbol] hig[hlow] hil[lshade] his[togram] historicalview ho[ldadjust] hpgl hpgl2 hsv2b[lue] hsv2g[reen] hsv2r[ed] ht[ml] hview ia ided[it] identif[y] identit[y] idw if igdsa[rc] igdsi[nfo] ige[sarc] il[lustrator] illustrator image imageg[rid] imagep[lot] imageplot imageview imp[ort] in index indexi[tem] info infodba[se] infodbm[s] infof[ile] init90[00] init9100 init9100b init91[00] init95[00] int intersect intersectarcs intersecte[rr] isn[ull] iso[cluster] it[ems] iview j[oinitem] join keeps keepselect keyan[gle] keyar[ea] keyb[ox] keyf[orms] keyl[ine] keym keym[arker] keymap keyp[osition] keyse[paration] keysh[ade] keyspot kill killm[ap] kr[iging] la labela[ngle] labele[rrors] labelm[arkers] labels labelsc[ale] labelsp[ot] labelt[ext] lal latticecl[ip] latticeco[ntour] latticed[em] latticem[erge] latticemarkers latticeo[perate]
syn keyword amlArcCmd contained  latticep[oly] latticerep[lace] latticeres[ample] lattices[pot] latticet[in] latticetext layer layera[nno] layerca[lculate] layerco[lumns] layerde[lete] layerdo[ts] layerdr[aw] layere[xport] layerf[ilter] layerid[entify] layerim[port] layerio[mode] layerli[st] layerloc[k] layerlog[file] layerq[uery] layerse[arch] layersp[ot] layert[ext] lc ldbmst le leadera[rrows] leaders leadersy[mbol] leadert[olerance] len[gth] les[sthan] lf lg lh li lib librari[an] library limitadjust limitautolink line line2pt linea[djustment] linecl[osureangle] linecolor linecolorr[amp] linecopy linecopyl[ayer] linedelete linedeletel[ayer] lineden[sity] linedir[ection] linedis[t] lineedit lineg[rid] lineh[ollow] lineinf[o] lineint[erval] linel[ayer] linelist linem[iterangle] lineo[ffset] linepa[ttern] linepe[n] linepu[t] linesa[ve] linesc[ale] linese[t] linesi[ze] linest[ats] linesy[mbol] linete[mplate]
syn keyword amlArcCmd contained  linety[pe] link[s] linkfeatures list listarchives listatt listc[overages] listcoverages listdbmstables listg[rids] listgrids listhistory listi[mages] listimages listinfotables listlayers listlibraries listo[utput] listse[lect] listst[acks] liststacks listtablespaces listti[ns] listtins listtr[averses] listtran listtransactions listw[orkspaces] listworkspaces lit ll ll[sfit] lla lm ln load loada[djacent] loadcolormap locko[nly] locks[ymbol] log log1[0] log2 logf[ile] logg[ing] loo[kup] lot[area] lp[os] lstk lt lts lw madditem majority majorityf[ilter] makere[gion] makero[ute] makese[ction] makest[ack] mal[ign] map mapa[ngle] mape[xtent] mapextent mapi[nfo] mapj[oin] mapl[imits] mappo[sition] mappr[ojection] mapsc[ale] mapsh[ift] mapu[nits] mapw[arp] mapz[oom] marker markera[ngle] markercolor markercolorr[amp] markercopy markercopyl[ayer] markerdelete markerdeletel[aye] markeredit markerf[ont] markeri[nfo] markerl[ayer] markerlist markerm[ask] markero[ffset]
syn keyword amlArcCmd contained  markerpa[ttern] markerpe[n] markerpu[t] markersa[ve] markersc[ale] markerse[t] markersi[ze] markersy[mbol] mas[elect] matchc[over] matchn[ode] max mb[egin] mc[opy] md[elete] me mean measure measurer[oute] measureroute med mend menu[cover] menuedit menv[ironment] merge mergeh[istory] mergev[at] mfi[t] mfr[esh] mg[roup] miadsa[rc] miadsr[ead] miadsread min minf[o] mino[rity] mir[ror] mitems mjoin ml[classify] mma[sk] mmo[ve] mn[select] mod mor[der] moran mosa[ic] mossa[rc] mossg[rid] move movee[nd] movei[tem] mp[osition] mr mr[otate] msc[ale] mse[lect] mselect mt[olerance] mu[nselect] multcurve multinv multipleadditem multipleitems multiplejoin multipleselect multprop mw[ho] nai ne near neatline neatlineg[rid] neatlineh[atch] neatlinel[abels] neatlinet[ics] new next ni[bble] nodeangleitem nodec[olor] nodee[rrors] nodem[arkers] nodep[oint] nodes nodesi[ze] nodesn[ap] nodesp[ot] nodet[ext] nor[mal] not ns[elect] oe ogrid ogridt[ool] oldwindow oo[ps] op[endatabase] or
syn keyword amlArcCmd contained  osymbol over overflow overflowa[rea] overflowp[osition] overflows[eparati] overl[ayevents] overlapsymbol overlayevents overp[ost] pagee[xtent] pages[ize] pageu[nits] pal[info] pan panview par[ticletrack] patc[h] path[distance] pe[nsize] pi[ck] pli[st] plot plotcopy plotg[erber] ploti[con] plotmany plotpanel plotsc[itex] plotsi[f] pointde[nsity] pointdist pointdista[nce] pointdo[ts] pointg[rid] pointi[nterp] pointm[arkers] pointn[ode] points pointsp[ot] pointst[ats] pointt[ext] polygonb[ordertex] polygond[ots] polygone[vents] polygonevents polygonl[ines] polygons polygonsh[ades] polygonsi[zelimit] polygonsp[ot] polygont[ext] polygr[id] polyr[egion] pop[ularity] por[ouspuff] pos pos[tscript] positions postscript pow prec[ision] prep[are] princ[omp] print product producti[nfo] project projectcom[pare] projectcop[y] projectd[efine] pul[litems] pur[gehistory] put pv q q[uit] quit rand rang[e] rank rb rc re readg[raphic] reads[elect] reb[ox] recl[ass] recoverdb rect[ify]
syn keyword amlArcCmd contained  red[o] refreshview regionb[uffer] regioncla[ss] regioncle[an] regiondi[ssolve] regiondo[ts] regione[rrors] regiong[roup] regionj[oin] regionl[ines] regionpoly regionpolyc[ount] regionpolycount regionpolyl[ist] regionpolylist regionq[uery] regions regionse[lect] regionsh[ades] regionsp[ot] regiont[ext] regionxa[rea] regionxarea regionxt[ab] regionxtab register registerd[bms] regr[ession] reindex rej[ects] rela[te] rele[ase] rem remapgrid reme[asure] remo[vescalar] remove removeback removecover removeedit removesnap removetransfer rename renamew[orkspace] renameworkspace reno[de] rep[lace] reposition resa[mple] resel[ect] reset resh[ape] restore restorearce[dit] restorearch[ive] resu[me] rgb2h[ue] rgb2s[at] rgb2v[al] rotate rotatep[lot] routea[rc] routeends routeendt[ext] routeer[rors] routeev[entspot] routeh[atch] routel[ines] routes routesp[ot] routest[ats] routet[ext] rp rs rt rt[l] rtl rv rw sa sai sample samples[ig] sav[e] savecolormap sc scal[ar] scat[tergram]
syn keyword amlArcCmd contained  scenefog sceneformat scenehaze sceneoversample sceneroll scenesave scenesize scenesky scitexl[ine] scitexpoi[nt] scitexpol[y] scitexr[ead] scitexread scitexw[rite] scitexwrite sco screenr[estore] screens[ave] sd sds sdtse[xport] sdtsim[port] sdtsin[fo] sdtsl[ist] se sea[rchtolerance] sectiona[rc] sectionends sectionendt[ext] sectionh[atch] sectionl[ines] sections sectionsn[ap] sectionsp[ot] sectiont[ext] sel select selectb[ox] selectc[ircle] selectg[et] selectm[ask] selectmode selectpoi[nt] selectpol[ygon] selectpu[t] selectt[ype] selectw[ithin] semivariogram sep[arator] separator ser[verstatus] setan[gle] setar[row] setce[ll] setcoa[lesce] setcon[nectinfo] setd[bmscheckin] setdrawsymbol sete[ditmode] setincrement setm[ask] setn[ull] setools setreference setsymbol setturn setw[indow] sext sf sfmt sfo sha shade shadea[ngle] shadeb[ackcolor] shadecolor shadecolorr[amp] shadecopy shadecopyl[ayer] shadedelete shadedeletel[ayer] shadeedit shadegrid shadei[nfo] shadela[yer]
syn keyword amlArcCmd contained  shadeli[nepattern] shadelist shadeo[ffset] shadepa[ttern] shadepe[n] shadepu[t] shadesa[ve] shadesc[ale] shadesep[aration] shadeset shadesi[ze] shadesy[mbol] shadet[ype] shapea[rc] shapef[ile] shapeg[rid] shi[ft] show showconstants showe[ditmode] shr[ink] si sin sinfo sing[leuser] sinh sink sit[e] sl slf[arc] sli[ce] slo[pe] sm smartanno snap snapc[over] snapcover snapcoverage snapenvironment snapfeatures snapitems snapo[rder] snappi[ng] snappo[ur] so[rt] sobs sos spi[der] spiraltrans spline splinem[ethod] split spot spoto[ffset] spots[ize] sproj sqr sqrt sra sre srl ss ssc ssh ssi ssky ssz sta stackh[istogram] stackprofile stacksc[attergram] stackshade stackst[ats] stati[stics] statu[s] statuscogo std stra[ighten] streamline streamlink streamo[rder] stri[pmap] subm[it] subs[elect] sum surface surfaceabbrev surfacecontours surfacedefaults surfacedrape surfaceextent surfaceinfo surfacel[ength] surfacelimits surfacemarker surfacemenu surfaceobserver surfaceprofile
syn keyword amlArcCmd contained  surfaceprojectio surfacerange surfaceresolutio surfacesave surfacescene surfaceshade surfacesighting surfacetarget surfacevalue surfaceviewfield surfaceviewshed surfacevisibility surfacexsection surfacezoom surfacezscale sv svfd svs sxs symboldump symboli[tem] symbolsa[ve] symbolsc[ale] symbolse[t] symbolset sz tab[les] tal[ly] tan tanh tc te tes[t] text textal[ignment] textan[gle] textcolor textcolorr[amp] textcop[y] textde[lete] textdi[rection] textedit textfil[e] textfit textfo[nt] textin[fo] textit[em] textj[ustificatio] textlist textm[ask] texto[ffset] textpe[n] textpr[ecision] textpu[t] textq[uality] textsa[ve] textsc[ale] textse[t] textset textsi[ze] textsl[ant] textspa[cing] textspl[ine] textst[yle] textsy[mbol] tf th thie[ssen] thin ti tics tict[ext] tigera[rc] tigert[ool] tigertool til[es] timped tin tina[rc] tinc[ontour] tinerrors tinhull tinl[attice] tinlines tinmarkers tins[pot] tinshades tintext tinv[rml] tl tm tol[erance] top[ogrid] topogridtool
syn keyword amlArcCmd contained  transa[ction] transfe[r] transfercoverage transferfeature transferitems transfersymbol transfo[rm] travrst travsav tre[nd] ts tsy tt tur[ntable] turnimpedance tut[orial] una[ry] unde[lete] undo ungenerate ungeneratet[in] unio[n] unit[s] unr[egisterdbms] unse[lect] unsp[lit] update updatei[nfoschema] updatel[abels] upo[s] us[age] v va[riety] vcgl vcgl2 veri[fy] vers[ion] vertex viewrst viewsav vip visd[ecode] visdecode vise[ncode] visencode visi[bility] vo[lume] vpfe[xport] vpfi[mport] vpfl[ist] vpft[ile] w war[p] wat[ershed] weedd[raw] weedo[perator] weedt[olerance] weedtolerance whe[re] whi[le] who wi[ndows] wm[f] wo[rkspace] workspace writec[andidates] writeg[raphic] writes[elect] wt x[or] ze[ta] zeta zi zo zonala[rea] zonalc[entroid] zonalf[ill] zonalg[eometry] zonalmaj[ority] zonalmax zonalmea[n] zonalmed[ian] zonalmin zonalmino[rity] zonalp[erimeter] zonalr[ange] zonalsta[ts] zonalstd zonalsu[m] zonalt[hickness] zonalv[ariety] zoomview zv

" FORMEDIT reserved words, defined as keywords.

syn keyword amlFormedCmd contained  button choice display help input slider text

" TABLES reserved words, defined as keywords.

syn keyword amlTabCmd contained  add additem alter asciihelp aselect at calc calculate change commands commit copy define directory dropindex dropitem erase external get help indexitem items kill list move nselect purge quit redefine rename reselect rollback save select show sort statistics unload update usagecontained

" INFO reserved words, defined as keywords.

syn keyword amlInfoCmd contained  accept add adir alter dialog alter alt directory aret arithmetic expressions aselect automatic return calculate cchr change options change comi cominput commands list como comoutput compile concatenate controlling defaults copy cursor data delete data entry data manipulate data retrieval data update date format datafile create datafile management decode define delimiter dfmt directory management directory display do doend documentation done end environment erase execute exiting expand export external fc files first format forms control get goto help import input form ipf internal item types items label lchar list logical expressions log merge modify options modify move next nselect output password prif print programming program protect purge query quit recase redefine relate relate release notes remark rename report options reporting report reselect reserved words restrictions run save security select set sleep sort special form spool stop items system variables take terminal types terminal time topics list type update upf

" VTRACE reserved words, defined as keywords.

syn keyword amlVtrCmd contained  add al arcscan arrowlength arrowwidth as aw backtrack branch bt cj clearjunction commands cs dash endofline endofsession eol eos fan fg foreground gap generalizetolerance gtol help hole js junctionsensitivity linesymbol linevariation linewidth ls lv lw markersymbol mode ms raster regionofinterest reset restore retrace roi save searchradius skip sr sta status stc std str straightenangle straightencorner straightendistance straightenrange vt vtrace

" The AML reserved words, defined as keywords.

syn keyword amlFunction contained  abs access acos after angrad asin atan before calc close copy cos cover coverage cvtdistance date delete dignum dir directory entryname exist[s] exp extract file filelist format formatdate full getchar getchoice getcover getdatabase getdeflayers getfile getgrid getimage getitem getlayercols getlibrary getstack getsymbol gettin getunique iacclose iacconnect iacdisconnect iacopen iacrequest index indexed info invangle invdistance iteminfo joinfile keyword length listfile listitem listunique locase log max menu min mod noecho null okangle okdistance open pathname prefix query quote quoteexists r radang random read rename response round scratchname search show sin sort sqrt subst substr suffix tan task token translate trim truncate type unquote upcase username value variable verify write

syn keyword amlDir contained  abbreviations above all aml amlpath append arc args atool brief by call canvas cc center cl codepage commands conv_watch_to_aml coordinates cr create current cursor cwta dalines data date_format delete delvar describe dfmt digitizer display do doend dv echo else enable encode encrypt end error expansion fail file flushpoints force form format frame fullscreen function getlastpoint getpoint goto iacreturn if ignore info inform key keypad label lc left lf lg list listchar listfiles listglobal listheader listlocal listprogram listvar ll lp lr lv map matrix menu menupath menutype mess message[s] modal mouse nopaging off on others page pause pinaction popup position pt pulldown push pushpoint r repeat return right routine run runwatch rw screen seconds select self setchar severity show sidebar single size staggered station stop stripe sys system tablet tb terminal test then thread to top translate tty ty type uc ul until ur usage w warning watch when while window workspace

syn keyword amlDir2 contained  delvar dv s set setvar sv

syn keyword amlOutput contained  inform warning error pause stop tty ty type


" AML Directives:
syn match amlDirSym "&"
syn match amlDirective "&[a-zA-Z]*" contains=amlDir,amlDir2,amlDirSym

" AML Functions
syn region amlFunc start="\[ *[a-zA-Z]*" end="\]" contains=amlFunction,amlVar
syn match amlFunc2 "\[.*\[.*\].*\]" contains=amlFunction,amlVar

" Numbers:
"syn match amlNumber		"-\=\<[0-9]*\.\=[0-9_]\>"

" Quoted Strings:
syn region amlQuote start=+"+ skip=+\\"+ end=+"+ contains=amlVar
syn region amlQuote start=+'+ skip=+\\'+ end=+'+

" ARC Application Commands only selected at the beginning of the line,
" or after a one line &if &then statement
syn match amlAppCmd "^ *[a-zA-Z]*" contains=amlArcCmd,amlInfoCmd,amlTabCmd,amlVtrCmd,amlFormedCmd
syn region amlAppCmd start="&then" end="$" contains=amlArcCmd,amlFormedCmd,amlInfoCmd,amlTabCmd,amlVtrCmd,amlFunction,amlDirective,amlVar2,amlSkip,amlVar,amlComment

" Variables
syn region amlVar start="%" end="%"
syn region amlVar start="%" end="%" contained
syn match amlVar2 "&s [a-zA-Z_.0-9]*" contains=amlDir2,amlDirSym
syn match amlVar2 "&sv [a-zA-Z_.0-9]*" contains=amlDir2,amlDirSym
syn match amlVar2 "&set [a-zA-Z_.0-9]*" contains=amlDir2,amlDirSym
syn match amlVar2 "&setvar [a-zA-Z_.0-9]*" contains=amlDir2,amlDirSym
syn match amlVar2 "&dv [a-zA-Z_.0-9]*" contains=amlDir2,amlDirSym
syn match amlVar2 "&delvar [a-zA-Z_.0-9]*" contains=amlDir2,amlDirSym

" Formedit 2 word commands
syn match amlFormed "^ *check box"
syn match amlFormed "^ *data list"
syn match amlFormed "^ *symbol list"

" Tables 2 word commands
syn match amlTab "^ *q stop"
syn match amlTab "^ *quit stop"

" Comments:
syn match amlComment "/\*.*"

" Regions for skipping over (not highlighting) program output strings:
syn region amlSkip matchgroup=amlOutput start="&call" end="$" contains=amlVar
syn region amlSkip matchgroup=amlOutput start="&routine" end="$" contains=amlVar
syn region amlSkip matchgroup=amlOutput start="&inform" end="$" contains=amlVar
syn region amlSkip matchgroup=amlOutput start="&return &inform" end="$" contains=amlVar
syn region amlSkip matchgroup=amlOutput start="&return &warning" end="$" contains=amlVar
syn region amlSkip matchgroup=amlOutput start="&return &error" end="$" contains=amlVar
syn region amlSkip matchgroup=amlOutput start="&pause" end="$" contains=amlVar
syn region amlSkip matchgroup=amlOutput start="&stop" end="$" contains=amlVar
syn region amlSkip matchgroup=amlOutput start="&tty" end="$" contains=amlVar
syn region amlSkip matchgroup=amlOutput start="&ty" end="$" contains=amlVar
syn region amlSkip matchgroup=amlOutput start="&typ" end="$" contains=amlVar
syn region amlSkip matchgroup=amlOutput start="&type" end="$" contains=amlVar

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_aml_syntax_inits")
  if version < 508
    let did_aml_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink amlComment	Comment
  HiLink amlNumber	Number
  HiLink amlQuote	String
  HiLink amlVar	Identifier
  HiLink amlVar2	Identifier
  HiLink amlFunction	PreProc
  HiLink amlDir	Statement
  HiLink amlDir2	Statement
  HiLink amlDirSym	Statement
  HiLink amlOutput	Statement
  HiLink amlArcCmd	ModeMsg
  HiLink amlFormedCmd	amlArcCmd
  HiLink amlTabCmd	amlArcCmd
  HiLink amlInfoCmd	amlArcCmd
  HiLink amlVtrCmd	amlArcCmd
  HiLink amlFormed	amlArcCmd
  HiLink amlTab	amlArcCmd

  delcommand HiLink
endif

let b:current_syntax = "aml"
