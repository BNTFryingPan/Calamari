package;

import sys.FileSystem;
import haxe.io.Path;
import sys.io.File;
import haxe.Json;
import Calamari;

using StringTools;

typedef ProjectSettings = {
   /**
    * The main class to use. equivalent to haxe's `--main` argument
    */
   ?mainClass:String,
   /**
    * class paths to include in the compile. equivalent to haxe's `--class-path` argument
    */
   ?classPaths:Array<String>,
   /**
    * specific haxe source files to include in the compile. equivalent to listing files when running `haxe` manually
    */
   ?files:Array<String>,
   /**
    * list of libraries to include when compiling
    */
   ?libraries:Map<String, Null<String>>,
   /**
    * list of targets that are supported. you can also include an unsupported target to specify a reason that the target is unsupported that is shown if someone tries compiling for that target.
    */
   ?targets:Array<TargetSupport>,
   /**
    * the folder to build to. actually creates folders for each target in the folder given here, `${buildFolder}/${target}/`
    */
   ?buildFolder:String,
   /**
    * the folder to place exported builds into
    */
   ?exportFolder:String,
   /**
    * hxml file to include
    */
   ?hxml:Array<String>,
   /**
    * list of defines to pass to the haxe compiler. equivalent to `-D ${key}=${value}` for each entry
    */
   ?defines:Map<String, Null<String>>,
}

typedef ProjectFileStructure = {
   > ProjectSettings,

   /**
    * the name of the project
    */
   projectName:String,

   /**
    * file that contains the version number. the version number will be included in the file name of exported builds
    */
   ?versionFile:String,
   /**
    * the type of project this is. defaults to `haxe`, and `hxgodot` will be supported in the near future 
    */
   ?projectType:ProjectType,
   /**
    * flags and options that can be passed to the build command to modify how the compiler is ran
    */
   ?options:Array<Option>,
}

typedef Library = {
   /**
    * the name of the library
    */
   name:String,

   /**
    * the version of the library or the url to the git repository of the library. if null, the library is not included at all. useful to exclude a library from certain targets or options
    * specifying a url is equivalent to `--library ${name}:git:${version}`
    * specifying the version is equivalent to `--library ${name}:${version}`.
    * not specifying the version is equivalent to just `--library ${name}`.
    */
   ?version:Null<String>,
}

/**
 * an option or flag that can be passed when running `calamari` to modify the behavior of the build.
 * can override most of the base project settings, including target support, libraries, or even the main class
 * overrides for array options will add to the base project in the order that the flags are specified when the command is ran
 */
typedef Option = {
   > ProjectSettings,

   /**
    * the key of the option. this is what would be specified when running `calamari` to set the value of this option. for example if the key is `test`, using `calamari build cpp -test` would use the settings defined in that option
    */
   key:String,

   /**
    * the id of the option. defaults to `null`. if non-null, adds this to the exported builds file name
    * 
    * i couldnt think of a better name :(
    */
   ?id:Null<String>,
   /**
    * the type of option. currently only `flag` is supported, but `option` is planned later to allow string values instead of just true/false
    */
   ?type:OptionType,
}

/**
 * a target that this project may or may not support. can override all of the same project settings as an option can
 */
typedef TargetSupport = {
   > ProjectSettings,

   /**
    * the target that this entry contains data for. supported targets are: `nodejs, neko, cpp, csharp, java, jvm, python, hashlink`
    */
   target:String,

   /**
    * whether or not this target is supported by the project
    */
   supported:Bool,

   /**
    * if unsupported, a reason can be specified that is shown in the error if someone tries compiling for this target
    */
   ?reason:String,
}

enum abstract OptionType(String) from String to String {
   var FLAG = 'flag';
   // var OPTION = 'option'; // might add someday
}

enum abstract ProjectType(String) from String to String {
   var HAXE = 'haxe';
   var HXGODOT = 'hxgodot';
}

class ProjectFile {
   public var data:ProjectFileStructure;

   final path:String;

   public static final DEFAULT_BUILD_FOLDER = "${root}/build/";
   public static final DEFAULT_EXPORT_FOLDER = "${root}/out/";
   public static final DEFAULT_PROJECT_FILE_NAME = 'project.calamari';
   public static final DEFAULT_FILE_EXTENSION = '.calamari';

   static var default_project:ProjectFile = null;

