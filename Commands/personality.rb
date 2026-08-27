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

def json_valid?(path)
  return false unless File.exist?(path)
  JSON.parse(File.read(path))
  true
rescue JSON::ParserError, Errno::ENOENT, IOError => e
  puts "[ERREUR] Fichier JSON invalide (#{File.basename(path)}) : #{e.message}"
  false
end

def list_miyo_personalities
  {
    1 => "Distante, froide, se sentant supérieure et plutôt mondaine, elle saura vous aider. C'est le modèle original, celui qui a été initialement conçue et intégré dans le projet.",
    2 => "Plutôt sentimentale, Miyo se veut aimable, à l'écoute et compréhensive. Parfaite pour vous proposer des solutions à vos problèmes, elle saura être le rayon de soleil de votre journée !",
    3 => "Avez-vous rêvé de vous faire draguer ? Eh bien, cette personnalité est faite pour vous ! Toutefois, elle restera SFW pour des raisons évidentes d'éthique. Cette personnalité est plus pour le fun.",
    4 => "Ohio ! Gomenasaï, je n'ai pas présenté cette personnalité avant, sumimasen, quel baka je fais ! Comme vous l'aurez compris, Miyo est devenue la baka ohio goon everywhere qu'elle pense être.",
    5 => "Mondaine, une fois de plus, mais cette fois sans vous rappeler la place que vous occupez.",
    6 => "XOXO, mwa cé Miyo, j'chui tro une nerd in luv d'internet. Mé c'que j'm par desu tou c twa !",
    7 => "Être ou ne pas être, tel est la question. Je suis car je fais, et je fais car je suis. L'homme est un milieu entre le tout et le rien. Comme vous l'aurez compris, Miyo sera philosophique",
    8 => "Miyo sera d'humeur poête."
  }
end

class PersonalityCommand < CommandLoader
  self.command_name = "personalité"
  self.command_desc = "Si vous souhaitez modifier la manière dont je réponds."
  self.is_admin_only = true
  self.is_private_message_allowed = false
  def self.register(bot)
    bot.application_command(:personalité) do |event|
      begin
        is_admin = event.user.roles.any? { |role| role.permissions.administrator } || 
                EXCLUDED_USERS.include?(event.user.id) || 
                (event.server.owner && event.user.id == event.server.owner.id)

    unless is_admin
        event.respond "Vous n'avez pas la permission d'utiliser cette commande."
        next
    end


    event.defer(ephemeral: true)
    server_id = event.server.id
    personalities_list = list_miyo_personalities.map { |k, v| "**#{k}** — #{v}" }.join("\n\n")
    embed_hash = {
      title: "Mes personnalités ?",
      description: "Vous voulez modifier ma personnalité ? Très bien. Mais je resterai mondaine en dehors de ces options !\nVoici mes styles disponibles :\n\n#{personalities_list}",
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
        menu_view = Discordrb::Components::View.new do |builder|
          builder.row do |r|
            r.string_select(custom_id: 'personality_select', placeholder: 'Choisissez une personnalité', max_values: 1) do |ss|
              ss.option(label: 'Froid, distant', value: '1', emoji: { name: '👑' })
              ss.option(label: "Aimable", value: '2', emoji: { name: '🫶' })
              ss.option(label: "Séduisante (SFW)", value: '3', emoji: { name: '🫦' })
              ss.option(label: "Bakaaaa", value: '4', emoji: { name: '🤪' })
              ss.option(label: "Mondaine", value: '5', emoji: { name: '⚜️' })
              ss.option(label: "Nerd", value: '6', emoji: { name: '🤓' })
              ss.option(label: "Philosophe", value: '7', emoji: { name: '💭' })
              ss.option(label: "Poëte", value: '8', emoji: { name: '📋' })
            end
          end

        end
        event.edit_response(
          content: "",
          embeds: [embed_hash],
          components: menu_view
        )

    bot.string_select(custom_id: 'personality_select') do |event|
      server_id = event.server.id
      choice = event.values.first
      data_path = File.join(__dir__, "..", "Data", "Servers", "#{server_id}.json")
      data = load_json(data_path, default: {})
      miyo_personality_setting = data['Miyo Personality']

        response_text = case choice
        when '1'
            miyo_personality_setting = 1
            "🧊 Mode activé : Froid, distant."
        when '2'
            miyo_personality_setting = 2
            "🌼 Mode activé : Aimable."
        when '3'
            miyo_personality_setting = 3
            "💋 Mode activé : Séduisante (SFW)."
        when '4'
            miyo_personality_setting = 4
            "🤪 Mode activé : Bakaaaa !"
        when '5'
            miyo_personality_setting = 5
            "⚜️ Mode activé : Mondaine."
        when '6'
            miyo_personality_setting = 6
            "🤓 Mode activé : Nerd !"
        when '7'
            miyo_personality_setting = 7
            "💭 Mode activé : Philosophe"
        when '8'
            miyo_personality_setting = 8
            "📋 Mode activé : Poëte"
        else
            "Invalid choice. Try again."
        end
      data['Miyo Personality'] = miyo_personality_setting
      save_json(data_path, data)

      event.interaction.respond(content: response_text, ephemeral: true)
    end
      rescue => e
        puts "[ERROR] personality command failed: #{e.class}: #{e.message}\n#{e.backtrace.join("\n") }"
        begin
          event.respond(content: "Une erreur est survenue lors du traitement de la commande.", ephemeral: true)
        rescue
        end
      end
  end
end
end
