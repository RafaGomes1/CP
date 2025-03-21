#include "fluid_solver.h"
#include <cmath>
#include <omp.h>
#include <cuda.h>
#include <algorithm>
#include <stdio.h>
#include <iostream>
#define THREADS_PER_BLOCK 8
#define CUDA_IX(i, j, k, M, N) ((i) + (M + 2) * (j) + (M + 2) * (N + 2) * (k))

#define IX(i, j, k) ((i) + (M + 2) * (j) + (M + 2) * (N + 2) * (k))
#define SWAP(x0, x)                                                            \
  {                                                                            \
    float *tmp = x0;                                                           \
    x0 = x;                                                                    \
    x = tmp;                                                                   \
  }
#define MAX(a, b) (((a) > (b)) ? (a) : (b))
#define LINEARSOLVERTIMES 20

 //void copy_data_to_device(int size, float *u, float *v, float *w, float *u0, float *v0, float *w0, float *h_x, float *h_x0) {
 //   std::cerr << "dens inicio" << (195) << ": " << (h_x[195]) << std::endl;
 //   cudaMemcpy(d_x_global, h_x, size * sizeof(float), cudaMemcpyHostToDevice);
 //   cudaError_t err = cudaGetLastError();
 //   if (err != cudaSuccess) {
 //       std::cerr << "Error copying h_x to d_x_global: " << cudaGetErrorString(err) << std::endl;
 //   }
 //   cudaMemcpy(d_x0_global, h_x0, size * sizeof(float), cudaMemcpyHostToDevice);
 //   cudaError_t err1 = cudaGetLastError();
 //   if (err1 != cudaSuccess) {
 //       std::cerr << "Error copying h_x0 to d_x0_global: " << cudaGetErrorString(err1) << std::endl;
 //   }
 //   cudaMemcpy(d_u, u, size * sizeof(float), cudaMemcpyHostToDevice);
 //   cudaError_t err2 = cudaGetLastError();
 //   if (err2 != cudaSuccess) {
 //       std::cerr << "Error copying u to d_u: " << cudaGetErrorString(err2) << std::endl;
 //   }
 //   cudaMemcpy(d_v, v, size * sizeof(float), cudaMemcpyHostToDevice);
 //   cudaError_t err7 = cudaGetLastError();
 //   if (err7 != cudaSuccess) {
 //       std::cerr << "Error copying v to d_v: " << cudaGetErrorString(err7) << std::endl;
 //   }
 //   cudaMemcpy(d_w, w, size * sizeof(float), cudaMemcpyHostToDevice);
 //   cudaError_t err3 = cudaGetLastError();
 //   if (err3 != cudaSuccess) {
 //       std::cerr << "Error copying w to d_w: " << cudaGetErrorString(err3) << std::endl;
 //   }
 //   cudaMemcpy(d_u0, u0, size * sizeof(float), cudaMemcpyHostToDevice);
 //   cudaError_t err4 = cudaGetLastError();
 //   if (err4 != cudaSuccess) {
 //       std::cerr << "Error copying u0 to d_u0: " << cudaGetErrorString(err4) << std::endl;
 //   }
 //   cudaMemcpy(d_v0, v0, size * sizeof(float), cudaMemcpyHostToDevice);
 //   cudaError_t err5 = cudaGetLastError();
 //   if (err5 != cudaSuccess) {
 //       std::cerr << "Error copying v0 to d_v0: " << cudaGetErrorString(err5) << std::endl;
 //   }
 //   cudaMemcpy(d_w0, w0, size * sizeof(float), cudaMemcpyHostToDevice);
 //   cudaError_t err6 = cudaGetLastError();
 //   if (err6 != cudaSuccess) {
 //       std::cerr << "Error copying w0 to d_w0: " << cudaGetErrorString(err6) << std::endl;
 //   }
 //   //cudaMemcpy(d_u, h_u, size * sizeof(float), cudaMemcpyHostToDevice);
 //   //cudaMemcpy(d_v, h_v, size * sizeof(float), cudaMemcpyHostToDevice);
 //   //cudaMemcpy(d_w, h_w, size * sizeof(float), cudaMemcpyHostToDevice);
 //   float h_value_from_gpu;
 //   cudaMemcpy(&h_value_from_gpu, &d_x_global[195], sizeof(float), cudaMemcpyDeviceToHost);
//
 //   std::cerr << "dens fim" << (195) << ": " << (h_value_from_gpu) << std::endl;
 //}

//void copy_data_to_device_vel(int size, float *u, float *v, float *w, float *u0, float *v0, float *w0){
//    cudaMemcpy(d_u, u, size * sizeof(float), cudaMemcpyHostToDevice);
//    cudaMemcpy(d_v, v, size * sizeof(float), cudaMemcpyHostToDevice);
//    cudaMemcpy(d_w, w, size * sizeof(float), cudaMemcpyHostToDevice);
//    cudaMemcpy(d_u0, u0, size * sizeof(float), cudaMemcpyHostToDevice);
//    cudaMemcpy(d_v0, v0, size * sizeof(float), cudaMemcpyHostToDevice);
//    cudaMemcpy(d_w0, w0, size * sizeof(float), cudaMemcpyHostToDevice);
//}

