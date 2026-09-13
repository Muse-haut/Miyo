class AlbumStatsCommand < CommandLoader
  self.command_name = "albumstats"
  self.command_desc = "Affiche des statistiques globales sur les albums enregistrés."
  self.is_admin_only = false
  self.is_private_message_allowed = true

  def self.register(bot)
    bot.application_command(:albumstats) do |event|
      event.defer
      data_path = File.join(__dir__, "..", "Data", "stats.json")
      data = load_json(data_path, default: {})

      if data.empty? || data["total_artists"].to_i.zero?
        event.edit_response(content: "La base de données d'albums est actuellement vide ou introuvable.")
        next
      end

      total_artists = data["total_artists"]
      total_albums = data["total_albums"]
      total_tracks = data["total_tracks"]
      artist_most_albums = data["artist_most_albums"]
      max_albums = data["max_albums"]
      best_album_name = data["best_album_name"]
      best_album_artist = data["best_album_artist"]
      best_album_fans = data["best_album_fans"]

      embed_hash = {
        title: "📊 Statistiques de la base d'albums",
        description: "Voici un aperçu des données musicales actuellement enregistrées par le bot.",
        color: 0x004951,
        timestamp: Time.now.iso8601,
        fields: [
          { name: "Artistes enregistrés", value: total_artists.to_s, inline: true },
          { name: "Albums enregistrés", value: total_albums.to_s, inline: true },
          { name: "Titres au total", value: total_tracks.to_s, inline: true },
          { name: "Artiste le plus prolifique", value: "**#{artist_most_albums}** avec #{max_albums} albums.", inline: false },
          { name: "Album le plus populaire", value: "**#{best_album_name}** par #{best_album_artist}\n(#{best_album_fans} fans)", inline: false }
        ],
        footer: { text: "Données extraites de stats.json" }
      }

      event.edit_response(embeds: [embed_hash])
    end
  end
end