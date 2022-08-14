package;

#if !display
import sys.FileSystem;
import sys.io.File;
#end

class Macros {
    public static macro function versionString() {
        var str = 'Unknown';
        #if !display
        if (FileSystem.exists('./version.txt'))
            str = File.getContent('./version.txt');
        #end
        return macro $v{str};
    }

    public static macro function commitHash() {
        var hash = '';
        #if !display
        var proc = new sys.io.Process('git', ['rev-parse', 'HEAD']);
        if (proc.exitCode() != 0) {
            var msg = proc.stderr.readAll().toString();
            var pos = haxe.macro.Context.currentPos();
            haxe.macro.Context.error("Failed to get git commit hash: $msg", pos);
        }

        hash = proc.stdout.readLine();
        #end
        return macro $v{hash};
    }

    public static macro function fileContent(path:String) {
        var content = '';
        #if !display
        if (FileSystem.exists(path)) content = File.getContent(path);
        #end
        return macro $v{content};
    }
}