# Because switching to git is hard, and being able to use the same
# transport we already use for puppet to do deployment is a nice thing.
#
# Requires subversion ruby bindings be installed
# These are provided by the following packages:
#   subversion-ruby (Enterprise Linux and derivitives) 
#   libsvn-ruby (Debian and derivitives)
require "svn/core"
require "svn/client"
require "svn/wc"
require "svn/repos"
# File utilities and find
require "fileutils"
require "find"

module MCollective
  module Agent
    # An agent for interacting with subversion over mcollective
    class Subversion<RPC::Agent
      metadata    :name   => "subversion",
                  :description  => "Plugin for interacting with Subversion",
                  :author   => "Nick Cammorato <nick.cammorato@gmail.com>",
                  :license  => "BSD",
                  :version  => "0.1",
                  :url      => "http://www.terc.edu",
                  :timeout  => 300
                  
      ["info", "status", "checkout", "update", "revert", "propset", "propget", "propdel", "proplist",\
        "add", "delete", "move", "commit", "cleanup" ].each do |act|
          action act do
            case act
            when "checkout"
              checkout_wrapper
            else
              svn_cmd_wrapper(act)
            end
          end
      end
      
      private 
      def get_path
        if (request[:path])
          request[:path].chomp("/")
        else
          nil
        end
      end
      
      def get_target
        if request[:target]
          request[:target].chomp("/")
        else
          nil
        end
      end
      
      def get_filter
        request[:filter] || "none"
      end
      
      def status_map
        { 2 => ['?', 'Unversioned' ,:unversioned_count, :unversioned, /\?/],\
          4 => ['A', 'Added', :added_count, :added, /A/ ],\
          5 => ['!', 'Missing', :missing_count, :missing, /!/], \
          6 => ['D', 'Deleted', :deleted_count, :deleted, /D/], \
          7 => ['R', 'Replaced', :replaced_count, :replaced, /R/], \
          8 => ['M', 'Modified', :modified_count, :modified, /M/], \
          9 => ['G', 'Merged', :merged_count, :merged, /G/], \
          10 => ['C', 'Conflicted', :conflicted_count, :conflicted, /C/], \
          11 => ['I', 'Ignored', :ignored_count, :ignored, /I/], \
          12 => ['~', 'Obstructed', :obstructed_count, :obstructed, /~/], \
          13 => ['X', 'External', :external_count, :external, /X/], \
          14 => ['!', 'Incomplete', :incompete_count, :incomplete, /!/] }
      end
      
      def reply_array (array, var1, var2)
        reply[var1] = "#{array.length}"
        if array.length > 0
          reply[var2] = "#{array.join(',')}"
        else
          reply[var2] = "None"
        end
      end

      def reply_hash (hash, var1, var2, var3, var4)
        reply_array(hash.keys, var1, var2)
        reply_array(hash.values, var3, var4)
      end
      
      def svn_cmd_wrapper (act)
        target = get_target
        path = get_path
        reply[:output] = "uncaught error"
        if File.exists?(target)
          logger.debug("'#{target}' present")
          reply[:output] = "'#{target}' present"
          if act != "status"
            username = request[:username]
            password = request[:password]
            auth = nil
            ctx = Svn::Client::Context.new()
            if username and password
              ctx.add_simple_provider
              ctx.auth_baton[Svn::Core::AUTH_PARAM_DEFAULT_USERNAME] = username
              ctx.auth_baton[Svn::Core::AUTH_PARAM_DEFAULT_PASSWORD] = password
              auth = "true"
            end
            case act
            when "info"
              info(ctx, auth, target)
            when "update"
              update(ctx, target)
            when "revert"
              begin
                ctx.revert(target)
              rescue Exception => err
                logger.warn("Error reverting '#{target}' - Error #{err}")
                reply.fail! "Error reverting '#{target}' - Error #{err}"
              end
            when "add"
              begin
                ctx.add(target)
              rescue Exception => err
                logger.warn("Error adding #{target} - Error: #{err}")
                reply.fail! "Error adding #{target} - Error: #{err}"
              end
            when "delete"
              begin
                ctx.delete(target)
               rescue Exception => err
                logger.warn("Error deleting #{target} - Error: #{err}")
                reply.fail! "Error deleting #{target} - Error: #{err}"
              end 
            when "move"
              begin
                ctx.move(target,path)
              rescue Exception => err
                logger.warn("Error moving #{target} to #{newpath} - Error: #{err}")
                reply.fail! "Error deleting #{target} - Error: #{err}"
              end
            when "cleanup"
              begin
                ctx.cleanup(target)
              rescue Exception => err
                logger.warn("Error executing cleanup on #{target} - Error: #{err}")
                reply.fail! "Error executing cleanup on #{target} - Error: #{err}"
              end
            when "commit"
              begin
                ctx.commit(target)
              rescue Exception => err
                logger.warn("Error committing #{target} - Error: #{err}")
                reply.fail! "Error committing #{target} - Error: #{err}"
              end
            when "propset","propdel","propget","proplist"
              prop_wrapper(act, ctx, target)
            else
              logger.warn("Unhandled command '#{act}'")
              reply.fail! "Unhandled command '#{act}'"
            end
          else
            status(target)
          end   
        else
          logger.warn("'#{target}' not present")
          reply.fail! "'#{target}' not present"
        end       
        reply[:output] = "OK"
      end
      
      def prop_wrapper (act, ctx, target)
        property = request[:property]
        value = request[:value]
        recurse = request[:recursion]
        revision = request[:revision]

        if revision
          revision = revision.to_i
        end
        if recurse and recurse != "false"
          recures = 'infinity'
        else
          recurse = 'empty'
        end
        
        if act != "proplist"
          case property
          when "ignore"
            actual_property = Svn::Core::PROP_IGNORE
          when "needs_lock"
            actual_property = Svn::Core::PROP_NEEDS_LOCK
          when "executable"
            actual_property = Svn::Core::PROP_EXECUTABLE
          when "externals"
            actual_property = Svn::Core::PROP_EXTERNALS
          when "mime-type"
            actual_property = Svn::Core::PROP_MIME_TYPE
          when "keywords"
            actual_property = Svn::Core::PROP_KEYWORDS
          else
            logger.debug("Recieved '#{property}, which we didn't know what do with")
            reply.fail! "Unknown property '#{property}', valid properties are ignore, needs_lock, executable, mime-type, and keywords"
          end
        end
        
        case act
        when "propset"
          begin
            ctx.propset(actual_property, value, target, recurse)
          rescue Exception => err
            logger.warn("Error setting property '#{property}' to value '#{value}' on '#{target}' - Error #{err}")
            reply.fail! "Error setting property '#{property}' to value '#{value}' on '#{target}' - Error #{err}"
          end
        when "propdel"
          begin
            ctx.propdel(actual_property, value, target, recurse)
          rescue Exception => err
            logger.warn("Error deleting property '#{property}' on '#{target}' - Error #{err}")
            reply.fail! "Error deleting property '#{property}' on '#{target}' - Error #{err}"
          end
        when "propget" 
          files = []
          values = []
           begin
            ctx.propget(actual_property, target, revision, nil, recurse) do |path, value|
              files.push(path)
              values.push(value)
            end
          rescue Exception => err
            logger.warn("Error getting value of property '#{property}' on '#{path}' - Error #{err}")
            reply.fail! "Error getting value of property '#{property}' on '#{path}' - Error #{err}"
          end
          reply_array(files, :files_count, :filelist)
          reply_array(values, :values_count, :valuelist)
        when "proplist"
          begin
            url = nil
            properties = [ {}, {}, {}, {}, {}, {} ]
            propindex = { "svn:ignore" => 0, "svn:keywords" => 1, "svn:mime-type" => 2, "svn:externals" => 3,\
                          "svn:needs_lock" => 4, "svn:executable" => 5 }
            replyhash = { 0 => [:ignored_file_count, :ignored_files, :ignored_value_count, :ignored_values ],\
                          1 => [:keywords_file_count, :keywords_files, :keywords_value_count, :keywords_values],\
                          2 => [:mimetype_file_count, :mimetype_files, :mimetype_value_count, :mimetype_values],\
                          3 => [:external_file_count, :external_files, :external_value_count, :external_values],\
                          4 => [:needslock_file_count, :needslock_files, :needslock_value_count, :needslock_values],\
                          5 => [:executable_file_count, :executable_files, :executable_value_count, :executable_values] }
            ctx.info(target) do |path, info|
              url = "#{info.url}"
              url.chomp!('/')
            end
            reply[:output] = "Info retrieved for '#{target}' - Base URL for checked out copy is: '#{url}' - Beginning Proplist"
            ctx.proplist(target) do |item,value|
              item.sub!(url, target)
              value.each do |key, value|
                reply[:output] = "#{key} => #{propindex[key]} "
                properties[propindex[key]][item] = value
              end
            end
            for i in 0..5 
              reply_hash(properties[i], replyhash[i][0], replyhash[i][1], replyhash[i][2], replyhash[i][3])
            end
          rescue Exception => err
            logger.warn("Error getting property list for '#{target}' - Error: #{err}")
            reply.fail! "Error getting property list for '#{target}' - Error: #{err}"
          end
        else
          logger.warn("Unrecognized property operation '#{act}'")
          reply.fail! "Unrecognized property operation '#{act}'"          
        end
      end

      def status_get_file (path, file, myhash)
        if File.directory?(path) and File.exists?("#{path}/.svn")
          begin
            adm = Svn::Wc::AdmAccess.open(nil, path, false, 0)
          rescue Exception => err
            logger.warn("Could not open working copy to get status of '#{path}/#{file}' - Error: #{err}")
            reply.fail! "Could not open working copy to get status of '#{path}/#{file}' - Error: #{err}"
          end
          if !File.directory?(file) and !file.match(/\.svn/)
            begin
              status = adm.status("#{path}/#{file}")
            rescue Exception => err
              logger.warn("Exception caught trying to get status on '#{path}/#{file}' - Error: #{err}")
              reply.fail!("Exception caught trying to get status on '#{path}/#{file}' - Error: #{err}")
            end
            if myhash[status.text_status]
              myhash[status.text_status].push("#{path}/#{file}")
            end
          end
        end
      end
            
      def status (target)
        filter = get_filter
        map = status_map

        statuses = {}
        for i in 1..13 do
          if map[i]
            statuses[i] ||= []
          end
        end
        if File.directory?("#{target}/.svn")
          Find.find(target) do |search|
            if !search.match(/\.svn/)
              if File.directory?(search)
                Dir.foreach(search) do |file|
                  status_get_file(search, file, statuses)
                end
              end
            end
          end
          for i in 1..13 do
            if map[i]
              if (filter == "none" and statuses[i].length > 0) \
               or filter == "all" \
               or filter.match(map[i][4]) 
                reply_array(statuses[i], map[i][2], map[i][3])
              end
            end
          end
          logger.debug("Reported working copy status for #{target}")
          reply[:output] = "OK"
         else
          logger.debug("No .svn directory inside '#{target}' - svn status not attempted")
          reply.fail! "#{target} is not an svn working copy"
         end
       else
         if File.exists?(target)
           search = File.dirname(target)
           if File.exists?(File.dirname(search)) and File.directory?(File.dirname(search))
             reply[:output] = "OK"
             status_get_file(search, target, statuses)
             for i in 1..13 do
               if map[i] and statuses[i].length > 0
                 logger.debug("Reported working copy status for #{target}")
                 reply[:output] = statuses[i][1]
               end
             end
           else
              logger.debug("Attempt to parse for directory for single file status on '#{target}' failed.")
              reply.fail! "Attempt to parse for directory for single file status on '#{target}' failed."
           end
        end
      end
      
      def info (ctx, auth, path)
        if auth
          begin
            ctx.info(path, nil) do |target, info|
              reply[:url] = "#{info.url}"
              reply[:revision] = "#{info.rev}"
              reply[:last_changed_author] = "#{info.last_changed_author}"
              reply[:last_changed_date] = "#{info.last_changed_date}"
              reply[:last_changed_rev] = "#{info.last_changed_rev}"
              reply[:present] = 1
              reply[:kind] = "#{info.kind}"
              reply[:root] = "#{info.repos_root_url}"
            end    
          rescue Exception => err
            logger.warn("Error retrieving svn info for '#{path}' - Error #{err}")
            reply.fail! "Error retrieving svn info for '#{path}' - Error #{err}"
          end
        else
          replier = Proc.new do |target, info|
            reply[:url] = "#{info.url}"
            reply[:revision] = "#{info.rev}"
            reply[:last_changed_author] = "#{info.last_changed_author}"
            reply[:last_changed_date] = "#{info.last_changed_date}"
            reply[:last_changed_rev] = "#{info.last_changed_rev}"
            reply[:present] = 1
            reply[:kind] = "#{info.kind}"
            reply[:root] = "#{info.repos_root_url}"
          end
     
          begin
            Svn::Client.info(path, nil, nil, replier, false, ctx)
          rescue Exception => err
            logger.warn("Error retrieving svn info for '#{path}' - Error #{err}")
            reply.fail! "Error retrieving svn info for '#{path}' - Error #{err}"
          end
        end
      end
      
      def actual_checkout (username, password, uri, path, rev)
        ctx = Svn::Client::Context.new()
        if username and password
          ctx.add_simple_provider
          ctx.auth_baton[Svn::Core::AUTH_PARAM_DEFAULT_USERNAME] = username
          ctx.auth_baton[Svn::Core::AUTH_PARAM_DEFAULT_PASSWORD] = password
        end
        
        if rev
          rev = rev.to_i
        end
        begin
          ctx.checkout(uri, path, rev, nil)
        rescue Exception => err
          logger.warn("Could not checkout '#{uri}' to '#{path}' - Error #{err}")
          reply.fail! "Could not checkout '#{uri}' to '#{path}' - Error #{err}"
        end
        reply[:output] = "OK"
      end
           
      def checkout_wrapper
        target = get_target
        username = request[:username]
        password = request[:password]
        uri = request[:uri]
        clear = request[:clear]
        revision = request[:revision]
        
        reply[:output] = "uncaught error"
        if File.exists?(target)
          reply[:output] = "Something exists in checkout path"
          if clear
            begin
              FileUtils.rm_r(target, :force => true)
              logger.debug("Removed '#{target}' to clear way for checkout")
            rescue
              logger.warn("Could not remove file '#{target}'")
              reply.fail! "Could not remove file '#{target}'"
            end
            actual_checkout(username, password, uri, target, revision) 
          else 
            reply[:output] = "Something exists in the checkout path and the force option isn't set"
            logger.warn("Something already exists in checkout path '#{target}'")
            reply.fail! "Something already exists in checkout path '#{target}'"
          end
        else
          reply[:output] = "Nothing exists in #{target} - attempting checkout"
          actual_checkout(username, password, uri, target, revision) 
        end
      end

      def update (ctx, target)
        revision = request[:revision]
        
        if revision
          revision = revision.to_i
        else
          revision = "HEAD"
        end
        begin
          ctx.update(target, revision, 'infinity')         
        rescue Exception => err
          logger.warn("Error updating '#{target}' - Error: #{err}")
          reply.fail! "Error updating '#{target}' - Error: #{err}"
        end
      end
      
    end
  end
end