package;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import haxe.Http;
import haxe.io.Path;
import sys.io.Process;
using StringTools;

enum abstract ExitCode(Int) {
    var OK = 0;
    var InvalidArguments = 1;
    var DuplicateFlag = 2;
    var UnknownCommand = 3;
}

enum abstract TargetLocations(String) {
    var BUILD_DIR = './build';
    var CPP = '$BUILD_DIR/cpp/';
    var CSHARP = '$BUILD_DIR/csharp/';
    var HASHLINK = '$BUILD_DIR/hashlink/';
    var JAVA = '$BUILD_DIR/java/';
    var JVM = '$BUILD_DIR/jvm/';
    var NODEJS = '$BUILD_DIR/nodejs/';
    var NEKO = '$BUILD_DIR/neko/';
    var PYTHON = '$BUILD_DIR/python/';
}

enum SysTarget {
    Cpp;
    Csharp;
    Hashlink;
    Java;
    Jvm;
    Nodejs;
    Neko;
    Python;
}

enum HostOS {
    Linux;
    Windows;
    Mac;
    Unknown;
}

typedef MinecraftVersion = {
    id:String,
    type:String,
    url:String,
    time:String,
    releaseTime:String,
}

typedef ManifestLatest = {
    release:String,
    snapshot:String,
}

typedef VersionManifest = {
    latest:ManifestLatest,
    versions:Array<MinecraftVersion>,
}

typedef AssetIndex = {
    id:String,
    sha1:String,
    size:Int,
    totalSize:Int,
    url:String,
}

typedef JavaVersionRequirement = {
    component:String,
    majorVersion:Int,
}

typedef ManifestOSRule = {
    arch:Null<String>,
    name:Null<String>,
    version:Null<String>,
}

typedef ManifestFeatureRule = {
    is_demo_user:Null<Bool>,
}

typedef ManifestRule = {
    action:String,
    os:Null<ManifestOSRule>,
    features:Null<ManifestFeatureRule>,
}

typedef LibraryArtifact = {
    path:String,
    sha1:String,
    size:Int,
    url:String,
}

typedef LibraryRequirement = {
    downloads:{artifact:LibraryArtifact},
    name:String,
    rules:Null<Array<ManifestRule>>,
}

typedef VersionDownload = {
    sha1:String,
    size:Int,
    url:String,
}

typedef VersionData = {
    assetIndex:AssetIndex,
    assets:String,
    complianceLevel:Int,
    downloads:{
        client:VersionDownload,
        client_mappings:VersionDownload,
        server:VersionDownload,
        server_mappings:VersionDownload,
    },
    id:String,
    javaVersion:JavaVersionRequirement,
    libraries:Array<LibraryRequirement>,
    logging:{
        client:{
            argument:String,
            file:{
                id:String,
                sha1:String,
                size:Int,
                url:String
            },
            type:String
        }
    },
    mainClass:String,
    minimumLauncherVersion:Int,
    releaseTime:String,
    time:String,
    type:String,
}

class Calamari {
    static function log(text:String) {
        if (options.exists('autocomplete')) return;
        Sys.println(text);
    }

    static var flags:Array<String> = [];
    static var options:Map<String, String> = [];
    static var args:Array<String> = [];

    static function runHaxe(args:Array<String>):Int {
        var proc = new Process('haxe', args);
        var exit = proc.exitCode();
        if (exit != 0) {
            var out = proc.stderr.readAll().toString();
            log('Error running Haxe: $out');
        }
        return exit;
    }

    static final rootCommandList = ['build', 'datagen', 'run', 'test', 'buildall', 'help'];
    static final helpTopicList = ['commands', 'targets'];
    static final knownFlags = ['debug', 'quiet', 'verbose'];
    static final targetAliases = [
        // C++
        'cpp' => Cpp,
        'c++' => Cpp,
        'cplusplus' => Cpp,
        'hxcpp' => Cpp,
        // C#
        'cs' => Csharp,
        'c#' => Csharp,
        'csharp' => Csharp,
        'hxcs' => Csharp,
        // Hashlink
        'hl' => Hashlink,
        'hashlink' => Hashlink,
        // Java
        'java' => Java,
        'hxjava' => Java,
        // JVM
        'jvm' => Jvm,
        // NodeJS
        'js' => Nodejs,
        'node' => Nodejs,
        'nodejs' => Nodejs,
        'hxnodejs' => Nodejs,
        // Neko
        'neko' => Neko,
        'n' => Neko,
        // Python
        'python' => Python,
        'py' => Python,
    ];

    static function getFullPath(path:String):String {
        var pat = ~/~/;
        return FileSystem.absolutePath(pat.replace(path, Sys.getEnv('HOME')));
    }

    static final CACHE_EXPIRE_TIME = 215e5; // 6 hours

