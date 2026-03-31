" Vim syntax file
" Language:     Slang
" Maintainer:	Austin Shijo <epestr@proton.me>
" Last Change:	2024 Jan 05

if exists("b:current_syntax")
  finish
endif

" Read the C syntax to start with
runtime! syntax/c.vim
unlet b:current_syntax

" Annotations
syn match           shaderslangAnnotation          /<.*;>/

" Attributes
syn match           shaderslangAttribute           /^\s*\[maxvertexcount(\s*\w\+\s*)\]/
syn match           shaderslangAttribute           /^\s*\[domain(\s*"\(tri\|quad\|isoline\)"\s*)\]/
syn match           shaderslangAttribute           /^\s*\[earlydepthstencil\]/
syn match           shaderslangAttribute           /^\s*\[instance(\s*\w\+\s*)\]/
syn match           shaderslangAttribute           /^\s*\[maxtessfactor(\s*\w\+\s*)\]/
syn match           shaderslangAttribute           /^\s*\[numthreads(\s*\w\+\s*,\s*\w\+\s*,\s*\w\+\s*)\]/
syn match           shaderslangAttribute           /^\s*\[outputcontrolpoints(\s*\w\+\s*)\]/
syn match           shaderslangAttribute           /^\s*\[outputtopology(\s*"\(point\|line\|triangle_cw\|triangle_ccw\|triangle\)"\s*)\]/
syn match           shaderslangAttribute           /^\s*\[partitioning(\s*"\(integer\|fractional_even\|fractional_odd\|pow2\)"\s*)\]/
syn match           shaderslangAttribute           /^\s*\[patchconstantfunc(\s*"\(\d\|\w\|_\)\+"\s*)\]/
syn match           shaderslangAttribute           /^\s*\[WaveSize(\s*\w\+\(\s*,\s*\w\+\(\s*,\s*\w\+\)\?\)\?\s*)\]/
syn match           shaderslangAttribute           /^\s*\[shader(\s*"\(anyhit\|callable\|closesthit\|intersection\|miss\|raygeneration\)"\s*)\]/

syn match           shaderslangAttribute           /^\s*\[fastopt\]/
syn match           shaderslangAttribute           /^\s*\[loop\]/
syn match           shaderslangAttribute           /^\s*\[unroll\]/
syn match           shaderslangAttribute           /^\s*\[allow_uav_condition\]/
syn match           shaderslangAttribute           /^\s*\[branch\]/
syn match           shaderslangAttribute           /^\s*\[flatten\]/
syn match           shaderslangAttribute           /^\s*\[forcecase\]/
syn match           shaderslangAttribute           /^\s*\[call\]/
syn match           shaderslangAttribute           /^\s*\[WaveOpsIncludeHelperLanes\]/

syn match           shaderslangAttribute           /\[raypayload\]/

" Work graph shader target attributes
syn match           shaderslangAttribute           /^\s*\[Shader(\s*"\(\d\|\w\|_\)\+"\s*)\]/

" Work graph shader function attributes
syn match           shaderslangAttribute           /^\s*\[NodeLaunch(\s*"\(broadcasting\|coalescing\|thread\)"\s*)\]/
syn match           shaderslangAttribute           /^\s*\[NodeIsProgramEntry\]/
syn match           shaderslangAttribute           /^\s*\[NodeLocalRootArgumentsTableIndex(\s*\w\+\s*)\]/
syn match           shaderslangAttribute           /^\s*\[NumThreads(\s*\w\+\s*,\s*\w\+\s*,\s*\w\+\s*)\]/
syn match           shaderslangAttribute           /^\s*\[NodeShareInputOf(\s*"\w\+"\(\s*,\s*\w\+\)\?\s*)\]/
syn match           shaderslangAttribute           /^\s*\[NodeDispatchGrid(\s*\w\+\s*,\s*\w\+\s*,\s*\w\+\s*)\]/
syn match           shaderslangAttribute           /^\s*\[NodeMaxDispatchGrid(\s*\w\+\s*,\s*\w\+\s*,\s*\w\+\s*)\]/
syn match           shaderslangAttribute           /^\s*\[NodeMaxRecursionDepth(\s*\w\+\s*)\]/
syn match           shaderslangAttribute           /^\s*\[NodeMaxInputRecordsPerGraphEntryRecord(\s*\w\+\s*,\s*\(true\|false\)\s*)\]/

