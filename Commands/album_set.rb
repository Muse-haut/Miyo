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

def save_server_settings(settings)
  data_file = File.join(__dir__, '../Data/dataserver.json')
  File.write(data_file, JSON.pretty_generate(settings))
end


class AulbumSetCommand < BaseCommand
  def self.register(bot)
    bot.application_command(:albumset) do |event|
        member = event.server&.member(event.user.id)
        is_admin = member&.roles&.any? { |role| role.permissions.administrator } || EXCLUDED_USERS.include?(event.user.id)

        unless is_admin
            event.respond "Vous n'avez pas la permission d'utiliser cette commande."
            next
        end

        BaseCommand.command_users[event.user.id] = Time.now
        lang = load_server_language_settings(event.server.id)
        event.defer(ephemeral: false)
        if lang == 'french'
            embed_hash = {
                title: "Système d'album",
                description: "Souhaitez-vous découvrir un nouvel album tous les jours ? Vous êtes sur la bonne commande !\n Voici ce que je peux vous proposer : \n\n- Activer ou désactiver le système d'album\n- Modifier ou paramètrer le salon d'envoi\n\nDépêchez-vous, je n'ai guère toute votre journée.",
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
                    { name: "Discord Place :", value: "[Alternative à Disboard 🙌](https://discordplace.com/)", inline: true }
                ]
            }
            menu_view = Discordrb::Components::View.new do |builder|
                builder.row do |r|
                    r.string_select(custom_id: 'album_set', placeholder: 'Que voulez-vous modifier ?', max_values: 1) do |ss|
                        ss.option(label: 'Activer/Désactiver le système', value: '1', emoji: { name: '1️⃣' })
                        ss.option(label: "Modifier le salon d'envoi de l'album", value: '2', emoji: { name: '2️⃣' })
                    end
                end
            end
            else
                embed_hash = {
                    title: "Album system.",
                    description: "Would you like to discover a new album every day ? You're in the right place ! \n Here's what I can do for you :\n\n- Enable or disable the album system\n- Change or set the sending channel\n\nHurry up, I don't have all your day.",
                    timestamp: Time.now.iso8601,
                    author: {
                        name: "Miyo",
                        url: "https://fr.tipeee.com/miyo-bot-discord/",
                        icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
                    },
                    footer: { text: "Signé,\nMiyo." },
                    fields: [
                        { name: "Linktree :", value: "[All the links here!🌳](https://linktr.ee/Miyo_DiscordBot)", inline: true },
                        { name: "Discord Place :", value: "[Alternative to Disboard 🙌](https://discordplace.com/)", inline: true }
                    ]
                }

            menu_view = Discordrb::Components::View.new do |builder|
                builder.row do |r|
                    r.string_select(custom_id: 'album_set', placeholder: 'Que voulez-vous modifier ?', max_values: 1) do |ss|
                        ss.option(label: 'Activate/Desactivate system', value: '1', emoji: { name: '1️⃣' })
                        ss.option(label: "Modify the album channel", value: '2', emoji: { name: '2️⃣' })
                    end
                end
            end
        end
        event.edit_response(
            content: "",
            embeds: [embed_hash],
            components: menu_view
        )
        end

        bot.string_select(custom_id: 'album_set') do |event|
            if BaseCommand.command_users[event.user.id].nil?
                event.interaction.respond(content: "Vous n'avez pas la permission d'utiliser cette commande.", ephemeral: true)
                next
            end

            BaseCommand.command_users[event.user.id] = Time.now
            lang = load_server_language_settings(event.server.id)
            server_id = event.server.id
            settings = load_server_settings
            server_settings = settings[server_id.to_s] || {}
            everyday_album_settings = server_settings['everyday_album'] || {}

            case event.values.first
            when '1'
                everyday_album_settings['active'] = !everyday_album_settings.fetch('active', false)
                if lang == 'french'
                    event.interaction.respond(content: "Le système d'album est maintenant #{everyday_album_settings['active'] ? 'activé' : 'désactivé'}.", ephemeral: true)
                else
                    event.interaction.respond(content: "The everyday album system is now #{everyday_album_settings['active'] ? 'activated' : 'deactivated'}.", ephemeral: true)
                end
            when '2'
                if lang == 'french'
                    event.interaction.respond(content: "Veuillez sélectionner le salon pour les messages d'album.", ephemeral: false)
                    placeholder_text = 'Sélectionnez le salon'
                else
                    event.interaction.respond(content: "Please choose the channel where everyday album messages will be send", ephemeral: false)
                    placeholder_text = 'Choose the channel'
                end

                event.channel.send_message(
                '', false, nil, nil, nil, nil,
                Discordrb::Components::View.new do |builder|
                    builder.row do |r|
                    r.channel_select(custom_id: 'everyday_album_channel_select', placeholder: placeholder_text, max_values: 1)
                    end
                end
                )
            end

            server_settings['everyday_album'] = everyday_album_settings
            settings[server_id.to_s] = server_settings
            save_server_settings(settings)
        end

        bot.channel_select(custom_id: 'everyday_album_channel_select') do |event|
            if BaseCommand.command_users[event.user.id].nil?
                event.interaction.respond(content: "Vous n'avez pas la permission d'utiliser cette commande.", ephemeral: true)
                next
            end

            BaseCommand.command_users[event.user.id] = Time.now
            lang = load_server_language_settings(event.server.id)
            server_id = event.server.id
            settings = load_server_settings
            server_settings = settings[server_id.to_s] || {}
            everyday_album_settings = server_settings['everyday_album'] || {}


            selected_channel = event.values.first
            everyday_album_settings['channel_id'] = selected_channel.id

            if lang == 'french'
                event.interaction.respond(content: "Le salon d'envoie d'album quotidien est maintenant <##{selected_channel.id}>.", ephemeral: true)
            else
                event.interaction.respond(content: "The channel where everyday album messages will be send is set on <##{selected_channel.id}>.", ephemeral: true)
            end

            server_settings['everyday_album'] = everyday_album_settings
            settings[server_id.to_s] = server_settings
            save_server_settings(settings)
        end
    end
end
