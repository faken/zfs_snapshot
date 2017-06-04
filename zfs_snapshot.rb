require 'optparse'
require 'open3'
require 'date'
require 'time_difference'

options = {}

OptionParser.new do |parser|
  options[:dataset] = nil
  parser.on( '-d', '--dataset DATASET', 'ZFS Dataset to work on' ) do|dataset|
    options[:dataset] = dataset
  end

  options[:ttl] = nil
  parser.on( '-t', '--ttl TIME IN DAYS', 'Amount of DAYS the created backup should be kept') do|ttl|
    options[:ttl] = ttl
  end

  options[:snapshot_name] = nil
  parser.on( '-n', '--name SNAPSHOT NAME', 'Basic name of the snapshot') do |name|
    options[:snapshot_name] = name
  end

  options[:verbose] = false
  parser.on( '-v', '--verbose', 'Output more information' ) do
    options[:verbose] = true
  end

  parser.on('-i', '--info', 'Shows statistics about created snapshots') do
    options[:stats] = true
  end

  parser.on('-r', '--recursive', 'Create / Destroy ZFS Snapshots recursively') do
    options[:recursive] = true
  end

  parser.on('-s', '--safe', 'Safe mode, dont execute actual command') do
    options[:safe_mode] = true
  end

  parser.on('-c', '--create', 'Create ZFS Snapshot') do
    options[:create] = true
  end

  parser.on('-p', '--purge', 'Deletes expired ZFS Snapshots') do
    options[:clean] = true
  end
end.parse!

def create_zfs_snapshot(dataset, ttl, snapshot_name, safe_mode=false, recursive=false, verbose=false)
  date = Time.now.utc.strftime('%Y%m%d-%H%M')
  command = "zfs snapshot #{recursive ? '-r' : nil} #{dataset}@#{snapshot_name}_#{date}_exp_#{ttl}"
  puts "Creating snapshot: #{dataset}@#{snapshot_name}_#{date}_exp_#{ttl}"
  execute_system_command(command,safe_mode, verbose)
end

def destroy_outdated_snapshots(dataset, recursive=false, safe_mode=false, verbose=false)
  puts 'Looking for outdated snapshots...'

  output = get_snapshots(dataset, verbose)

  if output
    output.split(/\r?\n|\r/).each do |line|
      snapshot_age = snapshot_age(line)

      if snapshot_age[0] > snapshot_age[1]
        puts "Destroying snapshot: #{line}"
        command = "zfs destroy #{recursive ? '-r' : nil} #{line}"
        execute_system_command(command, safe_mode)
      end
    end
  end
end

def show_statistics(dataset, verbose)
  output = get_snapshots(dataset, verbose)
  output.split(/\r?\n|\r/).each do |line|
    created_at_match = line.match('[0-9]{8}-[0-9]{4}')

    if created_at_match
      created_at = DateTime.strptime(created_at_match[0], '%Y%m%d-%H%M')
      age = snapshot_age(line)

      if created_at
        puts '--------------------------------------------------------'
        puts "Snapshot: #{line}"
        puts "Created: #{created_at}"
        puts "Age: #{age[0]}"
        puts "Expired: #{age[0] > age[1]}"
      end
    end
  end
  puts '--------------------------------------------------------'
end

def get_snapshots(dataset, verbose)
  execute_system_command("zfs list -H -o name -t snapshot | sort | grep #{dataset}", false, verbose)
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


if options[:stats]
  raise OptionParser::MissingArgument if options[:dataset].nil?
  
  show_statistics(options[:dataset], options[:verbose])
  abort
end

if options[:create]
  raise OptionParser::MissingArgument if options[:dataset].nil?
  raise OptionParser::MissingArgument if options[:snapshot_name].nil?
  raise OptionParser::MissingArgument if options[:ttl].nil?

  create_zfs_snapshot(options[:dataset], options[:ttl],
                    options[:snapshot_name], options[:safe_mode],
                    options[:recursive],options[:verbose])
end


if options[:clean]
  raise OptionParser::MissingArgument if options[:dataset].nil?

  destroy_outdated_snapshots(options[:dataset],
                             options[:recursive],
                             options[:safe_mode],
                             options[:verbose])
end