//void copy_data_to_host(int size, float *h_x, float *u, float *v, float *w) {
//    cudaMemcpy(h_x, d_x_global, size * sizeof(float), cudaMemcpyDeviceToHost);
//    cudaMemcpy(u, d_u, size * sizeof(float), cudaMemcpyDeviceToHost);
//    cudaMemcpy(v, d_v, size * sizeof(float), cudaMemcpyDeviceToHost);
//    cudaMemcpy(w, d_w, size * sizeof(float), cudaMemcpyDeviceToHost);
//}

//void copy_data_to_host_vel(int size, float *u, float *v, float *w){
//    cudaMemcpy(u, d_u, size * sizeof(float), cudaMemcpyDeviceToHost);
//    cudaMemcpy(v, d_v, size * sizeof(float), cudaMemcpyDeviceToHost);
//    cudaMemcpy(w, d_w, size * sizeof(float), cudaMemcpyDeviceToHost);
//}

// Kernel para adicionar fontes
__global__ void add_source_kernel(int size, float *x, const float *s, float dt) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < size) {
        x[idx] += dt * s[idx];
    }
}

void add_source_cuda(int M, int N, int O, float *x, const float *s, float dt) {
    int size = (M + 2) * (N + 2) * (O + 2);

    // Alocar memória no dispositivo
    //float *d_x, *d_s;
    //cudaMalloc(&d_x, size * sizeof(float));
    //cudaMalloc(&d_s, size * sizeof(float));

    // Copiar dados para o dispositivo
    //cudaMemcpy(d_u, x, size * sizeof(float), cudaMemcpyHostToDevice);
    //cudaMemcpy(d_v, s, size * sizeof(float), cudaMemcpyHostToDevice);

    // Configuração de threads e blocos
    int threadsPerBlock = 256;
    int blocksPerGrid = (size + threadsPerBlock - 1) / threadsPerBlock;

    // Executar o kernel
    add_source_kernel<<<blocksPerGrid, threadsPerBlock>>>(size, x, s, dt);
    cudaDeviceSynchronize();

    // Copiar dados de volta para o host
    //cudaMemcpy(x, d_u, size * sizeof(float), cudaMemcpyDeviceToHost);

    // Liberar memória do dispositivo
    //cudaFree(d_x);
    //cudaFree(d_s);
}


// Kernel para ajustar as condições de contorno
__global__ void set_bnd_kernel(int M, int N, int O, int b, float *x) {
    int i = blockIdx.x * blockDim.x + threadIdx.x + 1;
    int j = blockIdx.y * blockDim.y + threadIdx.y + 1;

    // Ajustar as faces
    if (i <= M && j <= N) {
        x[IX(i, j, 0)] = (b == 3) ? -x[IX(i, j, 1)] : x[IX(i, j, 1)];
        x[IX(i, j, O + 1)] = (b == 3) ? -x[IX(i, j, O)] : x[IX(i, j, O)];
        x[IX(0, i, j)] = (b == 1) ? -x[IX(1, i, j)] : x[IX(1, i, j)];
        x[IX(M + 1, i, j)] = (b == 1) ? -x[IX(M, i, j)] : x[IX(M, i, j)];
        x[IX(i, 0, j)] = (b == 2) ? -x[IX(i, 1, j)] : x[IX(i, 1, j)];
        x[IX(i, N + 1, j)] = (b == 2) ? -x[IX(i, N, j)] : x[IX(i, N, j)];
    }

    // Configurar os cantos (somente thread 0 para evitar redundância)
    if (i == 1 && j == 1) {
        x[IX(0, 0, 0)] = 0.33f * (x[IX(1, 0, 0)] + x[IX(0, 1, 0)] + x[IX(0, 0, 1)]);
        x[IX(M + 1, 0, 0)] = 0.33f * (x[IX(M, 0, 0)] + x[IX(M + 1, 1, 0)] + x[IX(M + 1, 0, 1)]);
        x[IX(0, N + 1, 0)] = 0.33f * (x[IX(1, N + 1, 0)] + x[IX(0, N, 0)] + x[IX(0, N + 1, 1)]);
        x[IX(M + 1, N + 1, 0)] = 0.33f * (x[IX(M, N + 1, 0)] + x[IX(M + 1, N, 0)] + x[IX(M + 1, N + 1, 1)]);
    }
}


