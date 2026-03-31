" Language: OpenGL Shading Language
" Maintainer: Gregory Anders <greg@gpanders.com>
" Last Modified: 2024 Jul 21
" Upstream: https://github.com/tikhomirov/vim-glsl

if exists('b:current_syntax')
  finish
endif

" Statements
syn keyword glslConditional if else switch case default
syn keyword glslRepeat      for while do
syn keyword glslStatement   discard return break continue

" Comments
syn keyword glslTodo     contained TODO FIXME XXX NOTE
syn region  glslCommentL start="//" skip="\\$" end="$" keepend contains=glslTodo,@Spell
syn region  glslComment  matchgroup=glslCommentStart start="/\*" end="\*/" extend contains=glslTodo,@Spell

" Preprocessor
syn region  glslPreCondit       start="^\s*#\s*\(if\|ifdef\|ifndef\|else\|elif\|endif\)" skip="\\$" end="$" keepend
syn region  glslDefine          start="^\s*#\s*\(define\|undef\)" skip="\\$" end="$" keepend
syn keyword glslTokenConcat     ##
syn keyword glslPredefinedMacro __LINE__ __FILE__ __VERSION__ GL_ES
syn region  glslPreProc         start="^\s*#\s*\(error\|pragma\|extension\|version\|line\)" skip="\\$" end="$" keepend
syn region  glslInclude         start="^\s*#\s*include" skip="\\$" end="$" keepend

" Folding Blocks
syn region glslCurlyBlock start="{" end="}" transparent fold
syn region glslParenBlock start="(" end=")" transparent fold

" Boolean Constants
syn keyword glslBoolean true false

" Integer Numbers
syn match glslDecimalInt display "\<\(0\|[1-9]\d*\)[uU]\?"
syn match glslOctalInt   display "\<0\o\+[uU]\?"
syn match glslHexInt     display "\<0[xX]\x\+[uU]\?"

" Float Numbers
syn match glslFloat display "\<\d\+\.\([eE][+-]\=\d\+\)\=\(lf\|LF\|f\|F\)\="
syn match glslFloat display "\<\.\d\+\([eE][+-]\=\d\+\)\=\(lf\|LF\|f\|F\)\="
syn match glslFloat display "\<\d\+[eE][+-]\=\d\+\(lf\|LF\|f\|F\)\="
syn match glslFloat display "\<\d\+\.\d\+\([eE][+-]\=\d\+\)\=\(lf\|LF\|f\|F\)\="

" Swizzles
syn match glslSwizzle display /\.[xyzw]\{1,4\}\>/
syn match glslSwizzle display /\.[rgba]\{1,4\}\>/
syn match glslSwizzle display /\.[stpq]\{1,4\}\>/

" Structure
syn keyword glslStructure struct nextgroup=glslIdentifier skipwhite skipempty

syn match glslIdentifier contains=glslIdentifierPrime "\%([a-zA-Z_]\)\%([a-zA-Z0-9_]\)*" display contained

