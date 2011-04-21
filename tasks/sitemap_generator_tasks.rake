begin
  require 'aws/s3'
  include AWS::S3
rescue LoadError
  raise RequiredLibraryNotFoundError.new('AWS::S3 could not be loaded')
end

# Require sitemap_generator at runtime.  If we don't do this the ActionView helpers are included
# before the Rails environment can be loaded by other Rake tasks, which causes problems
# for those tasks when rendering using ActionView.
namespace :sitemap do
  # Require sitemap_generator only.  When installed as a plugin, the require will fail, so in
  # this case, we have to load the full environment first.
  task :require, :site_code do |t, args|
    begin
      require 'sitemap_generator'
    rescue LoadError
      Rake::Task["sitemap:require_environment"].invoke(args[:site_code])
    end
  end

  # Require sitemap_generator after loading the Rails environment.  We still need the require
  # in case we are installed as a gem and are setup to not automatically be required.
  task :require_environment, :site_code, :needs => :environment do |t, args|
    require 'sitemap_generator'
    SitemapGenerator::Sitemap = SitemapGenerator::LinkSet.new(args[:site_code])
  end

  desc "Install a default config/sitemap.rb file"
  task :install => ['sitemap:require'] do
    SitemapGenerator::Utilities.install_sitemap_rb(verbose)
  end

  desc "Delete all Sitemap files in public/ directory"
  task :clean => ['sitemap:require'] do
    SitemapGenerator::Utilities.clean_files
  end

  desc "Create Sitemap XML files in public/ directory (rake -s for no output)"
  task :refresh, :site_code, :needs => ['sitemap:create'] do |t, args|
    SitemapGenerator::Sitemap.ping_search_engines
  end

  desc "Create Sitemap XML files (don't ping search engines)"
  task 'refresh:no_ping', :site_code, :needs => ['sitemap:create'] do |t, args|
  
  end

  desc "Generate the sitemap alone"
  task :create, :site_code, :needs => ['sitemap:require_environment'] do |t, args|
    SitemapGenerator::Sitemap.verbose = verbose
    SitemapGenerator::Sitemap.create(args[:site_code])
  end
  
  desc "Make it and send it in one go"
  task :generate_and_transfer, :site_code, :needs => ['sitemap:create','sitemap:transfer'] do |t, args|
    
  end
  
  desc "Send sitemaps to S3"
  task :transfer, :site_code, :needs => ['sitemap:require_environment'] do |t, args|
    
    s3_cred_hash = {}
    File.open("#{RAILS_ROOT}/config/s3.yml", 'r') do |file|
      YAML::load(file).each do |k,v|
        s3_cred_hash[k.to_sym] = v  
      end
    end
    
    sitemap_config = {}
    File.open("#{RAILS_ROOT}/config/sitemap.yml", 'r') do |file|
      YAML::load(file).each do |k,v|
        sitemap_config[k.to_sym] = v  
      end
    end
    
  
    local_storage = 'tmp'
    AWS::S3::Base.establish_connection!(s3_cred_hash)
    
    sitemap_files = Dir[File.join(RAILS_ROOT, "/tmp/#{args[:site_code]}_sitemap*.xml.gz")]
    sitemap_files.each do |filename|    
      AWS::S3::S3Object.store(File.basename(filename),
                              open(filename),
                              sitemap_config[:bucket],
                              :access => :public_read)
    end
    puts " [uploaded to S3:#{SitemapGenerator::Sitemap.s3_bucket_name}]" if verbose
  end
  
  
end
