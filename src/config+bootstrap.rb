# encoding: utf-8

require 'java'
java_import 'Configuration'

require_relative 'loblog'


class MultiServer
    # A category on the main MultiServer class.
    
    
    
    def self.ready_set_go!
        cfile = configuration_file_name
        unless cfile
            $stderr.puts usage_s
            return
        end
        configuration = get_config_from cfile
        set_logfile configuration[:logfile]

        # serve_with_handler HANDLER_CLASS.new(configuration)
        serve_with_handler HandlerClass.new(configuration)
        
        
    rescue ArgumentError => to_err
        $stderr.puts "Whoopsies!"
        $stderr.puts to_err.message
        
    end
    
    
    
    
    
    def self.logger
        @@logger
    end

    
    
    
    
    def self.configuration_file_name
        # This one's a try/catch doozy.
    
        # Append default config, in case none was specified.
        # argsToTry = ARGV + [ (WHERE_AM_I.parent + 'conf' + 'config.xml').to_s ]
        argsToTry = ARGV
    
        argsToTry.each do |gument|                  # For each command-line argument,
            next unless gument.end_with? '.xml'     # if an xml file,
            begin                                   # try
                File.open(gument) do |iost|         # to open the argument and
                    iost.getbyte                    # Read a byte to make sure it's possible.
                end
                                                    # It worked,
                return gument                       # so return it.
            
            rescue StandardError
                # Not this file. Keep trying?
            end
        end
    
        # None? That's a damn shame.
        nil
    end
    
    
    
    
    def self.usage_s
<<-END

    Usage: aptos /path/to/configuration.xml
    okie-dokie?
    
    You may also specify -log-debug to log mundane
    inner workings as well as general transfers.
END
    end
    
    
    
    
    def self.get_config_from cfile
        config = Configuration.new cfile
        
        return { :logfile => config.getLogFile,
            :documentRoot => config.getDocumentRoot,
            :defaultDocument => config.getDefaultDocument,
            :directoryDefaultDocument => config.getDirectoryDefaultDocument,
            :serverName => MultiServer::Name,  # Seriously, it's Aptos, not anything else.
            :port => config.getPortNumber }
            # Port may be nil, which is OK (defaults to 80 in HTTPHandler).
    
    rescue StandardError => to_err
        raise ArgumentError.new "The configuration file #{cfile} could not be interpreted."
    end
    
    
    
    
    private
    
    def self.set_logfile logf
        @@logger = LobLog.logblob(logf)
    end
    
    
    
    
end

