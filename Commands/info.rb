def load_server_settings
  data_file = File.join(__dir__, '../Data/dataserver.json') 
  unless File.exist?(data_file)
    File.write(data_file, "{}")
  end

  JSON.parse(File.read(data_file))
end

def load_server_language_settings(server_id)
  data_file = File.join(__dir__, '../Data/dataserver.json') 
  return 0 unless File.exist?(data_file)

  data = JSON.parse(File.read(data_file))

  server_data = data[server_id.to_s]
  return 'french' unless server_data

  language = server_data["miyo_language"] || "english"
  language
end

class InfoCommand < BaseCommand
    def self.register(bot)
        bot.application_command(:info) do |event|
            server_id = event.server.id
            settings = load_server_settings
            server_settings = settings[event.server.id.to_s] || {}
            language_settings = server_settings['language'] || {}
            lang = load_server_language_settings(server_id)

            if lang == 'french'
                embed_hash = {
                    title: "Des informations sur moi ? Charmant.",
                    description: "Je me prénomme Miyo, à votre service.\nJe suis codé intégralement en Ruby, en utilisant la librairie 'discordrb', majoritairement par mon créateur Museau.\nJe remercie l'aide de Cyn, qui a aidé Museau lorsqu'il en avait besoin.\nVous auriez besoin d'un gâteau ? Demandez à Glados et à son créateur, Roxas.\nBien, j'en eu trop dit, si vous souhaiter me solliciter, veuillez utiliser la commande !help. Si vous voulez bien m'excuser...",
                    color: 0x3498db,
                    timestamp: Time.now.iso8601,
                    author: {
                        name: "Miyo",
                        url: "https://fr.tipeee.com/miyo-bot-discord/",
                        icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
                    },
                    footer: { text: "Signé,\nMiyo." },
                    fields: [
                        { name: "Linktree :", value: "[Tous les liens ici !🌳](https://linktr.ee/Miyo_DiscordBot)", inline: true },
                        { name: "Discord Place : ​", value: "[Alternative à Disboard 🙌](https://discordplace.com/)", inline: true }
                    ]
                }
            elsif lang == 'english'
                embed_hash = {
                title: "My informations ? Charming",
                description: "My name is Miyo, at your service.\nI am fully coded in Ruby, using the 'discordrb' library, mostly by my creator Museau.\nI thank Cyn for the help given to Museau when he needed it.\nWell, I’ve said too much, if you wish to summon me, please use the !help command. If you will excuse me...",
                color: 0x3498db,
                timestamp: Time.now,

                author: {
                    name: "Miyo",
                    url: "https://fr.tipeee.com/miyo-bot-discord/",
                    icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
                },
                footer: { text: "Signed,\nMiyo." },
                fields: [
                    { name: "Linktree :", value: "[All the links here !🌳](https://linktr.ee/Miyo_DiscordBot)", inline: true },
                    { name: "Discord Place : ​", value: "[Disboard alternative !🙌](https://discordplace.com/)", inline: true }
                    ]
                }
            
            end
            event.respond(embeds: [embed_hash])
        end
    end
end