" Work graph record attributes
syn match           shaderslangAttribute           /\[NodeTrackRWInputSharing\]/
syn match           shaderslangAttribute           /\[MaxRecords(\s*\w\+\s*)\]/
syn match           shaderslangAttribute           /\[NodeID(\s*"\w\+"\(\s*,\s*\w\+\)\?\s*)\]/
syn match           shaderslangAttribute           /\[MaxRecordsSharedWith(\s*\w\+\s*)\]/
syn match           shaderslangAttribute           /\[AllowSparseNodes\]/
syn match           shaderslangAttribute           /\[NodeArraySize(\s*\w\+\s*)\]/
syn match           shaderslangAttribute           /\[UnboundedSparseNodes\]/

" Intrinsic functions
syn keyword         shaderslangFunc                abs acos acosh asin asinh atan atanh cos cosh exp exp2 floor log log10 log2 round rsqrt sin sincos sinh sqrt tan tanh trunc
syn keyword         shaderslangFunc                AllMemoryBarrier AllMemoryBarrierWithGroupSync DeviceMemoryBarrier DeviceMemoryBarrierWithGroupSync GroupMemoryBarrier GroupMemoryBarrierWithGroupSync
syn keyword         shaderslangFunc                abort clip errorf printf
syn keyword         shaderslangFunc                all any countbits faceforward firstbithigh firstbitlow isfinite isinf isnan max min noise pow reversebits sign
syn keyword         shaderslangFunc                asdouble asfloat asint asuint D3DCOLORtoUBYTE4 f16tof32 f32tof16
syn keyword         shaderslangFunc                ceil clamp degrees fma fmod frac frexp ldexp lerp mad modf radiants saturate smoothstep step
syn keyword         shaderslangFunc                cross determinant distance dot dst length lit msad4 mul normalize rcp reflect refract transpose
syn keyword         shaderslangFunc                ddx ddx_coarse ddx_fine ddy ddy_coarse ddy_fine fwidth
syn keyword         shaderslangFunc                EvaluateAttributeAtCentroid EvaluateAttributeAtSample EvaluateAttributeSnapped
syn keyword         shaderslangFunc                GetRenderTargetSampleCount GetRenderTargetSamplePosition
syn keyword         shaderslangFunc                InterlockedAdd InterlockedAnd InterlockedCompareExchange InterlockedCompareStore InterlockedExchange InterlockedMax InterlockedMin InterlockedOr InterlockedXor
syn keyword         shaderslangFunc                InterlockedCompareStoreFloatBitwise InterlockedCompareExchangeFloatBitwise
syn keyword         shaderslangFunc                Process2DQuadTessFactorsAvg Process2DQuadTessFactorsMax Process2DQuadTessFactorsMin ProcessIsolineTessFactors
syn keyword         shaderslangFunc                ProcessQuadTessFactorsAvg ProcessQuadTessFactorsMax ProcessQuadTessFactorsMin ProcessTriTessFactorsAvg ProcessTriTessFactorsMax ProcessTriTessFactorsMin
syn keyword         shaderslangFunc                tex1D tex1Dbias tex1Dgrad tex1Dlod tex1Dproj
syn keyword         shaderslangFunc                tex2D tex2Dbias tex2Dgrad tex2Dlod tex2Dproj
syn keyword         shaderslangFunc                tex3D tex3Dbias tex3Dgrad tex3Dlod tex3Dproj
syn keyword         shaderslangFunc                texCUBE texCUBEbias texCUBEgrad texCUBElod texCUBEproj
syn keyword         shaderslangFunc                WaveIsFirstLane WaveGetLaneCount WaveGetLaneIndex
syn keyword         shaderslangFunc                IsHelperLane
syn keyword         shaderslangFunc                WaveActiveAnyTrue WaveActiveAllTrue WaveActiveBallot
syn keyword         shaderslangFunc                WaveReadLaneFirst WaveReadLaneAt
syn keyword         shaderslangFunc                WaveActiveAllEqual WaveActiveAllEqualBool WaveActiveCountBits
syn keyword         shaderslangFunc                WaveActiveSum WaveActiveProduct WaveActiveBitAnd WaveActiveBitOr WaveActiveBitXor WaveActiveMin WaveActiveMax
syn keyword         shaderslangFunc                WavePrefixCountBits WavePrefixProduct WavePrefixSum
syn keyword         shaderslangFunc                QuadReadAcrossX QuadReadAcrossY QuadReadAcrossDiagonal QuadReadLaneAt
syn keyword         shaderslangFunc                QuadAny QuadAll
syn keyword         shaderslangFunc                WaveMatch WaveMultiPrefixSum WaveMultiPrefixProduct WaveMultiPrefixCountBits WaveMultiPrefixAnd WaveMultiPrefixOr WaveMultiPrefixXor
syn keyword         shaderslangFunc                NonUniformResourceIndex
syn keyword         shaderslangFunc                DispatchMesh SetMeshOutputCounts
syn keyword         shaderslangFunc                dot4add_u8packed dot4add_i8packed dot2add

