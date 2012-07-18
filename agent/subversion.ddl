metadata    :name         => "subversion",
            :description  => "Plugin for interacting with Subversion",
            :author       => "Nick Cammorato <nick.cammorato@gmail.com>",
            :license      => "BSD",
            :version      => "1.0",
            :url          => "http://www.terc.edu",
            :timeout      => 300

["info", "status", "checkout", "update", "revert", "propset",\
 "propget", "proplist", "add", "delete", "move", "commit", "cleanup"].each do |act|
	action act, :description => "Executes an svn #{act}" do
	    display :always
	    
		input :target,
			  :prompt		=> "Path to repository",
			  :description	=> "The path to the repository",
			  :type			=> :string,
			  :validation	=> '^.+$',
			  :optional		=> false,
			  :maxlength	=> 256
		if act != "status"
		  input :username,
	          :prompt         => "Username",
	          :description    => "Username for authentication.  Defaults to none or configured value",
	          :type           => :string,
	          :validation     => '^.+$',
	          :optional       => true,
	          :maxlength      => 256
  		  input :password,
	          :prompt         => "Password",
	          :description    => "Password for authentication purposes.  Defaults to none or configured value",
	          :type           => :string,
	          :validation     => '^.+$',
	          :optional       => true,
	          :maxlength      => 256
	    else
	      input :filter,
	      	  :prompt         => "Username",
	          :description    => "Username for authentication.  Defaults to none or configured value",
	          :type           => :string,
	          :validation     => '^.+$',
	          :optional       => true,
	          :maxlength      => 256
	    end
	    if act == "move"
	      input :path,
	      	  :prompt         => "Path",
	          :description    => "Path to move to",
	          :type           => :string,
	          :validation     => '^.+$',
	          :optional       => false,
	          :maxlength      => 256
	    end
	    if act != "info" and act != "status" and act != "revert"
	      input :revision,
        	  :prompt         => "Revision",
        	  :description    => "Revision.  Defaults to HEAD",
        	  :type           => :string,
        	  :validation     => '^.+$',
        	  :optional       => true,
        	  :maxlength      => 256
	    end
	    if act == "checkout"
	      input :clear,
			  :prompt		  => "clear",
			  :description	  => "Equivalent to passing the force option.  Defaults to off if not set",
			  :type			  => :boolean,
			  :optional		  => true
	      input :uri,
		  	  :prompt         => "URI",
		  	  :description    => "URI of repository",
		  	  :type           => :string,
		  	  :validation     => '^.+$',
		  	  :optional       => false,
		  	  :maxlength	  => 256
	    end 
	    if act == "propget" or act =="propset" or act =="propdel" or act == "proplist"
		  input :recurse,
		  	  :prompt		  => "Recurse",
			  :description	  => "Recurse the target.  Defaults to false.",
			  :type			  => :boolean,
			  :optional		  => true
	    end
		if act == "propget" or act == "propset" or act == "propdel"
		  input :property,
		  	  :prompt         => "Property",
		  	  :description    => "Property to set",
		  	  :type           => :list,
		  	  :list			  => ["ignore", "needs_lock", "keywords", "executable", "externals"],
		  	  :optional       => false
		end
		if act == "propset"
		  input :value,
        	  :prompt         => "Value",
        	  :description    => "Some properties have values, use this to pass them",
        	  :type           => :string,
        	  :validation     => '^.+$',
        	  :optional       => false,
        	  :maxlength      => 256
		end
		output :output,
			  :description	=> "Human readable information about the outcome of the operation",
			  :display_as	=> "Status"
	    if act == "info"
	      output :revision,
		      :description    => "Displays the current revision of the working copy",
		      :display_as     => "Current HEAD Revision"
		
		  output :last_changed_author,
		      :description    => "Displays the author of the revision of the current working copy",
		      :display_as     => "Last Changed Author"
		
		  output :last_changed_date,
		      :description	=> "Displays the date of the last revision of the current working copy",
		      :display_as		=> "Last Changed Date"
		
		  output :last_changed_rev,
			  :description	=> "Displays the revision of the last change",
			  :display_as		=> "Last Changed Revision"
		
		  output :url,
		      :description    => "Displays the URL of the current checked out copy",
		      :display_as     => "URL"
		
		  output :root,
		      :description    => "Displays the URL to the root of the repository",
		      :display_as     => "Repository Root"
		
		  output :kind,
		      :description    => "Displays the numeric value corresponding to the node kind",
		      :display_as     => "Node Kind"
		
		  output :present,
		      :description    => "Indicates if a working copy exists using 0 or 1",
		      :display_as     => "Present"
		end
		if act == "status"
		
		  ["unversioned", "added", "missing", "deleted", "replaced", "modified", "merged", "conflicted",\
		   "ignored", "obstructed", "external", "incomplete"].each do |out|
		    output :"#{out}_count",
        	  :description	=> "Count of #{out} files",
        	  :display_as	=> "#{out}"
		
		    output :"#{out}",
        	  :description	=> "Comma delimated list of #{out} files",
        	  :display_as	=> "#{out} Files"
		  end
		end
		if act == "proplist"
		  ["ignored", "keywords", "mimetype", "external", "needslock", "executable"].each do |out|
		    output :"#{out}_file_count",
		      :description	=> "Count of files with svn:#{out} property set",
        	  :display_as	=> "#{out} file count"
        	output :"#{out}_files",
        	  :description	=> "Comma delimated list of files with svn:#{out} property set",
        	  :display_as	=> "#{out} files"
        	output :"#{out}_value_count",
		      :description	=> "Count of svn:#{out} values",
        	  :display_as	=> "#{out} value count"
        	output :"#{out}_values",
        	  :description	=> "Comma delimated list of svn:#{out} values",
        	  :display_as	=> "#{out} values"
		  end
		end
	end	
end
