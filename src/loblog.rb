# encoding: utf-8

%w( logger time ).each {|dep| require dep }
autoload :MultiServer, 'multiserver'





#
# A LobLog logs blobs to the LobLog log.
# Utilizes Ruby's standard Logger.
class LobLog
    
    # A trusted source (http://stackoverflow.com/questions/4660264/is-rubys-stdlib-logger-class-thread-safe#answer-4660331)
    # suggests that standard Logger is threadsafe.
    
    
    
    #
    # Make and configure a LobLog in a particular location.
    def initialize logfile
        super()
        @lob = Logger.new logfile
        @lob.level = if MultiServer::LogDebug  then Logger::DEBUG  else Logger::INFO  end
        
        @lob.formatter = proc do |severity, datetime, progname, msg|
            # Replace bracket placeholder with date string.
            # Bug: replaces first bracket placeholder, so date must
            # appear before a path which contains such a token.
            msg.sub('[]', "[#{datetime.httpdate}]") + "\n"
        end
    end
    
    
    
    #
    # LobLog.logblob is a better-sounding synonym for LobLog.new
    def self.logblob logfile
        self.new logfile
    end
    
    
    
    #
    # Log a transfer (usu. successful).
    def transfer client_addr, request, status, bytes
        @lob.info "#{client_addr} [] \"#{request}\" #{status} #{bytes}"
    end
    
    
    
    #
    # Log a transfer error (extracting relevant info from the error itself).
    def transfer_error http_stderr
        request_info = http_stderr.request
        if request_info.nil?
            @lob.info "Error [] unspecified-request #{http_stderr.reason_code} ?"
            return
        end
        
        @lob.info "#{request_info.client} [] \"#{request_info.complete_request}\" #{http_stderr.reason_code} #{http_stderr.generic_response.bytesize}"
    end
    
    
    
    
    #
    # Log server-level status change.
    def status msg
        @lob.info "Status []: #{msg}"
    end
    
    
    
    
    #
    # Log a real bad error.
    def error msg, addr=nil
        @lob.error "Error #{addr ? addr+' ' : ''}[]: #{msg}"
    end
    
    
    #
    # Log a super suspicious warning.
    def warn msg
        @lob.warn "Warning []: #{msg}"
    end
    
    
    
    #
    # Log a debug message. This is a noöp by default,
    # unless turned on via the -log-debug flag.
    def debug msg
        @lob.debug "Debug []: #{msg}"
    end
    
end
