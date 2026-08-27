require 'json'
require 'fileutils'

class CommandLoader
  @command_users = {}

  class << self
    attr_accessor :command_users
    attr_accessor :command_name, :command_desc, :is_admin_only, :is_private_message_allowed
    attr_accessor :required_options, :optional_options
    attr_writer :passive

    def passive
      @passive ||= false
    end

    def register(bot)
      raise NotImplementedError, "Chaque commande doit définir `self.register(bot)`"
    end
  end
end

COMMANDS_DIR = File.join(__dir__, 'Commands')
DATA_DIR = File.join(__dir__, 'Data')
COMMANDS_DATA_FILE = File.join(DATA_DIR, 'commands.json')
VALID_OPTION_TYPES = %i[string integer number boolean user channel role mentionable attachment].freeze

FileUtils.mkdir_p(DATA_DIR)

Dir[File.join(COMMANDS_DIR, '*.rb')].each do |file|
  require file
end

def normalize_options(options)
  Array(options).map do |opt|
    type = opt[:type].to_s

    unless VALID_OPTION_TYPES.include?(type.to_sym)
      raise ArgumentError, "Type d'option invalide: #{opt[:type].inspect} (valides: #{VALID_OPTION_TYPES.join(', ')})"
    end

    {
      "type" => type,
      "name" => opt[:name].to_s,
      "desc" => opt[:desc].to_s
    }
  end
end

def command_signature(cmd)
  {
    "command_name" => cmd.command_name.to_s,
    "command_desc" => cmd.command_desc.to_s,
    "is_admin_only" => !!cmd.is_admin_only,
    "is_private_message_allowed" => !!cmd.is_private_message_allowed,
    "required_options" => normalize_options(cmd.required_options),
    "optional_options" => normalize_options(cmd.optional_options)
  }
end

def register_to_discord(bot, signature)
  bot.register_application_command(
    signature["command_name"].to_sym,
    signature["command_desc"],
    default_member_permissions: signature["is_admin_only"] ? 8 : nil,
    contexts: signature["is_private_message_allowed"] ? [0, 1, 2] : [0]
  ) do |cmd|
    signature["required_options"].each do |opt|
      cmd.public_send(opt["type"].to_sym, opt["name"], opt["desc"], required: true)
    end

    signature["optional_options"].each do |opt|
      cmd.public_send(opt["type"].to_sym, opt["name"], opt["desc"], required: false)
    end
  end
end

def unregister_from_discord(bot, name)
  existing = bot.get_application_commands
  target = existing.find { |c| c.name == name }
  return unless target

  bot.delete_application_command(target.id)
end

def load_commands(bot)
  saved_data = File.exist?(COMMANDS_DATA_FILE) ? JSON.parse(File.read(COMMANDS_DATA_FILE)) : {}
  new_data = {}

  detected_commands = ObjectSpace.each_object(Class).select { |c| c < CommandLoader }

  detected_commands.each do |cmd|
    if cmd.passive
      cmd.register(bot)
      next
    end

    if cmd.command_name.to_s.strip.empty? || cmd.command_desc.to_s.strip.empty?
      puts "You forgot some informations for this command : #{cmd}.\nYou can look at examples in the main repository : https://github.com/Muse-haut/Miyo"
      next
    end

    signature = command_signature(cmd)
    name = signature["command_name"]
    new_data[name] = signature

    if saved_data[name] == signature
    else
      register_to_discord(bot, signature)
    end

    cmd.register(bot)
  end

  removed_commands = saved_data.keys - new_data.keys
  removed_commands.each do |removed_name|
    unregister_from_discord(bot, removed_name)
  end

  File.write(COMMANDS_DATA_FILE, JSON.pretty_generate(new_data))
end