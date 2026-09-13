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

      no_data_path = File.join(__dir__, "..", "Data", "Users", "NonDataUsers.json")
      no_data = load_json(no_data_path, default: {})

      next if no_data.key?(user_id)

      content = event.message.content.downcase
      if content.end_with?("quoi", "quoi ?", "quoi?", "kwa", "kwa ?", "kwa?")
        data_path = File.join(__dir__, "..", "Data", "Users", "Feur.json")
        data = load_json(data_path, default: {})
        if data.key?(user_id)
          data[user_id] += 1
        else
          data[user_id] = 1
        end
        save_json(data_path, data)
        phrase = case rand(1000)
                when 1
                  "Quoicoubeh !"
                else
                  "Feur !"
                end

        event.message.reply!("#{phrase}\n-# Ça fait #{data[user_id]} fois que je te le dit btw...", mention_user: false)
      end
    end
  end
end