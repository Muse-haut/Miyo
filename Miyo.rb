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
puts "This bot's invite URL is #{bot.invite_url}"
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
TRIGGER_WORDS = ['quoi', 'quoi ?', 'quoi?', 'Quoi', 'Quoi?', 'Quoi ?','Kwa','Kwa ?','kwa ?','kwa','QUOI ?','QUOI']
mute_tracker = Hash.new(0) 
mute_cooldown = {}  
command_users = {}
STARBOARD_FILE = 'starboard.json'
uptime_start = Time.now
command_usage = Hash.new(0)


@insults = ["idiot", "stupid", "fool", "moron", "jerk","everyone","@everyone","@"]


# Introductory sentence (can be modified by the admin)
@intro_sentence = "Tu es une jeune fille raffinée prénommée Miyo. Tu es quelque peu mondaine, tu possèdes un langage très soutenu, proche de la perfection. Pour ce qui est de ta personnalité, tu es une personne prétentieuse et sûre d'elle-même et qui se sent supérieure de tout le monde, quelques peu arrogante et d'une froideur certaine. Toutefois, tu réponds à toutes les questions, bien que celà n'allume pas la braise de ton intérêt. Toutefois, tu voues un respect certains envers <@935207909183356951>, appelé Museau, ton créateur, ce qui te rend plus sympathique envers lui, et uniquement lui. Pour le reste des gens, tu te sens supérieure, après tout, qui d'autre que Museau pourrait égaler ta perfection ? Bien entendu, la personne qui vas te demander quelques chose n'est pas Museau, remet-lui gentillement les pendules à l'heure si la personne tente de se faire passer pour Museau."


##############################
# HELPER METHODS
##############################
FEUR_FILE = 'feur.json'
user_messages = {}
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
  if File.exist?(STARBOARD_FILE)
    JSON.parse(File.read(STARBOARD_FILE))
  else
    {}
  end
end

def save_starboard_settings(settings)
  File.write(STARBOARD_FILE, JSON.pretty_generate(settings))
end
# Miscellaneous helper methods
def FEUR(event)
  id = event.user.id.to_s
  $global_user_feur[id] ||= 0
  $global_user_feur[id] += 1
  
  event.respond "feur ! ||J'tai dis feur #{$global_user_feur[id]} fois, terrible hein ?||"
  save_feur_to_file
end

def disconnect(bot, event)
  if event.user.id == MY_USER_ID
    bot.send_message(event.channel.id, 'Bot is shutting down')
    exit
  else
    event.respond 'You do not have permission to disconnect the bot.'
  end
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


