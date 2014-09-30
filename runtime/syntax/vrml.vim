" Vim syntax file
" Language:	   VRML97
" Modified from:   VRML 1.0C by David Brown <dbrown@cgs.c4.gmeds.com>
" Maintainer:	   vacancy!
" Former Maintainer:    Gregory Seidman <gsslist+vim@anthropohedron.net>
" Last change:	   2006 May 03

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" keyword definitions

syn keyword VRMLFields	       ambientIntensity appearance attenuation
syn keyword VRMLFields	       autoOffset avatarSize axisOfRotation backUrl
syn keyword VRMLFields	       bboxCenter bboxSize beamWidth beginCap
syn keyword VRMLFields	       bottom bottomRadius bottomUrl ccw center
syn keyword VRMLFields	       children choice collide color colorIndex
syn keyword VRMLFields	       colorPerVertex convex coord coordIndex
syn keyword VRMLFields	       creaseAngle crossSection cutOffAngle
syn keyword VRMLFields	       cycleInterval description diffuseColor
syn keyword VRMLFields	       directOutput direction diskAngle
syn keyword VRMLFields	       emissiveColor enabled endCap family
syn keyword VRMLFields	       fieldOfView fogType fontStyle frontUrl
syn keyword VRMLFields	       geometry groundAngle groundColor headlight
syn keyword VRMLFields	       height horizontal info intensity jump
syn keyword VRMLFields	       justify key keyValue language leftToRight
syn keyword VRMLFields	       leftUrl length level location loop material
syn keyword VRMLFields	       maxAngle maxBack maxExtent maxFront
syn keyword VRMLFields	       maxPosition minAngle minBack minFront
syn keyword VRMLFields	       minPosition mustEvaluate normal normalIndex
syn keyword VRMLFields	       normalPerVertex offset on orientation
syn keyword VRMLFields	       parameter pitch point position priority
syn keyword VRMLFields	       proxy radius range repeatS repeatT rightUrl
syn keyword VRMLFields	       rotation scale scaleOrientation shininess
syn keyword VRMLFields	       side size skyAngle skyColor solid source
syn keyword VRMLFields	       spacing spatialize specularColor speed spine
syn keyword VRMLFields	       startTime stopTime string style texCoord
syn keyword VRMLFields	       texCoordIndex texture textureTransform title
syn keyword VRMLFields	       top topToBottom topUrl translation
syn keyword VRMLFields	       transparency type url vector visibilityLimit
syn keyword VRMLFields	       visibilityRange whichChoice xDimension
syn keyword VRMLFields	       xSpacing zDimension zSpacing
syn match   VRMLFields	       "\<[A-Za-z_][A-Za-z0-9_]*\>" contains=VRMLComment,VRMLProtos,VRMLfTypes
" syn match   VRMLFields	 "\<[A-Za-z_][A-Za-z0-9_]*\>\(,\|\s\)*\(#.*$\)*\<IS\>\(#.*$\)*\(,\|\s\)*\<[A-Za-z_][A-Za-z0-9_]*\>\(,\|\s\)*\(#.*$\)*" contains=VRMLComment,VRMLProtos
" syn region  VRMLFields	 start="\<[A-Za-z_][A-Za-z0-9_]*\>" end=+\(,\|#\|\s\)+me=e-1 contains=VRMLComment,VRMLProtos

syn keyword VRMLEvents	       addChildren ambientIntensity_changed
syn keyword VRMLEvents	       appearance_changed attenuation_changed
syn keyword VRMLEvents	       autoOffset_changed avatarSize_changed
syn keyword VRMLEvents	       axisOfRotation_changed backUrl_changed
syn keyword VRMLEvents	       beamWidth_changed bindTime bottomUrl_changed
syn keyword VRMLEvents	       center_changed children_changed
syn keyword VRMLEvents	       choice_changed collideTime collide_changed
syn keyword VRMLEvents	       color_changed coord_changed
syn keyword VRMLEvents	       cutOffAngle_changed cycleInterval_changed
syn keyword VRMLEvents	       cycleTime description_changed
syn keyword VRMLEvents	       diffuseColor_changed direction_changed
syn keyword VRMLEvents	       diskAngle_changed duration_changed
syn keyword VRMLEvents	       emissiveColor_changed enabled_changed
syn keyword VRMLEvents	       enterTime exitTime fogType_changed
syn keyword VRMLEvents	       fontStyle_changed fraction_changed
syn keyword VRMLEvents	       frontUrl_changed geometry_changed
syn keyword VRMLEvents	       groundAngle_changed headlight_changed
syn keyword VRMLEvents	       hitNormal_changed hitPoint_changed
syn keyword VRMLEvents	       hitTexCoord_changed intensity_changed
syn keyword VRMLEvents	       isActive isBound isOver jump_changed
syn keyword VRMLEvents	       keyValue_changed key_changed leftUrl_changed
syn keyword VRMLEvents	       length_changed level_changed
syn keyword VRMLEvents	       location_changed loop_changed
syn keyword VRMLEvents	       material_changed maxAngle_changed
syn keyword VRMLEvents	       maxBack_changed maxExtent_changed
syn keyword VRMLEvents	       maxFront_changed maxPosition_changed
syn keyword VRMLEvents	       minAngle_changed minBack_changed
syn keyword VRMLEvents	       minFront_changed minPosition_changed
syn keyword VRMLEvents	       normal_changed offset_changed on_changed
syn keyword VRMLEvents	       orientation_changed parameter_changed
syn keyword VRMLEvents	       pitch_changed point_changed position_changed
syn keyword VRMLEvents	       priority_changed radius_changed
syn keyword VRMLEvents	       removeChildren rightUrl_changed
syn keyword VRMLEvents	       rotation_changed scaleOrientation_changed
syn keyword VRMLEvents	       scale_changed set_ambientIntensity
syn keyword VRMLEvents	       set_appearance set_attenuation
syn keyword VRMLEvents	       set_autoOffset set_avatarSize
syn keyword VRMLEvents	       set_axisOfRotation set_backUrl set_beamWidth
syn keyword VRMLEvents	       set_bind set_bottomUrl set_center
syn keyword VRMLEvents	       set_children set_choice set_collide
syn keyword VRMLEvents	       set_color set_colorIndex set_coord
syn keyword VRMLEvents	       set_coordIndex set_crossSection
syn keyword VRMLEvents	       set_cutOffAngle set_cycleInterval
syn keyword VRMLEvents	       set_description set_diffuseColor
syn keyword VRMLEvents	       set_direction set_diskAngle
syn keyword VRMLEvents	       set_emissiveColor set_enabled set_fogType
syn keyword VRMLEvents	       set_fontStyle set_fraction set_frontUrl
syn keyword VRMLEvents	       set_geometry set_groundAngle set_headlight
syn keyword VRMLEvents	       set_height set_intensity set_jump set_key
syn keyword VRMLEvents	       set_keyValue set_leftUrl set_length
syn keyword VRMLEvents	       set_level set_location set_loop set_material
syn keyword VRMLEvents	       set_maxAngle set_maxBack set_maxExtent
syn keyword VRMLEvents	       set_maxFront set_maxPosition set_minAngle
syn keyword VRMLEvents	       set_minBack set_minFront set_minPosition
syn keyword VRMLEvents	       set_normal set_normalIndex set_offset set_on
syn keyword VRMLEvents	       set_orientation set_parameter set_pitch
syn keyword VRMLEvents	       set_point set_position set_priority
syn keyword VRMLEvents	       set_radius set_rightUrl set_rotation
syn keyword VRMLEvents	       set_scale set_scaleOrientation set_shininess
syn keyword VRMLEvents	       set_size set_skyAngle set_skyColor
syn keyword VRMLEvents	       set_source set_specularColor set_speed
syn keyword VRMLEvents	       set_spine set_startTime set_stopTime
syn keyword VRMLEvents	       set_string set_texCoord set_texCoordIndex
syn keyword VRMLEvents	       set_texture set_textureTransform set_topUrl
syn keyword VRMLEvents	       set_translation set_transparency set_type
syn keyword VRMLEvents	       set_url set_vector set_visibilityLimit
syn keyword VRMLEvents	       set_visibilityRange set_whichChoice
syn keyword VRMLEvents	       shininess_changed size_changed
syn keyword VRMLEvents	       skyAngle_changed skyColor_changed
syn keyword VRMLEvents	       source_changed specularColor_changed
syn keyword VRMLEvents	       speed_changed startTime_changed
syn keyword VRMLEvents	       stopTime_changed string_changed
syn keyword VRMLEvents	       texCoord_changed textureTransform_changed
syn keyword VRMLEvents	       texture_changed time topUrl_changed
syn keyword VRMLEvents	       touchTime trackPoint_changed
syn keyword VRMLEvents	       translation_changed transparency_changed
syn keyword VRMLEvents	       type_changed url_changed value_changed
syn keyword VRMLEvents	       vector_changed visibilityLimit_changed
syn keyword VRMLEvents	       visibilityRange_changed whichChoice_changed
syn region  VRMLEvents	       start="\S+[^0-9]+\.[A-Za-z_]+"ms=s+1 end="\(,\|$\|\s\)"me=e-1

syn keyword VRMLNodes	       Anchor Appearance AudioClip Background
syn keyword VRMLNodes	       Billboard Box Collision Color
syn keyword VRMLNodes	       ColorInterpolator Cone Coordinate
syn keyword VRMLNodes	       CoordinateInterpolator Cylinder
syn keyword VRMLNodes	       CylinderSensor DirectionalLight
syn keyword VRMLNodes	       ElevationGrid Extrusion Fog FontStyle
syn keyword VRMLNodes	       Group ImageTexture IndexedFaceSet
syn keyword VRMLNodes	       IndexedLineSet Inline LOD Material
syn keyword VRMLNodes	       MovieTexture NavigationInfo Normal
syn keyword VRMLNodes	       NormalInterpolator OrientationInterpolator
syn keyword VRMLNodes	       PixelTexture PlaneSensor PointLight
syn keyword VRMLNodes	       PointSet PositionInterpolator
syn keyword VRMLNodes	       ProximitySensor ScalarInterpolator
syn keyword VRMLNodes	       Script Shape Sound Sphere SphereSensor
syn keyword VRMLNodes	       SpotLight Switch Text TextureCoordinate
syn keyword VRMLNodes	       TextureTransform TimeSensor TouchSensor
syn keyword VRMLNodes	       Transform Viewpoint VisibilitySensor
syn keyword VRMLNodes	       WorldInfo

" the following line doesn't catch <node><newline><openbrace> since \n
" doesn't match as an atom yet :-(
syn match   VRMLNodes	       "[A-Za-z_][A-Za-z0-9_]*\(,\|\s\)*{"me=e-1
syn region  VRMLNodes	       start="\<EXTERNPROTO\>\(,\|\s\)*[A-Za-z_]"ms=e start="\<EXTERNPROTO\>\(,\|\s\)*" end="[\s]*\["me=e-1 contains=VRMLProtos,VRMLComment
syn region  VRMLNodes	       start="PROTO\>\(,\|\s\)*[A-Za-z_]"ms=e start="PROTO\>\(,\|\s\)*" end="[\s]*\["me=e-1 contains=VRMLProtos,VRMLComment

syn keyword VRMLTypes	       SFBool SFColor MFColor SFFloat MFFloat
syn keyword VRMLTypes	       SFImage SFInt32 MFInt32 SFNode MFNode
syn keyword VRMLTypes	       SFRotation MFRotation SFString MFString
syn keyword VRMLTypes	       SFTime MFTime SFVec2f MFVec2f SFVec3f MFVec3f

syn keyword VRMLfTypes	       field exposedField eventIn eventOut

syn keyword VRMLValues	       TRUE FALSE NULL

syn keyword VRMLProtos	       contained EXTERNPROTO PROTO IS

syn keyword VRMLRoutes	       contained ROUTE TO

if version >= 502
"containment!
  syn include @jscript $VIMRUNTIME/syntax/javascript.vim
  syn region VRMLjScriptString contained start=+"\(\(javascript\)\|\(vrmlscript\)\|\(ecmascript\)\):+ms=e+1 skip=+\\\\\|\\"+ end=+"+me=e-1 contains=@jscript
endif

" match definitions.
syn match   VRMLSpecial		  contained "\\[0-9][0-9][0-9]\|\\."
syn region  VRMLString		  start=+"+  skip=+\\\\\|\\"+  end=+"+	contains=VRMLSpecial,VRMLjScriptString
syn match   VRMLCharacter	  "'[^\\]'"
syn match   VRMLSpecialCharacter  "'\\.'"
syn match   VRMLNumber		  "[-+]\=\<[0-9]\+\(\.[0-9]\+\)\=\([eE]\{1}[-+]\=[0-9]\+\)\=\>\|0[xX][0-9a-fA-F]\+\>"
syn match   VRMLNumber		  "0[xX][0-9a-fA-F]\+\>"
syn match   VRMLComment		  "#.*$"

" newlines should count as whitespace, but they can't be matched yet :-(
syn region  VRMLRouteNode	  start="[^O]TO\(,\|\s\)*" end="\."me=e-1 contains=VRMLRoutes,VRMLComment
syn region  VRMLRouteNode	  start="ROUTE\(,\|\s\)*" end="\."me=e-1 contains=VRMLRoutes,VRMLComment
syn region  VRMLInstName	  start="DEF\>"hs=e+1 skip="DEF\(,\|\s\)*" end="[A-Za-z0-9_]\(\s\|$\|,\)"me=e contains=VRMLInstances,VRMLComment
syn region  VRMLInstName	  start="USE\>"hs=e+1 skip="USE\(,\|\s\)*" end="[A-Za-z0-9_]\(\s\|$\|,\)"me=e contains=VRMLInstances,VRMLComment

syn keyword VRMLInstances      contained DEF USE
syn sync minlines=1

if version >= 600
"FOLDS!
  syn sync fromstart
  "setlocal foldmethod=syntax
  syn region braceFold start="{" end="}" transparent fold contains=TOP
  syn region bracketFold start="\[" end="]" transparent fold contains=TOP
  syn region VRMLString start=+"+ skip=+\\\\\|\\"+ end=+"+ fold contains=VRMLSpecial,VRMLjScriptString
endif

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_VRML_syntax_inits")
  if version < 508
    let did_VRML_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink VRMLCharacter  VRMLString
  HiLink VRMLSpecialCharacter VRMLSpecial
  HiLink VRMLNumber     VRMLString
  HiLink VRMLValues     VRMLString
  HiLink VRMLString     String
  HiLink VRMLSpecial    Special
  HiLink VRMLComment    Comment
  HiLink VRMLNodes      Statement
  HiLink VRMLFields     Type
  HiLink VRMLEvents     Type
  HiLink VRMLfTypes     LineNr
"  hi     VRMLfTypes     ctermfg=6 guifg=Brown
  HiLink VRMLInstances  PreCondit
  HiLink VRMLRoutes     PreCondit
  HiLink VRMLProtos     PreProc
  HiLink VRMLRouteNode  Identifier
  HiLink VRMLInstName   Identifier
  HiLink VRMLTypes      Identifier

  delcommand HiLink
endif

let b:current_syntax = "vrml"

" vim: ts=8
