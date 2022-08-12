package;

using StringTools;

enum abstract ExitCode(Int) {
    var OK = 0;
    var InvalidArguments = 1;
    var DuplicateFlag = 2;
    var UnknownCommand = 3;
}

class Calamari {
    static function log(text:String) {
        Sys.println(text);
    }

    static var flags:Array<String> = [];
    static var options:Map<String, String> = [];
    static var args:Array<String> = [];

    static function main() {
        parseCommand();

        trace('flags: $flags');
        trace('options: $options');
        trace('args: $args');

        if (args.length == 0) {
            log('Calamari ${Macros.versionString()} - ${Macros.commitHash()}')
        }

        switch (args[0]) {
            case 'build':
                // build command
            case 'datagen':
                // data generator command
            case 'run':
                // run command
            case 'test':
                // build -> datagen -> run shorthand
            case 'buildall':
                // build executables for all targets
            default:
                log('Unknown command ${args[0]}');
                Sys.exit(cast UnknownCommand);

        }
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
                options.set(key, value);
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