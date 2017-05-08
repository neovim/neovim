" Vim syntax file
" Language:	CUDA (NVIDIA Compute Unified Device Architecture)
" Maintainer:	Timothy B. Terriberry <tterribe@users.sourceforge.net>
" Last Change:	2007 Oct 13

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Read the C syntax to start with
runtime! syntax/c.vim

" CUDA extentions
syn keyword cudaStorageClass	__device__ __global__ __host__
syn keyword cudaStorageClass	__constant__ __shared__
syn keyword cudaStorageClass	__inline__ __align__ __thread__
"syn keyword cudaStorageClass	__import__ __export__ __location__
syn keyword cudaStructure	template
syn keyword cudaType		char1 char2 char3 char4
syn keyword cudaType		uchar1 uchar2 uchar3 uchar4
syn keyword cudaType		short1 short2 short3 short4
syn keyword cudaType		ushort1 ushort2 ushort3 ushort4
syn keyword cudaType		int1 int2 int3 int4
syn keyword cudaType		uint1 uint2 uint3 uint4
syn keyword cudaType		long1 long2 long3 long4
syn keyword cudaType		ulong1 ulong2 ulong3 ulong4
syn keyword cudaType		float1 float2 float3 float4
syn keyword cudaType		ufloat1 ufloat2 ufloat3 ufloat4
syn keyword cudaType		dim3 texture textureReference
syn keyword cudaType		cudaError_t cudaDeviceProp cudaMemcpyKind
syn keyword cudaType		cudaArray cudaChannelFormatKind
syn keyword cudaType		cudaChannelFormatDesc cudaTextureAddressMode
syn keyword cudaType		cudaTextureFilterMode cudaTextureReadMode
syn keyword cudaVariable	gridDim blockIdx blockDim threadIdx
syn keyword cudaConstant	__DEVICE_EMULATION__
syn keyword cudaConstant	cudaSuccess
" Many more errors are defined, but only these are listed in the maunal
syn keyword cudaConstant	cudaErrorMemoryAllocation
syn keyword cudaConstant	cudaErrorInvalidDevicePointer
syn keyword cudaConstant	cudaErrorInvalidSymbol
syn keyword cudaConstant	cudaErrorMixedDeviceExecution
syn keyword cudaConstant	cudaMemcpyHostToHost
syn keyword cudaConstant	cudaMemcpyHostToDevice
syn keyword cudaConstant	cudaMemcpyDeviceToHost
syn keyword cudaConstant	cudaMemcpyDeviceToDevice
syn keyword cudaConstant	cudaReadModeElementType
syn keyword cudaConstant	cudaReadModeNormalizedFloat
syn keyword cudaConstant	cudaFilterModePoint
syn keyword cudaConstant	cudaFilterModeLinear
syn keyword cudaConstant	cudaAddressModeClamp
syn keyword cudaConstant	cudaAddressModeWrap
syn keyword cudaConstant	cudaChannelFormatKindSigned
syn keyword cudaConstant	cudaChannelFormatKindUnsigned
syn keyword cudaConstant	cudaChannelFormatKindFloat

hi def link cudaStorageClass	StorageClass
hi def link cudaStructure	Structure
hi def link cudaType		Type
hi def link cudaVariable	Identifier
hi def link cudaConstant	Constant

let b:current_syntax = "cuda"

" vim: ts=8
