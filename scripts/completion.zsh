#!/usr/bin/env bash

_calamari_complete_zsh() {
    local word completions
    word="$1"
    completions="$(calamari --autocomplete=$words)"
    reply=( "${(ps:\n:)completions}" )
}

_calamari_complete_bash() {
    #COMPREPLY=()
    local word="${COMP_WORDS[COMP_CWORD]}"
    #local completions=""
    COMPREPLY=( $(compgen -W "$(calamari --autocomplete="$COMP_LINE")" -- $word) )
    #echo $COMPREPLY
    #echo $COMP_LINE
}

if [ -n "$ZSH_VERSION" ]; then
    compctl -K _calamari_complete_zsh calamari
elif [ -n "$BASH_VERSION" ]; then
    complete -F _calamari_complete_bash calamari
fi