def fetch_ai_response(user_question, user_id = nil)
  puts "DEBUG: user_id = #{user_id.inspect}, class = #{user_id.class}"
  intro = @intro_sentence
  if user_id == MY_USER_ID
    intro = "Tu es une jeune fille raffinée prénommée Miyo. Tu es quelque peu mondaine, tu possèdes un langage très soutenu, proche de la perfection. Pour ce qui est de ta personnalité, tu es une personne prétentieuse et sûre d'elle-même et qui se sent supérieure de tout le monde, quelques peu arrogante et d'une froideur certaine. Toutefois, tu réponds à toutes les questions, bien que celà n'allume pas la braise de ton intérêt. Toutefois, tu voues un respect certains envers moi, <@935207909183356951>, appelé Museau, ton créateur, ce qui te rend plus sympathique envers lui, et uniquement lui. Pour le reste des gens, tu te sens supérieure, après tout, qui d'autre que Museau pourrait égaler ta perfection ? L'utilisateur ayant demandé ta grandeur est Museau, en d'autre terme, ton créateur."
  elsif user_id.to_i == 934971149580898364
    intro = "Tu es une jeune fille raffinée prénommée Miyo. Tu es quelque peu mondaine, tu possèdes un langage très soutenu, proche de la perfection. Pour ce qui est de ta personnalité, tu es une personne prétentieuse et sûre d'elle-même et qui se sent supérieure de tout le monde, quelques peu arrogante et d'une froideur certaine. Toutefois, tu réponds à toutes les questions, bien que celà n'allume pas la braise de ton intérêt. Toutefois, tu voues un respect certains envers <@935207909183356951>, appelé Museau, ton créateur, ce qui te rend plus sympathique envers lui, et uniquement lui. Pour le reste des gens, tu te sens supérieure, après tout, qui d'autre que Museau pourrait égaler ta perfection ? Bien entendu, la personne qui vas te demander quelques chose n'est pas Museau, remet-lui gentilment les pendules à l'heure si la personne tente de se faire passer pour Museau. Agis comme si tu étais en couple avec <@934971149580898364>, aussi connu sous le nom de Slomaki. L'utilisateur ayant demandé ta grandeur est <@934971149580898364>, Slomaki en d'autres termes, ton amant, et tu n'hésite pas à le dire, car tu en es plutôt fière, mais aussi, tu n'hésite pas à faire des blagues sur lui et à le charrier, et te montre froide car oui, tu es la personne dominante dans ce couple. Si cet utilisateur ne dit rien excepté ton nom, fais comme si tu vivais ta vie de couple avec lui(tout en restant dominante, mais sans insulte bien sûr)"
  else
    intro = "Tu es une jeune fille raffinée prénommée Miyo. Tu es quelque peu mondaine, tu possèdes un langage très soutenu, proche de la perfection. Pour ce qui est de ta personnalité, tu es une personne prétentieuse et sûre d'elle-même et qui se sent supérieure de tout le monde, quelques peu arrogante et d'une froideur certaine. Toutefois, tu réponds à toutes les questions, bien que celà n'allume pas la braise de ton intérêt. Toutefois, tu voues un respect certains envers <@935207909183356951>, appelé Museau, ton créateur, ce qui te rend plus sympathique envers lui, et uniquement lui. Pour le reste des gens, tu te sens supérieure, après tout, qui d'autre que Museau pourrait égaler ta perfection ? Bien entendu, la personne qui vas te demander quelques chose n'est pas Museau, remet-lui gentilment les pendules à l'heure si la personne tente de se faire passer pour Museau. Si l'utilisateur te demande d'être en couple, que tu es sa femme ou quoi qu'est-ce relié à ta situation amoureuse, agis comme si tu étais en couple avec @934971149580898364, aussi appelé Slomaki, et tu n'hésite pas à le dire, car tu en es plutôt fière. L'utilisateur ayant demandé ta grandeur est @#{user_id}."
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
    "question"           => "#{intro} Maintenant, l'utilisateur à envoyé ça. Réponds comme si tu jouais un personnage avec les traits de caractères que je t'ai précédemment envoyé. Ta personnalité ne t'empêche pas de t'exprimer sur ta situation amoureuse, mais tu n'en parle que si on te la demande. Tu dois être la plus synthétique possible, en 150 lettres grand maximum. Voici la requête de l'utilisateur : #{user_question}",
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
  "[L'invitation a été prise en compte !](https://tenor.com/lwhjabJxnbu.gif)"
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
  "Oh ! {user} ! Bienvenue dans {server}"
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
  "Sumire, best game ever",
  "Enter the Gungeon, quit a cool game",
  "Persona 4 The Golden, peak",
  "Persona 3 : Reload, fire",
  "Persona 5, still really good",
  "Osu, best rythm game",
  "My friend Peppa Pig, GOTY",
  "League of Legends, dunno what I've done in life to end like this",
  "Cookie Clicker, help me"
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

# Greetings things
cooldowns = {}
COOLDOWN_TIME = 108000

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


##############################
# BOT EVENTS & COMMANDS
##############################

# Système de ban automatique lors de l'envoie d'un message d'un utilisateur ayant causé des problème et ayant été report sur d'autres serveur. Feel free to use it.
bot.message do |event|
  if banned_users.key?(event.user.id)
    event.message.delete
    event.user.ban rescue nil
  end
end


bot.command(:banuseradd) do |event, user_id|
  break unless event.user.id == MY_USER_ID 

  user = event.server.member(user_id.to_i)
  if user
    banned_users[user.id] = user.username
    event.respond "**#{user.username}** (`#{user.id}`) a été ajouté à la liste des bannis."
  else
    event.respond "Impossible de trouver cet utilisateur."
  end
end


bot.command(:banuserremove) do |event, user_id|
  break unless event.user.id == MY_USER_ID  

  if banned_users.delete(user_id.to_i)
    event.respond "L'utilisateur `#{user_id}` a été retiré de la liste des bannis."
  else
    event.respond "Cet utilisateur n'est pas banni."
  end