syn keyword         shaderslangFunc                RestartStrip
syn keyword         shaderslangFunc                CalculateLevelOfDetail CalculateLevelOfDetailUnclamped Gather GetDimensions GetSamplePosition Load Sample SampleBias SampleCmp SampleCmpLevelZero SampleGrad SampleLevel GatherRaw SampleCmpLevel
syn keyword         shaderslangFunc                SampleCmpBias SampleCmpGrad
syn keyword         shaderslangFunc                WriteSamplerFeedback WriteSamplerFeedbackBias WriteSamplerFeedbackGrad WriteSamplerFeedbackLevel
syn keyword         shaderslangFunc                Append Consume DecrementCounter IncrementCounter
syn keyword         shaderslangFunc                Load2 Load3 Load4 Store Store2 Store3 Store4
syn keyword         shaderslangFunc                GatherRed GatherGreen GatherBlue GatherAlpha GatherCmp GatherCmpRed GatherCmpGreen GatherCmpBlue GatherCmpAlpha
syn match           shaderslangFunc                /\.mips\[\d\+\]\[\d\+\]/
syn match           shaderslangFunc                /\.sample\[\d\+\]\[\d\+\]/

" Ray intrinsics
syn keyword         shaderslangFunc                AcceptHitAndEndSearch CallShader IgnoreHit ReportHit TraceRay
syn keyword         shaderslangFunc                DispatchRaysIndex DispatchRaysDimensions
syn keyword         shaderslangFunc                WorldRayOrigin WorldRayDirection RayTMin RayTCurrent RayFlags
syn keyword         shaderslangFunc                InstanceIndex InstanceID GeometryIndex PrimitiveIndex ObjectRayOrigin ObjectRayDirection ObjectToWorld3x4 ObjectToWorld4x3 WorldToObject3x4 WorldToObject4x3
syn keyword         shaderslangFunc                HitKind

" RayQuery intrinsics
syn keyword         shaderslangFunc                TraceRayInline Proceed Abort CommittedStatus
syn keyword         shaderslangFunc                CandidateType CandidateProceduralPrimitiveNonOpaque CandidateTriangleRayT CandidateInstanceIndex CandidateInstanceID CandidateInstanceContributionToHitGroupIndex CandidateGeometryIndex
syn keyword         shaderslangFunc                CandidatePrimitiveIndex CandidateObjectRayOrigin CandidateObjectRayDirection CandidateObjectToWorld3x4 CandidateObjectToWorld4x3 CandidateWorldToObject3x4 CandidateWorldToObject4x3
syn keyword         shaderslangFunc                CommitNonOpaqueTriangleHit CommitProceduralPrimitiveHit CommittedStatus CommittedRayT CommittedInstanceIndex CommittedInstanceID CommittedInstanceContributionToHitGroupIndex
syn keyword         shaderslangFunc                CommittedGeometryIndex CommittedPrimitiveIndex CommittedObjectRayOrigin CommittedObjectRayDirection CommittedObjectToWorld3x4 CommittedObjectToWorld4x3 CommittedWorldToObject3x4
syn keyword         shaderslangFunc                CommittedWorldToObject4x3 CandidateTriangleBarycentrics CandidateTriangleFrontFace CommittedTriangleBarycentrics CommittedTriangleFrontFace

" Pack/unpack math intrinsics
syn keyword         shaderslangFunc                unpack_s8s16 unpack_u8u16 unpack_s8s32 unpack_u8u32
syn keyword         shaderslangFunc                pack_u8 pack_s8 pack_clamp_u8 pack_clamp_s8

" Work graph object methods
syn keyword         shaderslangFunc                Get FinishedCrossGroupSharing Count GetThreadNodeOutputRecords GetGroupNodeOutputRecords IsValid GroupIncrementOutputCount ThreadIncrementOutputCount OutputComplete

" Work graph free intrinsics
syn keyword         shaderslangFunc                GetRemainingRecursionLevels Barrier