" Types
syn keyword glslType accelerationStructureEXT
syn keyword glslType atomic_uint
syn keyword glslType bool
syn keyword glslType bvec2
syn keyword glslType bvec3
syn keyword glslType bvec4
syn keyword glslType dmat2
syn keyword glslType dmat2x2
syn keyword glslType dmat2x3
syn keyword glslType dmat2x4
syn keyword glslType dmat3
syn keyword glslType dmat3x2
syn keyword glslType dmat3x3
syn keyword glslType dmat3x4
syn keyword glslType dmat4
syn keyword glslType dmat4x2
syn keyword glslType dmat4x3
syn keyword glslType dmat4x4
syn keyword glslType double
syn keyword glslType dvec2
syn keyword glslType dvec3
syn keyword glslType dvec4
syn keyword glslType float
syn keyword glslType iimage1D
syn keyword glslType iimage1DArray
syn keyword glslType iimage2D
syn keyword glslType iimage2DArray
syn keyword glslType iimage2DMS
syn keyword glslType iimage2DMSArray
syn keyword glslType iimage2DRect
syn keyword glslType iimage3D
syn keyword glslType iimageBuffer
syn keyword glslType iimageCube
syn keyword glslType iimageCubeArray
syn keyword glslType image1D
syn keyword glslType image1DArray
syn keyword glslType image2D
syn keyword glslType image2DArray
syn keyword glslType image2DMS
syn keyword glslType image2DMSArray
syn keyword glslType image2DRect
syn keyword glslType image3D
syn keyword glslType imageBuffer
syn keyword glslType imageCube
syn keyword glslType imageCubeArray
syn keyword glslType int
syn keyword glslType isampler1D
syn keyword glslType isampler1DArray
syn keyword glslType isampler2D
syn keyword glslType isampler2DArray
syn keyword glslType isampler2DMS
syn keyword glslType isampler2DMSArray
syn keyword glslType isampler2DRect
syn keyword glslType isampler3D
syn keyword glslType isamplerBuffer
syn keyword glslType isamplerCube
syn keyword glslType isamplerCubeArray
syn keyword glslType ivec2
syn keyword glslType ivec3
syn keyword glslType ivec4
syn keyword glslType mat2
syn keyword glslType mat2x2
syn keyword glslType mat2x3
syn keyword glslType mat2x4
syn keyword glslType mat3
syn keyword glslType mat3x2
syn keyword glslType mat3x3
syn keyword glslType mat3x4
syn keyword glslType mat4
syn keyword glslType mat4x2
syn keyword glslType mat4x3
syn keyword glslType mat4x4
syn keyword glslType rayQueryEXT
syn keyword glslType sampler1D
syn keyword glslType sampler1DArray
syn keyword glslType sampler1DArrayShadow
syn keyword glslType sampler1DShadow
syn keyword glslType sampler2D
syn keyword glslType sampler2DArray
syn keyword glslType sampler2DArrayShadow
syn keyword glslType sampler2DMS
syn keyword glslType sampler2DMSArray
syn keyword glslType sampler2DRect
syn keyword glslType sampler2DRectShadow
syn keyword glslType sampler2DShadow
syn keyword glslType sampler3D
syn keyword glslType samplerBuffer
syn keyword glslType samplerCube
syn keyword glslType samplerCubeArray
syn keyword glslType samplerCubeArrayShadow
syn keyword glslType samplerCubeShadow
syn keyword glslType uimage1D
syn keyword glslType uimage1DArray
syn keyword glslType uimage2D
syn keyword glslType uimage2DArray
syn keyword glslType uimage2DMS
syn keyword glslType uimage2DMSArray
syn keyword glslType uimage2DRect
syn keyword glslType uimage3D
syn keyword glslType uimageBuffer
syn keyword glslType uimageCube
syn keyword glslType uimageCubeArray
syn keyword glslType uint
syn keyword glslType usampler1D
syn keyword glslType usampler1DArray
syn keyword glslType usampler2D
syn keyword glslType usampler2DArray
syn keyword glslType usampler2DMS
syn keyword glslType usampler2DMSArray
syn keyword glslType usampler2DRect
syn keyword glslType usampler3D
syn keyword glslType usamplerBuffer
syn keyword glslType usamplerCube
syn keyword glslType usamplerCubeArray
syn keyword glslType uvec2
syn keyword glslType uvec3
syn keyword glslType uvec4
syn keyword glslType vec2
syn keyword glslType vec3
syn keyword glslType vec4
syn keyword glslType void

" Qualifiers
syn keyword glslQualifier align
syn keyword glslQualifier attribute
syn keyword glslQualifier binding
syn keyword glslQualifier buffer
syn keyword glslQualifier callableDataEXT
syn keyword glslQualifier callableDataInEXT
syn keyword glslQualifier ccw
syn keyword glslQualifier centroid
syn keyword glslQualifier centroid varying
syn keyword glslQualifier coherent
syn keyword glslQualifier column_major
syn keyword glslQualifier const
syn keyword glslQualifier cw
syn keyword glslQualifier depth_any
syn keyword glslQualifier depth_greater
syn keyword glslQualifier depth_less
syn keyword glslQualifier depth_unchanged
syn keyword glslQualifier early_fragment_tests
syn keyword glslQualifier equal_spacing
syn keyword glslQualifier flat
syn keyword glslQualifier fractional_even_spacing
syn keyword glslQualifier fractional_odd_spacing
syn keyword glslQualifier highp
syn keyword glslQualifier hitAttributeEXT
syn keyword glslQualifier in
syn keyword glslQualifier index
syn keyword glslQualifier inout
syn keyword glslQualifier invariant
syn keyword glslQualifier invocations
syn keyword glslQualifier isolines
syn keyword glslQualifier layout
syn keyword glslQualifier line_strip
syn keyword glslQualifier lines
syn keyword glslQualifier lines_adjacency
syn keyword glslQualifier local_size_x
syn keyword glslQualifier local_size_y
syn keyword glslQualifier local_size_z
syn keyword glslQualifier location
syn keyword glslQualifier lowp
syn keyword glslQualifier max_vertices
syn keyword glslQualifier mediump
syn keyword glslQualifier nonuniformEXT
syn keyword glslQualifier noperspective
syn keyword glslQualifier offset
syn keyword glslQualifier origin_upper_left
syn keyword glslQualifier out
syn keyword glslQualifier packed
syn keyword glslQualifier patch
syn keyword glslQualifier pixel_center_integer
syn keyword glslQualifier point_mode
syn keyword glslQualifier points
syn keyword glslQualifier precise
syn keyword glslQualifier precision
syn keyword glslQualifier quads
syn keyword glslQualifier r11f_g11f_b10f
syn keyword glslQualifier r16
syn keyword glslQualifier r16_snorm
syn keyword glslQualifier r16f
syn keyword glslQualifier r16i
syn keyword glslQualifier r16ui
syn keyword glslQualifier r32f
syn keyword glslQualifier r32i
syn keyword glslQualifier r32ui
syn keyword glslQualifier r8
syn keyword glslQualifier r8_snorm
syn keyword glslQualifier r8i
syn keyword glslQualifier r8ui
syn keyword glslQualifier rayPayloadEXT
syn keyword glslQualifier rayPayloadInEXT
syn keyword glslQualifier readonly
syn keyword glslQualifier restrict
syn keyword glslQualifier rg16
syn keyword glslQualifier rg16_snorm
syn keyword glslQualifier rg16f
syn keyword glslQualifier rg16i
syn keyword glslQualifier rg16ui
syn keyword glslQualifier rg32f
syn keyword glslQualifier rg32i
syn keyword glslQualifier rg32ui
syn keyword glslQualifier rg8
syn keyword glslQualifier rg8_snorm
syn keyword glslQualifier rg8i
syn keyword glslQualifier rg8ui
syn keyword glslQualifier rgb10_a2
syn keyword glslQualifier rgb10_a2ui
syn keyword glslQualifier rgba16
syn keyword glslQualifier rgba16_snorm
syn keyword glslQualifier rgba16f
syn keyword glslQualifier rgba16i
syn keyword glslQualifier rgba16ui
syn keyword glslQualifier rgba32f
syn keyword glslQualifier rgba32i
syn keyword glslQualifier rgba32ui
syn keyword glslQualifier rgba8
syn keyword glslQualifier rgba8_snorm
syn keyword glslQualifier rgba8i
syn keyword glslQualifier rgba8ui
syn keyword glslQualifier row_major
syn keyword glslQualifier sample
syn keyword glslQualifier shaderRecordEXT
syn keyword glslQualifier shared
syn keyword glslQualifier smooth
syn keyword glslQualifier std140
syn keyword glslQualifier std430
syn keyword glslQualifier stream
syn keyword glslQualifier triangle_strip
syn keyword glslQualifier triangles
syn keyword glslQualifier triangles_adjacency
syn keyword glslQualifier uniform
syn keyword glslQualifier varying
syn keyword glslQualifier vertices
syn keyword glslQualifier volatile
syn keyword glslQualifier writeonly
syn keyword glslQualifier xfb_buffer
syn keyword glslQualifier xfb_offset
syn keyword glslQualifier xfb_stride