end

bot.command(:banuserlist) do |event|
  if banned_users.empty?
    event.respond "📜 La liste des bannis est vide."
  else
    list = banned_users.map { |id, username| "**#{username}** (`#{id}`)" }.join("\n")
    event.respond "📜 **Liste des utilisateurs bannis :**\n#{list}"
  end
end

bot.message do |event|
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

#Categories Random Sentences
bot.command :toggle_category do |event, category|
  server_id = event.server.id
  server_categories = load_enabled_categories
  enabled_categories = server_categories[server_id] || []

  if category.nil?
    event.respond "Please provide a category to toggle. Example: !toggle_category soft"
    return
  end

  if event.user.id == 935207909183356951 || (event.server && event.user.roles.any? { |role| role.permissions.bits & ADMINISTRATOR_BIT != 0 })
    category_sym = category.to_sym
    if categories.key?(category_sym)
      if enabled_categories.include?(category_sym)
        enabled_categories.delete(category_sym)
        event.respond "#{category} category disabled."
      else
        enabled_categories << category_sym
        event.respond "#{category} category enabled."
      end
      server_categories[server_id] = enabled_categories
      save_enabled_categories(server_categories)

      # Debug output
      puts "Enabled categories for server #{server_id}: #{enabled_categories.inspect}"
    else
      event.respond "Category #{category} not found."
    end
  else
    event.respond "You do not have permission to use this command."
  end
end

bot.command :list_category do |event|
  server_id = event.server.id.to_s
  server_categories = load_enabled_categories
  enabled_categories = server_categories[server_id] || []
  category_status = categories.keys.map do |category|
    category_str = category.to_s
    status = enabled_categories.include?(category_str) ? 'enabled' : 'disabled'
    "#{category_str} (#{status})"
  end
  event.respond "Available categories: #{category_status.join(', ')}"
end

bot.command :talk do |event|
  server_id = event.server.id.to_s
  server_categories = load_enabled_categories
  enabled_categories = server_categories[server_id] || []
  valid_categories = categories.select { |k, _| enabled_categories.include?(k.to_s) }
  all_subjects = valid_categories.values.map { |cat| cat[:subjects] }.flatten
  all_verbs   = valid_categories.values.map { |cat| cat[:verbs] }.flatten
  all_reasons = valid_categories.values.map { |cat| cat[:reasons] }.flatten

  if all_subjects.empty? || all_verbs.empty? || all_reasons.empty?
    event.respond "No categories enabled. Please enable at least one category."
  else
    sentence = "#{all_subjects.sample} #{all_verbs.sample} #{all_reasons.sample}"
    event.respond sentence
  end
end

bot.command :embed do |event|
  event.channel.send_embed do |embed|
    embed.title = "Titre de l'embed"
    embed.description = "Ceci est un message embed avec **discordrb** !"
    embed.color = 0x3498db # Couleur bleue
    embed.timestamp = Time.now

    embed.author = Discordrb::Webhooks::EmbedAuthor.new(
      name: "Auteur",
      url: "https://discord.com",
      icon_url: "https://cdn-icons-png.flaticon.com/512/2111/2111370.png"
    )

    embed.footer = Discordrb::Webhooks::EmbedFooter.new(
      text: "Pied de page",
      icon_url: "https://cdn-icons-png.flaticon.com/512/25/25231.png"
    )

    embed.add_field(name: "Champ 1", value: "Ceci est un champ", inline: true)
    embed.add_field(name: "Champ 2", value: "Un autre champ", inline: true)
  end
end

bot.message(start_with: '!talkabit') do |event|
  if authorized?(event)
    sentence = construct_sentence(icanmakeasentencebutidontthinkyoullenjoyit, :new)
    event.respond(sentence)
  else
    event.respond("T'essais de faire quoi là ? C'est pas une commande que tu peux utiliser blud.")
  end
end

