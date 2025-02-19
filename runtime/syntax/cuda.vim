" Vim syntax file
" Language:	CUDA (NVIDIA Compute Unified Device Architecture)
" Maintainer:	Timothy B. Terriberry <tterribe@users.sourceforge.net>
" Last Change:	2024 Apr 04
" Contributor:  jiangyinzuo

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Read the C++ syntax to start with
runtime! syntax/cpp.vim

" CUDA extentions.
" Reference: https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#c-language-extensions
syn keyword cudaStorageClass	__device__ __global__ __host__ __managed__
syn keyword cudaStorageClass	__constant__ __grid_constant__ __shared__
syn keyword cudaStorageClass	__inline__ __noinline__ __forceinline__ __inline_hint__
syn keyword cudaStorageClass	__align__ __thread__ __restrict__
"syn keyword cudaStorageClass	__import__ __export__ __location__
syn keyword cudaType		char1 char2 char3 char4
syn keyword cudaType		uchar1 uchar2 uchar3 uchar4
syn keyword cudaType		short1 short2 short3 short4
syn keyword cudaType		ushort1 ushort2 ushort3 ushort4
syn keyword cudaType		int1 int2 int3 int4
syn keyword cudaType		uint1 uint2 uint3 uint4
syn keyword cudaType		long1 long2 long3 long4
syn keyword cudaType		ulong1 ulong2 ulong3 ulong4
syn keyword cudaType		longlong1 longlong2 longlong3 longlong4
syn keyword cudaType		ulonglong1 ulonglong2 ulonglong3 ulonglong4
syn keyword cudaType		float1 float2 float3 float4
syn keyword cudaType		double1 double2 double3 double4
syn keyword cudaType		dim3 texture textureReference
syn keyword cudaType		cudaError_t cudaDeviceProp cudaMemcpyKind
syn keyword cudaType		cudaArray cudaChannelFormatKind
syn keyword cudaType		cudaChannelFormatDesc cudaTextureAddressMode
syn keyword cudaType		cudaTextureFilterMode cudaTextureReadMode
syn keyword cudaVariable	gridDim blockIdx blockDim threadIdx warpSize
syn keyword cudaConstant	__CUDA_ARCH__
syn keyword cudaConstant	__DEVICE_EMULATION__
" There are too many CUDA enumeration constants. We only define a subset of commonly used constants.
" Reference: https://docs.nvidia.com/cuda/cuda-runtime-api/group__CUDART__TYPES.html
syn keyword cudaConstant	cudaSuccess

hi def link cudaStorageClass	StorageClass
hi def link cudaType		Type
hi def link cudaVariable	Identifier
hi def link cudaConstant	Constant

let b:current_syntax = "cuda"

" vim: ts=8
