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

class FeurMessage < CommandLoader
  self.passive = true

  def self.register(bot)
    bot.message do |event|
      user_id = event.user.id.to_s

      data_path = File.join(__dir__, "..", "Data", "Users", "NonDataUsers.json")
      data = load_json(data_path, default: {})

      if data.key?(user_id)
        next
      else
        if event.message.content.downcase.end_with?("quoi","quoi ?","quoi?","kwa","kwa ?","kwa?")
          event.message.reply!("Feur !", mention_user: false)

          data_path = File.join(__dir__, "..", "Data", "Users", "Feur.json")
          data = load_json(data_path, default: {})

          if data.key?(user_id)
            data[user_id] += 1
            save_json(data_path, data)
          else
            data[user_id] = 1
            save_json(data_path, data)
          end
        end
      end
    end
  end
end