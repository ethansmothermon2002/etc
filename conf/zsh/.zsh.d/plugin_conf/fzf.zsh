# ┬─┐┬ ┐┌─┐┌─┐┐ ┬  ┬─┐o┌┐┐┬─┐┬─┐┬─┐
# ├─ │ │┌─┘┌─┘└┌┘──├─ │││││ │├─ │┬┘
# ┆  ┆─┘└─┘└─┘ ┆   ┆  ┆┆└┘┆─┘┴─┘┆└┘
# OPTIONS:{{{
# ---------------
# plugin handled externally with vim-plug
#[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Respecting .gitignore, .hgignore, and svn:ignore
# Setting ag as the default source for fzf
export FZF_DEFAULT_COMMAND='rg --hidden --smart-case --ignore-file ~/.globalignore --files'

export FZF_DEFAULT_OPTS='
  --color fg:15,bg:0,hl:2,fg+:15,bg+:235,hl+:10
  --color info:11,prompt:5,spinner:11,pointer:10,marker:208,header:15
'
export FZF_COMPLETION_TRIGGER='~~'

# To apply the command to CTRL-T as well
# export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"
#}}}
# COMMAND HISTORY: {{{
# -------------------

# fh - repeat history
fhist() {
  print -z $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf-tmux +s --tac | sed 's/ *[0-9]* *//')
}
#}}}
# CHANGING DIRECTORY {{{
# ---------------------

# fd - including hidden directories
fdir() {
  local dir
  dir=$(find ${1:-.} -type d 2> /dev/null | fzf-tmux +m) && cd "$dir"
}

# cdf - cd into the directory of the selected file
cdf() {
   local file
   local dir
   file=$(fzf +m -q "$1") && dir=$(dirname "$file") && cd "$dir"
}

# cf - fuzzy cd from anywhere
# ex: cf word1 word2 ... (even part of a file name)
# zsh autoload function
cf() {
  local file

  file="$(locate -Ai -0 $@ | grep -z -vE '~$' | fzf --read0 -0 -1)"

  if [[ -n $file ]]
  then
     if [[ -d $file ]]
     then
        cd -- $file
     else
        cd -- ${file:h}
     fi
  fi
}

#}}}
# KILL {{{
# -----------
fkill() {
  pid=$(ps -ef | sed 1d | fzf-tmux -m | awk '{print $2}')

  if [ "x$pid" != "x" ]
  then
    kill -${1:-9} $pid
  fi
}
#}}}
# OPENING FILES {{{
# ---------------

# Fuzzy match file and open with emacsclient
e() {
  if [ "$#" -ne 0 ]; then
    emacsclient -nw $@
  else
    local file
    file=$(fzf-tmux --query="$1")
    [ -n "$file" ] && emacsclient -nw "$file"
  fi
}

# Fuzzy match file and open with vim
# If passed an argument, open that file in vim, otherwise fzf seach from CWD
v() {
  if [ "$#" -ne 0 ]; then
    vim $@
  else
    local file
    file=$(fzf-tmux --query="$1")
    [ -n "$file" ] && vim -- "$file"
  fi
}

# To to org folder and open match
o() {
  local file
  ( cd ~/org && file=$(fzf-tmux --query="$1")  &&
    [ -n "$file" ] && emacsclient -nw "$file" && popd)
}

# vf - fuzzy open with vim from anywhere
# ex: vf word1 word2 ... (even part of a file name)
# zsh autoload function
ef() {
  local files

  files=(${(f)"$(locate -Ai -0 $@ | grep -z -vE '~$' | fzf-tmux --read0 -0 -1 -m)"})

  if [[ -n $files ]]
  then
     emacsclient -nw -- $files
     print -l $files[1]
  fi
}

#}}}
# GIT {{{
# ---------

# fco - checkout git branch/tag
fco() {
  local tags branches target
  tags=$(
    git tag | awk '{print "\x1b[31;1mtag\x1b[m\t" $1}') || return
  branches=$(
    git branch --all | grep -v HEAD             |
    sed "s/.* //"    | sed "s#remotes/[^/]*/##" |
    sort -u          | awk '{print "\x1b[34;1mbranch\x1b[m\t" $1}') || return
  target=$(
    (echo "$tags"; echo "$branches") |
    fzf-tmux -l30 -- --no-hscroll --ansi +m -d "\t" -n 2) || return
  git checkout $(echo "$target" | awk '{print $2}')
}

# fcoc - checkout git commit
fcoc() {
  local commits commit
  commits=$(git log --graph --color=always --pretty=oneline --format="%C(auto)%h%d %s %C(black)%C(white)%cr" --abbrev-commit) &&
  commit=$(echo "$commits" | fzf-tmux --ansi +s +m -e) &&
  git checkout $(echo "$commit" | grep -oe "[0-9a-f]\{5,32\}")
}

