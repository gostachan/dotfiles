alias rm='trash'

# docker
alias di="docker image"
alias dc="docker compose"
alias de="docker exec -it"
alias dl="docker logs -f"
alias dp="docker ps"

# git
alias ga='git add'
alias gb='git branch'
alias gc='git commit -m'
alias gca='git commit --amend'
alias gd='git diff'
alias gl='git log'
alias glol='git log --oneline'
alias gm='git merge'
alias gst='git status'
alias gsw='git switch'
alias gpl='git pull'
alias gps='git push'
alias gw='git worktree'
alias gwa='git worktree add'
alias gwl='git worktree list'
alias gwr='git worktree remove'

# tmux
alias t='tmux'
alias tl='tmux ls'
alias ta='tmux a'
alias tat='tmux a -t'
alias tks='tmux kill-server'
alias trst='tmux rename-session -t'

# vim
alias v='nvim'
alias vi='nvim'
alias vim='nvim'
alias vv='nvim'

# rust
alias carb='cargo build'
alias carc='cargo check'
alias carn='cargo new'
alias carr='cargo run'
alias ron='rustup override set nightly'

# cpp
alias gpp='g++ -std=c++20'

# terraform
alias ter="terraform"

# marp
alias marpp="marp --preview"

# etc
alias reboot_ghostty='killall ghostty && open -a ghostty'
alias mkdir='mkdir -p'
alias rmds="find . -name '.DS_Store' -type f -delete"
alias lls="(ls -al --color=always | grep '^d' | sort) && (ls -al --color=always | grep -v '^d' | sort)"
alias fixclock='sudo sntp -sS time.google.com'
alias mysqlp='mysql -h mysql -u user -p practice'

#edit
alias ezsh='nvim ~/.zshrc && source ~/.zshrc'
alias etmux='vim ~/.tmux.conf && tmux display-message "Reloaded tmux.conf" && tmux source-file ~/.tmux.conf'

# claude
alias clsp='claude --dangerously-skip-permissions'

# codex
alias cosp='codex --ask-for-approval never'

# python
alias p='python3'
