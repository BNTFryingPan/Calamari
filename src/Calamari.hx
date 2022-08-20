package;

import sys.io.FileOutput;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import haxe.Http;
import haxe.io.Path;
import sys.io.Process;
import ProjectFile;
import MinecraftManifests;
using StringTools;

enum abstract ExitCode(Int) {
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
    var NEKO = 'neko/';
    var PYTHON = 'python/';
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

enum HostArch {
    ArmV6;
    ArmV7;
    X86;
    X64;
}
class Calamari {
    public static function log(text:String) {
        if (!options.exists('autocomplete')) Sys.println(text);
        if (logFileOutput != null) {
            logFileOutput.writeString('$text\n');
            logFileOutput.flush();
        }
    }

    public static function error(text:String) {
        log('\x1b[31;1m    Error:\x1b[0m\x1b[1m $text\x1b[0m');
    }

    public static var flags:Array<String> = [];
    public static var options:Map<String, String> = [];
    public static var args:Array<String> = [];

    public static function runHaxe(args:Array<String>) {
        var proc = new Process('haxe', args);
        var exit = proc.exitCode();
        if (exit != 0) {
            var out = proc.stderr.readAll().toString();
            log('Error running Haxe: $out');
        };
    }

    public static function exit(code:ExitCode) {
        logFileOutput.close();
        if (!FileSystem.exists(getFullPath('~/.calamari/logs/'))) FileSystem.createDirectory(getFullPath('~/.calamari/logs'));
        if (!(options.exists('autocomplete') || options.exists('version') || flags.contains('setup')))
            Sys.command('cp ${getFullPath('~/.calamari/latest.log')} ${getFullPath('~/.calamari/logs/${DateTools.format(Date.now(), "%Y-%m-%d_%H.%M.%S")}.log')}');
        Sys.exit(cast code);
    }

