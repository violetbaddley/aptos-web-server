# encoding: utf-8



#
# Category on Pathname which allows checking
# whether some other path should be contained within the receiver's directory.

class Pathname
    def include? otherpath
        raise ArgumentError.new "Paths must be absolute to test containance." unless self.absolute? && otherpath.absolute?
        unless otherpath.respond_to?(:ascend) && otherpath.respond_to?(:cleanpath)
            otherpath = Pathname.new(otherpath)
        end
        
        otherpath = otherpath.cleanpath(false)  # False means we don't consider parents of symlinks.
        otherpath.ascend do |pname|
            return true if self == pname
        end
        
        false  # We are not equal to any directory in otherpath's ancestors.
    end
end

