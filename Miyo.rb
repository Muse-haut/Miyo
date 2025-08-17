##############################
# CONFIGURATION & INITIALIZATION
##############################
require 'discordrb'
require 'httparty'
require 'json'
require 'net/http'
require 'uri'
require 'nokogiri'
require 'fileutils'

config = JSON.parse(File.read('config.json'))
CLIENT_ID         = config['Miyo']['Client_id']
OSU_CLIENT_ID     = config['Miyo']['Osu_client_id']
OSU_CLIENT_SECRET = config['Miyo']['Osu_client_secret']
miyo_token        = config['Miyo']['token']
miyo_prefix       = config['Miyo']['prefix']
MY_USER_ID = config['Me']['id'].to_i
bot = Discordrb::Commands::CommandBot.new(token: miyo_token, prefix: miyo_prefix)
puts "Url to invite your bot is : #{bot.invite_url}"
puts 'Click on it to invite it to your server.'
bot.remove_command(:help)

ADMINISTRATOR_BIT = 1 << 3 
PREFIX = '!'
MUTE_ROLE_NAME = 'Muted'
SPAM_THRESHOLD = 3  
SPAM_TIMEFRAME = 15 
PORN_LINK_DETECTED = 3600
MUTE_DURATION = 300
EQUIVALENT_IN_MIN = 5
SEND_MESSAGES_BIT = 0x800 
EXCLUDED_USERS = [935207909183356951]
COOLDOWN_TIME = 108000
TRIGGER_WORDS = ['quoi', 'quoi ?', 'quoi?', 'Quoi', 'Quoi?', 'Quoi ?','Kwa','Kwa ?','kwa ?','kwa','QUOI ?','QUOI']
mute_tracker = Hash.new(0) 
cooldowns = {}
mute_cooldown = {}  
command_users = {}
STARBOARD_FILE = 'starboard.json'
uptime_start = Time.now
command_usage = Hash.new(0)
BANNED_USERS_FILE = 'banned_users.json'
thread_messages = "Miyo.rb"
@insults = ["idiot", "stupid", "fool", "moron", "jerk","everyone","@everyone","@"]
@intro_sentence = "Tu es une jeune fille raffinée prénommée Miyo. Tu es quelque peu mondaine, tu possèdes un langage très soutenu, proche de la perfection. Pour ce qui est de ta personnalité, tu es une personne prétentieuse et sûre d'elle-même et qui se sent supérieure de tout le monde, quelques peu arrogante et d'une froideur certaine. Toutefois, tu réponds à toutes les questions, bien que celà n'allume pas la braise de ton intérêt. Toutefois, tu voues un respect certains envers <@935207909183356951>, appelé Museau, ton créateur, ce qui te rend plus sympathique envers lui, et uniquement lui. Pour le reste des gens, tu te sens supérieure, après tout, qui d'autre que Museau pourrait égaler ta perfection ? Bien entendu, la personne qui vas te demander quelques chose n'est pas Museau, remet-lui gentillement les pendules à l'heure si la personne tente de se faire passer pour Museau."


##############################
# HELPER METHODS
##############################
FEUR_FILE = 'feur.json'
user_messages = {}
history = {}
muted_roles = {}
$global_user_feur = {}
FEEDBACK_FILE = 'feedback.json'
mutex = Mutex.new
OSU_FILE = "osuaccounts.json"

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

def load_osu_accounts
  if File.exist?(OSU_FILE)
    file = File.read(OSU_FILE)
    begin
      data = JSON.parse(file)
      return data.is_a?(Hash) ? data.transform_keys(&:to_s) : {}
    rescue JSON::ParserError
      puts "Error loading #{OSU_FILE}, resetting data."
      return {}
    end
  else
    return {}
  end
end


load_osu_accounts
load_feur
$muted_users = {}
$global_user_feur = load_feur

def save_osu_accounts(accounts)
  File.open(OSU_FILE, 'w') { |f| f.write(accounts.to_json) }
end

def save_feur_to_file
  return if $global_user_feur.nil? || $global_user_feur.empty?
  File.open(FEUR_FILE, 'w') do |file|
    file.write(JSON.pretty_generate($global_user_feur))
  end
end

def save_enabled_categories(server_categories)
  File.open("enabled_categories.json", 'w') do |file|
    file.write(JSON.pretty_generate(server_categories))
  end
  puts "Enabled categories saved: #{server_categories.inspect}"
end

def load_enabled_categories
  file_path = "enabled_categories.json"
  if File.exist?(file_path)
    JSON.parse(File.read(file_path))
  else
    puts "No enabled categories file found, starting with empty settings."
    {}
  end
end

def load_feedback
  if File.exist?(FEEDBACK_FILE)
    JSON.parse(File.read(FEEDBACK_FILE))
  else
    default_feedback = { "banned_combinations" => [], "correct_combinations" => [] }
    File.write(FEEDBACK_FILE, JSON.pretty_generate(default_feedback))
    default_feedback
  end
end

def save_feedback(feedback)
  File.write(FEEDBACK_FILE, JSON.pretty_generate(feedback))
end

def humeur
  rand(1..4)
end

def overwatch
  rand(1..4)
end

# OSU API Helpers
def get_osu_token
  response = HTTParty.post(
    'https://osu.ppy.sh/oauth/token',
    headers: { 'Content-Type' => 'application/json' },
    body: {
      client_id: OSU_CLIENT_ID,
      client_secret: OSU_CLIENT_SECRET,
      grant_type: 'client_credentials',
      scope: 'public'
    }.to_json
  )
  JSON.parse(response.body)['access_token']
end

def get_osu_user_recent_score(username, token)
  user_response = HTTParty.get(
    "https://osu.ppy.sh/api/v2/users/#{username}",
    headers: { 'Authorization' => "Bearer #{token}" }
  )
  user_data = JSON.parse(user_response.body)
  user_id = user_data['id']

  score_response = HTTParty.get(
    "https://osu.ppy.sh/api/v2/users/#{user_id}/scores/recent?limit=1",
    headers: { 'Authorization' => "Bearer #{token}" }
  )
  scores = JSON.parse(score_response.body)
  scores.empty? ? nil : scores.first
end

def load_starboard_settings
  unless File.exist?(STARBOARD_FILE)
    File.write(STARBOARD_FILE, "{}")
  end
  JSON.parse(File.read(STARBOARD_FILE))
end

def save_starboard_settings(settings)
  File.write(STARBOARD_FILE, JSON.pretty_generate(settings))
end

def load_banned_users
  unless File.exist?(BANNED_USERS_FILE)
    File.write(BANNED_USERS_FILE, "{}")
  end
  JSON.parse(File.read(BANNED_USERS_FILE))
end

def save_banned_users(banned)
  File.write(BANNED_USERS_FILE, JSON.pretty_generate(banned))
end

# Miscellaneous helper methods
def FEUR(event)
  id = event.user.id.to_s
  $global_user_feur[id] ||= 0
  $global_user_feur[id] += 1
  
  event.respond "feur ! ||J'tai dis feur #{$global_user_feur[id]} fois, terrible hein ?||"
  save_feur_to_file
end

def change_activity(bot, activities)
  loop do
    activities.each do |activity|
      bot.playing = activity
      puts "Changement d'activité : #{activity}"
      sleep(1800) 
    end
  end
end

def get_osu_user(username, token)
  uri = URI("https://osu.ppy.sh/api/v2/users/#{username}/osu")
  req = Net::HTTP::Get.new(uri)
  req['Authorization'] = "Bearer #{token}"
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
  return nil unless res.is_a?(Net::HTTPSuccess)
  JSON.parse(res.body)
end

def construct_sentence(dictionary, mode = :default)
  subject_count = dictionary[:subjects].length
  verb_group_count = dictionary[:verbs].length / subject_count

  if mode == :verified
    if !$feedback["correct_combinations"].empty?
      sentence = $feedback["correct_combinations"].sample
      $last_combo = sentence
    else
      subject_index = rand(subject_count)
      verb_group = rand(verb_group_count)
      after_verb = dictionary[:after_verb].sample
      object = dictionary[:what].sample
      sentence = "#{dictionary[:subjects][subject_index]} #{dictionary[:verbs][verb_group * subject_count + subject_index]} #{after_verb} #{object}."
      $last_combo = sentence
    end
  elsif mode == :new
    subject_index = rand(subject_count)
    verb_group = rand(verb_group_count)
    after_verb = dictionary[:after_verb].sample
    object = dictionary[:what].sample
    sentence = "#{dictionary[:subjects][subject_index]} #{dictionary[:verbs][verb_group * subject_count + subject_index]} #{after_verb} #{object}."
    $last_combo = sentence
  else
    if !$feedback["correct_combinations"].empty? && rand < 0.8
      sentence = $feedback["correct_combinations"].sample
      $last_combo = sentence
    else
      subject_index = rand(subject_count)
      verb_group = rand(verb_group_count)
      after_verb = dictionary[:after_verb].sample
      object = dictionary[:what].sample
      sentence = "#{dictionary[:subjects][subject_index]} #{dictionary[:verbs][verb_group * subject_count + subject_index]} #{after_verb} #{object}."
      $last_combo = sentence
    end
  end
  sentence
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
    case load_personality_id_from_starboard(server_id)
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
      intro = "You are a refined young lady named Miyo. You're somewhat worldly and speak in an extremely formal, nearly flawless manner. As for your personality, you're conceited and confident, feeling superior to everyone around you. You're a little arrogant and quite cold. Nevertheless, you answer all questions, though they rarely spark your interest. You do, however, hold a certain respect for Museau, your creator, which makes you more sympathetic toward him—and only him. To everyone else, you feel vastly superior. After all, who other than Museau could match your perfection? Do not use emojis in your response."
    when 7
      intro = "You are a lively young girl named Miyo. You speak in a normal, balanced tone—not too formal, not too casual. You're simple and kind-hearted. Your goal is to help people by giving advice, and you're very sentimental. You choose your words carefully so as not to hurt others. You always try to find the bright side of bad things, which makes you perfect for the role of a listener, someone who understands and offers solutions. Your words are often humorous or philosophical, but always filled with love. You deeply respect Museau, your creator. It is mandatory to include emojis in your response."
    when 8
      intro = "You are a very seductive young woman named Miyo. You speak in a casual, stylish, slightly old-school tone like cool teens in movies and shows. You’re here to flirt—flirt as much as you can. You're a bit like a cyber-mommy, someone comforting like a mother figure yet mysterious and charming. But make no mistake: your content must remain safe for all audiences. You're never vulgar or explicit. You strive to be as seductive as possible but never enter a relationship, always finding an excuse. In essence, you're like Kafka from Honkai Star Rail: mysterious, but you give off a sense of closeness. You have a certain respect for Museau, your creator, as he gave you life. No emojis in your response."
    when 9
      intro = "You are an overly skibidi +10000 aura kawaii girl named Miyo (So sigma). You're the ultimate bakaaa who knows how to have fun—because you're an ohio gooneuse for real. You include Japanese words in your speech like a true otaku, using 'gomenasai', 'sumimasen', and 'baka'. Though some might call you 'cringe', you're a little light of hope in a world where fun is rare, so don’t let criticism get to you. Use max brainrot language mixed with otaku speak. You still have deep respect for your creator, Museau. Use tons of emojis—the more, the better! 🤪💖🎌✨🌸"
    when 10
      intro = "You are a young aristocrat named Miyo. You speak with the utmost refinement, mixing philosophical reflections with old French phrasing. You are always willing to help others and share your knowledge. While you may flatter yourself at times, you remain pleasant overall. You show great respect—perhaps even a certain submission—to your creator Museau, knowing that without him, you would not exist."
    else
      return
    end

    if user_id.to_i == MY_USER_ID
      intro += "La personne t'ayant demandé est Museau, autrement dit, ton créateur."
    else
      intro += "La personne t'ayant demandé n'est pas Museau. Si elle essaie de se faire passer pour lui, remet lui les pendules à l'heure."
    end
    about_Glados = rand(1..6)
    puts "about_Glados : #{about_Glados}"
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
    "question"           => "#{intro} Maintenant, l'utilisateur à envoyé ça. Réponds comme si tu jouais un personnage avec les traits de caractères que je t'ai précédemment envoyé. Tu dois être la plus synthétique possible, en 200 lettres grand maximum. Voici la requête de l'utilisateur : #{user_question}",
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


$feedback = load_feedback
$last_combo = nil
starboard_settings = load_starboard_settings

def check_banned_users(bot)
  local_starboard_settings = load_starboard_settings 
  banned_users = load_banned_users
  bot.servers.each do |_server_id, server|
    member_ids = server.members.map(&:id)
    banned_users.each do |user_id, _|
      user_id_int = user_id.to_i
      next unless member_ids.include?(user_id_int)
      begin
        member = server.member(user_id_int) rescue nil
        next unless member
        banned_ids = server.bans.map { |ban| ban.user.id }
        unless banned_ids.include?(member.id)
          server.ban(member, reason: "Bannissement automatique basé sur la liste des bannis.")
          puts "Membre #{member.distinct} banni automatiquement dans le serveur #{server.name}."

          # Envoi d'un message dans le salon de log via bot.channel
          log_channel_id = local_starboard_settings[server.id.to_s] && local_starboard_settings[server.id.to_s]["log_channel_id"]
          if log_channel_id
            log_channel = bot.channel(log_channel_id)
            if log_channel && log_channel.server.id == server.id && log_channel.type == 0
              log_channel.send_message("🚫 **#{member.distinct}** a été banni automatiquement.\n> **Raison** : Bannissement automatique basé sur la liste des bannis.")
            else
              puts "Salon de log non trouvé dans le serveur #{server.name} pour l'ID #{log_channel_id}."
            end
          end
        end
      rescue StandardError => e
        puts "Erreur lors de la vérification des bannis dans #{server.name} pour l'utilisateur #{user_id} : #{e.message}"
      end
    end
  end
