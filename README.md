# Miyo - Discord Bot

## Forewords
Miyo is a discord bot, which is open source. You can use the code freely, but please consider tagging me somewhere. She's updated quite often
Miyo is my personal bot. It may not be the best in terms of optimisations, however, it works fine.
I hope it can be used as a model for starting or upgrading your Ruby bot.
Nevertheless, I won't share any data. Build your own database.
We decline every responsabilities in your online activities with the bot. This include streams, videos, screenshots... If you want to make content about her, do as you please, but we're not responsible.

## Dependencies
You have several dependencies to install before Miyo can work if you plan to use it as a starting point.
Here's the list : 
- `discordrb` Well, that's just the point of the code. But you can remove it i guess
- `httparty` Better if you want to use some info from the web
- `json` Idk how to use sql so this better works
- `net/http` Internet (again)
- `uri` also for internet (so much omg)
- `nokogiri` That's also for internet
- `fileutils` If you want to modify a file or smth idk
- `rufus-scheduler` if you want to send/do scheduled messages/actions
- `tzinfo` Better if you want to step up from a dummy code which don't know what's time to a dummy code, but know the time zone
- `tzinfo/data` Same but with data

If you want to install them in one command, here you go :

```
gem install discordrb httparty json nokogiri rufus-scheduler tzinfo tzinfo-data
```
## Commands

Here's the list with all the commands that Miyo has :
- /Album : Moderators only. This command allows the user to set if the user wants or not Miyo to send an album everyday. Also, the user can set where the album are sent.
- /Album search : This command allows the user to search through my database some album, rate the albums and tracks.
- /automute : Moderators only. This command allows the user to set an automute, which is based on how many similars message in a row someone has sent. Can be useful sometime because the bot check the whole server, rather than just a part of it.
- /data : Allows the user to disable some of the functionalities that requires the use of collected data.
- /help : Allows the user to check all of Miyo's commands.
- /info : Allows the user to see some basic info about Miyo.
- /language : Moderator only. Allows the user to set Miyo's language on the server.
- /personnality : Moderator only. Allows the user to change the Miyo's personnality when it respond with its AI.
- /welcome : Moderator only. This command allows the user to set if the user wants or not Miyo to send a message to welcome the new persons on the server. Also, the user can set where these message are sent.

## Other informations
---  
- The bot is constantly updated, some features may be changed or removed.  
- Please report any bugs or issues to **museau__** on discord.
- Since Miyo is still in development, she can "bug" sometimes. We apologise for this.
---

## Acknowledgements 
To Cyn, for helping me with some parts of the code!
To Roxas, and his integration of Miyo in his bot [Glados](https://aperture-sciences.com/)

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=Muse-haut/Miyo&type=Date)](https://www.star-history.com/#Muse-haut/Miyo&Date)
