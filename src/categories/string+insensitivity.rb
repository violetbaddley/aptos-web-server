# encoding: utf-8


#
# Category on String
# which allows more convenient checking of case-insensitive equality.

class String
    def eql_igncase? other
        # Behaves like java's String#equalsIgnoreCase;
        # or like Ruby's String#casecmp, except that it returns false for nil-comparison.
        return false unless other.class == self.class
        self.casecmp other
    end
end
