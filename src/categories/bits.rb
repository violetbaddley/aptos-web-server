# encoding: utf-8


#
# Some platform-dependent bitwise constants.
# 

PLATFORM_BITS = 0.size * 8
FIXNUM_MAX = 2 ** (0.size * 8 - 2) - 1
FIXNUM_MIN = -(FIXNUM_MAX + 1)

HALF_ROT_MASK = (1 << (PLATFORM_BITS / 2)) - 1

