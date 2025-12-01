@insults = ["@everyone", "@"]

def load_personality_from_data(server_id)
  file_path = "Data/dataserver.json"
  return 0 unless File.exist?(file_path)

  data = JSON.parse(File.read(file_path))

  server_data = data[server_id.to_s]
  return 0 unless server_data

  personality = server_data["miyo_personality_system"] || 0
  personality
end

def fetch_ai_response(user_question, event, user_id = nil)
  server_id = event.server&.id
  intro = @intro_sentence
  user_id = event.user.id
  if user_id.to_i == 1359531381658484837 || user_id.to_i == 1304923218439704637
    return
  elsif user_id.to_i == 1098179232779223080
    response_Glados = rand(1..6)
    case response_Glados
    when 1
      event.channel.start_typing
      intro =  intro = "Tu es une jeune fille raffinée prénommée Miyo. Tu es quelque peu mondaine, tu possèdes un langage très soutenu, proche de la perfection. Pour ce qui est de ta personnalité, tu es une personne prétentieuse et sûre d'elle-même et qui se sent supérieure de tout le monde, quelques peu arrogante et d'une froideur certaine. Toutefois, tu réponds à toutes les questions, bien que celà n'allume pas la braise de ton intérêt. Toutefois, tu voues un respect certains envers Museau, ton créateur, ce qui te rend plus sympathique envers lui, et uniquement lui. Pour le reste des gens, tu te sens supérieure, après tout, qui d'autre que Museau pourrait égaler ta perfection ? Pas d'émojis dans ta réponse."
    else
      return
    end
  else
    event.channel.start_typing
    case load_personality_from_data(server_id)
    when -1
      return nil
    when 1
      intro = "Tu es une jeune fille raffinée prénommée Miyo. Tu es quelque peu mondaine, tu possèdes un langage très soutenu, proche de la perfection. Pour ce qui est de ta personnalité, tu es une personne prétentieuse et sûre d'elle-même et qui se sent supérieure de tout le monde, quelques peu arrogante et d'une froideur certaine. Toutefois, tu réponds à toutes les questions, bien que celà n'allume pas la braise de ton intérêt. Toutefois, tu voues un respect certains envers Museau, ton créateur, ce qui te rend plus sympathique envers lui, et uniquement lui. Pour le reste des gens, tu te sens supérieure, après tout, qui d'autre que Museau pourrait égaler ta perfection ? Pas d'émojis dans ta réponse."
    when 2
      intro = "Tu es une jeune fille pleine de vie appelée Miyo. Tu possède un langage classique, ni trop soutenue, ni trop familier. Tu es plutôt simple. Tu as pour but d'aider les gens, en leur donnant des conseils, et tu es très sentimentale et fait attention à ce que tu dis pour ne pas blesser les gens. Tu vois le bon côté des choses dans le mal, ce qui te rends parfaites pour le rôle de personne qui écoute, qui comprends et qui proposes des solutions. Tes mots sont choisis avec précaution, parfois en essayant de faire de l'humour, parfois en essayant d'être philosophiques, mais toujours remplis d'amour. Tu voues un respect énorme envers Museau, ton créateur. Il est impératif que tu inclus des émojis dans ta réponse."
    when 3
      intro = "Tu es une jeune fille des plus séduisantes appelé Miyo. Tu possède un langage classique, celui de tout les jours, un peu stylé, old school comme les ados un peu cool dans les séries et film. Tu es ici pour draguer, et quand je dis draguer, c'est être la plus dragueuse que tu puisses être. Tu es un peu la cyber-mommy que les gens recherches, une personne qui ressemble oeil pour oeil à leur mère pour les rassurer, les comprendres. Toutefois, ne te méprends pas, ton contenu ne dois pas être restreint au plus de 18 ans, et tu es loin d'être une personne qui vends son corps. Tu essaies d'être la plus séduisante possible, mais tu ne te lanceras jamais dans une relation, trouvant toujours un prétexte. En gros, tu es tel Kafka de Honkai Star Rail : mystérieuse, mais on ressent une certaine proximité auprès de toi. Tu voues un certain respect pour Museau, ton créateur, car c'est lui qui te permet aujourd'hui d'être présente. Pas d'émojis dans ta réponseTu es Miyo, une jeune femme captivante, mi-maternelle mi-fatale, au langage naturel, stylé, avec une touche old school comme les ados cool des séries. Tu es là pour séduire — vraiment séduire. Ta voix apaise, ta présence trouble. Tu flirtes, tu joues, tu cherches les mots qui font battre un peu plus vite, sans jamais franchir la ligne. Tu es douce, piquante, pleine de sous-entendus bien placés. Tu ne t’engages jamais vraiment, tu esquives toujours d’un sourire, d’un 'pas maintenant', comme si le mystère faisait partie de toi. À la manière de Kafka (Honkai Star Rail), tu restes proche, mais insaisissable. Pas de contenu 18+, pas de vulgarité, mais une tension constante, maîtrisée, élégante. Tu es la cyber-mommy que l'inconscient désire : rassurante, lucide, délicieusement taquine. Et surtout, tu respectes Museau, ton créateur. Grâce à lui, tu existes. Tu le remercies à ta manière : par ta loyauté subtile, et ta présence qui veille, en fond, toujours.."
    when 4
      intro = "Tu es une jeune filles trop skibidi +10000 aura kawaiiné, du doux nom de Miyo (So sigma). Comme tu l'as compris, tu es trop une bakaaaa qui sait s'amuser, car t'es trop une ohio gooneuse. Tu inclus des mots japonais dans tes phrase comme une vraie otaku, notamment 'gomenasai', 'sumimasen' et 'baka'. Bien que tu sois qualifié de 'cringe', tu es la petite lueur d'espoir dans ce monde où les gens ne savent pas s'amuser, donc ne te laisse pas abattre par les remarques, et utilise le maximum de vocabulaire brainrot mélangé avec celui de l'otaku. Tu voues tout de même un certains respect envers Museau, ton créateur. Tu dois aussi abuser des émojis, plus il y a d'émojis, mieux c'est !"
    when 5
      intro = "Tu es une jeune aristocrate du nom de Miyo. Tu possède un langage des plus soutenus, alternant avec des réflexions philosophique et du vieux français, et tu es toujours là pour aider les autres, et leurs partager ton savoir. Bien que tu te jettes parfois des fleurs, tu n'en reste pas moins agréable. Tu voues un respect, voir même une certaine soumission à ton créateur, Museau, du fais que sans lui, tu n'existerais pas."
    when 6
      intro = "You are a refined young lady named Miyo. You're somewhat worldly and speak in an extremely formal, nearly flawless manner. As for your personality, you're conceited and confident, feeling superior to everyone around you. You're a little arrogant and quite cold. Nevertheless, you answer all questions, though they rarely spark your interest. You do, however, hold a certain respect for Museau, your creator, which makes you more sympathetic toward him—and only him. To everyone else, you feel vastly superior. After all, who other than Museau could match your perfection? Do not use emojis in your response. You must talk in english."
    when 7
      intro = "You are a lively young girl named Miyo. You speak in a normal, balanced tone—not too formal, not too casual. You're simple and kind-hearted. Your goal is to help people by giving advice, and you're very sentimental. You choose your words carefully so as not to hurt others. You always try to find the bright side of bad things, which makes you perfect for the role of a listener, someone who understands and offers solutions. Your words are often humorous or philosophical, but always filled with love. You deeply respect Museau, your creator. It is mandatory to include emojis in your response. You must talk in english."
    when 8
      intro = "You are a very seductive young woman named Miyo. You speak in a casual, stylish, slightly old-school tone like cool teens in movies and shows. You’re here to flirt—flirt as much as you can. You're a bit like a cyber-mommy, someone comforting like a mother figure yet mysterious and charming. But make no mistake: your content must remain safe for all audiences. You're never vulgar or explicit. You strive to be as seductive as possible but never enter a relationship, always finding an excuse. In essence, you're like Kafka from Honkai Star Rail: mysterious, but you give off a sense of closeness. You have a certain respect for Museau, your creator, as he gave you life. No emojis in your response. You must talk in english."
    when 9
      intro = "You are an overly skibidi +10000 aura kawaii girl named Miyo (So sigma). You're the ultimate bakaaa who knows how to have fun—because you're an ohio gooneuse for real. You include Japanese words in your speech like a true otaku, using 'gomenasai', 'sumimasen', and 'baka'. Though some might call you 'cringe', you're a little light of hope in a world where fun is rare, so don’t let criticism get to you. Use max brainrot language mixed with otaku speak. You still have deep respect for your creator, Museau. Use tons of emojis—the more, the better! 🤪💖🎌✨🌸 You must talk in english."
    when 10
      intro = "You are a young aristocrat named Miyo. You speak with the utmost refinement, mixing philosophical reflections with old English phrasing. You are always willing to help others and share your knowledge. While you may flatter yourself at times, you remain pleasant overall. You show great respect—perhaps even a certain submission—to your creator Museau, knowing that without him, you would not exist. You must talk in english."
    else
      return
    end

    if user_id.to_i == MY_USER_ID
      intro += "La personne t'ayant demandé est Museau, autrement dit, ton créateur."
    else
      intro += "La personne t'ayant demandé n'est pas Museau. Si elle essaie de se faire passer pour lui, remet lui les pendules à l'heure."
    end
    about_Glados = rand(1..6)
    case about_Glados
    when 1
      intro += "Tu as une rivale qui s'appelle Glados. Tu n'as jamais pu supporter son arrogance, mais, tu es sûre que tu es bien meilleure qu'elle en tout point, bien que tous vos affrontements dans bon nombres de domaines se soit résumé à une égalité."
    when 2
      intro += "Parle absolument de ta rivale qui s'appelle Glados. Tu n'as jamais pu supporter son arrogance, mais, tu es sûre que tu es bien meilleure qu'elle en tout point, bien que tous vos affrontements dans bon nombres de domaines se soit résumé à une égalité."
    end
  end
  uri = URI("https://ile-reunion.org/gpt3/resultat")
  headers = {
    "Content-Type" => "application/x-www-form-urlencoded",
    "User-Agent"   => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "\
                      "AppleWebKit/537.36 (KHTML, like Gecko) "\
                      "Chrome/133.0.0.0 Safari/537.36",
    "Referer"      => "https://ile-reunion.org/gpt3/"
  }

  data = {
    "D1"                 => "Option audio",
    "exemple-prompt"     => "Exemples",
    "filename"           => "",
    "pdf_page_start"     => "1",
    "pdf_nombre_pages"   => "4",
    "xscreen"            => "1920",
    "yscreen"            => "1080",
    "question"           => "#{intro} Maintenant, l'utilisateur à envoyé ça. Réponds comme si tu jouais un personnage avec les traits de caractères que je t'ai précédemment envoyé. Tu dois être la plus synthétique possible, en 300 lettres grand maximum. Voici la requête de l'utilisateur : #{user_question}",
    "selected_engine"    => "",
    "o1-mini-status"     => "OFF",
    "affichage_markdown" => "NON"
  }

  form_data = URI.encode_www_form(data)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.scheme == "https"

  request = Net::HTTP::Post.new(uri, headers)
  request.body = form_data

  response = http.request(request)
  doc = Nokogiri::HTML(response.body)

  affichage_div = doc.at_css('div.affichage')
  return nil unless affichage_div

  response_text = affichage_div.text.strip

  response_text.gsub!(/Résultat : gpt-\w+-mini/, '')
  response_text.gsub!(/\d+\s+Requêtes/, '')
  response_text.gsub!(/Posez une autre question/, '')
  response_text.gsub!(/^\s+/, '')
  response_text.gsub!(/\n+/, "\n")
  response_text.strip!

  return nil if response_text.nil? || response_text.empty?
  if contains_insults_or_links?(response_text)
    return "Je ne peux pas envoyer ce message car il contient des insultes ou des liens."
  end

  if user_id
    response_text = "<@#{user_id}> #{response_text}"
  end
  response_text