   public static function findProjectFile(path:String):Null<String> {
      trace('looking for project in $path');
      if (!FileSystem.exists(path))
         return null;
      if (path == '/' || path.charCodeAt(1) == ':'.code)
         return null;
      if (FileSystem.exists('$path/$DEFAULT_PROJECT_FILE_NAME'))
         return '$path/$DEFAULT_PROJECT_FILE_NAME';
      var filesInPath = FileSystem.readDirectory(path);
      var foundFile = false;
      var possibleProjects:Array<String> = [];
      for (file in filesInPath) {
         if (FileSystem.isDirectory('$path/$file'))
            continue;
         if (!file.endsWith(DEFAULT_FILE_EXTENSION))
            continue;
         possibleProjects.push('$path/$file');
      }
      if (possibleProjects.length == 0)
         return findProjectFile(Path.normalize(Path.join([path, '..'])));
      if (possibleProjects.length == 1)
         return possibleProjects[0];
      trace('more than 1 possible project found. please specify a project!');
      return null;
   }

   public function new(file:String) {
      this.path = file;
      data = Json.parse(File.getContent(file));

      trace(data);
   }

   public function resolveProjectSettings(target:Null<SysTarget>, flags:Array<String>):ProjectFileStructure {
      var resolved:ProjectFileStructure = {
         projectName: this.data.projectName,
         versionFile: this.data.versionFile,
         projectType: this.data.projectType,
         mainClass: this.data.mainClass,
         classPaths: this.data.classPaths,
         files: this.data.files,
         libraries: this.data.libraries,
         targets: this.data.targets,
         buildFolder: this.data.buildFolder,
         exportFolder: this.data.exportFolder,
         hxml: this.data.hxml,
         defines: this.data.defines,
      }

      function apply(thing:ProjectSettings) {
         if (thing.mainClass != null)
            resolved.mainClass = thing.mainClass;
         if (thing.buildFolder != null)
            resolved.buildFolder = thing.buildFolder;
         if (thing.exportFolder != null)
            resolved.exportFolder = thing.buildFolder;

         if (thing.classPaths != null)
            resolved.classPaths = resolved.classPaths.concat(thing.classPaths);
         if (thing.files != null)
            resolved.files = resolved.files.concat(thing.files);
         if (thing.hxml != null)
            resolved.hxml = resolved.hxml.concat(thing.hxml);

         if (thing.defines != null) {
            for (def => value in thing.defines) {
               if (value == null) {
                  resolved.defines.remove(def);
                  continue;
               }
               resolved.defines.set(def, value);
            }
         }

         if (thing.libraries != null) {
            for (lib => version in thing.libraries) {
               if (version == null) {
                  resolved.libraries.remove(lib);
                  continue;
               }
               resolved.libraries.set(lib, version);
            }
         }

         if (thing.targets != null) {
            // for (target)
         }
      }

      function handleTarget(thing:TargetSupport) {}

      return null;
   }

   public static function getProjectData(allowFail:Bool = true):Null<ProjectFile> {
      if (default_project != null)
         return default_project;
      var exists = verifyRunningFromProjectFolder(!allowFail);
      if (!exists)
         return null;
      return default_project = new ProjectFile(findProjectFile(Sys.getCwd()));
   }

   public static function verifyRunningFromProjectFolder(checkOnly = false):Bool {
      var file = findProjectFile(Sys.getCwd());
      if (file != null)
         return true;
      if (!checkOnly) {
         Calamari.error('This command must be run from within a Calamari project.');
         Calamari.exit(WorkingDirNotACalamariProject);
      }
      return false;
   }

   function getRelativePath(path:String):String {
      return path.replace("${root}", Path.directory(this.path));
   }

   public var projectName(get, never):String;

   function get_projectName():String {
      return data.projectName;
   }

   public var currentVersion(get, never):String;

   function get_currentVersion():String {
      if (data.versionFile == null)
         return '';
      return File.getContent(getRelativePath(data.versionFile));
   }

   public function supportsTarget(target:SysTarget):Bool {
      var matches = data.targets.filter((t) -> {
         return Calamari.resolveTargetAlias(t.target);
      })

      if (matches.)
         /*for (alias => t in Calamari.targetAliases) {
            if (t == target && data.targets.contains(alias))
               return true;
         }*/
         return false;
   }

   public var buildFolder(get, never):String;

   function get_buildFolder():String {
      if (data.buildFolder != null)
         return getRelativePath(data.buildFolder);
      return getRelativePath(DEFAULT_BUILD_FOLDER);
   }

   public var exportFolder(get, never):String;

   function get_exportFolder():String {
      if (data.exportFolder != null)
         return getRelativePath(data.exportFolder);
      return getRelativePath(DEFAULT_EXPORT_FOLDER);
   }
}