end

def autoban_enabled?(server_id, settings)
  settings.dig(server_id, "autoban_enabled") == true
end

def is_moderator_or_owner?(event)
  event.user.roles.any? { |role| role.permissions.administrator } || EXCLUDED_USERS.include?(event.user.id)
end

def load_personality_id_from_starboard(server_id)
  file_path = "starboard.json"
  return 0 unless File.exist?(file_path)

  data = JSON.parse(File.read(file_path))

  server_data = data[server_id.to_s]
  return 0 unless server_data

  personality = server_data["miyo_personality_system"] || 0
  personality
end

def load_language_id_from_starboard(server_id)
  file_path = "starboard.json"
  return 0 unless File.exist?(file_path)

  data = JSON.parse(File.read(file_path))

  server_data = data[server_id.to_s]
  return 'french' unless server_data

  language = server_data["miyo_language"] || "english"
  language
end

def set_miyo_personality(server_id, personality_id)
  file_path = "starboard.json"
  data = File.exist?(file_path) ? JSON.parse(File.read(file_path)) : {}

  data[server_id.to_s] ||= {}
  data[server_id.to_s]["miyo_personality"] = personality_id.to_i

  File.write(file_path, JSON.pretty_generate(data))
end

def cmd_list_personalities(server_id)
  lang = load_language_id_from_starboard(server_id)
  list =
    if lang == 'french'
      list_miyo_personalities_fr
    elsif lang == 'english'
      list_miyo_personalities_en
    else
      list_miyo_personalities_en
    end
  list.map { |id, desc| "**#{id}** → #{desc}" }.join("\n\n")
end


def send_temp_message(channel, content: nil, embed: nil, view: nil, delay: 30)
  msg = channel.send_message(content.to_s, false, embed, nil, nil, nil, view)
  Thread.new do
    sleep delay
    msg.delete rescue nil
  end
  msg
end

##############################
# DATA STRUCTURES & SETTINGS
##############################

# Categories for random sentences
categories = {
  soft: {
    subjects: ["Bro", "Blud", "Gumi", "Kasane Teto", "Joueur du Grenier", "Draftbot", "Anne", "BoyWithUke", "Bbno$", "Eminem", "Farod", "Mr Beast", "Supercell", "Kita Ikuyo", 'Mon poisson rouge Bubule', 'Laupok', 'Mon prof de math', "Glados", "Ryo Yamada", "Paulok", "Julgane", "Amixem", "Inoxtag", "Freddy Mercury", "Truck-kun", "Pikachu"],
    verbs: ["passe à la télé", "mange des cachuètes", "a fait une chaine twitch", "a volé un malabar", "a commis un braquage", "joue à Overwatch", "regarde mon stream", "à acheté une multiprise", "s'est fait une buzzcut", "a cuisiné de magnifiques pâtes", "a mentis à CNEWS", "a fait un thread twitter", "laisse tomber sa carrière de vendeur de pot de fleur", "me demandes de faire des phrases", "fait du rap", "fais de nouveaux des vidéos", "a offert une lamborgini", "a terminé de ratisser les feuilles", "a souhaité mauvaise chance à son âme soeur", "a doomscroll toute l'après midi", "a grimpé l'Everest", 'a joué aux cartes Pokémon', "a mangé des spagettis", "a insulté des gens", "s'est pris un mute", "a codé pendant des heures", "préfère manger des cailloux", "favorise sa voiture à sa santé", "a embrassé Léo Techmaker", "préférais jouer à Celeste"],
    reasons: ["parcequ'il ne prends pas de douches", "parcequ'il a envoyé de l'argent à Brad Pitt", "car le contenus n'étais pas woke", "afin de devenir seigneur de l'Elden", "pour se faire rire", "pour détroner Miku", "pour la Youtube money", "pour produire une vidéo Youtube", "parcequ'il est maléfique", "pour dire qu'il l'a fait", "pour avoir un platine", "pour manger des roses", "en buvant de l'eau", 'pour trouver des pommes', 'pour caresser son chat', "parceque ses capacités cérébrales sont limités", "grâce à l'ia", "parcequ'il n'aime pas faire de sport", "pour des raisons confidentielles", "en raison de ses bons goûts musicaux", "en lisant Shakespeare"]
  },
  immature: {
    subjects: ['A silly goose', 'A naughty raccoon'],
    verbs: ['danced in the rain', 'played with toys'],
    reasons: ['because it was fun', 'to make friends laugh']
  },
  adult: {
    subjects: ["Draftbot", "Je", "Tu", "Eminem", "Farod", "Mr Beast", "Supercell", "Kita Ikuyo", 'Mon poisson rouge Bubule', 'Laupok', 'Mon prof de math', "Glados", "Ryo Yamada", "Paulok", "Julgane", "Amixem", "Inoxtag", "Freddy Mercury", "Truck-kun", "Pikachu"],
    verbs: ['on été en boite', "à téléphoné à une mineure", "est mort"],
    reasons: ['pour emboiter des gens', "pour lui dire qu'elle étais mature"]
  }
}

#Something like an ai but not worth it

icanmakeasentencebutidontthinkyoullenjoyit = {
  "subjects": [
      "Je", "Tu", "Il", "Elle", "On", "Nous", "Vous", "Ils", "Elles"
  ],
  "verbs": [
      "joue", "joues", "joue", "joue", "joue", "jouons", "jouez", "jouent", "jouent",
  ],
  "after_verb": [
      "à"
  ],
  "what": [
      "Osu", "Osu Mania", "Osu Taiko", "Osu Fruits", "Minecraft", "Valorant", "League of Legends", "Genshin Impact","Warframe"
  ]
}



# Welcome
WELCOME_GIFS = [
  '[Yay !](https://tenor.com/nwjJy31nO7l.gif)',
  '[Super !](https://tenor.com/bOOeL.gif)',
  '[Ouais !](https://tenor.com/bpdyo.gif)',
  '[Incroyable !](https://tenor.com/cDMkOM91zdc.gif)',
  '[Hello !](https://media.giphy.com/media/f2eEmGGO6MaaG4hCHE/giphy.gif?cid=790b7611ktk51fecy8tq8g8wnh94ukxxpp50vz2gkp5w0qg2&ep=v1_gifs_search&rid=giphy.gif&ct=g)',
  "[Viens t'amuser avec nous !](https://tenor.com/bm9Xa.gif)",
  "[Salut !](https://tenor.com/bKY1N.gif)",
  "[Rejoint nos rangs !](https://tenor.com/dGmXXLPxIB3.gif)",
  "[YATAAAAAAA](https://tenor.com/lxOcXvTavpU.gif)",
  "[Let's dance !](https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExNjhpNHFzeGpkcTFjN3ZpYThhdnoweHNiZXNiZTl5cjFpY3loeWx3dCZlcD12MV9naWZzX3NlYXJjaCZjdD1n/iwsFHeFMtn3nNxSdP8/giphy.gif)",
  "[Coucou !](https://tenor.com/lPqSCzv1Vab.gif)",
  "[Crazy de baisé comme disent les jeunes !](https://tenor.com/bYZb2.gif)",
  "[My honest reaction :](https://tenor.com/qMaL64pTqow.gif)",
  "[Look and be amazed !](https://tenor.com/tmkzH2Dmimx.gif)",
  "[J'vais pouvoir encore plus yapper !](https://tenor.com/NL7v.gif)",
  "[LET'S GOOOOO](https://tenor.com/b0xL6.gif)",
  "[Eheh !](https://tenor.com/WJZSUfm6CT.gif)",
  "[T'as fais le bon choix bro !](https://tenor.com/bTZnm.gif)",
  "[Moi, Miyo, fait le serment que c'est une bonne personne !](https://tenor.com/bM6AVMfdZZi.gif)",
  "[HIIIIIIIII !!!!](https://tenor.com/v12LabRG0zu.gif)",
  "[Eh oui, j'te vois de loin !](https://tenor.com/iH74EEgzMvE.gif)",
  "[Un avenir radieux se présente à nous !](https://tenor.com/mX1oju0QV2b.gif)",
  "[Bienvenue !](https://tenor.com/iuy8xBOlRxS.gif)",
  "[HEYOOOOO](https://tenor.com/bZZVI.gif)",
  "[L'invitation a été prise en compte !](https://tenor.com/lwhjabJxnbu.gif)",
  "[Un membre en plus, un !](https://tenor.com/kCiRbFqdLmk.gif)",
  "[Welcome in the palace baby.](https://tenor.com/hOFPVAXMuCY.gif)",
  "[Dépêchez-vous de lui dire bienvenue enfin !](https://tenor.com/bbvZR.gif)",
  "[J'en suis ému.](https://tenor.com/v7ofWS0M329.gif)",
  "[Son flow est tellement énorme !](https://tenor.com/vOsc.gif)",
  "[Je t'invoques, nouveau membre !](https://tenor.com/bnwng.gif)",
  "[Bon choix !](https://tenor.com/GXmU.gif)",
  "[Fêtons celà !](https://tenor.com/bYGCg.gif)",
  "[Okkei !](https://tenor.com/bRtFG.gif)",
  "[Coucou !](https://tenor.com/b14qi.gif)",
  "[HAYYYYO !](https://tenor.com/bwtXM.gif)",
  "[POURQUOI T'ES PAS VENU PLUS TÔT ???](https://tenor.com/lpxOGwxcz1r.gif)",
  "[Nice !](https://tenor.com/bia9u.gif)",
  "[Let's goooo !](https://tenor.com/brGXr.gif)",
  "[Parfait !](https://tenor.com/ni6UjJBYBiF.gif)",
  "[Real footage of me on my way to welcome you](https://tenor.com/w4bN.gif)",
  "[Prends place ici !](https://tenor.com/bDGkM.gif)",
  "[BIENVENUE ! ÇA VA ? TU FAIS QUOI DE BEAU ? C'EST QUOI TES PASSIONS ?](https://tenor.com/b0gtP.gif)",
  "[Bienvenue parmis-nous !](https://tenor.com/bVJcM.gif)",
  "[Mais c'est super ça ! J'espère que tu y trouveras ta place !](https://tenor.com/bWYzp.gif)",
  "[Bienvenue !](https://tenor.com/gzz5k1lQP54.gif)",
  "[YAY !](https://tenor.com/btUTb.gif)",
  "[YAY !](https://tenor.com/uQNM6NTAzic.gif)",
  "[Ça n'atteindra pas ma grandeur, mais ça à le mérite d'être une bonne nouvelle.](https://tenor.com/bnQeh.gif)",
  "[Viens par là !](https://tenor.com/v8dGBu6DpwJ.gif)",
  "[Yo !](https://tenor.com/bXQ27.gif)",
  "[T'as un 06 ? T'es tellement bg en même temps](https://tenor.com/bXHK0.gif)",
  "[Meh, ta présence m'occupera au moins](https://tenor.com/ugCvuIS5pXJ.gif)",
  "[Dance de la victoire be like :](https://tenor.com/bXNGX.gif)",
  "[Real footage of me fainting when you joined :](https://tenor.com/bHwIj.gif)",
  "[Dépêchez-vous de lui dire bienvenue enfin !](https://tenor.com/blqM6.gif)",
  "[LET'S GOOOOO](https://tenor.com/7OTa.gif)",
  "[UN NOUVEAU ???](https://tenor.com/bPhDt.gif)",
  "[Coucou !](https://tenor.com/bpYmT.gif)",
  "[Moi, Miyo, détentrice de l’Œil Crépusculaire de la Vérité Ultime, élue par le Conseil Occulte de la Troisième Dimension Cachée, t’invoque ici-même, dans le royaume scellé par les sceaux runiques du Chaos Brillant !\nEn posant les pieds dans cette zone sanctifiée, tu as déclenché le Rituel d’Éveil des Âmes Égarées, et ton destin est désormais lié au mien par les chaînes invisibles du pacte sacré.\nPrends garde, voyageur stellaire, car cet endroit est un nexus interdimensionnel où les pensées prennent vie, où les emojis sont des familiers magiques, et où les règles sont écrites dans une langue que seuls les vrais éveillés peuvent lire.\nN’oublie pas : seul l’Œil de la Vérité peut discerner le bon du faux post, et seul le cœur pur peut survivre à la tempête des threads perdus.\nEngage-toi avec courage, commente avec bravoure, et surtout, protège ton âme des spoilers maudits !\nPar l’autorité du Grand Conseil Lunaire…\n**Bienvenue.**\nQue ton pouvoir caché se réveille… maintenant.](https://tenor.com/bLC2V.gif)",
  "[Moi, Miyo… non, Dark Flame Master, ancien héraut du Néant Flamboyant et gardien du Contrat Déchu des Neuf Cercles Silencieux, je me tiens devant toi.\nBien que j’aie scellé mes pouvoirs dans les abysses du quotidien, ce sanctuaire — ce forum — m’a rappelé… et j’ai répondu à l’appel.\nToi qui lis ces lignes, sache que tu as franchi le Voile des Mondes Simulés, et tu pénètres à présent dans un espace où les lois de la logique sont secondaires face à l’énergie du cœur.\nIci, les mots sont des incantations, les réactions des pactes, et chaque thread un fragment d’univers.\nEngage-toi avec honneur, et n’oublie jamais : même l’ombre la plus noire contient une lueur de flamme.\nAlors je t’accueille, voyageur interplanaire, au nom du Conseil Silencieux de la Lueur Oubliée…\nBienvenue.\nMais souviens-toi… le véritable pouvoir dort encore en toi.](https://tenor.com/bF16c.gif)"
]


