require 'json'
require 'fileutils'

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

TVC_TEMP_PATH = File.join(__dir__, '..', 'Data', 'temp_voice_channels.json')
FileUtils.mkdir_p(File.dirname(TVC_TEMP_PATH))

def tvc_load_temp
  return {} unless File.exist?(TVC_TEMP_PATH)
  JSON.parse(File.read(TVC_TEMP_PATH))
rescue
  {}
end

def tvc_save_temp(data)
  File.write(TVC_TEMP_PATH, JSON.pretty_generate(data))
rescue => e
  puts "Erreur sauvegarde temp_voice: #{e.message}"
end

def tvc_register_channel(server_id, channel_id)
  data = tvc_load_temp
  data[server_id.to_s] ||= { 'salons' => [] }
  data[server_id.to_s]['salons'] << channel_id.to_s
  data[server_id.to_s]['salons'].uniq!
  tvc_save_temp(data)
end

def tvc_unregister_channel(server_id, channel_id)
  data = tvc_load_temp
  return unless data[server_id.to_s]
  data[server_id.to_s]['salons'].delete(channel_id.to_s)
  tvc_save_temp(data)
end

def tvc_all_temp_channels(server_id)
  data = tvc_load_temp
  data.dig(server_id.to_s, 'salons') || []
end