" Built-in Constants
syn keyword glslBuiltinConstant gl_CullDistance
syn keyword glslBuiltinConstant gl_HitKindBackFacingTriangleEXT
syn keyword glslBuiltinConstant gl_HitKindFrontFacingTriangleEXT
syn keyword glslBuiltinConstant gl_MaxAtomicCounterBindings
syn keyword glslBuiltinConstant gl_MaxAtomicCounterBufferSize
syn keyword glslBuiltinConstant gl_MaxClipDistances
syn keyword glslBuiltinConstant gl_MaxClipPlanes
syn keyword glslBuiltinConstant gl_MaxCombinedAtomicCounterBuffers
syn keyword glslBuiltinConstant gl_MaxCombinedAtomicCounters
syn keyword glslBuiltinConstant gl_MaxCombinedClipAndCullDistances
syn keyword glslBuiltinConstant gl_MaxCombinedImageUniforms
syn keyword glslBuiltinConstant gl_MaxCombinedImageUnitsAndFragmentOutputs
syn keyword glslBuiltinConstant gl_MaxCombinedShaderOutputResources
syn keyword glslBuiltinConstant gl_MaxCombinedTextureImageUnits
syn keyword glslBuiltinConstant gl_MaxComputeAtomicCounterBuffers
syn keyword glslBuiltinConstant gl_MaxComputeAtomicCounters
syn keyword glslBuiltinConstant gl_MaxComputeImageUniforms
syn keyword glslBuiltinConstant gl_MaxComputeTextureImageUnits
syn keyword glslBuiltinConstant gl_MaxComputeUniformComponents
syn keyword glslBuiltinConstant gl_MaxComputeWorkGroupCount
syn keyword glslBuiltinConstant gl_MaxComputeWorkGroupSize
syn keyword glslBuiltinConstant gl_MaxCullDistances
syn keyword glslBuiltinConstant gl_MaxDrawBuffers
syn keyword glslBuiltinConstant gl_MaxFragmentAtomicCounterBuffers
syn keyword glslBuiltinConstant gl_MaxFragmentAtomicCounters
syn keyword glslBuiltinConstant gl_MaxFragmentImageUniforms
syn keyword glslBuiltinConstant gl_MaxFragmentInputComponents
syn keyword glslBuiltinConstant gl_MaxFragmentInputVectors
syn keyword glslBuiltinConstant gl_MaxFragmentUniformComponents
syn keyword glslBuiltinConstant gl_MaxFragmentUniformVectors
syn keyword glslBuiltinConstant gl_MaxGeometryAtomicCounterBuffers
syn keyword glslBuiltinConstant gl_MaxGeometryAtomicCounters
syn keyword glslBuiltinConstant gl_MaxGeometryImageUniforms
syn keyword glslBuiltinConstant gl_MaxGeometryInputComponents
syn keyword glslBuiltinConstant gl_MaxGeometryOutputComponents
syn keyword glslBuiltinConstant gl_MaxGeometryOutputVertices
syn keyword glslBuiltinConstant gl_MaxGeometryTextureImageUnits
syn keyword glslBuiltinConstant gl_MaxGeometryTotalOutputComponents
syn keyword glslBuiltinConstant gl_MaxGeometryUniformComponents
syn keyword glslBuiltinConstant gl_MaxGeometryVaryingComponents
syn keyword glslBuiltinConstant gl_MaxImageSamples
syn keyword glslBuiltinConstant gl_MaxImageUnits
syn keyword glslBuiltinConstant gl_MaxLights
syn keyword glslBuiltinConstant gl_MaxPatchVertices
syn keyword glslBuiltinConstant gl_MaxProgramTexelOffset
syn keyword glslBuiltinConstant gl_MaxSamples
syn keyword glslBuiltinConstant gl_MaxTessControlAtomicCounterBuffers
syn keyword glslBuiltinConstant gl_MaxTessControlAtomicCounters
syn keyword glslBuiltinConstant gl_MaxTessControlImageUniforms
syn keyword glslBuiltinConstant gl_MaxTessControlInputComponents
syn keyword glslBuiltinConstant gl_MaxTessControlOutputComponents
syn keyword glslBuiltinConstant gl_MaxTessControlTextureImageUnits
syn keyword glslBuiltinConstant gl_MaxTessControlTotalOutputComponents
syn keyword glslBuiltinConstant gl_MaxTessControlUniformComponents
syn keyword glslBuiltinConstant gl_MaxTessEvaluationAtomicCounterBuffers
syn keyword glslBuiltinConstant gl_MaxTessEvaluationAtomicCounters
syn keyword glslBuiltinConstant gl_MaxTessEvaluationImageUniforms
syn keyword glslBuiltinConstant gl_MaxTessEvaluationInputComponents
syn keyword glslBuiltinConstant gl_MaxTessEvaluationOutputComponents
syn keyword glslBuiltinConstant gl_MaxTessEvaluationTextureImageUnits
syn keyword glslBuiltinConstant gl_MaxTessEvaluationUniformComponents
syn keyword glslBuiltinConstant gl_MaxTessGenLevel
syn keyword glslBuiltinConstant gl_MaxTessPatchComponents
syn keyword glslBuiltinConstant gl_MaxTextureCoords
syn keyword glslBuiltinConstant gl_MaxTextureImageUnits
syn keyword glslBuiltinConstant gl_MaxTextureUnits
syn keyword glslBuiltinConstant gl_MaxTransformFeedbackBuffers
syn keyword glslBuiltinConstant gl_MaxTransformFeedbackInterleavedComponents
syn keyword glslBuiltinConstant gl_MaxVaryingComponents
syn keyword glslBuiltinConstant gl_MaxVaryingFloats
syn keyword glslBuiltinConstant gl_MaxVaryingVectors
syn keyword glslBuiltinConstant gl_MaxVertexAtomicCounterBuffers
syn keyword glslBuiltinConstant gl_MaxVertexAtomicCounters
syn keyword glslBuiltinConstant gl_MaxVertexAttribs
syn keyword glslBuiltinConstant gl_MaxVertexImageUniforms
syn keyword glslBuiltinConstant gl_MaxVertexOutputComponents
syn keyword glslBuiltinConstant gl_MaxVertexOutputVectors
syn keyword glslBuiltinConstant gl_MaxVertexTextureImageUnits
syn keyword glslBuiltinConstant gl_MaxVertexUniformComponents
syn keyword glslBuiltinConstant gl_MaxVertexUniformVectors
syn keyword glslBuiltinConstant gl_MaxViewports
syn keyword glslBuiltinConstant gl_MinProgramTexelOffset
syn keyword glslBuiltinConstant gl_RayFlagsCullBackFacingTrianglesEXT
syn keyword glslBuiltinConstant gl_RayFlagsCullFrontFacingTrianglesEXT
syn keyword glslBuiltinConstant gl_RayFlagsCullNoOpaqueEXT
syn keyword glslBuiltinConstant gl_RayFlagsCullOpaqueEXT
syn keyword glslBuiltinConstant gl_RayFlagsNoOpaqueEXT
syn keyword glslBuiltinConstant gl_RayFlagsNoneEXT
syn keyword glslBuiltinConstant gl_RayFlagsOpaqueEXT
syn keyword glslBuiltinConstant gl_RayFlagsSkipClosestHitShaderEXT
syn keyword glslBuiltinConstant gl_RayFlagsTerminateOnFirstHitEXT
syn keyword glslBuiltinConstant gl_RayQueryCandidateIntersectionAABBEXT
syn keyword glslBuiltinConstant gl_RayQueryCandidateIntersectionTriangleEXT
syn keyword glslBuiltinConstant gl_RayQueryCommittedIntersectionGeneratedEXT
syn keyword glslBuiltinConstant gl_RayQueryCommittedIntersectionNoneEXT
syn keyword glslBuiltinConstant gl_RayQueryCommittedIntersectionTriangleEXT

