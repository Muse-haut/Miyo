"""
Miyo is a totally independant project. Her source code can be found on github.
It's not the best template for a discord, you can use it as you please, but please credit me somewhere in your bot/github/website...
If you want more details about the bot, contact me on Discord or join the server.
"""

##############
# Depedencies
##############

require 'discordrb' # Well, that's just the point of the code. But you can remove it i guess
require 'httparty' # Better if you want to use some info from the web
require 'json' # Idk how to use sql so this better works
require 'net/http' # Internet (again)
require 'uri' # also for internet (so much omg)
require 'nokogiri' # That's also for internet
require 'fileutils' # If you want to modify a file or smth idk
require 'rufus-scheduler' # if you want to send/do scheduled messages/actions
require 'tzinfo' # Better if you want to step up from a dummy code which don't know what's time to a dummy code, but know the time zone
require 'tzinfo/data' #Same but with data
require 'rufus-scheduler' # For all the commands that are scheduled

require_relative 'commandloader'

history      = {}
muted_roles  = {}

#############
# Connect the bot
#############
config = JSON.parse(File.read('logininfo.json'))
scheduler = Rufus::Scheduler.new
album_data = 'Data/albums.json'
RATING_SESSIONS_FILE = 'Data/rating_sessions.json'
servers_file = 'Data/dataserver.json'
servers_data = JSON.parse(File.read(servers_file))

CLIENT_ID         = config['Miyo']['Client_id']
osu_client_id     = config['Miyo']['Osu_client_id']
osu_client_secret = config['Miyo']['Osu_client_secret']
miyo_token        = config['Miyo']['token']
miyo_prefix       = config['Miyo']['prefix']
MY_USER_ID = config['Me']['id'].to_i
API_KEY = config['Miyo']['API_DP']

bot = Discordrb::Commands::CommandBot.new(token: miyo_token, prefix: miyo_prefix)




def load_mute_system_from_starboard(server_id)
  file_path = "Data/dataserver.json"
  return false unless File.exist?(file_path)

  data = JSON.parse(File.read(file_path)) rescue {}
  server_data = data[server_id.to_s]
  return false unless server_data

  raw = server_data["miyo_mute_system"]

  result =
    case raw
    when TrueClass  then true
    when FalseClass then false
    when Integer    then raw != 0
    when String     then %w[1 true yes on].include?(raw.strip.downcase)
    else
      false
    end
  result
end

def load_rating_sessions
  return {} unless File.exist?(RATING_SESSIONS_FILE)
  JSON.parse(File.read(RATING_SESSIONS_FILE))
rescue => e
  puts "Erreur chargement sessions: #{e.message}"
  {}
end
def load_rating_sessions
  return {} unless File.exist?(RATING_SESSIONS_FILE)
  JSON.parse(File.read(RATING_SESSIONS_FILE))
rescue => e
  puts "Erreur chargement sessions: #{e.message}"
  {}
end

def save_rating_sessions(sessions)
  File.write(RATING_SESSIONS_FILE, JSON.pretty_generate(sessions))
rescue => e
  puts "Erreur sauvegarde sessions: #{e.message}"
end

bot.server_create do |event|
  server = event.server

  # Trouver simplement le premier salon texte
  channel = server.text_channels.first

  if channel
    embed_hash = {
      title: "Greetings!",
      description: "My name is Miyo, nice to meet you, I guess...\nBefore anything, I would like you yo use two of my commands :\n\n- language : You can set my language\n- personality : You can set my personnality with premade ones.\n\nWithout that, I won't be able to use my fonctionality to the full. You can do as you like, of course, I won't judge... But it would mean that you're a really special one, if you see what I mean...",
      color: 0x3498db,
      timestamp: Time.now.iso8601,
      author: {
        name: "Miyo",
        url: "https://fr.tipeee.com/miyo-bot-discord/",
        icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
      },
      footer: { text: "Signé,\nMiyo." },
      fields: [
        { name: "Linktree :", value: "[All the links there !🌳](https://linktr.ee/Miyo_DiscordBot)", inline: true },
        { name: "Discord Place :", value: "[Disboard alternative 🙌](https://discordplace.com/)", inline: true }
      ]
    }

    channel.send_message('', false, embed_hash)
    puts "[INFO] Message de bienvenue envoyé sur #{server.name} (#{channel.name})"
  else
    puts "[WARN] Aucun salon texte trouvé sur #{server.name}"
  end
