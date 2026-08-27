"""
Miyo is a totally independant project. Her source code can be found on github at this page : https://github.com/Muse-haut/Miyo.
It's clearly not the best template for a discord bot, however, you can use it as you please, but please credit me somewhere in your bot/github/website...
If you paid for this code, I'm sorry to tell you that you got scammed.
If you want more details about the bot, contact me on Discord('museau__').
"""

##############
# Depedencies
##############

require 'discordrb' # Well, that's just the point of the code. But you can remove it i guess
require 'httparty' # Better if you want to use some info from the web
require 'json' # Idk how to use sql so this better works
require 'net/http' # Internet (again)
require 'uri' # also for internet (so much omg)
require 'nokogiri' # That's also for internet
require 'fileutils' # If you want to modify a file or smth idk
require 'rufus-scheduler' # if you want to send/do scheduled messages/actions
require 'tzinfo' # Better if you want to step up from a dummy code which don't know what's time to a dummy code, but know the time zone
require 'tzinfo/data' # Same but with data
require 'rufus-scheduler' # For all the commands that are scheduled

if File.exist?("commandloader.rb")
    require_relative 'commandloader' # If you want to load the commands from the commandloader.rb. Otherwise you can just remove the file and write the code in 
                                     # this file even though I would personally not recommend it, or use your personal command loader.
else
    puts("You're currently running this bot without the 'commandloader.rb' which is totally fine if you wanted to do so\nOtherwise, you can just download it here : https://github.com/Muse-haut/Miyo")
end

FileUtils.mkdir_p("Commands") # Makes the global structure of Miyo
FileUtils.mkdir_p("Logs") # Also for the global structure
FileUtils.mkdir_p("Data/Users") # You guessed it ?
FileUtils.mkdir_p("Data/Servers") # Does NOT makes the global struture (joke)

PATHTOLOGININFO = File.join(__dir__, "logininfo.json") # Uses the .json to connect the bot which is the purpose i guess
PATHTOSERVERDATA = File.join(__dir__, "Data", "Servers") # Useful in cas you want to use 
PATHTONONDATAUSERS = File.join(__dir__, "Data", "Users", "NonDataUsers.json") # Useful if you care about privacy
EXCLUDED_USERS = [935207909183356951] # WARNING. Excluded users are people who can activates any commands on any servers as long as the bot is on it, even if they are not admins.

unless File.exist?(PATHTOLOGININFO) # To create the logininfo.json. You can delete it afterwards.
    puts "Seems like it's your first time lauching the bot. If it's not, then 'logininfo.json' has been deleted or is not in the same repertory as Miyo.rb."
    puts "If it's your first time, just type 'begin', and it will create the .json it needs."
    createslogininfo = gets.chomp
    if createslogininfo == 'begin'
        puts "\nWhat's the name of your bot ?"
        name = gets.chomp
         
        data = {
            name => {
                "token" => "",
                "prefix" => "",
                "client_id" => ""
            },
            "Me" => {
                "id" => ""
            }
        }
        File.write(PATHTOLOGININFO, JSON.pretty_generate(data))
        puts"\n\nNow you just have to fill the basics info. You can find them at https://discord.com/developers/home."
        puts"As for 'Me' and 'id' you'll need to fill it with your Discord ID. https://www.youtube.com/watch?v=BZYic0H-HOA\n\n"
    end
    exit
end

unless File.exist?(PATHTONONDATAUSERS)
  File.write(PATHTONONDATAUSERS, JSON.pretty_generate({}))
end

#####################
# Connect the bot
#####################

connect_bot = JSON.parse(File.read(File.join(__dir__, "logininfo.json"))) # Parse your logininfo.json (useful I would say)
bot_name         = connect_bot.keys.first # Uses the first key as a name 
token            = connect_bot[bot_name]['token'] # Uses your token (yeah that's right, you need a token to connect a bot)
prefix           = connect_bot[bot_name]['prefix'] # Uses a prefix for some commands, can be useful sometimes
client_id        = connect_bot[bot_name]['client_id'] # You may need it for some cases
MY_USER_ID = connect_bot['Me']['id'].to_i

bot = Discordrb::Commands::CommandBot.new(token: token, prefix: prefix, intents: :all) # To connect your bot it will be needed
bot.remove_command(:help) # Discord making some random ugly commands which has no purpose except to show your commands (You can create it yourself with a command you made)
Discordrb::LOGGER.mode = :quiet # You can remove it if you want it will show some informations which are not that important
load_commands(bot) # To load the commands

###############################
# When the bots joins a server
###############################

bot.server_create do |event|
  server = event.server
  ensure_server_data_file(server.id)
  channel = server.text_channels.first
  if channel
    embed_hash = {
      title: "Mes salutations",
      description: "Je me prénomme Miyo\nAvant toutes choses, j'aimerais que vous entriez les commandes suivantes afin de pouvoir me faire fonctionner correctement :\n\n- /personality : Vous permet de choisir une des personalités parmis plusieurs choix\n\nSans celà, je ne pourrais utiliser toutes mes capacités. Vous pouvez faire comme vous le souhaitez, bien entendu, mais celà voudrais dire que vous êtes.... Spécial, si vous voyez ce que je veux dire...",
      color: 0x0d5159,
      timestamp: Time.now.iso8601,
      author: {
        name: "Miyo",
        url: "https://museau.neocities.org/",
        icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/a36b1d2cafe6ff934a4a2a5c3bf8fbf4.png?size=2048"
      },
      footer: { text: "Signé,\nMiyo." },
      fields: [
        { name: "Linktree :", value: "[Tous les liens sont ici !🌳](https://linktr.ee/DiscordbotMiyo)", inline: true }
      ]
    }
    channel.send_message('', false, embed_hash)
  end
end

###################################################
# Definitions (useful if you want to add commands)
###################################################
def load_json(path, default: {})
  return default unless File.exist?(path)
  JSON.parse(File.read(path))
rescue => e
  puts "Erreur chargement #{File.basename(path)}: #{e.message}"
  default
end

def save_json(path, data)
  File.write(path, JSON.pretty_generate(data))
rescue => e
  puts "Erreur sauvegarde #{File.basename(path)}: #{e.message}"
end

def json_valid?(path)
  return false unless File.exist?(path)
  JSON.parse(File.read(path))
  true
rescue JSON::ParserError, Errno::ENOENT, IOError => e
  puts "[ERREUR] Fichier JSON invalide (#{File.basename(path)}) : #{e.message}"
  false
end

#########################################
# Check if each server has its own .json
#########################################
def server_data_path(server_id)
  File.join(PATHTOSERVERDATA, "#{server_id}.json")
end

def ensure_server_data_file(server_id)
  path = server_data_path(server_id)
  return if File.exist?(path)
  save_json(path, {})
end

bot.ready do |event|
  bot.servers.each_key do |server_id|
    ensure_server_data_file(server_id)
  end
  bot.update_status(:online, "https://linktr.ee/discordbotmiyo", nil) #change it if you want another status
end
puts("#{bot_name} is now connected !")

bot.run