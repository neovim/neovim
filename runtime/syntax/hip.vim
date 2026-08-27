" Vim syntax file
" Language:	HIP (Heterogeneous-compute Interface for Portability)
" Maintainer:	Young <young20050727@gmail.com>
" Last Change:	2026 Jul 15
" Based On:	syntax/cuda.vim by Timothy B. Terriberry

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Read the C++ syntax to start with
runtime! syntax/cpp.vim

" HIP extensions.
" Reference: https://docs.amd.com/en/latest/develop-perf-tips/hip-programming-guide/
syn keyword hipStorageClass	__device__ __global__ __host__ __managed__
syn keyword hipStorageClass	__constant__ __grid_constant__ __shared__
syn keyword hipStorageClass	__inline__ __noinline__ __forceinline__ __inline_hint__
syn keyword hipStorageClass	__align__ __thread__ __restrict__
syn keyword hipType		char1 char2 char3 char4
syn keyword hipType		uchar1 uchar2 uchar3 uchar4
syn keyword hipType		short1 short2 short3 short4
syn keyword hipType		ushort1 ushort2 ushort3 ushort4
syn keyword hipType		int1 int2 int3 int4
syn keyword hipType		uint1 uint2 uint3 uint4
syn keyword hipType		long1 long2 long3 long4
syn keyword hipType		ulong1 ulong2 ulong3 ulong4
syn keyword hipType		longlong1 longlong2 longlong3 longlong4
syn keyword hipType		ulonglong1 ulonglong2 ulonglong3 ulonglong4
syn keyword hipType		float1 float2 float3 float4
syn keyword hipType		double1 double2 double3 double4
syn keyword hipType		dim3 texture textureReference
syn keyword hipType		hipError_t hipDeviceProp hipMemcpyKind
syn keyword hipType		hipArray hipChannelFormatKind
syn keyword hipType		hipChannelFormatDesc hipTextureAddressMode
syn keyword hipType		hipTextureFilterMode hipTextureReadMode
syn keyword hipVariable		gridDim blockIdx blockDim threadIdx warpSize
syn keyword hipConstant		__HIP_ARCH__
syn keyword hipConstant		__DEVICE_EMULATION__
" There are too many HIP enumeration constants. We only define a subset of commonly used constants.
" Reference: https://docs.amd.com/en/latest/develop-perf-tips/hip-programming-guide/
syn keyword hipConstant		hipSuccess

hi def link hipStorageClass	StorageClass
hi def link hipType		Type
hi def link hipVariable		Identifier
hi def link hipConstant		Constant

let b:current_syntax = "hip"

" vim: ts=8
