class NewsCommand < CommandLoader
  self.command_name = "news"
  self.command_desc = "Configure le salon pour les annonces du bot."
  self.is_admin_only = true
  self.is_private_message_allowed = false

  def self.build_embed(enabled, channel_id)
    channel_mention = channel_id ? "<##{channel_id}>" : "*Non configuré*"
    {
      title: "Configuration News Miyo",
      description: "Définissez le salon qui recevra les nouveautés du bot.\n\n**État :** #{enabled ? '✅ Activé' : '❌ Désactivé'}\n**Salon :** #{channel_mention}",
      color: 0x004951,
      timestamp: Time.now.iso8601,
      author: { name: "Miyo", icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/a36b1d2cafe6ff934a4a2a5c3bf8fbf4.png?size=2048" }
    }
  end

  def self.build_buttons_view(enabled)
    Discordrb::Components::View.new do |builder|
      builder.row do |r|
        r.button(label: "Activer", style: :success, custom_id: "news_enable", emoji: { name: "✅" }) unless enabled
        r.button(label: "Désactiver", style: :danger, custom_id: "news_disable", emoji: { name: "❌" }) if enabled
        r.button(label: "Définir le salon", style: :primary, custom_id: "news_channel", emoji: { name: "📌" })
      end
    end
  end

  def self.register(bot)
    bot.application_command(:news_setup) do |event|
      is_admin = event.user.roles.any? { |role| role.permissions.administrator } ||
                 EXCLUDED_USERS.include?(event.user.id) ||
                 (event.server.owner && event.user.id == event.server.owner.id)

      unless is_admin
        event.respond(content: "Vous n'avez pas la permission.", ephemeral: true)
        next
      end

      event.defer(ephemeral: true)

      server_id = event.server.id
      data_path = File.join(__dir__, '..', 'Data', 'Servers', "#{server_id}.json")
      data = load_json(data_path, default: {})
      news_system = data['NewsMiyo'] || {}
      
      enabled = news_system['Enabled'] || false
      channel_id = news_system['SalonID']

      event.edit_response(content: "", embeds: [build_embed(enabled, channel_id)], components: build_buttons_view(enabled))
    end

    bot.button(custom_id: "news_enable") do |event|
      server_id = event.server.id
      data_path = File.join(__dir__, "..", "Data", "Servers", "#{server_id}.json")
      data = load_json(data_path, default: {})
      news_system = data['NewsMiyo'] ||= {}

      news_system['Enabled'] = true
      save_json(data_path, data)

      event.update_message(
        content: "Le système de news est activé.",
        embeds: [build_embed(true, news_system['SalonID'])],
        components: build_buttons_view(true)
      )
    end

    bot.button(custom_id: "news_disable") do |event|
      server_id = event.server.id
      data_path = File.join(__dir__, "..", "Data", "Servers", "#{server_id}.json")
      data = load_json(data_path, default: {})
      news_system = data['NewsMiyo'] ||= {}

      news_system['Enabled'] = false
      save_json(data_path, data)

      event.update_message(
        content: "Le système de news est désactivé.",
        embeds: [build_embed(false, news_system['SalonID'])],
        components: build_buttons_view(false)
      )
    end

    bot.button(custom_id: "news_channel") do |event|
      channel_select_view = Discordrb::Components::View.new do |builder|
        builder.row do |r|
          r.channel_select(custom_id: "news_channel_select", placeholder: "Choisissez le salon des news", max_values: 1)
        end
      end
      event.respond(content: "Sélectionnez le salon textuel :", components: channel_select_view, ephemeral: true)
    end

    bot.channel_select(custom_id: "news_channel_select") do |event|
      server_id = event.server.id
      selected_channel = event.values.first

      unless selected_channel&.text? || selected_channel&.news?
        event.update_message(content: "Merci de choisir un salon textuel ou d'annonce.", components: [])
        next
      end

      data_path = File.join(__dir__, "..", "Data", "Servers", "#{server_id}.json")
      data = load_json(data_path, default: {})
      news_system = data['NewsMiyo'] ||= {}
      
      news_system['SalonID'] = selected_channel.id.to_s
      save_json(data_path, data)

      event.update_message(content: "Salon configuré avec succès : #{selected_channel.mention}", components: [])
    end
    bot.message(start_with: '!news') do |event|
      event.message.delete
      next unless EXCLUDED_USERS.include?(event.user.id)
      status_message = event.respond("**Processing...**")
      
      news_embed = {
        title: "Ecnore un test GG",
        description: "Brrr brrr patapim",
        color: 0x004951,
        timestamp: Time.now.iso8601,
        author: { name: "Miyo", icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/a36b1d2cafe6ff934a4a2a5c3bf8fbf4.png?size=2048" },
        footer: { text: "Signé,\nMiyo." }
      }

      Thread.new do
        success_count = 0
        fail_count = 0

        event.bot.servers.each do |server_id, server|
          data_path = File.join(__dir__, '..', 'Data', 'Servers', "#{server_id}.json")
          data = load_json(data_path, default: {})
          news_system = data['NewsMiyo']
          
          next unless news_system && news_system['Enabled'] && news_system['SalonID']

          target_channel = server.channels.find { |c| c.id == news_system['SalonID'].to_i }
          
          if target_channel
            begin
              target_channel.send_embed("", news_embed)
              success_count += 1
              sleep(3)
            rescue => e
              puts "Erreur d'envoi des news sur le serveur #{server.name} (#{server.id}): #{e.message}"
              fail_count += 1
            end
          else
            fail_count += 1
          end
        end

        status_message.edit("**Diffusion globale terminée !**")
        sleep(10)
        status_message.delete
      end
    end
  end
end