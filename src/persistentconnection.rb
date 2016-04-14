# encoding: utf-8
require 'thread'
autoload :MultiServer, 'config+bootstrap'




#
# PersistentConnection
# binds a task Future (from java.util.concurrent) to a timestamp
# and a client connection stream.
# 
# The Future acts as proxy for the active connection. The connection
# code itself updates its PersistentConnection'slast access to 
# identify itself as active.
# 
# Finally, a PersistentConnection is itself a Runnable. It's meant to
# be scheduled in a single-thread queue (MultiServer::Cleanup).
# See `run()` below for details.
# 

class PersistentConnection
    
    attr_reader :connection_id
    
    
    #
    # Initializer which takes a cleanup Executor as argument (among others).
    def initialize cid, cleanup=MultiServer::Cleanup, io_sock=nil
        @future = nil
        @last_acc = Time.new
        @connection_id = cid.to_i
        @io_stream = io_sock
        
        @cleaner_upper = cleanup
        @access_lock = Mutex.new
        @future_lock = @access_lock  # no need to make too many locks where one will do.
    end
    
    
    
    #
    # The age since last update, in seconds.
    def age
        @access_lock.synchronize do
            return Time.new - @last_acc
        end
    end
    
    
    
    #
    # Update the access time of this connection to the present moment
    # (or at least the present moment as of the time the lock is available).
    def bump_access
        @access_lock.synchronize do
            @last_acc = Time.new
        end
    end
    
    
    
    #
    # Runs the provided block, synchronized against other accesses to the receiver.
    # Since you cannot call #age from within the block (obviously), and using this
    # method may block for a non-trivial amount of time, the block is passed the age
    # of the connection as a single argument.
    def do_timesync
        @access_lock.synchronize do
            ageNow = Time.new - @last_acc
            yield ageNow
        end
    end
    
    
    
    #
    # Returns the associated Future.
    def future
        @future_lock.synchronize do
            return @future
        end
    end
    
    
    #
    # Sets the associated future. Note that this method is only effectual
    # the first time it's called on a particular object.
    def future= new_fut
        @future_lock.synchronize do
            return unless @future.nil?
            @future = new_fut
            
            @future_lock = NullMutex::SharedNullMutex
            # The future will have been safely set exactly once, and all future calls
            # will bounce off ineffectually. Thus we no longer need to
            # synchronize access to @future (it is itself threadsafe).
        end
    end
    
    
    
    
    
    #
    # Run the clean-up/pruning procedure for stale connections.
    # 
    # This method makes PersistentConnections Runnable. When called, it sleeps
    # until it thinks there's a chance that its connection has timed out. At that
    # point, it checks and either kills its IO stream, or schedules itself again
    # on its executor to wait again for timeout.
    # 
    # This would work on a multi-threaded pool. However, since connections are
    # accepted serially (and scheduled serially for cleanup), and since there is
    # a constant timeout for all connections, it is most efficient and still
    # completely effective to run PersistentConnection timeouts in a serial queue.
    # If you don't believe me, run aptos with the -log-debug flag, and look at
    # the log file. You'll see tasks being pruned consistently just after the
    # specified 10-second timeout window.
    # 
    # Specifying the java_signature makes this code runnable from native javaland,
    # and lets JRuby convince the outside world that PersistentConnection conforms to Runnable.
    # 
    java_signature 'void run()'
    def run
        
        #
        # Wait until likely timeout:
        timeLeft = MultiServer::ConnectionActivityTimeout - self.age
        sleep(timeLeft) if timeLeft > 0
        
        #
        # After waiting, check to see if done.
        dispatchFuture = self.future
        unless dispatchFuture.nil?
            
            # If dispatchFuture is nil, it hasn't been set yet, so
            # we should reschedule ourselves for later.
            
            #
            # Are we done? Copacetic. Log and return.
            if dispatchFuture.isDone
                MultiServer.logger.debug "Connection #{@connection_id} is already disconnected."
                return
            end
            
            #
            # Are we timed out? Kill the IO stream.
            if self.age >= MultiServer::ConnectionActivityTimeout
                MultiServer.logger.debug "Connection #{@connection_id} is stale (#{self.age}s) and will be pruned."
                @io_stream.close rescue nil
                return
            end
            
        end
        
        #
        # If dispatchFuture is nil, or we didn't finish and timed out,
        # we need to reschedule on our executor (provided on initialization).
        MultiServer.logger.debug "Connection #{@connection_id} still alive; will come back later."
        @cleaner_upper.execute self
    end
    
    
    
end





class NullMutex
    # Not a real mutex.
    
    def synchronize
        yield
    end
    
    SharedNullMutex = NullMutex.new
end