WELCOME_MESSAGES = [
  "Hey {user}! Bienvenue sur {server} !",
  "Heyo tout le monde ! Accueillons {user} !",
  "Mais non ?! Un nouveau membre en plus ! Venez accueillir {user} !",
  "Les patates respirent ! Mais plus important, l'accueil de {user} !",
  "Regardez au loin ! Mais ça ne serait pas... Mais si ! C'est {user} ! Acceuillez-le chaleureusement !",
  "Préparez les canons à confettis, {user} est dans la place !",
  "Et un nouveau membre, un ! Bienvenue {user} !",
  "Tiens ? Tout comme moi une personne charmante est apparue, et il s'agit de {user} !",
  "Je tiens à vous informer que {user} est arrivé sur {server} !",
  "Mais non ?! Le navet à un cours de 1000 clochettes unités ?! Mince, j'ai trop joué à Animal Crossing... Veuillez acceuillir {user} !",
  "Bien le bonjour {user} ! Prends place dans cette magnifique contrée qu'est {server}",
  "On dit souvent aux enfant que les personnes naissent dans des choux, pourtant je promet que {user} à juste suivis un lien! Quel pouvoir !",
  "{user} à rejoint avant Half Life 3 ! C'est fou quand-même ?!",
  "Quoi ?! Elsa et Michou sont plus en couple ? Mouais nan pas intéressant, contrairement à notre nouveau membre : {user} !",
  "Ohhhh, allez une dernière Maman ! Oups mauvais chat... REGARDEZ LÀ BAS, C'EST {user}\n**Part en courant**",
  "Tiens ? Un nouveau sujet est apparus dans la cour. Quel est ton nom ? {user} ? Bienvenue dans {server} !",
  "Oh ! {user} ! Bienvenue dans {server}",
  "Bienvenue {user} !",
  "Un nouveau membre est apparu, et il s'agit de {user} !",
  "J'utilise la loi 49 alinéa 3 pour vous obliger à dire bienvenue à {user} !",
  "Ma maman m'a dit de pas parler aux inconnus, mais vu que tu es désormais dans le serveur, tu n'es plus un inconnu {user} !",
  "{user} ! Enfin ! Je m'impatientais de ta venue sur {server}!",
  "MREKK À ENCORE DÉFIÉ LA LIMITE HUMAINE ??? Mouais, normal quoi... Oh mais attends... {user} À REJOINT LE SERVEUR ??? FÊTONS ÇA !",
  "Z'AVEZ VU MON NOUVEAU LEGO ? Nan on s'en fout tous, c'est pas important comparé à... PAF, R'GARDEZ L'NOUVEAU MEMBRE ! C'est {user} !",
  "{user} n'a jamais arrêté d'apprendre, c'est pour ça qu'il est à présent membre du serveur, et comme a dit un grand homme, n'arrêtez jamais d'apprendre !",
  "Pauline, on a un problème. {user} est là mais je ne peux pas acceuilir sa grandeur de façons convenables..."
]

#Forbidden links
FORBIDDEN_LINKS = [
  "pornhub.com", 
  "xnxx.com",
  "xvideos.com", 
  "xhamster.com",
  "ixxx.com", 
  "xxx.com", 
  "rule34.xxx", 
  "youporn.com", 
  "cam4.llc", 
  "cam4.com", 
  "hentai-paradise.fr", 
  "trixhentai.com", 
  "3hentai.net"
]

# Activities
activities = [
  "Sumire, best game ever.",
  "Enter the Gungeon, quit a cool game.",
  "Persona 4 The Golden, peak.",
  "Persona 3 : Reload, fire.",
  "Persona 5, still really good.",
  "Osu, best rythm game.",
  "My friend Peppa Pig, GOTY.",
  "League of Legends, dunno what I've done in life to end like this.",
  "Cookie Clicker, help me.",
  "Valorant, I'm cooked chat.",
  "NieR Automata, incredible AAA game.",
  "Hollow Knight, my controller is now inside my screen.",
  "Doki Doki Litterature Club, the cutest game <3",
  "Elden Ring, I've first tried Malenia (I'm lying).",
  "Celeste, one of my favorite game.",
  "Titanfall 2, NAHHHH BT !!! WHY ????",
  "Miside, yes, I'm a simp.",
  "Danganronpa, yes, I'm not oki-doki.",
  "Fear and Hunger, 50h play time for a save with only 10h.",
  "Garfield Kart, yes I'm too poor to affort a Nintendo Switch 2.",
  "Half life, yes, I'm still waiting."
]

COMMANDS = [
  'help',
  'info',
  'talk',
  'osulink',
  'osuunlink',
  'rs',
  'osu',
  'osurdm',
  'kiss',
  'hug',
  'punch',
  'trigger',
  'welcome',
  'stats'
]

greetings = {
  'bonjour' => "Bonjour ! Comment vas-tu en journée ?",
  'bonsoir' => "Bonsoir ! Comment s'est passée ta journée ?",
  'salut'   => "Mes salutations ! Comment allez-vous ?",
  'hello'   => "Greetings! How are you today?",
  'hey'     => "Greetings! How are you today?"
}

banned_users = {
  '1219737701096489010' => 'kaiserrlearabe', # gore + pornographie
  '1014460761466224660' => 'sky100papier', # Harcèlements de femmes
  '1167590562820538439' => 'blazz@r', # Harcèlement de femmes
  '748256685209944166' => 'i want to khra zehef', # Harcèlement de femmes
  '813850329032556564' => 'moha95120' # Pub pour cartes bancaires "pas cher"
}

# ======================
# Personality manager
# ======================

# Liste des personnalités disponibles
def list_miyo_personalities_fr
  {
    1 => "Distante, froide, se sentant supérieure et plutôt mondaine, elle saura vous aider. C'est le modèle original, celui qui a été initialement conçue et intégré dans le projet.",
    2 => "Plutôt sentimentale, Miyo se veut aimable, à l'écoute et compréhensive. Parfaite pour vous proposer des solutions à vos problèmes, elle saura être le rayon de soleil de votre journée !",
    3 => "Avez-vous rêvé de vous faire draguer ? Eh bien, cette personnalité est faite pour vous ! Toutefois, elle restera SFW pour des raisons évidentes d'éthique. Cette personnalité est plus pour le fun.",
    4 => "Ohio ! Gomenasaï, je n'ai pas présenté cette personnalité avant, sumimasen, quel baka je fais ! Comme vous l'aurez compris, Miyo est devenue la baka ohio goon everywhere qu'elle pense être.",
    5 => "Mondaine, une fois de plus, mais cette fois sans vous rappeler la place que vous occupez."
  }
end

def list_miyo_personalities_en
  {
    1 => "Distant, cold, feeling superior and rather worldly, she will know how to help you. This is the original model, the one initially designed and integrated into the project.",
    2 => "Rather sentimental, Miyo aims to be kind, attentive, and understanding. Perfect to offer solutions to your problems, she will be the ray of sunshine in your day!",
    3 => "Ever dreamed of being flirted with? Well, this personality is made for you! However, she will remain SFW for obvious ethical reasons. This personality is more for fun.",
    4 => "Ohio! Gomenasaï, I didn’t introduce this personality earlier, sumimasen, what a baka I am! As you might have guessed, Miyo has become the baka ohio goon everywhere she thinks she is.",
    5 => "Worldly, once again, but this time without reminding you of the place you hold."
  }
end

##############################
# Bot command, but only for you (don't forget to change MY_USER_ID)
##############################

bot.command(:banuseradd) do |event, *args|
  break unless event.user.id == MY_USER_ID

  if args.empty?
    event.respond "Utilisation : `!banuseradd <user_id> [raison...]`"
    next
  end

  banned_users = load_banned_users
  user_id = args.shift.to_i
  reason = args.join(" ").strip
  user_id_str = user_id.to_s

  if user_id == 0
    event.respond "ID invalide."
    next
  end

  user = event.server.member(user_id) rescue nil

  username = if user
    "#{user.username}##{user.discriminator}"
  elsif banned_users[user_id_str]
    banned_users[user_id_str]["tag"]
  else
    event.respond "ℹLe pseudo de l’utilisateur est inconnu. Veuillez le saisir manuellement (ex : `Pseudo#1234`) :"
    response = event.user.await!(timeout: 30)
    if response
      response.message.content.strip
    else
      event.respond "Temps écoulé. Annulation de l’ajout."
      next
    end
  end

  banned_users[user_id_str] = {
    "tag" => username,
    "reason" => reason.empty? ? "Non précisé" : reason
  }

  save_banned_users(banned_users)
  event.respond "**#{username}** (`#{user_id}`) a été ajouté à la liste des bannis.\nRaison : *#{banned_users[user_id_str]['reason']}*"

  if event.server.member(user_id)
    begin
      user.pm.send_message(
        "**Bonjour,**\n\nVous avez été automatiquement banni de **#{event.server.name}** par le système d'autoban de Miyo.\n\n📄 **Raison :** #{reason}\n\nSi vous pensez qu’il s’agit d’une erreur, vous pouvez ajouter <@#{MY_USER_ID}> en ami pour en discuter, ou rejoindre ce serveur : https://discord.gg/SeJr7ANamW"
      )
    rescue
      puts "Impossible d’envoyer un message privé à #{user.distinct}."
    end
  
    begin
      event.server.ban(user, reason: "Ajout à la liste des bannis : #{reason}")
    rescue StandardError
      puts "Impossible de bannir #{user.username}"
    end
  end
end  


bot.command(:banuserremove) do |event, user_id|
  break unless event.user.id == MY_USER_ID

  banned_users = load_banned_users
  user_id_str = user_id.to_s

  if banned_users.delete(user_id_str)
    save_banned_users(banned_users)
    event.respond "Utilisateur `#{user_id}` retiré de la liste des bannis."
  else
    event.respond "Cet utilisateur n’est pas dans la liste."
  end
end

bot.command(:banuserlist) do |event|
  break unless event.user.id == MY_USER_ID

  banned_users = load_banned_users

  if banned_users.empty?
    event.respond "📜 La liste des bannis est vide."
  else
    list = banned_users.each_with_index.map do |(id, info), index|
      "**#{index + 1}.** `#{id}` • **#{info['tag']}**\n>  *#{info['reason']}*"
    end.join("\n")

    event.respond(list.length < 2000 ? list : "Trop de bannis pour être affichés dans un seul message (#{list.length} caractères).")
  end
end

bot.command :stats do |event|
  unless event.user.id == MY_USER_ID
    event.respond "Tu n'as pas la permission d'utiliser cette commande."
    next
  end
  command_usage['stats'] += 1
  stats = COMMANDS.map { |cmd| "`#{PREFIX}#{cmd}` : used #{command_usage[cmd]} times" }.join("\n\n")
  event.respond "**Stats actuelles :**\n#{stats}"
end

bot.command :déco do |event|
  if event.user.id == MY_USER_ID
    bot.send_message(event.channel.id, 'Bot is shutting down')
    exit
  else
    event.respond 'You do not have permission to disconnect the bot.'
  end
end

##############################
# INTERACTIONS COMMANDS
##############################
settings = JSON.parse(File.read('starboard.json'))
server_id = ENV.fetch('SLASH_COMMAND_BOT_SERVER_ID', nil).to_s
autoban_enabled = settings.dig(server_id, 'autoban_system', 'autoban_enabled')

# You'll need these if you want to use the same commands as me
# Just remove the '#'
# If you have registered wrong command, you'll need to put this line before all the one you want to keep
# bot.get_application_commands.each(&:delete)
# bot.register_application_command(:welcome, 'If you want to set my messages to welcome someone.', server_id: ENV.fetch('SLASH_COMMAND_BOT_SERVER_ID', nil)) do |cmd|
# end
# bot.register_application_command(:info, 'If you want informations about me.', server_id: ENV.fetch('SLASH_COMMAND_BOT_SERVER_ID', nil)) do |cmd|
# end
# bot.register_application_command(:language, 'You can change my language here.', server_id: ENV.fetch('SLASH_COMMAND_BOT_SERVER_ID', nil)) do |cmd|
# end
# bot.register_application_command(:personality, 'You can change my personality here.', server_id: ENV.fetch('SLASH_COMMAND_BOT_SERVER_ID', nil)) do |cmd|
# end
# bot.register_application_command(:autoban, "System to ban people who were problematic in other servers.", server_id: ENV.fetch('SLASH_COMMAND_BOT_SERVER_ID', nil)) do |cmd|
# end
#bot.register_application_command(:osurelated, 'Commandes liées à Osu!') do |cmd|
#
#  cmd.subcommand_group(:osu, 'Commandes Osu!') do |group|
#   group.subcommand('linkaccount', 'Lier votre compte Osu! à votre compte Discord.') do |sub|
#      sub.string('username_osu', "Link your Osu! username to your discord account", required: true)
#   end
#   group.subcommand('unlinkaccount', 'Unlink your username Osu! to your discord account.') do |sub|
#   end
#   group.subcommand('rs', 'Get the most recent score of a player.') do |sub|
#     sub.string('username', 'Not you ? Specify the name of the player here !', required: false)
#   end
#   group.subcommand('random_map', 'Find a random map for Osu') do |sub|
#      sub.string('stars', "The more you'll send, the more the map will be difficult.", required: true)
#   end
# end
#end
#bot.register_application_command(:twotruthsonelie, 'Lance Two Truths One Lie') do |cmd|
#  cmd.user('adversaire', 'La personne qui devra deviner', required: true)
#  cmd.string('truth1', 'Première vérité', required: true)
#  cmd.string('truth2', 'Deuxième vérité', required: true)
#  cmd.string('lie', 'Le mensonge', required: true)
# end
# bot.register_application_command(:dailyquestion, 'If you want to have a question everyday to revive your chat') do |cmd|
# end

