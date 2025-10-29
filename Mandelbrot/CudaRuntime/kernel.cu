﻿#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdio.h>
#include <string.h>
// --------------------------------------------------------------------
// Dll Exports
// --------------------------------------------------------------------
extern "C" __declspec(dllexport)
cudaError_t setCudaDevice(int device);

extern "C" __declspec(dllexport)
cudaError_t addWithCuda(int* c, const int* a, const int* b, unsigned int size);

extern "C" __declspec(dllexport)
int computeMandelWithCuda(int* output, int width, int height,
double centerX, double centerY, double mandelWidth, double mandelHeight, int maxDepth);

// --------------------------------------------------------------------
// CUDA Kernels
// --------------------------------------------------------------------
// Accepts pointers to three arrays and calculates c = a + b.
__global__ void addKernel(int* c, const int* a, const int* b)
{
	int i = threadIdx.x;
	c[i] = a[i] + b[i];
}

// CUDA kernel for computing Mandelbrot iteration counts
__global__ void mandelKernel(int* output, int width, int height, double centerX, double centerY, double mandelWidth, double mandelHeight, int maxDepth)
{
    int column = blockIdx.x * blockDim.x + threadIdx.x;
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    
    if (column >= width || row >= height) return;
    
	// Convert pixel coordinates to Mandelbrot rectangle coordinates
    double cx = centerX - mandelWidth + column * ((mandelWidth * 2.0) / width);
	double cy = centerY - mandelHeight + row * ((mandelHeight * 2.0) / height);
    
    // Compute iteration count using escape-time algorithm
    int result = 0;
    double x = 0.0;
    double y = 0.0;
    double xx = 0.0, yy = 0.0;
    
    while (xx + yy <= 4.0 && result < maxDepth) {
        xx = x * x;
   yy = y * y;
        double xtmp = xx - yy + cx;
        y = 2.0 * x * y + cy;
        x = xtmp;
        result++;
    }
    
    output[row * width + column] = result;
}

// --------------------------------------------------------------------
// Main Function
// --------------------------------------------------------------------
// The main() function creates three arrays, calls addWithCuda(),
// and prints out the result. Finally, it resets the CUDA device (GPU).
int main()
{
	cudaError_t cudaStatus = cudaSuccess;

	// Create three (stack-allocated) vectors.
	const int arraySize = 5;
	const int a[arraySize] = { 1, 2, 3, 4, 5 };
	const int b[arraySize] = { 10, 20, 30, 40, 50 };
	int c[arraySize] = { 0 };

	// Set CUDA device (GPU).
	cudaStatus = setCudaDevice(0);
	if (cudaStatus != cudaSuccess) 
	{
		fprintf(stderr, "setCudaDevice failed!");
		return 1;
	}

	// Add vectors in parallel.
	cudaStatus = addWithCuda(c, a, b, arraySize);
	if (cudaStatus != cudaSuccess) 
	{
		fprintf(stderr, "addWithCuda failed!");
		return 1;
	}

	// Print out the result.
	printf("{1,2,3,4,5} + {10,20,30,40,50} = {%d,%d,%d,%d,%d}\n", c[0], c[1], c[2], c[3], c[4]);

	// cudaDeviceReset must be called before exiting in order for profiling and
	// tracing tools such as Nsight and Visual Profiler to show complete traces.
	cudaStatus = cudaDeviceReset();
	if (cudaStatus != cudaSuccess) 
	{
		fprintf(stderr, "cudaDeviceReset failed!");
		return 1;
	}
	return 0;
}
// --------------------------------------------------------------------
// Helper Functions
// --------------------------------------------------------------------
// This function accepts a CUDA device ID, and sets the CUDA device (GPU).
cudaError_t setCudaDevice(int device)
{
	cudaError_t cudaStatus;

	// Choose which GPU to run on, change this on a multi-GPU system.
	// Note! Can be omitted if the default device (0) is used.
	cudaStatus = cudaSetDevice(device);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaSetDevice failed! Do you have a CUDA-capable GPU installed?");
	}
	return cudaStatus;
}
// This function uses CUDA to add vectors in parallel.
// It accepts pointers to three arrays, sets the CUDA device (GPU),
// allocates device buffers and copied the host buffers to them,
// launches a vector addition CUDA kernel, copied the device output
// buffer to the host output buffer (array), and finally
// frees the device buffers.
cudaError_t addWithCuda(int* c, const int* a, const int* b, unsigned int size)
{
	int* dev_a = 0;
	int* dev_b = 0;
	int* dev_c = 0;
	cudaError_t cudaStatus;

	// Allocate GPU buffers for three vectors (two input, one output) .
	cudaStatus = cudaMalloc((void**)&dev_c, size * sizeof(int));
	if (cudaStatus != cudaSuccess) 
	{
		fprintf(stderr, "cudaMalloc failed!");
			goto Error;
	}

	cudaStatus = cudaMalloc((void**)&dev_a, size * sizeof(int));
	if (cudaStatus != cudaSuccess) 
	{
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	cudaStatus = cudaMalloc((void**)&dev_b, size * sizeof(int));
	if (cudaStatus != cudaSuccess) 
	{
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}

	// Copy input vectors from host memory to GPU buffers.
	cudaStatus = cudaMemcpy(dev_a, a, size * sizeof(int), cudaMemcpyHostToDevice);
	if (cudaStatus != cudaSuccess) 
	{
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error;
	}

	cudaStatus = cudaMemcpy(dev_b, b, size * sizeof(int), cudaMemcpyHostToDevice);
	if (cudaStatus != cudaSuccess) 
	{
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error;
	}

	// Launch a kernel on the GPU with one thread for each element.
	addKernel <<<1, size >>> (dev_c, dev_a, dev_b);

	// Check for any errors launching the kernel
	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) 
	{
		fprintf(stderr, "addKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error;
	}

	// cudaDeviceSynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch.
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) 
	{
		fprintf(stderr,
			"cudaDeviceSynchronize returned error code %d after launching addKernel!\n",
			cudaStatus);
		goto Error;
	}

	// Copy output vector from GPU buffer to host memory.
	cudaStatus = cudaMemcpy(c, dev_c, size * sizeof(int), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) 
	{
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error;
	}
Error:
	cudaFree(dev_c);
	cudaFree(dev_a);
	cudaFree(dev_b);
		return cudaStatus;
}