" Layout Qualifiers
syn keyword         shaderslangLayoutQual          const row_major column_major
syn keyword         shaderslangLayoutQual          point line triangle lineadj triangleadj
syn keyword         shaderslangLayoutQual          InputPatch OutputPatch
syn match           shaderslangLayoutQual          /PointStream<\s*\w\+\s*>/
syn match           shaderslangLayoutQual          /LineStream<\s*\w\+\s*>/
syn match           shaderslangLayoutQual          /TriangleStream<\s*\w\+\s*>/

" User defined Semantics
syn match           shaderslangSemantic            /:\s*[A-Z]\w*/
syn match           shaderslangSemantic            /:\s*packoffset(\s*c\d\+\(\.[xyzw]\)\?\s*)/ " packoffset
syn match           shaderslangSemantic            /:\s*register(\s*\(r\|x\|v\|t\|s\|cb\|icb\|b\|c\|u\)\d\+\s*)/ " register
syn match           shaderslangSemantic            /:\s*read(\s*\(\(anyhit\|closesthit\|miss\|caller\)\s*,\s*\)*\(anyhit\|closesthit\|miss\|caller\)\?\s*)/ " read
syn match           shaderslangSemantic            /:\s*write(\s*\(\(anyhit\|closesthit\|miss\|caller\)\s*,\s*\)*\(anyhit\|closesthit\|miss\|caller\)\?\s*)/ " write

" System-Value Semantics
" Vertex Shader
syn match           shaderslangSemantic            /SV_ClipDistance\d\+/
syn match           shaderslangSemantic            /SV_CullDistance\d\+/
syn keyword         shaderslangSemantic            SV_Position SV_InstanceID SV_PrimitiveID SV_VertexID
syn keyword         shaderslangSemantic            SV_StartVertexLocation SV_StartInstanceLocation
" Tessellation pipeline
syn keyword         shaderslangSemantic            SV_DomainLocation SV_InsideTessFactor SV_OutputControlPointID SV_TessFactor
" Geometry Shader
syn keyword         shaderslangSemantic            SV_GSInstanceID SV_RenderTargetArrayIndex
" Pixel Shader - MSAA
syn keyword         shaderslangSemantic            SV_Coverage SV_Depth SV_IsFrontFace SV_SampleIndex
syn match           shaderslangSemantic            /SV_Target[0-7]/
syn keyword         shaderslangSemantic            SV_ShadingRate SV_ViewID
syn match           shaderslangSemantic            /SV_Barycentrics[0-1]/
" Compute Shader
syn keyword         shaderslangSemantic            SV_DispatchThreadID SV_GroupID SV_GroupIndex SV_GroupThreadID
" Mesh shading pipeline
syn keyword         shaderslangSemantic            SV_CullPrimitive
" Work graph record system values
syn keyword         shaderslangSemantic            SV_DispatchGrid

" slang structures
syn keyword         shaderslangStructure           cbuffer

" Shader profiles
" Cg profiles
syn keyword         shaderslangProfile             arbfp1 arbvp1 fp20 vp20 fp30 vp30 ps_1_1 ps_1_2 ps_1_3
" Shader Model 1
syn keyword         shaderslangProfile             vs_1_1
" Shader Model 2
syn keyword         shaderslangProfile             ps_2_0 ps_2_x vs_2_0 vs_2_x
" Shader Model 3
syn keyword         shaderslangProfile             ps_3_0 vs_3_0
" Shader Model 4
syn keyword         shaderslangProfile             gs_4_0 ps_4_0 vs_4_0 gs_4_1 ps_4_1 vs_4_1
" Shader Model 5
syn keyword         shaderslangProfile             cs_4_0 cs_4_1 cs_5_0 ds_5_0 gs_5_0 hs_5_0 ps_5_0 vs_5_0
" Shader Model 6
syn keyword         shaderslangProfile             cs_6_0 ds_6_0 gs_6_0 hs_6_0 ps_6_0 vs_6_0 lib_6_0

" Swizzling
syn match           shaderslangSwizzle             /\.[xyzw]\{1,4\}\>/
syn match           shaderslangSwizzle             /\.[rgba]\{1,4\}\>/
syn match           shaderslangSwizzle             /\.\(_m[0-3]\{2}\)\{1,4\}/
syn match           shaderslangSwizzle             /\.\(_[1-4]\{2}\)\{1,4\}/

" Other Statements
syn keyword         shaderslangStatement           discard

