# encoding: utf-8


module HTTPStatus
    
    KnownStatuses = {
        100 => "Continue",
        101 => "Switching Protocols",
        200 => "OK",
        201 => "Created",
        202 => "Accepted",
        203 => "Non-Authoritative Information",
        204 => "No Content",
        205 => "Reset Content",
        206 => "Partial Content",
        300 => "Multiple Choices",
        301 => "Moved Permanently",
        302 => "Found",
        303 => "See Other",
        304 => "Not Modified",
        305 => "Use Proxy",
        307 => "Temporary Redirect",
        400 => "Bad Request",
        401 => "Unauthorized",
        402 => "Payment Required",
        403 => "Forbidden",
        404 => "Not Found",
        405 => "Method Not Allowed",
        406 => "Not Acceptable",
        407 => "Proxy Authentication Required",
        408 => "Request Time-out",
        409 => "Conflict",
        410 => "Gone",
        411 => "Length Required",
        412 => "Precondition Failed",
        413 => "Request Entity Too Large",
        414 => "Request-URI Too Large",
        415 => "Unsupported Media Type",
        416 => "Requested range not satisfiable",
        417 => "Expectation Failed",
        500 => "Internal Server Error",
        501 => "Not Implemented",
        502 => "Bad Gateway",
        503 => "Service Unavailable",
        504 => "Gateway Time-out",
        505 => "HTTP Version not supported"
    }
    
    # I realize this is terrible design in terms of localization.
    # Let's just say there's room for it to be improved.
    GenericMessages = {
        403 => "Go away! You’re not allowed to look at [[PATH]]!",
        404 => "Whoa. I looked everywhere, but I totally couldn’t find [[PATH]].",
        408 => "Request timed out. Please try again---and be quick about it! (I haven’t got all the time in the world!)",
        500 => "Dammit. I totally fucked up this time. Sorry for the trouble; please try again.",
        501 => "I totally don’t know how to do that."
    }
    
    
    
    #
    # Generic responses are generated from this fixed template document.
    # 
    GenericDocumentTemplate = <<ALOHA
<!DOCTYPE html>
<html>

<head>
    <meta charset="UTF-8">
    <title>[[REASON]]</title>
</head>

<body>
    <h1>[[CODE]]: [[REASON]]</h1>
    <p>[[MESSAGE]]</p>
    <hr>
    <p style="color: #808080;">Aptos Server</p>
</body>

</html>

ALOHA
    GenericDocumentTemplate.force_encoding(TOTE)  # ...which is always utf-8.
    
end





#
# An error which can be raised
# and which can provide its own error response for the client.
class HTTPStandardError < ArgumentError
    
    #
    # Make an error for raising.
    def initialize reason_code, request=nil
        # The request path is assumed to be unprocessed (%xx)
        
        super(reason_code.to_s)
        @reason_code = reason_code.to_i
        @request = request
    end
    
    attr_reader :reason_code, :request
    
    
    #
    # The "message" is really what the specs call "reason phrase."
    def message
        httpReason = HTTPStatus::KnownStatuses[@reason_code]
        return httpReason ? httpReason : super
    end
    
    
    #
    # The extended message is a human-friendly suggestion beyond the reason phrase.
    def extended_message
        HTTPStatus::GenericMessages[@reason_code]
    end
    
    
    
    #
    # Construct a full response HTML page from the receiver,
    # returned as String.
    def generic_response
        pathname = @request ? @request.path : "the file"
        
        docuStr = HTTPStatus::GenericDocumentTemplate.dup
        docuStr.gsub!('[[CODE]]', @reason_code.to_s)
        docuStr.gsub!('[[REASON]]', self.message)
        
        extendedMessage = self.extended_message
        docuStr.gsub!('[[MESSAGE]]', (extendedMessage ? extendedMessage : ""))
        docuStr.gsub!('[[PATH]]', pathname)  # Swap in the given path if one appears in the message.
        
        docuStr
    end
    
    
    
    
end



