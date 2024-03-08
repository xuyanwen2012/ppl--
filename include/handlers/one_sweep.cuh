#pragma once

#include <spdlog/spdlog.h>

#include <cub/cub.cuh>

#include "cuda/helper.cuh"

struct OneSweepHandler {
  // need to match the ".cu" file
  static constexpr auto RADIX = 256;
  static constexpr auto RADIX_PASSES = 4;
  static constexpr auto BIN_PART_SIZE = 7680;
  static constexpr auto BIN_PARTS = 2;
  static constexpr auto GLOBAL_HIST_THREADS = 128;
  static constexpr auto BINNING_THREADS = 512;

  // ------------------------
  // Essential Data
  // ------------------------
  const size_t n;
  const size_t binning_blocks;

  unsigned int* u_sort;

  // ------------------------

  struct _IntermediateStorage {
    unsigned int* d_sort_alt;
    unsigned int* d_global_histogram;
    unsigned int* d_index;
    unsigned int* d_first_pass_histogram;
    unsigned int* d_second_pass_histogram;
    unsigned int* d_third_pass_histogram;
    unsigned int* d_fourth_pass_histogram;
  } im_storage;

  // on purpose, for future work (union the memories)
  using IntermediateStorage = _IntermediateStorage;

  OneSweepHandler() = delete;

  explicit OneSweepHandler(const size_t n)
      : n(n), binning_blocks(cub::DivideAndRoundUp(n, BIN_PART_SIZE)) {
    // Essential buffer that CPU/GPU both can access
    MALLOC_MANAGED(&u_sort, n);

    // Temporary data on device that CPU doesn't need to access
    MALLOC_DEVICE(&im_storage.d_sort_alt, n);
    MALLOC_DEVICE(&im_storage.d_global_histogram, RADIX * RADIX_PASSES);
    MALLOC_DEVICE(&im_storage.d_index, RADIX_PASSES);
    MALLOC_DEVICE(&im_storage.d_first_pass_histogram, RADIX * binning_blocks);
    MALLOC_DEVICE(&im_storage.d_second_pass_histogram, RADIX * binning_blocks);
    MALLOC_DEVICE(&im_storage.d_third_pass_histogram, RADIX * binning_blocks);
    MALLOC_DEVICE(&im_storage.d_fourth_pass_histogram, RADIX * binning_blocks);
    SYNC_DEVICE();

    spdlog::trace(
        "On constructor: OneSweepHandler, n: {}, binning_blocks: {}, ",
        n,
        binning_blocks);
  }

  OneSweepHandler(const OneSweepHandler&) = delete;
  OneSweepHandler& operator=(const OneSweepHandler&) = delete;
  OneSweepHandler(OneSweepHandler&&) = delete;
  OneSweepHandler& operator=(OneSweepHandler&&) = delete;

  ~OneSweepHandler() {
    CUDA_FREE(u_sort);
    CUDA_FREE(im_storage.d_sort_alt);
    CUDA_FREE(im_storage.d_global_histogram);
    CUDA_FREE(im_storage.d_index);
    CUDA_FREE(im_storage.d_first_pass_histogram);
    CUDA_FREE(im_storage.d_second_pass_histogram);
    CUDA_FREE(im_storage.d_third_pass_histogram);
    CUDA_FREE(im_storage.d_fourth_pass_histogram);

    spdlog::trace("On destructor: OneSweepHandler");
  }

  [[nodiscard]] size_t size() const { return n; }
  [[nodiscard]] const unsigned int* begin() const { return u_sort; }
  [[nodiscard]] unsigned int* begin() { return u_sort; }
  [[nodiscard]] const unsigned int* end() const { return u_sort + n; }
  [[nodiscard]] unsigned int* end() { return u_sort + n; }

  [[nodiscard]] const unsigned int* data() const { return u_sort; }
  [[nodiscard]] unsigned int* data() { return u_sort; }

  void attachStreamSingle(const cudaStream_t stream) const {
    ATTACH_STREAM_SINGLE(u_sort);
  }

  void attachStreamGlobal(const cudaStream_t stream) const {
    ATTACH_STREAM_GLOBAL(u_sort);
  }

  void attachStreamHost(const cudaStream_t stream) const {
    ATTACH_STREAM_HOST(u_sort);
    SYNC_STREAM(stream);
  }

  void clearMem() const {
    SET_MEM_2_ZERO(im_storage.d_global_histogram, RADIX * RADIX_PASSES);
    SET_MEM_2_ZERO(im_storage.d_index, RADIX_PASSES);
    SET_MEM_2_ZERO(im_storage.d_first_pass_histogram, RADIX * binning_blocks);
    SET_MEM_2_ZERO(im_storage.d_second_pass_histogram, RADIX * binning_blocks);
    SET_MEM_2_ZERO(im_storage.d_third_pass_histogram, RADIX * binning_blocks);
    SET_MEM_2_ZERO(im_storage.d_fourth_pass_histogram, RADIX * binning_blocks);
  }
};