" Storage class
syn match           shaderslangStorageClass        /\<in\(\s+pipeline\)\?\>/
syn match           shaderslangStorageClass        /\<out\(\s\+indices\|\s\+vertices\|\s\+primitives\)\?\>/
syn keyword         shaderslangStorageClass        inout
syn keyword         shaderslangStorageClass        extern nointerpolation precise shared groupshared static uniform volatile
syn keyword         shaderslangStorageClass        snorm unorm
syn keyword         shaderslangStorageClass        linear centroid nointerpolation noperspective sample
syn keyword         shaderslangStorageClass        globallycoherent

" Types
" Buffer types
syn keyword         shaderslangType                ConstantBuffer Buffer ByteAddressBuffer ConsumeStructuredBuffer StructuredBuffer
syn keyword         shaderslangType                AppendStructuredBuffer RWBuffer RWByteAddressBuffer RWStructuredBuffer
syn keyword         shaderslangType                RasterizerOrderedBuffer RasterizerOrderedByteAddressBuffer RasterizerOrderedStructuredBuffer

" Scalar types
syn keyword         shaderslangType                bool int uint dword half float double
syn keyword         shaderslangType                min16float min10float min16int min12int min16uint
syn keyword         shaderslangType                float16_t float32_t float64_t

" Vector types
syn match           shaderslangType                /vector<\s*\w\+,\s*[1-4]\s*>/
syn keyword         shaderslangType                bool1 bool2 bool3 bool4
syn keyword         shaderslangType                int1 int2 int3 int4
syn keyword         shaderslangType                uint1 uint2 uint3 uint4
syn keyword         shaderslangType                dword1 dword2 dword3 dword4
syn keyword         shaderslangType                half1 half2 half3 half4
syn keyword         shaderslangType                float1 float2 float3 float4
syn keyword         shaderslangType                double1 double2 double3 double4
syn keyword         shaderslangType                min16float1 min16float2 min16float3 min16float4
syn keyword         shaderslangType                min10float1 min10float2 min10float3 min10float4
syn keyword         shaderslangType                min16int1 min16int2 min16int3 min16int4
syn keyword         shaderslangType                min12int1 min12int2 min12int3 min12int4
syn keyword         shaderslangType                min16uint1 min16uint2 min16uint3 min16uint4
syn keyword         shaderslangType                float16_t1 float16_t2 float16_t3 float16_t4
syn keyword         shaderslangType                float32_t1 float32_t2 float32_t3 float32_t4
syn keyword         shaderslangType                float64_t1 float64_t2 float64_t3 float64_t4
syn keyword         shaderslangType                int16_t1 int16_t2 int16_t3 int16_t4
syn keyword         shaderslangType                int32_t1 int32_t2 int32_t3 int32_t4
syn keyword         shaderslangType                int64_t1 int64_t2 int64_t3 int64_t4
syn keyword         shaderslangType                uint16_t1 uint16_t2 uint16_t3 uint16_t4
syn keyword         shaderslangType                uint32_t1 uint32_t2 uint32_t3 uint32_t4
syn keyword         shaderslangType                uint64_t1 uint64_t2 uint64_t3 uint64_t4

" Packed types
syn keyword         shaderslangType                uint8_t4_packed int8_t4_packed

