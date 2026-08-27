class CommandInfo < CommandLoader
  self.command_name = "info"
  self.command_desc = "Si vous souhaitez afficher différentes informations à propos de Miyo"
  self.is_admin_only = false
  self.is_private_message_allowed = false

  def self.register(bot)
    bot.application_command(:info) do |event|
        embed_hash = {
            title: "Des informations sur moi ? Charmant.",
            description: "Je me prénomme Miyo, à votre service.\n\n**Informations**\nJe suis codé intégralement en Ruby, en utilisant la librairie 'discordrb', majoritairement par mon créateur Museau.\n\n**Remerciements**\nJe remercie l'aide de Cyn, qui a aidé Museau dans son code lorsqu'il en avait besoin.\nUn énorme merci à Linounonu pour mon avatar !\n\nBien, j'en eu trop dit, si vous souhaiter me solliciter, veuillez utiliser la commande !help. Si vous voulez bien m'excuser...",
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
        event.respond(embeds: [embed_hash])
        end
    end
end