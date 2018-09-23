autoload +X -U colors && colors

###### Prompt Configuration ####################################################

function _prompt_print_info {
  local prompt_info
  
  # --- prompt info indicator
  prompt_info+="${fg_bold[grey]}#${reset_color}"

  # --- username
  local user_name=${USER}
  if [ $EUID = 0 ]; then # highlight root user
    prompt_info+=" ${fg_bold[red]}${user_name}${reset_color}" 
  else
    prompt_info+=" ${fg[cyan]}${user_name}${reset_color}"
  fi
  
  # --- hostname
  local host_name=${${HOST:-HOSTNAME}%%.*}
  prompt_info+="${fg_bold[grey]}@${reset_color}"
  prompt_info+="${fg[blue]}${host_name}${reset_color}"

  # --- directory
  # shorten $PWD: replace $HOME wit '~' and parent folders with first character only
  local current_dir=${${PWD/#$HOME/'~'}//(#m)[^\/]##\//${MATCH[1]}/} 
  prompt_info+=" ${fg_bold[grey]}in${reset_color}"
  prompt_info+=" ${fg[yellow]}$current_dir${reset_color}"

  if [ $commands[git] ]; then
    # --- git info
    local current_branch_status_line="$(git status --short --branch --porcelain 2>/dev/null | head -1)"
    if [ -n "$current_branch_status_line" ]; then
      if [[ "$current_branch_status_line" == *"(no branch)"* ]]; then
          prompt_info+=" ${fg_bold[grey]}at${reset_color}"
          prompt_info+=" ${fg[green]}detached HEAD${reset_color}"
      else
          local branch_name="${${current_branch_status_line#*' '}%%'...'*}"
          prompt_info+=" ${fg_bold[grey]}on${reset_color}"
          prompt_info+=" ${fg[green]}${branch_name}$current_branch${reset_color}"
      fi

      if [ -n "$(git status --short --porcelain 2>/dev/null)" ]; then
        prompt_info+="${fg_bold[magenta]}*${reset_color}"
      fi
      
      if [[ "$current_branch_status_line" == *"ahead"* ]]; then
        prompt_info+=" ${fg_bold[magenta]}⇡${reset_color}"
      fi
      
      if [[ "$current_branch_status_line" == *"behind"* ]]; then
        prompt_info+=" ${fg_bold[magenta]}⇣${reset_color}"
      fi
    fi
  fi

  # \033[0K\r prevents strange line wrap behaviour when resizing terminal window
  printf "\033[0K\r${prompt_info}\n"
}

precmd_functions=($precmd_functions _prompt_print_info)

PS1="‣ "
PS2="• "


###### Handle Exit Codes #######################################################

_prompt_exec_flag='false'
function _prompt_flag_exec { 
  _prompt_exec_flag='true'
}

function _prompt_handle_exit_code {
  local exit_code=$status
  if [ $exit_code != 0 ]; then
    if [[ $_prompt_exec_flag == 'true' ]]; then
      # \033[0K\r prevents strange line wrap behaviour when resizing terminal window
      printf "\033[0K\r${fg_bold[red]}✖ ${exit_code}${reset_color}\n"
    fi
  fi
  _prompt_exec_flag='false'
}

preexec_functions=(_prompt_flag_exec $preexec_functions)
precmd_functions=(_prompt_handle_exit_code $precmd_functions)

# print dimed exit code when commandline is interupted
function _promp_handle_interupt {
  local exit_code=130
  if [ -n "${PREBUFFER}${BUFFER}" ]; then
    printf "\n${fg_bold[grey]}✖ ${exit_code}${reset_color}"
  fi
}
trap "_promp_handle_interupt; return INT" INT

###### clear screen with prompt info ###########################################

function _clear_screen_widget { 
  tput clear
  _prompt_info
  zle reset-prompt
}
zle -N _clear_screen_widget
bindkey "^L" _clear_screen_widget
