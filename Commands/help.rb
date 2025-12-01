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

puts "Loading HelpCommand file..."

class HelpCommand < BaseCommand
  def self.register(bot)
    bot.application_command(:help) do |event|
      server_id = event.server.id
      lang = load_server_language_settings(server_id)

      if lang == 'french'
        embed_hash = {
          title: "Mes salutations !",
          description: "Je me prénomme Miyo, à votre service.\nJe dispose de quelques commandes que vous pourrez utiliser tout du long de mon histoire sur ce serveur. \n### Fun\n- /twotruthonelie : vous permet de lancer un mini jeu avec un ami.\n### Osu\n- /osurelated osu osulink : permet de lier votre nom de compte osu avec votre id sur discord. Facilite l'utilisation de la commande '!rs' et 'osu'\n- /osurelated osu osuunlink : permet permet de délier votre nom de compte osu avec votre id sur discord.\n- /osurelated osu rs : permet de voir le score le plus récent d'un joueur osu.\n- /osurelated osu random_map : permet de trouver une beatmap adaptée à votre demande.\n### Interactions\n- !kiss : vous permet d'embrasser quelqu'un... Quelle commande futile.\n- !hug : vous permet de câliner quelqu'un... Enfin, si vous avez quelqu'un à câliner.\n- !punch : vous permet de frapper quelqu'un. Veuillez l'utiliser à tout moment, les affrontement de personnes inférieurs à la noblesse est tellement divertissant.\n- !trigger : afin d'exprimer votre colère.\n### Commandes modérateur\n- /welcome : vous permet de configurer un système de bienvenue sur votre serveur.\n- /autoban : vous permet de configurer un système d'autoban (plus d'informations en faisant la commande)\n- /personality : Vous permet de changer ma personnalité lors de mes interactions avec l'ia. À noter que mes messages, lors de mes commandes, ne changerons pas.\n- /language : Vous permet de changer ma langue lors de mes messages prédéfinis et pour l'IA.\n### Musique\n- Album search : Vous permet de chercher les informations et de noter un album dans la base de données de Miyo.\n- Albumset : Vous permet de paramètrer un envois d'album quotidien.\n\nÉgalement, je réagis à certains mots, il faudra que vous discutiez pour tous les connaîtres. Si vous me le permettez, ma présentation se termine ici, et j'espère qu'elle saura vous convaincre. Si vous souhaitez me solliciter, mentionnez-moi, je me ferais une (fausse) joie de vous répondre.",
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
            { name: "Discord Place : ​", value: "[Alternative à Disboard 🙌](https://discordplace.com/)", inline: true }
          ]
        }

      event.respond(embeds: [embed_hash])

      elsif lang == 'english'
        embed_hash = {
          title: "Greetings !",
          description: "My name is Miyo, at your service.\nI have a few commands you can use throughout my story on this server.\n### Fun\n- !talk : gives you a random sentence from all the words and people I know\n### Osu\n- !osulink : links your osu account name with your Discord ID. Makes using the '!rs' and 'osu' commands easier\n- !osuunlink : unlinks your osu account name from your Discord ID\n- !rs : shows the most recent score of an osu player\n- !osu : shows the most recent score of an osu player\n- !osurdm : helps you find a beatmap suited to your request\n### Interactions\n- !kiss : lets you kiss someone... What a futile command.\n- !hug : lets you hug someone... If you even have someone to hug.\n- !punch : lets you punch someone. Feel free to use it anytime, watching commoners fight is quite entertaining.\n- !trigger : to express your anger.\n### Moderator Commands\n- !welcome : lets you set up a welcome system on your server.\n- !autoban : lets you set up an autoban system (more info by using the command)\n- !personality : let you change my personality during AI interactions.\n- !language : let you change my language\n\nNote that my messages during commands will not change.\n\nI also react to certain words — you’ll have to talk to me to discover them all. If you allow me, this concludes my introduction, and I hope it will convince you. If you wish to summon me, mention me, and I’ll make a (fake) delight of replying to you.",
          color: 0x3498db,
          timestamp: Time.now.iso8601,
          author: {
            name: "Miyo",
            url: "https://fr.tipeee.com/miyo-bot-discord/",
            icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
          },
          footer: { text: "Signed,\nMiyo." },
          fields: [
            { name: "Linktree :", value: "[All the links here !🌳](https://linktr.ee/Miyo_DiscordBot)", inline: true },
            { name: "Discord Place : ​", value: "[Disboard alternative !🙌](https://discordplace.com/)", inline: true }
          ]
        }

        event.respond(embeds: [embed_hash])
      end
    end
  end
end

