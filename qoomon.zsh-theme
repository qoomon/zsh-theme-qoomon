autoload -Uz colors && colors

PROMPT_INFO_USER='true'
PROMPT_INFO_HOST='true'
PROMPT_INFO_GIT='true'

PROMPT_INFO_INDICATOR='╭╴' # ─ ╴

PROMPT_PRIMARY_INDICATOR='╰╼ '
PROMPT_SECONDARY_INDICATOR=''

PROMPT_INFO_SEPERATOR=' › ' # ∙ › ╼
PROMPT_ERROR_INDICATOR='✕'

PROMPT_INFO_GIT_DIRTY_INDICATOR='✲'
PROMPT_INFO_GIT_PUSH_INDICATOR='↑'
PROMPT_INFO_GIT_PULL_INDICATOR='↓'

###### Prompt Configuration ####################################################

function prompt_headline {
  setopt local_options extended_glob

  local prompt_info

  # --- username
  if [[ $PROMPT_INFO_USER == 'true' ]]
  then
    local user_name=$USER
    if [ $EUID = 0 ] # highlight root user
    then
      prompt_info+="${fg_bold[red]}${user_name}${reset_color}"
    else
      prompt_info+="${fg[cyan]}${user_name}${reset_color}"
    fi
  fi

  # --- hostname
  if [[ $PROMPT_INFO_HOST == 'true' ]]
  then
    if [[ $PROMPT_INFO_USER == 'true' ]]
    then
      prompt_info+="${fg_bold[default]}@${reset_color}"
    fi
    # hostname without domain
    local host_name=${${HOST:-HOSTNAME}%%.*}
    prompt_info+="${fg[blue]}${host_name}${reset_color}"
  fi

  # --- directory
  # abbreviate $HOME with '~'
  local working_dir=${PWD/#$HOME/'~'}
  # abbreviate intermediate directories with first letter of directory name
  # working_dir=${working_dir//(#m)[^\/]##\//${MATCH[1]}/}
  prompt_info+="${fg[default]}${PROMPT_INFO_SEPERATOR}${reset_color}${fg[yellow]}${working_dir}${reset_color}"

  # --- git info
  if [[ $PROMPT_INFO_GIT == 'true' ]] &&
    [[ $commands[git] ]] && git rev-parse --is-inside-work-tree &> /dev/null
  then
    prompt_info+="${fg[default]}${PROMPT_INFO_SEPERATOR}${reset_color}"

    # branch name
    local branch=$(git branch --show-current HEAD)
    if [[ $branch ]]
    then
      prompt_info+="${fg[green]}${branch}${reset_color}"
    else
      prompt_info+="${fg[magenta]}HEAD detached${reset_color}"
      prompt_info+="${fg[default]}${PROMPT_INFO_SEPERATOR}${reset_color}"
      # tag name
      local tag=$(git tag --sort=-creatordate --points-at HEAD | head -1)
      if [[ $tag ]]
      then
        prompt_info+="${fg[green]}${tag}${reset_color}"
      else
        # commit hash
        local commit_hash=$(git rev-parse --short HEAD)
        prompt_info+="${fg[green]}${commit_hash}${reset_color}"
      fi

    fi

    # dirty indicator
    local dirty_indicator
    if ! (git diff --exit-code --quiet 2> /dev/null && git diff --cached --exit-code --quiet 2> /dev/null)
    then
      dirty_indicator=$PROMPT_INFO_GIT_DIRTY_INDICATOR
    else
      if [[ $(git ls-files | wc -l) -lt 10000 ]]
      then # check for untracked files
        if [[ $(git ls-files --others --exclude-standard | wc -l) -gt 0 ]]
        then
          dirty_indicator=$PROMPT_INFO_GIT_DIRTY_INDICATOR
        fi
      else # skip check for large repositories
        dirty_indicator='?'
      fi
    fi
    if [[ $dirty_indicator ]]
    then
      prompt_info+="${fg_bold[magenta]}${dirty_indicator}${reset_color}"
    fi

    # commits ahead and behind
    if [[ $branch ]]
    then
      local remote_branch=$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2> /dev/null)
      if [[ $remote_branch ]]
      then
        read ahead behind <<<$(git rev-list --left-right --count $branch...$remote_branch)
        if [[ $ahead -gt 0 ]]
        then
          prompt_info+="${fg_bold[magenta]}${PROMPT_INFO_GIT_PUSH_INDICATOR}${reset_color}"
        fi
        if [[ $behind -gt 0 ]]
        then
          prompt_info+="${fg_bold[magenta]}${PROMPT_INFO_GIT_PULL_INDICATOR}${reset_color}"
        fi
      fi
    fi
  fi

  printf $'\033[0K' # prevents strange line wrap behaviour when resizing iterm2 terminal window
  echo "${fg[default]}${PROMPT_INFO_INDICATOR}${reset_color} ${prompt_info}"
}

precmd_functions=($precmd_functions prompt_headline)
PS1='%{'"${fg[default]}%}${PROMPT_PRIMARY_INDICATOR}%{${reset_color}"'%}'
PS2='%{'"${fg[default]}%}${PROMPT_SECONDARY_INDICATOR}%{${reset_color}"'%}'

if [[ $LC_TERMINAL == 'iTerm2' ]]
then
  precmd_functions[${precmd_functions[(i)prompt_headline]}]=()

  ITERM2_SQUELCH_MARK=1 # enable manual prompt marking
  function prompt_headline_iterm2 {
    echo $(
        if [[ $functions[iterm2_prompt_mark] ]]
        then
            iterm2_prompt_mark # mark headline as prompt start
        fi
        prompt_headline
    )
  }
  precmd_functions=($precmd_functions prompt_headline_iterm2)
fi

if [[ $TERMINAL_EMULATOR == 'JetBrains-JediTerm' ]]
then
    precmd_functions[${precmd_functions[(i)prompt_headline]}]=()

    setopt prompt_subst
    PS1=$'%{$(prompt_headline)%}\n'"$PS1"
fi


###### Handle Exit Codes #######################################################

typeset -g _prompt_line_executed
function _prompt_line_executed_preexec {
  _prompt_line_executed='true'
}
function _prompt_line_executed_precmd {
  _prompt_line_executed='false'
}
preexec_functions=(_prompt_line_executed_preexec $preexec_functions)
precmd_functions=(_prompt_line_executed_precmd $precmd_functions)

function _prompt_print_status {
  local exec_status=$status
  if [[ $_prompt_line_executed != 'true' ]]
  then
    return
  fi

  if [[ $exec_status != 0 ]]
  then
    printf '\033[2K' # prevents strange line wrap behaviour when resizing iterm2 terminal window
    printf "${fg_bold[red]}${PROMPT_ERROR_INDICATOR} ${exec_status}${reset_color}\n"
  fi
}
precmd_functions=(_prompt_print_status $precmd_functions)

# print exit code when command line is interupted
function _promp_handle_interupt {
  if [[ "$ZSH_EVAL_CONTEXT" != 'trap:shfunc' ]]
  then
    return
  fi

  if [[ "${PREBUFFER}${BUFFER}" ]]
  then
    printf '\n'
    printf '\033[2K' # prevents strange line wrap behaviour when resizing iterm2 terminal window
    printf "${fg_bold[default]}∙ 130${reset_color}"
  fi
}
trap "_promp_handle_interupt; return 130" INT
