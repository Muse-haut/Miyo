class SecretCommands < CommandLoader
    self.passive = true

    def self.register(bot)
        bot.command(:chene) do |event|
            event.message.delete

            images = [
                "https://media.discordapp.net/attachments/1325252358405623808/1548026534768545883/Design_sans_titre.png?ex=6aa58f8e&is=6aa43e0e&hm=c216e48fed561db41feb3e19cc8ab0372d3716917360c05e1bbd4bd6806513ef&=&format=webp&quality=lossless",
                "https://media.discordapp.net/attachments/1322197461745406106/1343345093075009566/Design_sans_titre_14.png?ex=6aa525dc&is=6aa3d45c&hm=50d79bffeea902d3f2c0705f5d7fde090352602f0b9f45cb5acd8149171b6f2d&=&format=webp&quality=lossless"
            ]
            random_image = images.sample
            embed_hash = {
                title: "Une commande secrète a été découverte !",
                description: "Je ne devrais pas partager cette information... Toutefois, il est bon de rire quelques fois. Voici une image des plus embarrassantes qu'a prise Chene.",
                image: { url: random_image },
                timestamp: Time.now.iso8601,
                color: 0x0d5159,
                author: {
                    name: "Miyo",
                    url: "https://museau.neocities.org/",
                    icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/a36b1d2cafe6ff934a4a2a5c3bf8fbf4.png?size=2048"
                },
                footer: { text: "Signé,\nMiyo." },
                fields: [
                    {
                        name: "Linktree :",
                        value: "[Tous les liens sont ici !🌳](https://linktr.ee/DiscordbotMiyo)",
                        inline: true
                    }
                ]
            }

            event.channel.send_embed(nil, embed_hash)
        end
    end
end