# fsha - get git commit sha
# example usage: git rebase -i `fsha`
fsha() {
  local commits commit
  commits=$(git log --graph --color=always --pretty=oneline --format="%C(auto)%h%d %s %C(black)%C(white)%cr" --abbrev-commit) &&
  commit=$(echo "$commits" | fzf-tmux +s +m -e --ansi) &&
  echo -n $(echo "$commit" | grep -oe "[0-9a-f]\{5,32\}")
}

#}}}
# TAGS {{{
# ------------------
# ftags - search ctags
ftags() {
  local line
  [ -e tags ] &&
  line=$(
    awk 'BEGIN { FS="\t" } !/^!/ {print toupper($4)"\t"$1"\t"$2"\t"$3}' tags |
    cut -c1-80 | fzf-tmux --nth=1,2
  ) && $EDITOR $(cut -f3 <<< "$line") -c "set nocst" \
                                      -c "silent tag $(cut -f2 <<< "$line")"
}
#}}}
# TMUX {{{
# ---------------
# fs [FUZZY PATTERN] - Select selected tmux session
#   - Bypass fuzzy finder if there's only one match (--select-1)
#   - Exit if there's no match (--exit-0)
fts() {
  local session
  session=$(tmux list-sessions -F "#{session_name}" | \
    fzf-tmux --query="$1" --select-1 --exit-0) &&
    tmux switch-client -t "$session"
}

# AG {{{
# ------

# search using ag and open selected file at linum
fv() {
  local match linum file;
  match=$(\ag \
    --nobreak \
    --smart-case \
    --hidden  \
    -p ~/.agignore \
    --noheading . | fzf-tmux +m) &&

    linum=$(echo "$match" | cut -d':' -f2) &&
    file=$(echo "$match" | cut -d':' -f1) &&

    emacsclient -nw +$linum $file
}

falias() {
  local match;
  match=$(cat ~/.zsh.d/aliases.zsh -n | fzf-tmux +m --reverse --preview="echo {1}") &&
    echo $match

  # cat aliases.zsh|sed -n '4,5p'
    # linum=$(echo "$match" | cut -d':' -f2) &&
    # file=$(echo "$match" | cut -d':' -f1) &&

    # ${EDITOR:-vim} +$linum $file
}

#}}}

# =============================
# Package managers
# =============================
# Search apt for query, and install selected package
fapt() {
  local pkg=$(apt-cache search $1 | fzf --no-multi -q $1 --ansi --preview="apt-cache show {1}" | awk '{ print $1 }')

  if [[ $pkg ]]; then
    sudo apt-get install $pkg
  fi
}

# Search AUR and official repos using yay and install on
# select. Supports multiple selections and preview using yay -Si
fyay() {
  if [ "$#" -ne 1 ]; then
    echo "Please provide a query"
  else
    local pkg=$(yay -Ssq "$1" | fzf --multi --query "$1" --preview="yay -Si {}")

    if [[ $pkg ]]; then
      yay -S - <<< $pkg
    fi
  fi
}

# Search with pacman, and install on select. Supports multiple
# selections, and preview using pacman -Si
fpac() {
  if [ "$#" -ne 1 ]; then
    echo "Please provide a query"
  else
    local pkg=$(pacman -Ssq "$1" | fzf --multi --query "$1" --preview="pacman -Si {}")
    if [[ $pkg ]]; then
      sudo pacman -S - <<< $pkg
    fi
  fi
}



# using ripgrep combined with preview
# find-in-files
fif() {
  match=$(\rg \
            --smart-case \
            --color "always" \
            --line-number \
            --hidden \
            --no-heading . | \
            fzf -d ":" \
                --ansi \
                --nth "2.." \
                --preview-window=up \
                --with-nth "1,3.." \
                --preview="fzf-preview {}") &&

    linum=$(echo "$match" | cut -d':' -f2) &&
    file=$(echo "$match" | cut -d':' -f1) &&

    emacsclient -nw +$linum $file
}

# using ripgrep combined with preview
# find-in-file - usage: fif <searchTerm>
_fif() {
  if [ ! "$#" -gt 1 ]; then echo "Need a string to search for!"; return 1; fi
  rg --files-with-matches --no-messages $1 | fzf --preview "highlight -O ansi -l {} 2> /dev/null | rg --colors 'match:bg:yellow' --ignore-case --pretty --context 10 $1 || rg --ignore-case --pretty --context 10 $1 {}"
}

forg() {
  local match linum file;
  (
    cd ~/org &&
    match=$(\rg \
              --smart-case \
              --color "always" \
              --line-number \
              --no-heading . | fzf -d ":" --ansi --with-nth "1,3.." --preview="fzf-preview {} {q}") &&

      linum=$(echo "$match" | cut -d':' -f2) &&
      file=$(echo "$match" | cut -d':' -f1) &&

      emacsclient -nw +$linum $file && popd
  )
}

#  vim: set ts=2 sw=2 tw=0 fdm=marker et :