end

scheduler.cron '00 10 * * *' do
  sessions = load_rating_sessions
  
  # Charger les données des albums
  albums_file = File.join(__dir__, 'Data/albums.json')
  albums_data = JSON.parse(File.read(albums_file))
  
  servers_data.each do |server_id, config|
    next unless config.dig('everyday_album', 'active')
    
    channel_id = config['everyday_album']['channel_id']
    channel = bot.channel(channel_id.to_i)
    next unless channel
    
    # Sélection aléatoire d'un artiste
    artist_name = albums_data.keys.sample
    artist_data = albums_data[artist_name]
    
    # Vérifier que l'artiste a bien des albums
    albums = artist_data['albums'] || {}
    next if albums.empty?
    
    # Sélection aléatoire d'un album
    album_name = albums.keys.sample
    album_data = albums[album_name]  # <- CECI contient les données de L'ALBUM uniquement
    
    # Créer l'ID de session
    session_id = "#{server_id}_#{Time.now.to_i}"
    
    # Construire l'embed avec les bonnes données
    # album_data = données de l'album (popularité, tracklist, etc.)
    # artist_data = données complètes de l'artiste (genres, followers, star_tracks, etc.)
    embed_hash = build_daily_album_embed(
      artist_name,    # Nom de l'artiste
      album_name,     # Nom de l'album
      album_data,     # Données de l'album uniquement
      artist_data     # Données complètes de l'artiste
    )
    
    # Construire les composants de notation
    components = build_daily_album_rating_menu(session_id, album_data)
    
    # Envoyer le message
    message = channel.send_message('', false, embed_hash, nil, nil, nil, components)
    
    # Sauvegarder la session
    sessions[session_id] = {
      'server_id' => server_id,
      'channel_id' => channel_id,
      'message_id' => message.id,
      'artist' => artist_name,
      'album' => album_name,
      'created_at' => Time.now.to_i
    }
    
    save_rating_sessions(sessions)
  end
end

