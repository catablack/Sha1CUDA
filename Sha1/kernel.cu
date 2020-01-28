#pragma once
#include "cuda_runtime.h"
#include <stdio.h>
#include "stdint.h"
#include <stddef.h>
#include <stdarg.h>
#include<string.h>
#include <stdlib.h>
#include <curand.h>
#include <curand_kernel.h>
#include "device_launch_parameters.h"
#include <sys/timeb.h>

__managed__ int found = 0;
__managed__ char* word = "cata";
__managed__ char* hash = "a31ae9fe898b3f1d73e28d0d501014e3385ac1d4";
__managed__ char result[20];

__device__ static void simple_outputchar(char** str, char c)
{
	if (str) {
		**str = c;
		++(*str);
	}
	else {
		//putchar(c);
	}
}

enum flags {
	PAD_ZERO = 1,
	PAD_RIGHT = 2,
};

__device__ static int prints(char** out, const char* string, int width, int flags)
{
	int pc = 0, padchar = ' ';

	if (width > 0) {
		int len = 0;
		const char* ptr;
		for (ptr = string; *ptr; ++ptr) ++len;
		if (len >= width) width = 0;
		else width -= len;
		if (flags & PAD_ZERO)
			padchar = '0';
	}
	if (!(flags & PAD_RIGHT)) {
		for (; width > 0; --width) {
			simple_outputchar(out, padchar);
			++pc;
		}
	}
	for (; *string; ++string) {
		simple_outputchar(out, *string);
		++pc;
	}
	for (; width > 0; --width) {
		simple_outputchar(out, padchar);
		++pc;
	}

	return pc;
}

#define PRINT_BUF_LEN 64

__device__ static int simple_outputi(char** out, long long i, int base, int sign, int width, int flags, int letbase)
{
	char print_buf[PRINT_BUF_LEN];
	char* s;
	int t, neg = 0, pc = 0;
	unsigned long long u = i;

	if (i == 0) {
		print_buf[0] = '0';
		print_buf[1] = '\0';
		return prints(out, print_buf, width, flags);
	}

	if (sign && base == 10 && i < 0) {
		neg = 1;
		u = -i;
	}

	s = print_buf + PRINT_BUF_LEN - 1;
	*s = '\0';

	while (u) {
		t = u % base;
		if (t >= 10)
			t += letbase - '0' - 10;
		*--s = t + '0';
		u /= base;
	}

	if (neg) {
		if (width && (flags & PAD_ZERO)) {
			simple_outputchar(out, '-');
			++pc;
			--width;
		}
		else {
			*--s = '-';
		}
	}

	return pc + prints(out, s, width, flags);
}


