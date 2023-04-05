package commands;

import sys.io.Process;
import Calamari.ExitCode;
import commands.Command.CommandInfo;

class Install extends Command {
   public static function getCommandInfo():CommandInfo {
      return {
         name: 'Install',
         shortDescription: 'Installs Calamari so you can use it easily from anywhere'
      }
   }

   public function execute(args:Array<String>, flags:Array<String>, options:Map<String, String>):Int {
      Calamari.log('   Attempting to install Calamari command...');
      switch (Calamari.host) {
         case Windows:
            Calamari.log('   To install calamari, put the exe in a folder on your PATH.');
            return InstallFailed;
         case Linux:
            Calamari.log('Enter password to copy the executable to /usr/bin/');
            var proc = new Process('sudo', ['cp', Sys.programPath(), '/usr/bin/calamari']);
            var exit = proc.exitCode();
            if (exit != 0) {
               var out = proc.stderr.readAll().toString();
               Calamari.error('Error copying file: $out');
               Calamari.log('Failed to install Calamari');
               return ExitCode.InstallFailed;
            }
            Calamari.log('Succesfully installed Calamari command. Add `source $(calamari -setup)` to your `~/.bashrc` or `~/.zshrc` to get completions');
            return ExitCode.OK;
         case Mac:
            Calamari.log('   To install calamari, put the exectuable somewhere that your shell can find it.');
            return InstallFailed;
         default:
            Calamari.error('Unknown platform! Can\'t provide install instructions.');
            return InstallFailed;
      }
   }
}