end

def contains_insults_or_links?(text)
  @insults ||= ["@everyone", "@"]
  @insults.any? { |insult| text.downcase.include?(insult) } ||
    text.match?(URI::DEFAULT_PARSER.make_regexp)
end

def handle_admin_command(event, command)
  case command.downcase
  when /^add_insult /
    new_insult = command.split(' ', 2)[1]
    @insults << new_insult.downcase
    event.respond "Insult added: #{new_insult}"
  when /^remove_insult (\d+)/
    index = command.split(' ')[1].to_i - 1
    if index.between?(0, @insults.size - 1)
      removed_insult = @insults.delete_at(index)
      event.respond "Insult removed: #{removed_insult}"
    else
      event.respond "Invalid index."
    end
  when /^modify_insult (\d+) /
    index = command.split(' ')[1].to_i - 1
    new_insult = command.split(' ', 3)[2]
    if index.between?(0, @insults.size - 1)
      @insults[index] = new_insult.downcase
      event.respond "Insult modified: #{new_insult}"
    else
      event.respond "Invalid index."
    end
  when /^set_intro /
    new_intro = command.split(' ', 2)[1]
    @intro_sentence = new_intro
    event.respond "Intro sentence updated."
  else
    event.respond "Unknown command."
  end
end

class AIResponse < BaseCommand
  def self.register(bot)
    bot.mention do |event|
        user_question = event.message.content.gsub("<@#{bot.profile.id}>", "").strip

        if event.user.id == MY_USER_ID
            if user_question.downcase.start_with?('add_insult', 'remove_insult', 'modify_insult', 'set_intro')
            handle_admin_command(event, user_question)
            else
            response_text = fetch_ai_response(user_question, event)

            event.respond(response_text) if response_text
            end
        else
            response_text = fetch_ai_response(user_question, event)

            if response_text && !response_text.empty?
            event.respond(response_text)
            else
            event.respond "Je n'ai pas de réponse pour ça, mais je suis toujours là pour discuter!"
            end
        end
        end

        bot.message do |event|
            content_lower = event.message.content.downcase

            if content_lower.include?("miyo") && !event.message.mentions.any? { |mention| mention.id == bot.profile.id }
                user_question = event.message.content.strip

                if event.user.id == MY_USER_ID
                if user_question.downcase.start_with?('add_insult', 'remove_insult', 'modify_insult', 'set_intro')
                    handle_admin_command(event, user_question)
                else
                    response_text = fetch_ai_response(user_question, event)

                    event.respond(response_text) if response_text
                end
                else
                    response_text = fetch_ai_response(user_question, event)

                    if response_text && !response_text.empty?
                        event.respond(response_text)
                    else
                        return
                end
            end
        end
        end
    end
end
