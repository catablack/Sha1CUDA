#pragma once
#pragma once
#ifndef SHA1_H
#define SHA1_H

/*
   SHA-1 in C
   By Steve Reid <steve@edmweb.com>
   100% Public Domain
 */

#include "stdint.h"
#include"cuda_runtime.h"

 typedef struct
{
    uint32_t state[5];
    uint32_t count[2];
    unsigned char buffer[64];
} SHA1_CTX;

__device__ void SHA1Transform(
    uint32_t state[5],
    const unsigned char buffer[64]
);

__device__ void SHA1Init(
    SHA1_CTX* context
);

__device__ void SHA1Update(
    SHA1_CTX* context,
    const unsigned char* data,
    uint32_t len
);

__device__ void SHA1Final(
    unsigned char digest[20],
    SHA1_CTX* context
);

__device__ void SHA1(
    char* hash_out,
    const char* str,
    int len);

#endif /* SHA1_H */
