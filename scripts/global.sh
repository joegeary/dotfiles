#!/usr/bin/env bash

set -e

srcDir="$(dirname "$(realpath "$0")")"
confDir="${XDG_CONFIG_HOME:-$HOME/.config}"

export confDir

pkg_available() {
  local PkgIn=$1

  if pacman -Si "${PkgIn}" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

aur_available() {
  local PkgIn=$1

  # shellcheck disable=SC2154
  if yay -Si "${PkgIn}" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

print_log() {
  local executable="${0##*/}"
  local logFile="${srcDir}/logs/${TIMESTAMP}/${executable}"
  mkdir -p "$(dirname "${logFile}")"
  local section=${log_section:-}
  {
    [ -n "${section}" ] && echo -ne "\e[32m[$section] \e[0m"
    while (("$#")); do
      case "$1" in
      -r | +r)
        echo -ne "\e[31m$2\e[0m"
        shift 2
        ;; # Red
      -g | +g)
        echo -ne "\e[32m$2\e[0m"
        shift 2
        ;; # Green
      -y | +y)
        echo -ne "\e[33m$2\e[0m"
        shift 2
        ;; # Yellow
      -b | +b)
        echo -ne "\e[34m$2\e[0m"
        shift 2
        ;; # Blue
      -m | +m)
        echo -ne "\e[35m$2\e[0m"
        shift 2
        ;; # Magenta
      -c | +c)
        echo -ne "\e[36m$2\e[0m"
        shift 2
        ;; # Cyan
      -wt | +w)
        echo -ne "\e[37m$2\e[0m"
        shift 2
        ;; # White
      -n | +n)
        echo -ne "\e[96m$2\e[0m"
        shift 2
        ;; # Neon
      -stat)
        echo -ne "\e[30;46m $2 \e[0m :: "
        shift 2
        ;; # status
      -crit)
        echo -ne "\e[97;41m $2 \e[0m :: "
        shift 2
        ;; # critical
      -warn)
        echo -ne "WARNING :: \e[97;43m $2 \e[0m :: "
        shift 2
        ;; # warning
      +)
        echo -ne "\e[38;5;$2m$3\e[0m"
        shift 3
        ;; # Set color manually
      -sec)
        echo -ne "\e[32m[$2] \e[0m"
        shift 2
        ;; # section use for logs
      -err)
        echo -ne "ERROR :: \e[4;31m$2 \e[0m"
        shift 2
        ;; #error
      *)
        echo -ne "$1"
        shift
        ;;
      esac
    done
    echo ""
  } | if [ -n "${TIMESTAMP}" ]; then
    tee >(sed 's/\x1b\[[0-9;]*m//g' >>"${logFile}")
  else
    cat
  fi
}
