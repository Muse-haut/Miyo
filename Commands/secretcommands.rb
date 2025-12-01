class SecretCommands < BaseCommand
  def self.register(bot)
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
    end
end