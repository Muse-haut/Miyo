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


class DataCommand < CommandLoader
    self.command_name = "data"
    self.command_desc = "Vous permet de gérer si oui ou non vous acceptez la collectes de données non-personelles."
    self.is_admin_only = false
    self.is_private_message_allowed = true
    def self.register(bot)
        bot.application_command(:data) do |event|
            user_id = event.user.id
            event.defer(ephemeral: true)
            embed_hash = {
            title: "Vous souhaitez gérer vos données ?",
            description: "Vous êtes au bon endroit. Moi, Miyo, collecte quelques données afin de pouvoir bien fonctionner (tel que le système de feur, le gacha...).\nCes données sont stockées localement auprès de moi, non partagées avec des tiers puisqu'elles ne servent qu'à mon fonctionnement, et elles ne sont nommées que par l'id de votre compte. **Aucune autre donnée, hormis celle servant au bon fonctionnement des systèmes en etant relié à votre compte n'est collecté**.\nToutefois, si vous le souhaitez, vous pouvez désactiver ces données collectées. Ainsi, la seule donnée sur vous sauvegardée par mes soins sera dans un fichier afin d'identifier qui ne souhaite pas avoir de données collectées. Toutefois, vous n'aurez plus accès aux systèmes suivants :\n\n- Nombre de feurs (ces données seront supprimés après un relancement du bot, elles sont dans la mémoire vive).\n- Système de Gacha et PVE\n- Notations des albums.\n\nEn désactivant la collecte de ces données, **toutes vos informations seront supprimées et cela sera irréversible**.",
            color: 0x004951,
            timestamp: Time.now.iso8601,
            author: {
                name: "Miyo",
                url: "https://museau.neocities.org/",
                icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
            },
            footer: { text: "Signé,\nMiyo." },
            fields: [
                { name: "Linktree :", value: "[Tous les liens ici !🌳](https://linktr.ee/DiscordbotMiyo)", inline: true }
                ]
            }
            buttons_view = Discordrb::Components::View.new do |builder|
                builder.row do |r|
                r.button(label: "Activer", style: :success, custom_id: "data_enable", emoji: { name: "✅" })
                r.button(label: "Désactiver", style: :danger, custom_id: "data_disable", emoji: { name: "❌" })
                end
            end

            event.edit_response(
                content: "",
                embeds: [embed_hash],
                components: buttons_view
            )
            end
            bot.button(custom_id: "data_enable") do |event|
                user_id = event.user.id.to_s

                data_path = File.join(__dir__, "..", "Data", "Users", "NonDataUsers.json")
                data = load_json(data_path, default: {})

                if data.key?(user_id)
                    data.delete(user_id)
                    save_json(data_path, data)

                    event.respond(
                        content: "La collecte des différentes données est désormais activée.",
                        ephemeral: true
                    )
                else
                    event.respond(
                        content: "La collecte des différentes données est déjà activée.",
                        ephemeral: true
                    )
                end
            end
            bot.button(custom_id: "data_disable") do |event|
                user_id = event.user.id.to_s

                data_path = File.join(__dir__, "..", "Data", "Users", "NonDataUsers.json")
                data = load_json(data_path, default: {})

                if data.key?(user_id)
                    event.respond(
                        content: "La collecte des différentes données est déjà désactivée.",
                        ephemeral: true
                    )
                else
                    data[user_id] = true
                    save_json(data_path, data)

                    event.respond(
                        content: "La collecte des différentes données est désormais désactivée.",
                        ephemeral: true
                    )
                end
            end
        end
    end