__device__ static int simple_vsprintf(char** out, char* format, va_list ap)
{
	int width, flags;
	int pc = 0;
	char scr[2];
	union {
		char c;
		char* s;
		int i;
		unsigned int u;
		long li;
		unsigned long lu;
		long long lli;
		unsigned long long llu;
		short hi;
		unsigned short hu;
		signed char hhi;
		unsigned char hhu;
		void* p;
	} u;

	for (; *format != 0; ++format) {
		if (*format == '%') {
			++format;
			width = flags = 0;
			if (*format == '\0')
				break;
			if (*format == '%')
				goto out;
			if (*format == '-') {
				++format;
				flags = PAD_RIGHT;
			}
			while (*format == '0') {
				++format;
				flags |= PAD_ZERO;
			}
			if (*format == '*') {
				width = va_arg(ap, int);
				format++;
			}
			else {
				for (; *format >= '0' && *format <= '9'; ++format) {
					width *= 10;
					width += *format - '0';
				}
			}
			switch (*format) {
			case('d'):
				u.i = va_arg(ap, int);
				pc += simple_outputi(out, u.i, 10, 1, width, flags, 'a');
				break;

			case('u'):
				u.u = va_arg(ap, unsigned int);
				pc += simple_outputi(out, u.u, 10, 0, width, flags, 'a');
				break;

			case('x'):
				u.u = va_arg(ap, unsigned int);
				pc += simple_outputi(out, u.u, 16, 0, width, flags, 'a');
				break;

			case('X'):
				u.u = va_arg(ap, unsigned int);
				pc += simple_outputi(out, u.u, 16, 0, width, flags, 'A');
				break;

			case('c'):
				u.c = va_arg(ap, int);
				scr[0] = u.c;
				scr[1] = '\0';
				pc += prints(out, scr, width, flags);
				break;

			case('s'):
				u.s = va_arg(ap, char*);
				pc += prints(out, u.s ? u.s : "(null)", width, flags);
				break;
			case('l'):
				++format;
				switch (*format) {
				case('d'):
					u.li = va_arg(ap, long);
					pc += simple_outputi(out, u.li, 10, 1, width, flags, 'a');
					break;

				case('u'):
					u.lu = va_arg(ap, unsigned long);
					pc += simple_outputi(out, u.lu, 10, 0, width, flags, 'a');
					break;

				case('x'):
					u.lu = va_arg(ap, unsigned long);
					pc += simple_outputi(out, u.lu, 16, 0, width, flags, 'a');
					break;

				case('X'):
					u.lu = va_arg(ap, unsigned long);
					pc += simple_outputi(out, u.lu, 16, 0, width, flags, 'A');
					break;

				case('l'):
					++format;
					switch (*format) {
					case('d'):
						u.lli = va_arg(ap, long long);
						pc += simple_outputi(out, u.lli, 10, 1, width, flags, 'a');
						break;

					case('u'):
						u.llu = va_arg(ap, unsigned long long);
						pc += simple_outputi(out, u.llu, 10, 0, width, flags, 'a');
						break;

					case('x'):
						u.llu = va_arg(ap, unsigned long long);
						pc += simple_outputi(out, u.llu, 16, 0, width, flags, 'a');
						break;

					case('X'):
						u.llu = va_arg(ap, unsigned long long);
						pc += simple_outputi(out, u.llu, 16, 0, width, flags, 'A');
						break;

					default:
						break;
					}
					break;
				default:
					break;
				}
				break;
			case('h'):
				++format;
				switch (*format) {
				case('d'):
					u.hi = va_arg(ap, int);
					pc += simple_outputi(out, u.hi, 10, 1, width, flags, 'a');
					break;

				case('u'):
					u.hu = va_arg(ap, unsigned int);
					pc += simple_outputi(out, u.lli, 10, 0, width, flags, 'a');
					break;

				case('x'):
					u.hu = va_arg(ap, unsigned int);
					pc += simple_outputi(out, u.lli, 16, 0, width, flags, 'a');
					break;

				case('X'):
					u.hu = va_arg(ap, unsigned int);
					pc += simple_outputi(out, u.lli, 16, 0, width, flags, 'A');
					break;

				case('h'):
					++format;
					switch (*format) {
					case('d'):
						u.hhi = va_arg(ap, int);
						pc += simple_outputi(out, u.hhi, 10, 1, width, flags, 'a');
						break;

					case('u'):
						u.hhu = va_arg(ap, unsigned int);
						pc += simple_outputi(out, u.lli, 10, 0, width, flags, 'a');
						break;

					case('x'):
						u.hhu = va_arg(ap, unsigned int);
						pc += simple_outputi(out, u.lli, 16, 0, width, flags, 'a');
						break;

					case('X'):
						u.hhu = va_arg(ap, unsigned int);
						pc += simple_outputi(out, u.lli, 16, 0, width, flags, 'A');
						break;

					default:
						break;
					}
					break;
				default:
					break;
				}
				break;
			default:
				break;
			}
		}
		else {
		out:
			simple_outputchar(out, *format);
			++pc;
		}
	}
	if (out) **out = '\0';
	return pc;
}

__device__ int simple_printf(char* fmt, ...)
{
	va_list ap;
	int r;

	va_start(ap, fmt);
	r = simple_vsprintf(NULL, fmt, ap);
	va_end(ap);

	return r;
}

