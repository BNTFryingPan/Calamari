_calamari_complete_zsh() {
    local word completions
    word="$1"
    completions="${calamari --autocomplete=${word}}"
    reply=("${(ps:\n:)completions}")
}

compctl -K _calamari_complete_zsh calamari