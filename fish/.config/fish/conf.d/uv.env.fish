# uv's standalone installer writes ~/.local/bin/env.fish, but here uv comes
# from mise and that file does not exist. Only source it when present so a
# missing file no longer errors on every fish startup.
test -f "$HOME/.local/bin/env.fish"; and source "$HOME/.local/bin/env.fish"
