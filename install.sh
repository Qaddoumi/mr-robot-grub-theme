#! /usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

THEME_NAME='mr-robot-theme'
# INSTALLER_LANG='English'

# Color codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
bold="\e[1m"
no_color='\033[0m' # reset the color to default

if [ "$EUID" -eq 0 ] || [ "$(id -u)" = "0" ]; then
	if command -v "eval"; then
		ESCALATION_TOOL="eval"
	else
		ESCALATION_TOOL=""
	fi
else
	for tool in sudo doas pkexec; do
		if command -v "${tool}" >/dev/null 2>&1; then
			ESCALATION_TOOL="${tool}"
			echo -e "${cyan}Using ${tool} for privilege escalation${no_color}"
			break
		fi
	done

	if [ -z "${ESCALATION_TOOL}" ]; then
		echo -e "${red}Error: This script requires root privileges. Please run as root or install sudo, doas, or pkexec.${no_color}"
		exit 1
	fi
fi

backup_file() {
	local file="$1"
	if "${ESCALATION_TOOL}" test -f "$file"; then
		"${ESCALATION_TOOL}" cp -an "$file" "$file.backup.$(date +%Y%m%d_%H%M%S)"
		echo -e "${green}Backed up $file${no_color}"
	else
		echo -e "${yellow}File $file does not exist, skipping backup${no_color}"
	fi
}

# # Select language, optional
# declare -A INSTALLER_LANGS=(
#     [Chinese]=zh_CN
#     [English]=EN
#     [French]=FR
#     [German]=DE
#     [Italian]=IT
#     [Norwegian]=NO
#     [Portuguese]=PT
#     [Russian]=RU
#     [Spanish]=ES
#     [Turkish]=TR
#     [Ukrainian]=UA
# )

# INSTALLER_LANG_NAMES=($(echo ${!INSTALLER_LANGS[*]} | tr ' ' '\n' | sort -n))

# PS3='Please select language #: '
# select l in "${INSTALLER_LANG_NAMES[@]}"; do
#     if [[ -v INSTALLER_LANGS[$l] ]]; then
#         INSTALLER_LANG=$l
#         break
#     else
#         echo 'No such language, try again'
#     fi
# done < /dev/tty
# echo "Selected language: ${INSTALLER_LANG}"

# if [[ "$INSTALLER_LANG" != "English" ]]; then
#     echo "Changing language to ${INSTALLER_LANG}"
#     sed -i -r -e '/^\s+# EN$/{n;s/^(\s*)/\1# /}' \
#               -e '/^\s+# '"${INSTALLER_LANGS[$INSTALLER_LANG]}"'$/{n;s/^(\s*)#\s*/\1/}' theme.txt
# fi

# Detect distro and set GRUB location and update method
GRUB_DIR='grub'
THEME_DIR='/boot/grub/themes'
UPDATE_GRUB=''
BOOT_MODE='legacy'

if [[ -d /boot/efi && -d /sys/firmware/efi ]]; then
    BOOT_MODE='UEFI'
fi

echo "Boot mode: ${BOOT_MODE}"

if [[ -e /etc/os-release ]]; then

    ID=""
    ID_LIKE=""
    source /etc/os-release

    if [[ "$ID" =~ (debian|ubuntu|solus|void) || \
          "$ID_LIKE" =~ (debian|ubuntu|void) ]]; then

        UPDATE_GRUB='update-grub'

    elif [[ "$ID" =~ (arch|gentoo) || \
            "$ID_LIKE" =~ (archlinux|gentoo) ]]; then

        THEME_DIR='/boot/grub/themes'
        UPDATE_GRUB='grub-mkconfig -o /boot/grub/grub.cfg'

    elif [[ "$ID" =~ (centos|fedora|opensuse) || \
            "$ID_LIKE" =~ (fedora|rhel|suse) ]]; then

        GRUB_DIR='grub2'
        THEME_DIR='/boot/grub2/themes'
        GRUB_CFG='/boot/grub2/grub.cfg'

        if [[ "$BOOT_MODE" = "UEFI" ]]; then
            GRUB_CFG="/boot/efi/EFI/${ID}/grub.cfg"
        fi

        UPDATE_GRUB="grub2-mkconfig -o ${GRUB_CFG}"

        # BLS etries have 'kernel' class, copy corresponding icon
        if [[ -d /boot/loader/entries && -e "${THEME_NAME}/icons/${ID}.png" ]]; then
            cp ${THEME_NAME}/icons/${ID}.png ${THEME_NAME}/icons/kernel.png
        fi
    fi
