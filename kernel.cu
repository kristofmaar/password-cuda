#include <stdio.h>
#include <iostream>
#include <time.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <sstream>
#include <cuda_runtime.h>
#include <cuda_runtime_api.h>
#include <device_functions.h>
#include "md5.cu"

#define CONST_WORD_LENGTH_KRISTOF 5


 /* Global variables */
uint8_t g_wordLength;
char g_cracked[CONST_WORD_LENGTH_KRISTOF];

__device__ char g_deviceCracked[CONST_WORD_LENGTH_KRISTOF];

__global__ void md5Crack(uint8_t wordLength, uint32_t hash01, uint32_t hash02, uint32_t hash03, uint32_t hash04) {

	/* Thread variables */
	char threadTextWord[6] = "teszt";
	uint8_t threadWordLength;
	uint32_t threadHash01, threadHash02, threadHash03, threadHash04;

	/* Copy everything to local memory */
	memcpy(&threadWordLength, &wordLength, sizeof(uint8_t));

	md5Hash((unsigned char*)threadTextWord, threadWordLength, &threadHash01, &threadHash02, &threadHash03, &threadHash04);

	if (threadHash01 == hash01 && threadHash02 == hash02 && threadHash03 == hash03 && threadHash04 == hash04) {
		memcpy(g_deviceCracked, threadTextWord, threadWordLength);
	}
}

int main() {
	/* hash stored as u32 integers */
	uint32_t md5Hash[4];

	/* parse hash to u32 integer */
	for (uint8_t i = 0; i < 4; i++) {
		char tmp[16];
		strncpy(tmp, "6c90aa3760658846a86a263a4e92630e" + i * 8, 8);
		sscanf(tmp, "%x", &md5Hash[i]);
		md5Hash[i] = (md5Hash[i] & 0xFF000000) >> 24 | (md5Hash[i] & 0x00FF0000) >> 8 | (md5Hash[i] & 0x0000FF00) << 8 | (md5Hash[i] & 0x000000FF) << 24;
	}

	/* Fill memory */
	memset(g_cracked, 0, CONST_WORD_LENGTH_KRISTOF);
	g_wordLength = CONST_WORD_LENGTH_KRISTOF;

	/* copy to device */
	cudaMemcpyToSymbol(g_deviceCracked, g_cracked, sizeof(uint8_t) * CONST_WORD_LENGTH_KRISTOF, 0, cudaMemcpyHostToDevice);

	md5Crack <<< 1,1 >>> (g_wordLength, md5Hash[0], md5Hash[1], md5Hash[2], md5Hash[3]);

	/* Copy result */
	cudaMemcpyFromSymbol(g_cracked, g_deviceCracked, sizeof(uint8_t) * CONST_WORD_LENGTH_KRISTOF, 0, cudaMemcpyDeviceToHost);

	std::cout << "Notice: cracked " << g_cracked << std::endl;
}