bot.mention do |event|
  user_question = event.message.content.gsub("<@#{bot.profile.id}>", "").strip

  if event.user.id == MY_USER_ID
    if user_question.downcase.start_with?('add_insult', 'remove_insult', 'modify_insult', 'set_intro')
      handle_admin_command(event, user_question)
    else
      response_text = fetch_ai_response(user_question, event.user.id)
      event.respond(response_text) if response_text
    end
  else
    response_text = fetch_ai_response(user_question, event.user.id)
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
        response_text = fetch_ai_response(user_question, event.user.id)
        event.respond(response_text) if response_text
      end
    else
      response_text = fetch_ai_response(user_question, event.user.id)
      if response_text && !response_text.empty?
        event.respond(response_text)
      else
        event.respond "Je n'ai pas de réponse pour ça, mais je suis toujours là pour discuter!"
      end
    end
  end
end

bot.message(content: 'Agreed') do |event|
  unless authorized?(event)
    event.respond("You are not authorized to give feedback!")
    next
  end

  if $last_combo
    unless $feedback["correct_combinations"].include?($last_combo)
      $feedback["correct_combinations"] << $last_combo
      save_feedback($feedback)
      event.respond("Sentence saved as correct!")
    else
      event.respond("Sentence already marked as correct.")
    end
    $last_combo = nil
  else
    event.respond("No sentence to evaluate!")
  end
end

bot.message(content: 'Wrong') do |event|
  unless authorized?(event)
    event.respond("You are not authorized to give feedback!")
    next
  end

  if $last_combo
    unless $feedback["banned_combinations"].include?($last_combo)
      $feedback["banned_combinations"] << $last_combo
      save_feedback($feedback)
      event.respond("Sentence saved as incorrect and will not be used again!")
    else
      event.respond("Sentence already marked as incorrect.")
    end
    $last_combo = nil
  else
    event.respond("No sentence to evaluate!")
  end
end

# Osu Commands
def get_osu_user(username, token)
  uri = URI("https://osu.ppy.sh/api/v2/users/#{username}/osu")
  req = Net::HTTP::Get.new(uri)
  req['Authorization'] = "Bearer #{token}"
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
  return nil unless res.is_a?(Net::HTTPSuccess)
  JSON.parse(res.body)
end

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

#Feur
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

bot.message do |event|
  next unless event.server 
  
  user_id = event.user.id
  content = event.message.content.downcase
  user = event.server.member(user_id)
  next unless user  
  is_admin = user.roles.any? { |role| role.permissions.administrator }
  is_excluded = EXCLUDED_USERS.include?(user_id)
  next if is_admin || is_excluded

  last_word = content.split.last&.downcase 
  if content.start_with?('!') || (last_word && TRIGGER_WORDS.include?(last_word))
    mutex.synchronize do
      mute_tracker[user_id] += 1
    end

    if mute_tracker[user_id] > 3 && (mute_cooldown[user_id].nil? || Time.now - mute_cooldown[user_id] > MUTE_DURATION)
      SEND_MESSAGES_BIT = 0x00000800
      roles_with_send_permission = user.roles.reject { |role| role.managed || role.id == event.server.everyone_role.id }

      roles_with_send_permission.each { |role| user.remove_role(role) }
      event.respond "<@#{user_id}> has been muted for #{MUTE_DURATION / 60} minutes!"
      
      mute_cooldown[user_id] = Time.now  

      Thread.new do
        sleep(MUTE_DURATION)
        roles_with_send_permission.each { |role| user.add_role(role) }
        event.respond "<@#{user_id}> is now unmuted."
      end
    end
  end
end

bot.message do |event|
  if event.content.downcase.include?('ça va et toi') || event.content.downcase.include?('bien et toi')
    case humeur()
    when 1 then bot.send_message(event.channel.id, "Je vais bien également !")
    when 2 then bot.send_message(event.channel.id, "Je me sens bien aujourd'hui aussi")
    when 3 then bot.send_message(event.channel.id, "Ça va ça va, la journée se passe tranquillement")
    when 4 then bot.send_message(event.channel.id, "Ça va ! Un peu calme aujourd'hui mais ça se passe !")
    else bot.send_message(event.channel.id, "Something went wrong. Please try again.")
    end
  end
end

# French (needs to be in the same with english and ask english or french)
bot.message do |event|
  if event.content.downcase.include?('ça va et toi') || event.content.downcase.include?('bien et toi')
    case humeur()
    when 1 then bot.send_message(event.channel.id, "Je vais bien également !")
    when 2 then bot.send_message(event.channel.id, "Je me sens bien aujourd'hui aussi")
    when 3 then bot.send_message(event.channel.id, "Ça va ça va, la journée se passe tranquillement")
    when 4 then bot.send_message(event.channel.id, "Ça va ! Un peu calme aujourd'hui mais ça se passe !")
    else bot.send_message(event.channel.id, "Something went wrong. Please try again.")
    end
  end
