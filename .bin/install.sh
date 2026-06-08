set -ue

helpmsg() {
  command echo "Usage: $0 [--debug | -d] [--help | -h]" 0>&2
  command echo ""
}

link_file() {
  local src="$1" dst="$2"
  if [[ -L "$dst" ]]; then
    command rm -f "$dst"
  elif [[ -e "$dst" ]]; then
    command mv "$dst" "$HOME/.dotbackup/"
  fi
  command ln -snf "$src" "$dst"
}

link_to_homedir() {
  command echo "backup old dotfiles..."
  if [ ! -d "$HOME/.dotbackup" ];then
    command echo "$HOME/.dotbackup not found. Auto Make it"
    command mkdir "$HOME/.dotbackup"
  fi

  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  local dotdir=$(dirname ${script_dir})
  if [[ "$HOME" != "$dotdir" ]];then
    for f in $dotdir/.??*; do
      local name="$(basename "$f")"
      [[ "$name" == ".git" ]] && continue
      if [[ -d "$f" && -d "$HOME/$name" && ! -L "$HOME/$name" ]]; then
        # 既存の実ディレクトリがある場合はファイル単位でリンク
        command mkdir -p "$HOME/$name"
        for inner in "$f"/*; do
          link_file "$inner" "$HOME/$name/$(basename "$inner")"
        done
      else
        link_file "$f" "$HOME/$name"
      fi
    done
  else
    command echo "same install src dest"
  fi
}

while [ $# -gt 0 ];do
  case ${1} in
    --debug|-d)
      set -uex
      ;;
    --help|-h)
      helpmsg
      exit 1
      ;;
    *)
      ;;
  esac
  shift
done

link_to_homedir
git config --global include.path "~/.gitconfig_shared"
command echo -e "Install completed!!!!"