// This function uses CUDA to compute Mandelbrot iteration counts in parallel.
// It allocates device buffer, copies parameters, launches the Mandelbrot kernel,
// and copies results back to host.
int computeMandelWithCuda(int* output, int width, int height,
    double centerX, double centerY, double mandelWidth, double mandelHeight, int maxDepth)
{
    int* dev_output = 0;
    cudaError_t cudaStatus;
    
    // Allocate GPU buffer for output
    int totalPixels = width * height;
    cudaStatus = cudaMalloc((void**)&dev_output, totalPixels * sizeof(int));
    if (cudaStatus != cudaSuccess) 
	{
        fprintf(stderr, "cudaMalloc failed!");
		return 1;
	}
    
    // Initialize output buffer to zero
    cudaStatus = cudaMemset(dev_output, 0, totalPixels * sizeof(int));
    if (cudaStatus != cudaSuccess) 
	{
        fprintf(stderr, "cudaMemset failed!");
        cudaFree(dev_output);
		return 1;
    }
    
    // Launch kernel with 2D grid
    dim3 threadsPerBlock(16, 16);
    dim3 numBlocks((width + threadsPerBlock.x - 1) / threadsPerBlock.x, (height + threadsPerBlock.y - 1) / threadsPerBlock.y);
    
    mandelKernel<<<numBlocks, threadsPerBlock>>>(dev_output, width, height, centerX, centerY, mandelWidth, mandelHeight, maxDepth);
    
    // Check for kernel launch errors
    cudaStatus = cudaGetLastError();
    if (cudaStatus != cudaSuccess) 
	{
		fprintf(stderr, "mandelKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
        cudaFree(dev_output);
        return 1;
    }
    
    // Wait for kernel to finish
    cudaStatus = cudaDeviceSynchronize();
    if (cudaStatus != cudaSuccess) 
	{
		fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching mandelKernel!\n", cudaStatus);
        cudaFree(dev_output);
        return 1;
    }
    
    // Copy output from GPU to host
    cudaStatus = cudaMemcpy(output, dev_output, totalPixels * sizeof(int), cudaMemcpyDeviceToHost);
    if (cudaStatus != cudaSuccess) 
	{
		fprintf(stderr, "cudaMemcpy failed!");
        cudaFree(dev_output);
        return 1;
    }
    
    cudaFree(dev_output);
    return 0; // Success
}
