class Object
  def exists?
    true
  end
end

class NilClass
  def exists?
    false
  end
end

def list_options
  puts
  puts 'What would you like to do?'
  puts '1. List contents of current directory'
  puts '2. Enter directory'
  puts '3. Leave current directory'
  puts '4. Move file to target host'
  puts '5. Move folder to target host'
  puts '6. Exit'
end

def send_data(file, folder, recursive, connection)
  puts 'Checking target directory...'
  if check_target(folder)
    channel = connection.open_channel do |chan|
      chan.exec(in_directory + "rsync -P #{recursive} --rsh=ssh #{file} --bwlimit=3000 #{@target_user}@#{@target}:#{folder}") do |callbacks, success|
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

def in_directory
  "pushd #{@current_dir}; "
end

def change_directory(dir)
  @current_dir = File.join(@current_dir, dir)
end

def leave_directory
  @current_dir = @current_dir[0...@current_dir.rindex('/')]
end

def check_directory(dir, connection)
  connection.exec!("cd #{dir}").nil?
end

def check_relative_directory(dir, connection)
  !connection.exec!(in_directory + "cd #{dir}").include?('No such file or directory')
end

def check_target(path)
  checked = ""
  failed = 0
  Net::SSH.start(@target, @target_user, password: @target_pass) do |conn|
    path.split('/').each do |subpath|
      checked = File.join(checked, subpath)
      failed += 1 unless conn.exec!("cd #{checked}").nil?
    end
  end
  failed <= 1
end
