package commands;

import haxe.io.Path;
import sys.FileSystem;
import Calamari;
import commands.Command.CommandInfo;

class Clean extends Command {
   public static function getCommandInfo():CommandInfo {
      return {
         name: 'Clean',
         shortDescription: 'Cleans up build files for a project.',
         description: 'Cleans up build files for a project.',
         args: [
            {
               name: 'type',
               description: 'What data to clean up. Possible options are `build` to clean up build files, `export` to clean up the export folder, and `all` for both.',
               required: true,
            }
         ]
      }
   }

   var projectFolder:Null<ProjectFile>;

   public function execute(args:Array<String>, flags:Array<String>, options:Map<String, String>):Int {
      projectFolder = ProjectFile.getProjectData(false);
      if (args.length == 0) {
         Calamari.error('No clean command provided. Use `calamari help clean` for usage.');
         // TODO : change this error code
         return ExitCode.OK;
      }

      switch (args[0]) {
         case 'all':
            Calamari.log('Cleaning all data for this project...');
            cleanBuildFolder();
            cleanExportFolder();
         case 'build' | 'compile':
            cleanBuildFolder();
         case 'export' | 'output' | 'out':
            cleanExportFolder();
         default:
            Calamari.error('Unknown clean command');
            return UnknownCommand;
      }
      Calamari.log('Done!');

      return ExitCode.OK;
   }

   function cleanExportFolder() {
      Calamari.log('Cleaning export folder...');
      FileSystem.deleteDirectory(projectFolder.exportFolder);
   }

   function cleanBuildFolder() {
      Calamari.log('Cleaning build folder...');
      FileSystem.deleteDirectory(projectFolder.buildFolder);
   }

   public override function completions(input:Array<String>):Array<String> {
      if (input.length <= 1) {
         return ['all', 'build', 'compile', 'output', 'out', 'export',];
      }
      return [];
   }
}