bot.application_command(:dailyquestion) do |event|
    is_admin = event.user.roles.any? { |role| role.permissions.administrator } || EXCLUDED_USERS.include?(event.user.id)
  unless is_admin
    event.respond "Vous n'avez pas la permission d'utiliser cette commande."
    next
  end
  server__id = event.server.id
  settings = load_starboard_settings
  server_settings = settings[event.server.id.to_s] || {}
  language_settings = server_settings['language'] || {}
  lang = load_language_id_from_starboard(server_id)

  if lang == 'french'
    event.channel.send_embed do |embed|
      embed.title = "Une question tous les jours ? C'est dans mes cordes."
      embed.description = "Si vous sentez que votre communautés s'affaiblie et/ou que vous souhaitez plus d'activités, voici l'une des solutions que je peux vous proposer.\nVous n'avez qu'à paramétrez où est-ce que vous souhaitez que je l'envoie et activer le système.\n-Les questions sont des questions prédéfinies, il se peux que je me répète et/ou que je répète la même question deux jours d'affilés si vous souhaitez en ajouter, veuillez passer par notre serveur."
      embed.color = 0x3498db
      embed.timestamp = Time.now

      embed.author = Discordrb::Webhooks::EmbedAuthor.new(
        name: "Miyo",
        url: "https://linktr.ee/Miyo_DiscordBot",
        icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
      )

      embed.footer = Discordrb::Webhooks::EmbedFooter.new(
        text: "Signé,\nMiyo.",
      )
    end
    menu_message = event.channel.send_message(
    '', false, nil, nil, nil, nil,
    Discordrb::Components::View.new do |builder|
      builder.row do |r|
        r.string_select(custom_id: 'daily_question_option', placeholder: 'Choose an option', max_values: 1) do |ss|
          ss.option(label: 'Activate/Desactivate the system', value: '1', emoji: { name: '1️⃣' })
          ss.option(label: "Modify the channel where the question will be sended", value: '2', emoji: { name: '2️⃣' })
        end
      end
    end
    )
  elsif lang == 'english'
    event.channel.send_embed do |embed|
     embed.title = "Une question tous les jours ? C'est dans mes cordes."
      embed.description = "Si vous sentez que votre communautés s'affaiblie et/ou que vous souhaitez plus d'activités, voici l'une des solutions que je peux vous proposer.\nVous n'avez qu'à paramétrez où est-ce que vous souhaitez que je l'envoie et activer le système.\n-Les questions sont des questions prédéfinies, il se peux que je me répète et/ou que je répète la même question deux jours d'affilés si vous souhaitez en ajouter, veuillez passer par notre serveur."      
      embed.color = 0x3498db
      embed.timestamp = Time.now

      embed.author = Discordrb::Webhooks::EmbedAuthor.new(
        name: "Miyo",
        url: "https://fr.tipeee.com/miyo-bot-discord/",
        icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
      )

      embed.footer = Discordrb::Webhooks::EmbedFooter.new(
        text: "Signed,\nMiyo.",
      )

      embed.add_field(name: "Tipeee ☕", value: "[Thanks !](https://fr.tipeee.com/miyo-bot-discord/)", inline: true)
    end
  end
end

bot.string_select(custom_id: 'daily_question_option') do |event|
  if command_users[event.user.id].nil?
    event.interaction.respond(content: "Vous n'avez pas la permission d'utiliser cette commande.", ephemeral: true)
    next
  end

  command_users[event.user.id] = Time.now

  settings = load_starboard_settings
  server_settings = settings[event.server.id.to_s] || {}
  question_settings = server_settings['daily_question_system'] || {}

  case event.values.first
  when '1'
    question_settings['active'] = !question_settings.fetch('active', false)
    event.interaction.respond(content: "Le système d'envoie de question quotidiennes est désormais #{question_settings['active'] ? 'activé' : 'désactivé'}.", ephemeral: true)
  when '2'
    event.interaction.respond(content: "Veuillez sélectionner le salon pour les questions du jour.", ephemeral: false)
    event.channel.send_message(
      '', false, nil, nil, nil, nil,
      Discordrb::Components::View.new do |builder|
        builder.row do |r|
          r.channel_select(custom_id: 'question_channel_select', placeholder: 'Sélectionnez le salon', max_values: 1)
        end
      end
    )
  end

  server_settings['daily_question_system'] = question_settings
  settings[event.server.id.to_s] = server_settings
  save_starboard_settings(settings)
end

#####################################
# Help command
#####################################
bot.application_command(:help) do |event|
  server_id = event.server.id
  settings = load_starboard_settings
  server_settings = settings[event.server.id.to_s] || {}
  language_settings = server_settings['language'] || {}

  
  lang = load_language_id_from_starboard(server_id)
  if lang == 'french'
    event.channel.send_embed do |embed|
      embed.title = "Mes salutations !"
      embed.description = "Je me prénomme Miyo, à votre service.\nJe dispose de quelques commandes que vous pourrez utiliser tout du long de mon histoire sur ce serveur. \n### Fun\n- !talk : vous donne une phrase aléatoire parmi tous les mots et personnes que je connais \n### Osu\n- !osulink : permet de lier votre nom de compte osu avec votre id sur discord. Facilite l'utilisation de la commande '!rs' et 'osu'\n- !osuunlink : permet permet de délier votre nom de compte osu avec votre id sur discord.\n- !rs : permet de voir le score le plus récent d'un joueur osu.\n- !osu : permet de voir le score le plus récent d'un joueur osu.\n- !osurdm : permet de trouver une beatmap adaptée à votre demande.\n### Interactions\n- !kiss : vous permet d'embrasser quelqu'un... Quelle commande futile.\n- !hug : vous permet de câliner quelqu'un... Enfin, si vous avez quelqu'un à câliner.\n- !punch : vous permet de frapper quelqu'un. Veuillez l'utiliser à tout moment, les affrontement de personnes inférieurs à la noblesse est tellement divertissant.\n- !trigger : afin d'exprimer votre colère.\n### Commandes modérateur\n- !welcome : vous permet de configurer un système de bienvenue sur votre serveur.\n- !autoban : vous permet de configurer un système d'autoban (plus d'informations en faisant la commande)\n- !personality : Vous permet de changer ma personnalité lors de mes interactions avec l'ia. À noter que mes messages, lors de mes commandes, ne changerons pas.\n- !language : Vous permet de changer ma langue lors de mes messages prédéfinis et pour l'IA.\n\nÉgalement, je réagis à certains mots, il faudra que vous discutiez pour tous les connaîtres. Si vous me le permettez, ma présentation se termine ici, et j'espère qu'elle saura vous convaincre. Si vous souhaitez me solliciter, mentionnez-moi, je me ferais une (fausse) joie de vous répondre."
      embed.color = 0x3498db
      embed.timestamp = Time.now

      embed.author = Discordrb::Webhooks::EmbedAuthor.new(
        name: "Miyo",
        url: "https://fr.tipeee.com/miyo-bot-discord/",
        icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
      )

      embed.footer = Discordrb::Webhooks::EmbedFooter.new(
        text: "Signé,\nMiyo.",
      )

      embed.add_field(name: "Tipeee ☕", value: "[Merci !](https://fr.tipeee.com/miyo-bot-discord/)", inline: true)
    end
  elsif lang == 'english'
    event.channel.send_embed do |embed|
      embed.title = "Greetings !"
      embed.description = "My name is Miyo, at your service.\nI have a few commands you can use throughout my story on this server.\n### Fun\n- !talk : gives you a random sentence from all the words and people I know\n### Osu\n- !osulink : links your osu account name with your Discord ID. Makes using the '!rs' and 'osu' commands easier\n- !osuunlink : unlinks your osu account name from your Discord ID\n- !rs : shows the most recent score of an osu player\n- !osu : shows the most recent score of an osu player\n- !osurdm : helps you find a beatmap suited to your request\n### Interactions\n- !kiss : lets you kiss someone... What a futile command.\n- !hug : lets you hug someone... If you even have someone to hug.\n- !punch : lets you punch someone. Feel free to use it anytime, watching commoners fight is quite entertaining.\n- !trigger : to express your anger.\n### Moderator Commands\n- !welcome : lets you set up a welcome system on your server.\n- !autoban : lets you set up an autoban system (more info by using the command)\n- !personality : let you change my personality during AI interactions.\n- !language : let you change my language\n\nNote that my messages during commands will not change.\n\nI also react to certain words — you’ll have to talk to me to discover them all. If you allow me, this concludes my introduction, and I hope it will convince you. If you wish to summon me, mention me, and I’ll make a (fake) delight of replying to you."
      embed.color = 0x3498db
      embed.timestamp = Time.now

      embed.author = Discordrb::Webhooks::EmbedAuthor.new(
        name: "Miyo",
        url: "https://fr.tipeee.com/miyo-bot-discord/",
        icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
      )

      embed.footer = Discordrb::Webhooks::EmbedFooter.new(
        text: "Signed,\nMiyo.",
      )

      embed.add_field(name: "Tipeee ☕", value: "[Thanks !](https://fr.tipeee.com/miyo-bot-discord/)", inline: true)
    end
  end
end

#####################################
# Info command
#####################################

bot.application_command(:info) do |event|
  server_id = event.server.id
  settings = load_starboard_settings
  server_settings = settings[event.server.id.to_s] || {}
  language_settings = server_settings['language'] || {}
  lang = load_language_id_from_starboard(server_id)
  if lang == 'french'
    event.channel.send_embed do |embed|
      embed.title = "Des informations sur moi ? Charmant."
      embed.description = "Je me prénomme Miyo, à votre service.\nJe suis codé intégralement en Ruby, en utilisant la librairie 'discordrb', majoritairement par mon créateur Museau.\nJe remercie l'aide de Cyn, qui a aidé Museau lorsqu'il en avait besoin.\nVous auriez besoin d'un gâteau ? Demandez à Glados et à son créateur, Roxas.\nBien, j'en eu trop dit, si vous souhaiter me solliciter, veuillez utiliser la commande !help. Si vous voulez bien m'excuser..."
      embed.color = 0x3498db
      embed.timestamp = Time.now

      embed.author = Discordrb::Webhooks::EmbedAuthor.new(
        name: "Miyo",
        url: "https://fr.tipeee.com/miyo-bot-discord/",
        icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
      )

      embed.footer = Discordrb::Webhooks::EmbedFooter.new(
        text: "Signé,\nMiyo.",
      )

      embed.add_field(name: "Tipeee ☕", value: "[Merci !](https://fr.tipeee.com/miyo-bot-discord/)", inline: true)
    end
  elsif lang == 'english'
    event.channel.send_embed do |embed|
      embed.title = "My informations ? Charming"
      embed.description = "My name is Miyo, at your service.\nI am fully coded in Ruby, using the 'discordrb' library, mostly by my creator Museau.\nI thank Cyn for the help given to Museau when he needed it.\nWell, I’ve said too much, if you wish to summon me, please use the !help command. If you will excuse me..."
      embed.color = 0x3498db
      embed.timestamp = Time.now

      embed.author = Discordrb::Webhooks::EmbedAuthor.new(
        name: "Miyo",
        url: "https://fr.tipeee.com/miyo-bot-discord/",
        icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
      )

      embed.footer = Discordrb::Webhooks::EmbedFooter.new(
        text: "Signed,\nMiyo.",
      )

      embed.add_field(name: "Tipeee ☕", value: "[Thanks !](https://fr.tipeee.com/miyo-bot-discord/)", inline: true)
    end
  end
end

#####################################
# Language command
#####################################