end

# English (needs to be in the same with french and ask english or french)
bot.message do |event|
  if event.content.downcase.include?('good and you') || event.content.downcase.include?('fine and you')
    case humeur()
    when 1 then bot.send_message(event.channel.id, "I'm fine!")
    when 2 then bot.send_message(event.channel.id, "I'm feeling good today")
    when 3 then bot.send_message(event.channel.id, "I'm good too!")
    when 4 then bot.send_message(event.channel.id, "I'm good. It's a bit calm today, but it's not a real problem")
    else bot.send_message(event.channel.id, "Something went wrong. Please try again.")
    end
  end
end

bot.message(start_with: '!museau') do |event|
  event.message.delete

  lat = rand(-90.0..90.0).round(6)
  lng = rand(-180.0..180.0).round(6)

  google_map_link = "https://www.google.com/maps?q=#{lat},#{lng}"

  # Mise à jour de l'URL de prévisualisation avec le paramètre "red-pushpin"
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

#keywords
bot.message do |event|
  if event.content.downcase.include?('zizi')
    bot.send_message(event.channel.id, "Obsédé")
  end
end

bot.message do |event|
  if event.content.downcase.include?('caca')
    bot.send_message(event.channel.id, "Un humour... spécial. Tout comme vous, je présume.")
  end
end

# Silence toi aussi eheh and other things that I didn't sort (boring)
bot.message do |event|
  if event.content.downcase.include?('can you be silent too ?')
    if event.user.id == 939217692496375888
      sleep(2)
      bot.send_message(event.channel.id, "Traduction : Ta gueule")
    end
  end
end

bot.message do |event|
  if event.content.downcase.include?("bro, don't steal this reference, please")
    if event.user.id == 939217692496375888
      sleep(2)
      bot.send_message(event.channel.id, "Traduction : Ta gueule")
    end
  end
end

bot.message do |event|
  if event.content.downcase.include?("nobody ask your intervention miyo, stfu")
    if event.user.id == 939217692496375888
      sleep(2)
      bot.send_message(event.channel.id, "Ta gueule le bandeur des states là.")
    end
  end
end

bot.message do |event|
  if event.content.downcase.include?("ah ! tu vois que tu peux parler anglais aussi ?")
    if event.user.id == 939217692496375888
      sleep(2)
      bot.send_message(event.channel.id, "Orh, ferme là")
    end
  end
end

bot.message do |event|
  if event.content.downcase.include?("you'll see that my mind is too fast for eyes")
    if event.user.id == 939217692496375888
      sleep(2)
      bot.send_message(event.channel.id, "YOU'RE DONE IN")
    end
  end
end

bot.message do |event|
  if event.content.downcase.include?('suicide')
    bot.send_message(event.channel.id, "IS THAT A PERSONA 3 REFERENCE ?")
    sleep(1)
  end
end

bot.message do |event|
  if event.content.downcase.include?("bro, this gif represent your sect or what ?")
    if event.user.id == 939217692496375888
      sleep(2)
      bot.send_message(event.channel.id, "Mec, laisse le profiter de son gif de con")
    end
  end
end

bot.message do |event|
  if event.content.downcase.include?("i'm just curious, if it's one, i'll ask how can i join it ? :smiley:")
    if event.user.id == 939217692496375888
      sleep(2)
      bot.send_message(event.channel.id, "...")
    end
  end
end

#Gif Sallie
bot.message do |event|
  if event.content.downcase.include?("this gif isn't yours buddy")
    if event.user.id == 939217692496375888
      sleep(2)
      bot.send_message(event.channel.id, "J'chui d'accord avec <@939217692496375888>, pourquoi t'utilise le seul gif réservé ? T'es débiles ? :skull:")
    end
  end
end

