require 'optparse'
require 'open3'
require 'date'
require 'time_difference'
require 'net/ftp'

options = {}

OptionParser.new do |parser|
  options[:database] = nil
  parser.on( '--database DATABASE', 'MySQL Database' ) do |database|
    options[:database] = database
  end

  options[:database_username] = nil
  parser.on( '--database_username USERNAME', 'MySQL Database Username' ) do |username|
    options[:database_username] = username
  end

  options[:database_password] = nil
  parser.on( '--database_password PASSWORD', 'MySQL Database Password' ) do |password|
    options[:database_password] = password
  end

  options[:database_host] = nil
  parser.on( '--database_host HOST', 'MySQL Database Host' ) do |host|
    options[:database_host] = host
  end

  options[:verbose] = false
  parser.on( '-v', '--verbose', 'Output more information' ) do
    options[:verbose] = true
  end

  options[:ftp_username] = nil
  parser.on('-u', '--username USERNAME', 'Remote FTP Username') do |username|
    options[:ftp_username] = username
  end

  options[:ftp_password] = nil
  parser.on('-p', '--password PASSWORD', 'Remote FTP Password') do |password|
    options[:ftp_password] = password
  end

  options[:ftp_host] = nil
  parser.on('-h', '--host HOST', 'Remote FTP Host') do |host|
    options[:ftp_host] = host
  end

  options[:ftp_dest_folder] = nil
  parser.on('-f', '--folder FOLDER', 'Remote FTP destination folder') do |folder|
    options[:ftp_dest_folder] = folder
  end

  options[:ttl] = nil
  parser.on( '-t', '--ttl TIME IN DAYS', 'Amount of DAYS the created backup should be kept') do |ttl|
    options[:ttl] = ttl
  end
end.parse!

def create_mysql_backup(database, username, password, host, filename, safe, verbose)
  command = "mysqldump --user=#{username} --password=#{password} --host=#{host} #{database} > #{filename}"
  execute_system_command(command, safe, verbose)
end

def snapshot_age(snapshot_name)
  exp_match = snapshot_name.match('exp_(([0-9]*)([hdmy]))')
  created_at_match = snapshot_name.match('[0-9]{8}-[0-9]{4}')

  if exp_match && created_at_match
    exp = exp_match[2]
    exp_unit = exp_match[3]
    created_at = DateTime.strptime(created_at_match[0], '%Y%m%d-%H%M')

    if exp && exp_unit && created_at
      age_unit_selector_mapping = {h: 'in_hours', d: 'in_days', m: 'in_months', y: 'in_years'}
      age_unit_selector = age_unit_selector_mapping[exp_unit.downcase.intern]

      if age_unit_selector
        return [TimeDifference.between(DateTime.now.utc , created_at.utc).send(age_unit_selector), exp.to_f, exp_unit]
      end
    end
  end
end

def upload_file(hostname, username, password, filename, destination_folder, safe_mode, verbose)
  if safe_mode || verbose
    puts "uploading file: #{filename} to #{username}:#{password}@#{hostname}:/#{destination_folder}/"
  end

  unless safe_mode
    Net::FTP.open(hostname, username, password) do |ftp|
      ftp.chdir(destination_folder)
      file = File.new(filename)
      ftp.putbinaryfile(file, File.basename(file))
    end
  end
end

def delete_remote_file(hostname, username, password, filename, destination_folder, safe_mode, verbose)
  if safe_mode || verbose
    puts "deleting remote file #{username}:#{password}@#{hostname}:/#{destination_folder}/#{filename}"
  end

  unless safe_mode
    Net::FTP.open(hostname, username, password) do |ftp|
      ftp.chdir(destination_folder)
      ftp.delete(filename)
    end
  end
end

def get_remote_backups(hostname, username, password, folder, verbose)
  if verbose
    "getting file list from ftp: #{username}:#{password}@#{hostname}:/#{folder}"
  end

  Net::FTP.open(hostname, username, password) do |ftp|
    ftp.chdir(folder)
    ftp.list.map { |entry| entry.split.last }
  end
end

def execute_system_command(cmd, safe_mode=false, verbose=false)
  if safe_mode || verbose
    puts "Executing command: #{cmd}"
  end

  unless safe_mode
    Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
      exit_status = wait_thr.value
      unless exit_status.success?
        abort "Failure executing command: #{cmd}"
      end

      return stdout.read
    end
  end
end

raise OptionParser::MissingArgument if options[:database].nil?
raise OptionParser::MissingArgument if options[:ftp_host].nil?
raise OptionParser::MissingArgument if options[:ftp_username].nil?
raise OptionParser::MissingArgument if options[:ftp_password].nil?
raise OptionParser::MissingArgument if options[:ftp_dest_folder].nil?
raise OptionParser::MissingArgument if options[:database].nil?
raise OptionParser::MissingArgument if options[:database_username].nil?
raise OptionParser::MissingArgument if options[:database_host].nil?
raise OptionParser::MissingArgument if options[:ttl].nil?


date = Time.now.strftime('%Y%m%d-%H%M')
backup_name_filename = "/tmp/#{options[:database]}_#{date}_exp_#{options[:ttl]}.sql"
create_mysql_backup(options[:database], options[:database_username],
                    options[:database_password], options[:database_host],
                    backup_name_filename, false, options[:verbose])

upload_file(options[:ftp_host], options[:ftp_username],
            options[:ftp_password], backup_name_filename,
            options[:ftp_dest_folder], false,
            options[:verbose])

remote_backups = get_remote_backups(options[:ftp_host], options[:ftp_username],
                                    options[:ftp_password], options[:ftp_dest_folder],
                                    options[:verbose])

remote_backups.each { |remote_file|
  snapshot_age = snapshot_age(remote_file)

    if snapshot_age != nil && snapshot_age[0] > snapshot_age[1]
    puts "Deleting remote backup: #{remote_file}"
    delete_remote_file(options[:ftp_host], options[:ftp_username],
                       options[:ftp_password], remote_file,
                       options[:ftp_dest_folder], options[:safe_mode],
                       options[:verbose])
  end
}