void set_bnd_cuda(int M, int N, int O, int b, float *x) {
    //int size = (M + 2) * (N + 2) * (O + 2);

    // Alocar memória no dispositivo
    //float *d_x;
    //cudaMalloc(&d_x, size * sizeof(float));

    // Copiar dados para o dispositivo
    //cudaMemcpy(d_x, x, size * sizeof(float), cudaMemcpyHostToDevice);

    // Configuração de threads e blocos
    dim3 threadsPerBlock(16, 16);
    dim3 numBlocks((M + threadsPerBlock.x - 1) / threadsPerBlock.x,
                   (N + threadsPerBlock.y - 1) / threadsPerBlock.y);

    // Executar o kernel
    set_bnd_kernel<<<numBlocks, threadsPerBlock>>>(M, N, O, b, x);

    // Sincronizar para garantir a execução
    cudaDeviceSynchronize();

    // Copiar dados de volta para o host
    //cudaMemcpy(x, d_x, size * sizeof(float), cudaMemcpyDeviceToHost);

    // Liberar memória do dispositivo
    //cudaFree(d_x);
}


__device__ float atomicMaxFloat(float *address, float val) {
    int *address_as_int = (int *)address;
    int old = *address_as_int, assumed;

    do {
        assumed = old;
        old = atomicCAS(address_as_int, assumed,
                        __float_as_int(fmaxf(val, __int_as_float(assumed))));
    } while (assumed != old);

    return __int_as_float(old);
}

//__device__ double atomicMaxDouble(double* address, double val) {
//    unsigned long long* address_as_ull = (unsigned long long*)address;
//    unsigned long long old = *address_as_ull, assumed;
//
//    do {
//        assumed = old;
//        old = atomicCAS(address_as_ull, assumed, __double_as_longlong(fmax(val, __longlong_as_double(assumed))));
//    } while (assumed != old);
//
//    return __longlong_as_double(old);
//}

//__global__ void lin_solve_red_kernel_optimized(int M, int N, int O, float *x, const float *x0, float a, float c, float *max_c) {
//    extern __shared__ float local_max[]; // Memória partilhada
//    int k = blockIdx.z * blockDim.z + threadIdx.z + 1;
//    int j = blockIdx.y * blockDim.y + threadIdx.y + 1;
//    int i = blockIdx.x * blockDim.x + threadIdx.x + 1;
//
//    int local_idx = threadIdx.x + threadIdx.y * blockDim.x + threadIdx.z * blockDim.x * blockDim.y;
//    float max_local_change = 0.0f;
//
//    if ((k + j) % 2 == 0 && i <= M && j <= N && k <= O) {
//        int idx = CUDA_IX(i, j, k, M, N);
//        float old_x = x[idx];
//        float new_x = (x0[idx] +
//                      a * (x[CUDA_IX(i - 1, j, k, M, N)] + x[CUDA_IX(i + 1, j, k, M, N)] +
//                           x[CUDA_IX(i, j - 1, k, M, N)] + x[CUDA_IX(i, j + 1, k, M, N)] +
//                           x[CUDA_IX(i, j, k - 1, M, N)] + x[CUDA_IX(i, j, k + 1, M, N)])) / c;
//
//        x[idx] = new_x;
//        max_local_change = fabsf(new_x - old_x);
//    }
//
//    // Redução warp-level para encontrar o máximo local
//    for (int offset = warpSize / 2; offset > 0; offset /= 2) {
//        max_local_change = fmaxf(max_local_change, __shfl_down_sync(0xFFFFFFFF, max_local_change, offset));
//    }
//
//    // Apenas uma thread por warp armazena o valor no local_max
//    if (threadIdx.x % warpSize == 0) {
//        local_max[local_idx / warpSize] = max_local_change;
//    }
//    __syncthreads();
//
//    // Redução no bloco utilizando memória partilhada
//    if (threadIdx.x < blockDim.x) {
//        max_local_change = 0.0f;
//        for (int idx = threadIdx.x; idx < blockDim.x * blockDim.y * blockDim.z / warpSize; idx += blockDim.x) {
//            max_local_change = fmaxf(max_local_change, local_max[idx]);
//        }
//        local_max[threadIdx.x] = max_local_change;
//    }
//    __syncthreads();
//
//    // A thread 0 atualiza o max_c global
//    if (threadIdx.x == 0 && threadIdx.y == 0 && threadIdx.z == 0) {
//        //atomicMaxFloat(max_c, local_max[0]);
//        atomicMaxDouble((double*)max_c, (double)local_max[0]);
//    }
//}