__device__ int simple_sprintf(char* buf, char* fmt, ...)
{
	va_list ap;
	int r;

	va_start(ap, fmt);
	r = simple_vsprintf(&buf, fmt, ap);
	va_end(ap);

	return r;
}

__device__ int sha1digest(uint8_t* digest, char* hexdigest, const uint8_t* data, size_t databytes) {
#define SHA1ROTATELEFT(value, bits) (((value) << (bits)) | ((value) >> (32 - (bits))))

	uint32_t W[80];
	uint32_t H[] = { 0x67452301,
		0xEFCDAB89,
		0x98BADCFE,
		0x10325476,
		0xC3D2E1F0 };
	uint32_t a;
	uint32_t b;
	uint32_t c;
	uint32_t d;
	uint32_t e;
	uint32_t f = 0;
	uint32_t k = 0;

	uint32_t idx;
	uint32_t lidx;
	uint32_t widx;
	uint32_t didx = 0;

	int32_t wcount;
	uint32_t temp;
	uint64_t databits = ((uint64_t)databytes) * 8;
	uint32_t loopcount = (databytes + 8) / 64 + 1;
	uint32_t tailbytes = 64 * loopcount - databytes;
	uint8_t datatail[128] = { 0 };

	if (!digest && !hexdigest)
		return -1;

	if (!data)
		return -1;

	/* Pre-processing of data tail (includes padding to fill out 512-bit chunk):
	Add bit '1' to end of message (big-endian)
	Add 64-bit message length in bits at very end (big-endian) */
	datatail[0] = 0x80;
	datatail[tailbytes - 8] = (uint8_t)(databits >> 56 & 0xFF);
	datatail[tailbytes - 7] = (uint8_t)(databits >> 48 & 0xFF);
	datatail[tailbytes - 6] = (uint8_t)(databits >> 40 & 0xFF);
	datatail[tailbytes - 5] = (uint8_t)(databits >> 32 & 0xFF);
	datatail[tailbytes - 4] = (uint8_t)(databits >> 24 & 0xFF);
	datatail[tailbytes - 3] = (uint8_t)(databits >> 16 & 0xFF);
	datatail[tailbytes - 2] = (uint8_t)(databits >> 8 & 0xFF);
	datatail[tailbytes - 1] = (uint8_t)(databits >> 0 & 0xFF);

	/* Process each 512-bit chunk */
	for (lidx = 0; lidx < loopcount; lidx++)
	{
		/* Compute all elements in W */
		memset(W, 0, 80 * sizeof(uint32_t));

		/* Break 512-bit chunk into sixteen 32-bit, big endian words */
		for (widx = 0; widx <= 15; widx++)
		{
			wcount = 24;

			/* Copy byte-per byte from specified buffer */
			while (didx < databytes && wcount >= 0)
			{
				W[widx] += (((uint32_t)data[didx]) << wcount);
				didx++;
				wcount -= 8;
			}
			/* Fill out W with padding as needed */
			while (wcount >= 0)
			{
				W[widx] += (((uint32_t)datatail[didx - databytes]) << wcount);
				didx++;
				wcount -= 8;
			}
		}

		/* Extend the sixteen 32-bit words into eighty 32-bit words, with potential optimization from:
		"Improving the Performance of the Secure Hash Algorithm (SHA-1)" by Max Locktyukhin */
		for (widx = 16; widx <= 31; widx++)
		{
			W[widx] = SHA1ROTATELEFT((W[widx - 3] ^ W[widx - 8] ^ W[widx - 14] ^ W[widx - 16]), 1);
		}
		for (widx = 32; widx <= 79; widx++)
		{
			W[widx] = SHA1ROTATELEFT((W[widx - 6] ^ W[widx - 16] ^ W[widx - 28] ^ W[widx - 32]), 2);
		}

		/* Main loop */
		a = H[0];
		b = H[1];
		c = H[2];
		d = H[3];
		e = H[4];

		for (idx = 0; idx <= 79; idx++)
		{
			if (idx <= 19)
			{
				f = (b & c) | ((~b) & d);
				k = 0x5A827999;
			}
			else if (idx >= 20 && idx <= 39)
			{
				f = b ^ c ^ d;
				k = 0x6ED9EBA1;
			}
			else if (idx >= 40 && idx <= 59)
			{
				f = (b & c) | (b & d) | (c & d);
				k = 0x8F1BBCDC;
			}
			else if (idx >= 60 && idx <= 79)
			{
				f = b ^ c ^ d;
				k = 0xCA62C1D6;
			}
			temp = SHA1ROTATELEFT(a, 5) + f + e + k + W[idx];
			e = d;
			d = c;
			c = SHA1ROTATELEFT(b, 30);
			b = a;
			a = temp;
		}

		H[0] += a;
		H[1] += b;
		H[2] += c;
		H[3] += d;
		H[4] += e;
	}

	/* Store binary digest in supplied buffer */
	if (digest)
	{
		for (idx = 0; idx < 5; idx++)
		{
			digest[idx * 4 + 0] = (uint8_t)(H[idx] >> 24);
			digest[idx * 4 + 1] = (uint8_t)(H[idx] >> 16);
			digest[idx * 4 + 2] = (uint8_t)(H[idx] >> 8);
			digest[idx * 4 + 3] = (uint8_t)(H[idx]);
		}
	}

	/* Store hex version of digest in supplied buffer */
	if (hexdigest)
	{
		simple_sprintf(hexdigest, "%08x%08x%08x%08x%08x",
			H[0], H[1], H[2], H[3], H[4]);
	}

	return 0;
}


