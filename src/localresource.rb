# encoding: utf-8

%w( thread java ).each {|dep| require dep }
%w( httperrors ).each {|dep| require_relative dep }
%w( java.util.WeakHashMap java.util.Collections ).each {|dep| java_import dep }

autoload :MultiServer, 'config+bootstrap'





#
# Arbitrates HTTP requests with disk file access.
# The standard procedure is to call LocalResource.from
# with an HTTPRequest.
# Then call file_segments, which fetches the referred-to document
# from disk or from the cache.
class LocalResource
    
    attr_reader :equivalent_pathname, :file_size
    
    # the actual cache:
    @@resources = Collections.synchronizedMap(WeakHashMap.new)
    
    
    
    # 
    # Class Methods:
    class << self
        attr_accessor :documentRoot, :defaultDocument, :directoryDefault
        
        
        #
        # Read the request from the given io stream
        # and return a new LocalResource representing it.
        # (May be a cached instance).
        def for request
            desiredPath = actual_path_for request
            
            # Check & populate cache:
            desiredResource = @@resources.get desiredPath
            if desiredResource.nil?
                desiredResource = new(request, desiredPath)
                @@resources.put(desiredPath, desiredResource)
            end
            
            desiredResource
        end
        
        
        
        #
        # Determines the actual, on-disk path for the request.
        # Raises appropriate HTTP Errors if there was a problem doing so.
        def actual_path_for request
            path = request.path
        
            if path == '/'
                path = defaultDocument  # use default
            else
                # we know that the path has a leading slash (pre-verified in HTTPRequest),
                # but we need to strip that off.
                path = path[1..-1]
            end
            
            #
            # Check for any obvious problems with the path not being in the document root.
            abspath = documentRoot + path
            raise HTTPStandardError.new(403, request) unless documentRoot.include? abspath
            
            #
            # Now look up the actual file (resolving symlinks) and check it against the root dir again.
            abspath = abspath.realpath  # May raise ENOENT.
            raise HTTPStandardError.new(403, request) unless documentRoot.include? abspath
            
            return abspath
        
        
        rescue StandardError, Errno::ENOENT
            # Nerp. Just couldn't find it.
            raise HTTPStandardError.new(404, request)
        end
        
        
        
    end  #class methods
    
    
    
    
    
    # 
    # Set up a particular LocalResource. A LocalResource has no knowledge
    # of the global cache, but is rather owned by that cache.
    # It does, however, have knowledge of its own file and the cached data
    # for it.
    def initialize with_request, abspath=nil
        abspath ||= self.class.actual_path_for( request )
        
        @equivalent_pathname = abspath
        @file_size = File.size(abspath)
        @cached_data = "".force_encoding(Encoding::ASCII_8BIT)  # best native approx. of raw data bucket.
        @cache_complete = false
        @cachelock = Mutex.new
        
        #
        # Open in read-binary mode. This is to confirm that we can do so.
        # If the file data are cacheable, we leave the file open until we
        # explicitly read from it (which also reads into the cache).
        # If they are not cacheable, we will re-open the file every time,
        # so we should close it here.
        @io_stream = abspath.open('rb')
        @io_stream.close if too_big_to_cache
        
        
    rescue StandardError => openationError
        # If the file could not be opened, we need to handle the error here,
        # by trying the directory default document.
        
        raise openationError if self.class.directoryDefault.nil?
        
        relpath = with_request.path[1..-1]; relpath ||= ''
        abspath = (self.class.documentRoot + relpath + self.class.directoryDefault).realpath
        raise HTTPStandardError.new(403, with_request) unless self.class.documentRoot.include? abspath
        
        # Much of this is the same as above, but for the directory default.
        @equivalent_pathname = abspath
        @file_size = File.size(abspath)
        @io_stream = abspath.open('rb')
        @io_stream.close if too_big_to_cache
        
    end
    
    
    def too_big_to_cache
        @file_size > 1000000  # 1 MB
    end
    
    
    
    #
    # Yields segments of the represented file to provided block.
    # In practice, entire file is usually yielded in one segment,
    # but this may not be true for larger files.
    def file_segments
        
        
        if too_big_to_cache
            #
            # Case 1.
            # Too big. We never attempted to cache it.
            # Treat as a vanilla transfer.
            
            real_io_stream = @equivalent_pathname.open('rb')
            begin
                loop do
                    yield real_io_stream.readpartial(4096)  # disk block size
                end
            rescue EOFError
                # expected, to break from loop
            ensure
                real_io_stream.close
            end
            
            
            
        elsif (@cachelock.synchronize { @cache_complete })
            #
            # Case 2.
            # File is cached already. All reads should proceed through the cache
            # and no longer need to be synchronized.
            
            yield @cached_data
            
            MultiServer.logger.debug "File #{@equivalent_pathname} yielded from cache."
            
            
        else
            #
            # Case 3.
            # The file is cacheable, but has not yet been cached.
            # Glom the whole thing, cache it, and yield the result.
            
            segf = ""
            @cachelock.synchronize do
                
                begin
                    @cached_data = @io_stream.read
                    @cache_complete = true
                    
                rescue StandardError => to_err
                    @cached_data = nil
                    raise to_err
                ensure
                    @io_stream.close rescue nil
                end
                
            end
            
            yield @cached_data
            
            
            
        end
        
        
        
    end  #file_segments
    
    
    
    
    
    
    
    
    
end