class TempVoiceCommand < CommandLoader
  self.command_name             = "vocal_temporaire"
  self.command_desc             = "Configurez un salon vocal temporaire sur votre serveur."
  self.is_admin_only            = true
  self.is_private_message_allowed = false

  def self.register(bot)
    bot.application_command(:vocal_temporaire) do |event|
      is_admin = event.user.roles.any? { |role| role.permissions.administrator } ||
                 EXCLUDED_USERS.include?(event.user.id) ||
                 (event.server.owner && event.user.id == event.server.owner.id)

      unless is_admin
        event.respond(content: "Vous n'avez pas la permission d'utiliser cette commande.", ephemeral: true)
        next
      end

      event.defer(ephemeral: true)

      server_id = event.server.id
      data_path = File.join(__dir__, '..', 'Data', 'Servers', "#{server_id}.json")
      config    = load_json(data_path, default: {})
      tvc       = config['TempVoice'] || {}
      enabled   = tvc['Enabled'] || false
      hub_name  = tvc['HubName'] || '➕ Créer un salon'
      category  = tvc['CategoryID'] ? event.server.channels.find { |c| c.id == tvc['CategoryID'].to_i }&.name : nil

      embed_hash = {
        title: "Salons vocaux temporaires",
        description: "Lorsqu'un membre rejoint le salon hub, un salon vocal privé lui est automatiquement créé. Il en devient propriétaire et peut le renommer, expulser des membres et modifier ses paramètres. Le salon est supprimé dès que tout le monde en est parti.\n\n**État actuel :** #{enabled ? '✅ Activé' : '❌ Désactivé'}",
        color: 0x004951,
        timestamp: Time.now.iso8601,
        author: {
          name: "Miyo",
          url: "https://museau.neocities.org/",
          icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/a36b1d2cafe6ff934a4a2a5c3bf8fbf4.png?size=2048"
        },
        footer: { text: "Signé,\nMiyo." },
        fields: [
          { name: "🎙️ Nom du salon hub", value: "`#{hub_name}`",                              inline: true },
          { name: "📁 Catégorie cible",  value: category ? "`#{category}`" : "*Non configurée*", inline: true },
          { name: "Linktree :",          value: "[Tous les liens ici !🌳](https://linktr.ee/DiscordbotMiyo)", inline: true }
        ]
      }

      buttons_view = Discordrb::Components::View.new do |builder|
        builder.row do |r|
          r.button(label: "Activer",   style: :success,   custom_id: "tvc_enable",        emoji: { name: "✅" }) unless enabled
          r.button(label: "Désactiver", style: :danger,   custom_id: "tvc_disable",        emoji: { name: "❌" }) if enabled
          r.button(label: "Nom du hub", style: :primary,  custom_id: "tvc_set_name",       emoji: { name: "✏️" })
          r.button(label: "Catégorie",  style: :secondary, custom_id: "tvc_set_category",  emoji: { name: "📁" })
        end
      end

      event.edit_response(content: "", embeds: [embed_hash], components: buttons_view)
    end

    bot.button(custom_id: "tvc_enable") do |event|
      server_id = event.server.id
      data_path = File.join(__dir__, '..', 'Data', 'Servers', "#{server_id}.json")
      config    = load_json(data_path, default: {})
      tvc       = config['TempVoice'] ||= {}

      if tvc['Enabled']
        event.respond(content: "Le système de salons vocaux temporaires est déjà activé.", ephemeral: true)
        next
      end

      unless tvc['HubName'] && tvc['CategoryID']
        event.respond(content: "Configurez d'abord le nom du salon hub et la catégorie avant d'activer le système.", ephemeral: true)
        next
      end

      category_channel = event.server.channels.find { |c| c.id == tvc['CategoryID'].to_i && c.type == 4 }

      unless category_channel
        event.respond(content: "La catégorie configurée est introuvable. Veuillez en choisir une nouvelle.", ephemeral: true)
        next
      end

      begin
        hub = event.server.create_channel(tvc['HubName'], 2, parent: category_channel, user_limit: 1)
        tvc['Enabled'] = true
        tvc['HubID']   = hub.id
        config['TempVoice'] = tvc
        save_json(data_path, config)

        hub_name = tvc['HubName']
        category_name = category_channel.name

        updated_embed = {
          title: "Salons vocaux temporaires",
          description: "Lorsqu'un membre rejoint le salon hub, un salon vocal privé lui est automatiquement créé. Il en devient propriétaire et peut le renommer, expulser des membres et modifier ses paramètres. Le salon est supprimé dès que tout le monde en est parti.\n\n**État actuel :** ✅ Activé\n\n✅ Le salon hub **#{hub_name}** a été créé dans la catégorie **#{category_name}**.",
          color: 0x004951,
          timestamp: Time.now.iso8601,
          author: {
            name: "Miyo",
            url: "https://museau.neocities.org/",
            icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/a36b1d2cafe6ff934a4a2a5c3bf8fbf4.png?size=2048"
          },
          footer: { text: "Signé,\nMiyo." },
          fields: [
            { name: "🎙️ Nom du salon hub", value: "`#{hub_name}`",        inline: true },
            { name: "📁 Catégorie cible",  value: "`#{category_name}`",   inline: true },
            { name: "🔗 Salon hub",        value: hub.mention,             inline: true },
            { name: "Linktree :",          value: "[Tous les liens ici !🌳](https://linktr.ee/DiscordbotMiyo)", inline: true }
          ]
        }

        updated_buttons = Discordrb::Components::View.new do |builder|
          builder.row do |r|
            r.button(label: "Désactiver", style: :danger,    custom_id: "tvc_disable",     emoji: { name: "❌" })
            r.button(label: "Nom du hub", style: :primary,   custom_id: "tvc_set_name",    emoji: { name: "✏️" })
            r.button(label: "Catégorie",  style: :secondary, custom_id: "tvc_set_category", emoji: { name: "📁" })
          end
        end

        event.update_message(content: "", embeds: [updated_embed], components: updated_buttons)
      rescue => e
        event.respond(content: "Une erreur est survenue lors de la création du salon : `#{e.message}`", ephemeral: true)
      end
    end

    bot.button(custom_id: "tvc_disable") do |event|
      server_id = event.server.id
      data_path = File.join(__dir__, '..', 'Data', 'Servers', "#{server_id}.json")
      config    = load_json(data_path, default: {})
      tvc       = config['TempVoice'] ||= {}

      unless tvc['Enabled']
        event.respond(content: "Le système de salons vocaux temporaires est déjà désactivé.", ephemeral: true)
        next
      end

      if tvc['HubID']
        begin
          hub_channel = event.server.channels.find { |c| c.id == tvc['HubID'].to_i }
          hub_channel&.delete
        rescue => e
          puts "Erreur suppression hub: #{e.message}"
        end
      end

      tvc['Enabled'] = false
      tvc['HubID']   = nil
      config['TempVoice'] = tvc
      save_json(data_path, config)

      hub_name  = tvc['HubName'] || '➕ Créer un salon'
      category  = tvc['CategoryID'] ? event.server.channels.find { |c| c.id == tvc['CategoryID'].to_i }&.name : nil

      updated_embed = {
        title: "Salons vocaux temporaires",
        description: "Lorsqu'un membre rejoint le salon hub, un salon vocal privé lui est automatiquement créé. Il en devient propriétaire et peut le renommer, expulser des membres et modifier ses paramètres. Le salon est supprimé dès que tout le monde en est parti.\n\n**État actuel :** ❌ Désactivé\n\n❌ Le salon hub a été supprimé.",
        color: 0x004951,
        timestamp: Time.now.iso8601,
        author: {
          name: "Miyo",
          url: "https://museau.neocities.org/",
          icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/a36b1d2cafe6ff934a4a2a5c3bf8fbf4.png?size=2048"
        },
        footer: { text: "Signé,\nMiyo." },
        fields: [
          { name: "🎙️ Nom du salon hub", value: "`#{hub_name}`",                              inline: true },
          { name: "📁 Catégorie cible",  value: category ? "`#{category}`" : "*Non configurée*", inline: true },
          { name: "Linktree :",          value: "[Tous les liens ici !🌳](https://linktr.ee/DiscordbotMiyo)", inline: true }
        ]
      }

      updated_buttons = Discordrb::Components::View.new do |builder|
        builder.row do |r|
          r.button(label: "Activer",    style: :success,   custom_id: "tvc_enable",       emoji: { name: "✅" })
          r.button(label: "Nom du hub", style: :primary,   custom_id: "tvc_set_name",     emoji: { name: "✏️" })
          r.button(label: "Catégorie",  style: :secondary, custom_id: "tvc_set_category", emoji: { name: "📁" })
        end
      end

      event.update_message(content: "", embeds: [updated_embed], components: updated_buttons)
    end

    bot.button(custom_id: "tvc_set_name") do |event|
      event.show_modal(title: "Nom du salon hub", custom_id: "tvc_name_modal") do |modal|
        modal.row do |r|
          r.text_input(
            style:       :short,
            custom_id:   "tvc_name_input",
            label:       "Nom du salon hub",
            placeholder: "➕ Créer un salon",
            required:    true,
            min_length:  2,
            max_length:  100
          )
        end
      end
    end

    bot.modal_submit(custom_id: "tvc_name_modal") do |event|
      server_id = event.server.id
      data_path = File.join(__dir__, '..', 'Data', 'Servers', "#{server_id}.json")
      new_name  = event.value("tvc_name_input")&.strip

      unless new_name && !new_name.empty?
        event.respond(content: "Le nom renseigné est invalide.", ephemeral: true)
        next
      end

      config = load_json(data_path, default: {})
      tvc    = config['TempVoice'] ||= {}

      if tvc['HubID']
        begin
          hub_channel = event.server.channels.find { |c| c.id == tvc['HubID'].to_i }
          hub_channel&.name = new_name
        rescue => e
          puts "Erreur renommage hub: #{e.message}"
        end
      end

      tvc['HubName'] = new_name
      config['TempVoice'] = tvc
      save_json(data_path, config)

      embed_hash = {
        title: "Nom mis à jour",
        description: "Le nom du salon hub a été défini sur **#{new_name}**.",
        color: 0x004951,
        timestamp: Time.now.iso8601,
        author: {
          name: "Miyo",
          url: "https://museau.neocities.org/",
          icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/a36b1d2cafe6ff934a4a2a5c3bf8fbf4.png?size=2048"
        },
        footer: { text: "Signé,\nMiyo." }
      }
      event.respond(content: "", embeds: [embed_hash], ephemeral: true)
    end

    bot.button(custom_id: "tvc_set_category") do |event|
      categories = event.server.channels.select { |c| c.type == 4 }

      if categories.empty?
        event.respond(content: "Aucune catégorie n'a été trouvée sur ce serveur.", ephemeral: true)
        next
      end

      select_view = Discordrb::Components::View.new do |v|
        v.row do |r|
          r.string_select(custom_id: "tvc_category_select", placeholder: "Choisissez une catégorie", max_values: 1) do |ss|
            categories.first(25).each do |cat|
              ss.option(label: cat.name, value: cat.id.to_s, emoji: { name: "📁" })
            end
          end
        end
      end

      embed_hash = {
        title: "Choisir une catégorie",
        description: "Sélectionnez la catégorie dans laquelle le salon hub sera créé. Les salons temporaires seront également créés dans cette catégorie.",
        color: 0x004951,
        timestamp: Time.now.iso8601,
        author: {
          name: "Miyo",
          url: "https://museau.neocities.org/",
          icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/a36b1d2cafe6ff934a4a2a5c3bf8fbf4.png?size=2048"
        },
        footer: { text: "Signé,\nMiyo." }
      }
      event.respond(content: "", embeds: [embed_hash], components: select_view, ephemeral: true)
    end

    bot.string_select(custom_id: "tvc_category_select") do |event|
      server_id   = event.server.id
      data_path   = File.join(__dir__, '..', 'Data', 'Servers', "#{server_id}.json")
      category_id = event.values.first
      category    = event.server.channels.find { |c| c.id == category_id.to_i && c.type == 4 }

      unless category
        event.update_message(content: "La catégorie sélectionnée est introuvable.", components: [])
        next
      end

      config = load_json(data_path, default: {})
      tvc    = config['TempVoice'] ||= {}

      if tvc['HubID']
        begin
          hub_channel = event.server.channels.find { |c| c.id == tvc['HubID'].to_i }
          hub_channel&.parent = category
        rescue => e
          puts "Erreur déplacement hub: #{e.message}"
        end
      end

      tvc['CategoryID'] = category_id
      config['TempVoice'] = tvc
      save_json(data_path, config)

      embed_hash = {
        title: "Catégorie configurée",
        description: "La catégorie **#{category.name}** a été définie pour les salons temporaires.",
        color: 0x004951,
        timestamp: Time.now.iso8601,
        author: {
          name: "Miyo",
          url: "https://museau.neocities.org/",
          icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/a36b1d2cafe6ff934a4a2a5c3bf8fbf4.png?size=2048"
        },
        footer: { text: "Signé,\nMiyo." }
      }
      event.update_message(content: "", embeds: [embed_hash], components: [])
    end

    bot.voice_state_update do |event|
      server = event.server
      next unless server

      server_id = server.id
      data_path = File.join(__dir__, '..', 'Data', 'Servers', "#{server_id}.json")
      config    = load_json(data_path, default: {})
      tvc       = config['TempVoice']
      next unless tvc && tvc['Enabled'] && tvc['HubID']

      user    = event.user
      channel = event.channel

      if channel && channel.id == tvc['HubID'].to_i
        category_id = tvc['CategoryID']&.to_i
        category    = category_id ? server.channels.find { |c| c.id == category_id && c.type == 4 } : nil

        begin
          temp_channel = server.create_channel("🎙️ #{user.display_name}", 2, parent: category)
          temp_channel.define_overwrite(
            user,
            Discordrb::Permissions.new([:manage_channels, :move_members, :mute_members, :deafen_members]),
            Discordrb::Permissions.new
          )
          server.move(user, temp_channel)
          tvc_register_channel(server_id, temp_channel.id)
        rescue => e
          puts "Erreur création salon temporaire: #{e.message}"
        end
      end

      old_channel_id = event.old_channel&.id
      if old_channel_id
        temp_ids = tvc_all_temp_channels(server_id)
        if temp_ids.include?(old_channel_id.to_s)
          old_channel = server.channels.find { |c| c.id == old_channel_id }
          if old_channel && old_channel.users.empty?
            begin
              old_channel.delete
              tvc_unregister_channel(server_id, old_channel_id)
            rescue => e
              puts "Erreur suppression salon vide: #{e.message}"
            end
          end
        end
      end
    end

    bot.ready do |event|
      temp_data = tvc_load_temp
      temp_data.each do |server_id_str, server_entry|
        server = event.bot.servers[server_id_str.to_i]
        next unless server
        (server_entry['salons'] || []).dup.each do |channel_id_str|
          channel = server.channels.find { |c| c.id == channel_id_str.to_i }
          if channel.nil?
            tvc_unregister_channel(server_id_str, channel_id_str)
          elsif channel.users.empty?
            begin
              channel.delete
              tvc_unregister_channel(server_id_str, channel_id_str)
            rescue => e
              puts "Erreur nettoyage salon orphelin: #{e.message}"
            end
          end
        end
      end
    end

  end
end