// Kernel para a fase vermelha
__global__ void lin_solve_red_kernel(int M, int N, int O, float *x, const float *x0, float a, float c, float *max_c) {
    extern __shared__ float local_max[]; // Memória compartilhada para o bloco
    int k = blockIdx.z * blockDim.z + threadIdx.z + 1;
    int j = blockIdx.y * blockDim.y + threadIdx.y + 1;
    int i = blockIdx.x * blockDim.x + threadIdx.x + 1;

    int local_idx = threadIdx.x + threadIdx.y * blockDim.x + threadIdx.z * blockDim.x * blockDim.y;
    local_max[local_idx] = 0.0f; // Inicializar o máximo local

    if ((k + j) % 2 == 0 && i <= M && j <= N && k <= O) {
        int idx = CUDA_IX(i, j, k, M, N);
        float old_x = x[idx];
        x[idx] = (x0[idx] +
                  a * (x[CUDA_IX(i - 1, j, k, M, N)] + x[CUDA_IX(i + 1, j, k, M, N)] +
                       x[CUDA_IX(i, j - 1, k, M, N)] + x[CUDA_IX(i, j + 1, k, M, N)] +
                       x[CUDA_IX(i, j, k - 1, M, N)] + x[CUDA_IX(i, j, k + 1, M, N)])) / c;

        float change = fabsf(x[idx] - old_x);
        local_max[local_idx] = change; // Armazenar mudança local
    }

    __syncthreads();

    // Redução dentro do bloco para encontrar o máximo local
    for (int stride = blockDim.x * blockDim.y * blockDim.z / 2; stride > 0; stride /= 2) {
        if (local_idx < stride) {
            local_max[local_idx] = fmaxf(local_max[local_idx], local_max[local_idx + stride]);
        }
        __syncthreads();
    }

    // Thread 0 atualiza o valor global de max_c
    if (local_idx == 0) {
        atomicMaxFloat(max_c, local_max[0]); // Atualização atômica
        //atomicMaxDouble((double*)max_c, (double)local_max[0]);
    }
}

//__global__ void lin_solve_black_kernel_optimized(int M, int N, int O, float *x, const float *x0, float a, float c, float *max_c) {
//    extern __shared__ float local_max[]; // Memória partilhada
//    int k = blockIdx.z * blockDim.z + threadIdx.z + 1;
//    int j = blockIdx.y * blockDim.y + threadIdx.y + 1;
//    int i = blockIdx.x * blockDim.x + threadIdx.x + 1;
//
//    int local_idx = threadIdx.x + threadIdx.y * blockDim.x + threadIdx.z * blockDim.x * blockDim.y;
//    float max_local_change = 0.0f;
//
//    if ((k + j) % 2 != 0 && i <= M && j <= N && k <= O) {
//        int idx = CUDA_IX(i, j, k, M, N);
//        float old_x = x[idx];
//        float new_x = (x0[idx] +
//                      a * (x[CUDA_IX(i - 1, j, k, M, N)] + x[CUDA_IX(i + 1, j, k, M, N)] +
//                           x[CUDA_IX(i, j - 1, k, M, N)] + x[CUDA_IX(i, j + 1, k, M, N)] +
//                           x[CUDA_IX(i, j, k - 1, M, N)] + x[CUDA_IX(i, j, k + 1, M, N)])) / c;
//
//        x[idx] = new_x;
//        max_local_change = fabsf(new_x - old_x);
//    }
//
//    // Redução warp-level para encontrar o máximo local
//    for (int offset = warpSize / 2; offset > 0; offset /= 2) {
//        max_local_change = fmaxf(max_local_change, __shfl_down_sync(0xFFFFFFFF, max_local_change, offset));
//    }
//
//    // Apenas uma thread por warp armazena o valor no local_max
//    if (threadIdx.x % warpSize == 0) {
//        local_max[local_idx / warpSize] = max_local_change;
//    }
//    __syncthreads();
//
//    // Redução no bloco utilizando memória partilhada
//    if (threadIdx.x < blockDim.x) {
//        max_local_change = 0.0f;
//        for (int idx = threadIdx.x; idx < blockDim.x * blockDim.y * blockDim.z / warpSize; idx += blockDim.x) {
//            max_local_change = fmaxf(max_local_change, local_max[idx]);
//        }
//        local_max[threadIdx.x] = max_local_change;
//    }
//    __syncthreads();
//
//    // A thread 0 atualiza o max_c global
//    if (threadIdx.x == 0 && threadIdx.y == 0 && threadIdx.z == 0) {
//        atomicMaxFloat(max_c, local_max[0]);
//    }
//}


// Kernel para a fase preta
__global__ void lin_solve_black_kernel(int M, int N, int O, float *x, const float *x0, float a, float c, float *max_c) {
    extern __shared__ float local_max[];
    int k = blockIdx.z * blockDim.z + threadIdx.z + 1;
    int j = blockIdx.y * blockDim.y + threadIdx.y + 1;
    int i = blockIdx.x * blockDim.x + threadIdx.x + 1;

    int local_idx = threadIdx.x + threadIdx.y * blockDim.x + threadIdx.z * blockDim.x * blockDim.y;
    local_max[local_idx] = 0.0f;

    if ((k + j) % 2 != 0 && i <= M && j <= N && k <= O) {
        int idx = CUDA_IX(i, j, k, M, N);
        float old_x = x[idx];
        x[idx] = (x0[idx] +
                  a * (x[CUDA_IX(i - 1, j, k, M, N)] + x[CUDA_IX(i + 1, j, k, M, N)] +
                       x[CUDA_IX(i, j - 1, k, M, N)] + x[CUDA_IX(i, j + 1, k, M, N)] +
                       x[CUDA_IX(i, j, k - 1, M, N)] + x[CUDA_IX(i, j, k + 1, M, N)])) / c;

        float change = fabsf(x[idx] - old_x);
        local_max[local_idx] = change;
    }

    __syncthreads();

    for (int stride = blockDim.x * blockDim.y * blockDim.z / 2; stride > 0; stride /= 2) {
        if (local_idx < stride) {
            local_max[local_idx] = fmaxf(local_max[local_idx], local_max[local_idx + stride]);
        }
        __syncthreads();
    }

    if (local_idx == 0) {
        atomicMaxFloat(max_c, local_max[0]);
        //atomicMaxDouble((double*)max_c, (double)local_max[0]);
    }
}