    static function downloadMinecraftVersion(version:String) {
        var verData = getPistionDataForVersion(version);

        var path = getFullPath('~/.calamari/versions/${verData.type}_${verData.id}.jar');
        if (!FileSystem.exists(getFullPath('~/.calamari/versions/'))) FileSystem.createDirectory(getFullPath('~/.calamari/versions'));
        var file = File.write(path);
        var request = new Http(verData.downloads.server.url);
        var bytesSoFar = 0;
        var finished = false;
        request.onBytes = function (bytes) {
            bytesSoFar += bytes.length;
            file.write(bytes);
            log('    Downloading server jar: ${bytesSoFar}/${verData.downloads.server.size} (${Math.floor((bytesSoFar / verData.downloads.server.size)*100)}%)');
            if (bytesSoFar >= verData.downloads.server.size) {
                file.close();
                finished = true;
            }
        }
        request.request(false);
        while (finished == false) {
            Sys.sleep(0.2);
        }
        log('    Finished!');
    }

    static function getPistionDataForVersion(version:String):VersionData {
        var manifest = getMinecraftVersionManifest();
        var targetVersion:MinecraftVersion = null;

        for (ver in manifest.versions) {
            if (ver.id == version) {
                targetVersion = ver;
                break;
            }
        }
        if (targetVersion == null) throw 'Could not fine Minecraft version matching "$version" in manifest.';

        var path = getFullPath('~/.calamari/version_data/${targetVersion.type}_${targetVersion.id}.json');
        if ((!flags.contains('nocache')) && FileSystem.exists(path)) { // dont check expiry on this because its unlikely to change, but allow nocache to redownload anyways if something does change
            return Json.parse(File.getContent(path));
        }

        var data = Http.requestUrl(targetVersion.url);
        if (!FileSystem.exists(getFullPath('~/.calamari/version_data/'))) FileSystem.createDirectory(getFullPath('~/.calamari/version_data'));
        var file = File.write(path);
        file.writeString(data);
        file.close();
        return Json.parse(data);
    }

    static function getMinecraftVersionManifest():VersionManifest {
        if (FileSystem.exists(getFullPath('~/.calamari/minecraft_version_manifest.json'))) {
            var stat = FileSystem.stat(getFullPath('~/.calamari/minecraft_version_manifest.json'));
            if (Date.now().getTime() - stat.mtime.getTime() < CACHE_EXPIRE_TIME && !flags.contains('nocache')) {
                return Json.parse(File.getContent(getFullPath('~/.calamari/minecraft_version_manifest.json')));
            }
        }
        var data = Http.requestUrl('https://launchermeta.mojang.com/mc/game/version_manifest.json');
        if (!FileSystem.exists(getFullPath('~/.calamari/'))) FileSystem.createDirectory(getFullPath('~/.calamari'));
        var file = File.write(getFullPath('~/.calamari/minecraft_version_manifest.json'));
        file.writeString(data);
        file.close();
        return Json.parse(data);
    }

    static function getMinecraftVersionList():Array<String> {
        var data = getMinecraftVersionManifest();
        
        var versions = [];

        for (ver in data.versions) {
            versions.push(ver.id);
        }

        versions.reverse();

        return versions;


        //trace(File.read('~/.calamari/minecraft_version_manifest.json').readAll().toString());
    }

    static var host(get, never):HostOS;
    static var _host:Null<HostOS>;

