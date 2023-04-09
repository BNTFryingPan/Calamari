package commands;

import Calamari.ExitCode;
import commands.Command;

class Help extends Command {
   public static function getCommandInfo():CommandInfo {
      return {
         name: 'Help',
         shortDescription: 'Basic help command for how to use Calamari.',
         description: 'Basic help command. See `calamari help` for actual help.',
         args: [
            {
               name: 'topic',
               required: false,
               description: 'Command or topic to get help on',
            }
         ],
         examples: [
            {
               usage: 'commands',
               description: 'Lists all available commands',
            }
         ]
      };
   }

   public static var ROOT_COMMAND_INFO:CommandInfo = {
      name: 'Calamari',
      shortDescription: 'Root command',
      description: 'Root calamari command',
      args: [
         {
            name: 'command',
            required: false,
            description: 'The subcommand to run. See `calamari help commands` for a list of subcommands',
         },
         {
            name: '...',
            required: false,
            description: 'Arguments for the subcommand. See `calamari help <command>` for more information about a specific command',
         }
      ],
      flags: [
         {
            name: 'quiet',
            description: 'limits text output'
         },
         {
            name: 'verbose',
            description: 'increases text output'
         },
         {
            name: 'disable-color',
            description: 'disables color and styling of text output'
         }
      ],
      options: [
         {
            name: 'version',
            description: 'displays the version of the Calamari executable',
            values: [
               {
                  value: 'hash',
                  description: 'shows the commit hash'
               },
               {
                  value: 'short',
               },
               {
                  value: 'long',
               }
            ]
         },
         {
            name: 'project',
            description: 'specifies a project file for Calamari to use',
            value: 'path/to/project.calamari',
         }
      ]
   }

   public static var helpTopics:Map<Null<String>, Void->String> = [
      null => () -> 'Calamari is a project management utility for Haxe. It helps manage libraries and Haxe compiler arguments.
Use `calamari help <topic>` to see more about a certain topic.
You can also use `calamari help <command>` to see more about a certain command.
List of help topics:
   calamari - List of global flags and options
   commands - List of available commands
   targets - List of available targets and their aliases',
      'targets' => () -> 'List of targets and the available aliases to refer to them:
      C++: c++, cpp, cplusplus, hxcpp
      C#: c#, cs, csharp, hxcs
      Hashlink: hashlink, hl
      Java: java, hxjava
      Java Bytecode: jvm
      JavaScript: javascript, js
      Neko: neko, n
      Python: python, py'
   ];

   public function execute(args:Array<String>, flags:Array<String>, options:Map<String, String>):Int {
      var topic = args.shift();
      if (topic != null)
         topic = topic.toLowerCase();
      if (helpTopics.exists(topic)) {
         Calamari.log(helpTopics[topic]());
         return ExitCode.OK;
      }
      switch topic {
         case 'commands':
            Calamari.log('List of commands:');
            for (key => value in Calamari.commands) {
               var data:CommandInfo = Reflect.field(value, 'getCommandInfo')();
               Calamari.log('   ${key}   ${data.shortDescription}');
            }
            return ExitCode.OK;
         case 'targets':
            Calamari.log();
         case 'calamari':
            printHelpForCommandData(ROOT_COMMAND_INFO, true);
         default:
            if (!Calamari.commands.exists(topic)) {
               Calamari.error('Command or topic not found!');
               Calamari.log('Use `calamari help` to see available topics, or `calamari help commands` for a list of commands.');
               return ExitCode.HelpTopicNotFound;
            }

            var data:CommandInfo = Reflect.field(Calamari.commands.get(topic), 'getCommandInfo')();
            trace(data);
            printHelpForCommandData(data);
      }

      return ExitCode.OK;
   }

   function getHelpForCommandData(data:CommandInfo, root:Bool = false) {
      Calamari.log('${data.name} Command Usage:');
      var usageString = '   calamari';
      if (!root) {
         usageString += ' ${data.name.toLowerCase()}';
      }

      if (data.args != null && data.args.length > 0) {
         usageString += ' ${data.args.map(a -> a.required == true ? '<${a.name}>' : '[${a.name}]').join(' ')}';
      }

      Calamari.log(usageString);

      if (data.description == null) {
         if (data.shortDescription != null) {
            Calamari.log('\nDescription');
            Calamari.log('   ${data.shortDescription}');
         }
      } else {
         Calamari.log('\nDescription');
         Calamari.log('   ${data.description}');
      }

      if (data.args != null && data.args.length > 0) {
         Calamari.log('\nArguments:');
         for (arg in data.args) {
            Calamari.log('   ${arg.name} - ${arg.description}');
         }
      }

      if (data.flags != null && data.flags.length > 0) {
         Calamari.log('\nFlags:');
         for (flag in data.flags) {
            Calamari.log('   -${flag.name} - ${flag.description}');
         }
      }

      if (data.options != null && data.options.length > 0) {
         Calamari.log('\nOptions:');
         for (option in data.options) {
            if (option.value != null) {
               Calamari.log('   --${option.name}=${option.value} - ${option.description}');
            } else {
               Calamari.log('   --${option.name} - ${option.description}');
            }

            if (option.values != null && option.values.length > 0) {
               for (value in option.values) {
                  var optString = '      ${value.value}';
                  if (value.description != null) {
                     optString += ' - ${value.description}';
                  }
                  Calamari.log(optString);
               }
            }
         }
      }

      if (data.examples != null && data.examples.length > 0) {
         Calamari.log('\nExamples:');

         for (example in data.examples) {
            Calamari.log('   calamari ${data.name.toLowerCase()} ${example.usage}');
            Calamari.log('      ${example.description}');
         }
      }
   }

   public override function completions(input:Array<String>):Array<String> {
      Calamari.log('${input}');
      Calamari.log('${input.length} "${input.join('", "')}"');
      if (input.length == 0) {
         return [for (key => value in helpTopics) if (key != null) key].concat([for (key => value in Calamari.commands) key]);
      }
      return [];
   }
}
