class TokenGrabMenuCommand < CommandLoader
  self.command_name = "antispam"
  self.command_desc = "Vous permet de configurer le système de détection anti spam."
  self.is_admin_only = true
  self.is_private_message_allowed = false

  def self.register(bot)
    bot.application_command(:antispam) do |event|
      is_admin = event.user.roles.any? { |role| role.permissions.administrator } ||
                EXCLUDED_USERS.include?(event.user.id) ||
                (event.server.owner && event.user.id == event.server.owner.id)

      unless is_admin
        event.respond "Vous n'avez pas la permission d'utiliser cette commande."
        next
      end

      server_id = event.server.id
      event.defer(ephemeral: true)

      embed_hash = {
        title: "Système anti spam !",
        description: "Souhaitez-vous vous protéger contre les comptes volés ? Les spammeurs ? Voici ce que je peux faire :\n\n- Activer ou désactiver la détection\n- Modifier le salon d'envoie pour le message spammé\n\n**À noter**\nCe système agis sur tous les salons. Si un membre envoie la même image ou le même message 3 fois dans le même salon ou dans des salons différents, il se fera timeout. Veuillez prévenir vos membres.\nCe système ne bannis pas, il timeout (durant 5 minutes, le compte ne peut plus intéragir avec le serveur), car il peut y avoir des cas de faux positif (même s'il faudrait s'avérer un peu idiot pour envoyer 3 fois le même message sur le même serveur). C'est pour celà que je vous recommande vivement d'avoir un salon spécifique pour l'envois des différents messages spammés.\nDans le cas où le propriétaire du serveur se fait token grab, je supprimerais les messages mais je ne pourrais pas le timeout.",
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
          r.button(label: "Activer", style: :success, custom_id: "tokengrab_enable", emoji: { name: "✅" })
          r.button(label: "Désactiver", style: :danger, custom_id: "tokengrab_disable", emoji: { name: "❌" })
          r.button(label: "Changer le salon", style: :primary, custom_id: "tokengrab_channel", emoji: { name: "📌" })
        end
      end

      event.edit_response(
        content: "",
        embeds: [embed_hash],
        components: buttons_view
      )
    end

    bot.button(custom_id: "tokengrab_enable") do |event|
      server_id = event.server.id
      data_path = File.join(__dir__, "..", "Data", "Servers", "#{server_id}.json")
      data = load_json(data_path, default: {})

      tokengrab_system = data['Token Grab System'] ||= {}

      if tokengrab_system['Enabled']
        event.respond(content: "Bien tenté, mais le système anti token-grab est déjà activé.", ephemeral: true)
        next
      end

      tokengrab_system['Enabled'] = true
      save_json(data_path, data)

      unless tokengrab_system['Channel ID']
        event.respond(
          content: "Système anti token-grab activé.\nAucun salon de review n'est encore configuré, pensez à en choisir un via **Changer le salon**.",
          ephemeral: true
        )
        next
      end

      event.respond(content: "Le système anti token-grab est désormais activé.", ephemeral: true)
    end

    bot.button(custom_id: "tokengrab_disable") do |event|
      server_id = event.server.id
      data_path = File.join(__dir__, "..", "Data", "Servers", "#{server_id}.json")
      data = load_json(data_path, default: {})

      tokengrab_system = data['Token Grab System'] ||= {}

      unless tokengrab_system['Enabled']
        event.respond(content: "Bien tenté, mais le système anti token-grab est déjà désactivé.", ephemeral: true)
        next
      end

      tokengrab_system['Enabled'] = false
      save_json(data_path, data)

      event.respond(content: "Le système anti token-grab est désormais **désactivé**. Restez vigilants tout de même.", ephemeral: true)
    end

    bot.button(custom_id: "tokengrab_channel") do |event|
      channel_select_view = Discordrb::Components::View.new do |builder|
        builder.row do |r|
          r.channel_select(
            custom_id: "tokengrab_channel_select",
            placeholder: "Choisissez un salon",
            max_values: 1
          )
        end
      end

      event.respond(
        content: "Sélectionnez le salon dans lequel les alertes de détection seront envoyées :",
        components: channel_select_view,
        ephemeral: true
      )
    end

    bot.channel_select(custom_id: "tokengrab_channel_select") do |event|
        server_id = event.server.id

        selected_channel = event.values.first

        unless selected_channel&.text?
            event.update_message(content: "Merci de choisir un salon textuel.", components: [])
            next
        end

        data_path = File.join(__dir__, "..", "Data", "Servers", "#{server_id}.json")
        data = load_json(data_path, default: {})

        tokengrab_system = data['Token Grab System'] ||= {}
        tokengrab_system['Channel ID'] = selected_channel.id

        save_json(data_path, data)

        event.update_message(
            content: "Le salon de review a été défini sur #{selected_channel.mention}.",
            components: []
        )
    end
  end
end