# Calamari
Calamari is a (work in progress) project management utility for Haxe. It helps manage libraries and Haxe compiler arguments.

Originally created for building [Cuttlefish](https://github.com/LeotomasMC/Cuttlefish), it will be able to be used for other projects as well.

# Project File

Calamari uses a JSON file to define project settings. When you run `calamari`, it will look upwards through directories until it finds one that has one or more files with a `.calamari` extension. If it finds more than one, and by default it will check if there is a file named `project.calamari` to use, otherwise it will fail. If you have multiple project files in a directory, you can specify which project file to use with the `--project` option. You can provide a full file path, relative file path, or just a file name. If you just provide the file name, it will do the same upwards search until it finds a file with the name you gave.

The `src/ProjectFile.hx` file documents most of the options you can configure, but here are some of the important ones:
<!-- i should document this better -->
- `projectName`: the name of the project
- `mainClass`: the main class file, same as `--main` in hxml
- `classPaths`: an array of folders to include in compilation. same as having a `--class-path` arg for each entry

There are more things you can change, including per-target settings, custom flags, etc. which are somewhat documented in the source file. 

### Completions

Calamari supports tab completions in `zsh` and `bash`. adding the following to your `.zshrc` or `.bashrc` should allow completions/suggestions to show up:
```sh
source $(calamari -setup)
```
kind of jank until i find a better way to do it (also i only tested them on zsh)