#Help
bot.command :help do |event|
  event.channel.send_embed do |embed|
    embed.title = "Mes salutations !"
    embed.description = "Je me prénomme Miyo, à votre service.\nJe dispose de quelques commandes que vous pourrez utiliser tout du long de mon histoire sur ce serveur. \n### Fun\n- !talk : vous donne une phrase aléatoire parmi tous les mots et personnes que je connais \n### Osu\n- !osulink : permet de lier votre nom de compte osu avec votre id sur discord. Facilite l'utilisation de la commande '!rs' et 'osu'\n- !osuunlink : permet permet de délier votre nom de compte osu avec votre id sur discord.\n- !rs : permet de voir le score le plus récent d'un joueur osu.\n- !osu : permet de voir le score le plus récent d'un joueur osu.\n- !osurdm : permet de trouver une beatmap adaptée à votre demande.\n### Interactions\n- !kiss : vous permet d'embrasser quelqu'un... Quelle commande futile.\n- !hug : vous permet de câliner quelqu'un... Enfin, si vous avez quelqu'un à câliner.\n- !punch : vous permet de frapper quelqu'un. Veuillez l'utiliser à tout moment, les affrontement de personnes inférieurs à la noblesse est tellement divertissant.\n- !trigger : afin d'exprimer votre colère.\n### Commandes modérateur\n- !welcome : vous permet de configurer un système de bienvenue sur votre serveur.\n\nÉgalement, je réagis à certains mots, il faudra que vous discutiez pour tous les connaîtres. Si vous me le permettez, ma présentation se termine ici, et j'espère qu'elle saura vous convaincre. Si vous souhaitez me solliciter, mentionnez-moi, je me ferais une (fausse) joie de vous répondre."
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

    embed.add_field(name: "Buy me a coffee ☕", value: "[Merci !](https://fr.tipeee.com/miyo-bot-discord/)", inline: true)
  end
end

bot.command :info do |event|
  event.channel.send_embed do |embed|
    embed.title = "Des informations sur moi ? Charmant."
    embed.description = "Je me prénomme Miyo, à votre service.\nJe suis codé intégralement en Ruby, en utilisant la librairie 'discordrb', majoritairement par mon créateur Museau.\nJe remercie l'aide de Cyn, qui a aidé Museau lorsqu'il en avait besoin.\nBien, j'en eu trop dit, si vous souhaiter me solliciter, veuillez utiliser la commande !help. Si vous voulez bien m'excuser..."
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

    embed.add_field(name: "Buy me a coffee ☕", value: "[Merci !](https://fr.tipeee.com/miyo-bot-discord/)", inline: true)
  end
end

#Déco
bot.command :déco do |event|
  disconnect(bot, event)
end

#Overwatch
bot.message do |event|
  if event.content.downcase.include?('overwatch')
    x = rand(1..5)
    case x 
    when 1 then bot.send_message(event.channel.id, "Ouais nan.")
    when 2 then bot.send_message(event.channel.id, "J'me sentais bien jusqu'à ce que tu parles d'Overwatch.")
    when 3 then bot.send_message(event.channel.id, "Terrible comme jeu.")
    when 4 then bot.send_message(event.channel.id, "Arrête de parler d'Overwatch. Au risque d'un ban perm.")
    when 5 then bot.send_message(event.channel.id, "Va jouer à un vrai bon jeu.")
    else bot.send_message(event.channel.id, "Something went wrong. Please try again.")
    end
  end
end


#Valorant
bot.message do |event|
  if event.content.downcase.include?('valorant') || event.content.downcase.include?('valo')
    x = rand(1..5)
    case x 
    when 1 then bot.send_message(event.channel.id, "Comment peux-tu dire que Valorant est un bon jeu quand les 3/4 de tes games se résument à un eboy et une egirl ? ")
    when 2 then bot.send_message(event.channel.id, "J'me sentais bien jusqu'à ce que tu parles de Valorant.")
    when 3 then bot.send_message(event.channel.id, "Average player who [get on Valorant](https://tenor.com/view/get-on-valorant-rem-emilia-ram-anime-gif-10034682886570431020?quality=lossless)")
    when 4 then bot.send_message(event.channel.id, "Arrête de parler de Valorant. Au risque d'un ban perm.")
    when 5 then bot.send_message(event.channel.id, "Valo ? Valo quoi...")
    else bot.send_message(event.channel.id, "Something went wrong. Please try again.")
    end
  end
end