" Built-in Variables
syn keyword glslBuiltinVariable gl_BackColor
syn keyword glslBuiltinVariable gl_BackLightModelProduct
syn keyword glslBuiltinVariable gl_BackLightProduct
syn keyword glslBuiltinVariable gl_BackLightProduct
syn keyword glslBuiltinVariable gl_BackMaterial
syn keyword glslBuiltinVariable gl_BackSecondaryColor
syn keyword glslBuiltinVariable gl_ClipDistance
syn keyword glslBuiltinVariable gl_ClipPlane
syn keyword glslBuiltinVariable gl_ClipVertex
syn keyword glslBuiltinVariable gl_Color
syn keyword glslBuiltinVariable gl_DepthRange
syn keyword glslBuiltinVariable gl_EyePlaneQ
syn keyword glslBuiltinVariable gl_EyePlaneR
syn keyword glslBuiltinVariable gl_EyePlaneS
syn keyword glslBuiltinVariable gl_EyePlaneT
syn keyword glslBuiltinVariable gl_Fog
syn keyword glslBuiltinVariable gl_FogCoord
syn keyword glslBuiltinVariable gl_FogFragCoord
syn keyword glslBuiltinVariable gl_FragColor
syn keyword glslBuiltinVariable gl_FragCoord
syn keyword glslBuiltinVariable gl_FragData
syn keyword glslBuiltinVariable gl_FragDepth
syn keyword glslBuiltinVariable gl_FrontColor
syn keyword glslBuiltinVariable gl_FrontFacing
syn keyword glslBuiltinVariable gl_FrontLightModelProduct
syn keyword glslBuiltinVariable gl_FrontLightProduct
syn keyword glslBuiltinVariable gl_FrontMaterial
syn keyword glslBuiltinVariable gl_FrontSecondaryColor
syn keyword glslBuiltinVariable gl_GeometryIndexEXT
syn keyword glslBuiltinVariable gl_GlobalInvocationID
syn keyword glslBuiltinVariable gl_HelperInvocation
syn keyword glslBuiltinVariable gl_HitKindEXT
syn keyword glslBuiltinVariable gl_HitTEXT
syn keyword glslBuiltinVariable gl_IncomingRayFlagsEXT
syn keyword glslBuiltinVariable gl_InstanceCustomIndexEXT
syn keyword glslBuiltinVariable gl_InstanceID
syn keyword glslBuiltinVariable gl_InstanceID
syn keyword glslBuiltinVariable gl_InvocationID
syn keyword glslBuiltinVariable gl_LaunchIDEXT
syn keyword glslBuiltinVariable gl_LaunchSizeEXT
syn keyword glslBuiltinVariable gl_Layer
syn keyword glslBuiltinVariable gl_LightModel
syn keyword glslBuiltinVariable gl_LightSource
syn keyword glslBuiltinVariable gl_LocalInvocationID
syn keyword glslBuiltinVariable gl_LocalInvocationIndex
syn keyword glslBuiltinVariable gl_ModelViewMatrix
syn keyword glslBuiltinVariable gl_ModelViewMatrixInverse
syn keyword glslBuiltinVariable gl_ModelViewMatrixInverseTranspose
syn keyword glslBuiltinVariable gl_ModelViewMatrixTranspose
syn keyword glslBuiltinVariable gl_ModelViewProjectionMatrix
syn keyword glslBuiltinVariable gl_ModelViewProjectionMatrixInverse
syn keyword glslBuiltinVariable gl_ModelViewProjectionMatrixInverseTranspose
syn keyword glslBuiltinVariable gl_ModelViewProjectionMatrixTranspose
syn keyword glslBuiltinVariable gl_MultiTexCoord0
syn keyword glslBuiltinVariable gl_MultiTexCoord1
syn keyword glslBuiltinVariable gl_MultiTexCoord2
syn keyword glslBuiltinVariable gl_MultiTexCoord3
syn keyword glslBuiltinVariable gl_MultiTexCoord4
syn keyword glslBuiltinVariable gl_MultiTexCoord5
syn keyword glslBuiltinVariable gl_MultiTexCoord6
syn keyword glslBuiltinVariable gl_MultiTexCoord7
syn keyword glslBuiltinVariable gl_Normal
syn keyword glslBuiltinVariable gl_NormalMatrix
syn keyword glslBuiltinVariable gl_NormalScale
syn keyword glslBuiltinVariable gl_NumSamples
syn keyword glslBuiltinVariable gl_NumWorkGroups
syn keyword glslBuiltinVariable gl_ObjectPlaneQ
syn keyword glslBuiltinVariable gl_ObjectPlaneR
syn keyword glslBuiltinVariable gl_ObjectPlaneS
syn keyword glslBuiltinVariable gl_ObjectPlaneT
syn keyword glslBuiltinVariable gl_ObjectRayDirectionEXT
syn keyword glslBuiltinVariable gl_ObjectRayOriginEXT
syn keyword glslBuiltinVariable gl_ObjectToWorld3x4EXT
syn keyword glslBuiltinVariable gl_ObjectToWorldEXT
syn keyword glslBuiltinVariable gl_PatchVerticesIn
syn keyword glslBuiltinVariable gl_Point
syn keyword glslBuiltinVariable gl_PointCoord
syn keyword glslBuiltinVariable gl_PointSize
syn keyword glslBuiltinVariable gl_Position
syn keyword glslBuiltinVariable gl_PrimitiveID
syn keyword glslBuiltinVariable gl_PrimitiveID
syn keyword glslBuiltinVariable gl_PrimitiveIDIn
syn keyword glslBuiltinVariable gl_ProjectionMatrix
syn keyword glslBuiltinVariable gl_ProjectionMatrixInverse
syn keyword glslBuiltinVariable gl_ProjectionMatrixInverseTranspose
syn keyword glslBuiltinVariable gl_ProjectionMatrixTranspose
syn keyword glslBuiltinVariable gl_RayTmaxEXT
syn keyword glslBuiltinVariable gl_RayTminEXT
syn keyword glslBuiltinVariable gl_SampleID
syn keyword glslBuiltinVariable gl_SampleMask
syn keyword glslBuiltinVariable gl_SampleMaskIn
syn keyword glslBuiltinVariable gl_SamplePosition
syn keyword glslBuiltinVariable gl_SecondaryColor
syn keyword glslBuiltinVariable gl_TessCoord
syn keyword glslBuiltinVariable gl_TessLevelInner
syn keyword glslBuiltinVariable gl_TessLevelOuter
syn keyword glslBuiltinVariable gl_TexCoord
syn keyword glslBuiltinVariable gl_TextureEnvColor
syn keyword glslBuiltinVariable gl_TextureMatrix
syn keyword glslBuiltinVariable gl_TextureMatrixInverse
syn keyword glslBuiltinVariable gl_TextureMatrixInverseTranspose
syn keyword glslBuiltinVariable gl_TextureMatrixTranspose
syn keyword glslBuiltinVariable gl_Vertex
syn keyword glslBuiltinVariable gl_VertexID
syn keyword glslBuiltinVariable gl_VertexIndex
syn keyword glslBuiltinVariable gl_ViewportIndex
syn keyword glslBuiltinVariable gl_WorkGroupID
syn keyword glslBuiltinVariable gl_WorkGroupSize
syn keyword glslBuiltinVariable gl_WorldRayDirectionEXT
syn keyword glslBuiltinVariable gl_WorldRayOriginEXT
syn keyword glslBuiltinVariable gl_WorldToObject3x4EXT
syn keyword glslBuiltinVariable gl_WorldToObjectEXT
syn keyword glslBuiltinVariable gl_in
syn keyword glslBuiltinVariable gl_out

