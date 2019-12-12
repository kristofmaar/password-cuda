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
#include "md5_gpu.cu"
#include "md5.h"
#include <fstream>
#include <ctime>

#define CONST_FILE_LENGTH 10000
#define CONST_WORD_LENGTH_KRISTOF 5

using namespace std;

 /* Global variables */
uint8_t g_wordLength;
char g_cracked[CONST_WORD_LENGTH_KRISTOF];
string g_words[CONST_FILE_LENGTH];

__device__ char g_deviceCracked[CONST_WORD_LENGTH_KRISTOF];
//__device__ string g_deviceWords[CONST_FILE_LENGTH];

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

int findHashCPU(string input[CONST_FILE_LENGTH], string inputHash)
{
	int found = 0;
	for (unsigned int i = 0; i < CONST_FILE_LENGTH; i = i + 1)
	{
		string data = input[i];
		string data_hex_digest;

		MD5 hash;
		if (inputHash == hash(data)) {
			found = i;
		}
	}
	return found;
}

int main() {
	/* password hash to find: cattle*/
	char passwordHash[33] = "bd5f4b0419caa97dd2f9b4d3238ff92f";

	/* read text file to array*/
	string wordsArray[CONST_FILE_LENGTH];
	ifstream file("passwords.txt");
	if (file.is_open()) for (int i = 0; i < CONST_FILE_LENGTH; ++i) file >> wordsArray[i];

	/*CPU hash finder*/
	std::clock_t c_start = std::clock();

	int index = findHashCPU(wordsArray, passwordHash);

	std::clock_t c_end = std::clock();

	double time_elapsed_ms = 1000.0 * (c_end - c_start) / CLOCKS_PER_SEC;

	std::cout << "CPU bruteforce:\n\cracked word: " << wordsArray[index] << std::endl;
	std::cout << "\ttime used: " << time_elapsed_ms << " ms\n";

	/* variable for hash stored as u32 integers */
	uint32_t md5Hash[4];

	/* parse hash to u32 integer */
	for (uint8_t i = 0; i < 4; i++) {
		char tmp[16];
		strncpy(tmp, passwordHash + i * 8, 8);
		sscanf(tmp, "%x", &md5Hash[i]);
		md5Hash[i] = (md5Hash[i] & 0xFF000000) >> 24 | (md5Hash[i] & 0x00FF0000) >> 8 | (md5Hash[i] & 0x0000FF00) << 8 | (md5Hash[i] & 0x000000FF) << 24;
	}

	/* fill memory */
	memset(g_cracked, 0, CONST_WORD_LENGTH_KRISTOF);
	//memset(g_deviceWords, 0, CONST_FILE_LENGTH);
	g_wordLength = CONST_WORD_LENGTH_KRISTOF;

	/* copy to device */
	cudaMemcpyToSymbol(g_deviceCracked, g_cracked, sizeof(uint8_t) * CONST_WORD_LENGTH_KRISTOF, 0, cudaMemcpyHostToDevice);

	cudaEvent_t clockBegin;
	cudaEvent_t clockLast;

	cudaEventCreate(&clockBegin);
	cudaEventCreate(&clockLast);
	cudaEventRecord(clockBegin, 0);

	md5Crack <<< 1,1 >>> (g_wordLength, md5Hash[0], md5Hash[1], md5Hash[2], md5Hash[3]);

	/* Copy result */
	cudaMemcpyFromSymbol(g_cracked, g_deviceCracked, sizeof(uint8_t) * CONST_WORD_LENGTH_KRISTOF, 0, cudaMemcpyDeviceToHost);

	float milliseconds = 0;
	cudaEventRecord(clockLast, 0);
	cudaEventSynchronize(clockLast);
	cudaEventElapsedTime(&milliseconds, clockBegin, clockLast);

	cudaEventDestroy(clockBegin);
	cudaEventDestroy(clockLast);

	std::cout << "\nGPU bruteforce:\n\tcracked word: " << g_cracked << std::endl;
	std::cout << "\tcomputation time: " << milliseconds << " ms" << std::endl;
}