void lin_solve_cuda(int M, int N, int O, int b, float *x, float *x0, float a, float c, float *d_max_c_global, float *d_max_c2_global) {
    //int size = (M + 2) * (N + 2) * (O + 2);

    // Alocar memória no dispositivo
    //float *d_x, *d_x0, *d_max_c, *d_max_c2;
    //cudaMalloc(&d_x, size * sizeof(float));
    //cudaMalloc(&d_x0, size * sizeof(float));
    //cudaMalloc(&d_max_c, sizeof(float));
    //cudaMalloc(&d_max_c2, sizeof(float));

    // Copiar dados para o dispositivo
    //cudaMemcpy(d_x_global, x, size * sizeof(float), cudaMemcpyHostToDevice);
    //cudaMemcpy(d_x0_global, x0, size * sizeof(float), cudaMemcpyHostToDevice);

    // Configuração de blocos e grids
    dim3 threadsPerBlock(8,8,8);
    dim3 numBlocks((M + threadsPerBlock.x - 1) / threadsPerBlock.x,
                   (N + threadsPerBlock.y - 1) / threadsPerBlock.y,
                   (O + threadsPerBlock.z - 1) / threadsPerBlock.z);

    float tol = 1e-7;
    int iterations = 0, max_iter = 20;
    float max_c_host = 0.0f;
    float max_c2_host = 0.0f;
    do {
        //max_c_host = 0.0f;
        //max_c2_host = 0.0f;
        //cudaMemcpy(d_max_c, &max_c_host, sizeof(float), cudaMemcpyHostToDevice);
        //cudaMemcpy(d_max_c2, &max_c2_host, sizeof(float), cudaMemcpyHostToDevice);

        cudaMemset(d_max_c_global, 0, sizeof(float));
        cudaMemset(d_max_c2_global, 0, sizeof(float));

        // Fase vermelha
        lin_solve_red_kernel<<<numBlocks, threadsPerBlock, threadsPerBlock.x * threadsPerBlock.y * threadsPerBlock.z * sizeof(float)>>>(M, N, O, x, x0, a, c, d_max_c_global);
        cudaDeviceSynchronize();

        // Fase preta
        lin_solve_black_kernel<<<numBlocks, threadsPerBlock, threadsPerBlock.x * threadsPerBlock.y * threadsPerBlock.z * sizeof(float)>>>(M, N, O, x, x0, a, c, d_max_c2_global);
        cudaDeviceSynchronize();

        // Copiar max_c de volta para o host
        cudaMemcpy(&max_c_host, d_max_c_global, sizeof(float), cudaMemcpyDeviceToHost);
        cudaMemcpy(&max_c2_host, d_max_c2_global, sizeof(float), cudaMemcpyDeviceToHost);

        iterations++;
    } while ((max_c_host > tol || max_c2_host > tol) && iterations < max_iter);

    // Copiar dados de volta para o host
    //cudaMemcpy(x, d_x_global, size * sizeof(float), cudaMemcpyDeviceToHost);

    // Liberar memória do dispositivo
    //cudaFree(d_x);
    //cudaFree(d_x0);
    //cudaFree(d_max_c);
    //cudaFree(d_max_c2);
}



void diffuse(int M, int N, int O, int b, float *x, float *x0, float diff, float dt, float *d_max_c_global, float *d_max_c2_global) {
  int max = MAX(MAX(M, N), O);
  float a = dt * diff * max * max;
  lin_solve_cuda(M, N, O, b, x, x0, a, 1 + 6 * a, d_max_c_global, d_max_c2_global);
}


