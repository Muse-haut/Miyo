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

class WelcomeCommand < CommandLoader
  self.command_name = "welcome"
  self.command_desc = "Vous permet d'acceuillir des membres avec un message et un gif de bienvenue."
  self.is_admin_only = true
  self.is_private_message_allowed = false

  def self.register(bot)
    bot.application_command(:welcome) do |event|
      is_admin = event.user.roles.any? { |role| role.permissions.administrator } ||
                EXCLUDED_USERS.include?(event.user.id) ||
                (event.server.owner && event.user.id == event.server.owner.id)

      unless is_admin
        event.respond(content: "Vous n'avez pas la permission d'utiliser cette commande.", ephemeral: true)
        next
      end

      server_id = event.server.id
      event.defer(ephemeral: true)

      embed_hash = {
        title: "Système de bienvenue !",
        description: "Vous prévoyez d'accueillir de nouvelles personnes ? Voici ce que je peux faire :\n\n- Activer ou désactiver le système de bienvenue\n- Modifier le salon d'envoi du message de bienvenue\n\nDépêchez-vous, je n'ai guère votre temps.",
        color: 0x004951,
        timestamp: Time.now.iso8601,
        author: {
            name: "Miyo",
            url: "https://museau.neocities.org/",
            icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/a36b1d2cafe6ff934a4a2a5c3bf8fbf4.png?size=2048"
        },
        footer: { text: "Signé,\nMiyo." },
        fields: [
            { name: "Linktree :", value: "[Tous les liens ici !🌳](https://linktr.ee/DiscordbotMiyo)", inline: true }
          ]
        }

      buttons_view = Discordrb::Components::View.new do |builder|
        builder.row do |r|
          r.button(label: "Activer", style: :success, custom_id: "welcome_enable", emoji: { name: "✅" })
          r.button(label: "Désactiver", style: :danger, custom_id: "welcome_disable", emoji: { name: "❌" })
          r.button(label: "Changer le salon", style: :primary, custom_id: "welcome_channel", emoji: { name: "📌" })
        end
      end

      event.edit_response(
        content: "",
        embeds: [embed_hash],
        components: buttons_view
      )
    end

    bot.button(custom_id: "welcome_enable") do |event|
      server_id = event.server.id
      data_path = File.join(__dir__, "..", "Data", "Servers", "#{server_id}.json")
      data = load_json(data_path, default: {})
      welcome_system = data['Welcome System'] ||= {}

      if welcome_system['Enabled']
        event.respond(content: "Bien tenté, mais le système de bienvenue est déjà activé.", ephemeral: true)
        next
      end

      welcome_system['Enabled'] = true
      save_json(data_path, data)

      unless welcome_system['Channel ID']
        event.respond(
          content: "Système de bienvenue activé.\nAucun salon n'est encore configuré, pensez à en choisir un via **Changer le salon**.",
          ephemeral: true
        )
        next
      end

      event.respond(content: "Le système de bienvenue est désormais activé.", ephemeral: true)
    end

    bot.button(custom_id: "welcome_disable") do |event|
      server_id = event.server.id
      data_path = File.join(__dir__, "..", "Data", "Servers", "#{server_id}.json")
      data = load_json(data_path, default: {})
      welcome_system = data['Welcome System'] ||= {}

      unless welcome_system['Enabled']
        event.respond(content: "Bien tenté, mais le système de bienvenue est déjà désactivé.", ephemeral: true)
        next
      end

      welcome_system['Enabled'] = false
      save_json(data_path, data)

      event.respond(content: "Le système de bienvenue est désormais **désactivé**. En espérant que vous acceuillerez tout de mêmes vos nouveaux membres.", ephemeral: true)
    end

    bot.button(custom_id: "welcome_channel") do |event|
      channel_select_view = Discordrb::Components::View.new do |builder|
        builder.row do |r|
          r.channel_select(
            custom_id: "welcome_channel_select",
            placeholder: "Choisissez un salon",
            max_values: 1
          )
        end
      end

      event.respond(
        content: "Sélectionnez le salon dans lequel les messages de bienvenue seront envoyés :",
        components: channel_select_view,
        ephemeral: true
      )
    end

    bot.channel_select(custom_id: "welcome_channel_select") do |event|
        server_id = event.server.id
        selected_channel = event.values.first

        unless selected_channel&.text?
            event.update_message(content: "Merci de choisir un salon textuel.", components: [])
            next
        end

        data_path = File.join(__dir__, "..", "Data", "Servers", "#{server_id}.json")
        data = load_json(data_path, default: {})

        welcome_system = data['Welcome System'] ||= {}
        welcome_system['Channel ID'] = selected_channel.id

        save_json(data_path, data)

        event.update_message(
            content: "Le salon de bienvenue a été défini sur #{selected_channel.mention}.",
            components: []
        )
    end
  end
end