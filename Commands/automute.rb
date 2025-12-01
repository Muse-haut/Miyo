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

class AutomuteSetCommand < BaseCommand
  def self.register(bot)
    bot.application_command(:automute) do |event|
      is_admin = event.user.roles.any? { |role| role.permissions.administrator } || EXCLUDED_USERS.include?(event.user.id)
      
      unless is_admin
        event.respond(content: "Vous n'avez pas la permission d'utiliser cette commande.", ephemeral: true)
        next
      end

      server_id = event.server.id.to_s
      settings = load_server_settings
      server_settings = settings[server_id] || {}
      lang = server_settings['miyo_language'] || 'french'
      mute_settings = server_settings['miyo_mute_system'] || 'désactivé'

      if lang == 'french'
        embed_hash = {
          title: "Un système pour retirer la voix aux personnes qui ont tendance à se répéter ?",
          description: "Vous êtes au bon endroit. Ce système est actuellement **#{mute_settings}** sur ce serveur.\nVoici ce que je peux vous proposer :\n\n- Activer/Désactiver ce système\n\n**Note** :\n- Ce système ne mutera pas les rôles ayant la permission administrateurs.\n- Il faudra que vous créiez un rôle qui sera attribuer à chacun des utilisateurs avec la permission 'Envoyer des messages', et désactiver cette même permission au rôle 'everyone'.\n- Ce système n'est pas intelligent, il vérifie uniquement les 3 derniers messages de chacun des utilisateurs. Il est conseillé de l'asssocier avec un bot fais pour ça. Toutefois, ce système est ici pour empêcher les comptes qui se font hack de partager des liens/messages problématiques.",
          color: 0x3498db,
          timestamp: Time.now.iso8601,
          author: {
            name: "Miyo",
            url: "https://linktr.ee/Miyo_DiscordBot",
            icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
          },
          footer: { text: "Signé,\nMiyo." }
        }

        components_array = [
          {
            type: 1,
            components: [
              { type: 2, style: 3, label: "Activer", custom_id: "automute_activate_#{server_id}" },
              { type: 2, style: 4, label: "Désactiver", custom_id: "automute_deactivate_#{server_id}" }
            ]
          }
        ]

        event.respond(embeds: [embed_hash], components: components_array)

      elsif lang == 'english'
        embed_hash = {
          title: "A system to mute people who tend to repeat themselves?",
          description: "You're in the right place. This system is currently **#{mute_settings}** on this server.\nHere's what I can offer:\n\n- Enable/Disable this system\n\n**Note**:\n- This system will not mute roles with administrator permissions.\n- You will need to create a role that is assigned to each user with the 'Send Messages' permission, and disable this same permission for the 'everyone' role.\n- This system is not smart; it only checks the last 3 messages of each user. It is recommended to pair it with a bot made for this purpose. However, this system is here to prevent accounts that get hacked from sharing problematic links/messages.",
          color: 0x3498db,
          timestamp: Time.now.iso8601,
          author: {
            name: "Miyo",
            url: "https://linktr.ee/Miyo_DiscordBot",
            icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
          },
          footer: { text: "Signed,\nMiyo." }
        }

        components_array = [
          {
            type: 1,
            components: [
              { type: 2, style: 3, label: "Enable", custom_id: "automute_activate_#{server_id}" },
              { type: 2, style: 4, label: "Disable", custom_id: "automute_deactivate_#{server_id}" }
            ]
          }
        ]

        event.respond(embeds: [embed_hash], components: components_array)
      end
    end

    bot.button(custom_id: /automute_activate_\d+/) do |event|
      event.defer(ephemeral: true)
      member = event.server&.member(event.user.id)
      is_admin = member && (member.roles.any? { |r| r.permissions.administrator } || EXCLUDED_USERS.include?(event.user.id))
      
      unless is_admin
        event.respond(content: "Vous n'avez pas la permission.", ephemeral: true)
        next
      end

      server_id = event.server.id.to_s
      settings = load_server_settings
      server_settings = settings[server_id] || {}
      lang = server_settings['miyo_language'] || 'french'

      server_settings['miyo_mute_system'] = 'activé'
      settings[server_id] = server_settings
      save_server_settings(settings)

      if lang == 'french'
        event.edit_response(content: "Le système Automute a été **activé** !")
      elsif lang == 'english'
        event.edit_response(content: "The Automute system has been **enabled**!")
      end
    end

    bot.button(custom_id: /automute_deactivate_\d+/) do |event|
      event.defer(ephemeral: true)
      member = event.server&.member(event.user.id)
      is_admin = member && (member.roles.any? { |r| r.permissions.administrator } || EXCLUDED_USERS.include?(event.user.id))
      
      unless is_admin
        event.respond(content: "Vous n'avez pas la permission.", ephemeral: true)
        next
      end

      server_id = event.server.id.to_s
      settings = load_server_settings
      server_settings = settings[server_id] || {}
      lang = server_settings['miyo_language'] || 'french'

      server_settings['miyo_mute_system'] = 'désactivé'
      settings[server_id] = server_settings
      save_server_settings(settings)

      if lang == 'french'
        event.edit_response(content: "Le système Automute a été **désactivé** !")
      elsif lang == 'english'
        event.edit_response(content: "The Automute system has been **disabled**!")
      end
    end
  end
end





