/**
 * Copyright Quadrivium LLC
 * All Rights Reserved
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <boost/outcome/result.hpp>

#include <system_error>
#include <utility>

#define LIBP2P_OUTCOME_JOIN2(a, b) a##b
#define LIBP2P_OUTCOME_JOIN(a, b) LIBP2P_OUTCOME_JOIN2(a, b)
#define LIBP2P_OUTCOME_UNIQUE_NAME(prefix) LIBP2P_OUTCOME_JOIN(prefix, __COUNTER__)

#define _OUTCOME_TRY_void(tmp, expr)    \
  auto &&tmp = expr;                    \
  if (tmp.has_error()) {                \
    return std::move(tmp).as_failure(); \
  }
#define _BOOST_OUTCOME_TRY(tmp, out, expr) \
  _OUTCOME_TRY_void(tmp, expr) out = std::move(tmp).value()
#define BOOST_OUTCOME_TRY(out, expr) \
  _BOOST_OUTCOME_TRY(LIBP2P_OUTCOME_UNIQUE_NAME(outcome_res_), out, expr)
#define _OUTCOME_TRY_out(tmp, out, expr) \
  _BOOST_OUTCOME_TRY(tmp, auto &&out, expr)
#define _OUTCOME_OVERLOAD(_1, _2, s, ...) _OUTCOME_TRY_##s
#define OUTCOME_TRY(...) \
  _OUTCOME_OVERLOAD(__VA_ARGS__, out, void)(LIBP2P_OUTCOME_UNIQUE_NAME(outcome_res_), __VA_ARGS__)

namespace outcome {
  template <class R>
  using result = boost::outcome_v2::result<R>;
  using boost::outcome_v2::failure;
  using boost::outcome_v2::success;
}  // namespace outcome
