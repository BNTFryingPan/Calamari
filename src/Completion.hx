package;

using StringTools;
using String;

enum Token {
   Argument(name:String);
   Flag(name:String);
   Option(name:String, value:Null<String>);
}

enum CompletionNode {
   /**
      The root of the completion tree.

      @param subcommands Array of `Subcommand` nodes
      @param flags Array of strings that can be suggested as flags
      @param options Array of `Option` nodes that can be suggested as options
   **/
   Root(subcommands:Array<CompletionNode>, flags:Array<String>, options:Array<OptionNode>);
   /**
      a subcommand.

      @param name the string literal used to call this command
      @param children either an array containing 1 non-`Subcommand` completion node, or multiple `Subcommand` nodes
   **/
   Subcommand(name:String, children:Array<CompletionNode>, ?desc:String);
   /**
      lists aliases for all targets.

      @param keepShort if true, will keep short aliases like `py` and `n` as suggestions
      @param child the next completion node. if null, will keep suggesting unused target names until the user adds a `-` to start a flag or option. use the `Flags` node if this is the last argument and you only want 1 target suggested.
   **/
   AllTargetAliases(keepShort:Bool, child:Null<CompletionNode>);
   /**
      same as `AllTargetAliases`, but instead of showing aliases for all targets, it will only show aliases supported by the selected project. if no project is selected or can be found, it will act identically to `AllTargetAliases`.

      @param keepShort if true, will keep short aliases like `py` and `n` as suggestions
      @param child the next completion node. if null, will keep suggesting unused target names until the user adds a `-` to start a flag or option. use the `Flags` node if this is the last argument and you only want 1 target suggested.
   **/
   SupportedTargetAliases(keepShort:Bool, child:Null<CompletionNode>); // lists only aliases for targets supported by the project in the selected project file
   /**
      suggests minecraft versions

      @param requireServerJar if true, will only show versions that have a server jar download available from mojang servers
      @param requireClientJar if true, will only show versions that have a client jar download available from mojang servers
      @param snapshots if true, will include snapshot, pre-releases, and release candidates in the suggestions.
      @param old if true, will include versions of minecraft before release 1.0
   **/
   MinecraftVersions(requireServerJar:Bool, requireClientJar:Bool, snapshots:Bool, old:Bool);
   /**
      indicates that only flags and options should be suggested at this point
   **/
   Flags;
}

enum OptionNode {
   NoOp(key:String);
   Files(key:String, extension:Null<String>);
   Folders(key:String);
   OptionList(key:String, values:Array<String>);
}

class Completion {
   var args:Array<String> = [];
   var flags:Array<String> = [];
   var options:Map<String, String> = [];

   var raw:Array<String>;

   public static final tree:CompletionNode = Root([
      Subcommand('install', [Flags]),
      Subcommand('build', [SupportedTargetAliases(false, null)]),
      Subcommand('datagen', [MinecraftVersions(true, false, false, false)]),
      Subcommand('run', [SupportedTargetAliases(false, null)]),
      Subcommand('test', []),
      Subcommand('buildall', [Flags]),
      Subcommand('help', [
         Subcommand('install', []),
         Subcommand('build', []),
         Subcommand('datagen', []),
         Subcommand('run', []),
         Subcommand('test', []),
         Subcommand('buildall', []),
         Subcommand('help', []),
         Subcommand('commands', []),
         Subcommand('targets', []),
      ]),
   ], [
      'version',
      'debug',
      'quiet',
      'verbose',
      // 'setup' - hidden because it should only be used for the .zshrc or .bashrc file
      // 'bash' and 'zsh' - hidden because its only used internally by the completion script
   ], [
      OptionList('version', ['', 'hash', 'long', 'short']),
      Files('project', 'calamari'),
      Folders('out'),
   ]);

