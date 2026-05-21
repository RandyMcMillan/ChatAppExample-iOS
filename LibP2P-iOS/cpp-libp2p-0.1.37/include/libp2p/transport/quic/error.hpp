/**
 * Copyright Quadrivium LLC
 * All Rights Reserved
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <system_error>
#include <string>
#include <type_traits>

namespace libp2p {
  enum class QuicError {
    HANDSHAKE_FAILED,
    CONN_CLOSED,
    STREAM_CLOSED,
    TOO_MANY_STREAMS,
    CANT_CREATE_CONNECTION,
    CANT_OPEN_STREAM,
  };

  class QuicErrorCategory final : public std::error_category {
   public:
    const char *name() const noexcept final {
      return "libp2p.quic";
    }
    std::string message(int code) const final {
      switch (static_cast<QuicError>(code)) {
        case QuicError::HANDSHAKE_FAILED:
          return "HANDSHAKE_FAILED";
        case QuicError::CONN_CLOSED:
          return "CONN_CLOSED";
        case QuicError::STREAM_CLOSED:
          return "STREAM_CLOSED";
        case QuicError::TOO_MANY_STREAMS:
          return "TOO_MANY_STREAMS";
        case QuicError::CANT_CREATE_CONNECTION:
          return "CANT_CREATE_CONNECTION";
        case QuicError::CANT_OPEN_STREAM:
          return "CANT_OPEN_STREAM";
      }
      return "UNKNOWN";
    }
  };

  inline const std::error_category &quicErrorCategory() {
    static const QuicErrorCategory category;
    return category;
  }

  inline std::error_code make_error_code(QuicError error) {
    return {static_cast<int>(error), quicErrorCategory()};
  }
}  // namespace libp2p

template <>
struct std::is_error_code_enum<libp2p::QuicError> : std::true_type {};
