class CommandHelp < CommandLoader
  self.command_name = "help"
  self.command_desc = "Si vous souhaitez afficher différentes informations à propos de Miyo"
  self.is_admin_only = false
  self.is_private_message_allowed = false

  def self.register(bot)
    categories = {
      "fun" => {
        label: "Fun",
        emoji: "🎉",
        description: "Commandes visant au divertissement des membres.",
        fields: [
          { name: "/8ball", value: "Pose une question à la boule magique", inline: true },
          { name: "/meme", value: "Envoie un mème aléatoire", inline: true }
        ]
      },
      "moderation" => {
        label: "Modération",
        emoji: "🛡️",
        description: "Différentes commandes visant la gestion du serveur et de systèmes que vous pouvez activer ou non.",
        fields: [
          { name: "/exclure", value: "Met en isolement temporaire un membre.", inline: true },
          { name: "/kick", value: "Expulse un membre.", inline: true },
          { name: "/ban", value: "Bannit un membre.", inline: true }
        ]
      }
    }

    build_menu = lambda do |view|
      view.row do |row|
        row.select_menu(custom_id: "help_category") do |select|
          categories.each do |key, cat|
            select.option(label: cat[:label], value: key, description: cat[:description], emoji: cat[:emoji])
          end
        end
      end
    end

    bot.application_command(:help) do |event|
        embed_hash = {
        title: "Mes salutations !",
        description: "Je me prénomme Miyo, à votre service.\nJe dispose de plusieurs commandes que vous pourrez utiliser sur votre serveur. Choisissez une des catégories ci-dessous afin de voir la liste des commandes correspondantes à la catégorie que vous choisirez.",
        color: 0x004951,
        timestamp: Time.now.iso8601,
        author: {
            name: "Miyo",
            url: "https://museau.neocities.org/",
            icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/a36b1d2cafe6ff934a4a2a5c3bf8fbf4.png?size=2048"
        },
        footer: { text: "Signé,\nMiyo." },
        fields: [
            { name: "Linktree :", value: "[Tous les liens ici !🌳](https://linktr.ee/Miyo_DiscordBot)", inline: true },
            ]
        }
        event.respond(embeds: [embed_hash]) do |_builder, view|
            build_menu.call(view)
        end
    end

    bot.select_menu(custom_id: "help_category") do |event|
        selected = categories[event.values.first]

        embed_hash = {
        title: "#{selected[:emoji]} Catégorie : #{selected[:label]}",
        description: selected[:description],
        color: 0x004951,
        timestamp: Time.now.iso8601,
        author: {
            name: "Miyo",
            url: "https://museau.neocities.org/",
            icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/a36b1d2cafe6ff934a4a2a5c3bf8fbf4.png?size=2048"
        },
        footer: { text: "Signé,\nMiyo." },
        fields: selected[:fields]
        }

        event.update_message(embeds: [embed_hash]) do |_builder, view|
            build_menu.call(view)
        end
    end
  end
end