" Built-in Functions
syn keyword glslBuiltinFunction EmitStreamVertex
syn keyword glslBuiltinFunction EmitVertex
syn keyword glslBuiltinFunction EndPrimitive
syn keyword glslBuiltinFunction EndStreamPrimitive
syn keyword glslBuiltinFunction abs
syn keyword glslBuiltinFunction acos
syn keyword glslBuiltinFunction acosh
syn keyword glslBuiltinFunction all
syn keyword glslBuiltinFunction any
syn keyword glslBuiltinFunction asin
syn keyword glslBuiltinFunction asinh
syn keyword glslBuiltinFunction atan
syn keyword glslBuiltinFunction atanh
syn keyword glslBuiltinFunction atomicAdd
syn keyword glslBuiltinFunction atomicAnd
syn keyword glslBuiltinFunction atomicCompSwap
syn keyword glslBuiltinFunction atomicCounter
syn keyword glslBuiltinFunction atomicCounterDecrement
syn keyword glslBuiltinFunction atomicCounterIncrement
syn keyword glslBuiltinFunction atomicExchange
syn keyword glslBuiltinFunction atomicMax
syn keyword glslBuiltinFunction atomicMin
syn keyword glslBuiltinFunction atomicOr
syn keyword glslBuiltinFunction atomicXor
syn keyword glslBuiltinFunction barrier
syn keyword glslBuiltinFunction bitCount
syn keyword glslBuiltinFunction bitfieldExtract
syn keyword glslBuiltinFunction bitfieldInsert
syn keyword glslBuiltinFunction bitfieldReverse
syn keyword glslBuiltinFunction ceil
syn keyword glslBuiltinFunction clamp
syn keyword glslBuiltinFunction cos
syn keyword glslBuiltinFunction cosh
syn keyword glslBuiltinFunction cross
syn keyword glslBuiltinFunction dFdx
syn keyword glslBuiltinFunction dFdxCoarse
syn keyword glslBuiltinFunction dFdxFine
syn keyword glslBuiltinFunction dFdy
syn keyword glslBuiltinFunction dFdyCoarse
syn keyword glslBuiltinFunction dFdyFine
syn keyword glslBuiltinFunction degrees
syn keyword glslBuiltinFunction determinant
syn keyword glslBuiltinFunction distance
syn keyword glslBuiltinFunction dot
syn keyword glslBuiltinFunction equal
syn keyword glslBuiltinFunction executeCallableEXT
syn keyword glslBuiltinFunction exp
syn keyword glslBuiltinFunction exp2
syn keyword glslBuiltinFunction faceforward
syn keyword glslBuiltinFunction findLSB
syn keyword glslBuiltinFunction findMSB
syn keyword glslBuiltinFunction floatBitsToInt
syn keyword glslBuiltinFunction floatBitsToUint
syn keyword glslBuiltinFunction floor
syn keyword glslBuiltinFunction fma
syn keyword glslBuiltinFunction fract
syn keyword glslBuiltinFunction frexp
syn keyword glslBuiltinFunction ftransform
syn keyword glslBuiltinFunction fwidth
syn keyword glslBuiltinFunction fwidthCoarse
syn keyword glslBuiltinFunction fwidthFine
syn keyword glslBuiltinFunction greaterThan
syn keyword glslBuiltinFunction greaterThanEqual
syn keyword glslBuiltinFunction groupMemoryBarrier
syn keyword glslBuiltinFunction ignoreIntersectionEXT
syn keyword glslBuiltinFunction imageAtomicAdd
syn keyword glslBuiltinFunction imageAtomicAnd
syn keyword glslBuiltinFunction imageAtomicCompSwap
syn keyword glslBuiltinFunction imageAtomicExchange
syn keyword glslBuiltinFunction imageAtomicMax
syn keyword glslBuiltinFunction imageAtomicMin
syn keyword glslBuiltinFunction imageAtomicOr
syn keyword glslBuiltinFunction imageAtomicXor
syn keyword glslBuiltinFunction imageLoad
syn keyword glslBuiltinFunction imageSize
syn keyword glslBuiltinFunction imageStore
syn keyword glslBuiltinFunction imulExtended
syn keyword glslBuiltinFunction intBitsToFloat
syn keyword glslBuiltinFunction interpolateAtCentroid
syn keyword glslBuiltinFunction interpolateAtOffset
syn keyword glslBuiltinFunction interpolateAtSample
syn keyword glslBuiltinFunction inverse
syn keyword glslBuiltinFunction inversesqrt
syn keyword glslBuiltinFunction isinf
syn keyword glslBuiltinFunction isnan
syn keyword glslBuiltinFunction ldexp
syn keyword glslBuiltinFunction length
syn keyword glslBuiltinFunction lessThan
syn keyword glslBuiltinFunction lessThanEqual
syn keyword glslBuiltinFunction log
syn keyword glslBuiltinFunction log2
syn keyword glslBuiltinFunction matrixCompMult
syn keyword glslBuiltinFunction max
syn keyword glslBuiltinFunction memoryBarrier
syn keyword glslBuiltinFunction memoryBarrierAtomicCounter
syn keyword glslBuiltinFunction memoryBarrierBuffer
syn keyword glslBuiltinFunction memoryBarrierImage
syn keyword glslBuiltinFunction memoryBarrierShared
syn keyword glslBuiltinFunction min
syn keyword glslBuiltinFunction mix
syn keyword glslBuiltinFunction mod
syn keyword glslBuiltinFunction modf
syn keyword glslBuiltinFunction noise1
syn keyword glslBuiltinFunction noise2
syn keyword glslBuiltinFunction noise3
syn keyword glslBuiltinFunction noise4
syn keyword glslBuiltinFunction normalize
syn keyword glslBuiltinFunction not
syn keyword glslBuiltinFunction notEqual
syn keyword glslBuiltinFunction outerProduct
syn keyword glslBuiltinFunction packDouble2x32
syn keyword glslBuiltinFunction packHalf2x16
syn keyword glslBuiltinFunction packSnorm2x16
syn keyword glslBuiltinFunction packSnorm4x8
syn keyword glslBuiltinFunction packUnorm2x16
syn keyword glslBuiltinFunction packUnorm4x8
syn keyword glslBuiltinFunction pow
syn keyword glslBuiltinFunction radians
syn keyword glslBuiltinFunction rayQueryConfirmIntersectionEXT
syn keyword glslBuiltinFunction rayQueryGenerateIntersectionEXT
syn keyword glslBuiltinFunction rayQueryGetIntersectionBarycentricsEXT
syn keyword glslBuiltinFunction rayQueryGetIntersectionCandidateAABBOpaqueEXT
syn keyword glslBuiltinFunction rayQueryGetIntersectionFrontFaceEXT
syn keyword glslBuiltinFunction rayQueryGetIntersectionGeometryIndexEXT
syn keyword glslBuiltinFunction rayQueryGetIntersectionInstanceCustomIndexEXT
syn keyword glslBuiltinFunction rayQueryGetIntersectionInstanceIdEXT
syn keyword glslBuiltinFunction rayQueryGetIntersectionInstanceShaderBindingTableRecordOffsetEXT
syn keyword glslBuiltinFunction rayQueryGetIntersectionObjectRayDirectionEXT
syn keyword glslBuiltinFunction rayQueryGetIntersectionObjectRayOriginEXT
syn keyword glslBuiltinFunction rayQueryGetIntersectionObjectToWorldEXT
syn keyword glslBuiltinFunction rayQueryGetIntersectionPrimitiveIndexEXT
syn keyword glslBuiltinFunction rayQueryGetIntersectionTEXT
syn keyword glslBuiltinFunction rayQueryGetIntersectionTypeEXT
syn keyword glslBuiltinFunction rayQueryGetIntersectionWorldToObjectEXT
syn keyword glslBuiltinFunction rayQueryGetRayFlagsEXT
syn keyword glslBuiltinFunction rayQueryGetRayTMinEXT
syn keyword glslBuiltinFunction rayQueryGetWorldRayDirectionEXT
syn keyword glslBuiltinFunction rayQueryGetWorldRayOriginEXT
syn keyword glslBuiltinFunction rayQueryInitializeEXT
syn keyword glslBuiltinFunction rayQueryProceedEXT
syn keyword glslBuiltinFunction rayQueryTerminateEXT
syn keyword glslBuiltinFunction reflect
syn keyword glslBuiltinFunction refract
syn keyword glslBuiltinFunction reportIntersectionEXT
syn keyword glslBuiltinFunction round
syn keyword glslBuiltinFunction roundEven
syn keyword glslBuiltinFunction shadow1D
syn keyword glslBuiltinFunction shadow1DLod
syn keyword glslBuiltinFunction shadow1DProj
syn keyword glslBuiltinFunction shadow1DProjLod
syn keyword glslBuiltinFunction shadow2D
syn keyword glslBuiltinFunction shadow2DLod
syn keyword glslBuiltinFunction shadow2DProj
syn keyword glslBuiltinFunction shadow2DProjLod
syn keyword glslBuiltinFunction sign
syn keyword glslBuiltinFunction sin
syn keyword glslBuiltinFunction sinh
syn keyword glslBuiltinFunction smoothstep
syn keyword glslBuiltinFunction sqrt
syn keyword glslBuiltinFunction step
syn keyword glslBuiltinFunction tan
syn keyword glslBuiltinFunction tanh
syn keyword glslBuiltinFunction terminateRayEXT
syn keyword glslBuiltinFunction texelFetch
syn keyword glslBuiltinFunction texelFetchOffset
syn keyword glslBuiltinFunction texture
syn keyword glslBuiltinFunction texture1D
syn keyword glslBuiltinFunction texture1DLod
syn keyword glslBuiltinFunction texture1DProj
syn keyword glslBuiltinFunction texture1DProjLod
syn keyword glslBuiltinFunction texture2D
syn keyword glslBuiltinFunction texture2DLod
syn keyword glslBuiltinFunction texture2DProj
syn keyword glslBuiltinFunction texture2DProjLod
syn keyword glslBuiltinFunction texture3D
syn keyword glslBuiltinFunction texture3DLod
syn keyword glslBuiltinFunction texture3DProj
syn keyword glslBuiltinFunction texture3DProjLod
syn keyword glslBuiltinFunction textureCube
syn keyword glslBuiltinFunction textureCubeLod
syn keyword glslBuiltinFunction textureGather
syn keyword glslBuiltinFunction textureGatherOffset
syn keyword glslBuiltinFunction textureGatherOffsets
syn keyword glslBuiltinFunction textureGrad
syn keyword glslBuiltinFunction textureGradOffset
syn keyword glslBuiltinFunction textureLod
syn keyword glslBuiltinFunction textureLodOffset
syn keyword glslBuiltinFunction textureOffset
syn keyword glslBuiltinFunction textureProj
syn keyword glslBuiltinFunction textureProjGrad
syn keyword glslBuiltinFunction textureProjGradOffset
syn keyword glslBuiltinFunction textureProjLod
syn keyword glslBuiltinFunction textureProjLodOffset
syn keyword glslBuiltinFunction textureProjOffset
syn keyword glslBuiltinFunction textureQueryLevels
syn keyword glslBuiltinFunction textureQueryLod
syn keyword glslBuiltinFunction textureSize
syn keyword glslBuiltinFunction traceRayEXT
syn keyword glslBuiltinFunction transpose
syn keyword glslBuiltinFunction trunc
syn keyword glslBuiltinFunction uaddCarry
syn keyword glslBuiltinFunction uintBitsToFloat
syn keyword glslBuiltinFunction umulExtended
syn keyword glslBuiltinFunction unpackDouble2x32
syn keyword glslBuiltinFunction unpackHalf2x16
syn keyword glslBuiltinFunction unpackSnorm2x16
syn keyword glslBuiltinFunction unpackSnorm4x8
syn keyword glslBuiltinFunction unpackUnorm2x16
syn keyword glslBuiltinFunction unpackUnorm4x8
syn keyword glslBuiltinFunction usubBorrow

hi def link glslConditional     Conditional
hi def link glslRepeat          Repeat
hi def link glslStatement       Statement
hi def link glslTodo            Todo
hi def link glslCommentL        glslComment
hi def link glslCommentStart    glslComment
hi def link glslComment         Comment
hi def link glslPreCondit       PreCondit
hi def link glslDefine          Define
hi def link glslTokenConcat     glslPreProc
hi def link glslPredefinedMacro Macro
hi def link glslPreProc         PreProc
hi def link glslInclude         Include
hi def link glslBoolean         Boolean
hi def link glslDecimalInt      glslInteger
hi def link glslOctalInt        glslInteger
hi def link glslHexInt          glslInteger
hi def link glslInteger         Number
hi def link glslFloat           Float
hi def link glslIdentifierPrime glslIdentifier
hi def link glslIdentifier      Identifier
hi def link glslStructure       Structure
hi def link glslType            Type
hi def link glslQualifier       StorageClass
hi def link glslBuiltinConstant Constant
hi def link glslBuiltinFunction Function
hi def link glslBuiltinVariable Identifier
hi def link glslSwizzle         Identifier

let b:current_syntax = 'glsl'
