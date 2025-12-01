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

class LanguageCommand < BaseCommand
  def self.register(bot)
    bot.application_command(:language) do |event|
      member = event.server.member(event.user.id)
      is_admin = member&.roles&.any? { |role| role.permissions.administrator } || EXCLUDED_USERS.include?(event.user.id)
      unless is_admin
        event.respond "Vous n'avez pas la permission d'utiliser cette commande."
        next
      end

      server_id = event.server.id
      lang = load_server_language_settings(server_id)
      BaseCommand.command_users[event.user.id] = Time.now
      event.defer(ephemeral: false)

      if lang == 'french'
        embed_hash = {
          title: "Système de changement de langue",
          description: "Vous souhaitez changer de langue ? Bien, c'est ici que vous pourrez opérer. Vous avez juste à cliquer sur le menu ci-dessous, et vous pourrez apprécier une autre langue.\n\nToutefois, veuillez garder en tête que les commandes ne seront pas changées.",
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
            r.string_select(custom_id: 'language_select', placeholder: 'Choose a language', max_values: 1) do |ss|
              ss.option(label: 'English', value: '1', emoji: { name: '🇬🇧' })
              ss.option(label: "Français", value: '2', emoji: { name: '🇫🇷' })
            end
          end
        end
      end

      if lang == 'english'
        embed_hash = {
          title: "Language switching system",
          description: "Do you want to change my language ? Well, this is where you can operate. You just need to click on the menu below, and you'll be able to enjoy another language.\n\nNote: This will not change command names.",
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
            r.string_select(custom_id: 'language_select', placeholder: 'Choose a language', max_values: 1) do |ss|
              ss.option(label: 'English', value: '1', emoji: { name: '🇬🇧' })
              ss.option(label: "Français", value: '2', emoji: { name: '🇫🇷' })
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

    bot.string_select(custom_id: 'language_select') do |event|
      unless BaseCommand.command_users.key?(event.user.id)
        event.interaction.respond(content: "Vous n'avez pas la permission d'utiliser cette commande.", ephemeral: true)
        next
      end

      choice = event.values.first
      settings = load_server_settings
      server_settings = settings[event.server.id.to_s] ||= {}

      response_text = case choice
      when '1'
        server_settings['miyo_language'] = 'english'
        "Miyo will now talk in english ! Enjoy !"
      when '2'
        server_settings['miyo_language'] = 'french'
        "Miyo parlera maintenant en français ! Enjoy !"
      else
        "Choix invalide."
      end

      save_server_settings(settings)
      event.interaction.respond(content: response_text, ephemeral: true)
    end
  end 
end



