class BaseCommand
  @command_users = {}
  class << self
    attr_accessor :command_users

    def register(bot)
      raise NotImplementedError, "Chaque commande doit définir `self.register(bot)`"
    end
  end
end
