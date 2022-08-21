#!/usr/bin/env bash

_calamari_complete_zsh() {
    local word completions
    word="$1"
    #echo ${(j. .)words} > ~/.calamari/words.txt
    completions="$(calamari -zsh --autocomplete=\"${(j. .)words}\")"
    reply=( "${(ps:\n:)completions}" )
}

_calamari_complete_bash() {
    local word="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=( $(compgen -W "$(calamari -bash --autocomplete="$COMP_LINE")" -- $word) )
}

if [ -n "$ZSH_VERSION" ]; then
    compctl -K _calamari_complete_zsh calamari
elif [ -n "$BASH_VERSION" ]; then
    complete -F _calamari_complete_bash calamari
fi