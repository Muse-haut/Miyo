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

def list_miyo_personalities_fr
  {
    1 => "Distante, froide, se sentant supérieure et plutôt mondaine, elle saura vous aider. C'est le modèle original, celui qui a été initialement conçue et intégré dans le projet.",
    2 => "Plutôt sentimentale, Miyo se veut aimable, à l'écoute et compréhensive. Parfaite pour vous proposer des solutions à vos problèmes, elle saura être le rayon de soleil de votre journée !",
    3 => "Avez-vous rêvé de vous faire draguer ? Eh bien, cette personnalité est faite pour vous ! Toutefois, elle restera SFW pour des raisons évidentes d'éthique. Cette personnalité est plus pour le fun.",
    4 => "Ohio ! Gomenasaï, je n'ai pas présenté cette personnalité avant, sumimasen, quel baka je fais ! Comme vous l'aurez compris, Miyo est devenue la baka ohio goon everywhere qu'elle pense être.",
    5 => "Mondaine, une fois de plus, mais cette fois sans vous rappeler la place que vous occupez."
  }
end

def list_miyo_personalities_en
  {
    1 => "Distant, cold, feeling superior and rather worldly, she will know how to help you. This is the original model, the one initially designed and integrated into the project.",
    2 => "Rather sentimental, Miyo aims to be kind, attentive, and understanding. Perfect to offer solutions to your problems, she will be the ray of sunshine in your day!",
    3 => "Ever dreamed of being flirted with? Well, this personality is made for you! However, she will remain SFW for obvious ethical reasons. This personality is more for fun.",
    4 => "Ohio! Gomenasaï, I didn’t introduce this personality earlier, sumimasen, what a baka I am! As you might have guessed, Miyo has become the baka ohio goon everywhere she thinks she is.",
    5 => "Worldly, once again, but this time without reminding you of the place you hold."
  }
end

def cmd_list_personalities(server_id)
  lang = load_server_language_settings(server_id)
  list =
    if lang == 'french'
      list_miyo_personalities_fr
    elsif lang == 'english'
      list_miyo_personalities_en
    else
      list_miyo_personalities_en
    end
  list.map { |id, desc| "**#{id}** → #{desc}" }.join("\n\n")
end

def set_miyo_personality(server_id, personality_id)
  file_path = "../Data/dataserver.json"
  data = File.exist?(file_path) ? JSON.parse(File.read(file_path)) : {}

  data[server_id.to_s] ||= {}
  data[server_id.to_s]["miyo_personality"] = personality_id.to_i

  File.write(file_path, JSON.pretty_generate(data))
end

def set_miyo_personality(server_id, personality_id)
  file_path = "../Data/dataserver.json"
  data = File.exist?(file_path) ? JSON.parse(File.read(file_path)) : {}

  data[server_id.to_s] ||= {}
  data[server_id.to_s]["miyo_personality"] = personality_id.to_i

  File.write(file_path, JSON.pretty_generate(data))
end

class PersonalityCommand < BaseCommand
  def self.register(bot)
    bot.application_command(:personality) do |event|
      is_admin = event.user.roles.any? { |role| role.permissions.administrator } || EXCLUDED_USERS.include?(event.user.id)
      unless is_admin
        event.respond "Vous n'avez pas la permission d'utiliser cette commande."
        next
      end

      server_id = event.server.id
      lang = load_server_language_settings(server_id)

      BaseCommand.command_users[event.user.id] = Time.now


      event.defer(ephemeral: false)
      if lang == "french"
        embed_hash = {
          title: "Mes personnalités ?",
          description: "Vous voulez modifier ma personnalité ? Très bien.\n\nMais je resterai mondaine en dehors de ces options !\n\nVoici mes styles disponibles :\n\n",
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
            r.string_select(custom_id: 'personality_select', placeholder: 'Choisissez une personnalité', max_values: 1) do |ss|
              ss.option(label: 'Froid, distant', value: '1', emoji: { name: '👑' })
              ss.option(label: "Aimable", value: '2', emoji: { name: '🫶' })
              ss.option(label: "Séduisante (SFW)", value: '3', emoji: { name: '🫦' })
              ss.option(label: "Bakaaaa", value: '4', emoji: { name: '🤪' })
              ss.option(label: "Mondaine", value: '5', emoji: { name: '⚜️' })
            end
          end
        end
        event.edit_response(
          content: "",
          embeds: [embed_hash],
          components: menu_view
        )

      elsif lang == "english"
        event.channel.send_embed do |embed|
          embed.title = "My personalities?"
          embed.description = "Want to change my personality? Very well.\n\nBut I’ll stay worldly outside these options!\n\nHere are my available styles:\n\n#{cmd_list_personalities(server_id)}"
          embed.color = 0x3498db
          embed.timestamp = Time.now
          embed.author = Discordrb::Webhooks::EmbedAuthor.new(
            name: "Miyo",
            url: "https://fr.tipeee.com/miyo-bot-discord/",
            icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
          )
          embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "Signed,\nMiyo.")
          embed.add_field(name: "Buy me a coffee ☕", value: "[Thank you!](https://fr.tipeee.com/miyo-bot-discord/)", inline: true)
        end
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
              r.string_select(custom_id: 'personality_select', placeholder: 'Choose a personality', max_values: 1) do |ss|
                ss.option(label: 'Cold, distant', value: '6', emoji: { name: '👑' })
                ss.option(label: "Kind", value: '7', emoji: { name: '🫶' })
                ss.option(label: "Seductive (SFW)", value: '8', emoji: { name: '🫦' })
                ss.option(label: "Bakaaaa", value: '9', emoji: { name: '🤪' })
                ss.option(label: "Worldly", value: '10', emoji: { name: '⚜️' })
              end
            end
          end
        )
      end
    end

    bot.string_select(custom_id: 'personality_select') do |event|
      unless BaseCommand.command_users.key?(event.user.id)
        event.interaction.respond(content: "Vous n'avez pas la permission d'utiliser cette commande.", ephemeral: true)
        next
      end

      choice = event.values.first
      settings = load_server_settings
      server_settings = settings[event.server.id.to_s] ||= {}
      language_settings = server_settings['language'] || {}

      response_text = case choice
      when '1'
        server_settings['miyo_personality_system'] = 1
        "🧊 Mode activé : Froid, distant."
      when '2'
        server_settings['miyo_personality_system'] = 2
        "🌼 Mode activé : Aimable."
      when '3'
        server_settings['miyo_personality_system'] = 3
        "💋 Mode activé : Séduisante (SFW)."
      when '4'
        server_settings['miyo_personality_system'] = 4
        "🤪 Mode activé : Bakaaaa !"
      when '5'
        server_settings['miyo_personality_system'] = 5
        "⚜️ Mode activé : Mondaine."
      when '6'
        server_settings['miyo_personality_system'] = 6
        "🧊 Activated mode : Cold, distant."
      when '7'
        server_settings['miyo_personality_system'] = 7
        "🌼 Activated mode : Kind."
      when '8'
        server_settings['miyo_personality_system'] = 8
        "💋 Activated mode : Seductive (SFW)."
      when '9'
        server_settings['miyo_personality_system'] = 9
        "🤪 Activated mode : Bakaaaa."
      when '10'
        server_settings['miyo_personality_system'] = 10
        "⚜️ Activated mode : Worldly"
      else
        "Invalid choice. Try again."
      end

      save_server_settings(settings)

      event.interaction.respond(content: response_text, ephemeral: true)
    end
  end
end


