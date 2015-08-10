# Method simply prints out valid commands.
def list_options
  puts
  puts 'What would you like to do?'
  puts '1. List contents of current directory'
  puts '2. Enter directory'
  puts '3. Leave current directory'
  puts '4. Move file to target host'
  puts '5. Move all files in current directory to target host'
  puts '6. Move folder to target host'
  puts '7. Unarchive a file in the current directory'
  puts '8. Exit'
end

# Method performs basic validation on target path, then calls rsync to move the file or directory.
def send_data(file, folder, recursive, connection)
  puts 'Checking target directory...'
  if check_target(folder)
    puts 'Creating intermediate directories...'
    Net::SSH.start(@target, @target_user, password: @target_pass) { |conn| conn.exec!("mkdir -p #{folder}") }

    channel = connection.open_channel do |chan|
      chan.exec(in_directory + "rsync -P #{recursive} --rsh=ssh #{file} --bwlimit=3000 '#{@target_user}@#{@target}:#{folder}'") do |callbacks, success|
        raise 'An error occured while executing a command' unless success

        callbacks.on_data do |_, data|
          rows = data.gsub(/\s/, ' ').split(' ')
          puts if data.include?("\n")
          print "\r" + (" " * 50)
          print "\rCurrent File Progress: #{rows[1]}\t#{rows[2]}"
        end

        callbacks.on_close { puts "\nDone!" }
      end
    end
    channel.wait
  else
    puts 'Target folder is invalid. Please check the supplied path'
  end
end

def unarchive(archive, target, connection)
  if archive.include?('.rar') || /r[0-9]+/ =~ archive
    command = "unrar e #{archive} #{target}"
  elsif archive.include?('.zip')
    command = "unzip #{archive} -d #{target}"
  else
    puts 'File does not appear to be part of an archive'
    return
  end
  
  puts 'Creating directory to unarchive into...'
  connection.exec!(in_directory + "mkdir -p #{target}")

  puts 'Beginning unarchive...'
  channel = connection.open_channel do |chan|
    chan.exec(in_directory + command) do |callbacks, success|
        raise 'An error occured while executing a command' unless success

        callbacks.on_data do |_, data|
          puts if data.include?("\n")
          print "\r" + (" " * 50)
          print "\r" + data
        end

        callbacks.on_close { puts "\nDone!" }
    end
  end
  channel.wait
end

# SSH Library is unfortunately stateless, so this method provides a command to execute a
# command within the current directory.
def in_directory
  "pushd #{@current_dir}; "
end

# Method updates current directory state.
def change_directory(dir)
  @current_dir = File.join(@current_dir, dir)
end

# Method updates current directory state.
def leave_directory
  return if @current_dir == '/'
  @current_dir = @current_dir[0...@current_dir.rindex('/')]
end

# Method checks that the requested fully qualified path exists on the source host.
def check_directory(dir, connection)
  connection.exec!("cd #{dir}").nil?
end

# Method checks that the requested relative path exists on the source host.
def check_relative_directory(dir, connection)
  !connection.exec!(in_directory + "cd #{dir}").include?('No such file or directory')
end

def check_file(file, connection)
  !connection.exec!(in_directory + "du #{file}").include?('No such file or directory')
end

# Method checks the specified target path on the target host. Basically, method checks that all
# directories within the specified path exist except for, at most, the last two.
def check_target(path)
  checked = ""
  failed = 0
  Net::SSH.start(@target, @target_user, password: @target_pass) do |conn|
    path.split('/').each do |subpath|
      checked = File.join(checked, subpath)
      failed += 1 unless conn.exec!("cd #{checked}").nil?
    end
  end
  failed <= 2
end
