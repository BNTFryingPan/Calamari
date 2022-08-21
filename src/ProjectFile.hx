package;

import sys.FileSystem;
import haxe.io.Path;
import sys.io.File;
import haxe.Json;
import Calamari;

using StringTools;

typedef ProjectFileStructure = {
    projectName:String,
    ?versionFile:String,
    mainClass:String,
    classPath:String,
    ?libraries:Array<String>,
    ?supportedTargets:Array<String>,
    ?buildFolder:String,
    ?exportFolder:String,
}

class ProjectFile {
    public var data:ProjectFileStructure;
    final path:String;

    public static final DEFAULT_BUILD_FOLDER = "${root}/build/";
    public static final DEFAULT_EXPORT_FOLDER = "${root}/out/";
    public static final DEFAULT_PROJECT_FILE_NAME = 'project.calamari';

    static var default_project:ProjectFile = null;

    public static function getProjectFileName():String {
        return Calamari.options.exists('project') ? Calamari.options.get('project') : DEFAULT_PROJECT_FILE_NAME;
    }

    public static function getProjectData(allowFail:Bool = true):Null<ProjectFile> {
        if (default_project != null) return default_project;
        var exists = verifyRunningFromProjectFolder(!allowFail);
        if (!exists) return null;

        return default_project = new ProjectFile('./${getProjectFileName()}');
    }

    public static function verifyRunningFromProjectFolder(checkOnly=false):Bool {
        if (!FileSystem.exists('./${getProjectFileName()}')) {
            if (!checkOnly) {
                Calamari.error('This command must be run from the root of a Calamari project.');
                Calamari.exit(WorkingDirNotACalamariProject);
            }
            return false;
        }
        return true;
    }

    public static function getOutputPath():String {
        if (Calamari.options.exists('out')) return Calamari.options.get('out');
        var project = getProjectData(false);
        if (project != null) return project.exportFolder;
        return ProjectFile.DEFAULT_EXPORT_FOLDER;
    }

    function getRelativePath(path:String):String {
        return path.replace("${root}", Path.directory(this.path));
    }

    public function new(path) {
        this.path = path;
        data = Json.parse(File.getContent(this.path));
    }

    public var projectName(get, never):String;
    function get_projectName():String {
        return data.projectName;
    }

    public var currentVersion(get, never):String;
    function get_currentVersion():String {
        if (data.versionFile == null) return '';
        return File.getContent(getRelativePath(data.versionFile));
    }

    public function supportsTarget(target:SysTarget):Bool {
        for (alias => t in Calamari.targetAliases) {
            if (t == target && data.supportedTargets.contains(alias)) return true;
        }
        return false;
    }

    public var buildFolder(get, never):String;
    function get_buildFolder():String {
        if (data.buildFolder != null) return getRelativePath(data.buildFolder);
        return getRelativePath(DEFAULT_BUILD_FOLDER);
    }

    public var exportFolder(get, never):String;
    function get_exportFolder():String {
        if (data.exportFolder != null) return getRelativePath(data.exportFolder);
        return getRelativePath(DEFAULT_EXPORT_FOLDER);
    }
}