    static function get_host():HostOS {
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

    static function getExecutableName(target:SysTarget, windows:Bool=false, debug:Bool=false) {
        var name = 'Cuttlefish';
  
        if (debug) name += '.dev';
        name += '-${File.getContent('./version.txt')}';

        var hash:String = null;
        var proc = new Process('git', ['rev-parse', 'HEAD']);
        if (proc.exitCode() != 0) {
            var msg = proc.stderr.readAll().toString();
            log('error getting commit hash: $msg');
        } else name += '-${proc.stdout.readLine().substr(0, 6)}';
  
        name += switch target {
           case Cpp: '.cpp';
           case Csharp: '.cs';
           case Hashlink: '.hl';
           case Java: '.jar';
           case Nodejs: 'js';
           case Jvm: '.jvm.jar';
           case Neko: '.n';
           case Python: '.py';
           default: throw 'unknown target';
        }
  
        if ((target == Cpp || target == Csharp) && windows) name += '.exe';
        return name;
     }

    static function getCompletions(input:String):Array<String> {
        flags.remove('nocache');
        var args = input.split(' ');
        args.shift();

        var targetCompletionAliases = [for (key in targetAliases.keys()) key];
        targetCompletionAliases.remove('n');
        targetCompletionAliases.remove('py');

        if (args[args.length-1].startsWith('-')) {
            return [for (flag in knownFlags) '-$flag'];
        }

        if (args.length == 1) return rootCommandList;
        if (args.length == 2) {
            var arg1 = args[0];
            switch arg1 {
                case 'help': return helpTopicList.concat(rootCommandList);
                case 'buildall': return [];
                case 'test': return targetCompletionAliases;
                case 'run': return targetCompletionAliases;
                case 'datagen':
                    var input = args[1];

                    return getMinecraftVersionList();
            }
        }
        if (args.length >= 2) {
            if (args[0] == 'build') {
                var targetArgs = args.copy();
                targetArgs.shift();
                var targetList:Array<SysTarget> = [];

                for (arg in targetArgs) {
                    if (targetAliases.exists(arg)) {
                        if (!targetList.contains(targetAliases.get(arg))) {
                            targetList.push(targetAliases.get(arg));
                        }
                    }
                }

                var unusedTargetAliases = [for (alias in targetCompletionAliases) if (!targetList.contains(targetAliases.get(alias))) alias];
                return unusedTargetAliases;
            }
        }
        return [];
    }

    static function getScriptPath():String {
        return new Path(Sys.programPath()).dir;
    }

    static function main() {
        parseCommand();

        if (options.exists('autocomplete')) {
            var completions = getCompletions(options.get('autocomplete'));
            var output = completions.join('\n'); 
            log(output);
            Sys.exit(cast OK);
        }

        if (flags.contains('setup')) {
            log(Macros.fileContent('./scripts/completion.zsh'));
            Sys.exit(cast OK);
        }

        if (args.length == 0) {
            log('Calamari ${Macros.versionString()} - ${Macros.commitHash().substr(0, 6)}');
            log('    No command provided - use `calamari help` for usage');
            Sys.exit(cast OK);
        }

        log('Calamari ${Macros.versionString()} - ${Macros.commitHash().substr(0, 6)}');
        switch (args[0]) {
            case 'install':
                switch (host) {
                    case Windows:
                        log('    To install calamari, put the exe in a folder on your PATH.');
                    case Linux:
                        var proc = new Process('sudo', ['cp', Sys.programPath(), '/usr/bin/calamari']);
                        var exit = proc.exitCode();
                        if (exit != 0) {
                            var out = proc.stderr.readAll().toString();
                            log('Error copying file: $out');
                        }
                    case Mac:
                        log('    To install calamari, put the exectuable somewhere that your shell can find it.');
                    case Unknown:
                        log('    Unknown platform! Can\'t provide install instructions.');
                }
            case 'build':
                var targetArgs = args.copy();
                targetArgs.shift();
                var targetList:Array<SysTarget> = [];

                for (arg in targetArgs) {
                    if (targetAliases.exists(arg)) {
                        if (!targetList.contains(targetAliases.get(arg))) {
                            targetList.push(targetAliases.get(arg));
                        }
                    }
                }

                for (target in targetList) {
                    var args = ['-p=src', '-m=Main', '-L=uuid'];
                    var copyTo = './out/${getExecutableName(target, host==Windows, flags.contains('debug'))}';
                    switch target {
                        case Cpp:
                            args.push('--cpp=$CPP');
                            args.push('--cmd=cp ${CPP}Main${(host == Windows ? '.exe' : '')} $copyTo');
                        case Csharp:
                            args.push('--cs=$CSHARP');
                            args.push('--cmd=cp ${CPP}Main${(host == Windows ? '.exe' : '')} $copyTo');
                        case Hashlink:
                            args.push('--hl=${HASHLINK}Cuttlefish.hl');
                            args.push('--cmd=cp ${HASHLINK}Cuttlefish.hl $copyTo');
                        case Java:
                            args.push('--java=$JAVA');
                            args.push('--cmd=cp ${JAVA}Main${flags.contains('debug') ? '-Debug' : ''}.jar $copyTo');
                        case Jvm:
                            args.push('--jvm=${JVM}Cuttlefish.jar');
                            args.push('--cmd=cp ${JVM}Cuttlefish.jar $copyTo');
                        case Nodejs:
                            log('    Error: NodeJS is currently not supported due to `hxnodejs` not supporting threads.');
                        case Neko:
                            args.push('--neko=${NEKO}Cuttlefish.n');
                            args.push('--cmd=cp ${NEKO}Cuttlefish.n $copyTo');
                        case Python:
                            args.push('--python=${PYTHON}Cuttlefish.py');
                            args.push('--cmd=cp ${PYTHON}Cuttlefish.py $copyTo');
                    }
                    runHaxe(args);
                }
                
                //runHaxe(['-p=src',  '-m=Calamari', '-cpp=./build/', '--cmd=cp ./build/Calamari ./calamari2']);
                // build command
            case 'datagen':
                if (args.length == 1) {
                    log('    No Minecraft version provided. See `calamari help datagen` if you dont know how to use this command.');
                    Sys.exit(0);
                }

                downloadMinecraftVersion(args[1]);
                //getMinecraftVersions();
                // data generator command
            case 'run':
                // run command
            case 'test':
                // build -> datagen -> run shorthand
            case 'buildall':
                // build executables for all targets
            case 'help':
                log('Calamari ${Macros.versionString()} - ${Macros.commitHash().substr(0, 6)} - Help');
                switch (args[1]) {
                    case 'commands':
                        log('List of commands:
    build <list of targets> - Builds Cuttlefish for the specified target
    datagen [version] - Attempts to download the server jar for the provided Minecraft version and runs its Data Generators. If you do not provide a version it defaults to 1.19.0
    run <target> - Finds the most recent build of Cuttlefish and runs it if one exists
    test <target> [version] - Builds, generates data for, and then runs Cuttlefish for the specified target. Uses the latest supported version of Minecraft by default
    buildall - Builds Cuttlefish for all targets automatically
    help - Basic help command for how to use Calamari');
                    case 'targets':
                        log('List of targets and the available aliases to refer to them:
    C++: cpp, c++, cplusplus, hxcpp
    C#: cs, c#, csharp, hxcs
    Hashlink: hl, hashlink
    Java: java, hxjava
    Java Bytecode: jvm
    NodeJS: js, node, nodejs, hxnodejs. Note: NodeJS is currently not supported due to a lack of thread support in `hxnodejs`.
    Neko: neko, n
    Python: python, py');
                    case 'build':
                        log('Build Command Usage:
    calamari build <targets>
Description:
    Builds Cuttlefish for the specified targets. See `calamari help targets` for a list of available targets.
Arguments:
    targets - A list of at least 1 target
Examples:
    calamari build cpp hl jvm n
        Builds Cuttlefish as a native executable with C++, a Hashlink bytecode file, a jar file, and a Neko bytecode file');
                    case 'datagen':
                    
                    case 'run':
                        log('Run Command Usage:
    calamari run <target>
Description:
    Runs the latest locally available build of Cuttlefish for the specified target.
Arguments:
    target - a single target to search for
Examples:
    calamari run cs
        Will look for a compiled C# build, and run it if it finds one.');
                    case 'test':
                        log('Test Command Usage:
    calamari test <target> [version]
Description:
    Builds Cuttlefish for the specified target, generates data for the specified Minecraft version, then runs it.
Arguments:
    target - a single target to build for
    version - optional argument - the Minecraft version to generate data for, which will also be the version Cuttlefish will host a server for
Examples:
    calamari test cpp
        Will build a native executable for Cuttlefish, then generate Minecraft 1.19.0 data, then run the Cuttlefish executable
    calamari test java 1.18.2
        Will build a jar file for Cuttlefish, generate Minecraft 1.18.2 data, then run the Cuttlefish jar with `java`');
                    case 'buildall':
                        log('buildall Command Usage:
    calamari buildall
Description:
    Builds Cuttlefish for all targets automatically.');
                    case 'help':
                        log('Basic help command. See `calamari help` for actual help.');
                    default:
                        log('Calamari is a utility for building and running Cuttlefish.
Use `calamari help <page>` to see more about a certain topic.
You can also use `calamari help <command>` to see more about a certain command.
If you just want to build a Cuttlefish executable, you can use `calamari build cpp`.
List of help pages:
    commands - List of available commands
    targets - List of available targets and some details about each');
                }
            default:
                log('Unknown command ${args[0]}');
                Sys.exit(cast UnknownCommand);

        }
    }

    static function parseArgs(all:Array<String>):{flags:Array<String>, args:Array<String>, options:Map<String, String>} {
        return {flags: [], args: [], options: []};
    }

    static function parseCommand() {
        var all = Sys.args();

        var pastArgs = false;

        for (arg in all) {
            if (arg.startsWith('--')) {
                pastArgs = true;
                var eqPos = arg.indexOf('=');
                if (eqPos < 0) {
                    log('Invalid Arguments');
                    Sys.exit(cast InvalidArguments);
                }
                var key = arg.substr(2, arg.indexOf('=')-2);
                var value = arg.substr(arg.indexOf('=')+1);
                if (options.exists(key)) options.set(key, options.get(key) + ' $value');
                else options.set(key, value);
            } else if (arg.startsWith('-')) {
                pastArgs = true;
                if (flags.contains(arg.substr(1))) {
                    log('Duplicate flag: $arg');
                    Sys.exit(cast DuplicateFlag);
                }
                flags.push(arg.substr(1));
            } else {
                if (pastArgs) {
                    log('Command Error');
                    Sys.exit(cast InvalidArguments);
                }

                args.push(arg);
            }
        }
    }
}