package;

import sys.io.FileOutput;
import haxe.io.Path;
import sys.io.File;
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

class Calamari {
    static function log(text:String) {
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
    static final allKnownAliases = [
        // C++
        'cpp',
        'c++',
        'cplusplus',
        'hxcpp',
        // C#
        'cs',
        'c#',
        'csharp',
        'hxcs',
        // Hashlink
        'hl',
        'hashlink',
        // Java
        'java',
        'hxjava',
        // JVM
        'jvm',
        // NodeJS
        'js',
        'node',
        'nodejs',
        'hxnodejs',
        // Neko
        'neko',
        // excluding the 'n' alias as on zsh with autosuggestions, typing `calamari test n` ends the suggestion, even though pressing enter still works
        // Python
        'python',
    ];

    static function getCompletions(input:String):Array<String> {
        var args = input.split(' ');
        args.shift();

        if (args[args.length-1].startsWith('-')) {
            return [for (flag in knownFlags) '-$flag'];
        }

        if (args.length == 1) return rootCommandList;
        if (args.length == 2) {
            var arg1 = args[0];
            switch arg1 {
                case 'help': return helpTopicList.concat(rootCommandList);
                case 'buildall': return [];
                case 'test': return allKnownAliases;
                case 'run': return allKnownAliases;
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

        switch (args[0]) {
            case 'build':
                runHaxe(['-p=src',  '-m=Calamari', '-cpp=./build/', '--cmd=cp ./build/Calamari ./calamari2']);
                // build command
            case 'datagen':
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