# encoding: utf-8

%w( java cgi ).each {|dep| require dep }
%w( httperrors httphandler categories/string+insensitivity ).each {|dep| require_relative dep }





#
# HTTPRequest reads a request from the client and parses it
# for easy access by other components. It treats the header as a
# dictionary where all entries are more-or-less optional, while
# also providing direct methods to access some of the common ones.
class HTTPRequest
    
    attr_reader :complete_request, :verb, :resource, :http_version, :extra_args, :client
    # path and connection type are provided dynamically.
    
    TokenSeparators = [ "(", ")", "<", ">", "@",
                        ",", ";", ":", "\\",'"',
                        "/", "[", "]", "?", "=",
                        "{", "}", " ", "\t"      ]  # per RFC 2616 p.17
    
    
    
    
    #
    # Takes an i/o stream and reads from it until a complete HTTP
    # request has been given (denoted by 2xCRLF), and returns that request.
    # This method reserves the right to raise EOFError when the stream is exhausted.
    # It will also raise if there was no valid request.
    def self.from io_stream
        
        # This method could use a hell of a lot more smarts to prevent overflow attacks.
        # Read from stream, then pass the buck.
        
        compound = ""
        
        loop do
            thisline = io_stream.readline("\r\n")  # Read, breaking on CRLF
            compound << thisline
            break if thisline.chomp == ''  # end of request
        end
        
        # Make new instance; let initializer handle the rest.
        # peeraddr(:numeric)[2] gets the ip address of the client. Yeah, that makes sense...
        return new(compound, io_stream.peeraddr(:numeric)[2])
        
        
    end
    
    
    
    
    
    
    #
    # Takes a complete text block and reads the HTTP request from it.
    # Raises an appropriate error if there was no valid request.
    def initialize text, client_ip=nil
        
        
        @client = client_ip ? client_ip : ""
        @complete_request = ''
        @verb = ''
        @resource = ''
        @http_version = [0,0]
        @extra_args = {}
        
        
        # if text is nil at this point, we will leave it at a stub request
        # for debugging purposes.
        return if text.nil?
        
        
        #
        # Separate and chomp each line into array.
        headlines = text.each_line("\r\n").map{|line| line.chomp }.to_a
        
        #
        # Rip off the first line and store it as complete request
        requestLine = headlines.shift
        @complete_request = requestLine
        
        #
        # Split request line.
        requestComponents = requestLine.split(/ /)  # split on single-space exactly.
        raise HTTPStandardError.new(400, self) unless requestComponents.count == 3  # Bad Request
        
        # We now know there are three parts to the request line.
        @verb, @resource, versionString = requestComponents
        raise HTTPStandardError.new(501, self) unless HTTPHandler::ImplementedVerbs.include?(@verb)  # Not Implemented
        raise HTTPStandardError.new(400, self) unless @resource.length > 0 && @resource[0] == '/'
        
        @http_version = version_from versionString
        
        #
        # Having gotten the request, parse the additional information:
        headlines.each do |messageHeader|
            next if messageHeader.length == 0
            
            #
            # Split leading token from the rest.
            headParts = messageHeader.split(':', 2)  # Limit split to 2 pcs. b/c rest may contain colons
            raise HTTPStandardError.new(400, self) unless headParts.count == 2
            
            #
            # We take all keys as lowercase, and disallow any key
            # which contains a Token Separator.
            fieldName, fieldValue = headParts
            fieldName.downcase! ;  fieldValue.strip!
            TokenSeparators.each {|sep| raise HTTPStandardError 400 if fieldName.include?(sep) }
            
            #
            # Add to dictionary.
            if @extra_args[fieldName]
                # Field already specified; comma-append the new value:
                @extra_args[fieldName] = "#{@extra_args[fieldName]},#{fieldValue}"
            else
                @extra_args[fieldName] = fieldValue
            end
        end
        
    end
    
    
    
    
    
    #
    # Decodes a filesystem-appropriate path from the URI path,
    # by unescaping %xx entities.
    def path
        CGI::unescape @resource
    end
    
    
    
    #
    # The "Connection:" type
    def connection_type
        @extra_args["connection"]  # the options are downcased as they're added.
    end
    
    
    
    #
    # Determines whether the request is keep-alive type or close type.
    # If either one is listed explicitly, it is used.
    # Otherwise, the HTTP version is used to pick a sensible default.
    def should_keep_alive
        # Explicit:
        return true if 'keep-alive'.eql_igncase? connection_type
        return false if 'close'.eql_igncase? connection_type
        
        # Otherwise, we have to guess:
        # (the UFO operator does lexical array comparison, positive if @ht_v > 1.1)
        (@http_version <=> [1,1]) >= 0
    end
    
    
    
    #
    # For printing/logging/debugging...
    def inspect
        argsPretty = @extra_args.each.map{|key, vahl| "\t#{key}: #{vahl}" }.join("\n")
        return "From #{@client}\n\t#{@complete_request}\n#{argsPretty}"
    end
    
    
    
    
    private
    
    #
    # Returns a 2-tuple array from the specification string:
    # "1.1" --> [1, 1];   "-2.0.9 fish" --> error 400
    def version_from specification
        
        #
        # Require exactly one slash.
        parts = specification.split('/')
        raise HTTPStandardError.new(400, self) unless parts.count == 2
        
        protocol, version = parts
        
        #
        # Require HTTP and a 2-int version separated by .
        raise HTTPStandardError.new(400, self) unless protocol == "HTTP"
        versionParts = version.split('.')
        raise HTTPStandardError.new(400, self) unless versionParts.count == 2
        versionParts = versionParts.map do |part|
            # Throw up if anything other than a nonnegative integer is found on either side of the point.
            raise HTTPStandardError.new(400, self) if part.match(/[^\d]/)
            part.to_i
        end
        
        return versionParts
    end
    
    
end




