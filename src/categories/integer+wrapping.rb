# encoding: utf-8
require_relative 'bits'


#
# Category on Integer
# which increments and wraps around to some maximum.

class Integer
    def succ_wrap maximum=FIXNUM_MAX
        # Default size will never create a Bignum.
        (self + 1) % maximum
    end
end




