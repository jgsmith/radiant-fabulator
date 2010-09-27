namespace :radiant do
  namespace :extensions do
    namespace :fabulator do

      desc "Runs the migration for the Fabulator extension"
      task :migrate => :environment do 
        require 'radiant/extension_migrator'
        if ENV["VERSION"]
          FabulatorExtension.migrator.migrate(ENV["VERSION"].to_i)
          Rake::Task['db:schema:dump'].invoke
        else
          FabulatorExtension.migrator.migrate
          Rake::Task['db:schema:dump'].invoke
        end
      end

      desc "Copies public assets of the Fabulator extenion to the instance public/ directory."
      task :update => :environment do
        is_svn_or_dir = proc { |path| path =~ /\.svn/ || File.directory?(path) }
        Dir[FabulatorExtension.root + "/public/**/*"].reject(&is_svn_or_dir).each do |file|
          path = file.sub(FabulatorExtension.root, '')
          directory = File.dirname(path)
          puts "Copying #{path}..."
          mkdir_p RAILS_ROOT + directory, :verbose => false
          cp file, RAILS_ROOT + path, :verbose => false
        end
      end
    end
  end
end