__device__ int strLen(char* str) {
    int len = -1;
    while (str[len + 1] != NULL)
        len++;
    return len + 1;
}

__device__ void copy_str(char* dest, char* src) {
	int i = 0;
	while (src[i] != '\0') {
		dest[i] = src[i];
		i++;
	}
	dest[i] = '\0';
}


__device__ int str_cmp(char string1[], char string2[])
{
	for (int i = 0; ; i++)
	{
		if (string1[i] != string2[i])
		{
			return string1[i] < string2[i] ? -1 : 1;
		}

		if (string1[i] == '\0')
		{
			return 0;
		}
	}
}


__global__  void sha_find() {
	curandState_t state;
	char buf[20];

	copy_str(buf, word);

	/* we have to initialize the state */
	curand_init(0, /* the seed controls the sequence of random values that are produced */
		blockIdx.x * blockDim.x + threadIdx.x, /* the sequence number is only important with multiple cores */
		0, /* the offset is how much extra we advance in the sequence for each call, can be 0 */
		&state);

	while (found == 0 && strLen(buf) < 20)
	{
		uint8_t digest[20]; char hexdigest[41];
		int n = strLen(buf);
		buf[n] = char(curand(&state) % 127);
		buf[++n] = '\0';
		//printf("Hashing: %s\n", buf);
		sha1digest(digest, hexdigest, (uint8_t*)buf, strLen(buf));
		if (str_cmp(hexdigest, hash) == 0) {
			found = 1;
			//printf("The word is: %s", buf);
			copy_str(result, buf);
		}
		
	}
	/* curand works like rand - except that it takes a state as a parameter */
	
	//printf("Started\n");
	//printf("Word is %s\n", word);
	//printf("Rand: %d \n", result);
	/*uint8_t digest[20]; char hexdigest[41];
	sha1digest(digest, hexdigest, (uint8_t*)word, strLen(word));
	printf("%s\n", hexdigest);*/
}

// Helper function for using CUDA to add vectors in parallel.
void runCuda()
{
	double timee;
	struct timeb start, end;
	ftime(&start);
	while (found == 0)
	{
		sha_find << <1, 100 >> > ();
		cudaDeviceSynchronize();
	};
	ftime(&end);
	timee = end.time - start.time + ((double)end.millitm - (double)start.millitm) / 1000.0;
	printf("The word is: %s\n", result);
	printf("Duration = % .2lf\n", timee);
	
}

int main()
{
    // Add vectors in parallel.
    runCuda();
 
    return 0;
}
