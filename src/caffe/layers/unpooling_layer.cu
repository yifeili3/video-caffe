#include <algorithm>
#include <cfloat>
#include <vector>

#include "caffe/util/math_functions.hpp"
#include "caffe/layers/unpooling_layer.hpp"

namespace caffe {

template <typename Dtype>
__global__ void MaxUnpoolForward(const int nthreads, const Dtype* bottom_data,
    const int num, const int channels, const int height,
    const int width, const int unpooled_height, const int unpooled_width,
    const int kernel_h, const int kernel_w, const int stride_h,
    const int stride_w, const int pad_h, const int pad_w, Dtype* top_data, const Dtype* bottom_mask) {
  CUDA_KERNEL_LOOP(index, nthreads) {
    int pw = index % width;
    int ph = (index / width) % height;
    int c = (index / width / height) % channels;
    int n = index / width / height / channels;
    top_data += (n * channels + c) * ph * pw;
    const int mask_index = bottom_mask[index];
    top_data[mask_index] = bottom_data[index]; 
  }
}

template <typename Dtype>
void UnpoolingLayer<Dtype>::Forward_gpu(const vector<Blob<Dtype>*>& bottom,
      const vector<Blob<Dtype>*>& top) {
  const Dtype* bottom_data = bottom[0]->gpu_data();
  int count = bottom[0]->count();
  Dtype* top_data = top[0]->mutable_gpu_data();
  caffe_gpu_set(top[0]->count(), Dtype(0.), top_data);
  // We'll get the mask from bottom[1] if it's of size >1.
  const Dtype* bottom_mask = NULL;
      bottom_mask = bottom[1]->gpu_data();
    // NOLINT_NEXT_LINE(whitespace/operators)
    MaxUnpoolForward<Dtype><<<CAFFE_GET_BLOCKS(count), CAFFE_CUDA_NUM_THREADS>>>(
        count, bottom_data, bottom[0]->num(), channels_,
        height_, width_, unpooled_height_, unpooled_width_, kernel_h_,
        kernel_w_, stride_h_, stride_w_, pad_h_, pad_w_, top_data, bottom_mask);
  CUDA_POST_KERNEL_CHECK;
}


template <typename Dtype>
__global__ void MaxUnpoolBackward(const int nthreads, const Dtype* top_diff,
    const Dtype* bottom_mask, const int num, const int channels,
    const int height, const int width, const int unpooled_height,
    const int unpooled_width, const int kernel_h, const int kernel_w,
    const int stride_h, const int stride_w, const int pad_h, const int pad_w,
    Dtype* bottom_diff) {
  CUDA_KERNEL_LOOP(index, nthreads) {
    // find out the local index
    // find out the local offset
    int pw = index % width;
    int ph = (index / width) % height;
    int c = (index / width / height) % channels;
    int n = index / width / height / channels;
    top_diff += (n * channels + c) * ph * pw;
    const int mask_index = bottom_mask[index];
    bottom_diff[index] = top_diff[mask_index]; 
  }
}


template <typename Dtype>
void UnpoolingLayer<Dtype>::Backward_gpu(const vector<Blob<Dtype>*>& top,
      const vector<bool>& propagate_down, const vector<Blob<Dtype>*>& bottom) {
  if (!propagate_down[0]) {
    return;
  }
  const Dtype* top_diff = top[0]->gpu_diff();
  Dtype* bottom_diff = bottom[0]->mutable_gpu_diff();
  const int count = bottom[0]->count();
  caffe_gpu_set(count, Dtype(0.), bottom_diff);
  // We'll get the mask from bottom[1] if it's of size >1.
  const Dtype* bottom_mask = NULL;
  bottom_mask = bottom[1]->gpu_data(); 
    // NOLINT_NEXT_LINE(whitespace/operators)
    MaxUnpoolBackward<Dtype><<<CAFFE_GET_BLOCKS(count), CAFFE_CUDA_NUM_THREADS>>>(
        count, top_diff, bottom_mask, top[0]->num(), channels_,
        height_, width_, unpooled_height_, unpooled_width_,
        kernel_h_, kernel_w_, stride_h_, stride_w_, pad_h_, pad_w_,
        bottom_diff);

  CUDA_POST_KERNEL_CHECK;
}


INSTANTIATE_LAYER_GPU_FUNCS(UnpoolingLayer);


}  // namespace caffe