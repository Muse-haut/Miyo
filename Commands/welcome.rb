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

class WelcomeCommand < BaseCommand
  def self.register(bot)
    bot.application_command(:welcome) do |event|
      is_admin = event.user.roles.any? { |role| role.permissions.administrator } || EXCLUDED_USERS.include?(event.user.id)
      unless is_admin
        event.respond "Vous n'avez pas la permission d'utiliser cette commande."
        next
      end

      BaseCommand.command_users[event.user.id] = Time.now
      server_id = event.server.id
      lang = load_server_language_settings(server_id)
      event.defer(ephemeral: false)
      if lang == 'french'
        embed_hash = {
          title: "Système de bienvenue !",
          description: "Vous prévoyez d'accueillir de nouvelles personnes ? Voici ce que je peux faire :\n\n- Activer ou désactiver le système de bienvenue\n- Modifier le salon d'envoi du message de bienvenue\n\nDépêchez-vous, je n'ai guère votre temps.",
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
              r.string_select(custom_id: 'welcome_select', placeholder: 'Choisissez une option', max_values: 1) do |ss|
                ss.option(label: 'Activer/Désactiver le système', value: '1', emoji: { name: '1️⃣' })
                ss.option(label: "Modifier le salon d'envoi", value: '2', emoji: { name: '2️⃣' })
              end
            end
          end

      elsif lang == 'english'
        embed_hash = {
          title: "Welcome System!",
          description: "Planning to welcome new people? Here's what I can do:\n\n- Activate or deactivate the welcome system\n- Modify the channel for the welcome message\n\nHurry up, I don't have all your time.",
          color: 0x3498db,
          timestamp: Time.now.iso8601,
          author: {
            name: "Miyo",
            url: "https://fr.tipeee.com/miyo-bot-discord/",
            icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
          },
          footer: { text: "Signed,\nMiyo." },
          fields: [
            { name: "Linktree :", value: "[Tous les liens ici !🌳](https://linktr.ee/Miyo_DiscordBot)", inline: true },
            { name: "Discord Place :", value: "[Alternative à Disboard 🙌](https://discordplace.com/)", inline: true }
          ]
        }

        event.respond(embeds: [embed_hash])

        event.channel.send_message(
          '',
          false,
          nil,
          nil,
          nil,
          nil,
          Discordrb::Components::View.new do |builder|
            builder.row do |r|
              r.string_select(custom_id: 'welcome_select', placeholder: 'Choose an option', max_values: 1) do |ss|
                ss.option(label: 'Activate/Deactivate system', value: '1', emoji: { name: '1️⃣' })
                ss.option(label: "Modify the welcome channel", value: '2', emoji: { name: '2️⃣' })
              end
            end
          end
        )
      end
      event.edit_response(
        content: "",
        embeds: [embed_hash],
        components: menu_view
        )
    end

    bot.string_select(custom_id: 'welcome_select') do |event|
      lang = load_server_language_settings(event.server.id)

      if command_users[event.user.id].nil?
        msg = lang == 'french' ? "Vous n'avez pas la permission d'utiliser cette commande." : "You don't have the permission to use this command."
        event.interaction.respond(content: msg, ephemeral: true)
        next
      end

      command_users[event.user.id] = Time.now

      settings = load_server_settings
      server_settings = settings[event.server.id.to_s] || {}
      welcome_settings = server_settings['welcome_system'] || {}

      case event.values.first
      when '1'
        welcome_settings['active'] = !welcome_settings.fetch('active', false)
        msg = if lang == 'french'
                "Le système de bienvenue est maintenant #{welcome_settings['active'] ? 'activé' : 'désactivé'}."
              else
                "The welcome system is now #{welcome_settings['active'] ? 'activated' : 'deactivated'}."
              end
        event.interaction.respond(content: msg, ephemeral: true)

      when '2'
        msg = lang == 'french' ? "Veuillez sélectionner le salon pour les messages de bienvenue." : "Please choose the channel where welcome messages will be sent."
        event.interaction.respond(content: msg, ephemeral: false)

        event.channel.send_message(
          '',
          false,
          nil,
          nil,
          nil,
          nil,
          Discordrb::Components::View.new do |builder|
            builder.row do |r|
              r.channel_select(custom_id: 'welcome_channel_select', placeholder: lang == 'french' ? 'Sélectionnez le salon' : 'Choose the channel', max_values: 1)
            end
          end
        )
      end

      server_settings['welcome_system'] = welcome_settings
      settings[event.server.id.to_s] = server_settings
      save_server_settings(settings)
    end
    bot.channel_select(custom_id: 'welcome_channel_select') do |event|
      lang = load_server_language_settings(event.server.id)

      if command_users[event.user.id].nil?
        msg = lang == 'french' ? "Vous n'avez pas la permission d'utiliser cette commande." : "You don't have the permission to use this command."
        event.interaction.respond(content: msg, ephemeral: true)
        next
      end

      command_users[event.user.id] = Time.now

      settings = load_server_settings
      server_settings = settings[event.server.id.to_s] || {}
      welcome_settings = server_settings['welcome_system'] || {}

      welcome_settings['welcome_channel_id'] = event.values.first.id

      msg = if lang == 'french'
              "Le salon de bienvenue est maintenant <##{event.values.first.id}>."
            else
              "The channel for welcome messages is now set to <##{event.values.first.id}>."
            end

      event.interaction.respond(content: msg, ephemeral: true)

      server_settings['welcome_system'] = welcome_settings
      settings[event.server.id.to_s] = server_settings
      save_server_settings(settings)
    end
  end
end



