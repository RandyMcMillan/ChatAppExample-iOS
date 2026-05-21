/**
 * Copyright Quadrivium LLC
 * All Rights Reserved
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <array>
#include <algorithm>
#include <compare>
#include <cstdint>
#include <span>
#include <type_traits>
#include <utility>
#include <vector>

namespace libp2p::common {
  namespace detail {
#ifdef __APPLE__
    template <class I1, class I2, class Cmp>
    constexpr auto lexicographicalCompareThreeWay(
        I1 f1, I1 l1, I2 f2, I2 l2, Cmp comp) -> decltype(comp(*f1, *f2)) {
      using ret_t = decltype(comp(*f1, *f2));
      static_assert(std::disjunction_v<std::is_same<ret_t, std::strong_ordering>,
                        std::is_same<ret_t, std::weak_ordering>,
                        std::is_same<ret_t, std::partial_ordering>>,
          "The return type must be a comparison category type.");

      bool exhaust1 = (f1 == l1);
      bool exhaust2 = (f2 == l2);
      for (; !exhaust1 && !exhaust2;
           exhaust1 = (++f1 == l1), exhaust2 = (++f2 == l2)) {
        if (auto c = comp(*f1, *f2); c != 0) {
          return c;
        }
      }

      return !exhaust1 ? std::strong_ordering::greater
          : !exhaust2  ? std::strong_ordering::less
                       : std::strong_ordering::equal;
    }

#if !defined(__cpp_lib_three_way_comparison)
    struct compare_three_way {
      template <class T1, class T2>
      constexpr auto operator()(T1 &&lhs, T2 &&rhs) const
          noexcept(noexcept(std::forward<T1>(lhs) <=> std::forward<T2>(rhs))) {
        return std::forward<T1>(lhs) <=> std::forward<T2>(rhs);
      }

      using is_transparent = void;
    };
#else
    using compare_three_way = std::compare_three_way;
#endif

    template <class I1, class I2>
    constexpr auto lexicographicalCompareThreeWay(
        I1 f1, I1 l1, I2 f2, I2 l2) {
      return lexicographicalCompareThreeWay(
          f1, l1, f2, l2, compare_three_way{});
    }
#else
    using std::lexicographical_compare_three_way;
#endif
  }  // namespace detail

  /// Hash160 as a sequence of 20 bytes
  using Hash160 = std::array<uint8_t, 20u>;
  /// Hash256 as a sequence of 32 bytes
  using Hash256 = std::array<uint8_t, 32u>;
  /// Hash512 as a sequence of 64 bytes
  using Hash512 = std::array<uint8_t, 64u>;
}  // namespace libp2p::common

namespace libp2p {

  /// @brief convenience alias for arrays of bytes
  using Bytes = std::vector<uint8_t>;

  /// @brief convenience alias for immutable span of bytes
  using BytesIn = std::span<const uint8_t>;

  /// @brief convenience alias for mutable span of bytes
  using BytesOut = std::span<uint8_t>;

  template <class T>
  concept SpanOfBytes = std::is_same_v<std::decay_t<T>, BytesIn>
                     or std::is_same_v<std::decay_t<T>, BytesIn>;

  inline bool operator==(const SpanOfBytes auto &lhs,
                         const SpanOfBytes auto &rhs) {
    return std::equal(lhs.begin(), lhs.end(), rhs.begin(), rhs.end());
  }

  inline auto operator<=>(const SpanOfBytes auto &lhs,
                          const SpanOfBytes auto &rhs) {
    return libp2p::common::detail::lexicographicalCompareThreeWay(
        lhs.begin(), lhs.end(), rhs.begin(), rhs.end());
  }

}  // namespace libp2p