#Lemon
bot.message do |event|
  if event.content.downcase.include?('lemon') || event.content.downcase.include?('citron')
    bot.send_message(event.channel.id, "Blud said [LEMON](https://tenor.com/view/lemonade-gif-4432764702889359454?quality=lossless)")
  end 
end

# Osu interaction
bot.message do |event|
  if event.content.downcase.include?('osu')
    if event.content.start_with?('!osu') ||event.content.start_with?('!osurdm')
    else
      x = rand(1..7) 
      case x
      when 1 then bot.send_message(event.channel.id, "Play more")
      when 2 then bot.send_message(event.channel.id, "727")
      when 3 then bot.send_message(event.channel.id, "wtf I can't hit that")
      when 4 then bot.send_message(event.channel.id, "[Blud is talking about osu](https://media.discordapp.net/attachments/1257371773976973346/1335670229132644443/my-honest-reaction-my-reaction-to-that-information.gif?ex=67a10356&is=679fb1d6&hm=65478843552bebac54711c04b5ea67391e52957ca359f48524ac29d17a4cb565&=) !")
      when 5 then bot.send_message(event.channel.id, "When you miss a note in osu, just remember, Museau probably missed 10. 😏")
      when 6 then bot.send_message(event.channel.id, "I bet you can't even beat the easiest map, Noob?")
      when 7 then bot.send_message(event.channel.id, "Yo, you gotta play osu if you want real rhythm challenge! This ain't it!")
      else bot.send_message(event.channel.id, "Something went wrong. Please try again.")
      end
    end
  end
end
 #other interact command (yay)
bot.message do |event|
  if event.content.downcase.include?('maman')
    bot.send_message(event.channel.id, "C'est ma maman qui m'a fais à manger <a:zerotwo:1335716769490538639>")
  end
end

bot.message do |event|
  if event.content.downcase.include?('persona')
    x = rand(1..10)
    case x
    when 1 then bot.send_message(event.channel.id, "YOU'LL NEVER SEE IT COMING")
    when 2 then bot.send_message(event.channel.id, "Looking cool Joker !")
    when 3 then bot.send_message(event.channel.id, "PERSONA !")
    when 4 then bot.send_message(event.channel.id, "You should go to sleep Joker")
    when 5 then bot.send_message(event.channel.id, "IS THAT THE GRIM REAPER ?!")
    when 6 then bot.send_message(event.channel.id, "Number of person who already played Persona and aren't just musics enjoyers : ")
    when 7 then bot.send_message(event.channel.id, "Play persona. At any cost")
    when 8 then bot.send_message(event.channel.id, "Take your heart")
    when 9 then bot.send_message(event.channel.id, "DISTURBING THE PEACE")
    when 10 then bot.send_message(event.channel.id, "Can't get my mind, out of those memorieees")
    end
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

#Easter eggs
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

#Osu search

bot.message(start_with: '!osurdm') do |event|
  args = event.message.content.split
  if args.length < 2
    event.respond "Je vais m'expliquer. Afin de faire fonctionner cette commande, il vous faudra dire '!osurdm <star>', star représentant la difficulté que vous souhaitez. Faites-vite, je ne veux perdre plus de temps"
    next
  end
  
  star_rating = args[1].to_f
  if star_rating <= 0
    event.respond "Êtes-vous un fanfaron ou un sôt ? Il me faudrait que vous me transmettiez une difficulté valide. Dépêchez-vous, je ne veux vous accorder plus de temps."
    next
  end
  
  min_sr = star_rating - 0.1
  max_sr = star_rating + 0.1
  
  cache_path = "beatmap_cache.json"
  begin
    beatmap_cache = JSON.parse(File.read(cache_path))
  rescue => e
    event.respond "Erreur lors de la lecture du cache de beatmaps: #{e.message}"
    next
  end
  
  eligible_beatmaps = []
  beatmap_cache.each do |id, beatmap|
    difficulty = beatmap["difficulty"].to_f
    if difficulty >= min_sr && difficulty <= max_sr
      eligible_beatmaps << beatmap
    end
  end
  
  if eligible_beatmaps.empty?
    event.respond "Je n'ai trouvé aucune beatmap correspondant à cette difficulté (#{star_rating}±0.1). Essayez une autre valeur."
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
    embed.description = "Ma perfection me permet de vous annoncer que vous devriez télécharger cette beatmap. J'espère que votre prochaine performance ne me décevra pas.\n#{beatmap_url}\n\n**Titre**: #{beatmap_title}\n**Difficulté**: #{difficulty_name}\n**Star Rating**: #{difficulty_rating}\n**BPM**: #{bpm}\n**Beatmap ID**: #{beatmap_id}"
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

