require 'rufus-scheduler'
require 'open3'
require 'set'
require 'json'

class AutomaticScan < CommandLoader
    self.passive = true
    def self.scan_and_add_spotify_artists(bot)
        artists = spotify_artists_from_bot(bot)
        return if artists.empty?

        artists.each do |artist|
            next if artist.strip.empty?
            next if artist_in_albums?(artist)

            added = add_artist_to_albums(artist)
        end
        rescue StandardError => e
        puts "[SPOTIFY SCAN] Erreur : #{e.class} #{e.message}"
    end
      def self.artist_in_albums?(artist_name)
    return false if artist_name.nil? || artist_name.strip.empty?

    File.join(__dir__, "..", "Data", "albums.json")
    return false unless File.exist?(albums_file)

    albums_data = JSON.parse(File.read(albums_file))
    albums_data.key?(artist_name)
  rescue StandardError
    false
  end

    def self.extract_artists_from_state(state)
        return [] if state.nil? || state.strip.empty?

        state.to_s.split(/\s*;\s*/).map(&:strip).reject(&:empty?)
    end

    def self.spotify_artists_from_bot(bot)
        artists = Set.new

        bot.servers.each_value do |server|
        server.members.each do |member|
            activities = member.activities.to_a rescue []
            activities.each do |act|
            next unless act.type == Discordrb::Activity::LISTENING && act.sync?

            spotify_name = act.name.to_s.downcase == 'spotify'
            spotify_app = act.application_id.to_s == '1'
            spotify_url = act.url.to_s.include?('spotify.com')
            next unless spotify_name || spotify_app || spotify_url

            extracted_artists = extract_artists_from_state(act.state)
            extracted_artists.each do |artist|
                puts "[SPOTIFY SCAN] state=#{act.state.inspect} artist=#{artist.inspect}"
                artists.add(artist)
            end
            end
        rescue StandardError => e
            puts "[SPOTIFY SCAN] erreur membre=#{member.id} : #{e.class} #{e.message}"
            next
        end
        end

        artists
    end

    def self.add_artist_to_albums(artist_name)
        return false if artist_name.nil? || artist_name.strip.empty?

        script_path = File.expand_path('../info album.py', __dir__)
        python_executables = %w[py python python3]
        python_cmd = python_executables.find do |cmd|
        system(cmd, '--version', out: File::NULL, err: File::NULL)
        rescue Errno::ENOENT
            false
        end
        unless python_cmd
            puts "[SPOTIFY SCAN] Impossible de trouver Python pour ajouter #{artist_name.inspect}"
            return false
        end

        stdout, stderr, status = Open3.capture3(python_cmd, script_path, artist_name)
        if status.success?
            puts "[SPOTIFY SCAN]✅ #{artist_name.inspect} ajouté"
            puts stdout unless stdout.strip.empty?
            true
        else
            puts "[SPOTIFY SCAN] Échec Python pour #{artist_name.inspect}: #{stderr.strip}"
            false
        end
    end
        def self.register(bot)
            scheduler = Rufus::Scheduler.new

            scheduler.every '5m' do
                begin
                    puts "[SPOTIFY SCAN] Check des musiques en cours"
                    scan_and_add_spotify_artists(bot)
                rescue => e
                    puts "[SPOTIFY SCAN] Erreur : #{e.class} #{e.message}"
                end
            end
        end
    
end