// Kernel para realizar a advecção
__global__ void advect_kernel(int M, int N, int O, int b, float *d, const float *d0, const float *u, const float *v, const float *w, float dt) {
    int k = blockIdx.z * blockDim.z + threadIdx.z + 1;
    int j = blockIdx.y * blockDim.y + threadIdx.y + 1;
    int i = blockIdx.x * blockDim.x + threadIdx.x + 1;

    if (i <= M && j <= N && k <= O) {
        int curr = CUDA_IX(i, j, k, M, N);

        float x = i - dt * M * u[curr];
        float y = j - dt * N * v[curr];
        float z = k - dt * O * w[curr];

        // Clamp os valores para dentro do domínio
        x = fminf(fmaxf(x, 0.5f), M + 0.5f);
        y = fminf(fmaxf(y, 0.5f), N + 0.5f);
        z = fminf(fmaxf(z, 0.5f), O + 0.5f);

        int i0 = (int)x, i1 = i0 + 1;
        int j0 = (int)y, j1 = j0 + 1;
        int k0 = (int)z, k1 = k0 + 1;

        float s1 = x - i0, s0 = 1 - s1;
        float t1 = y - j0, t0 = 1 - t1;
        float u1 = z - k0, u0 = 1 - u1;

        d[curr] =
            s0 * (t0 * (u0 * d0[CUDA_IX(i0, j0, k0, M, N)] + u1 * d0[CUDA_IX(i0, j0, k1, M, N)]) +
                  t1 * (u0 * d0[CUDA_IX(i0, j1, k0, M, N)] + u1 * d0[CUDA_IX(i0, j1, k1, M, N)])) +
            s1 * (t0 * (u0 * d0[CUDA_IX(i1, j0, k0, M, N)] + u1 * d0[CUDA_IX(i1, j0, k1, M, N)]) +
                  t1 * (u0 * d0[CUDA_IX(i1, j1, k0, M, N)] + u1 * d0[CUDA_IX(i1, j1, k1, M, N)]));
    }
}

void advect_cuda(int M, int N, int O, int b, float *d, const float *d0, const float *u, const float *v, const float *w, float dt) {
    //int size = (M + 2) * (N + 2) * (O + 2);

    // Alocar memória no dispositivo
    //float *d_d, *d_d0, *d_u, *d_v, *d_w;
    //cudaMalloc(&d_d, size * sizeof(float));
    //cudaMalloc(&d_d0, size * sizeof(float));
    //cudaMalloc(&d_u, size * sizeof(float));
    //cudaMalloc(&d_v, size * sizeof(float));
    //cudaMalloc(&d_w, size * sizeof(float));

    // Copiar dados para o dispositivo
    //cudaMemcpy(d_p, d, size * sizeof(float), cudaMemcpyHostToDevice);
    //cudaMemcpy(d_div, d0, size * sizeof(float), cudaMemcpyHostToDevice);
    //cudaMemcpy(d_u, u, size * sizeof(float), cudaMemcpyHostToDevice);
    //cudaMemcpy(d_v, v, size * sizeof(float), cudaMemcpyHostToDevice);
    //cudaMemcpy(d_w, w, size * sizeof(float), cudaMemcpyHostToDevice);

    // Configuração de blocos e threads
    dim3 threadsPerBlock(8, 8, 8);
    dim3 numBlocks((M + threadsPerBlock.x - 1) / threadsPerBlock.x,
                   (N + threadsPerBlock.y - 1) / threadsPerBlock.y,
                   (O + threadsPerBlock.z - 1) / threadsPerBlock.z);

    // Executar o kernel
    advect_kernel<<<numBlocks, threadsPerBlock>>>(M, N, O, b, d, d0, u, v, w, dt);
    cudaDeviceSynchronize();

    // Copiar dados de volta para o host
    //cudaMemcpy(d, d, size * sizeof(float), cudaMemcpyDeviceToHost);

    // Liberar memória do dispositivo
    //cudaFree(d_d);
    //cudaFree(d_d0);
    //cudaFree(d_u);
    //cudaFree(d_v);
    //cudaFree(d_w);

    // Aplicar as condições de contorno
    set_bnd_cuda(M, N, O, b, d);
}

                         


// Kernel para calcular a divergência e inicializar p
__global__ void calculate_divergence_and_initialize_p(int M, int N, int O, float *u, float *v, float *w, float *p, float *div) {
    int k = blockIdx.z * blockDim.z + threadIdx.z + 1;
    int j = blockIdx.y * blockDim.y + threadIdx.y + 1;
    int i = blockIdx.x * blockDim.x + threadIdx.x + 1;

    if (i <= M && j <= N && k <= O) {
        int idx = CUDA_IX(i, j, k, M, N);
        div[idx] = -0.5f * ((u[CUDA_IX(i + 1, j, k, M, N)] - u[CUDA_IX(i - 1, j, k, M, N)]) +
                            (v[CUDA_IX(i, j + 1, k, M, N)] - v[CUDA_IX(i, j - 1, k, M, N)]) +
                            (w[CUDA_IX(i, j, k + 1, M, N)] - w[CUDA_IX(i, j, k - 1, M, N)])) / M;
        p[idx] = 0;
    }
}