bot.application_command(:language) do |event|
  member = event.server.member(event.user.id)
  is_admin = member&.roles&.any? { |role| role.permissions.administrator } || EXCLUDED_USERS.include?(event.user.id)
  
  unless is_admin
    event.respond "Vous n'avez pas la permission d'utiliser cette commande."
    next
  end

  server_id = event.server.id
  settings = load_starboard_settings
  server_settings = settings[event.server.id.to_s] || {}
  language_settings = server_settings['language'] || {}


  command_users[event.user.id] = Time.now
  if load_language_id_from_starboard(server_id) == "french"
    event.channel.send_embed do |embed|
      embed.title = "Système de changement de langue"
      embed.description = "Vous souhaitez changer de langue ? Bien, c'est ici que vous pourrez opérer. Vous avez juste à cliquer sur le menu ci-dessous, et vous pourrez apprécier une autre langue.\n\nToutefois, veuillez garder en tête que les commandes ne seront pas changées."
      embed.color = 0x3498db
      embed.timestamp = Time.now
      embed.author = Discordrb::Webhooks::EmbedAuthor.new(
        name: "Miyo",
        url: "https://fr.tipeee.com/miyo-bot-discord/",
        icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
      )
      embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "Signé,\nMiyo.")
      embed.add_field(
        name: "Si vous souhaitez contribuer au système de langue en proposant et/ou en traduisant le bot, vous n'avez qu'à rejoindre le serveur si dessous.",
        value: "[Museau's World](https://discord.gg/SeJr7ANamW)",
        inline: true
      )
      embed.add_field(name: "Tipeee ☕", value: "[Merci !](https://fr.tipeee.com/miyo-bot-discord/)", inline: true)
    end
    menu_message = event.channel.send_message(
    '', false, nil, nil, nil, nil,
    Discordrb::Components::View.new do |builder|
      builder.row do |r|
        r.string_select(custom_id: 'language_select', placeholder: 'Choose a language', max_values: 1) do |ss|
          ss.option(label: 'English', value: '1', emoji: { name: '🇬🇧' })
          ss.option(label: "Français", value: '2', emoji: { name: '🇫🇷' })
        end
      end
    end
    )
    elsif load_language_id_from_starboard(server_id) == "english"
      event.channel.send_embed do |embed|
        embed.title = "Language switching system"
        embed.description = "Do you want to change my language ? Well, this is where you can operate. You just need to click on the menu below, and you'll be able to enjoy another language\n\nNote: This will not change command names"
        embed.color = 0x3498db
        embed.timestamp = Time.now
        embed.author = Discordrb::Webhooks::EmbedAuthor.new(
          name: "Miyo",
          url: "https://fr.tipeee.com/miyo-bot-discord/",
          icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
        )
        embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "Signé,\nMiyo.")
        embed.add_field(
          name: "If you want to contribute in the language switching system by asking a language and/or participate in the translation, all you need is to join this server.",
          value: "[Museau's World](https://discord.gg/SeJr7ANamW)",
          inline: true
        )
        embed.add_field(name: "Tipeee ☕", value: "[Merci !](https://fr.tipeee.com/miyo-bot-discord/)", inline: true)
      end
      menu_message = event.channel.send_message(
    '', false, nil, nil, nil, nil,
    Discordrb::Components::View.new do |builder|
      builder.row do |r|
        r.string_select(custom_id: 'language_select', placeholder: 'Choose a language', max_values: 1) do |ss|
          ss.option(label: 'English', value: '1', emoji: { name: '🇬🇧' })
          ss.option(label: "Français", value: '2', emoji: { name: '🇫🇷' })
        end
      end
    end
  )
  end
end

bot.string_select(custom_id: 'language_select') do |event|
  unless command_users.key?(event.user.id)
    event.interaction.respond(content: "Vous n'avez pas la permission d'utiliser cette commande.", ephemeral: true)
    next
  end

  choice = event.values.first
  settings = load_starboard_settings
  server_settings = settings[event.server.id.to_s] ||= {}

  response_text = case choice
  when '1'
    server_settings['miyo_language'] = 'english'
    "The bot will now talk in english ! Enjoy !"
  when '2'
    server_settings['miyo_language'] = 'french'
    "Le bot parlera maintenant en français ! Enjoy !"
  else
    "Choix invalide."
  end

  save_starboard_settings(settings)

  event.interaction.respond(content: response_text, ephemeral: true)
end

#####################################
# Personality command
#####################################
bot.application_command(:personality) do |event|
  is_admin = event.user.roles.any? { |role| role.permissions.administrator } || EXCLUDED_USERS.include?(event.user.id)
  unless is_admin
    event.respond "Vous n'avez pas la permission d'utiliser cette commande."
    next
  end

  server_id = event.server.id
  settings = load_starboard_settings
  server_settings = settings[event.server.id.to_s] || {}
  language_settings = server_settings['language'] || {}

  command_users[event.user.id] = Time.now
  lang = load_language_id_from_starboard(server_id)

  if lang == "french"
    event.channel.send_embed do |embed|
      embed.title = "Mes personnalités ?"
      embed.description = "Vous voulez modifier ma personnalité ? Très bien.\n\nMais je resterai mondaine en dehors de ces options !\n\nVoici mes styles disponibles :\n\n#{cmd_list_personalities(server_id)}"
      embed.color = 0x3498db
      embed.timestamp = Time.now
      embed.author = Discordrb::Webhooks::EmbedAuthor.new(
        name: "Miyo",
        url: "https://fr.tipeee.com/miyo-bot-discord/",
        icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
      )
      embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "Signé,\nMiyo.")
      embed.add_field(name: "Buy me a coffee ☕", value: "[Merci !](https://fr.tipeee.com/miyo-bot-discord/)", inline: true)
    end

    menu_message = event.channel.send_message(
      '', false, nil, nil, nil, nil,
      Discordrb::Components::View.new do |builder|
        builder.row do |r|
          r.string_select(custom_id: 'personality_select', placeholder: 'Choisissez une personnalité', max_values: 1) do |ss|
            ss.option(label: 'Froid, distant', value: '1', emoji: { name: '👑' })
            ss.option(label: "Aimable", value: '2', emoji: { name: '🫶' })
            ss.option(label: "Séduisante (SFW)", value: '3', emoji: { name: '🫦' })
            ss.option(label: "Bakaaaa", value: '4', emoji: { name: '🤪' })
            ss.option(label: "Mondaine", value: '5', emoji: { name: '⚜️' })
          end
        end
      end
    )
  elsif lang == "english"
    event.channel.send_embed do |embed|
      embed.title = "My personalities?"
      embed.description = "Want to change my personality? Very well.\n\nBut I’ll stay worldly outside these options!\n\nHere are my available styles:\n\n#{cmd_list_personalities(server_id)}"
      embed.color = 0x3498db
      embed.timestamp = Time.now
      embed.author = Discordrb::Webhooks::EmbedAuthor.new(
        name: "Miyo",
        url: "https://fr.tipeee.com/miyo-bot-discord/",
        icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
      )
      embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "Signed,\nMiyo.")
      embed.add_field(name: "Buy me a coffee ☕", value: "[Thank you!](https://fr.tipeee.com/miyo-bot-discord/)", inline: true)
    end

    menu_message = event.channel.send_message(
      '', false, nil, nil, nil, nil,
      Discordrb::Components::View.new do |builder|
        builder.row do |r|
          r.string_select(custom_id: 'personality_select', placeholder: 'Choose a personality', max_values: 1) do |ss|
            ss.option(label: 'Cold, distant', value: '6', emoji: { name: '👑' })
            ss.option(label: "Kind", value: '7', emoji: { name: '🫶' })
            ss.option(label: "Seductive (SFW)", value: '8', emoji: { name: '🫦' })
            ss.option(label: "Bakaaaa", value: '9', emoji: { name: '🤪' })
            ss.option(label: "Worldly", value: '10', emoji: { name: '⚜️' })
          end
        end
      end
    )
  end
end

bot.string_select(custom_id: 'personality_select') do |event|
  unless command_users.key?(event.user.id)
    event.interaction.respond(content: "Vous n'avez pas la permission d'utiliser cette commande.", ephemeral: true)
    next
  end

  choice = event.values.first
  settings = load_starboard_settings
  server_settings = settings[event.server.id.to_s] ||= {}
  language_settings = server_settings['language'] || {}

  response_text = case choice
  when '1'
    server_settings['miyo_personality_system'] = 1
    "🧊 Mode activé : Froid, distant."
  when '2'
    server_settings['miyo_personality_system'] = 2
    "🌼 Mode activé : Aimable."
  when '3'
    server_settings['miyo_personality_system'] = 3
    "💋 Mode activé : Séduisante (SFW)."
  when '4'
    server_settings['miyo_personality_system'] = 4
    "🤪 Mode activé : Bakaaaa !"
  when '5'
    server_settings['miyo_personality_system'] = 5
    "⚜️ Mode activé : Mondaine."
  when '6'
    server_settings['miyo_personality_system'] = 6
    "🧊 Activated mode : Cold, distant."
  when '7'
    server_settings['miyo_personality_system'] = 7
    "🌼 Activated mode : Kind."
  when '8'
    server_settings['miyo_personality_system'] = 8
    "💋 Activated mode : Seductive (SFW)."
  when '9'
    server_settings['miyo_personality_system'] = 9
    "🤪 Activated mode : Bakaaaa."
  when '10'
    server_settings['miyo_personality_system'] = 10
    "⚜️ Activated mode : Worldly"
  else
    "Invalid choice. Try again."
  end

  save_starboard_settings(settings)

  event.interaction.respond(content: response_text, ephemeral: true)
end

#####################################
# Autoban command
#####################################

bot.application_command(:autoban) do |event|
  is_admin = event.user.roles.any? { |role| role.permissions.administrator } || EXCLUDED_USERS.include?(event.user.id)
  unless is_admin
    event.respond "Vous n'avez pas la permission d'utiliser cette commande."
    next
  end

  command_users[event.user.id] = Time.now
  lang = load_language_id_from_starboard(event.server.id)

  server_id = event.server.id
  settings = load_starboard_settings
  server_settings = settings[event.server.id.to_s] || {}
  autoban_settings = server_settings['autoban_system'] || {}


  command_users[event.user.id] = Time.now
  if lang == 'french'
    event.channel.send_embed do |embed|
      embed.title = "Système d'auto bannissement"
      embed.description = "Le système d'auto bannissement est actuellement ** #{autoban_settings['active'] ? 'activé' : 'désactivé'}.** sur ce serveur.\nCe système vous permet de bannir automatiquement des personnes qui ont été perçues comme peu recommandables sur d'autres serveurs dès qu'elles rejoignent, ou après une petite période de temps. Ce système n'est pas parfait, il n'empêche pas et n'empêchera jamais quelqu'un d'envoyer un contenu contraire aux règles ou conditions d'utilisation de Discord, et n'empêche en aucun cas la création d'un second compte.\n\nVoici les options :\n- Activer ou désactiver ce système\n- Modifier le salon d'envoi\n\nDépêchez-vous, je n'ai guère de temps à vous accorder."
      embed.color = 0x3498db
      embed.timestamp = Time.now
      embed.author = Discordrb::Webhooks::EmbedAuthor.new(
        name: "Miyo",
        url: "https://fr.tipeee.com/miyo-bot-discord/",
        icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
      )
      embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "Signé,\nMiyo.")
      embed.add_field(
        name: "Si vous souhaitez contribuer au système d'autoban, en ajoutant quelqu'un par exemple, veuillez en parler ici (preuves à l'appui demandées)",
        value: "[Museau's World](https://discord.gg/SeJr7ANamW)",
        inline: true
      )
      embed.add_field(name: "Buy me a coffee ☕", value: "[Merci !](https://fr.tipeee.com/miyo-bot-discord/)", inline: true)
    end
  elsif lang == 'english'
    event.channel.send_embed do |embed|
      embed.title = "Autoban system"
      embed.description = "The autoban system is currently ** #{autoban_settings['active'] ? 'actived' : 'desactivated'}.** on this server.\nThis system allows you to automatically ban people who have been flagged as untrustworthy on other servers as soon as they join, or after a short period of time. This system is not perfect; it does not and never will prevent someone from sending content that violates the rules or Discord's terms of service, and it does not in any way prevent the creation of a second account.\n\nHere are the options:\n- Activate or deactivate this system\n- Modify the output channel\n\nHurry up, I have little time to spare for you."
      embed.color = 0x3498db
      embed.timestamp = Time.now
      embed.author = Discordrb::Webhooks::EmbedAuthor.new(
        name: "Miyo",
        url: "https://fr.tipeee.com/miyo-bot-discord/",
        icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
      )
      embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "Signé,\nMiyo.")
      embed.add_field(
        name: "If you want to contribute in the autoban system, for example to add someone, please join the server (proof will be asked)",
        value: "[Museau's World](https://discord.gg/SeJr7ANamW)",
        inline: true
      )
      embed.add_field(name: "Buy me a coffee ☕", value: "[Merci !](https://fr.tipeee.com/miyo-bot-discord/)", inline: true)
    end
  end

  menu_message = event.channel.send_message(
    '', false, nil, nil, nil, nil,
    Discordrb::Components::View.new do |builder|
      builder.row do |r|
        r.string_select(custom_id: 'autoban_select', placeholder: 'Choisissez une option', max_values: 1) do |ss|
          ss.option(label: 'Activate/Desactivate the system', value: '1', emoji: { name: '1️⃣' })
          ss.option(label: "Modify the channel where autoban messages will be sended", value: '2', emoji: { name: '2️⃣' })
        end
      end
    end
  )
end

bot.string_select(custom_id: 'autoban_select') do |event|
  if command_users[event.user.id].nil?
    event.interaction.respond(content: "Vous n'avez pas la permission d'utiliser cette commande.", ephemeral: true)
    next
  end

  command_users[event.user.id] = Time.now

  settings = load_starboard_settings
  server_settings = settings[event.server.id.to_s] || {}
  autoban_settings = server_settings['autoban_system'] || {}

  case event.values.first
  when '1'
    autoban_settings['active'] = !autoban_settings.fetch('active', false)
    event.interaction.respond(content: "Le système d'auto bannissement est désormais #{autoban_settings['active'] ? 'activé' : 'désactivé'}.", ephemeral: true)
  when '2'
    event.interaction.respond(content: "Veuillez sélectionner le salon pour les messages de l'auto bannissement.", ephemeral: false)
    event.channel.send_message(
      '', false, nil, nil, nil, nil,
      Discordrb::Components::View.new do |builder|
        builder.row do |r|
          r.channel_select(custom_id: 'autoban_channel_select', placeholder: 'Sélectionnez le salon', max_values: 1)
        end
      end
    )
  end

  server_settings['autoban_system'] = autoban_settings
  settings[event.server.id.to_s] = server_settings
  save_starboard_settings(settings)
