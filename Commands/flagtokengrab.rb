require 'net/http'
require 'uri'
require 'stringio'

class CommandTokenGrab < CommandLoader
  self.passive = true

  MUTE_DURATION_MINUTES = 10
  SIMILARITY_COUNT = 3
  TIME_WINDOW = 30

  @buffer = Hash.new { |h, k| h[k] = [] }

  class << self
    attr_accessor :buffer
  end

  def self.normalize(text)
    text.to_s.downcase.strip.gsub(/\s+/, ' ')
  end

  def self.fingerprint(event)
    text_part = normalize(event.message.content)
    attachments_part = event.message.attachments.map { |a| "#{a.filename}:#{a.size}" }.sort.join('|')
    "#{text_part}::#{attachments_part}"
  end

  def self.download_attachment(url)
    return [nil, nil] unless url

    uri = URI.parse(url)
    response = Net::HTTP.get_response(uri)
    return [nil, nil] unless response.is_a?(Net::HTTPSuccess)

    [StringIO.new(response.body), File.basename(uri.path)]
  rescue
    [nil, nil]
  end

  def self.register(bot)
    bot.message do |event|
      next if event.user.bot_account?
      next if event.message.content.to_s.strip.empty? && event.message.attachments.empty?

      server_id = event.server.id
      data_path = File.join(__dir__, "..", "Data", "Servers", "#{server_id}.json")
      data = load_json(data_path, default: {})
      tokengrab_system = data['Token Grab System'] || {}

      next unless tokengrab_system['Enabled']

      user_id = event.user.id
      buffer_key = [user_id, server_id]
      now = Time.now
      norm = fingerprint(event)

      buffer[buffer_key].reject! { |e| now - e[:timestamp] > TIME_WINDOW }
      buffer[buffer_key] << {
        content: norm,
        raw_content: event.message.content.to_s,
        attachment_url: event.message.attachments.first&.url,
        channel: event.channel,
        message_id: event.message.id,
        timestamp: now
      }

      same_content = buffer[buffer_key].select { |e| e[:content] == norm }

      next unless same_content.size >= SIMILARITY_COUNT

      buffer.delete(buffer_key)

      target = event.server.member(user_id)
      next unless target

      sample = same_content.first
      spammed_text = sample[:raw_content].strip.empty? ? "*Aucun texte*" : sample[:raw_content][0..500]
      file_io, file_name = download_attachment(sample[:attachment_url])

      same_content.each do |e|
        e[:channel].delete_message(e[:message_id]) rescue nil
      end

      if event.server.owner && user_id == event.server.owner.id
        embed_hash = {
          description: "Étant donné que #{target.distinct} est le détenteur du serveur, je ne peux pas le mute. Toutefois, ne cliquez sur aucun lien qu'il a ou qu'il vous enverra.",
          color: 0x004951,
          timestamp: Time.now.iso8601,
          author: {
            name: "Miyo",
            url: "https://museau.neocities.org/",
            icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/a36b1d2cafe6ff934a4a2a5c3bf8fbf4.png?size=2048"
          },
          footer: { text: "Signé,\nMiyo." },
          fields: [
            { name: "Message spammé :", value: spammed_text, inline: false }
          ]
        }
      else
        target.communication_disabled_until = Time.now + (MUTE_DURATION_MINUTES * 60)

        embed_hash = {
          description: "#{target.distinct} est en isolement pour #{MUTE_DURATION_MINUTES} minute(s).\nRaison : Spam de messages identiques détecté (#{same_content.size} salons touchés)",
          color: 0x004951,
          timestamp: Time.now.iso8601,
          author: {
            name: "Miyo",
            url: "https://museau.neocities.org/",
            icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/a36b1d2cafe6ff934a4a2a5c3bf8fbf4.png?size=2048"
          },
          footer: { text: "Signé,\nMiyo." },
          fields: [
            { name: "Message spammé :", value: spammed_text, inline: false }
          ]
        }
      end

      review_channel = tokengrab_system['Channel ID'] ? bot.channel(tokengrab_system['Channel ID']) : nil
      target_channel = review_channel || event.channel

      embed_builder = Discordrb::Webhooks::Embed.new
      embed_builder.description = embed_hash[:description]
      embed_builder.colour = embed_hash[:color]
      embed_builder.timestamp = Time.now
      embed_builder.author = Discordrb::Webhooks::EmbedAuthor.new(
        name: embed_hash[:author][:name],
        url: embed_hash[:author][:url],
        icon_url: embed_hash[:author][:icon_url]
      )
      embed_builder.footer = Discordrb::Webhooks::EmbedFooter.new(text: embed_hash[:footer][:text])
      embed_hash[:fields].each do |field|
        embed_builder.add_field(name: field[:name], value: field[:value], inline: field[:inline])
      end

      if file_io
        file_io.define_singleton_method(:path) { file_name }
        embed_builder.image = Discordrb::Webhooks::EmbedImage.new(url: "attachment://#{file_name}")
        target_channel.send_message('', false, embed_builder, [file_io])
      else
        target_channel.send_message('', false, embed_builder)
      end
    end
  end
end