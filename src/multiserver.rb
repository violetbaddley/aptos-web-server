#!/usr/bin/env jruby
# encoding: utf-8


#
# System Requires
%w( java socket pathname ).each {|dep| require dep }


#
# Set a few constants. The $CLASSPATH is what the jruby jar uses to load our files.
WHERE_AM_I = Pathname.new( File.dirname( File.expand_path(__FILE__) ) )
$CLASSPATH << WHERE_AM_I.to_s
TOTE = Encoding::UTF_8  # that is, The Only Text Encoding.


#
# Load in the helping classes.
%w( httphandler persistentconnection loblog
    mime/types categories/integer+wrapping  ).each {|dep| require_relative dep }
    # Mime-types is by Austin Ziegler and Mark Overmeer (https://github.com/halostatue/mime-types).

java_import 'Configuration'   # By Greg Gagne, as far as I can tell.



#
# Lazily load the category on MultiServer
# (extra methods in separate file to clean up this one.)
autoload :MultiServer, 'config+bootstrap'




#
# “The use of persistent
# connections places no requirements on the length (or existence) of
# [some] time-out for either the client or the server....
# A client, server, or proxy MAY close the transport connection at any
# time.”
#                                           - RFC 2616, p. 46..7.
# 
# Fuck yes, crazy strict timeouts here-we-come!
#





#
# The Main Class
# which accepts and dispatches requests.
# 
class MultiServer
    
    
    
    #
    # Some Class Constants:
    Name = "Aptos"  # This is not up for configuration.
    HandlerClass = HTTPHandler
    Dispatch = java.util.concurrent.Executors.newCachedThreadPool
    Cleanup = java.util.concurrent.Executors.newSingleThreadExecutor
    ConnectionActivityTimeout = 10  # seconds
    LogDebug = ARGV.include?('-log-debug')
    
    
    
    
    #
    # Called to get the server up-and-running.
    def self.serve_with_handler handler
        
        port = handler.service_port
        socket = TCPServer.new port
        puts "Server up on #{port}.\n^C to quit."
        logger.status "Server up on #{port}"
    
        connectionCount = 0
    
        loop do
            
            #
            # Listen for connection
            client = socket.accept
            
            connectionCount = connectionCount.succ_wrap
            cNum = connectionCount  # to avoid global overwrite
            logger.debug "Accepted connection #{cNum}"
            
            #
            # Create an activity tracker for this connection.
            persistence = PersistentConnection.new(cNum, Cleanup, client)
            
            #
            # Send it off to be handled.
            task = Dispatch.submit  do
                handler.process(client, persistence)
            end
            
            #
            # Bind the java future (`task`) to the tracker (this is threadsafe)
            # and schedule the tracker for pruning.
            persistence.future = task
            Cleanup.execute persistence  # Schedule for pruning
        
        end
    
    
    
    rescue Errno::EACCES => accessError
        $stderr.puts "The server was disallowed from listening on port #{handler.service_port}."
        btrace = accessError.backtrace * "\n"
        logblob = "#{accessError}\n#{btrace}".each_line.map{|aLine| "    " + aLine.chomp }.join("\n")
        logger.error "Permission denied for port #{handler.service_port}:\n#{logblob}"
    
    rescue StandardError => eep
        # Don't let it get suppressed by the ensure block.
        raise eep
    
    ensure
        # All the nice things that should happen, if possible.
        # Hitting ^C, however, bypasses all of this.
        logger.status "Server gracefully down."
        socket.close rescue nil
        dispatch.shutdown rescue nil
    
    end
    
    
    
end


















MultiServer.ready_set_go!




# Light the match, that lights the torch, that...