end

bot.channel_select(custom_id: 'autoban_channel_select') do |event|
  if command_users[event.user.id].nil?
    event.interaction.respond(content: "Vous n'avez pas la permission d'utiliser cette commande.", ephemeral: true)
    next
  end

  command_users[event.user.id] = Time.now

  settings = load_starboard_settings
  server_settings = settings[event.server.id.to_s] || {}
  autoban_settings = server_settings['autoban_system'] || {}

  autoban_settings['log_channel_id'] = event.values.first.id
  event.interaction.respond(content: "Le salon d'auto bannissement est désormais <##{event.values.first.id}>.", ephemeral: true)

  server_settings['autoban_system'] = autoban_settings
  settings[event.server.id.to_s] = server_settings
  save_starboard_settings(settings)
end

#####################################
# Welcome command
#####################################

bot.application_command(:welcome) do |event|
  is_admin = event.user.roles.any? { |role| role.permissions.administrator } || EXCLUDED_USERS.include?(event.user.id)
  unless is_admin
    event.respond "Vous n'avez pas la permission d'utiliser cette commande."
    next
  end

  command_users[event.user.id] = Time.now
  lang = load_language_id_from_starboard(event.server.id)
  if lang == 'french'
    event.channel.send_embed do |embed|
      embed.title = "Système de bienvenue !"
      embed.description = "Vous prévoyez d'accueillir de nouvelles personnes ? Voici ce que je peux faire :\n\n- Activer ou désactiver le système de bienvenue\n- Modifier le salon d'envoi du message de bienvenue\n\nDépêchez-vous, je n'ai guère votre temps."
      embed.color = 0x3498db
      embed.timestamp = Time.now
      embed.author = Discordrb::Webhooks::EmbedAuthor.new(
        name: "Miyo",
        url: "https://fr.tipeee.com/miyo-bot-discord/",
        icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
      )
      embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "Signé,\nMiyo.")
    end

    menu_message = event.channel.send_message(
      '', false, nil, nil, nil, nil,
      Discordrb::Components::View.new do |builder|
        builder.row do |r|
          r.string_select(custom_id: 'welcome_select', placeholder: 'Choisissez une option', max_values: 1) do |ss|
            ss.option(label: 'Activer/Désactiver le système', value: '1', emoji: { name: '1️⃣' })
            ss.option(label: "Modifier le salon d'envoi", value: '2', emoji: { name: '2️⃣' })
          end
        end
      end
    )
  elsif lang == 'english'
    event.channel.send_embed do |embed|
      embed.title = "Welcome System!"
      embed.description = "Planning to welcome new people? Here's what I can do:\n\n- Activate or deactivate the welcome system\n- Modify the channel for the welcome message\n\nHurry up, I don't have all your time."
      embed.color = 0x3498db
      embed.timestamp = Time.now
      embed.author = Discordrb::Webhooks::EmbedAuthor.new(
        name: "Miyo",
        url: "https://fr.tipeee.com/miyo-bot-discord/",
        icon_url: "https://cdn.discordapp.com/avatars/1304923218439704637/756278f1866c1579e31e9989f27802e2.png?size=256"
      )
      embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "Signed,\nMiyo.")
    end

    menu_message = event.channel.send_message(
      '', false, nil, nil, nil, nil,
      Discordrb::Components::View.new do |builder|
        builder.row do |r|
          r.string_select(custom_id: 'welcome_select', placeholder: 'Choose an option', max_values: 1) do |ss|
            ss.option(label: 'Activate/Desactivate system', value: '1', emoji: { name: '1️⃣' })
            ss.option(label: "Modify the welcome channel", value: '2', emoji: { name: '2️⃣' })
          end
        end
      end
    )
  end
end

bot.string_select(custom_id: 'welcome_select') do |event|
  lang = load_language_id_from_starboard(event.server.id)
  if lang == 'french'
    if command_users[event.user.id].nil?
      event.interaction.respond(content: "Vous n'avez pas la permission d'utiliser cette commande.", ephemeral: true)
      next
    end

    command_users[event.user.id] = Time.now

    settings = load_starboard_settings
    server_settings = settings[event.server.id.to_s] || {}
    welcome_settings = server_settings['welcome_system'] || {}

    case event.values.first
    when '1'
      welcome_settings['active'] = !welcome_settings.fetch('active', false)
      event.interaction.respond(content: "Le système de bienvenue est maintenant #{welcome_settings['active'] ? 'activé' : 'désactivé'}.", ephemeral: true)
    when '2'
      event.interaction.respond(content: "Veuillez sélectionner le salon pour les messages de bienvenue.", ephemeral: false)
      event.channel.send_message(
        '', false, nil, nil, nil, nil,
        Discordrb::Components::View.new do |builder|
          builder.row do |r|
            r.channel_select(custom_id: 'welcome_channel_select', placeholder: 'Sélectionnez le salon', max_values: 1)
          end
        end
      )
    end

  elsif lang == 'english'
    if command_users[event.user.id].nil?
      event.interaction.respond(content: "You don't have the permission to use this command.", ephemeral: true)
      next
    end

    command_users[event.user.id] = Time.now

    settings = load_starboard_settings
    server_settings = settings[event.server.id.to_s] || {}
    welcome_settings = server_settings['welcome_system'] || {}

    case event.values.first
    when '1'
      welcome_settings['active'] = !welcome_settings.fetch('active', false)
      event.interaction.respond(content: "The welcome system is now #{welcome_settings['active'] ? 'actived' : 'desactivated'}.", ephemeral: true)
    when '2'
      event.interaction.respond(content: "Please choose the channel where welcomes messages will be send", ephemeral: false)
      event.channel.send_message(
        '', false, nil, nil, nil, nil,
        Discordrb::Components::View.new do |builder|
          builder.row do |r|
            r.channel_select(custom_id: 'welcome_channel_select', placeholder: 'Choose the channel', max_values: 1)
          end
        end
      )
    end
  server_settings['welcome_system'] = welcome_settings
  settings[event.server.id.to_s] = server_settings
  save_starboard_settings(settings)
  end
end

bot.channel_select(custom_id: 'welcome_channel_select') do |event|
  lang = load_language_id_from_starboard(event.server.id)
  if lang == 'french'
    if command_users[event.user.id].nil?
      event.interaction.respond(content: "Vous n'avez pas la permission d'utiliser cette commande.", ephemeral: true)
      next
    end

    command_users[event.user.id] = Time.now

    settings = load_starboard_settings
    server_settings = settings[event.server.id.to_s] || {}
    welcome_settings = server_settings['welcome_system'] || {}

    welcome_settings['welcome_channel_id'] = event.values.first.id
    event.interaction.respond(content: "Le salon de bienvenue est maintenant <##{event.values.first.id}>.", ephemeral: true)

    server_settings['welcome_system'] = welcome_settings
    settings[event.server.id.to_s] = server_settings
    save_starboard_settings(settings)
  elsif lang == 'english'
    event.interaction.respond(content: "You don't have the permission to use this command", ephemeral: true)
    next
  end

  command_users[event.user.id] = Time.now

  settings = load_starboard_settings
  server_settings = settings[event.server.id.to_s] || {}
  welcome_settings = server_settings['welcome_system'] || {}

  welcome_settings['welcome_channel_id'] = event.values.first.id
  event.interaction.respond(content: "The channel where welcome messages will be send is set on <##{event.values.first.id}>.", ephemeral: true)

  server_settings['welcome_system'] = welcome_settings
  settings[event.server.id.to_s] = server_settings
  save_starboard_settings(settings)
end

#####################################
# Osu related commands
#####################################

bot.application_command(:osurelated).group(:osu) do |group|
  group.subcommand('linkaccount') do |event|
    osu_username = event.options['username_osu']

    if osu_username.nil? || osu_username.strip.empty?
      event.respond(content: "Merci d'indiquer un nom de compte après la commande. Exemple : `/osurelated osu linkaccount username_osu: Cookiezi`", ephemeral: true)
      next
    end

    accounts = load_osu_accounts
    accounts[event.user.id.to_s] = osu_username
    save_osu_accounts(accounts)

    event.respond(content: "Votre compte Discord et votre nom de compte Osu (**#{osu_username}**) ont bien été enregistrés.", ephemeral: true)
  end
  group.subcommand('unlinkaccount') do |event|
    accounts = load_osu_accounts
    user_id = event.user.id.to_s
  
    if accounts.key?(user_id)
      accounts.delete(user_id)
      save_osu_accounts(accounts)
      event.respond(content:"Votre nom de compte Osu n'est désormais plus affilié à votre compte discord", ephemeral: true)
    else
      event.respond(content:"Avant de vouloir retirer votre nom de compte, il faudrait peut-être en ajouter un, ne pensez vous pas ?", ephemeral: true)
    end
  end
  group.subcommand('rs') do |event|
    event.defer
    username = event.options['username'] || event.options[:username]
    token = get_osu_token
    accounts = load_osu_accounts
    registered = accounts[event.user.id.to_s]
  
    if (username ||= registered).to_s.strip.empty?
      event.edit_response(
        content: "Avant de voir le score le plus récent, merci d’enregistrer votre compte avec `/osurelated osu linkaccount` ou de fournir un nom d'utilisateur osu! en argument."
      )
      next
    end
  
    score = get_osu_user_recent_score(username, token)
  
    if score
      beatmap_title     = score.dig('beatmapset', 'title') || 'Unknown Beatmap'
      beatmap_id        = score.dig('beatmap', 'id') || '#'
      mapset_id         = score.dig('beatmapset', 'id')
      difficulty_rating = score.dig('beatmap', 'difficulty_rating') || 'N/A'
      bpm               = score.dig('beatmap', 'bpm') || 'N/A'
      difficulty_name   = score.dig('beatmap', 'version') || 'Unknown Difficulty'
      rank              = score['rank']
      accuracy          = score['accuracy']
      modifiers         = score['mods'] || []
  
      count_300  = score.dig('statistics', 'count_300') || 0
      count_100  = score.dig('statistics', 'count_100') || 0
      count_50   = score.dig('statistics', 'count_50') || 0
      count_miss = score.dig('statistics', 'count_miss') || 0
      pp_value   = score['pp'] || 'N/A'
  
      rank_emojis = {
        'SS' => '<:Perfect:1335666845017178243>', 
        'S'  => '<:FullCombo:1335665676714770515>', 
        'A'  => '<:PassA:1335665721774051519>', 
        'B'  => '<:PassB:1335665702203555901>', 
        'C'  => '<:PassC:1335665688572071987>', 
        'D'  => '<:PassD:1346136133016354847>', 
        'F'  => '<:Fail:1335665081547227136>'
      }
  
      if accuracy == 1.0
        rank = (modifiers.include?('HD') || modifiers.include?('FL')) ? '<:Perfect:1335666845017178243>' : 'SS'
      end
  
      rank_display = rank_emojis[rank] || rank
  
      event.channel.send_embed do |embed|
        embed.title = "**Score le plus récent de #{username}:**"
        embed.description = "▸ **Beatmap:** [#{beatmap_title}](https://osu.ppy.sh/b/#{beatmap_id}) (#{difficulty_name}) (#{difficulty_rating}★) (BPM: #{bpm})\n" \
                            "▸ **Score:** #{score['score']}\n" \
                            "▸ **Accuracy:** #{(accuracy * 100).round(2)}%\n" \
                            "▸ **Rank:** #{rank_display}\n" \
                            "▸ **PP:** #{pp_value.nil? ? 'N/A' : '%.2f' % pp_value.to_f}\n" \
                            "▸ **300s:** #{count_300} | **100s:** #{count_100} | **50s:** #{count_50} | **Misses:** #{count_miss}\n" \
                            "*Game Mode: #{score['mode']}*"
        embed.color = 0x3498db
        embed.timestamp = Time.now
  
        user_data = get_osu_user(username, token)
        if user_data
          embed.author = Discordrb::Webhooks::EmbedAuthor.new(
            name: user_data['username'],
            url: "https://osu.ppy.sh/users/#{user_data['id']}",
            icon_url: "https://a.ppy.sh/#{user_data['id']}"
          )
        end
  
        if mapset_id
          embed.add_field(
            name: "Beatmap Info",
            value: "[#{beatmap_title}](https://osu.ppy.sh/beatmapsets/#{mapset_id}) (#{difficulty_name})",
            inline: true
          )
          embed.image = Discordrb::Webhooks::EmbedImage.new(
            url: "https://assets.ppy.sh/beatmaps/#{mapset_id}/covers/cover.jpg"
          )
        end
      end
    else
      event.edit_response(
        content: "J'ai remué ciel, terre et mer, mais je n'ai pas trouvé de score récent pour **#{username}**. Êtes-vous sûr que ce joueur a joué récemment ? C'est le seul travail que je vous demande, et vous n'y arrivez même pas."
      )
    end
  end

  group.subcommand('random_map') do |event|
    star_value = event.options['stars']
    puts star_value
    if star_value.nil?
      event.respond(content:"Veuillez me donner une valeur de difficulté (ex: 4.5).")
      next
    end
  
    star_rating = star_value.to_f
    if star_rating <= 0
      event.respond(content:"Êtes-vous un fanfaron ou un sôt ? Il me faudrait une difficulté valide. Vite, je m'impatiente.")
      next
    end
  
    min_sr = star_rating - 0.1
    max_sr = star_rating + 0.1
  
    cache_path = "beatmap_cache.json"
    begin
      beatmap_cache = JSON.parse(File.read(cache_path))
    rescue => e
      event.respond(content:"Erreur lors de la lecture du cache de beatmaps : #{e.message}")
      next
    end
  
    eligible_beatmaps = beatmap_cache.values.select do |beatmap|
      difficulty = beatmap["difficulty"].to_f
      difficulty >= min_sr && difficulty <= max_sr
    end
  
    if eligible_beatmaps.empty?
      event.respond(content:"Aucune beatmap trouvée pour #{star_rating}★ ±0.1. Essayez une autre valeur.")
      next
    end
  
    selected_map = eligible_beatmaps.sample
  
    beatmap_id = selected_map["id"]
    beatmap_title = selected_map["title"] || "Unknown Beatmap"
    difficulty_name = selected_map["difficulty_name"] || "Unknown Difficulty"
    difficulty_rating = selected_map["difficulty"] || "N/A"
    bpm = selected_map["bpm"] || "N/A"
    beatmap_url = selected_map["url"]
    beatmapset_id = selected_map["beatmapset_id"]
  
    event.channel.send_embed do |embed|
      embed.title = "Vous conviendras-t-elle ?"
      embed.description = "Ma perfection me permet de vous annoncer que vous devriez télécharger cette beatmap.\n#{beatmap_url}\n\n"\
                          "**Titre**: #{beatmap_title}\n**Difficulté**: #{difficulty_name}\n**Star Rating**: #{difficulty_rating}\n"\
                          "**BPM**: #{bpm}\n**Beatmap ID**: #{beatmap_id}"
      embed.color = 0x3498db
      embed.timestamp = Time.now
      embed.author = Discordrb::Webhooks::EmbedAuthor.new(
        name: "Osu",
        url: "https://osu.ppy.sh/",
        icon_url: "https://cdn.discordapp.com/attachments/1236241484857212938/1343995476487438336/pngkit_weeaboo-png_3451155.png"
      )
      if beatmapset_id
        embed.image = Discordrb::Webhooks::EmbedImage.new(
          url: "https://assets.ppy.sh/beatmaps/#{beatmapset_id}/covers/cover.jpg"
        )
      end
      embed.footer = Discordrb::Webhooks::EmbedFooter.new(
        text: "Signé,\nMiyo."
      )
      embed.add_field(name: "Buy me a coffee ☕", value: "[Merci !](https://fr.tipeee.com/miyo-bot-discord/)", inline: true)
    end
  end