    public static final rootCommandList = ['build', 'datagen', 'run', 'test', 'buildall', 'help', 'install'];
    public static final helpTopicList = ['commands', 'targets'];
    public static final knownFlags = ['debug', 'quiet', 'verbose'];
    public static final knownOptions = [
        'version' => ['', 'hash', 'long', 'short'],
        'project' => ['@'],
        'out' => ['@'],
    ];
    public static final targetAliases = [
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

    public static function getFullPath(path:String):String {
        var pat = ~/~/;
        return FileSystem.absolutePath(pat.replace(path, Sys.getEnv('HOME')));
    }

    public static final CACHE_EXPIRE_TIME = 215e5; // 6 hours

    public static function downloadMinecraftVersion(version:String) {
        var verData = getPistionDataForVersion(version);

        if (verData.downloads.server == null) {
            error('Found data for Minecraft ${version}, but it does not include a server jar url. Unable to continue');
            exit(VersionExistsButNoServerJar);
        }

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

    public static function getPistionDataForVersion(version:String):VersionData {
        var manifest = getMinecraftVersionManifest();
        var targetVersion:MinecraftVersion = null;

        for (ver in manifest.versions) {
            if (ver.id == version) {
                targetVersion = ver;
                break;
            }
        }
        if (targetVersion == null) throw 'Could not find Minecraft version matching "$version" in manifest.';

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

    public static function getMinecraftVersionManifest():VersionManifest {
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

    public static function getCachedVersionListData():Array<{id:String, hasServerDownload:Bool}> {
        if (FileSystem.exists(getFullPath('~/.calamari/cached_version_data.json'))) return Json.parse(File.getContent(getFullPath('~/.calamari/cached_version_data.json')));
        var data = getMinecraftVersionManifest();
        var versions = [];

        for (ver in data.versions) {
            var verData = getPistionDataForVersion(ver.id);
            versions.push({id: verData.id, hasServerDownload: verData.downloads.server != null});
        }

        File.saveContent(getFullPath('~/.calamari/cached_version_data.json'), Json.stringify(versions));

        return versions;
    }

    public static function getMinecraftVersionList(requireServerJar=false):Array<String> {
        var data = getCachedVersionListData();
        var versions = [for (ver in data) if (ver.hasServerDownload) ver.id];
        log(versions.toString());
        return versions;
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
                var proc = new Process('uname', ['-m']);
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

    public static function getExecutableName(target:SysTarget, windows:Bool=false, debug:Bool=false) {
        var name = 'Cuttlefish';
  
        if (debug) name += '.dev';
        name += '-${File.getContent('./version.txt')}';

        var hash:String = null;
        var proc = new Process('git', ['rev-parse', 'HEAD']);
        if (proc.exitCode() != 0) {
            var msg = proc.stderr.readAll().toString();
            error('Unable to get commit hash: $msg');
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

        if (target == Cpp || target == Csharp) {
            name += switch (arch) {
                case ArmV6: '.armv6';
                case ArmV7: '.armv7';
                case X86: '.x86';
                case X64: '.x64';
            }

            if (windows) name += '.exe';
        }

        return name;
    }

    public static function getVersionCompletions(input:String):Array<String> {
        log('generating version completions for $input');
        var split = ~/[-._ ]/g;
        var snapshotRegex = ~/([1-9][0-9])w([0-5][0-9])([a-z])/;

        var inputParts = split.split(input);
        var versions = getMinecraftVersionList(true);
        
        var validVersionPartsForThisPart = [];

        for (ver in versions) {
            var lower = ver.toLowerCase();
            var parts = split.split(lower);
            if (parts.length < inputParts.length) continue;

            if (lower.substring(0, input.length) != input) continue;
            if (snapshotRegex.match(lower)) continue;

            var whatToPutInList = split.split(ver.substring(input.length))[0];

            if (validVersionPartsForThisPart.contains(whatToPutInList)) continue;
            validVersionPartsForThisPart.push(whatToPutInList);
        }
        
        return validVersionPartsForThisPart.map(v -> '$input$v');
    }

    public static function getCompletions(input:String):Array<String> {
        log(input);
        flags.remove('nocache');
        var args = input.split(' ');
        args.shift();
        log('${args.length} $args');
        var targetCompletionAliases = [for (key in targetAliases.keys()) key];
        targetCompletionAliases.remove('n');
        targetCompletionAliases.remove('py');
        targetCompletionAliases.remove('c#');

        if (args[args.length-1].startsWith('-')) {
            if (args[args.length-1].startsWith('--')) {
                return [
                    for (opt => values in knownOptions)
                        for (value in values)
                            if (value == '') '--$opt'
                            else if (value == '@') '--$opt='
                            else '--$opt=$value'
                ];
            }
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
                    return getVersionCompletions(args[1].toLowerCase());
                    
            }
        }
        log('"${args[0]}" ${args[0] == "test"}');
        if (args.length == 3 && args[0] == 'test') {
            return getVersionCompletions(args[2].toLowerCase());
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

    public static function getScriptPath():String {
        return new Path(Sys.programPath()).dir;
    }

    public static var logFileOutput:FileOutput;

    public static function build(targets:Array<SysTarget>) {
        for (target in targets) {
            var args = ['-p=src', '-m=Main', '-L=uuid'];
            if (flags.contains('debug')) args.push('--debug');
            var copyTo = './out/${getExecutableName(target, host==Windows, flags.contains('debug'))}';
            switch target {
                case Cpp:
                    log('Building C++');
                    args.push('--cpp=$CPP');
                    args.push('--cmd=cp ${CPP}Main${(host == Windows ? '.exe' : '')} $copyTo');
                case Csharp:
                    log('Building C#');
                    args.push('--cs=$CSHARP');
                    args.push('--cmd=cp ${CPP}Main${(host == Windows ? '.exe' : '')} $copyTo');
                case Hashlink:
                    log('Building Hashlink');
                    args.push('--hl=${HASHLINK}Cuttlefish.hl');
                    args.push('--cmd=cp ${HASHLINK}Cuttlefish.hl $copyTo');
                case Java:
                    log('Building Java');
                    args.push('--java=$JAVA');
                    args.push('--cmd=cp ${JAVA}Main${flags.contains('debug') ? '-Debug' : ''}.jar $copyTo');
                case Jvm:
                    log('Building Java Bytecode');
                    args.push('--jvm=${JVM}Cuttlefish.jar');
                    args.push('--cmd=cp ${JVM}Cuttlefish.jar $copyTo');
                case Nodejs:
                    error('NodeJS is currently not supported due to `hxnodejs` not supporting threads.');
                    continue;
                case Neko:
                    log('Building Neko');
                    args.push('--neko=${NEKO}Cuttlefish.n');
                    args.push('--cmd=cp ${NEKO}Cuttlefish.n $copyTo');
                case Python:
                    log('Building Python');
                    args.push('--python=${PYTHON}Cuttlefish.py');
                    args.push('--cmd=cp ${PYTHON}Cuttlefish.py $copyTo');
            }
            runHaxe(args);
        }
    }

    public static function main() {
        if (!FileSystem.exists(getFullPath('~/.calamari/'))) FileSystem.createDirectory(getFullPath('~/.calamari'));
        logFileOutput = File.write(getFullPath('~/.calamari/latest.log'));
        parseCommand();

        if (options.exists('autocomplete')) {
            var completions = getCompletions(options.get('autocomplete'));
            var output = completions.join('\n'); 
            for (choice in completions) {
                Sys.println(choice);
            }
            //log(output);
            exit(OK);
        }

        if (options.exists('version')) {
            var verType = options.get('version').toLowerCase();
            switch verType {
                case 'hash': Sys.println(flags.contains('full') ? Macros.commitHash() : Macros.commitHash().substr(0, 6));
                case 'short': Sys.println(Macros.versionString());
                case 'long': Sys.println('Calamari v${Macros.versionString()}-${Macros.commitHash().substr(0, 6)}');
                default: Sys.println('Calamari ${Macros.versionString()}');
            }
            exit(OK);
        }

        if (flags.contains('setup')) {
            if (!FileSystem.exists(getFullPath('~/.calamari/'))) FileSystem.createDirectory(getFullPath('~/.calamari'));
            var out = File.write(getFullPath('~/.calamari/completion.sh'));
            out.writeString(Macros.fileContent('./scripts/completion.zsh'));
            out.close();
            Sys.println(getFullPath('~/.calamari/completion.sh'));
            exit(OK);
        }

        if (args.length == 0) {
            log('Calamari ${Macros.versionString()} - ${Macros.commitHash().substr(0, 6)}');
            log('    No command provided - use `calamari help` for usage');
            exit(OK);
        }

        log('Calamari ${Macros.versionString()} - ${Macros.commitHash().substr(0, 6)}');
        switch (args[0]) {
            case 'install':
                log('    Attempting to install Calamari command...');
                switch (host) {
                    case Windows:
                        log('    To install calamari, put the exe in a folder on your PATH.');
                    case Linux:
                        var proc = new Process('sudo', ['cp', Sys.programPath(), '/usr/bin/calamari']);
                        var exit = proc.exitCode();
                        if (exit != 0) {
                            var out = proc.stderr.readAll().toString();
                            log('    Error copying file: $out');
                            log('Failed to install Calamari');
                        } else log('Succesfully installed Calamari command. Add `source $(calamari -setup)` to your `~/.bashrc` or `~/.zshrc` to get completions');
                    case Mac:
                        log('    To install calamari, put the exectuable somewhere that your shell can find it.');
                    case Unknown:
                        log('    Unknown platform! Can\'t provide install instructions.');
                }
            case 'build':
                var project = ProjectFile.getProjectData();
                var targetArgs = args.copy();
                targetArgs.shift();
                var targetList:Array<SysTarget> = [];

                for (arg in targetArgs) {
                    if (targetAliases.exists(arg)) {
                        if (!targetList.contains(targetAliases.get(arg))) {
                            var target = targetAliases.get(arg);
                            if (!project.supportsTarget(target)) {
                                error('That target is not supported by this project');
                                continue;
                            }
                            targetList.push(target);
                        }
                    }
                }

                build(targetList);
                
                //runHaxe(['-p=src',  '-m=Calamari', '-cpp=./build/', '--cmd=cp ./build/Calamari ./calamari2']);
                // build command
            case 'datagen':
                if (args.length == 1) {
                    log('    No Minecraft version provided. See `calamari help datagen` if you dont know how to use this command.');
                    exit(OK);
                }

                log('    Downloading data for Minecraft ${args[1]}');
                downloadMinecraftVersion(args[1]);
                //getMinecraftVersions();
                // data generator command
            case 'run':
                // run command
            case 'test':
                // build -> datagen -> run shorthand
            case 'buildall':
                // build executables for all targets
                build([Cpp, Csharp, Hashlink, Neko, Java, Jvm, Python]);
            case 'help':
                //log('Calamari ${Macros.versionString()} - ${Macros.commitHash().substr(0, 6)} - Help');
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
                    case null:
                        log('Calamari is a utility for building and running Cuttlefish.
Use `calamari help <page>` to see more about a certain topic.
You can also use `calamari help <command>` to see more about a certain command.
If you just want to build a Cuttlefish executable, you can use `calamari build cpp`.
List of help pages:
    commands - List of available commands
    targets - List of available targets and some details about each');
                    default:
                        if (rootCommandList.contains(args[1]))
                            log('    No help page found for `calamari ${args[1]}`!');
                        else
                            error('Unknown help topic. Use `calamari help` to see what help topics you can view.');
                }
            default:
                log('Unknown command ${args[0]}');
                exit(UnknownCommand);

        }
        exit(OK);
    }

    public static function parseArgs(all:Array<String>):{flags:Array<String>, args:Array<String>, options:Map<String, String>} {
        return {flags: [], args: [], options: []};
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