   public static function getNodesMatchingInput(node:CompletionNode, input:Array<String>):Array<CompletionNode> {
      switch (node) {
         case Root(subcommands, flags, options):
            var matchingSubcommands:Array<CompletionNode> = [];
            for (subcommand in subcommands) {
               switch subcommand {
                  case Subcommand(name, children, desc):
                     if (name.toLowerCase().startsWith(input[0].toLowerCase())) matchingSubcommands.push(subcommand);
                  default:
                     // invalid!
               }
            }
            //var matching = subcommandNames.filter(s -> s.toLowerCase().startsWith(input[0].toLowerCase()));
            if (matchingSubcommands.length == 1 && input.length > 1) {
               input = input.slice(1);
               return getNodesMatchingInput(matchingSubcommands[0], input);
            }
            return matchingSubcommands;
         case Subcommand(name, children, desc):
            var matchingSubcommands:Array<CompletionNode> = [];
            for (subcommand in children) {
               switch subcommand {
                  case Subcommand(name, children, desc):
                     if (name.toLowerCase().startsWith(input[0].toLowerCase())) matchingSubcommands.push(subcommand);
                  default:
                     // invalid!
               }
            }
            //var matching = subcommandNames.filter(s -> s.toLowerCase().startsWith(input[0].toLowerCase()));
            if (matchingSubcommands.length == 1 && input.length > 1) {
               input = input.slice(1);
               return getNodesMatchingInput(matchingSubcommands[0], input);
            }
            return matchingSubcommands;
         case AllTargetAliases(keepShort, child):
            return [node];
            //if (keepShort) return [for (k in Calamari.targetAliases.keys()) k];
            //return [for (k in Calamari.targetAliases.keys()) if (k.length >= 3) k];
         case SupportedTargetAliases(keepShort, child):
            return [node];
            //if (keepShort) return [for (k in Calamari.targetAliases.keys()) k];
            //return [for (k in Calamari.targetAliases.keys()) if (k.length >= 3) k];
         case MinecraftVersions(requireServerJar, requireClientJar, snapshots, old):
            return [node];
            //return Calamari.getVersionCompletions(input[0]);
         case Flags:
            return [];
      }
      return [];
   }

   public static function getCompletions(str:String):Array<String> {
      var arguments = [];
      var buffer = '';
      var escaped = false;
      var doubleQuoted = false;
      var singleQuoted = false;
      
      for (char in str) {
         var c = char.fromCharCode();
         if (escaped) {
            buffer += c;
            escaped = false;
            continue;
         }

         if (char == '\\'.code) {
            if (singleQuoted) {
               buffer += c;
               continue;
            }
            escaped = true;
            continue;
         }

         if (c.isSpace(0)) {
            if (singleQuoted || doubleQuoted) {
               buffer += c;
               continue;
            }
            if (buffer.length > 0) arguments.push(buffer);
            buffer = '';
            continue;
         }

         if (char == "'".code) {
            if (doubleQuoted) {
               buffer += c;
               continue;
            }
            singleQuoted = !singleQuoted;
            continue;
         }

         if (char == '"'.code) {
            if (singleQuoted) {
               buffer += c;
               continue;
            }
            doubleQuoted = !doubleQuoted;
            continue;
         }

         buffer += c;
      }
      if (buffer.length > 0) arguments.push(buffer);

      if (arguments[0] == 'calamari') arguments.shift();
      var completions = getNodesMatchingInput(tree, arguments);
      trace(completions);
      //return completions;
      return [];
      //trace(argv);

      //trace(parts);

      //return [];
   }

   public static function parseSingleArg(arg:String):Token {
      if (arg.charCodeAt(0) == '-'.code) {
         if (arg.charCodeAt(1) == '-'.code) {
            var valueSep = arg.indexOf('=');
            if (valueSep < 0) {
               return Option(arg.substring(2), null);
            }
            return Option(arg.substring(2, valueSep), arg.substring(valueSep+1));
         }
         return Flag(arg.substring(1));
      }
      return Argument(arg);
   }

   public function new(args:Array<String>) {
      this.raw = args;

      var parts:Array<Token> = [];

      for (arg in args) {
         parts.push(parseSingleArg(arg));
      }

      for (p in parts) {
         switch p {
            case Argument(name):
               trace('argument: "$name"');
            case Flag(name):
               trace('flag: "$name"');
            case Option(name, value):
               if (value == null) trace('option: "$name"');
               else trace('option "$name"="$value"');
         }
      }

      /*for (arg in all) {
         if (arg.startsWith('--')) {
            pastArgs = true;

            var eqPos = arg.indexOf('=');
            var key;
            var value = '';

            if (eqPos < 0) {
               key = arg.substr(2);
            } else {
               key = arg.substr(2, arg.indexOf('=')-2);
               value = arg.substr(arg.indexOf('=')+1);
            }
               if (options.exists(key)) options.set(key, options.get(key) + ' $value');
               else options.set(key, value);
         } else if (arg.startsWith('-')) {
            pastArgs = true;
            if (flags.contains(arg.substr(1))) {
               log('Duplicate flag: $arg');
               exit(DuplicateFlag);
            }
            flags.push(arg.substr(1));
         } else {
            if (pastArgs) {
               log('Command Error');
               exit(InvalidArguments);
            }

            args.push(arg);
         }
      }*/
   }
}