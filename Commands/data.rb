class DataCommand < BaseCommand
  DATA_DIR = File.join(__dir__, '../User data')
  NON_DATA_USERS_FILE = File.join(DATA_DIR, 'nondatausers.json')

  def self.register(bot)
    Dir.mkdir(DATA_DIR) unless Dir.exist?(DATA_DIR)

    bot.application_command(:data) do |event|
      user_id = event.user.id
      lang = get_language(event)

      if lang == 'french'
        embed_hash = {
          title: "Vous souhaitez gérer vos données ?",
          description: "Vous êtes au bon endroit. Moi, Miyo, collecte quelques données afin de pouvoir bien fonctionner (tel que le système de feur, le gacha...).\nCes données sont stockées localement auprès de moi, non partagées avec des tiers puisqu'elles ne servent qu'à mon fonctionnement, et elles ne sont nommées que par l'id de votre compte. **Aucune autre donnée, hormis celle servant au bon fonctionnement des systèmes en etant relié à votre compte n'est collecté**.\nToutefois, si vous le souhaitez, vous pouvez désactiver ces données collectées. Ainsi, la seule donnée sur vous sauvegardée par mes soins sera dans un fichier afin d'identifier qui ne souhaite pas avoir de données collectées. Toutefois, vous n'aurez plus accès aux systèmes suivants :\n\n- Nombre de feurs (ces données seront supprimés après un relancement du bot, elles sont dans la mémoire vive).\n- Système de Gacha et PVE\n- Notations des albums.\n\nEn désactivant la collecte de ces données, **toutes vos informations seront supprimées et cela sera irréversible**.",
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
            { name: "Discord Place : ", value: "[Alternative à Disboard 🙌](https://discordplace.com/)", inline: true }
          ]
        }
      elsif lang == 'english'
        embed_hash = {
          title: "Wanna control your data?",
          description: "You're in the right place. I, Miyo, collect some data to fulfill my mission (such as the gacha or the album rating).\nThese data are stored locally with me, and aren't shared with any third party services since their only purpose is to make some of my systems work, and they're only named by the id of your account. **There's no other collected data than the ones that makes the bot works properly that can be linked to your account.**\nNevertheless, if you desire so, you can disable these collected data. In that case, the only data saved by me will be in a file which will only contain the id of the people who don't want their data to be collected. However, there is a catch. If you disable these data, you will no longer be able to access these systems:\n\n- Feur system\n- Gacha and PVE system\n- Rating for the albums\n\nMoreover, if you disable these data, **all of your data will be lost forever** (a very long time).",
          color: 0x3498db,
          timestamp: Time.now.iso8601,
          author: {
            name: "Miyo",
            url: "https://fr.tipeee.com/miyo-bot-discord/",
            icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
          },
          footer: { text: "Signed,\nMiyo." },
          fields: [
            { name: "Linktree :", value: "[All the links here!🌳](https://linktr.ee/Miyo_DiscordBot)", inline: true },
            { name: "Discord Place : ", value: "[Disboard alternative!🙌](https://discordplace.com/)", inline: true }
          ]
        }
      end

      components_array = [
        {
          type: 1,
          components: [
            { type: 2, style: 3, label: lang == 'french' ? "Activer" : "Enable", custom_id: "data_activate_#{user_id}" },
            { type: 2, style: 4, label: lang == 'french' ? "Désactiver" : "Disable", custom_id: "data_deactivate_#{user_id}" }
          ]
        }
      ]

      event.respond(embeds: [embed_hash], components: components_array)
    end
    bot.button(custom_id: /^data_activate_(\d+)$/) do |event|
      begin
        match = event.custom_id.match(/^data_activate_(\d+)$/)
        user_id = match[1]
        server_id = event.server&.id
        lang = server_id ? DataCommand.load_server_language_settings(server_id) : 'french'

        if event.user.id.to_s != user_id
          event.respond(content: lang == 'french' ? "Ce bouton n'est pas pour vous !" : "This button is not for you!", ephemeral: true)
          next
        end

        if DataCommand.data_collection_disabled?(user_id)
          DataCommand.enable_data_collection(user_id)
          message = lang == 'french' ? "✅ La collecte de données a été activée !" : "✅ Data collection has been enabled!"
          event.respond(content: message, ephemeral: true)
        else
          message = lang == 'french' ? "La collecte de données est déjà activée." : "Data collection is already enabled."
          event.respond(content: message, ephemeral: true)
        end
      rescue => e
        puts "Error in data_activate: #{e.message}"
        puts e.backtrace
        event.respond(content: "Une erreur est survenue. / An error occurred.", ephemeral: true)
      end
    end
    bot.button(custom_id: /^data_deactivate_(\d+)$/) do |event|
      begin
        match = event.custom_id.match(/^data_deactivate_(\d+)$/)
        user_id = match[1]
        server_id = event.server&.id
        lang = server_id ? DataCommand.load_server_language_settings(server_id) : 'french'

        if event.user.id.to_s != user_id
          event.respond(content: lang == 'french' ? "Ce bouton n'est pas pour vous !" : "This button is not for you!", ephemeral: true)
          next
        end

        if DataCommand.data_collection_disabled?(user_id)
          message = lang == 'french' ? "La collecte de données est déjà désactivée." : "Data collection is already disabled."
          event.respond(content: message, ephemeral: true)
        else
          confirmation_embed = {
            title: lang == 'french' ? "⚠️ Confirmation requise" : "⚠️ Confirmation required",
            description: lang == 'french' ? 
              "Êtes-vous sûr de vouloir désactiver la collecte de données ?\n\n**Toutes vos données seront supprimées définitivement et vous n'aurez plus accès aux systèmes suivants :**\n- Nombre de feurs\n- Système de Gacha et PVE\n- Notations des albums" :
              "Are you sure you want to disable data collection?\n\n**All your data will be permanently deleted and you will no longer have access to the following systems:**\n- Feur system\n- Gacha and PVE system\n- Album ratings",
            color: 0xe74c3c
          }

          confirmation_components = [
            {
              type: 1,
              components: [
                { type: 2, style: 4, label: lang == 'french' ? "Oui, supprimer" : "Yes, delete", custom_id: "data_confirm_delete_#{user_id}" },
                { type: 2, style: 2, label: lang == 'french' ? "Non, annuler" : "No, cancel", custom_id: "data_cancel_delete_#{user_id}" }
              ]
            }
          ]

          event.respond(embeds: [confirmation_embed], components: confirmation_components, ephemeral: true)
        end
      rescue => e
        puts "Error in data_deactivate: #{e.message}"
        puts e.backtrace
        event.respond(content: "An error occurred.", ephemeral: true)
      end
    end
    bot.button(custom_id: /^data_confirm_delete_(\d+)$/) do |event|
      begin
        match = event.custom_id.match(/^data_confirm_delete_(\d+)$/)
        user_id = match[1]
        server_id = event.server&.id
        lang = server_id ? DataCommand.load_server_language_settings(server_id) : 'french'

        if event.user.id.to_s != user_id
          event.respond(content: lang == 'french' ? "Ce bouton n'est pas pour vous !" : "This button is not for you!", ephemeral: true)
          next
        end

        DataCommand.disable_data_collection(user_id)
        message = lang == 'french' ? 
          "🗑️ Vos données ont été supprimées et la collecte a été désactivée." :
          "🗑️ Your data has been deleted and collection has been disabled."
        
        event.update_message(content: message, embeds: [], components: [])
      rescue => e
        puts "Error in data_confirm_delete: #{e.message}"
        puts e.backtrace
        event.respond(content: "Une erreur est survenue. / An error occurred.", ephemeral: true)
      end
    end
    bot.button(custom_id: /^data_cancel_delete_(\d+)$/) do |event|
      begin
        match = event.custom_id.match(/^data_cancel_delete_(\d+)$/)
        user_id = match[1]
        server_id = event.server&.id
        lang = server_id ? DataCommand.load_server_language_settings(server_id) : 'french'

        if event.user.id.to_s != user_id
          event.respond(content: lang == 'french' ? "Ce bouton n'est pas pour vous !" : "This button is not for you!", ephemeral: true)
          next
        end

        message = lang == 'french' ? "❌ Opération annulée." : "❌ Operation cancelled."
        event.update_message(content: message, embeds: [], components: [])
      rescue => e
        puts "Error in data_cancel_delete: #{e.message}"
        puts e.backtrace
        event.respond(content: "Une erreur est survenue. / An error occurred.", ephemeral: true)
      end
    end
  end

  def self.data_collection_disabled?(user_id)
    return false unless File.exist?(NON_DATA_USERS_FILE)
    
    non_data_users = JSON.parse(File.read(NON_DATA_USERS_FILE)) rescue []
    non_data_users.include?(user_id.to_s)
  end

  def self.enable_data_collection(user_id)
    return unless File.exist?(NON_DATA_USERS_FILE)
    
    non_data_users = JSON.parse(File.read(NON_DATA_USERS_FILE)) rescue []
    non_data_users.delete(user_id.to_s)
    File.write(NON_DATA_USERS_FILE, JSON.generate(non_data_users))
  end

  def self.disable_data_collection(user_id)
    user_file = File.join(DATA_DIR, "#{user_id}.json")
    File.delete(user_file) if File.exist?(user_file)
    feur_file = File.join(__dir__, '../Data/feur.json')
    if File.exist?(feur_file)
      begin
        feur_data = JSON.parse(File.read(feur_file))
        if feur_data.key?(user_id.to_s)
          feur_data.delete(user_id.to_s)
          File.write(feur_file, JSON.pretty_generate(feur_data))
        end
      rescue JSON::ParserError

      end
    end
    non_data_users = if File.exist?(NON_DATA_USERS_FILE)
                       JSON.parse(File.read(NON_DATA_USERS_FILE)) rescue []
                     else
                       []
                     end
    
    non_data_users << user_id.to_s unless non_data_users.include?(user_id.to_s)
    File.write(NON_DATA_USERS_FILE, JSON.generate(non_data_users))
  end

  def self.get_language(event)
    server_id = event.server_id
    return 'french' unless server_id
    
    load_server_language_settings(server_id)
  end

  def self.load_server_language_settings(server_id)
    data_file = File.join(__dir__, '../Data/dataserver.json')
    return 'french' unless File.exist?(data_file)
    
    data = JSON.parse(File.read(data_file))
    server_data = data[server_id.to_s]
    return 'french' unless server_data
    
    language = server_data["miyo_language"] || "english"
    language
  end
end