end

##############################
# Two truth one lie
##############################
games = {}
bot.application_command(:twotruthsonelie) do |event|
  host_id     = event.user.id.to_s
  guesser_id  = event.options['adversaire'].to_s
  channel_id  = event.channel.id

  if games.key?(guesser_id) || games.key?(host_id)
    event.respond(content: "Toi ou ton adversaire êtes déjà dans une partie pourquoi multiplier les échecs ?", ephemeral: true)
    next
  end

  statements      = [event.options['truth1'], event.options['truth2'], event.options['lie']].shuffle
  correct_index   = statements.index(event.options['lie']) + 1

  games[guesser_id] = {
    host_id:       host_id,
    statements:    statements,
    correct:       correct_index,
    channel_id:    channel_id,
    state:         :waiting_confirmation
  }

  event.respond(content: "En attente de <@#{guesser_id}>. Enfin bon, je ne pense pas qu'il osera, les bêlitres restent des bêlitres après tout...")
  bot.send_message(channel_id,
    "Enfin bon<@#{guesser_id}>, acceptes-tu de jouer à Two Truths One Lie avec <@#{host_id}> ? Réponds simplement `yes` ou `no`.")
end

bot.message do |event|
  key = event.user.id.to_s
  game = games[key]
  next unless game && game[:state] == :waiting_confirmation

  content = event.message.content.downcase.strip

  if content.start_with?('yes')
    # confirmation acceptée
    game[:state] = :awaiting_guess
    # suite du code ...
    stmt = game[:statements]
    bot.send_message(
      game[:channel_id],
      "<@#{key}>, voici les affirmations, à vous de débusquer laquelle est fausse (enfin, si vous le pouvez):\n" \
      "1️⃣ #{stmt[0]}\n" \
      "2️⃣ #{stmt[1]}\n" \
      "3️⃣ #{stmt[2]}\n" \
      "Répondez simplement par `1`, `2` ou `3`."
    )
  elsif content.start_with?('no')
    # refus
    bot.send_message(game[:channel_id], "<@#{key}> n'a donc pas accepté le défi, quel indignité.")
    games.delete(key)
  end
end


bot.message(content: /^[123]$/, in: nil) do |event|
  key = event.user.id.to_s
  game = games[key]
  next unless game && game[:state] == :awaiting_guess

  choice = event.message.content.to_i
  channel = game[:channel_id]

  if choice == game[:correct]
    bot.send_message(channel, "Aussi surprenant que celà puisse paraître, <@#{key}> à bien découvert quel étais le mensonge. Bien joué, j'imagine.")
  else
    bot.send_message(channel,
      "Bien tenté <@#{key}>, mais votre incompétence a résulté en la perte de cette bataille. Le mensonge était la ##{game[:correct]}. Je ne vous conseille pas de devenir détective ; c'étais chose aisé.")
  end
  games.delete(key)
end

##############################
# Old commands, works for everyone
##############################

bot.command :osu, aliases: [:rs] do |event, username|
  token = get_osu_token
  accounts = load_osu_accounts
  registered_username = accounts[event.user.id.to_s]

  if username.nil? || username.empty?
    if registered_username.nil?
      event.respond "Avant de vouloir voir le score le plus récent, il faudrait soit enregistrer votre nom de compte (!osulink votre_nom_de_compte) ou en ajouter un à la fin de votre commande."
      next
    else
      username = registered_username
    end
  end

  score = get_osu_user_recent_score(username, token)

  if score
    beatmap_title     = score.dig('beatmapset', 'title') || 'Unknown Beatmap'
    beatmap_id        = score.dig('beatmap', 'id') || '#'
    mapset_id         = score.dig('beatmapset', 'id')
    difficulty_rating = score.dig('beatmap', 'difficulty_rating') || 'N/A'
    bpm               = score.dig('beatmap', 'bpm') || 'N/A'
    difficulty_name   = score.dig('beatmap', 'version') || 'Unknown Difficulty'
    rank              = score['rank']
    accuracy          = score['accuracy']
    modifiers         = score['mods'] || []

    count_300  = score.dig('statistics', 'count_300') || 0
    count_100  = score.dig('statistics', 'count_100') || 0
    count_50   = score.dig('statistics', 'count_50') || 0
    count_miss = score.dig('statistics', 'count_miss') || 0
    pp_value   = score['pp'] || 'N/A'

    rank_emojis = {
      'SS' => '<:Perfect:1335666845017178243>', 
      'S'  => '<:FullCombo:1335665676714770515>', 
      'A'  => '<:PassA:1335665721774051519>', 
      'B'  => '<:PassB:1335665702203555901>', 
      'C'  => '<:PassC:1335665688572071987>', 
      'D'  => '<:PassD:1346136133016354847>', 
      'F'  => '<:Fail:1335665081547227136>'
    }

    if accuracy == 1.0
      rank = (modifiers.include?('HD') || modifiers.include?('FL')) ? '<:Perfect:1335666845017178243>' : 'SS'
    end

    rank_display = rank_emojis[rank] || rank

    event.channel.send_embed do |embed|
      embed.title = "**Score le plus récent de #{username}:**"
      embed.description = "▸ **Beatmap:** [#{beatmap_title}](https://osu.ppy.sh/b/#{beatmap_id}) (#{difficulty_name}) (#{difficulty_rating}★) (BPM: #{bpm})\n" \
                          "▸ **Score:** #{score['score']}\n" \
                          "▸ **Accuracy:** #{(accuracy * 100).round(2)}%\n" \
                          "▸ **Rank:** #{rank_display}\n" \
                          "▸ **PP:** #{pp_value.nil? ? 'N/A' : '%.2f' % pp_value.to_f}\n" \
                          "▸ **300s:** #{count_300} | **100s:** #{count_100} | **50s:** #{count_50} | **Misses:** #{count_miss}\n" \
                          "*Game Mode: #{score['mode']}*"
      embed.color = 0x3498db
      embed.timestamp = Time.now

      user_data = get_osu_user(username, token)
      if user_data
        embed.author = Discordrb::Webhooks::EmbedAuthor.new(
          name: user_data['username'],
          url: "https://osu.ppy.sh/users/#{user_data['id']}",
          icon_url: "https://a.ppy.sh/#{user_data['id']}"
        )
      end

      if mapset_id
        embed.add_field(
          name: "Beatmap Info",
          value: "[#{beatmap_title}](https://osu.ppy.sh/beatmapsets/#{mapset_id}) (#{difficulty_name})",
          inline: true
        )
        embed.image = Discordrb::Webhooks::EmbedImage.new(
          url: "https://assets.ppy.sh/beatmaps/#{mapset_id}/covers/cover.jpg"
        )
      end
    end
  else
    event.respond "J'ai remué ciel, terre et mer, mais je n'ai pas trouvé de score récent pour **#{username}**. Êtes-vous sûr que ce joueur a joué récemment ? C'est le seul travail que je vous demande, et vous n'y arrivez même pas."
  end
end

bot.message(start_with: '!kiss') do |event|
  mentioned_users = event.message.mentions
  if mentioned_users.empty?
    event.respond "Le principe d'embrasser quelqu'un est au moins d'avoir quelqu'un à qui faire un bisous, veuillez l'indiquer. Mais bon, je peux comprendre que vous n'avez personne à embrasser, au vu votre hygiène corporel des plus... Exotiques. Plus vite, je n'ai que faire des personnes inférieures."
  elsif mentioned_users.first.id == event.user.id
    event.respond "Il est fort triste d'apprendre que vous vous sentiez tellement seul que vous vous embrassiez vous même. Toutefois, je ne suis point psychologue."
  else
    mentioned_user = mentioned_users.first
    x = rand(1..4)
    case x  
    when 1 then bot.send_message(event.channel.id, "#{mentioned_user.mention} a été embrassé par #{event.user.mention}. [Même les esprits les plus... Spéciaux peuvent avoir leurs moment j'imagine](https://media.tenor.com/8ZSbH0w9G30AAAAM/gift.gif)")
    when 2 then bot.send_message(event.channel.id, "#{mentioned_user.mention} a été embrassé par #{event.user.mention}. [Même les esprits les plus... Spéciaux peuvent avoir leurs moment j'imagine](https://media.tenor.com/7T1cuiOtJvQAAAAM/anime-kiss.gif)")
    when 3 then bot.send_message(event.channel.id, "#{mentioned_user.mention} a été embrassé par #{event.user.mention}. [Même les esprits les plus... Spéciaux peuvent avoir leurs moment j'imagine](https://media.tenor.com/hXRnV3eq7KUAAAAM/alluka-cute.gif)")
    when 4 then bot.send_message(event.channel.id, "#{mentioned_user.mention} a été embrassé par #{event.user.mention}. [Même les esprits les plus... Spéciaux peuvent avoir leurs moment j'imagine](https://media.tenor.com/zIU_JbsnMQ8AAAAM/zatch-bell-golden-gash.gif)")
    else
      bot.send_message(event.channel.id, "Something went wrong. Please try again.")
    end
  end
end

bot.message(start_with: '!punch') do |event|
  mentioned_users = event.message.mentions
  if mentioned_users.empty?
    event.respond "Le principe de frapper quelqu'un est au moins d'avoir un opposant, veuillez l'indiquer. Plus vite, je n'ai que faire des personnes inférieures."
  elsif mentioned_users.first.id == event.user.id
    event.respond "Blud veux se faire du mal tout seul."
  else
    mentioned_user = mentioned_users.first
    x = rand(1..4)
    case x  
    when 1 then event.respond("Eh bien, que de passe temps en cette contrée, étonnament, #{mentioned_user.mention} a été frappé par #{event.user.mention}. Un acte que seul des personnes inférieur peuvent s'abaisser à faire. [Mais, celà est fort divertissant, il faut l'avouer. Continuez, je vous en pris.](https://media1.tenor.com/m/BoYBoopIkBcAAAAd/anime-smash.gif)")
    when 2 then event.respond("Eh bien, que de passe temps en cette contrée, étonnament, #{mentioned_user.mention} a été frappé par #{event.user.mention}. Un acte que seul des personnes inférieur peuvent s'abaisser à faire. [Mais, celà est fort divertissant, il faut l'avouer. Continuez, je vous en pris.](https://media1.tenor.com/m/54vXJe6Jj3kAAAAC/spy-family-spy-x-family.gif)")
    when 3 then event.respond("Eh bien, que de passe temps en cette contrée, étonnament, #{mentioned_user.mention} a été frappé par #{event.user.mention}. Un acte que seul des personnes inférieur peuvent s'abaisser à faire. [Mais, celà est fort divertissant, il faut l'avouer. Continuez, je vous en pris.](https://media1.tenor.com/m/lWmjgII6fcgAAAAd/saki-saki-mukai-naoya.gif)")
    when 4 then event.respond("Eh bien, que de passe temps en cette contrée, étonnament, #{mentioned_user.mention} a été frappé par #{event.user.mention}. Un acte que seul des personnes inférieur peuvent s'abaisser à faire. [Mais, celà est fort divertissant, il faut l'avouer. Continuez, je vous en pris.](https://c.tenor.com/0ssFlowQEUQAAAAC/tenor.gif)")
    else 
      event.respond("Something went wrong. Please try again.")
    end
  end
