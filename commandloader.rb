require_relative 'basecommand'

Dir[File.join(__dir__, 'Commands', '*.rb')].each do |file|
  puts "Requiring command file: #{file}"
  require file
end

def load_commands(bot)
    puts "Detecting commands..."
    ObjectSpace.each_object(Class).select { |c| c < BaseCommand }.each do |cmd|
    puts "Registering command: #{cmd}"
    cmd.register(bot)
  end
end