// Kernel para corrigir u, v, w usando p
__global__ void correct_velocity(int M, int N, int O, float *u, float *v, float *w, float *p) {
    int k = blockIdx.z * blockDim.z + threadIdx.z + 1;
    int j = blockIdx.y * blockDim.y + threadIdx.y + 1;
    int i = blockIdx.x * blockDim.x + threadIdx.x + 1;

    if (i <= M && j <= N && k <= O) {
        int idx = CUDA_IX(i, j, k, M, N);
        u[idx] -= 0.5f * (p[CUDA_IX(i + 1, j, k, M, N)] - p[CUDA_IX(i - 1, j, k, M, N)]);
        v[idx] -= 0.5f * (p[CUDA_IX(i, j + 1, k, M, N)] - p[CUDA_IX(i, j - 1, k, M, N)]);
        w[idx] -= 0.5f * (p[CUDA_IX(i, j, k + 1, M, N)] - p[CUDA_IX(i, j, k - 1, M, N)]);
    }
}

// Função principal para realizar a projeção
void project_cuda(int M, int N, int O, float *u, float *v, float *w, float *d_u, float *d_v, float *d_max_c_global, float *d_max_c2_global) {
    //int size = (M + 2) * (N + 2) * (O + 2);

    // Alocar memória no dispositivo
    //float *d_u, *d_v, *d_w, *d_p, *d_div;
    //cudaMalloc(&d_u, size * sizeof(float));
    //cudaMalloc(&d_v, size * sizeof(float));
    //cudaMalloc(&d_w, size * sizeof(float));
    //cudaMalloc(&d_p, size * sizeof(float));
    //cudaMalloc(&d_div, size * sizeof(float));

    // Copiar dados para o dispositivo
    //cudaMemcpy(d_u, u, size * sizeof(float), cudaMemcpyHostToDevice);
    //cudaMemcpy(d_v, v, size * sizeof(float), cudaMemcpyHostToDevice);
    //cudaMemcpy(d_w, w, size * sizeof(float), cudaMemcpyHostToDevice);

    // Configuração de blocos e threads
    dim3 threadsPerBlock(8, 8, 8);
    dim3 numBlocks((M + threadsPerBlock.x - 1) / threadsPerBlock.x,
                   (N + threadsPerBlock.y - 1) / threadsPerBlock.y,
                   (O + threadsPerBlock.z - 1) / threadsPerBlock.z);

    // Calcular divergência e inicializar p
    calculate_divergence_and_initialize_p<<<numBlocks, threadsPerBlock>>>(M, N, O, u, v, w, d_u, d_v);
    cudaDeviceSynchronize();

    // Aplicar condições de contorno para div e p
    set_bnd_cuda(M, N, O, 0, d_v);
    set_bnd_cuda(M, N, O, 0, d_u);

    // Resolver o sistema linear para p
    lin_solve_cuda(M, N, O, 0, d_u, d_v, 1, 6, d_max_c_global, d_max_c2_global);

    // Corrigir u, v, w
    correct_velocity<<<numBlocks, threadsPerBlock>>>(M, N, O, u, v, w, d_u);
    cudaDeviceSynchronize();

    // Aplicar condições de contorno para u, v, w
    set_bnd_cuda(M, N, O, 1, u);
    set_bnd_cuda(M, N, O, 2, v);
    set_bnd_cuda(M, N, O, 3, w);

    // Copiar dados de volta para o host
    //cudaMemcpy(u, d_u, size * sizeof(float), cudaMemcpyDeviceToHost);
    //cudaMemcpy(v, d_v, size * sizeof(float), cudaMemcpyDeviceToHost);
    //cudaMemcpy(w, d_w, size * sizeof(float), cudaMemcpyDeviceToHost);

    // Liberar memória do dispositivo
    //cudaFree(d_u);
    //cudaFree(d_v);
    //cudaFree(d_w);
    //cudaFree(d_p);
    //cudaFree(d_div);
}


// Step function for density
void dens_step(int M, int N, int O, float *x, float *x0, float *u, float *v, float *w, float diff, float dt, float *d_max_c_global, float *d_max_c2_global) {
    //add_source_cuda(M, N, O, x, x0, dt);
    //diffuse(M, N, O, 0, x0, x, diff, dt);
    //SWAP(x0, x);
    //advect_cuda(M, N, O, 0, x, x0, u, v, w, dt);
  //int size = (M + 2) * (N + 2) * (O + 2);
  //allocate_device_memory(size);

  //copy_data_to_device(size,x,x0,u,v,w);
  
  add_source_cuda(M, N, O, x, x0, dt);

  //SWAP(x0, x);
  diffuse(M, N, O, 0, x0, x, diff, dt, d_max_c_global, d_max_c2_global);

  //SWAP(x0, x);
  advect_cuda(M, N, O, 0, x, x0, u, v, w, dt);

  //copy_data_to_host(size,x);

  //free_device_memory();
}


