class MCollective::Application::Subversion<MCollective::Application
  description "Subversion application"
  usage "Usage: mc-subversion [--path PATH] [info]"
  
  option :path,
  :description  => "Path to working copy",
  :arguments  => ["--path PATH", "-p PATH"],
  :required => true

  def post_option_parser(configuration)
    configuration[:command] = ARGV.shift if ARGV.size > 0
  end

  def main
    mc = rpcclient("subversion", :options => options)

    case configuration[:command]
    when "info"
      printrpc mc.info(:path => configuration[:path])

    when "status"
      printrpc mc.status(:path => configuration[:path])
      
    else
      mc.disconnect
      puts "Valid commands are 'info', 'status'"
      exit 1
    end
    
    mc.disconnect
    postrpcstats
  end
end
