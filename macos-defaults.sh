#!/bin/bash
# macOSのシステム設定をdefaultsコマンドで反映する。新しいMacの初回セットアップ時に1回実行する
set -eu

# キーボード
# キーリピートを最速に
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
# 自動テキスト置換（大文字化・ピリオド・スマート引用符・スマートダッシュ・スペル修正）をOFF
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
# F1〜F12を標準のファンクションキーとして使う
defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true
# Ctrl+Spaceの「前の入力ソースを選択」を無効化し、エディタ側のCtrl+Spaceを使えるようにする。入力ソースの切り替えはKarabinerの英数/かなキーで行う
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 \
  '<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>262144</integer></array><key>type</key><string>standard</string></dict></dict>'
# 「次のウィンドウを操作対象にする」をCommand+F1に変更する（デフォルトはCommand+`）
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 27 \
  '<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>122</integer><integer>9437184</integer></array><key>type</key><string>standard</string></dict></dict>'

# トラックパッド
# タップでクリック（内蔵・Bluetooth・ログイン画面）
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
# ポインタの速度を速く
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 2
# ナチュラルスクロールをOFF
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# Dock
defaults write com.apple.dock autohide -bool true

# Finder
# 隠しファイルを表示し、デフォルトを列表示にする
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder FXPreferredViewStyle -string clmv

# スクリーンショット
# 保存先を~/Downloadsにし、撮影後のサムネイルプレビューを出さない
defaults write com.apple.screencapture location -string "$HOME/Downloads"
defaults write com.apple.screencapture show-thumbnail -bool false

# アクセシビリティ
# 修飾キー＋スクロールで画面ズーム
# com.apple.universalaccessへの書き込みは、実行するターミナルにフルディスクアクセスが無いと失敗する
if ! defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true 2>/dev/null; then
  echo "警告: ズーム設定を書き込めなかった。「システム設定 > アクセシビリティ > ズーム > スクロールジェスチャと修飾キーを使ってズーム」を手動でONにする" >&2
fi

killall Dock Finder SystemUIServer
echo "キーボード・トラックパッドの設定を完全に反映するには再ログインが必要"
