# Calamari
Utility for building and running [Cuttlefish](https://github.com/LeotomasMC/Cuttlefish).

## completions
Calamari supports tab completions in `zsh` and `bash`. adding the following to your `.zshrc` or `.bashrc` should allow completions/suggestions to show up:
```sh
calamari -setup > ~/calamari-setup.sh
source ~/calamari-setup.sh
rm ~/calamari-setup.sh
```
kind of jank until i find a better way to do it