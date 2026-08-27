require 'rufus-scheduler'

def load_daily_questions
  questions_file = File.join(__dir__, "..", "Data", "questions.json")
  return [] unless File.exist?(questions_file)

  data = JSON.parse(File.read(questions_file))
  case data
  when Array
    data.compact
  when Hash
    Array(data['questions']).compact
  else
    []
  end
rescue => e
  []
end

def send_daily_question(bot_client)
  questions = load_daily_questions
  return if questions.empty?

  question = questions.sample

  servers_dir = File.join(__dir__, "..", "Data", "Servers")
  return unless Dir.exist?(servers_dir)

  Dir[File.join(servers_dir, "*.json")].each do |server_file|
    server_id = File.basename(server_file, ".json")

    begin
      config = JSON.parse(File.read(server_file))
    rescue => e
      next
    end

    daily_question = config['Daily Question'] || {}
    next unless daily_question['Enabled']

    channel_id = daily_question['Channel ID']
    next if channel_id.to_s.strip.empty?

    channel = bot_client.channel(channel_id.to_i)
    unless channel
      next
    end

    begin
      role_id = daily_question['Role ID']
      message_content = question

      unless role_id.to_s.strip.empty?
        message_content = "||<@&#{role_id}>||\nQuestion du Jour ! :\n#{question}"
      end

      channel.send_message(message_content)
    rescue Discordrb::Errors::UnknownChannel
    rescue Discordrb::Errors::NoPermission
    rescue => e
    end
  end
end

class CommandDailyQuestion < CommandLoader
  self.command_name = "dailyquestion"
  self.command_desc = "Vous permet de configurer l'envoi de questions journalières à vos membres."
  self.is_admin_only = true
  self.is_private_message_allowed = false

  def self.register(bot)
    scheduler = Rufus::Scheduler.new
    scheduler.cron '0 12 * * *' do
      send_daily_question(bot)
    end

    bot.application_command(:dailyquestion) do |event|
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
        title: "Système de questions journalières !",
        description: "Souhaitez-vous questionner vos membres jour après jour ? Voici ce que je peux faire :\n\n- Activer ou désactiver l'envoi de questions\n- Modifier le salon d'envoi\n- Choisir un rôle à mentionner\n\nDépêchez-vous, je n'ai guère votre temps.",
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
          r.button(label: "Activer", style: :success, custom_id: "dailyquestion_enable", emoji: { name: "✅" })
          r.button(label: "Désactiver", style: :danger, custom_id: "dailyquestion_disable", emoji: { name: "❌" })
          r.button(label: "Changer le salon", style: :primary, custom_id: "dailyquestion_channel", emoji: { name: "📌" })
          r.button(label: "Changer le rôle", style: :primary, custom_id: "dailyquestion_role", emoji: { name: "🏷️" })
        end
      end

      event.edit_response(
        content: "",
        embeds: [embed_hash],
        components: buttons_view
      )
    end

    bot.button(custom_id: "dailyquestion_enable") do |event|
      server_id = event.server.id
      data_path = File.join(__dir__, "..", "Data", "Servers", "#{server_id}.json")
      data = load_json(data_path, default: {})

      daily_question = data['Daily Question'] ||= {}

      if daily_question['Enabled']
        event.respond(content: "Bien tenté, mais le système de questions journalières est déjà activé.", ephemeral: true)
        next
      end

      daily_question['Enabled'] = true
      save_json(data_path, data)

      unless daily_question['Channel ID']
        event.respond(
          content: "Système de questions journalières activé.\nAucun salon n'est encore configuré, pensez à en choisir un via **Changer le salon**.",
          ephemeral: true
        )
        next
      end

      event.respond(content: "Le système de questions journalières est désormais activé.", ephemeral: true)
    end

    bot.button(custom_id: "dailyquestion_disable") do |event|
      server_id = event.server.id
      data_path = File.join(__dir__, "..", "Data", "Servers", "#{server_id}.json")
      data = load_json(data_path, default: {})

      daily_question = data['Daily Question'] ||= {}

      unless daily_question['Enabled']
        event.respond(content: "Bien tenté, mais le système de questions journalières est déjà désactivé.", ephemeral: true)
        next
      end

      daily_question['Enabled'] = false
      save_json(data_path, data)

      event.respond(content: "Le système de questions journalières est désormais **désactivé**.", ephemeral: true)
    end

    bot.button(custom_id: "dailyquestion_channel") do |event|
      channel_select_view = Discordrb::Components::View.new do |builder|
        builder.row do |r|
          r.channel_select(
            custom_id: "dailyquestion_channel_select",
            placeholder: "Choisissez un salon",
            max_values: 1
          )
        end
      end

      event.respond(
        content: "Sélectionnez le salon dans lequel les questions journalières seront envoyées :",
        components: channel_select_view,
        ephemeral: true
      )
    end

    bot.button(custom_id: "dailyquestion_role") do |event|
      role_select_view = Discordrb::Components::View.new do |builder|
        builder.row do |r|
          r.role_select(
            custom_id: "dailyquestion_role_select",
            placeholder: "Choisissez un rôle",
            max_values: 1
          )
        end
      end

      event.respond(
        content: "Sélectionnez le rôle à mentionner pour les questions journalières :",
        components: role_select_view,
        ephemeral: true
      )
    end

    bot.channel_select(custom_id: "dailyquestion_channel_select") do |event|
        server_id = event.server.id

        selected_channel = event.values.first

        unless selected_channel&.text?
            event.update_message(content: "Merci de choisir un salon textuel.", components: [])
            next
        end

        data_path = File.join(__dir__, "..", "Data", "Servers", "#{server_id}.json")
        data = load_json(data_path, default: {})

        daily_question = data['Daily Question'] ||= {}
        daily_question['Channel ID'] = selected_channel.id

        save_json(data_path, data)

        event.update_message(
            content: "Le salon d'envoi des questions journalières a été défini sur #{selected_channel.mention}.",
            components: []
        )
    end

    bot.role_select(custom_id: "dailyquestion_role_select") do |event|
        server_id = event.server.id

        selected_role = event.values.first

        data_path = File.join(__dir__, "..", "Data", "Servers", "#{server_id}.json")
        data = load_json(data_path, default: {})

        daily_question = data['Daily Question'] ||= {}
        daily_question['Role ID'] = selected_role.id

        save_json(data_path, data)

        event.update_message(
            content: "Le rôle à mentionner pour les questions journalières a été défini sur #{selected_role.mention}.",
            components: []
        )
    end
  end
end