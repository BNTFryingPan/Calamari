package;

import sys.FileSystem;
import commands.Command;
import commands.Build;

using StringTools;

enum abstract ExitCode(Int) to Int {
   var OK = 0;
   var InvalidArguments = 1;
   var DuplicateFlag = 2;
   var UnknownCommand = 3;
   var WorkingDirNotACalamariProject = 4;
   var VersionExistsButNoServerJar = 5;
}

enum abstract TargetLocations(String) {
   var CPP = 'cpp/';
   var CSHARP = 'csharp/';
   var HASHLINK = 'hashlink/';
   var JAVA = 'java/';
   var JVM = 'jvm/';
   var NODEJS = 'nodejs/';
   var HTML5 = 'html5/';
   var NEKO = 'neko/';
   var PYTHON = 'python/';
   var PHP = 'php/';
}

enum HostOS {
   Linux;
   Windows;
   Mac;
   Unknown;
}

enum HostArch {
   ArmV6;
   ArmV7;
   X86;
   X64;
}

enum abstract ANSICodes(String) {
   var BLACK = '\u001b[30m';
   var RED = '\u001b[31m';
   var GREEN = '\u001b[32m';
   var DARK_YELLOW = '\u001b[33m';
   var BLUE = '\u001b[34m';
   var MAGENTA = '\u001b[35m';
   var DARK_CYAN = '\u001b[36m';
   var LIGHT_GREY = '\u001b[37m';
   var DARK_GREY = '\u001b[30;1m';
   var LIGHT_RED = '\u001b[31;1m';
   var LIGHT_GREEN = '\u001b[32;1m';
   var YELLOW = '\u001b[33;1m';
   var LIGHT_BLUE = '\u001b[34;1m';
   var PINK = '\u001b[35;1m';
   var CYAN = '\u001b[36;1m';
   var WHITE = '\u001b[37;1m';
   var RESET = '\u001b[0m';
   var BOLD = '\u001b[1m';
   var UNDERLINE = '\u001b[4m';
}

class Calamari2 {
   public static function log(text:String, ?pos:haxe.PosInfos) {
      /*if (!options.exists('autocomplete')) Sys.println('$WHITE$text$RESET');
      if (logFileOutput != null) {
         logFileOutput.writeString('${pos.fileName}@${pos.lineNumber}: $text\n');
         logFileOutput.flush();
      }*/
      Sys.println('$WHITE$text$RESET');
   }

   public static function error(text:String) {
      log('$LIGHT_RED    Error:$RESET$BOLD $text');
   }

   public static var flags:Array<String> = [];
   public static var options:Map<String, String> = [];
   public static var args:Array<String> = [];

   public static function exit(code:ExitCode) {
      //logFileOutput.close();
      //if (!FileSystem.exists(getFullPath('~/.calamari/logs/'))) FileSystem.createDirectory(getFullPath('~/.calamari/logs'));
      //if (!(options.exists('autocomplete') || options.exists('version') || flags.contains('setup')))
         //Sys.command('cp ${getFullPath('~/.calamari/latest.log')} ${getFullPath('~/.calamari/logs/${DateTools.format(Date.now(), "%Y-%m-%d_%H.%M.%S")}.log')}');
      Sys.exit(code);
   }

   public static var host(get, never):HostOS;
   public static var _host:Null<HostOS>;

   public static function get_host():HostOS {
      if (_host != null) return _host;
      return _host = switch (Sys.systemName()) {
         case 'Windows':
            Windows;
         case 'Linux' | 'BSD':
            Linux;
         case 'Mac':
            Mac;
         default:
            Unknown;
      }
   }

   public static var arch(get, never):HostArch;
   public static var _arch:Null<HostArch>;

   public static function get_arch():HostArch {
      if (_arch != null) return _arch;
      switch (host) {
         case Windows:
            if (Sys.getEnv('PROCESSOR_ARCHITECTURE').indexOf('64') > -1) return _arch = X64;

            var proc_arch_wow64 = Sys.getEnv('PROCESSOR_ARCHITEW6432');
            if (proc_arch_wow64 != null && proc_arch_wow64.indexOf('64') > -1) return _arch = X64;
            return _arch = X86;
         case Linux | Mac:
            var proc = new sys.io.Process('uname', ['-m']);
            if (proc.exitCode() != 0) {
               error('Unable to get host architecture: ${proc.stderr.readAll().toString()}');
               return _arch = X86;
            }

            var out = proc.stdout.readAll().toString();
            if (out.indexOf('armv6') > -1) return _arch = ArmV6;
            if (out.indexOf('armv7') > -1) return _arch = ArmV7;
            if (out.indexOf('64') > -1) return _arch = X64;
         default:
      }
      return _arch = ArmV6;
   }

   public static final commands:Array<Command> = [
      new Build()
   ];

   static function main() {
      //if !silent and !autocomplete
      log('${CYAN}${BOLD}Calamari $DARK_CYAN${Macros.versionString()}$WHITE - $DARK_GREY${Macros.commitHash().substr(0, 6)} on ${host.getName()} (${arch.getName()})');
      parseCommand();

      

      if (args.length == 0) {
         if (options.exists('autocomplete')) {
            // handle completion
            return;
         }

         if (flags.contains('setup')) {
            if (!FileSystem.exists())
         }

         log('    No command provided - use $RESET`calamari help`$WHITE for usage');
         return exit(OK);
      }
      for (cmd in commands) {
         if (cmd.getLiteral() == args[0]) {
            return cmd.init(args, flags, options);
         }
      }
      //log(flags.toString());
      //log(args.toString());
      //log(options.toString());
   }

   public static function parseCommand() {
      var all = Sys.args();

      var pastArgs = false;

      for (arg in all) {
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
      }
   }
}