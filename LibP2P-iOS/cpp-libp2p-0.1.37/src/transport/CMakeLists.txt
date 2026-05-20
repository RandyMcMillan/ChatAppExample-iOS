#
# Copyright Quadrivium LLC
# All Rights Reserved
# SPDX-License-Identifier: Apache-2.0
#

add_subdirectory(impl)
add_subdirectory(tcp)

if (LIBP2P_ENABLE_QUIC)
  add_subdirectory(quic)
endif ()
