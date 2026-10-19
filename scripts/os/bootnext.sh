#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/current-system/sw/bin:/run/wrappers/bin:/usr/bin:/bin:${PATH:-}"

MODE="${1:-normal}"
SCRIPT_NAME="${0##*/}"

error() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

require_commands() {
    local command_name

    for command_name in efibootmgr lsblk jq sort; do
        command -v "$command_name" >/dev/null 2>&1 \
            || error "Required command not found: $command_name"
    done
}

check_uefi() {
    [[ -d /sys/firmware/efi/efivars ]] \
        || error 'UEFI variables are not available.'
}

load_entries() {
    local block_data partition_data boot_data line boot_id active_flag
    local match_text description efi_partition partuuid label priority status entry
    local -A partitions=()
    local -a entries=()

    CURRENT_BOOT=""
    NEXT_BOOT=""
    SORTED_ENTRIES=()
    BOOT_IDS=()
    BOOT_LABELS=()
    BOOT_PARTITIONS=()
    BOOT_PARTUUIDS=()
    BOOT_STATUSES=()

    block_data="$(lsblk --json --list --output PARTN,PARTUUID)" \
        || error 'Failed to read block devices.'

    partition_data="$(jq -r '
        .blockdevices[]
        | select(.partn != null and .partuuid != null)
        | [(.partuuid | ascii_downcase), (.partn | tostring)]
        | @tsv
    ' <<< "$block_data")" \
        || error 'Failed to parse partition information.'

    while IFS=$'\t' read -r partuuid efi_partition; do
        [[ -n "$partuuid" ]] || continue
        partitions["$partuuid"]="$efi_partition"
    done <<< "$partition_data"

    boot_data="$(efibootmgr --verbose)" || error 'Failed to read EFI boot entries.'

    while IFS= read -r line; do
        if [[ "$line" =~ ^BootCurrent:[[:space:]]*([[:xdigit:]]{4}) ]]; then
            CURRENT_BOOT="${BASH_REMATCH[1]^^}"
            continue
        fi

        if [[ "$line" =~ ^BootNext:[[:space:]]*([[:xdigit:]]{4}) ]]; then
            NEXT_BOOT="${BASH_REMATCH[1]^^}"
            continue
        fi

        [[ "$line" =~ ^Boot([[:xdigit:]]{4})(\*)?[[:space:]]+ ]] || continue

        boot_id="${BASH_REMATCH[1]^^}"
        active_flag="${BASH_REMATCH[2]}"
        match_text="${BASH_REMATCH[0]}"
        description="${line:${#match_text}}"

        [[ -n "$active_flag" ]] || continue
        [[ "$description" =~ HD\(([0-9]+),GPT,([[:xdigit:]-]+), ]] || continue

        efi_partition="${BASH_REMATCH[1]}"
        partuuid="${BASH_REMATCH[2],,}"

        [[ -n "${partitions[$partuuid]+present}" ]] || continue
        [[ "${partitions[$partuuid]}" == "$efi_partition" ]] || continue

        label="${description%%HD(*}"
        label="${label%"${label##*[![:space:]]}"}"
        label="${label//$'\t'/ }"
        [[ -n "$label" ]] || label="Boot $boot_id"

        case "${description,,}" in
            *windows*) priority=1 ;;
            *nixos*) priority=2 ;;
            *cachy*) priority=3 ;;
            *) priority=9 ;;
        esac

        entries+=("$priority"$'\t'"$boot_id"$'\t'"$label"$'\t'"$efi_partition"$'\t'"$partuuid")
    done <<< "$boot_data"

    ((${#entries[@]} > 0)) \
        || error 'No active EFI entries matched local GPT partitions.'

    mapfile -t SORTED_ENTRIES < <(
        printf '%s\n' "${entries[@]}" | sort -t $'\t' -k1,1n -k2,2
    )

    for entry in "${SORTED_ENTRIES[@]}"; do
        IFS=$'\t' read -r priority boot_id label efi_partition partuuid <<< "$entry"

        status="-"
        [[ "$boot_id" == "$CURRENT_BOOT" ]] && status="Current"

        if [[ "$boot_id" == "$NEXT_BOOT" ]]; then
            if [[ "$status" == "Current" ]]; then
                status="Current, Next"
            else
                status="Next"
            fi
        fi

        BOOT_IDS+=("$boot_id")
        BOOT_LABELS+=("$label")
        BOOT_PARTITIONS+=("$efi_partition")
        BOOT_PARTUUIDS+=("$partuuid")
        BOOT_STATUSES+=("$status")
    done
}

print_ui_list() {
    local index

    for ((index = 0; index < ${#BOOT_IDS[@]}; index++)); do
        printf '%s\t%s\t%s\t%s\t%s\n' \
            "${BOOT_IDS[$index]}" \
            "${BOOT_LABELS[$index]}" \
            "${BOOT_PARTITIONS[$index]}" \
            "${BOOT_PARTUUIDS[$index]}" \
            "${BOOT_STATUSES[$index]}"
    done
}

print_terminal_list() {
    local mode="$1"
    local index number

    printf '\nEFI Boot Entries\n\n'

    if [[ "$mode" == "detail" ]]; then
        printf ' %-3s %-25s %-9s %-6s %-36s %s\n' 'No' 'Boot entry' 'Partition' 'EFI' 'PARTUUID' 'Status'
        printf ' %s\n' '----------------------------------------------------------------------------------------------------'
    else
        printf ' %-3s %-25s %-9s %-6s %s\n' 'No' 'Boot entry' 'Partition' 'EFI' 'Status'
        printf ' %s\n' '----------------------------------------------------------------'
    fi

    for ((index = 0; index < ${#BOOT_IDS[@]}; index++)); do
        number=$((index + 1))

        if [[ "$mode" == "detail" ]]; then
            printf ' %-3s %-25.25s %-9s %-6s %-36s %s\n' \
                "$number" "${BOOT_LABELS[$index]}" "${BOOT_PARTITIONS[$index]}" \
                "${BOOT_IDS[$index]}" "${BOOT_PARTUUIDS[$index]}" "${BOOT_STATUSES[$index]}"
        else
            printf ' %-3s %-25.25s %-9s %-6s %s\n' \
                "$number" "${BOOT_LABELS[$index]}" "${BOOT_PARTITIONS[$index]}" \
                "${BOOT_IDS[$index]}" "${BOOT_STATUSES[$index]}"
        fi
    done

    printf '\n'
}

set_next_and_reboot_as_root() {
    local selected_boot="${1^^}"
    local index found=false

    (( EUID == 0 )) || error 'This action must run through the polkit authorization dialog.'
    [[ "$selected_boot" =~ ^[[:xdigit:]]{4}$ ]] || error 'Invalid EFI boot ID.'

    require_commands
    check_uefi
    load_entries

    for ((index = 0; index < ${#BOOT_IDS[@]}; index++)); do
        if [[ "${BOOT_IDS[$index]}" == "$selected_boot" ]]; then
            found=true
            break
        fi
    done

    [[ "$found" == true ]] || error "Boot entry $selected_boot is no longer available."

    efibootmgr --bootnext "$selected_boot" >/dev/null \
        || error "Failed to set BootNext to $selected_boot."

    printf 'BootNext set to %s. Rebooting now.\n' "$selected_boot"
    systemctl reboot || error 'BootNext was set, but system reboot failed.'
}

require_commands
check_uefi

case "$MODE" in
    list-ui)
        (( $# == 1 )) || error "Usage: $SCRIPT_NAME list-ui"
        load_entries
        print_ui_list
        ;;

    set-reboot-root)
        (( $# == 2 )) || error "Usage: $SCRIPT_NAME set-reboot-root BOOT_ID"
        set_next_and_reboot_as_root "$2"
        ;;

    normal|detail)
        (( $# <= 1 )) || error "Usage: $SCRIPT_NAME [detail]"
        load_entries
        print_terminal_list "$MODE"

        [[ -t 0 ]] || exit 0

        read -r -p 'Select boot number (Enter to cancel): ' selection || exit 0
        [[ -n "$selection" ]] || exit 0

        if [[ ! "$selection" =~ ^[1-9][0-9]*$ ]] || (( ${#selection} > 5 )); then
            error 'Invalid selection.'
        fi

        index=$((10#$selection - 1))
        (( index < ${#BOOT_IDS[@]} )) || error 'Selection is out of range.'

        selected_boot="${BOOT_IDS[$index]}"
        selected_label="${BOOT_LABELS[$index]}"

        if (( EUID == 0 )); then
            efibootmgr --bootnext "$selected_boot" >/dev/null \
                || error 'Failed to set the next boot entry.'
        else
            command -v sudo >/dev/null 2>&1 || error 'sudo is required to update EFI variables.'
            sudo efibootmgr --bootnext "$selected_boot" >/dev/null \
                || error 'Failed to set the next boot entry.'
        fi

        printf 'Next boot: %s (Boot%s)\n' "$selected_label" "$selected_boot"
        printf 'The system will not reboot automatically.\n'
        ;;

    *)
        error "Usage: $SCRIPT_NAME [detail|list-ui|set-reboot-root BOOT_ID]"
        ;;
esac
