class CommandExpulser < CommandLoader
  self.command_name = "kick"
  self.command_desc = "Expulser un membre du serveur (il peut revenir avec une invitation)"
  self.is_admin_only = true
  self.is_private_message_allowed = false

  self.required_options = [
    { type: :user, name: "membre", desc: "Le membre à expulser" }
  ]
  self.optional_options = [
    { type: :string, name: "raison", desc: "La raison de l'expulsion" }
  ]

  def self.register(bot)
    bot.application_command(:expulser) do |event|
      member_id = event.options["membre"]
      reason = event.options["raison"] || "Aucune raison fournie"

      target = event.server.member(member_id)

      unless target
        event.respond(content: "Membre introuvable sur ce serveur.")
        next
      end

      target.kick(reason)
      embed_hash = {
        description: "#{target.distinct} a été expulsé.\nRaison : #{reason}",
        color: 0x004951,
        timestamp: Time.now.iso8601,
        author: {
            name: "Miyo",
            url: "https://museau.neocities.org/",
            icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/a36b1d2cafe6ff934a4a2a5c3bf8fbf4.png?size=2048"
        },
        footer: { text: "Signé,\nMiyo." },
      }
    event.respond(embeds: [embed_hash])
    end
  end
end