" Matrix types
syn match           shaderslangType                /matrix<\s*\w\+\s*,\s*[1-4]\s*,\s*[1-4]\s*>/
syn keyword         shaderslangType                bool1x1 bool2x1 bool3x1 bool4x1 bool1x2 bool2x2 bool3x2 bool4x2 bool1x3 bool2x3 bool3x3 bool4x3 bool1x4 bool2x4 bool3x4 bool4x4
syn keyword         shaderslangType                int1x1 int2x1 int3x1 int4x1 int1x2 int2x2 int3x2 int4x2 int1x3 int2x3 int3x3 int4x3 int1x4 int2x4 int3x4 int4x4
syn keyword         shaderslangType                uint1x1 uint2x1 uint3x1 uint4x1 uint1x2 uint2x2 uint3x2 uint4x2 uint1x3 uint2x3 uint3x3 uint4x3 uint1x4 uint2x4 uint3x4 uint4x4
syn keyword         shaderslangType                dword1x1 dword2x1 dword3x1 dword4x1 dword1x2 dword2x2 dword3x2 dword4x2 dword1x3 dword2x3 dword3x3 dword4x3 dword1x4 dword2x4 dword3x4 dword4x4
syn keyword         shaderslangType                half1x1 half2x1 half3x1 half4x1 half1x2 half2x2 half3x2 half4x2 half1x3 half2x3 half3x3 half4x3 half1x4 half2x4 half3x4 half4x4
syn keyword         shaderslangType                float1x1 float2x1 float3x1 float4x1 float1x2 float2x2 float3x2 float4x2 float1x3 float2x3 float3x3 float4x3 float1x4 float2x4 float3x4 float4x4
syn keyword         shaderslangType                double1x1 double2x1 double3x1 double4x1 double1x2 double2x2 double3x2 double4x2 double1x3 double2x3 double3x3 double4x3 double1x4 double2x4 double3x4 double4x4
syn keyword         shaderslangType                min16float1x1 min16float2x1 min16float3x1 min16float4x1 min16float1x2 min16float2x2 min16float3x2 min16float4x2 min16float1x3 min16float2x3 min16float3x3 min16float4x3 min16float1x4 min16float2x4 min16float3x4 min16float4x4
syn keyword         shaderslangType                min10float1x1 min10float2x1 min10float3x1 min10float4x1 min10float1x2 min10float2x2 min10float3x2 min10float4x2 min10float1x3 min10float2x3 min10float3x3 min10float4x3 min10float1x4 min10float2x4 min10float3x4 min10float4x4
syn keyword         shaderslangType                min16int1x1 min16int2x1 min16int3x1 min16int4x1 min16int1x2 min16int2x2 min16int3x2 min16int4x2 min16int1x3 min16int2x3 min16int3x3 min16int4x3 min16int1x4 min16int2x4 min16int3x4 min16int4x4
syn keyword         shaderslangType                min12int1x1 min12int2x1 min12int3x1 min12int4x1 min12int1x2 min12int2x2 min12int3x2 min12int4x2 min12int1x3 min12int2x3 min12int3x3 min12int4x3 min12int1x4 min12int2x4 min12int3x4 min12int4x4
syn keyword         shaderslangType                min16uint1x1 min16uint2x1 min16uint3x1 min16uint4x1 min16uint1x2 min16uint2x2 min16uint3x2 min16uint4x2 min16uint1x3 min16uint2x3 min16uint3x3 min16uint4x3 min16uint1x4 min16uint2x4 min16uint3x4 min16uint4x4
syn keyword         shaderslangType                float16_t1x1 float16_t2x1 float16_t3x1 float16_t4x1 float16_t1x2 float16_t2x2 float16_t3x2 float16_t4x2 float16_t1x3 float16_t2x3 float16_t3x3 float16_t4x3 float16_t1x4 float16_t2x4 float16_t3x4 float16_t4x4
syn keyword         shaderslangType                float32_t1x1 float32_t2x1 float32_t3x1 float32_t4x1 float32_t1x2 float32_t2x2 float32_t3x2 float32_t4x2 float32_t1x3 float32_t2x3 float32_t3x3 float32_t4x3 float32_t1x4 float32_t2x4 float32_t3x4 float32_t4x4
syn keyword         shaderslangType                float64_t1x1 float64_t2x1 float64_t3x1 float64_t4x1 float64_t1x2 float64_t2x2 float64_t3x2 float64_t4x2 float64_t1x3 float64_t2x3 float64_t3x3 float64_t4x3 float64_t1x4 float64_t2x4 float64_t3x4 float64_t4x4
syn keyword         shaderslangType                int16_t1x1 int16_t2x1 int16_t3x1 int16_t4x1 int16_t1x2 int16_t2x2 int16_t3x2 int16_t4x2 int16_t1x3 int16_t2x3 int16_t3x3 int16_t4x3 int16_t1x4 int16_t2x4 int16_t3x4 int16_t4x4
syn keyword         shaderslangType                int32_t1x1 int32_t2x1 int32_t3x1 int32_t4x1 int32_t1x2 int32_t2x2 int32_t3x2 int32_t4x2 int32_t1x3 int32_t2x3 int32_t3x3 int32_t4x3 int32_t1x4 int32_t2x4 int32_t3x4 int32_t4x4
syn keyword         shaderslangType                int64_t1x1 int64_t2x1 int64_t3x1 int64_t4x1 int64_t1x2 int64_t2x2 int64_t3x2 int64_t4x2 int64_t1x3 int64_t2x3 int64_t3x3 int64_t4x3 int64_t1x4 int64_t2x4 int64_t3x4 int64_t4x4
syn keyword         shaderslangType                uint16_t1x1 uint16_t2x1 uint16_t3x1 uint16_t4x1 uint16_t1x2 uint16_t2x2 uint16_t3x2 uint16_t4x2 uint16_t1x3 uint16_t2x3 uint16_t3x3 uint16_t4x3 uint16_t1x4 uint16_t2x4 uint16_t3x4 uint16_t4x4
syn keyword         shaderslangType                uint32_t1x1 uint32_t2x1 uint32_t3x1 uint32_t4x1 uint32_t1x2 uint32_t2x2 uint32_t3x2 uint32_t4x2 uint32_t1x3 uint32_t2x3 uint32_t3x3 uint32_t4x3 uint32_t1x4 uint32_t2x4 uint32_t3x4 uint32_t4x4
syn keyword         shaderslangType                uint64_t1x1 uint64_t2x1 uint64_t3x1 uint64_t4x1 uint64_t1x2 uint64_t2x2 uint64_t3x2 uint64_t4x2 uint64_t1x3 uint64_t2x3 uint64_t3x3 uint64_t4x3 uint64_t1x4 uint64_t2x4 uint64_t3x4 uint64_t4x4

