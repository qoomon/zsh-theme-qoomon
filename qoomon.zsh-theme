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
    prompt_info+="${fg_bold[grey]}@${reset_color}"
    prompt_info+="${fg[blue]}${host_name}${reset_color}"
  fi

  # --- directory
  local working_dir=$PWD
  # abbreviate $HOME with '~'
  working_dir=${working_dir/#$HOME/'~'}
  # abbreviate intermediate directories with firt letter of directory name
  #working_dir=${working_dir//(#m)[^\/]##\//${MATCH[1]}/}
  prompt_info+=" ${fg_bold[grey]}>${reset_color}"
  prompt_info+=" ${fg[yellow]}${working_dir}${reset_color}"

  # --- git info
  if [[ $PROMPT_INFO_GIT == 'true' ]] && [ $commands[git] ]; then

    local current_branch_status_line="$(git status 2>/dev/null | head -1)"
    if [ -n "$current_branch_status_line" ]; then
      local ref_name="$(echo $current_branch_status_line | awk '{print $NF}')"
      if [[ "$current_branch_status_line" == "HEAD detached"* ]]; then
          prompt_info+=" ${fg_bold[grey]}>${reset_color}"
          prompt_info+=" ${fg[green]}${ref_name}${reset_color}"
          prompt_info+=" ${fg[magenta]}HEAD detached${reset_color}"
      else
          prompt_info+=" ${fg_bold[grey]}>${reset_color}"
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

_prompt_exec_flag='false'
function _prompt_flag_exec {
  _prompt_exec_flag='true'
}

function _prompt_handle_exit_code {
  local exit_code=$status
  if [ $exit_code != 0 ]; then
    if [[ $_prompt_exec_flag == 'true' ]]; then
      printf "\033[2K" # \033[2K\r prevents strange line wrap behaviour when resizing terminal window
      printf "${fg_bold[red]}✖ ${exit_code}${reset_color}\n"
    fi
  fi
  _prompt_exec_flag='false'
}

preexec_functions=(_prompt_flag_exec $preexec_functions)
precmd_functions=(_prompt_handle_exit_code $precmd_functions)

# print exit code when commandline is interupted
function _promp_handle_interupt {
  if [ "$SUFFIX_ACTIVE" = 0 ] && [ -n "${PREBUFFER}${BUFFER}" ]; then
    local exit_code=130
    printf "\n\033[2K" # \033[2K\r prevents strange line wrap behaviour when resizing terminal window
    printf "${fg_bold[grey]}✖ ${exit_code}${reset_color}"
  fi
}
trap "_promp_handle_interupt; return INT" INT

###### clear screen with prompt info ###########################################

function _clear_screen_widget {
  tput clear
  _prompt_print_info
  zle reset-prompt
}
zle -N _clear_screen_widget
bindkey "^L" _clear_screen_widget
