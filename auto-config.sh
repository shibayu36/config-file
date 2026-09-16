#!/bin/sh
ln -s ~/development/config-file/.zprofile  ~/
ln -s ~/development/config-file/.zshenv ~/
ln -s ~/development/config-file/.zshrc ~/
ln -s ~/development/config-file/.gitignore ~/
ln -s ~/development/config-file/.proverc ~/
ln -s ~/development/config-file/.my.cnf ~/
ln -s ~/development/config-file/.zsh ~/
ln -s ~/development/config-file/.inputrc ~/
ln -s ~/development/config-file/.tmux.conf ~/
ln -s ~/development/config-file/.gitconfig ~/
ln -s ~/development/config-file/.tigrc ~/
mkdir -p ~/Library/Application\ Support/lazygit
ln -s ~/development/config-file/lazygit/config.yml ~/Library/Application\ Support/lazygit/config.yml
mkdir -p ~/.config
ln -s ~/development/config-file/karabiner ~/.config/
ln -sn ~/development/config-file/KeyBindings ~/Library/KeyBindings
mkdir -p ~/Library/Application\ Support/Code/User
ln -s ~/development/config-file/vscode/settings.json ~/Library/Application\ Support/Code/User/settings.json
ln -s ~/development/config-file/vscode/keybindings.json ~/Library/Application\ Support/Code/User/keybindings.json
ln -s ~/development/config-file/vscode/snippets ~/Library/Application\ Support/Code/User/
ln -s ~/development/config-file/.vscode-powertools ~/
ln -s ~/development/config-file/.textlintrc ~/
ln -s ~/development/config-file/.asdfrc ~/
ln -s ~/development/config-file/starship.toml ~/.config/
mkdir -p ~/Library/Application\ Support/Cursor/User
ln -s ~/development/config-file/cursor/settings.json ~/Library/Application\ Support/Cursor/User/settings.json
ln -s ~/development/config-file/cursor/keybindings.json ~/Library/Application\ Support/Cursor/User/keybindings.json
ln -s ~/development/config-file/vscode/snippets ~/Library/Application\ Support/Cursor/User/
# Claude／Codexの設定ディレクトリにはローカルデータもあるため、管理対象だけをリンクする。
mkdir -p ~/.claude/agents ~/.claude/skills ~/.agents/skills
ln -sn ~/development/config-file/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -sn ~/development/config-file/claude/settings.json ~/.claude/settings.json
ln -sn ~/development/config-file/claude/keybindings.json ~/.claude/keybindings.json
ln -sn ~/development/config-file/claude/scripts ~/.claude/scripts
for item in ~/development/config-file/claude/agents/*; do
  ln -s "$item" ~/.claude/agents/
done
for item in ~/development/config-file/claude/skills/*; do
  ln -s "$item" ~/.claude/skills/
done
for item in ~/development/config-file/skills/*; do
  ln -s "$item" ~/.claude/skills/
  ln -s "$item" ~/.agents/skills/
done

ai_codex_home="${CODEX_HOME:-$HOME/.codex}"
mkdir -p "$ai_codex_home/agents" "$ai_codex_home/rules"
ln -sn ~/development/config-file/codex/AGENTS.md "$ai_codex_home/AGENTS.md"
ln -sn ~/development/config-file/codex/hooks.json "$ai_codex_home/hooks.json"
ln -sn ~/development/config-file/codex/keybindings.json "$ai_codex_home/keybindings.json"
ln -sn ~/development/config-file/codex/rules/common.rules "$ai_codex_home/rules/common.rules"
for item in ~/development/config-file/codex/agents/*.toml; do
  ln -s "$item" "$ai_codex_home/agents/"
done
# config.toml は Codex がローカル固有の値を書き込むためリンクせず、共通設定をマージする
~/development/config-file/bin/sync-codex-config
mkdir -p ~/.config/herdr
ln -s ~/development/config-file/herdr/config.toml ~/.config/herdr/config.toml
herdr integration install claude
herdr plugin install shibayu36/herdr-equalize-panes --yes
ln -s ~/development/config-file/deck ~/.config/
ln -s ~/development/config-file/.coderabbit.yml ~/
mkdir -p ~/Library/Application\ Support/com.mitchellh.ghostty
ln -s ~/development/config-file/ghostty/config ~/Library/Application\ Support/com.mitchellh.ghostty/config

#zsh関数群
ln -s ~/development/config-file/.zshrc.function ~/

#bin
mkdir -p ~/bin
ln -s ~/development/config-file/bin/* ~/bin/
