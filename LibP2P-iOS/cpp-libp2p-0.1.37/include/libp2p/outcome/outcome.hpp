/**
 * Copyright Quadrivium LLC
 * All Rights Reserved
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <boost/outcome/result.hpp>

#include <system_error>
#include <type_traits>
#include <typeinfo>
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

#define _LIBP2P_ERROR_CODE_MESSAGE(E, ns, e) std::string ns errorCodeMessage(E e)
#define _LIBP2P_MAKE_ERROR_CODE(E)                                           \
  inline std::error_code make_error_code(const E &e) {                       \
    return {static_cast<int>(e), ::libp2p::outcome::EnumErrorCategory<E>::get()}; \
  }
#define _LIBP2P_ENUM_ERROR_CODE(friend_, E)           \
  friend_ inline _LIBP2P_ERROR_CODE_MESSAGE(E, , e);  \
  friend_ _LIBP2P_MAKE_ERROR_CODE(E)                  \
  friend_ inline _LIBP2P_ERROR_CODE_MESSAGE(E, , e)
#define Q_ENUM_ERROR_CODE(E) _LIBP2P_ENUM_ERROR_CODE(, E)
#define Q_ENUM_ERROR_CODE_FRIEND(E) _LIBP2P_ENUM_ERROR_CODE(friend, E)
#define _OUTCOME_HPP_DECLARE_ERROR(friend_, E) \
  friend_ _LIBP2P_ERROR_CODE_MESSAGE(E, , );   \
  friend_ _LIBP2P_MAKE_ERROR_CODE(E)
#define OUTCOME_HPP_DECLARE_ERROR(ns, E) \
  namespace ns {                         \
    _OUTCOME_HPP_DECLARE_ERROR(, E)      \
  }
#define OUTCOME_CPP_DEFINE_CATEGORY(ns, E, e) _LIBP2P_ERROR_CODE_MESSAGE(E, ns::, e)

namespace libp2p::outcome {
  template <typename E>
  concept IsEnumErrorCode =
      std::is_enum_v<E> and requires { errorCodeMessage(E{}); };

  template <IsEnumErrorCode E>
  class EnumErrorCategory final : public std::error_category {
   public:
    const char *name() const noexcept final {
      return typeid(E).name();
    }
    std::string message(int code) const final {
      return errorCodeMessage(static_cast<E>(code));
    }
    static const EnumErrorCategory<E> &get() {
      static const EnumErrorCategory<E> category;
      return category;
    }
  };
}  // namespace libp2p::outcome

template <libp2p::outcome::IsEnumErrorCode E>
struct std::is_error_code_enum<E> : std::true_type {};

namespace outcome {
  template <class R>
  using result = boost::outcome_v2::result<R>;
  using boost::outcome_v2::failure;
  using boost::outcome_v2::success;
}  // namespace outcome