" Sampler types
syn keyword         shaderslangType                SamplerState SamplerComparisonState
syn keyword         shaderslangType                sampler sampler1D sampler2D sampler3D samplerCUBE sampler_state

" Texture types
syn keyword         shaderslangType                Texture1D Texture1DArray Texture2D Texture2DArray Texture2DMS Texture2DMSArray Texture3D TextureCube TextureCubeArray
syn keyword         shaderslangType                RWTexture1D RWTexture2D RWTexture2DArray RWTexture3D RWTextureCubeArray RWTexture2DMS RWTexture2DMSArray
syn keyword         shaderslangType                FeedbackTexture2D FeedbackTexture2DArray
syn keyword         shaderslangType                RasterizerOrderedTexture1D RasterizerOrderedTexture1DArray RasterizerOrderedTexture2D RasterizerOrderedTexture2DArray RasterizerOrderedTexture3D
syn keyword         shaderslangTypeDeprec          texture texture1D texture2D texture3D

" Raytracing types
syn keyword         shaderslangType                RaytracingAccelerationStructure RayDesc RayQuery BuiltInTriangleIntersectionAttributes

" Work graph input record objects
syn keyword         shaderslangType                DispatchNodeInputRecord RWDispatchNodeInputRecord GroupNodeInputRecords RWGroupNodeInputRecords ThreadNodeInputRecord RWThreadNodeInputRecord EmptyNodeInput

" Work graph output node objects
syn keyword         shaderslangType                NodeOutput NodeOutputArray EmptyNodeOutput EmptyNodeOutputArray

" Work graph output record objects
syn keyword         shaderslangType                ThreadNodeOutputRecords GroupNodeOutputRecords

" State Groups args
syn case ignore " This section case insensitive

" Blend state group
syn keyword         shaderslangStateGroupArg       AlphaToCoverageEnable BlendEnable SrcBlend DestBlend BlendOp SrcBlendAlpha DestBlendAlpha BlendOpAlpha RenderTargetWriteMask
syn keyword         shaderslangStateGroupVal       ZERO ONE SRC_COLOR INV_SRC_COLOR SRC_ALPHA INV_SRC_ALPHA DEST_ALPHA INV_DEST_ALPHA DEST_COLOR INV_DEST_COLOR SRC_ALPHA_SAT BLEND_FACTOR INV_BLEND_FACTOR SRC1_COLOR INV_SRC1_COLOR SRC1_ALPHA INV_SRC1_ALPHA
syn keyword         shaderslangStateGroupVal       ADD SUBSTRACT REV_SUBSTRACT MIN MAX

" Rasterizer state group
syn keyword         shaderslangStateGroupArg       FillMode CullMode FrontCounterClockwise DepthBias DepthBiasClamp SlopeScaledDepthBias ZClipEnable DepthClipEnable ScissorEnable MultisampleEnable AntialiasedLineEnable
syn keyword         shaderslangStateGroupVal       SOLID WIREFRAME
syn keyword         shaderslangStateGroupVal       NONE FRONT BACK

