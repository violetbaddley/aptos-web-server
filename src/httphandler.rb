# encoding: utf-8

#
# Require up some prerequisites:
%w( java pathname ).each {|dep| require dep }
%w( categories/pathname+inclusion localresource mime/types
    loblog httperrors httprequest ).each {|dep| require_relative dep }

#
# And don't forget to lazy-load the parts of MultiServer
# that contain some app-level globals we need (like the logger).
autoload :MultiServer, 'config+bootstrap'



#
# Ah, probably the most important class of the server.
# HTTPHandler handles HTTP requests on its #process method.
# One single handler is usually created on startup.
class HTTPHandler
    
    #
    # We only know how to GET.
    ImplementedVerbs = ["GET"]
    
    
    #
    # Takes a dictionary built from the configuration file.
    # This pre-processing is done by MultiServer.
    def initialize config
        super()
        
        @port = config[:port]
        @documentRoot = Pathname.new( File.expand_path(config[:documentRoot]) ).realpath  # Make every effort for the precise path name.
        @defaultDocument = config[:defaultDocument]
        @directoryDefault = config[:directoryDefaultDocument]  ||  'index.html'
        @serverName = config[:serverName]
        
        #
        # This is really kludgey. I should make this less so.
        # Here we just tell LocalResource how to find certain important things.
        LocalResource.documentRoot = @documentRoot
        LocalResource.defaultDocument = @defaultDocument
        LocalResource.directoryDefault = @directoryDefault
    end
    
    
    
    #
    # The port on which HTTPHandler wants to serve.
    # Configurable.
    def service_port
        # if @port  then @port  else 80  end
        # Uncomment the above line in a real server,
        # and delete the following:
        
        if @port  then @port  else 2880  end
    end
    
    
    
    #
    # For convenience, we provide access to MultiServer's general logger.
    def logger
        MultiServer.logger
    end
    
    
    
    
    #
    # Handle a user request, from start to end.
    # Blocks on I/O, so cutting I/O aborts the method (somewhat-) gracefully.
    def process client, persistence
        readPath = nil
        connectionCount = persistence.connection_id
        
        loop do
            readPath = nil
            persistence.bump_access
            
            #
            # Get and parse request
            request = HTTPRequest.from client
            persistence.bump_access
            
            #
            # Acquire the referred-to file, either from disk or cache
            diskfile = LocalResource.for request
            
            readPath = diskfile.equivalent_pathname  # The disk path, not the user-requested one.
            filesize = diskfile.file_size
            mimeType = MIME::Types.type_for(readPath.extname).first  # may be nil if unrecognized
            
            #
            # Prepare the header
            allGood = 200
            headerString = "HTTP/1.1 #{allGood} #{HTTPStatus::KnownStatuses[allGood]}\r\n"
            headerString << "Server: #{@serverName}\r\n"
            headerString << "Content-Type: #{mimeType}\r\n"  if mimeType
            headerString << "Date: #{Time.new.httpdate}\r\n"  # Time..httpdate is my new favorite method.
            headerString << "Content-Length: #{filesize}\r\n"
            headerString << "Connection: keep-alive\r\n"
            headerString << "\r\n"
            
            #
            # Write the header & file to the client
            persistence.bump_access
            client.write headerString
            
            # Loop over all file chunks (if there are many):
            diskfile.file_segments do |databits|
                persistence.bump_access  # on every write
                client.write databits
            end
            
            
            #
            # Log the transfer, including debug string mentioning connection Nº
            logger.transfer client.peeraddr(:numeric)[2], request.complete_request, allGood, filesize
            logger.debug "Transfer of #{request.resource} done on connection #{connectionCount}."
            
            #
            # Keep Alive?
            break unless request.should_keep_alive
        end
        
        
        logger.debug "Connection #{connectionCount} finished explicitly."
        
        
    
    rescue HTTPStandardError => hterr
        # Numbered error which we should write back to the client.
        write_error hterr, client
        logger.debug "HTTP Standard Error on connection #{connectionCount}."
        
    rescue EOFError => eep
        # Most likely, client closed connection prematurely.
        
    rescue SocketError, IOError, Errno::EPIPE => eep
        # Something's wrong with the connection.
        # We'll assume it was the client's doing and just let ensure clean things up.
        bactria = eep.backtrace.map{|line| "\t" + line }.join("\n")
        logger.debug "#{eep.class.name} on #{readPath} (connection #{connectionCount})\n#{bactria}"
        
    rescue StandardError => all_others
        # Something unexpected happened. This goes in the log file for sure.
        log_ruby_error all_others, client
        
    ensure
        client.close rescue nil
        logger.debug "Last diskfile and socket connection probably closed for connection #{connectionCount}."
        
    end
    
    
    
    
    
    
    
    private
    
    
    
    #
    # There was a runtime error, which we need to log.
    def log_ruby_error to_err, client
        logger.error(to_err.to_s.lines.first, client.peeraddr(:numeric)[2])
    end
    
    
    
    #
    # There was a standard, handle-able HTTP error,
    # which we will write back to the client.
    def write_error hterr, to_client
        logger.transfer_error hterr
        
        # Construct header
        responseHeader = "HTTP/1.1 #{hterr.reason_code} #{hterr.message}\r\n"
        responseHeader << "Server: #{@serverName}\r\n"
        responseHeader << "Content-Type: text/html\r\n"
        responseHeader << "Date: #{Time.new.httpdate}\r\n"
        
        # Gather response page (built-in)
        responsePage = hterr.generic_response
        responseHeader << "Content-Length: #{responsePage.bytesize}\r\n"
        responseHeader << "Connection: close\r\n"
        responseHeader << "\r\n"
        
        # Write them back.
        begin
            to_client.write responseHeader
            to_client.write responsePage
            
        rescue SocketError, IOError => err
            # Eh, whatever.
        rescue StandardError, Errno => err
            # Hm, we should log this.
            log_ruby_error err, to_client
        end
        
    end
    
    
    
    
    
    
end


