" Interactive Data Language syntax file (IDL, too  [:-)]
" Maintainer: Aleksandar Jelenak <ajelenak AT yahoo.com>
" Last change: 2011 Apr 11
" Created by: Hermann Rochholz <Hermann.Rochholz AT gmx.de>

" Remove any old syntax stuff hanging around
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syntax case ignore

syn match idlangStatement "^\s*pro\s"
syn match idlangStatement "^\s*function\s"
syn keyword idlangStatement return continue mod do break
syn keyword idlangStatement compile_opt forward_function goto
syn keyword idlangStatement begin common end of
syn keyword idlangStatement inherits on_ioerror begin

syn keyword idlangConditional if else then for while case switch
syn keyword idlangConditional endcase endelse endfor endswitch
syn keyword idlangConditional endif endrep endwhile repeat until

syn match idlangOperator "\ and\ "
syn match idlangOperator "\ eq\ "
syn match idlangOperator "\ ge\ "
syn match idlangOperator "\ gt\ "
syn match idlangOperator "\ le\ "
syn match idlangOperator "\ lt\ "
syn match idlangOperator "\ ne\ "
syn match idlangOperator /\(\ \|(\)not\ /hs=e-3
syn match idlangOperator "\ or\ "
syn match idlangOperator "\ xor\ "

syn keyword idlangStop stop pause

syn match idlangStrucvar "\h\w*\(\.\h\w*\)\+"
syn match idlangStrucvar "[),\]]\(\.\h\w*\)\+"hs=s+1

syn match idlangSystem "\!\a\w*\(\.\w*\)\="

syn match idlangKeyword "\([(,]\s*\(\$\_s*\)\=\)\@<=/\h\w*"
syn match idlangKeyword "\([(,]\s*\(\$\_s*\)\=\)\@<=\h\w*\s*="

syn keyword idlangTodo contained TODO

syn region idlangString start=+"+ end=+"+
syn region idlangString start=+'+ end=+'+

syn match idlangPreCondit "^\s*@\w*\(\.\a\{3}\)\="

syn match idlangRealNumber "\<\d\+\(\.\=\d*e[+-]\=\d\+\|\.\d*d\|\.\d*\|d\)"
syn match idlangRealNumber "\.\d\+\(d\|e[+-]\=\d\+\)\="

syn match idlangNumber "\<\.\@!\d\+\.\@!\(b\|u\|us\|s\|l\|ul\|ll\|ull\)\=\>"

syn match  idlangComment "[\;].*$" contains=idlangTodo

syn match idlangContinueLine "\$\s*\($\|;\)"he=s+1 contains=idlangComment
syn match idlangContinueLine "&\s*\(\h\|;\)"he=s+1 contains=ALL

syn match  idlangDblCommaError "\,\s*\,"

" List of standard routines as of IDL version 5.4.
syn match idlangRoutine "EOS_\a*"
syn match idlangRoutine "HDF_\a*"
syn match idlangRoutine "CDF_\a*"
syn match idlangRoutine "NCDF_\a*"
syn match idlangRoutine "QUERY_\a*"
syn match idlangRoutine "\<MAX\s*("he=e-1
syn match idlangRoutine "\<MIN\s*("he=e-1

syn keyword idlangRoutine A_CORRELATE ABS ACOS ADAPT_HIST_EQUAL ALOG ALOG10
syn keyword idlangRoutine AMOEBA ANNOTATE ARG_PRESENT ARRAY_EQUAL ARROW
syn keyword idlangRoutine ASCII_TEMPLATE ASIN ASSOC ATAN AXIS BAR_PLOT
syn keyword idlangRoutine BESELI BESELJ BESELK BESELY BETA BILINEAR BIN_DATE
syn keyword idlangRoutine BINARY_TEMPLATE BINDGEN BINOMIAL BLAS_AXPY BLK_CON
syn keyword idlangRoutine BOX_CURSOR BREAK BREAKPOINT BROYDEN BYTARR BYTE
syn keyword idlangRoutine BYTEORDER BYTSCL C_CORRELATE CALDAT CALENDAR
syn keyword idlangRoutine CALL_EXTERNAL CALL_FUNCTION CALL_METHOD
syn keyword idlangRoutine CALL_PROCEDURE CATCH CD CEIL CHEBYSHEV CHECK_MATH
syn keyword idlangRoutine CHISQR_CVF CHISQR_PDF CHOLDC CHOLSOL CINDGEN
syn keyword idlangRoutine CIR_3PNT CLOSE CLUST_WTS CLUSTER COLOR_CONVERT
syn keyword idlangRoutine COLOR_QUAN COLORMAP_APPLICABLE COMFIT COMMON
syn keyword idlangRoutine COMPLEX COMPLEXARR COMPLEXROUND
syn keyword idlangRoutine COMPUTE_MESH_NORMALS COND CONGRID CONJ
syn keyword idlangRoutine CONSTRAINED_MIN CONTOUR CONVERT_COORD CONVOL
syn keyword idlangRoutine COORD2TO3 CORRELATE COS COSH CRAMER CREATE_STRUCT
syn keyword idlangRoutine CREATE_VIEW CROSSP CRVLENGTH CT_LUMINANCE CTI_TEST
syn keyword idlangRoutine CURSOR CURVEFIT CV_COORD CVTTOBM CW_ANIMATE
syn keyword idlangRoutine CW_ANIMATE_GETP CW_ANIMATE_LOAD CW_ANIMATE_RUN
syn keyword idlangRoutine CW_ARCBALL CW_BGROUP CW_CLR_INDEX CW_COLORSEL
syn keyword idlangRoutine CW_DEFROI CW_FIELD CW_FILESEL CW_FORM CW_FSLIDER
syn keyword idlangRoutine CW_LIGHT_EDITOR CW_LIGHT_EDITOR_GET
syn keyword idlangRoutine CW_LIGHT_EDITOR_SET CW_ORIENT CW_PALETTE_EDITOR
syn keyword idlangRoutine CW_PALETTE_EDITOR_GET CW_PALETTE_EDITOR_SET
syn keyword idlangRoutine CW_PDMENU CW_RGBSLIDER CW_TMPL CW_ZOOM DBLARR
syn keyword idlangRoutine DCINDGEN DCOMPLEX DCOMPLEXARR DEFINE_KEY DEFROI
syn keyword idlangRoutine DEFSYSV DELETE_SYMBOL DELLOG DELVAR DERIV DERIVSIG
syn keyword idlangRoutine DETERM DEVICE DFPMIN DIALOG_MESSAGE
syn keyword idlangRoutine DIALOG_PICKFILE DIALOG_PRINTERSETUP
syn keyword idlangRoutine DIALOG_PRINTJOB DIALOG_READ_IMAGE
syn keyword idlangRoutine DIALOG_WRITE_IMAGE DIGITAL_FILTER DILATE DINDGEN
syn keyword idlangRoutine DISSOLVE DIST DLM_LOAD DLM_REGISTER
syn keyword idlangRoutine DO_APPLE_SCRIPT DOC_LIBRARY DOUBLE DRAW_ROI EFONT
syn keyword idlangRoutine EIGENQL EIGENVEC ELMHES EMPTY ENABLE_SYSRTN EOF
syn keyword idlangRoutine ERASE ERODE ERRORF ERRPLOT EXECUTE EXIT EXP EXPAND
syn keyword idlangRoutine EXPAND_PATH EXPINT EXTRAC EXTRACT_SLICE F_CVF
syn keyword idlangRoutine F_PDF FACTORIAL FFT FILE_CHMOD FILE_DELETE
syn keyword idlangRoutine FILE_EXPAND_PATH FILE_MKDIR FILE_TEST FILE_WHICH
syn keyword idlangRoutine FILEPATH FINDFILE FINDGEN FINITE FIX FLICK FLOAT
syn keyword idlangRoutine FLOOR FLOW3 FLTARR FLUSH FORMAT_AXIS_VALUES
syn keyword idlangRoutine FORWARD_FUNCTION FREE_LUN FSTAT FULSTR FUNCT
syn keyword idlangRoutine FV_TEST FX_ROOT FZ_ROOTS GAMMA GAMMA_CT
syn keyword idlangRoutine GAUSS_CVF GAUSS_PDF GAUSS2DFIT GAUSSFIT GAUSSINT
syn keyword idlangRoutine GET_DRIVE_LIST GET_KBRD GET_LUN GET_SCREEN_SIZE
syn keyword idlangRoutine GET_SYMBOL GETENV GOTO GRID_TPS GRID3 GS_ITER
syn keyword idlangRoutine H_EQ_CT H_EQ_INT HANNING HEAP_GC HELP HILBERT
syn keyword idlangRoutine HIST_2D HIST_EQUAL HISTOGRAM HLS HOUGH HQR HSV
syn keyword idlangRoutine IBETA IDENTITY IDL_Container IDLanROI
syn keyword idlangRoutine IDLanROIGroup IDLffDICOM IDLffDXF IDLffLanguageCat
syn keyword idlangRoutine IDLffShape IDLgrAxis IDLgrBuffer IDLgrClipboard
syn keyword idlangRoutine IDLgrColorbar IDLgrContour IDLgrFont IDLgrImage
syn keyword idlangRoutine IDLgrLegend IDLgrLight IDLgrModel IDLgrMPEG
syn keyword idlangRoutine IDLgrPalette IDLgrPattern IDLgrPlot IDLgrPolygon
syn keyword idlangRoutine IDLgrPolyline IDLgrPrinter IDLgrROI IDLgrROIGroup
syn keyword idlangRoutine IDLgrScene IDLgrSurface IDLgrSymbol
syn keyword idlangRoutine IDLgrTessellator IDLgrText IDLgrView
syn keyword idlangRoutine IDLgrViewgroup IDLgrVolume IDLgrVRML IDLgrWindow
syn keyword idlangRoutine IGAMMA IMAGE_CONT IMAGE_STATISTICS IMAGINARY
syn keyword idlangRoutine INDGEN INT_2D INT_3D INT_TABULATED INTARR INTERPOL
syn keyword idlangRoutine INTERPOLATE INVERT IOCTL ISHFT ISOCONTOUR
syn keyword idlangRoutine ISOSURFACE JOURNAL JULDAY KEYWORD_SET KRIG2D
syn keyword idlangRoutine KURTOSIS KW_TEST L64INDGEN LABEL_DATE LABEL_REGION
syn keyword idlangRoutine LADFIT LAGUERRE LEEFILT LEGENDRE LINBCG LINDGEN
syn keyword idlangRoutine LINFIT LINKIMAGE LIVE_CONTOUR LIVE_CONTROL
syn keyword idlangRoutine LIVE_DESTROY LIVE_EXPORT LIVE_IMAGE LIVE_INFO
syn keyword idlangRoutine LIVE_LINE LIVE_LOAD LIVE_OPLOT LIVE_PLOT
syn keyword idlangRoutine LIVE_PRINT LIVE_RECT LIVE_STYLE LIVE_SURFACE
syn keyword idlangRoutine LIVE_TEXT LJLCT LL_ARC_DISTANCE LMFIT LMGR LNGAMMA
syn keyword idlangRoutine LNP_TEST LOADCT LOCALE_GET LON64ARR LONARR LONG
syn keyword idlangRoutine LONG64 LSODE LU_COMPLEX LUDC LUMPROVE LUSOL
syn keyword idlangRoutine M_CORRELATE MACHAR MAKE_ARRAY MAKE_DLL MAP_2POINTS
syn keyword idlangRoutine MAP_CONTINENTS MAP_GRID MAP_IMAGE MAP_PATCH
syn keyword idlangRoutine MAP_PROJ_INFO MAP_SET MATRIX_MULTIPLY MD_TEST MEAN
syn keyword idlangRoutine MEANABSDEV MEDIAN MEMORY MESH_CLIP MESH_DECIMATE
syn keyword idlangRoutine MESH_ISSOLID MESH_MERGE MESH_NUMTRIANGLES MESH_OBJ
syn keyword idlangRoutine MESH_SMOOTH MESH_SURFACEAREA MESH_VALIDATE
syn keyword idlangRoutine MESH_VOLUME MESSAGE MIN_CURVE_SURF MK_HTML_HELP
syn keyword idlangRoutine MODIFYCT MOMENT MORPH_CLOSE MORPH_DISTANCE
syn keyword idlangRoutine MORPH_GRADIENT MORPH_HITORMISS MORPH_OPEN
syn keyword idlangRoutine MORPH_THIN MORPH_TOPHAT MPEG_CLOSE MPEG_OPEN
syn keyword idlangRoutine MPEG_PUT MPEG_SAVE MSG_CAT_CLOSE MSG_CAT_COMPILE
syn keyword idlangRoutine MSG_CAT_OPEN MULTI N_ELEMENTS N_PARAMS N_TAGS
syn keyword idlangRoutine NEWTON NORM OBJ_CLASS OBJ_DESTROY OBJ_ISA OBJ_NEW
syn keyword idlangRoutine OBJ_VALID OBJARR ON_ERROR ON_IOERROR ONLINE_HELP
syn keyword idlangRoutine OPEN OPENR OPENW OPLOT OPLOTERR P_CORRELATE
syn keyword idlangRoutine PARTICLE_TRACE PCOMP PLOT PLOT_3DBOX PLOT_FIELD
syn keyword idlangRoutine PLOTERR PLOTS PNT_LINE POINT_LUN POLAR_CONTOUR
syn keyword idlangRoutine POLAR_SURFACE POLY POLY_2D POLY_AREA POLY_FIT
syn keyword idlangRoutine POLYFILL POLYFILLV POLYSHADE POLYWARP POPD POWELL
syn keyword idlangRoutine PRIMES PRINT PRINTF PRINTD PROFILE PROFILER
syn keyword idlangRoutine PROFILES PROJECT_VOL PS_SHOW_FONTS PSAFM PSEUDO
syn keyword idlangRoutine PTR_FREE PTR_NEW PTR_VALID PTRARR PUSHD QROMB
syn keyword idlangRoutine QROMO QSIMP R_CORRELATE R_TEST RADON RANDOMN
syn keyword idlangRoutine RANDOMU RANKS RDPIX READ READF READ_ASCII
syn keyword idlangRoutine READ_BINARY READ_BMP READ_DICOM READ_IMAGE
syn keyword idlangRoutine READ_INTERFILE READ_JPEG READ_PICT READ_PNG
syn keyword idlangRoutine READ_PPM READ_SPR READ_SRF READ_SYLK READ_TIFF
syn keyword idlangRoutine READ_WAV READ_WAVE READ_X11_BITMAP READ_XWD READS
syn keyword idlangRoutine READU REBIN RECALL_COMMANDS RECON3 REDUCE_COLORS
syn keyword idlangRoutine REFORM REGRESS REPLICATE REPLICATE_INPLACE
syn keyword idlangRoutine RESOLVE_ALL RESOLVE_ROUTINE RESTORE RETALL RETURN
syn keyword idlangRoutine REVERSE REWIND RK4 ROBERTS ROT ROTATE ROUND
syn keyword idlangRoutine ROUTINE_INFO RS_TEST S_TEST SAVE SAVGOL SCALE3
syn keyword idlangRoutine SCALE3D SEARCH2D SEARCH3D SET_PLOT SET_SHADING
syn keyword idlangRoutine SET_SYMBOL SETENV SETLOG SETUP_KEYS SFIT
syn keyword idlangRoutine SHADE_SURF SHADE_SURF_IRR SHADE_VOLUME SHIFT SHOW3
syn keyword idlangRoutine SHOWFONT SIN SINDGEN SINH SIZE SKEWNESS SKIPF
syn keyword idlangRoutine SLICER3 SLIDE_IMAGE SMOOTH SOBEL SOCKET SORT SPAWN
syn keyword idlangRoutine SPH_4PNT SPH_SCAT SPHER_HARM SPL_INIT SPL_INTERP
syn keyword idlangRoutine SPLINE SPLINE_P SPRSAB SPRSAX SPRSIN SPRSTP SQRT
syn keyword idlangRoutine STANDARDIZE STDDEV STOP STRARR STRCMP STRCOMPRESS
syn keyword idlangRoutine STREAMLINE STREGEX STRETCH STRING STRJOIN STRLEN
syn keyword idlangRoutine STRLOWCASE STRMATCH STRMESSAGE STRMID STRPOS
syn keyword idlangRoutine STRPUT STRSPLIT STRTRIM STRUCT_ASSIGN STRUCT_HIDE
syn keyword idlangRoutine STRUPCASE SURFACE SURFR SVDC SVDFIT SVSOL
syn keyword idlangRoutine SWAP_ENDIAN SWITCH SYSTIME T_CVF T_PDF T3D
syn keyword idlangRoutine TAG_NAMES TAN TANH TAPRD TAPWRT TEK_COLOR
syn keyword idlangRoutine TEMPORARY TETRA_CLIP TETRA_SURFACE TETRA_VOLUME
syn keyword idlangRoutine THIN THREED TIME_TEST2 TIMEGEN TM_TEST TOTAL TRACE
syn keyword idlangRoutine TRANSPOSE TRI_SURF TRIANGULATE TRIGRID TRIQL
syn keyword idlangRoutine TRIRED TRISOL TRNLOG TS_COEF TS_DIFF TS_FCAST
syn keyword idlangRoutine TS_SMOOTH TV TVCRS TVLCT TVRD TVSCL UINDGEN UINT
syn keyword idlangRoutine UINTARR UL64INDGEN ULINDGEN ULON64ARR ULONARR
syn keyword idlangRoutine ULONG ULONG64 UNIQ USERSYM VALUE_LOCATE VARIANCE
syn keyword idlangRoutine VAX_FLOAT VECTOR_FIELD VEL VELOVECT VERT_T3D VOIGT
syn keyword idlangRoutine VORONOI VOXEL_PROJ WAIT WARP_TRI WATERSHED WDELETE
syn keyword idlangRoutine WEOF WF_DRAW WHERE WIDGET_BASE WIDGET_BUTTON
syn keyword idlangRoutine WIDGET_CONTROL WIDGET_DRAW WIDGET_DROPLIST
syn keyword idlangRoutine WIDGET_EVENT WIDGET_INFO WIDGET_LABEL WIDGET_LIST
syn keyword idlangRoutine WIDGET_SLIDER WIDGET_TABLE WIDGET_TEXT WINDOW
syn keyword idlangRoutine WRITE_BMP WRITE_IMAGE WRITE_JPEG WRITE_NRIF
syn keyword idlangRoutine WRITE_PICT WRITE_PNG WRITE_PPM WRITE_SPR WRITE_SRF
syn keyword idlangRoutine WRITE_SYLK WRITE_TIFF WRITE_WAV WRITE_WAVE WRITEU
syn keyword idlangRoutine WSET WSHOW WTN WV_APPLET WV_CW_WAVELET WV_CWT
syn keyword idlangRoutine WV_DENOISE WV_DWT WV_FN_COIFLET WV_FN_DAUBECHIES
syn keyword idlangRoutine WV_FN_GAUSSIAN WV_FN_HAAR WV_FN_MORLET WV_FN_PAUL
syn keyword idlangRoutine WV_FN_SYMLET WV_IMPORT_DATA WV_IMPORT_WAVELET
syn keyword idlangRoutine WV_PLOT3D_WPS WV_PLOT_MULTIRES WV_PWT
syn keyword idlangRoutine WV_TOOL_DENOISE XBM_EDIT XDISPLAYFILE XDXF XFONT
syn keyword idlangRoutine XINTERANIMATE XLOADCT XMANAGER XMNG_TMPL XMTOOL
syn keyword idlangRoutine XOBJVIEW XPALETTE XPCOLOR XPLOT3D XREGISTERED XROI
syn keyword idlangRoutine XSQ_TEST XSURFACE XVAREDIT XVOLUME XVOLUME_ROTATE
syn keyword idlangRoutine XVOLUME_WRITE_IMAGE XYOUTS ZOOM ZOOM_24

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link idlangConditional	Conditional
hi def link idlangRoutine	Type
hi def link idlangStatement	Statement
hi def link idlangContinueLine	Todo
hi def link idlangRealNumber	Float
hi def link idlangNumber	Number
hi def link idlangString	String
hi def link idlangOperator	Operator
hi def link idlangComment	Comment
hi def link idlangTodo	Todo
hi def link idlangPreCondit	Identifier
hi def link idlangDblCommaError	Error
hi def link idlangStop	Error
hi def link idlangStrucvar	PreProc
hi def link idlangSystem	Identifier
hi def link idlangKeyword	Special


let b:current_syntax = "idlang"
" vim: ts=18