fi

echo 'Creating GRUB themes directory'
"$ESCALATION_TOOL" mkdir -p /boot/${GRUB_DIR}/themes/${THEME_NAME}

echo 'Copying theme to GRUB themes directory'
"$ESCALATION_TOOL" cp -fa ./"${THEME_NAME}"/* /boot/${GRUB_DIR}/themes/${THEME_NAME}

#==========================================================================================
#==========================================================================================
echo -e "${green}Enabling grub menu${no_color}"
# remove default grub style if any
echo -e "${blue}sed -i '/GRUB_TIMEOUT_STYLE=/d' /etc/default/grub${no_color}"
"${ESCALATION_TOOL}" sed -i '/GRUB_TIMEOUT_STYLE=/d' /etc/default/grub

# issue #16
echo -e "${blue}sed -i '/GRUB_TERMINAL_OUTPUT=/d' /etc/default/grub${no_color}"
"${ESCALATION_TOOL}" sed -i '/GRUB_TERMINAL_OUTPUT=/d' /etc/default/grub

echo -e "${blue}echo 'GRUB_TIMEOUT_STYLE=\"menu\"' | ${ESCALATION_TOOL:-} tee -a /etc/default/grub${no_color}"
echo 'GRUB_TIMEOUT_STYLE="menu"' | "${ESCALATION_TOOL}" tee -a /etc/default/grub > /dev/null

#--------------------------------------------------

echo -e "${green}Setting ${THEME_NAME} as default${no_color}"
# remove theme if any
echo -e "${blue}sed -i '/GRUB_THEME=/d' /etc/default/grub${no_color}"
"${ESCALATION_TOOL}" sed -i '/GRUB_THEME=/d' /etc/default/grub

echo -e "${blue}echo \"GRUB_THEME=\"${THEME_DIR}/${THEME_NAME}/theme.txt\"\" | ${ESCALATION_TOOL:-} tee -a /etc/default/grub${no_color}"
echo "GRUB_THEME=\"${THEME_DIR}/${THEME_NAME}/theme.txt\"" | "${ESCALATION_TOOL}" tee -a /etc/default/grub > /dev/null

#--------------------------------------------------

echo -e "${green}Setting grub graphics mode to auto${no_color}"
# remove default timeout if any
echo -e "${blue}sed -i '/GRUB_GFXMODE=/d' /etc/default/grub${no_color}"
"${ESCALATION_TOOL}" sed -i '/GRUB_GFXMODE=/d' /etc/default/grub

echo -e "${blue}echo 'GRUB_GFXMODE=\"auto\"' | ${ESCALATION_TOOL:-} tee -a /etc/default/grub${no_color}"
echo 'GRUB_GFXMODE="auto"' | "${ESCALATION_TOOL}" tee -a /etc/default/grub > /dev/null
#==========================================================================================
#==========================================================================================


echo 'Updating GRUB'
if [[ $UPDATE_GRUB ]]; then
    eval "$ESCALATION_TOOL" "$UPDATE_GRUB"
else
    cat << '    EOF'
    --------------------------------------------------------------------------------
    Cannot detect your distro, you will need to run `grub-mkconfig` (as root) manually.

    Common ways:
    - Debian, Ubuntu, Solus and derivatives: `update-grub` or `grub-mkconfig -o /boot/grub/grub.cfg`
    - RHEL, CentOS, Fedora, SUSE and derivatives: `grub2-mkconfig -o /boot/grub2/grub.cfg`
    - Arch, Gentoo and derivatives: `grub-mkconfig -o /boot/grub/grub.cfg`
    --------------------------------------------------------------------------------
EOF
fi

echo -e "${green}Boot Theme Update Completed!${no_color}"