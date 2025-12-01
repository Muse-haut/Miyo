require 'json'
require 'net/http'
require 'uri'

def load_server_settings
  data_file = File.join(__dir__, '../Data/dataserver.json') 
  unless File.exist?(data_file)
    File.write(data_file, "{}")
  end
  JSON.parse(File.read(data_file))
end

def load_server_language_settings(server_id)
  data_file = File.join(__dir__, '../Data/dataserver.json') 
  return 'french' unless File.exist?(data_file)

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

class AlbumSearchCommand < BaseCommand
  NUMBER_EMOJIS = ["1️⃣","2️⃣","3️⃣","4️⃣","5️⃣","6️⃣","7️⃣","8️⃣","9️⃣","🔟"]
  SESSION_TTL = 5 * 60
  
  @@album_pages = {}
  @@albums_data = nil
  @@bot_token = nil

  def self.album_pages
    @@album_pages
  end

  def self.albums_data
    @@albums_data
  end

  def self.albums_data=(value)
    @@albums_data = value
  end

  def self.bot_token
    @@bot_token
  end

  def self.bot_token=(value)
    @@bot_token = value
  end

  def self.load_albums_data
    albums_file = File.join(__dir__, '../Data/albums.json')
    @@albums_data = JSON.parse(File.read(albums_file))
    migrated = false
    @@albums_data.each do |artist, data|
      next unless data.is_a?(Hash) && data['albums'].is_a?(Hash)
      data['albums'].each do |al, info|
        next unless info.is_a?(Hash)
        if info.key?('note') && !info.key?('notes')
          info['notes'] = { '0' => info.delete('note') }
          migrated = true
        end
      end
    end
    
    if migrated
      File.open(albums_file, 'w') do |f|
        f.flock(File::LOCK_EX)
        f.write(JSON.pretty_generate(@@albums_data))
        f.flock(File::LOCK_UN)
      end
    end
  end

  def self.truncate_str(s, max_len = 100)
    s = s.to_s
    return s if s.length <= max_len
    s[0, max_len - 1] + "…"
  end

  def self.build_album_embed_hash(artist_name, album_name, album_data, viewer_id: nil, artist_data: nil)
      if artist_data.nil? && @@albums_data && @@albums_data[artist_name]
        artist_data = @@albums_data[artist_name]
      end

      return { error: "Données de l'album invalides." } unless album_data.is_a?(Hash)
      genres = artist_data&.dig("genres")&.join(", ") || "N/C"
      popularite = artist_data&.dig("popularite") || "N/C"
      followers_raw = artist_data&.dig("followers")
      followers = followers_raw ? followers_raw.to_s.reverse.scan(/\d{1,3}/).join(" ").reverse : "N/C"
      image_groupe = artist_data&.dig("image_groupe")
      lien_spotify = artist_data&.dig("lien_spotify")&.to_s || ""
      star_tracks = []
      if artist_data && artist_data["star_tracks"].is_a?(Array)
        star_tracks = artist_data["star_tracks"].map.with_index do |t, i|
          "#{i + 1}. **#{t['titre']}** — Popularité: #{t['popularite']}/100"
        end
      end
      img_album = album_data["img_album"]
      release = album_data["date_sortie"] || "N/C"
      pop_album = album_data["popularite"] || "N/C"
      duree_tot = album_data["duree_totale"] || "N/C"
      nbr_tracks = album_data["nbr_tracks"] || 0
      lien_album = album_data["lien_spotify"] || ""
      tracks = album_data["tracklist"] || {}
      formatted_tracks = tracks.each_with_index.map do |(titre, infos), i|
        expl = infos["explicite"] ? "🔞" : ""
        "#{i + 1}. **#{titre}** #{expl} — #{infos['duree']} (pop: #{infos['popularite']}/100)"
      end
      track_fields = []
      chunk = ""
      part = 1
      
      formatted_tracks.each do |line|
        if (chunk + line + "\n").length > 1024
          track_fields << { 
            name: part == 1 ? "Tracklist" : "Tracklist (suite #{part})", 
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
      description_parts = []
      description_parts << "**Genre(s)** : #{genres}"
      description_parts << "**Popularité groupe** : #{popularite}/100"
      description_parts << "**Followers** : #{followers}"
      description_parts << "**Lien Spotify** : <#{lien_spotify}>" unless lien_spotify.empty?
      description = description_parts.join("\n")
      embed = {
        title: "🎵 #{artist_name} — #{album_name}",
        description: description,
        color: 0x3498db,
        timestamp: Time.now.iso8601,
        footer: { text: "Signé,\nMiyo." },
        fields: []
      }
      if image_groupe
        embed[:author] = { name: artist_name, icon_url: image_groupe }
      end
      embed[:thumbnail] = { url: img_album } if img_album
      embed[:fields] << { 
        name: "📀 Album", 
        value: "**Sortie :** #{release}\n**Durée :** #{duree_tot}\n**Tracks :** #{nbr_tracks}\n**Popularité :** #{pop_album}/100\n<#{lien_album}>", 
        inline: false 
      }
      unless star_tracks.empty?
        embed[:fields] << {
          name: "⭐ Titres populaires",
          value: star_tracks.join("\n"),
          inline: false
        }
      end
      embed[:fields].concat(track_fields)
      
      embed
  end


  def self.build_page_payload(matches, page, per_page = 10)
    total = matches.size
    pages = (total.to_f / per_page).ceil
    page = [[0, page].max, [pages - 1, page].min].min

    start_index = page * per_page
    slice = matches[start_index, per_page] || []

    desc = slice.each_with_index.map do |m, i|
      idx = start_index + i + 1
      album_data = m[:data]

      popularite = album_data["popularite"]
      date_sortie = album_data["date_sortie"]
      duree = album_data["duree_totale"]

      infos = []
      infos << "⏱️ #{duree}" if duree

      infos_text = infos.empty? ? "" : " *(#{infos.join(' • ')})*"

      "**#{idx}.** #{m[:artist]} — #{m[:album]}#{infos_text}"
    end.join("\n")

    embed_hash = {
      title: "Résultats de la recherche",
      description: desc.empty? ? "Aucun résultat sur cette page." : desc,
      color: 0x3498db,
      timestamp: Time.now.iso8601,
      footer: { text: "Page #{page + 1}/#{pages} • Sélectionne dans le menu ci-dessous" }
    }

    options = slice.map.with_index do |m, i|
      absolute_index = start_index + i
      album_data = m[:data]

      img = album_data["img_album"]
      base_label = "#{m[:artist]} - #{m[:album]}"

      {
        label: truncate_str(base_label, 100),
        value: absolute_index.to_s,
        description: "Popularité #{album_data['popularite']}/100 | #{album_data['nbr_tracks']} tracks",
        emoji: (img ? { name: "💿" } : { name: "🎵" })
      }
    end

    components_array = [
      {
        type: 1,
        components: [
          { type: 2, style: 2, label: 'Précédent', custom_id: 'albums_prev', emoji: { name: '⬅️' } },
          { type: 2, style: 2, label: 'Suivant', custom_id: 'albums_next', emoji: { name: '➡️' } },
          { type: 2, style: 4, label: 'Fermer', custom_id: 'albums_close', emoji: { name: '❌' } }
        ]
      },
      {
        type: 1,
        components: [
          {
            type: 3,
            custom_id: 'albums_select_menu',
            placeholder: "Choisis un album (page #{page + 1})",
            min_values: 1,
            max_values: 1,
            options: options
          }
        ]
      }
    ]

    [embed_hash, components_array, page, pages]
  end


  def self.build_new_search_components
    [
      {
        type: 1,
        components: [
          { 
            type: 2, 
            style: 1, 
            label: 'Nouvelle recherche', 
            custom_id: 'album_new_search',
            emoji: { name: '🔍' }
          }
        ]
      }
    ]
  end

  def self.build_new_search_embed
    {
      title: "Recherche d'albums 🎵",
      description: "Cliquez sur le bouton **Nouvelle recherche** ci-dessous pour lancer une recherche d'album ou d'artiste.\n\nVous pourrez ensuite :\n• Entrer le nom d'un artiste ou d'un album\n• Choisir le type de recherche (artist/album)",
      color: 0x3498db,
      timestamp: Time.now.iso8601,
      footer: { text: "Signé,\nMiyo." }
    }
  end

  def self.build_rating_menu_components(message_id, album_index, show_tracks: false)
    if show_tracks
      state = @@album_pages[message_id]
      return [] unless state && state[:matches] && state[:matches][album_index]
      
      match = state[:matches][album_index]
      tracklist = match[:data]['tracklist'] || {}
      
      return [] if tracklist.empty?
      
      options = tracklist.keys.first(25).map.with_index do |track_name, i|
        {
          label: truncate_str(track_name, 100),
          value: "#{message_id}|||#{album_index}|||track|||#{i}",
          description: "Cliquez pour noter cette track"
        }
      end
      
      [
        {
          type: 1,
          components: [
            {
              type: 3,
              custom_id: 'track_select_to_rate',
              placeholder: 'Choisir une track à noter',
              min_values: 1,
              max_values: 1,
              options: options
            }
          ]
        },
        {
          type: 1,
          components: [
            { type: 2, style: 2, label: 'Noter l\'album', custom_id: 'rate_album_mode', emoji: { name: '💿' } },
            { type: 2, style: 2, label: 'Retour', custom_id: 'album_back_to_list', emoji: { name: '⬅️' } },
            { type: 2, style: 4, label: 'Fermer', custom_id: 'albums_close', emoji: { name: '❌' } }
          ]
        }
      ]
    else
      options = (1..10).map do |i|
        { 
          label: i.to_s, 
          value: "#{message_id}|||#{album_index}|||album|||#{i}", 
          emoji: { name: NUMBER_EMOJIS[i - 1] } 
        }
      end

      [
        {
          type: 1,
          components: [
            { 
              type: 3, 
              custom_id: 'album_rate', 
              placeholder: 'Noter cet album (1-10)', 
              min_values: 1, 
              max_values: 1, 
              options: options 
            }
          ]
        },
        {
          type: 1,
          components: [
            { type: 2, style: 1, label: 'Noter les tracks', custom_id: 'rate_tracks_mode', emoji: { name: '🎵' } },
            { type: 2, style: 2, label: 'Retour', custom_id: 'album_back_to_list', emoji: { name: '⬅️' } },
            { type: 2, style: 4, label: 'Fermer', custom_id: 'albums_close', emoji: { name: '❌' } }
          ]
        }
      ]
    end
  end

  def self.send_message_with_components(channel_id, embed_hash, components_array)
    payload = { content: "" }
    payload[:components] = components_array if components_array && !components_array.empty?
    payload[:embeds] = [embed_hash] if embed_hash && (!embed_hash.respond_to?(:empty?) || !embed_hash.empty?)

    uri = URI("https://discord.com/api/v10/channels/#{channel_id}/messages")
    req = Net::HTTP::Post.new(uri)
    req['Authorization'] = @@bot_token
    req['Content-Type'] = 'application/json'
    req.body = payload.to_json
    
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      res = http.request(req)
      unless res.is_a?(Net::HTTPSuccess)
        puts "Erreur API Discord (send message): #{res.code} #{res.body}"
        return nil
      end
      JSON.parse(res.body) rescue nil
    end
  end

  def self.edit_message_with_components(channel_id, message_id, embed_hash, components_array)
    payload = {}
    payload[:embeds] = [embed_hash] if embed_hash
    payload[:components] = components_array if components_array

    uri = URI("https://discord.com/api/v10/channels/#{channel_id}/messages/#{message_id}")
    req = Net::HTTP::Patch.new(uri)
    req['Authorization'] = @@bot_token
    req['Content-Type'] = 'application/json'
    req.body = payload.to_json
    
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      res = http.request(req)
      unless res.is_a?(Net::HTTPSuccess)
        puts "Erreur API Discord (edit message): #{res.code} #{res.body}"
        return nil
      end
      JSON.parse(res.body) rescue nil
    end
  end

  def self.acknowledge_interaction(event)
    if event.respond_to?(:defer_update)
      begin
        event.defer_update
        return :deferred
      rescue => e
        puts "defer_update failed: #{e.class} #{e.message}"
        return :failed
      end
    end
    :failed
  end
  def self.user_wants_data_collection?(user_id)
    non_data_users_file = File.join(__dir__, '../User data/nondatausers.json')
    return false unless File.exist?(non_data_users_file)
    
    non_data_users = JSON.parse(File.read(non_data_users_file)) rescue []
    non_data_users.include?(user_id.to_s)
  end

  def self.register(bot)
    self.bot_token = bot.token
    load_albums_data
    bot.application_command(:album).subcommand(:search) do |event|
      query = event.options['query']
      search_type = event.options['type'] || 'album'

      if query.nil? || query.strip.empty?
        event.respond(content: "Argument `query` manquant.", ephemeral: true)
        next
      end

      q = query.strip.downcase
      matches = []

      AlbumSearchCommand.albums_data.each do |artist, data|
        next unless data['albums'].is_a?(Hash)
        data['albums'].each do |album, info|
          case search_type
          when 'artist'
            matches << { artist: artist, album: album, data: info } if artist.downcase.include?(q)
          when 'album'
            matches << { artist: artist, album: album, data: info } if album.downcase.include?(q)
          else
            matches << { artist: artist, album: album, data: info } if artist.downcase.include?(q) || album.downcase.include?(q)
          end
        end
      end

      matches.sort_by! { |m| search_type == 'artist' ? m[:artist].downcase : m[:album].downcase }

      if matches.empty?
        embed_hash = {
          title: "Aucun résultat trouvé",
          description: "Aucun album ou artiste ne correspond à votre recherche : `#{q}`\n\nEssayez avec d'autres mots-clés !",
          color: 0xe74c3c,
          timestamp: Time.now.iso8601,
          footer: { text: "Signé,\nMiyo." }
        }
        
        components = build_new_search_components
        AlbumSearchCommand.send_message_with_components(event.channel.id, embed_hash, components)
        next
      end

      if matches.size == 1
        m = matches.first
        embed_hash = AlbumSearchCommand.build_album_embed_hash(m[:artist], m[:album], m[:data], viewer_id: event.user.id, artist_data: m[:artist_data])
        
        temp_res = AlbumSearchCommand.send_message_with_components(event.channel.id, embed_hash, [])
        
        if temp_res.is_a?(Hash) && temp_res['id']
          message_id = temp_res['id'].to_i
          AlbumSearchCommand.album_pages[message_id] = {
            matches: matches,
            selected_index: 0,
            page: 0,
            per_page: 1,
            total_pages: 1,
            author_id: event.user.id,
            channel_id: event.channel.id,
            expires_at: Time.now + SESSION_TTL
          }
          
          rating_components = AlbumSearchCommand.build_rating_menu_components(message_id, 0)
          AlbumSearchCommand.edit_message_with_components(event.channel.id, message_id, embed_hash, rating_components)
        end
        next
      end

      per_page = 10
      page = 0
      embed_hash, components, page, total_pages = AlbumSearchCommand.build_page_payload(matches, page, per_page)
      
      res = AlbumSearchCommand.send_message_with_components(event.channel.id, embed_hash, components)

      if res.is_a?(Hash) && res['id']
        message_id = res['id'].to_i
        AlbumSearchCommand.album_pages[message_id] = {
          matches: matches,
          page: page,
          per_page: per_page,
          total_pages: total_pages,
          author_id: event.user.id,
          channel_id: event.channel.id,
          expires_at: Time.now + SESSION_TTL
        }
      end
    end
    bot.select_menu(custom_id: 'albums_select_menu') do |event|
      value = event.values.first
      index = value.to_i
      orig_msg = event.message

      state = AlbumSearchCommand.album_pages[orig_msg.id]
      album_data = nil
      artist = nil
      album = nil
      absolute_index = index

      if state && state[:matches] && state[:matches][absolute_index]
        m = state[:matches][absolute_index]
        artist = m[:artist]
        album = m[:album]
        album_data = m[:data]
        state[:selected_index] = absolute_index
        state[:expires_at] = Time.now + SESSION_TTL
      end

      if album_data && album_data.is_a?(Hash)
        AlbumSearchCommand.acknowledge_interaction(event)
        embed_hash = AlbumSearchCommand.build_album_embed_hash(artist, album, album_data, viewer_id: event.user.id, artist_data: state[:matches][absolute_index][:artist_data])
        rating_components = AlbumSearchCommand.build_rating_menu_components(orig_msg.id, absolute_index, show_tracks: false)

        begin
          AlbumSearchCommand.edit_message_with_components(event.channel.id, orig_msg.id, embed_hash, rating_components)
        rescue => e
          puts "Erreur envoi / edit après sélection: #{e.class} #{e.message}"
        end
      else
        event.respond(content: "Impossible de charger l'album sélectionné.", ephemeral: true)
      end
    end
    bot.button(custom_id: 'albums_prev') do |event|
      state = AlbumSearchCommand.album_pages[event.message.id]
      if state && event.user.id == state[:author_id]
        AlbumSearchCommand.acknowledge_interaction(event)
        new_page = state[:page] - 1
        embed_hash, components, new_page, total_pages = AlbumSearchCommand.build_page_payload(state[:matches], new_page, state[:per_page])
        AlbumSearchCommand.edit_message_with_components(state[:channel_id], event.message.id, embed_hash, components)
        state[:page] = new_page
        state[:total_pages] = total_pages
        state[:expires_at] = Time.now + SESSION_TTL
      else
        event.respond(content: "Cette session n'est plus valide ou ne vous appartient pas.", ephemeral: true)
      end
    end
    bot.button(custom_id: 'albums_next') do |event|
      state = AlbumSearchCommand.album_pages[event.message.id]
      if state && event.user.id == state[:author_id]
        AlbumSearchCommand.acknowledge_interaction(event)
        new_page = state[:page] + 1
        embed_hash, components, new_page, total_pages = AlbumSearchCommand.build_page_payload(state[:matches], new_page, state[:per_page])
        AlbumSearchCommand.edit_message_with_components(state[:channel_id], event.message.id, embed_hash, components)
        state[:page] = new_page
        state[:total_pages] = total_pages
        state[:expires_at] = Time.now + SESSION_TTL
      else
        event.respond(content: "Cette session n'est plus valide ou ne vous appartient pas.", ephemeral: true)
      end
    end
    bot.button(custom_id: 'albums_close') do |event|
      state = AlbumSearchCommand.album_pages.delete(event.message.id)
      if state && event.user.id == state[:author_id]
        AlbumSearchCommand.acknowledge_interaction(event)
        
        new_search_embed = AlbumSearchCommand.build_new_search_embed
        new_search_components = AlbumSearchCommand.build_new_search_components
        
        AlbumSearchCommand.edit_message_with_components(
          state[:channel_id], 
          event.message.id, 
          new_search_embed, 
          new_search_components
        )
      else
        event.respond(content: "Impossible de fermer : session expirée ou non autorisée.", ephemeral: true)
      end
    end
    bot.button(custom_id: 'album_new_search') do |event|
      event.show_modal(
        title: 'Recherche d\'albums',
        custom_id: 'album_search_modal'
      ) do |modal|
        modal.row do |row|
          row.text_input(
            style: :short,
            custom_id: 'search_query',
            label: 'Nom de l\'artiste ou de l\'album',
            placeholder: 'Ex: Daft Punk, Random Access Memories...',
            required: true,
            min_length: 1,
            max_length: 100
          )
        end
        modal.row do |row|
          row.text_input(
            style: :short,
            custom_id: 'search_type',
            label: 'Type de recherche (artist/album)',
            placeholder: 'artist ou album (défaut: album)',
            required: false,
            max_length: 10
          )
        end
      end
    end
    bot.modal_submit(custom_id: 'album_search_modal') do |event|
      query = event.value('search_query')
      search_type_input = event.value('search_type')
      search_type = search_type_input.nil? || search_type_input.empty? ? 'album' : search_type_input.downcase.strip

      unless ['artist', 'album'].include?(search_type)
        event.respond(content: "⚠️ Type de recherche invalide. Utilisez 'artist' ou 'album'.", ephemeral: true)
        next
      end

      if query.nil? || query.strip.empty?
        event.respond(content: "⚠️ Veuillez entrer un nom à rechercher.", ephemeral: true)
        next
      end

      event.defer_update

      begin
        event.message.delete
      rescue => e
        puts "Impossible de supprimer le message: #{e.message}"
      end

      q = query.strip.downcase
      matches = []

      AlbumSearchCommand.albums_data.each do |artist, data|
        next unless data['albums'].is_a?(Hash)
        data['albums'].each do |album, info|
          case search_type
          when 'artist'
            matches << { artist: artist, album: album, data: info, artist_data: data } if artist.downcase.include?(q)
          when 'album'
            matches << { artist: artist, album: album, data: info, artist_data: data } if album.downcase.include?(q)
          end
        end
      end

      matches.sort_by! { |m| search_type == 'artist' ? m[:artist].downcase : m[:album].downcase }

      if matches.empty?
        embed_hash = {
          title: "Aucun résultat trouvé",
          description: "Aucun album ou artiste ne correspond à votre recherche : `#{query}`\n\nEssayez avec d'autres mots-clés !",
          color: 0xe74c3c,
          timestamp: Time.now.iso8601,
          footer: { text: "Signé,\nMiyo." }
        }
        
        components = AlbumSearchCommand.build_new_search_components
        res = AlbumSearchCommand.send_message_with_components(event.channel.id, embed_hash, components)
        next
      end

      if matches.size == 1
        m = matches.first
        embed_hash = AlbumSearchCommand.build_album_embed_hash(m[:artist], m[:album], m[:data], viewer_id: event.user.id)
        
        temp_res = AlbumSearchCommand.send_message_with_components(event.channel.id, embed_hash, [])
        
        if temp_res.is_a?(Hash) && temp_res['id']
          message_id = temp_res['id'].to_i
          AlbumSearchCommand.album_pages[message_id] = {
            matches: matches,
            selected_index: 0,
            page: 0,
            per_page: 1,
            total_pages: 1,
            author_id: event.user.id,
            channel_id: event.channel.id,
            expires_at: Time.now + SESSION_TTL
          }
          
          rating_components = AlbumSearchCommand.build_rating_menu_components(message_id, 0)
          AlbumSearchCommand.edit_message_with_components(event.channel.id, message_id, embed_hash, rating_components)
        end
        next
      end

      per_page = 10
      page = 0
      embed_hash, components, page, total_pages = AlbumSearchCommand.build_page_payload(matches, page, per_page)
      
      res = AlbumSearchCommand.send_message_with_components(event.channel.id, embed_hash, components)

      if res.is_a?(Hash) && res['id']
        message_id = res['id'].to_i
        AlbumSearchCommand.album_pages[message_id] = {
          matches: matches,
          page: page,
          per_page: per_page,
          total_pages: total_pages,
          author_id: event.user.id,
          channel_id: event.channel.id,
          expires_at: Time.now + SESSION_TTL
        }
      end
    end

    bot.button(custom_id: 'album_back_to_list') do |event|
      state = AlbumSearchCommand.album_pages[event.message.id]
      if state && event.user.id == state[:author_id]
        AlbumSearchCommand.acknowledge_interaction(event)
        embed_hash, components, page, total_pages = AlbumSearchCommand.build_page_payload(
          state[:matches], 
          state[:page], 
          state[:per_page]
        )
        
        AlbumSearchCommand.edit_message_with_components(
          state[:channel_id], 
          event.message.id, 
          embed_hash, 
          components
        )
        
        state[:expires_at] = Time.now + SESSION_TTL
      else
        event.respond(content: "Cette session n'est plus valide ou ne vous appartient pas.", ephemeral: true)
      end
    end
    bot.select_menu(custom_id: 'album_rate') do |event|
      user_id = event.user.id
      if AlbumSearchCommand.user_wants_data_collection?(user_id) == true
        event.respond(content: "Veuillez changer vos paramètres de confidentialité avec /data. Vous avez désactiver la collecte de celle-ci.", ephemeral: true) rescue nil
      else

        value = event.values.first
        parts = value.split('|||', 5)
        
        if parts.length < 4
          event.respond(content: "Valeur de note invalide.", ephemeral: true) rescue nil
          next
        end

        orig_msg_id = parts[0].to_i
        absolute_index = parts[1].to_i
        rate_type = parts[2] # 'album' ou 'track'
        chosen_note = parts[3].to_i

        state = AlbumSearchCommand.album_pages[orig_msg_id]
        unless state && state[:matches] && state[:matches][absolute_index]
          event.respond(content: "⚠ Session introuvable ou expirée — impossible d'appliquer la note.", ephemeral: true) rescue nil
          next
        end

        match = state[:matches][absolute_index]
        artist = match[:artist]
        album = match[:album]

        if AlbumSearchCommand.albums_data.dig(artist, 'albums', album)
          user_key = event.user.id.to_s
          AlbumSearchCommand.albums_data[artist]['albums'][album]['notes'] ||= {}
          AlbumSearchCommand.albums_data[artist]['albums'][album]['notes'][user_key] = chosen_note

          begin
            albums_file = File.join(__dir__, '../Data/albums.json')
            File.open(albums_file, 'w') do |f|
              f.flock(File::LOCK_EX)
              f.write(JSON.pretty_generate(AlbumSearchCommand.albums_data))
              f.flock(File::LOCK_UN)
            end
          rescue => e
            puts "Erreur écriture JSON notes: #{e.class} #{e.message}"
            event.respond(content: "⚠ Erreur lors de la sauvegarde de la note.", ephemeral: true) rescue nil
            next
          end

          event.respond(content: "✅ Note enregistrée : **#{chosen_note}/10** pour l'album **#{album}** — **#{artist}**.", ephemeral: true) rescue nil

          begin
            new_embed_hash = AlbumSearchCommand.build_album_embed_hash(artist, album, AlbumSearchCommand.albums_data[artist]['albums'][album], viewer_id: event.user.id, artist_data: match[:artist_data])
            rating_components = AlbumSearchCommand.build_rating_menu_components(orig_msg_id, absolute_index, show_tracks: false)
            AlbumSearchCommand.edit_message_with_components(state[:channel_id], orig_msg_id, new_embed_hash, rating_components)
          rescue => e
            puts "Erreur update embed après note: #{e.class} #{e.message}"
          end
        else
          event.respond(content: "⚠ Impossible de sauvegarder la note : album introuvable dans le JSON.", ephemeral: true) rescue nil
        end
      end
    end
    bot.button(custom_id: 'rate_tracks_mode') do |event|
      state = AlbumSearchCommand.album_pages[event.message.id]
      if state && event.user.id == state[:author_id] && state[:selected_index]
        AlbumSearchCommand.acknowledge_interaction(event)
        
        match = state[:matches][state[:selected_index]]
        artist = match[:artist]
        album = match[:album]
        album_data = match[:data]
        
        embed_hash = AlbumSearchCommand.build_album_embed_hash(artist, album, album_data, viewer_id: event.user.id, artist_data: match[:artist_data])
        track_components = AlbumSearchCommand.build_rating_menu_components(event.message.id, state[:selected_index], show_tracks: true)
        
        AlbumSearchCommand.edit_message_with_components(state[:channel_id], event.message.id, embed_hash, track_components)
        state[:expires_at] = Time.now + SESSION_TTL
      else
        event.respond(content: "Cette session n'est plus valide ou ne vous appartient pas.", ephemeral: true)
      end
    end
    bot.button(custom_id: 'rate_album_mode') do |event|
      state = AlbumSearchCommand.album_pages[event.message.id]
      if state && event.user.id == state[:author_id] && state[:selected_index]
        AlbumSearchCommand.acknowledge_interaction(event)
        
        match = state[:matches][state[:selected_index]]
        artist = match[:artist]
        album = match[:album]
        album_data = match[:data]
        
        embed_hash = AlbumSearchCommand.build_album_embed_hash(artist, album, album_data, viewer_id: event.user.id, artist_data: match[:artist_data])
        rating_components = AlbumSearchCommand.build_rating_menu_components(event.message.id, state[:selected_index], show_tracks: false)
        
        AlbumSearchCommand.edit_message_with_components(state[:channel_id], event.message.id, embed_hash, rating_components)
        state[:expires_at] = Time.now + SESSION_TTL
      else
        event.respond(content: "Cette session n'est plus valide ou ne vous appartient pas.", ephemeral: true)
      end
    end
    bot.select_menu(custom_id: 'track_select_to_rate') do |event|
      value = event.values.first
      parts = value.split('|||', 4)
      
      if parts.length != 4
        event.respond(content: "Valeur invalide.", ephemeral: true) rescue nil
        next
      end

      orig_msg_id = parts[0].to_i
      absolute_index = parts[1].to_i
      track_index = parts[3].to_i

      state = AlbumSearchCommand.album_pages[orig_msg_id]
      unless state && state[:matches] && state[:matches][absolute_index]
        event.respond(content: "⚠ Session introuvable.", ephemeral: true) rescue nil
        next
      end

      match = state[:matches][absolute_index]
      tracklist = match[:data]['tracklist'] || {}
      track_name = tracklist.keys[track_index]
      
      unless track_name
        event.respond(content: "⚠ Track introuvable.", ephemeral: true) rescue nil
        next
      end
      event.show_modal(
        title: "Noter: #{truncate_str(track_name, 40)}",
        custom_id: "track_rate_modal|||#{orig_msg_id}|||#{absolute_index}|||#{track_index}"
      ) do |modal|
        modal.row do |row|
          row.text_input(
            style: :short,
            custom_id: 'track_rating',
            label: 'Note (1-10)',
            placeholder: 'Entrez une note entre 1 et 10',
            required: true,
            min_length: 1,
            max_length: 2
          )
        end
      end
    end
    bot.modal_submit(custom_id: /track_rate_modal/) do |event|
      parts = event.custom_id.split('|||', 4)
      
      if parts.length != 4
        event.respond(content: "Erreur de traitement.", ephemeral: true) rescue nil
        next
      end

      orig_msg_id = parts[1].to_i
      absolute_index = parts[2].to_i
      track_index = parts[3].to_i
      
      rating_input = event.value('track_rating')
      chosen_note = rating_input.to_i
      
      unless chosen_note.between?(1, 10)
        event.respond(content: "⚠️ La note doit être entre 1 et 10.", ephemeral: true)
        next
      end

      state = AlbumSearchCommand.album_pages[orig_msg_id]
      unless state && state[:matches] && state[:matches][absolute_index]
        event.respond(content: "⚠ Session introuvable.", ephemeral: true) rescue nil
        next
      end

      event.defer_update

      match = state[:matches][absolute_index]
      artist = match[:artist]
      album = match[:album]
      tracklist = match[:data]['tracklist'] || {}
      track_name = tracklist.keys[track_index]

      if track_name && AlbumSearchCommand.albums_data.dig(artist, 'albums', album, 'tracklist', track_name)
        user_key = event.user.id.to_s
        AlbumSearchCommand.albums_data[artist]['albums'][album]['tracklist'][track_name]['notes'] ||= {}
        AlbumSearchCommand.albums_data[artist]['albums'][album]['tracklist'][track_name]['notes'][user_key] = chosen_note

        begin
          albums_file = File.join(__dir__, '../Data/albums.json')
          File.open(albums_file, 'w') do |f|
            f.flock(File::LOCK_EX)
            f.write(JSON.pretty_generate(AlbumSearchCommand.albums_data))
            f.flock(File::LOCK_UN)
          end
          event.channel.send_message("✅ <@#{event.user.id}> : Note **#{chosen_note}/10** enregistrée pour **#{track_name}** !")
        rescue => e
          puts "Erreur écriture JSON track notes: #{e.class} #{e.message}"
        end
      end
    end
    Thread.new do
      loop do
        begin
          now = Time.now
          AlbumSearchCommand.album_pages.dup.each do |msg_id, state|
            next unless state[:expires_at] && state[:expires_at] <= now
            begin
              new_search_embed = AlbumSearchCommand.build_new_search_embed
              new_search_components = AlbumSearchCommand.build_new_search_components
              
              AlbumSearchCommand.edit_message_with_components(
                state[:channel_id], 
                msg_id, 
                new_search_embed, 
                new_search_components
              )
            rescue => e
              puts "Erreur lors de la désactivation d'une session expirée: #{e.class} #{e.message}"
            end
            AlbumSearchCommand.album_pages.delete(msg_id)
          end
        rescue => e
          puts "Cleaner thread error: #{e.class} #{e.message}"
        end
        sleep 15
      end
    end
  end
end