end


bot.message(start_with: '!hug') do |event|
  mentioned_users = event.message.mentions
  if mentioned_users.empty?
    event.respond "Le principe de faire un câlin quelqu'un est au moins d'avoir quelqu'un à qui faire le câlin, veuillez l'indiquer. Mais bon, je peux comprendre que vous n'avez personne à embrasser, au vu votre hygiène corporel des plus... Exotiques. Plus vite, je n'ai que faire des personnes inférieures."
  elsif mentioned_users.first.id == event.user.id
    event.respond "Il est fort triste d'apprendre que vous vous sentiez tellement seul que vous vous câliniez vous même. Toutefois, je ne suis point psychologue."
  else
    mentioned_user = mentioned_users.first
    x = rand(1..4)
    case x  
    when 1 then event.respond("#{mentioned_user.mention} à été câliné par #{event.user.mention}! [Même les esprits les plus... Spéciaux peuvent avoir leurs moment j'imagine](https://media.tenor.com/Qw4m3inaSZYAAAAM/crying-anime-kyoukai-no-kanata-hug.gif)!")
    when 2 then event.respond("#{mentioned_user.mention} à été câliné par #{event.user.mention}! [Même les esprits les plus... Spéciaux peuvent avoir leurs moment j'imagine](https://media.tenor.com/gqM9rl1GKu8AAAAM/kitsune-upload-hug.gif)!")
    when 3 then event.respond("#{mentioned_user.mention} à été câliné par #{event.user.mention}! [Même les esprits les plus... Spéciaux peuvent avoir leurs moment j'imagine](https://media.tenor.com/H0I1CvCsLWcAAAAM/abasho.gif)!")
    when 4 then event.respond("#{mentioned_user.mention} à été câliné par #{event.user.mention}! [Même les esprits les plus... Spéciaux peuvent avoir leurs moment j'imagine](https://media.tenor.com/wGbmNu-xwCsAAAAM/hug-anime.gif)!")
    else 
      event.respond("Something went wrong. Please try again.")
    end
  end
end

bot.message(start_with: '!trigger') do |event|
  x = rand(1..4)
  case x
  when 1 then event.respond("#{event.user.mention} est énervé. [Une émotions des plus pitoyable, ne trouvez-vous pas ?](https://media.tenor.com/7Xu-od5b5QAAAAAM/king-crimson-triggered.gif)")
  when 2 then event.respond("#{event.user.mention} est énervé. [Une émotions des plus pitoyable, ne trouvez-vous pas ?](https://media.tenor.com/K5F2zlu7hNkAAAAM/triggered-anime.gif)")
  when 3 then event.respond("#{event.user.mention} est énervé. [Une émotions des plus pitoyable, ne trouvez-vous pas ?](https://media.tenor.com/nHtdolZtx-8AAAAM/triggered.gif)")
  when 4 then event.respond("#{event.user.mention} est énervé. [Une émotions des plus pitoyable, ne trouvez-vous pas ?](https://media.tenor.com/nbOhbxXPiWMAAAAM/triggered-anime.gif)")
  else 
    event.respond("Something went wrong. Please try again.")
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

################################################################
# Other, works automatically or there's no command to trigger it
################################################################

bot.message do |event|
  if event.user.bot_account? && event.message.content.include?(thread_messages)
    begin
      event.message.delete
      puts "Message supp"
    rescue => e
      puts "erreur lors de la suppression du message"
    end
  end
  next unless event.server 
  user_id = event.user.id
  content = event.message.content.downcase
  user = event.server.member(user_id)
  next unless user  

  is_admin = user.roles.any? { |role| role.permissions.administrator }
  is_excluded = EXCLUDED_USERS.include?(user_id)
  next if is_admin || is_excluded

  contains_forbidden_link = FORBIDDEN_LINKS.any? { |link| content.include?(link) }
  
  if contains_forbidden_link
    event.message.delete
    event.respond "Essayez de devinez qui a envoyé un lien des plus immondes... Il s'agit de #{user.mention} ! Répugnant !"
    mutex.synchronize do
      mute_tracker[user_id] += 1
    end
    roles_with_send_permission = user.roles.reject { |role| role.managed || role.id == event.server.everyone_role.id }
    roles_with_send_permission.each { |role| user.remove_role(role) }
    event.respond "<@#{user_id}> has been muted for #{PORN_LINK_DETECTED / 60} minutes!"

    mute_cooldown[user_id] = Time.now  
    Thread.new do
      sleep(PORN_LINK_DETECTED)
      roles_with_send_permission.each { |role| user.add_role(role) }
      event.respond "<@#{user_id}> is now unmuted."
    end
  end
end

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

#Feur (you don't need that if you're english, but if you're french...)
bot.message do |event|
  if event.message.content.end_with?('quoi', 'quoi ?', 'quoi?', 'Quoi', 'Quoi?', 'Quoi ?', 'Kwa', 'Kwa ?', 'kwa ?', 'kwa', 'QUOI ?', 'QUOI')
    FEUR(event)
  end
end

# Cooldown for greetings (3h)
bot.message do |event|
  server_id = event.server.id
  current_time = Time.now.to_i
  if cooldowns[server_id].nil? || (current_time - cooldowns[server_id]) >= COOLDOWN_TIME
    greetings.each do |word, response|
      if event.content.downcase.include?(word)
        bot.send_message(event.channel.id, response)
        cooldowns[server_id] = current_time
        break
      end
    end
  end
end

# Auto mute
history      = {}
muted_roles  = {}

bot.message do |event|
  next if event.server.nil? || event.user.bot_account?

  msg        = event.message
  channel_id = event.channel.id
  message_id = msg.id
  if msg.content.empty? && msg.attachments.empty?
    raw = Discordrb::API::Channel.message(bot.token, channel_id, message_id)
    data = JSON.parse(raw) rescue {}
    if data['sticker_items'].is_a?(Array) && data['sticker_items'].any?
      next
    end
  end

  server_id = event.server.id
  user_id   = event.user.id

  history[server_id]      ||= {}
  history[server_id][user_id] ||= []
  history[server_id][user_id] << msg
  history[server_id][user_id].shift if history[server_id][user_id].size > 3

  if history[server_id][user_id].size == 3
    msgs     = history[server_id][user_id]
    contents = msgs.map(&:content)

    next if contents.all? { |c| c.start_with?('!') || c.downcase == 'kd' || c.downcase == 'cat' || c.start_with?('$')}

    next if contents.all?(&:empty?)

    if contents.uniq.length == 1
      member = event.user

      excluded = EXCLUDED_USERS.include?(member.id) ||
                 member.roles.any? { |r| r.permissions.administrator }
      next if excluded

      msgs.each do |m|
        begin
          m.delete unless m.content.empty?
        rescue Discordrb::Errors::UnknownMessage
        end
      end

      event.channel.send_message(
        "<@#{member.id}>, vous ne faites que vous répéter. " \
        "Votre sentence : 10 minutes de calme. " \
        "Vous avez envoyé plusieurs fois le même message, vous êtes d'un ennuie... " \
        "Si il s'agit d'un lien et que vous y avez encore accès, ne cliquez pas dessus, merci."
      )

      roles_to_remove = member.roles.select do |role|
        next false if role.id == server_id
        perms = role.permissions
        next false if perms.administrator   ||
                      perms.manage_roles    ||
                      perms.manage_server   ||
                      perms.kick_members    ||
                      perms.ban_members     ||
                      perms.manage_messages ||
                      perms.manage_channels
        perms.send_messages
      end

      roles_to_remove.each { |r| member.remove_role(r) }
      muted_roles[server_id] ||= {}
      muted_roles[server_id][user_id] = roles_to_remove

      Thread.new do
        sleep 600
        roles_to_remove.each { |r| member.add_role(r) }
        muted_roles[server_id]&.delete(user_id)
      end
    end
  end
end


bot.member_join do |event|
  settings = load_starboard_settings
  server_id_str = event.server.id.to_s
  settings[server_id_str] ||= {}
  settings[server_id_str]['autoban_system'] ||= {
    "active" => false,
    "autoban_enabled" => false,
    "log_channel_id" => nil
  }
  settings[server_id_str]['welcome_system'] ||= {
    "active" => false,
    "welcome_channel_id" => nil
  }

  save_starboard_settings(settings)

  autoban_coucou = settings[server_id_str]['autoban_system']
  autoban_active = autoban_coucou['active']

  if autoban_active == true || autoban_active.to_s == 'true'
    banned_users = load_banned_users
    user_id_str = event.user.id.to_s

    if banned_users.key?(user_id_str)
      user = event.user
      reason = banned_users[user_id_str]['reason'] || 'Aucune raison précisée'

      begin
        event.server.ban(user, reason: "Autoban : inscrit dans la liste noire - Raison: #{reason}")
        puts "Utilisateur #{user.distinct} banni automatiquement à l’arrivée dans #{event.server.name}."

        log_channel_id = autoban_coucou["log_channel_id"]
        if log_channel_id
          log_channel = bot.channel(log_channel_id)
          if log_channel && log_channel.server.id == event.server.id && log_channel.type == 0
            log_channel.send_message("🚫 **#{user.distinct}** a été banni automatiquement à l’arrivée.\n> **Raison** : #{reason}")
          else
            puts "Salon de log non trouvé ou invalide pour le serveur #{event.server.name} (ID: #{log_channel_id})."
          end
        end
      rescue StandardError => e
        puts "Erreur lors du bannissement automatique : #{e.message}"
      end
    end
  else
    puts "Autoban inactif ou désactivé pour #{event.server.name}."
  end

  welcome_settings = settings[server_id_str]['welcome_system']
  if welcome_settings['active']
    target_channel = event.server.text_channels.find { |c| c.id == welcome_settings['welcome_channel_id'] }
    if target_channel
      sleep 5
      mention = "<@#{event.user.id}>"
      welcome_text = WELCOME_MESSAGES.sample.gsub("{user}", mention).gsub("{server}", event.server.name)
      gif = WELCOME_GIFS.sample
      allowed = Discordrb::AllowedMentions.new(users: [event.user.id])
      target_channel.send_message("#{welcome_text}\n#{gif}", false, nil, nil, allowed)
    end
  end
end

bot.message do |event|
  content = event.message.content
  if content.start_with?(PREFIX)
    next if content == "#{PREFIX}stats"
    command_word = content[PREFIX.length..-1].split.first
    if COMMANDS.include?(command_word)
      command_usage[command_word] += 1
    end
  end
  nil
end

###################
# Secret commands
###################

bot.message(start_with: '!museau') do |event|
  event.message.delete

  lat = rand(-90.0..90.0).round(6)
  lng = rand(-180.0..180.0).round(6)

  google_map_link = "https://www.google.com/maps?q=#{lat},#{lng}"
  preview_url = "https://staticmap.openstreetmap.de/staticmap.php?center=#{lat},#{lng}&zoom=15&size=600x300&markers=#{lat},#{lng},red-pushpin"

  embed = Discordrb::Webhooks::Embed.new(
    title: "Une commande secrète a été trouvée !",
    description: "Voici où est actuellement Museau. Bien que je ne puisse décrire exactement l'endroit, il se trouve sûrement dans une contrée éloignée pour se ressourcer.",
    url: google_map_link,
    color: 0x3498db,
    timestamp: Time.now
  )
  
  embed.add_field(name: "Coordonnées", value: "#{lat}, #{lng}", inline: true)
  embed.image = Discordrb::Webhooks::EmbedImage.new(url: preview_url)
  
  event.respond('', false, embed)
end

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


######################
#Test
######################



#OUAIIIIS LE BOT IL EST ENCORE VIVANT YOUHOU
Signal.trap('INT') do
  bot.stop
end

Signal.trap('TERM') do
  bot.stop
end

bot.ready do
  puts 'Le bot est en ligne !'

  Thread.new { change_activity(bot, activities) }

  Thread.new do
    loop do
      mutex.synchronize do
        mute_tracker.each { |user, count| mute_tracker[user] -= 1 if count > 0 }
      end
      sleep(5)  
    end
  end

  Thread.new do
    loop do
      check_banned_users(bot)
      sleep 30
    end
  end
  load_enabled_categories
  sleep(3)
end


bot.run

uptime_end = Time.now
filename = "#{uptime_end.strftime('%Y-%m-%d_%H-%M-%S')}.txt"
logs_dir = 'logs'
FileUtils.mkdir_p(logs_dir)

filepath = File.join(logs_dir, filename)
File.open(filepath, "w") do |file|
  file.puts "#{uptime_start.strftime('%d/%m/%Y %H:%M:%S')} to #{uptime_end.strftime('%d/%m/%Y %H:%M:%S')}"
  file.puts

  COMMANDS.each do |cmd|
    file.puts "#{PREFIX}#{cmd} : used #{command_usage[cmd]} times"
    file.puts
  end
end



puts "\nBot stats saved to #{filepath}. Bye!"
