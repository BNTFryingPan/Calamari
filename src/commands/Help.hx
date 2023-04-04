package commands;

import Calamari.ExitCode;
import commands.Command;

class Help extends Command {
   public function getCommandInfo():CommandInfo {
      return {
         name: 'Help',
         shortDescription: 'Basic help command for how to use Calamari.',
         description: 'Basic help command. See `calamari help` for actual help.',
      };
   }

   public function execute(args:Array<String>, flags:Array<String>, options:Map<String, String>):Int {
      var topic = args.shift();
      trace(topic);
      if (topic == null) {
         Calamari.log('Calamari is a project management utility for Haxe. It helps manage libraries and Haxe compiler arguments.');
         Calamari.log('Use `calamari help <topic>` to see more about a certain topic.');
         Calamari.log('You can also use `calamari help <command>` to see more about a certain command.');
         Calamari.log('List of help topics:');
         Calamari.log('   commands - List of available commands');
         Calamari.log('   targets - List of available targets and their aliases');
         return ExitCode.OK;
      }
      topic = topic.toLowerCase();
      switch topic {
         case 'commands':
            Calamari.log('List of commands:');
            for (key => value in Calamari.commands) {
               var data = Type.createInstance(value, []).getCommandInfo();
               Calamari.log('   ${key}   ${data.shortDescription}');
            }
            return ExitCode.OK;
         case 'targets':

         default:
            if (!Calamari.commands.exists(topic)) {
               Calamari.error('Command or topic not found!');
               Calamari.log('Use `calamari help` to see available topics, or `calamari help commands` for a list of commands.');
               return ExitCode.HelpTopicNotFound;
            }

            var data = Type.createInstance(Calamari.commands.get(topic), []).getCommandInfo();

            var helpString = '${data.name} Command Usage:
   calamari $topic';

            if (data.args != null && data.args.length > 0) {
               helpString += ' ${data.args.map(a -> a.required == true ? '<${a.name}>' : '[${a.name}]').join(' ')}';
               helpString += '\nArguments:';
               for (arg in data.args) {
                  helpString += '\n   ${arg.name} - ${arg.description}';
               }
            }

            Calamari.log(helpString);
      }

      return ExitCode.OK;
   }

   function get_commandName():String {
      return 'help';
   }
}
