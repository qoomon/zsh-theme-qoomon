autoload +X -U colors && colors

export PROMPT_INFO_INDICATOR=${PROMPT_INFO_INDICATOR:-'#'}
export PROMPT_INFO_USER=${PROMPT_INFO_USER:-'true'}
export PROMPT_INFO_HOST=${PROMPT_INFO_HOST:-'true'}
export PROMPT_INFO_GIT=${PROMPT_INFO_GIT:-'true'}
export PROMPT_PRIMARY_INDICATOR=${PROMPT_PRIMARY_INDICATOR:-'‣'}
export PROMPT_SECONDARY_INDICATOR=${PROMPT_SECONDARY_INDICATOR:-'•'}

###### Prompt Configuration ####################################################

function _prompt_print_info {
  setopt local_options extended_glob

  local prompt_info

  # --- prompt info indicator
  prompt_info+="${fg_bold[grey]}${PROMPT_INFO_INDICATOR}${reset_color}"

  # --- username
  if [[ $PROMPT_INFO_USER == 'true' ]]; then
    local user_name=$USER
    if [ $EUID = 0 ]; then # highlight root user
      prompt_info+=" ${fg_bold[red]}${user_name}${reset_color}"
    else
      prompt_info+=" ${fg[cyan]}${user_name}${reset_color}"
    fi
  fi

  # --- hostname
  if [[ $PROMPT_INFO_HOST == 'true' ]]; then
    local host_name=${HOST:-HOSTNAME}
    # hide domain if any
    host_name=${host_name%%.*}
    if [[ $PROMPT_INFO_USER == 'true' ]]; then
      prompt_info+="${fg_bold[grey]}@${reset_color}"
    fi
    prompt_info+="${fg[blue]}${host_name}${reset_color}"
    prompt_info+=" ${fg_bold[grey]}‣${reset_color}"
  elif [[ $PROMPT_INFO_USER == 'true' ]]; then
      prompt_info+=" ${fg_bold[grey]}•${reset_color}"
  fi

  # --- directory
  # abbreviate $HOME with '~'
  local working_dir=${PWD/#$HOME/'~'}
  # abbreviate intermediate directories with firt letter of directory name
  #working_dir=${working_dir//(#m)[^\/]##\//${MATCH[1]}/}
  prompt_info+=" ${fg[yellow]}${working_dir}${reset_color}"

  # --- git info
  if [[ $PROMPT_INFO_GIT == 'true' ]] && [ $commands[git] ]; then

    local current_branch_status_line="$(git status 2>/dev/null | head -1)"
    if [ -n "$current_branch_status_line" ]; then
      local ref_name="$(echo $current_branch_status_line | awk '{print $NF}')"
      prompt_info+=" ${fg_bold[grey]}•${reset_color}"
      if [[ "$current_branch_status_line" == "HEAD detached"* ]]; then
          prompt_info+=" ${fg[green]}${ref_name}${reset_color}"
          prompt_info+=" ${fg[magenta]}HEAD detached${reset_color}"
      else
          prompt_info+=" ${fg[green]}${ref_name}${current_branch}${reset_color}"
      fi

      if [ -n "$(git status --short --porcelain 2>/dev/null)" ]; then
        prompt_info+="${fg_bold[magenta]}*${reset_color}"
      fi

      local git_remote_sync="$(git status --branch --porcelain | grep  -o "\[.*\]")"
      if [[ "$git_remote_sync" == *"ahead "* ]]; then
        prompt_info+=" ${fg_bold[magenta]}⇡${reset_color}"
      fi

      if [[ "$git_remote_sync" == *"behind "* ]]; then
        prompt_info+=" ${fg_bold[magenta]}⇣${reset_color}"
      fi
    fi
  fi

  # \033[0K\r prevents strange line wrap behaviour when resizing terminal window
  printf "\033[0K\r${prompt_info}\n"
}

precmd_functions=($precmd_functions _prompt_print_info)

PS1="${PROMPT_PRIMARY_INDICATOR} "
PS2="${PROMPT_SECONDARY_INDICATOR} "

###### Handle Exit Codes #######################################################

typeset -g _prompt_line_executed
function _prompt_line_executed_preexec {
  _prompt_line_executed='true'
}
function _prompt_line_executed_precmd {
  _prompt_line_executed='false'
}
preexec_functions=(_prompt_line_executed_preexec $preexec_functions)
precmd_functions=(_prompt_line_executed_precmd $precmd_functions )

function _prompt_print_status {
  local exec_status=$status
  if [[ $_prompt_line_executed != 'true' ]]; then
    return
  fi
    
  if [[ $exec_status != 0 ]]; then
    printf '\033[2K\r' # clear line; prevents strange line wrap behaviour when resizing terminal window
    printf "${fg_bold[red]}✖ ${exec_status}${reset_color}\n"
  fi
}
precmd_functions=(_prompt_print_status $precmd_functions)

# print exit code when command line is interupted
function _promp_handle_interupt {
  if [[ "$ZSH_EVAL_CONTEXT" != 'trap:shfunc' ]]; then
    return
  fi

  if [[ "${PREBUFFER}${BUFFER}" ]]; then
    printf '\n'
    printf '\033[2K\r' #clear line
    printf "${fg_bold[grey]}✖ 130${reset_color}"
  fi
}
trap "_promp_handle_interupt; return 130" INT


###### clear s  creen with prompt info ###########################################

function _clear_screen_widget {
  tput clear
  _prompt_print_info
  zle reset-prompt
}
zle -N _clear_screen_widget
bindkey "^L" _clear_screen_widget
