# Include the necessary external libraries
require 'net/ssh'
require 'trollop'
require_relative 'helpers'

# Include the necessary system libraries
require 'yaml'
require 'shellwords'

# Parse command line options
opts = Trollop::options do
  opt :source, 'The source host', type: :string, short: '-s'
  opt :target, 'The target host', type: :string, short: '-t'
  
  opt :source_user, 'Username for the source host', type: :string, short: '-u'
  opt :target_user, 'Username for the target host', type: :string
  
  opt :source_path, 'Base path for the source host', type: :string, short: '-p'
  opt :target_path, 'Base path for the target host', type: :string

  opt :source_pass, 'Password for the source host', type: :string
  opt :target_pass, 'Password for the target host', type: :string

  opt :pass_file, 'Path to file containing passwords for source and target hosts'
end

# Get the necessary config information
@source = opts[:source] || 'bigdickmystics.lw211.ultraseedbox.com'
@target = opts[:target] || 'christopherfretz.com'
@source_user = opts[:source_user] || 'bigdickmystics'
@target_user = opts[:target_user] || 'root'
@source_path = opts[:source_path] || '~/Torrents/Complete'
@target_path = opts[:target_path] || '/mnt/nfs/media/media'

# Special logic for getting password info
@source_pass = opts[:source_pass]
@target_pass = opts[:target_pass]
if @source_pass.nil? || @target_pass.nil?
  passes = YAML::load_file(opts[:pass_file] || 'passwords.yml')
  @source_pass ||= passes['source']
  @target_pass ||= passes['target']
end

# Open the remote session to the source host
Net::SSH.start(@source, @source_user, password: @source_pass) do |conn|
  raise 'Base directory for source host does not exist' unless check_directory(@source_path, conn)
  @current_dir = @source_path
  puts "Logged in and ready to go!"
  loop do
    list_options
    choice = gets.to_i
    case choice
    when 1
      puts conn.exec!(in_directory + 'ls').split("\n")[1..-1]
    when 2
      puts 'Enter chosen directory name'
      dir = Shellwords::escape(gets.strip)
      check_relative_directory(dir, conn) ? change_directory(dir) : puts('Sorry, directory does not exist')
    when 3
      leave_directory
    when 4
      puts 'Enter the file name'
      file = Shellwords::escape(gets.strip)
      puts "Enter the directory (relative to #{@target_path}) to send to on the target host"
      folder = Shellwords::escape(gets.strip)
      send_data(file, File.join(@target_path, folder), '', conn)
    when 5
      puts 'Enter the directory name'
      dir = Shellwords::escape(gets.strip)
      puts "Enter the directory (relative to #{@target_path}) to send the chosen directory to on the target host"
      folder = Shellwords::escape(gets.strip)
      send_data(dir, File.join(@target_path, folder), '-r', conn)
    when 6
      break
    else
      puts 'Please enter a valid choice'
    end
  end
end
