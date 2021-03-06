#include "caffe2/operators/tanh_op.h"

#include <algorithm>
#include <functional>

#include "caffe2/core/context_gpu.h"

namespace caffe2 {

namespace {

template <typename T>
__global__ void TanhCUDAKernel(const int N, const T* X, T* Y) {
  CUDA_1D_KERNEL_LOOP(i, N) {
#if __CUDA_ARCH__ >= 350
    Y[i] = tanh(__ldg(X + i));
#else
    Y[i] = tanh(X[i]);
#endif
  }
}

template <typename T>
__global__ void
TanhGradientCUDAKernel(const int N, const T* dY, const T* Y, T* dX) {
  CUDA_1D_KERNEL_LOOP(i, N) {
#if __CUDA_ARCH__ >= 350
    dX[i] = __ldg(dY + i) * (T(1) - __ldg(Y + i) * __ldg(Y + i));
#else
    dX[i] = dY[i] * (T(1) - Y[i] * Y[i]);
#endif
  }
}

} // namespace

template <>
template <typename T>
bool TanhFunctor<CUDAContext>::
operator()(const int N, const T* X, T* Y, CUDAContext* context) const {
  TanhCUDAKernel<T>
      <<<CAFFE_GET_BLOCKS(N),
         CAFFE_CUDA_NUM_THREADS,
         0,
         context->cuda_stream()>>>(N, X, Y);
  return true;
}

template <>
template <typename T>
bool TanhGradientFunctor<CUDAContext>::Forward(
    const std::vector<int>& dY_dims,
    const std::vector<int>& /* Y_dims */,
    const T* dY,
    const T* Y,
    T* dX,
    CUDAContext* context) const {
  const int size = std::accumulate(
      dY_dims.cbegin(), dY_dims.cend(), 1, std::multiplies<int>());
  TanhGradientCUDAKernel<T>
      <<<CAFFE_GET_BLOCKS(size),
         CAFFE_CUDA_NUM_THREADS,
         0,
         context->cuda_stream()>>>(size, dY, Y, dX);
  return true;
}

REGISTER_CUDA_OPERATOR(
    Tanh,
    UnaryElementwiseOp<
        TensorTypes<float>,
        CUDAContext,
        TanhFunctor<CUDAContext>>);
REGISTER_CUDA_OPERATOR(
    TanhGradient,
    BinaryElementwiseOp<
        TensorTypes<float>,
        CUDAContext,
        TanhGradientFunctor<CUDAContext>>);

} // namespace caffe2