" Sampler state group
syn keyword         shaderslangStateGroupArg       Filter AddressU AddressV AddressW MipLODBias MaxAnisotropy ComparisonFunc BorderColor MinLOD MaxLOD ComparisonFilter
syn keyword         shaderslangStateGroupVal       MIN_MAG_MIP_POINT MIN_MAG_POINT_MIP_LINEAR MIN_POINT_MAG_LINEAR_MIP_POINT MIN_POINT_MAG_MIP_LINEAR MIN_LINEAR_MAG_MIP_POINT MIN_LINEAR_MAG_POINT_MIP_LINEAR MIN_MAG_LINEAR_MIP_POINT MIN_MAG_MIP_LINEAR ANISOTROPIC
syn keyword         shaderslangStateGroupVal       COMPARISON_MIN_MAG_MIP_POINT COMPARISON_MIN_MAG_POINT_MIP_LINEAR COMPARISON_MIN_POINT_MAG_LINEAR_MIP_POINT COMPARISON_MIN_POINT_MAG_MIP_LINEAR COMPARISON_MIN_LINEAR_MAG_MIP_POINT
syn keyword         shaderslangStateGroupVal       COMPARISON_MIN_LINEAR_MAG_POINT_MIP_LINEAR COMPARISON_MIN_MAG_LINEAR_MIP_POINT COMPARISON_MIN_MAG_MIP_LINEAR COMPARISON_ANISOTROPIC
syn keyword         shaderslangStateGroupVal       COMPARISON_NEVER COMPARISON_LESS COMPARISON_EQUAL COMPARISON_LESS_EQUAL COMPARISON_GREATER COMPARISON_NOT_EQUAL COMPARISON_GREATER_EQUAL COMPARISON_ALWAYS
syn keyword         shaderslangStateGroupVal       WRAP MIRROR CLAMP BORDER MIRROR_ONCE
syn keyword         shaderslangStateGroupVal       SAMPLER_FEEDBACK_MIN_MIP SAMPLER_FEEDBACK_MIP_REGION_USED

" Ray flags
syn keyword         shaderslangStateGroupVal       RAY_FLAG_NONE RAY_FLAG_FORCE_OPAQUE RAY_FLAG_FORCE_NON_OPAQUE RAY_FLAG_ACCEPT_FIRST_HIT_AND_END_SEARCH RAY_FLAG_SKIP_CLOSEST_HIT_SHADER
syn keyword         shaderslangStateGroupVal       RAY_FLAG_CULL_BACK_FACING_TRIANGLES RAY_FLAG_CULL_FRONT_FACING_TRIANGLES RAY_FLAG_CULL_OPAQUE RAY_FLAG_CULL_NON_OPAQUE
syn keyword         shaderslangStateGroupVal       RAY_FLAG_SKIP_TRIANGLES RAY_FLAG_SKIP_PROCEDURAL_PRIMITIVES

" HitKind enum
syn keyword         shaderslangStateGroupVal       HIT_KIND_TRIANGLE_FRONT_FACE HIT_KIND_TRIANGLE_BACK_FACE

" RayQuery enums
syn keyword         shaderslangStateGroupVal       COMMITTED_NOTHING COMMITTED_TRIANGLE_HIT COMMITTED_PROCEDURAL_PRIMITIVE_HIT
syn keyword         shaderslangStateGroupVal       CANDIDATE_NON_OPAQUE_TRIANGLE CANDIDATE_PROCEDURAL_PRIMITIVE

" Heap objects
syn keyword         shaderslangStateGroupVal       ResourceDescriptorHeap SamplerDescriptorHeap

" Work graph constants
syn keyword         shaderslangStateGroupVal       UAV_MEMORY GROUP_SHARED_MEMORY NODE_INPUT_MEMORY NODE_OUTPUT_MEMORY ALL_MEMORY GROUP_SYNC GROUP_SCOPE DEVICE_SCOPE

syn case match " Case sensitive from now on

" Effect files declarations and functions
" Effect groups, techniques passes
syn keyword         shaderslangEffectGroup         fxgroup technique11 pass
" Effect functions
syn keyword         shaderslangEffectFunc          SetBlendState SetDepthStencilState SetRasterizerState SetVertexShader SetHullShader SetDomainShader SetGeometryShader SetPixelShader SetComputeShader CompileShader ConstructGSWithSO SetRenderTargets

" Default highlighting
hi def link shaderslangProfile        shaderslangStatement
hi def link shaderslangStateGroupArg  shaderslangStatement
hi def link shaderslangStateGroupVal  Number
hi def link shaderslangStatement      Statement
hi def link shaderslangType           Type
hi def link shaderslangTypeDeprec     WarningMsg
hi def link shaderslangStorageClass   StorageClass
hi def link shaderslangSemantic       PreProc
hi def link shaderslangFunc           shaderslangStatement
hi def link shaderslangLayoutQual     shaderslangFunc
hi def link shaderslangAnnotation     PreProc
hi def link shaderslangStructure      Structure
hi def link shaderslangSwizzle        SpecialChar
hi def link shaderslangAttribute      Statement

hi def link shaderslangEffectGroup    Type
hi def link shaderslangEffectFunc     Statement

let b:current_syntax = "shaderslang"