# Fonction pour construire l'embed quotidien
def build_daily_album_embed(artist_name, album_name, album_data, artist_data)
  # Extraire les infos de l'artiste (avec fallbacks)
  genres = artist_data&.dig("genres")&.join(", ") || "N/C"
  popularite = artist_data&.dig("popularite") || "N/C"
  followers_raw = artist_data&.dig("followers")
  followers = followers_raw ? followers_raw.to_s.reverse.scan(/\d{1,3}/).join(" ").reverse : "N/C"
  image_groupe = artist_data&.dig("image_groupe")
  lien_spotify = artist_data&.dig("lien_spotify")&.to_s || ""
  
  # Construction des top tracks
  star_tracks = []
  if artist_data && artist_data["star_tracks"].is_a?(Array)
    star_tracks = artist_data["star_tracks"].map.with_index do |t, i|
      "#{i + 1}. **#{t['titre']}** — Popularité: #{t['popularite']}/100"
    end
  end
  
  # Données de l'album
  img_album = album_data["img_album"]
  release = album_data["date_sortie"] || "N/C"
  pop_album = album_data["popularite"] || "N/C"
  duree_tot = album_data["duree_totale"] || "N/C"
  nbr_tracks = album_data["nbr_tracks"] || 0
  lien_album = album_data["lien_spotify"] || ""
  
  # Construction de la tracklist
  tracks = album_data["tracklist"] || {}
  formatted_tracks = tracks.each_with_index.map do |(titre, infos), i|
    expl = infos["explicite"] ? "🔞" : ""
    "#{i + 1}. **#{titre}** #{expl} — #{infos['duree']} (pop: #{infos['popularite']}/100)"
  end
  
  # Découpage de la tracklist en chunks de 1024 caractères max
  track_fields = []
  chunk = ""
  part = 1
  
  formatted_tracks.each do |line|
    if (chunk + line + "\n").length > 1024
      track_fields << { 
        name: part == 1 ? "**Tracklist**" : "Tracklist (suite #{part})", 
        value: chunk.rstrip, 
        inline: false 
      }
      chunk = line + "\n"
      part += 1
    else
      chunk += line + "\n"
    end
  end
  
  track_fields << {
    name: part == 1 ? "**Tracklist**" : "Tracklist (suite #{part})",
    value: chunk.rstrip,
    inline: false
  } unless chunk.strip.empty?
  
  # Construction de la description (toujours non vide)
  description_parts = []
  description_parts << "🎵 **Album du jour !**\n"
  description_parts << "**Genre(s)** : #{genres}"
  description_parts << "**Popularité groupe** : #{popularite}/100"
  description_parts << "**Followers** : #{followers}"
  description_parts << "**Lien Spotify** : <#{lien_spotify}>" unless lien_spotify.empty?
  
  description = description_parts.join("\n")
  
  # Construction de l'embed
  embed = {
    title: "🎵 #{artist_name} — #{album_name}",
    description: description,
    color: 0x3498db,
    timestamp: Time.now.iso8601,
    footer: { text: "Notez cet album avec le menu ci-dessous • Signé, Miyo." },
    fields: []
  }
  
  # Ajouter l'auteur avec l'image si disponible
  if image_groupe
    embed[:author] = { name: artist_name, icon_url: image_groupe }
  end
  
  # Ajouter la miniature de l'album si disponible
  embed[:thumbnail] = { url: img_album } if img_album
  
  # Ajout des infos album
  embed[:fields] << { 
    name: "📀 Album", 
    value: "**Sortie :** #{release}\n**Durée :** #{duree_tot}\n**Tracks :** #{nbr_tracks}\n**Popularité :** #{pop_album}/100\n<#{lien_album}>", 
    inline: false 
  }
  
  # Ajout des top tracks
  unless star_tracks.empty?
    embed[:fields] << {
      name: "⭐ Titres populaires",
      value: star_tracks.join("\n"),
      inline: false
    }
  end
  
  # Ajout de la tracklist
  embed[:fields].concat(track_fields)
  
  embed
end

# Fonction pour construire le menu de notation
def build_daily_album_rating_menu(session_id, album_data)
  number_emojis = ["1️⃣","2️⃣","3️⃣","4️⃣","5️⃣","6️⃣","7️⃣","8️⃣","9️⃣","🔟"]
  
  options = (1..10).map do |i|
    { 
      label: "#{i}/10", 
      value: "#{session_id}|||#{i}",
      description: "Noter cet album #{i}/10",
      emoji: { name: number_emojis[i - 1] } 
    }
  end

  [
    {
      type: 1,
      components: [
        { 
          type: 3, 
          custom_id: 'daily_album_rate', 
          placeholder: 'Notez cet album (1-10)',
          min_values: 1, 
          max_values: 1, 
          options: options 
        }
      ]
    },
    {
      type: 1,
      components: [
        { 
          type: 2, 
          style: 5, # Style link
          label: 'Écouter sur Spotify',
          url: album_data["lien_spotify"] || "https://open.spotify.com"
        }
      ]
    }
  ]
end

bot.command :chene do |event|
  event.message.delete
  event.channel.send_embed do |embed|
    embed.title = "Une commande secrète à été découverte !"
    embed.description = "Je ne devrais partager cette information... Toutefois, il est bon de rire quelques fois. Voici une image des plus embarrassante qu'a pris Chene."
    embed.color = 0x3498db
    embed.timestamp = Time.now
    embed.image = { url: "https://cdn.discordapp.com/attachments/1322197461745406106/1343345093075009566/Design_sans_titre_14.png?ex=67bd97dc&is=67bc465c&hm=0c810320e3c03932b1bdfc6073761902dfa84cfd1b8114b686d99b56517a1d58&" }
  end
end

load_commands(bot)
bot.run