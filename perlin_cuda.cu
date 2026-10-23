#include <iostream>
#include <fstream>
#include <cuda_runtime.h>
#include <cmath>
#include <cstdlib>

using namespace std;

// Image dimensions
const int WIDTH = 1920;
const int HEIGHT = 1080;

// 2-D vector structure
struct vector2 {
    float x, y;
};

// function to compute the random gradient (taken directly from video)
__device__ vector2 randomGradient(int ix, int iy) {
    // No precomputed gradients mean this works for any number of grid coordinates
    const unsigned w = 8 * sizeof(unsigned);
    const unsigned s = w / 2;

    unsigned a = (unsigned)ix;
    unsigned b = (unsigned)iy;

    a *= 3284157443u;

    b ^= (a << s) | (a >> (w - s));
    b *= 1911520717u;

    a ^= (b << s) | (b >> (w - s));
    a *= 2048419325u;

    float random = a * (3.14159265f / (float)(~(~0u >> 1)));

    // Create the vector from the angle
    vector2 v;
    v.x = sinf(random);
    v.y = cosf(random);

    return v;
}

// function to calculate the dot product and gradient of each point
__device__ float dotProduct(int a, int b, float x, float y) {

    // (a,b) -> current grid point to find dot product with
    // (x,y) -> point being evaluated

    // random gradient associated with the grid points a,b

    vector2 gradient = randomGradient(a, b);

    // dist. vectors
    float dx = x - (float)a;
    float dy = y - (float)b;

    // dot prod.
    return dx * gradient.x + dy * gradient.y;
}

// function to interpolate between 2 distances
__device__ float interpolate(float a0, float a1, float w) {
    // a0 -> first interpolation input, a1 -> second interpolation input
    // w -> interpolation weight -> [0,1]
    return (a1 - a0) * (3.0f - 2.0f * w) * w * w + a0;
}

// function to sample perlin noise at any point (x,y)
__device__ float perlin(float x, float y) {
    // grid points -> (floor and ciel integer values of x,y)
    int x1 = (int)x;
    int y1 = (int)y;

    int x2 = x1 + 1;
    int y2 = y1 + 1;

    // interpolation weights
    float wx = x - (float)x1;
    float wy = y - (float)y1;

    // interpolate at top 2 points
    float n0 = dotProduct(x1, y1, x, y);
    float n1 = dotProduct(x2, y1, x, y);
    // interpolation based on horizontal weight
    float ix1 = interpolate(n0, n1, wx);

    // interpolate at bottom 2 points
    n0 = dotProduct(x1, y2, x, y);
    n1 = dotProduct(x2, y2, x, y);
    // interpolation based on horizontal weight
    float ix2 = interpolate(n0, n1, wx);

    // interpolate by vertical weight
    return interpolate(ix1, ix2, wy);
}

// CUDA kernel: each thread calculates one pixel
__global__ void generatePerlin(float* output, int width, int height,
                               float scale) {
    // Calculate this thread's pixel coordinates
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    // Ignore threads outside the image
    if (x >= width || y >= height) {
        return;
    }

    // Calculate 12-octave Perlin noise
    float val = 0.0f;
    float freq = 1.0f;
    float amp = 1.0f;
    float maxAmp = 0.0f;

    for (int octave = 0; octave < 12; octave++) {
        val += perlin(x * scale * freq,
                      y * scale * freq) * amp;

        maxAmp += amp;

        freq *= 2.0f;
        amp *= 0.5f;
    }

    // Normalize to approximately [-1, 1]
    val /= maxAmp;

    // Store this pixel's noise value in GPU memory
    output[y * width + x] = val;
}

int main() {
    const float scale = 0.02f;

    size_t numPixels = (size_t)WIDTH * HEIGHT;
    size_t size = numPixels * sizeof(float);

    // allocate memory on the GPU
    float* d_output = nullptr;

    cudaError_t err = cudaMalloc((void**)&d_output, size);

    if (err != cudaSuccess) {
        cerr << "GPU memory allocation failed: "
             << cudaGetErrorString(err) << '\n';
        return 1;
    }

    // threads per block
    dim3 threads(16, 16);

    // calculating blocks required
    dim3 blocks(
        (WIDTH + threads.x - 1) / threads.x,
        (HEIGHT + threads.y - 1) / threads.y
    );

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    cudaEventRecord(start);

    // launching the kernel
    generatePerlin<<<blocks, threads>>>(
        d_output, WIDTH, HEIGHT, scale
    );

    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float gpuTime = 0.0f;
    cudaEventElapsedTime(&gpuTime, start, stop);

    cout << "GPU Kernel Execution Time: "
        << gpuTime << " ms\n";

    cudaEventDestroy(start);
    cudaEventDestroy(stop);

    // Check for kernel launch errors
    err = cudaGetLastError();

    if (err != cudaSuccess) {
        cerr << "Kernel launch failed: "
             << cudaGetErrorString(err) << '\n';
        cudaFree(d_output);
        return 1;
    }

    // waiting for gpu to finish
    err = cudaDeviceSynchronize();

    if (err != cudaSuccess) {
        cerr << "GPU execution failed: "
             << cudaGetErrorString(err) << '\n';
        cudaFree(d_output);
        return 1;
    }

    // allocate cpu memory
    float* h_output = new float[numPixels];

    err = cudaMemcpy(
        h_output,
        d_output,
        size,
        cudaMemcpyDeviceToHost
    );

    if (err != cudaSuccess) {
        cerr << "Memory copy failed: "
             << cudaGetErrorString(err) << '\n';

        delete[] h_output;
        cudaFree(d_output);
        return 1;
    }

    ofstream image("perlin_cuda.pgm");

    if (!image) {
        cerr << "Could not open output image file.\n";

        delete[] h_output;
        cudaFree(d_output);
        return 1;
    }

    image << "P2\n";
    image << WIDTH << " " << HEIGHT << "\n";
    image << "255\n";

    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            float val = h_output[(size_t)y * WIDTH + x];

            int pixel = (int)((val + 1.0f) * 0.5f * 255.0f);

            // Ensure valid grayscale pixel values
            if (pixel < 0) pixel = 0;
            if (pixel > 255) pixel = 255;

            image << pixel << " ";
        }

        image << "\n";
    }

    image.close();

    
    delete[] h_output;
    cudaFree(d_output);

    return 0;
}