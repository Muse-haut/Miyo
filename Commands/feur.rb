FEUR_FILE = "Data/feur.json"

def self.user_wants_data_collection?(user_id)
    non_data_users_file = File.join(__dir__, '../User data/nondatausers.json')
    return false unless File.exist?(non_data_users_file)
    
    non_data_users = JSON.parse(File.read(non_data_users_file)) rescue []
    non_data_users.include?(user_id.to_s)
end

def load_feur
  if File.exist?(FEUR_FILE)
    file = File.read(FEUR_FILE)
    begin
      data = JSON.parse(file)
      return data.transform_keys(&:to_s) if data.is_a?(Hash)
    rescue JSON::ParserError
      puts "Error loading #{FEUR_FILE}, resetting feur(cheh)."
      return {}
    end
  else
    return {}
  end
end
load_feur
$global_user_feur = load_feur
def save_feur_to_file
  return if $global_user_feur.nil? || $global_user_feur.empty?
  File.open(FEUR_FILE, 'w') do |file|
    file.write(JSON.pretty_generate($global_user_feur))
  end
end

class FeurCommand < BaseCommand
    def self.register(bot)
        bot.message do |event|
            if event.message.content.end_with?('quoi', 'quoi ?', 'quoi?', 'Quoi', 'Quoi?', 'Quoi ?', 'Kwa', 'Kwa ?', 'kwa ?', 'kwa', 'QUOI ?', 'QUOI')
                user_id = event.user.id.to_s
                if AlbumSearchCommand.user_wants_data_collection?(user_id) == true
                    next
                else
                    $global_user_feur[user_id] ||= 0
                    $global_user_feur[user_id] += 1
                    event.respond "feur ! ||J'tai dis feur #{$global_user_feur[user_id]} fois, terrible hein ?||"
                    save_feur_to_file
                end
            end
        end
        bot.message(start_with: '!top') do |event|
            $global_user_feur = load_feur
            if $global_user_feur.empty?
                event.respond("No users with a balance available.")
            else
                sorted_users = $global_user_feur.sort_by { |_, feur| -feur }
                top_10_users = sorted_users.first(10)
                leaderboard_message = "Top 10 Users by feur (all server):"
                top_10_users.each_with_index do |(user_id, balance), index|
                user = event.bot.user(user_id.to_i)
                username = user ? user.username : user_id
                leaderboard_message += "\n> #{index + 1}. #{username}: #{balance} feur"
                end
                
                event.respond(leaderboard_message)
            end
        end
    end
end