void diffuse_3(int M, int N, int O, int b1, int b2, int b3, float *x, float *x0, float *y, float *y0, float *z, float *z0, float diff, float dt, float *d_max_c_global, float *d_max_c2_global) {
    float a = dt * diff * O * O;

    lin_solve_cuda(M, N, O, b1, x, x0, a, 1 + 6 * a, d_max_c_global, d_max_c2_global);
           
    lin_solve_cuda(M, N, O, b2, y, y0, a, 1 + 6 * a, d_max_c_global, d_max_c2_global);
 
    lin_solve_cuda(M, N, O, b3, z, z0, a, 1 + 6 * a, d_max_c_global, d_max_c2_global);
}


void advect_3(int M, int N, int O, int b1,int b2, int b3, float *d1, float *d2, float *d3, float *u, float *v, float *w, float dt) {
  float dtX = dt * M, dtY = dt * N, dtZ = dt * O;

  #pragma omp parallel for 
  for (int k = 1; k <= M; k++) {
    for (int j = 1; j <= N; j++) {
      for (int i = 1; i <= O; i++) {



        int curr = IX(i,j,k);
        float x = i - dtX * u[curr];
        float y = j - dtY * v[curr];  // i
        float z = k - dtZ * w[curr];

        // Clamp to grid boundaries
        if (x < 0.5f)
          x = 0.5f;
        if (x > M + 0.5f)
          x = M + 0.5f;
        if (y < 0.5f)
          y = 0.5f;
        if (y > N + 0.5f)
          y = N + 0.5f;
        if (z < 0.5f)
          z = 0.5f;
        if (z > O + 0.5f)
          z = O + 0.5f;

        int i0 = (int)x, i1 = i0 + 1;
        int j0 = (int)y, j1 = j0 + 1; // i
        int k0 = (int)z, k1 = k0 + 1;

        float s1 = x - i0, s0 = 1 - s1;
        float t1 = y - j0, t0 = 1 - t1; // i
        float u1 = z - k0, u0 = 1 - u1;

        d1[curr] =
            s0 * (t0 * (u0 * u[IX(i0, j0, k0)] + u1 * u[IX(i0, j0, k1)]) +
                  t1 * (u0 * u[IX(i0, j1, k0)] + u1 * u[IX(i0, j1, k1)])) +  // i
            s1 * (t0 * (u0 * u[IX(i1 ,j0, k0)] + u1 * u[IX(i1, j0, k1)]) +
                  t1 * (u0 * u[IX(i1, j1, k0)] + u1 * u[IX(i1, j1, k1)]));




        d2[curr] =
            s0 * (t0 * (u0 * v[IX(i0, j0, k0)] + u1 * v[IX(i0, j0, k1)]) +
                  t1 * (u0 * v[IX(i0, j1, k0)] + u1 * v[IX(i0, j1, k1)])) +  // i
            s1 * (t0 * (u0 * v[IX(i1 ,j0, k0)] + u1 * v[IX(i1, j0, k1)]) +
                  t1 * (u0 * v[IX(i1, j1, k0)] + u1 * v[IX(i1, j1, k1)]));

        d3[curr] =
            s0 * (t0 * (u0 * w[IX(i0, j0, k0)] + u1 * w[IX(i0, j0, k1)]) +
                  t1 * (u0 * w[IX(i0, j1, k0)] + u1 * w[IX(i0, j1, k1)])) + // i
            s1 * (t0 * (u0 * w[IX(i1 ,j0, k0)] + u1 * w[IX(i1, j0, k1)]) +
                  t1 * (u0 * w[IX(i1, j1, k0)] + u1 * w[IX(i1, j1, k1)]));

      }
    }

    set_bnd_cuda(M, N, O, b1, d1);

    set_bnd_cuda(M, N, O, b2, d3);

    set_bnd_cuda(M, N, O, b3, d3);
  }

}


// Step function for velocity
void vel_step(int M, int N, int O, float *u, float *v, float *w, float *u0, float *v0, float *w0, float visc, float dt, float *d_max_c_global, float *d_max_c2_global) {
  //int size = (M + 2) * (N + 2) * (O + 2);
  //allocate_device_memory(size);
  
 // add_source_3(M, N, O, u, u0, v, v0, w, w0, dt);

  //copy_data_to_device_vel(size,u,v,w,u0,v0,w0);

  add_source_cuda(M,N,O,u,u0,dt);
  add_source_cuda(M,N,O,v,v0,dt);
  add_source_cuda(M,N,O,w,w0,dt);

  diffuse_3(M, N, O, 1, 2, 3, u0, u, v0, v, w0, w, visc, dt, d_max_c_global, d_max_c2_global);

  project_cuda(M, N, O, u0, v0, w0, u, v, d_max_c_global, d_max_c2_global);

  advect_cuda(M,N,O,1,u,u0,u0,v0,w0,dt);
  advect_cuda(M,N,O,2,v,v0,u0,v0,w0,dt);
  advect_cuda(M,N,O,3,w,w0,u0,v0,w0,dt);

  project_cuda(M, N, O, u, v, w, u0, v0, d_max_c_global, d_max_c2_global);

  //copy_data_to_host_vel(size,u,v,w);

  //free_device_memory();
}



