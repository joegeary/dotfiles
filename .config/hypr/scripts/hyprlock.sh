#! /bin/bash
srcDir=${srcDir:-$HOME/.local/lib/hyde}
confDir="${confDir:-$XDG_CONFIG_HOME}"
cacheDir="$HOME/.cache"

USAGE() {
  cat <<EOF
    Usage: $(basename "${0}") --[arg]

    arguments:
      --mpris <player>   - Handles mpris thumbnail generation
                            : \$MPRIS_IMAGE
      --cava             - Placeholder function for cava
                            : \$CAVA_CMD
      --art              - Prints the path to the mpris art"
                            : \$MPRIS_ART
      --help       -h    - Displays this help message"
EOF
}

fn_mpris() {
  local player=${1:-$(playerctl --list-all 2>/dev/null | head -n 1)}
  THUMB="${cacheDir}/mpris"
  player_status="$(playerctl -p "${player}" status 2>/dev/null)"
  if [[ "${player_status}" == "Playing" ]]; then
    playerctl -p "${player}" metadata --format "{{xesam:title}} $(mpris_icon "${player}")  {{xesam:artist}}"
    mpris_thumb "${player}"
  else
    if [ -f "$HOME/.face.icon" ]; then
      if ! cmp -s "$HOME/.face.icon" "${THUMB}.png"; then
        cp -f "$HOME/.face.icon" "${THUMB}.png"
        pkill -USR2 hyprlock >/dev/null 2>&1 # updates the mpris thumbnail
      fi
    # else
    #   if ! cmp -s "$XDG_DATA_HOME/icons/Wallbash-Icon/hyde.png" "${THUMB}.png"; then
    #     cp "$XDG_DATA_HOME/icons/Wallbash-Icon/hyde.png" "${THUMB}.png"
    #     pkill -USR2 hyprlock >/dev/null 2>&1 # updates the mpris thumbnail
    #   fi
    fi
    exit 1
  fi
}

mpris_icon() {

  local player=${1:-default}
  declare -A player_dict=(
    ["default"]=""
    ["spotify"]=""
    ["firefox"]=""
    ["vlc"]="嗢"
    ["google-chrome"]=""
    ["opera"]=""
    ["brave"]=""
  )

  for key in "${!player_dict[@]}"; do
    if [[ ${player} == "$key"* ]]; then
      echo "${player_dict[$key]}"
      return
    fi
  done
  echo "" # Default icon if no match is found

}

mpris_thumb() { # Generate thumbnail for mpris
  local player=${1:-""}
  artUrl=$(playerctl -p "${player}" metadata --format '{{mpris:artUrl}}')
  [ "${artUrl}" == "$(cat "${THUMB}".lnk)" ] && [ -f "${THUMB}".png ] && exit 0
  echo "${artUrl}" >"${THUMB}".lnk
  curl -Lso "${THUMB}".art "$artUrl"
  magick "${THUMB}.art" -quality 50 "${THUMB}.png"
  pkill -USR2 hyprlock >/dev/null 2>&1 # updates the mpris thumbnail
}

fn_cava() {
  local tempFile=/tmp/hyprlock-cava
  [ -f "${tempFile}" ] && tail -n 1 "${tempFile}"
  config_file="$HYDE_RUNTIME_DIR/cava.hyprlock"
  if [ "$(pgrep -c -f "cava -p ${config_file}")" -eq 0 ]; then
    trap 'rm -f ${tempFile}' EXIT
    "$scrDir/cava.sh" hyprlock >${tempFile} 2>&1
  fi
}

fn_art() {
  echo "${cacheDir}/landing/mpris.art"
}

# Define long options
LONGOPTS="mpris:,cava,art,help"

# Parse options
PARSED=$(
  if ! getopt --options shb --longoptions $LONGOPTS --name "$0" -- "$@"; then
    exit 2
  fi
)

# Apply parsed options
eval set -- "$PARSED"

while true; do
  case "$1" in
  mpris | --mpris)
    fn_mpris "${2}"
    exit 0
    ;;
  cava | --cava) # Placeholder function for cava
    fn_cava
    exit 0
    ;;
  art | --art)
    fn_art
    exit 0
    ;;
  help | --help | -h)
    USAGE
    exit 0
    ;;
  --)
    shift
    break
    ;;
  *)
    break
    ;;
  esac
  shift
done