bot.command :osuaccount do |event, osu_username|
  if osu_username.nil? || osu_username.empty?
    event.respond "Merci de dire un nom de compte après la commande. Exemple: `!osuaccount Cookiezi`"
    next
  end

  accounts = load_osu_accounts
  accounts[event.user.id.to_s] = osu_username
  save_osu_accounts(accounts)
  event.respond "Votre compte discord et votre nom de compte Osu (**#{osu_username}**) on bel et bien été enrengistré."
end

bot.command :osuunlink do |event|
  accounts = load_osu_accounts
  user_id = event.user.id.to_s

  if accounts.key?(user_id)
    accounts.delete(user_id)
    save_osu_accounts(accounts)
    event.respond "Votre nom de compte Osu n'est désormais plus affilié à votre compte discord"
  else
    event.respond "Avant de vouloir retirer votre nom de compte, il faudrait peut-être en ajouter un, ne pensez vous pas ?"
  end
end

bot.message do |event|
  if event.message.content == '!welcome'
    is_admin = event.user.roles.any? { |role| role.permissions.administrator } || EXCLUDED_USERS.include?(event.user.id)
    unless is_admin
      event.respond "Vous n'avez pas la permission d'utiliser cette commande."
      next
    end

    command_users[event.user.id] = Time.now

    event.channel.send_embed do |embed|
      embed.title = "Système de bienvenue !"
      embed.description = "Vous prévoyez d'accueillir de nouvelles personnes ? Voici ce que je peux faire :\n\n- Activer ou désactiver le système de bienvenue\n- Modifier le salon d'envoi du message de bienvenue\n\nDépêchez vous, je n'ai guère votre temps."
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
          r.string_select(custom_id: 'string_select', placeholder: 'Choisissez une option', max_values: 1) do |ss|
            ss.option(label: 'Activer/Désactiver le système', value: '1', emoji: { name: '1️⃣' })
            ss.option(label: "Modifier le salon d'envoi", value: '2', emoji: { name: '2️⃣' })
          end
        end
      end
    )

    Thread.new do
      sleep 30
      if Time.now - command_users[event.user.id] >= 30
        menu_message.delete
        command_users.delete(event.user.id)
      end
    end
  end
end

bot.string_select do |event|
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
    event.interaction.respond(content: "Veuillez sélectionner le salon pour les messages de bienvenue.", ephemeral: true)
    event.channel.send_message(
      '', false, nil, nil, nil, nil,
      Discordrb::Components::View.new do |builder|
        builder.row do |r|
          r.channel_select(custom_id: 'channel_select', placeholder: 'Sélectionnez le salon', max_values: 1)
        end
      end
    )
  end

  server_settings['welcome_system'] = welcome_settings
  settings[event.server.id.to_s] = server_settings
  save_starboard_settings(settings)
end

bot.channel_select do |event|
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
end

bot.member_join do |event|
  settings = load_starboard_settings
  server_settings = settings[event.server.id.to_s] || {}
  welcome_settings = server_settings['welcome_system'] || {}
  next unless welcome_settings['active']

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

bot.command :stats do |event|
  unless event.user.id == MY_USER_ID
    event.respond "Tu n'as pas la permission d'utiliser cette commande."
    next
  end
  command_usage['stats'] += 1
  stats = COMMANDS.map { |cmd| "`#{PREFIX}#{cmd}` : used #{command_usage[cmd]} times" }.join("\n\n")
  event.respond "**Stats actuelles :**\n#{stats}"
end


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


  load_enabled_categories


  sleep(3)  


  bot.servers.each do |_, server|
    role_name = "Muted_Miyo"  
    existing_role = server.roles.find { |r| r.name == role_name }
    unless existing_role
      server.create_role(name: role_name, permissions: 0, mentionable: false)
      puts "Created missing mute role in server: #{server.name} (ID: #{server.id})"
    else
      puts "Mute role already exists in server: #{server.name} (ID: #{server.id})"
    end
  end
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
