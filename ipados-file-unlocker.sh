#!/bin/sh
#
# iOS/iPadOS File Unlocker
# Version 1.0.3
#
# SAFETY / SEGURANÇA
# This script NEVER deletes files or folders.
# Este script NUNCA apaga arquivos ou pastas.
#
# It only runs:
#   chflags -R nouchg
#   chmod   -R u+rwX
#
# Designed for a-Shell on iPhone and iPad.
#

VERSION="1.0.3"
UI_LANG=""

# a-Shell can write to Documents/Library/tmp, but not always to the
# application container root. Keep the preference file in Documents.
if [ -d "$HOME/Documents" ] && [ -w "$HOME/Documents" ]; then
    CONFIG_DIR="$HOME/Documents"
elif [ -d "$HOME" ] && [ -w "$HOME" ]; then
    CONFIG_DIR="$HOME"
else
    CONFIG_DIR="$(pwd)"
fi

CONFIG_FILE="$CONFIG_DIR/.ipados_file_unlocker.conf"

save_language() {
    printf 'language=%s\n' "$UI_LANG" > "$CONFIG_FILE" 2>/dev/null
}

load_language() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi

    lang="$(sed -n 's/^language=//p' "$CONFIG_FILE" 2>/dev/null | head -n 1)"
    case "$lang" in
        pt|en)
            UI_LANG="$lang"
            return 0
            ;;
    esac

    return 1
}

choose_language() {
    while :; do
        printf '\n'
        printf '========================================\n'
        printf '      iOS/iPadOS File Unlocker\n'
        printf '========================================\n\n'
        printf 'Selecione o idioma / Select language:\n\n'
        printf '  [1] Português (PT-BR)\n'
        printf '  [2] English (EN)\n'
        printf '  [0] Cancelar / Cancel\n\n'
        printf '> '
        IFS= read -r choice

        case "$choice" in
            1)
                UI_LANG="pt"
                if ! save_language; then
                    printf '\nAviso: não foi possível salvar o idioma.\n'
                fi
                return 0
                ;;
            2)
                UI_LANG="en"
                if ! save_language; then
                    printf '\nWarning: language preference could not be saved.\n'
                fi
                return 0
                ;;
            0)
                return 1
                ;;
            *)
                printf '\nOpção inválida / Invalid option.\n'
                ;;
        esac
    done
}

pause_screen() {
    printf '\n'
    if [ "$UI_LANG" = "pt" ]; then
        printf 'Pressione ENTER para continuar...'
    else
        printf 'Press ENTER to continue...'
    fi
    IFS= read -r _
}

check_commands() {
    missing=""

    for cmd in chflags chmod; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing="$missing $cmd"
        fi
    done

    if [ -n "$missing" ]; then
        printf '\n'
        if [ "$UI_LANG" = "pt" ]; then
            printf 'Erro: comandos indisponíveis:%s\n' "$missing"
            printf 'Atualize o a-Shell e tente novamente.\n'
        else
            printf 'Error: unavailable commands:%s\n' "$missing"
            printf 'Update a-Shell and try again.\n'
        fi
        exit 1
    fi
}

unlock_target() {
    target="$1"

    if [ -z "$target" ] || [ "$target" = "/" ] || [ ! -d "$target" ]; then
        if [ "$UI_LANG" = "pt" ]; then
            printf '\nOperação cancelada: pasta inválida ou insegura.\n'
        else
            printf '\nOperation cancelled: invalid or unsafe folder.\n'
        fi
        return 1
    fi

    if [ "$UI_LANG" = "pt" ]; then
        printf '\nRemovendo flags de bloqueio...\n'
        printf 'Restaurando permissões de leitura/escrita...\n\n'
    else
        printf '\nRemoving file-lock flags...\n'
        printf 'Restoring read/write permissions...\n\n'
    fi

    chflags -R nouchg "$target"
    flags_status=$?

    chmod -R u+rwX "$target"
    perms_status=$?

    printf '\n'

    if [ "$flags_status" -eq 0 ] && [ "$perms_status" -eq 0 ]; then
        if [ "$UI_LANG" = "pt" ]; then
            printf '✓ Desbloqueio concluído.\n\n'
            printf 'Nenhum arquivo foi apagado.\n'
            printf 'Volte ao app Arquivos e tente apagar, mover\n'
            printf 'ou restaurar os itens normalmente.\n'
        else
            printf '✓ Unlock completed.\n\n'
            printf 'No files were deleted.\n'
            printf 'Return to the Files app and try to delete, move,\n'
            printf 'or restore the items normally.\n'
        fi
        return 0
    fi

    if [ "$UI_LANG" = "pt" ]; then
        printf '⚠ O processo terminou com avisos.\n'
        printf 'Alguns itens podem continuar bloqueados.\n'
        printf 'Nenhum arquivo foi apagado.\n'
    else
        printf '⚠ The process finished with warnings.\n'
        printf 'Some items may still be locked.\n'
        printf 'No files were deleted.\n'
    fi

    return 1
}

bookmark_path_from_line() {
    line="$1"
    printf '%s\n' "$line" | sed 's/^[^:]*: //'
}

find_file_provider_root() {
    current="$(pwd)"

    if [ -d "$current/.Trash" ]; then
        printf '%s\n' "$current"
        return 0
    fi

    if ! command -v showmarks >/dev/null 2>&1; then
        return 1
    fi

    marks="$(showmarks 2>/dev/null)"
    FOUND_ROOT=""

    while IFS= read -r line; do
        case "$line" in
            *"File Provider Storage"*)
                path="$(bookmark_path_from_line "$line")"
                if [ -d "$path/.Trash" ]; then
                    FOUND_ROOT="$path"
                    break
                fi
                ;;
        esac
    done <<EOF_MARKS
$marks
EOF_MARKS

    if [ -n "$FOUND_ROOT" ]; then
        printf '%s\n' "$FOUND_ROOT"
        return 0
    fi

    return 1
}

select_folder_safely() {
    SELECTED_FOLDER=""

    if ! command -v pickFolder >/dev/null 2>&1; then
        return 1
    fi

    before_pwd="$(pwd)"

    if command -v showmarks >/dev/null 2>&1; then
        before_marks="$(showmarks 2>/dev/null)"
    else
        before_marks=""
    fi

    pickFolder

    after_pwd="$(pwd)"

    if [ "$after_pwd" != "$before_pwd" ]; then
        SELECTED_FOLDER="$after_pwd"
        return 0
    fi

    # Some a-Shell builds bookmark the selected folder without immediately
    # updating pwd when pickFolder is called from inside a script.
    if command -v showmarks >/dev/null 2>&1; then
        after_marks="$(showmarks 2>/dev/null)"

        while IFS= read -r line; do
            [ -z "$line" ] && continue

            if ! printf '%s\n' "$before_marks" | grep -Fqx "$line" 2>/dev/null; then
                path="$(bookmark_path_from_line "$line")"

                if [ -d "$path" ]; then
                    SELECTED_FOLDER="$path"
                    break
                fi
            fi
        done <<EOF_MARKS
$after_marks
EOF_MARKS
    fi

    if [ -n "$SELECTED_FOLDER" ]; then
        return 0
    fi

    return 1
}

unlock_trash() {
    printf '\n'

    if [ "$UI_LANG" = "pt" ]; then
        printf '=== Desbloquear Lixeira ===\n\n'
        printf 'Tentando localizar a raiz "No Meu iPhone / No Meu iPad"\n'
        printf 'já autorizada no a-Shell...\n'
    else
        printf '=== Unlock Trash ===\n\n'
        printf 'Trying to locate an already-authorized\n'
        printf '"On My iPhone / On My iPad" root...\n'
    fi

    root="$(find_file_provider_root 2>/dev/null)"

    if [ -z "$root" ]; then
        if [ "$UI_LANG" = "pt" ]; then
            printf '\nA raiz ainda não está acessível.\n'
            printf 'No seletor, escolha "No Meu iPhone / No Meu iPad".\n'
            printf 'Nenhum arquivo será apagado.\n\n'
            printf 'Pressione ENTER para abrir o seletor...'
        else
            printf '\nThe root is not accessible yet.\n'
            printf 'In the picker, choose "On My iPhone / On My iPad".\n'
            printf 'No files will be deleted.\n\n'
            printf 'Press ENTER to open the picker...'
        fi

        IFS= read -r _

        if command -v pickFolder >/dev/null 2>&1; then
            pickFolder
        fi

        root="$(find_file_provider_root 2>/dev/null)"
    fi

    if [ -z "$root" ] || [ ! -d "$root/.Trash" ]; then
        printf '\n'

        if [ "$UI_LANG" = "pt" ]; then
            printf '✗ Não foi possível acessar a pasta .Trash automaticamente.\n\n'
            printf 'Algumas versões do a-Shell não atualizam a pasta atual\n'
            printf 'imediatamente quando pickFolder é chamado dentro de um script.\n\n'
            printf 'Faça uma vez no prompt:\n\n'
            printf '  pickFolder\n\n'
            printf 'Selecione "No Meu iPhone / No Meu iPad" e execute\n'
            printf 'este script novamente. Nada foi alterado.\n'
        else
            printf '✗ The .Trash folder could not be accessed automatically.\n\n'
            printf 'Some a-Shell builds do not immediately update the current\n'
            printf 'folder when pickFolder is called from inside a script.\n\n'
            printf 'Run this once at the prompt:\n\n'
            printf '  pickFolder\n\n'
            printf 'Select "On My iPhone / On My iPad", then run this\n'
            printf 'script again. Nothing was changed.\n'
        fi

        return 1
    fi

    trash="$root/.Trash"

    if [ "$UI_LANG" = "pt" ]; then
        printf '\nLixeira encontrada:\n%s\n' "$trash"
    else
        printf '\nTrash folder found:\n%s\n' "$trash"
    fi

    unlock_target "$trash"
}

unlock_custom_folder() {
    printf '\n'

    if [ "$UI_LANG" = "pt" ]; then
        printf '=== Selecionar pasta para desbloquear ===\n\n'
        printf 'Recomendação: trabalhe preferencialmente dentro de\n'
        printf '"No Meu iPhone / No Meu iPad".\n\n'
        printf 'Todos os itens dentro da pasta escolhida serão processados\n'
        printf 'recursivamente. Nenhum arquivo será apagado.\n\n'
        printf 'Pressione ENTER para abrir o seletor...'
    else
        printf '=== Select folder to unlock ===\n\n'
        printf 'Recommendation: preferably work inside\n'
        printf '"On My iPhone / On My iPad".\n\n'
        printf 'All items inside the selected folder will be processed\n'
        printf 'recursively. No files will be deleted.\n\n'
        printf 'Press ENTER to open the picker...'
    fi

    IFS= read -r _

    if ! select_folder_safely; then
        printf '\n'

        if [ "$UI_LANG" = "pt" ]; then
            printf 'Não foi possível identificar a pasta selecionada com segurança.\n'
            printf 'Nada foi alterado.\n\n'
            printf 'Como alternativa, execute pickFolder no prompt, selecione\n'
            printf 'a pasta e então execute o script a partir dela.\n'
        else
            printf 'The selected folder could not be safely identified.\n'
            printf 'Nothing was changed.\n\n'
            printf 'As a workaround, run pickFolder at the prompt, select\n'
            printf 'the folder, then run the script from that location.\n'
        fi

        return 1
    fi

    target="$SELECTED_FOLDER"

    printf '\n'

    if [ "$UI_LANG" = "pt" ]; then
        printf 'Pasta selecionada:\n%s\n\n' "$target"
        printf 'Deseja desbloquear esta pasta e todo o conteúdo dela?\n'
        printf '  [S] Sim\n'
        printf '  [N] Cancelar\n\n'
        printf '> '
    else
        printf 'Selected folder:\n%s\n\n' "$target"
        printf 'Unlock this folder and all of its contents?\n'
        printf '  [Y] Yes\n'
        printf '  [N] Cancel\n\n'
        printf '> '
    fi

    IFS= read -r confirm

    if [ "$UI_LANG" = "pt" ]; then
        case "$confirm" in
            s|S|sim|Sim|SIM)
                unlock_target "$target"
                ;;
            *)
                printf '\nOperação cancelada. Nada foi alterado.\n'
                ;;
        esac
    else
        case "$confirm" in
            y|Y|yes|Yes|YES)
                unlock_target "$target"
                ;;
            *)
                printf '\nOperation cancelled. Nothing was changed.\n'
                ;;
        esac
    fi
}

show_menu() {
    while :; do
        printf '\n'
        printf '========================================\n'
        printf '   iOS/iPadOS File Unlocker v%s\n' "$VERSION"
        printf '========================================\n\n'

        if [ "$UI_LANG" = "pt" ]; then
            printf 'Remove bloqueios e restaura permissões.\n'
            printf 'NENHUM arquivo é apagado por esta ferramenta.\n\n'
            printf 'Use preferencialmente itens em\n'
            printf '"No Meu iPhone / No Meu iPad".\n\n'
            printf '  [1] Desbloquear Lixeira\n'
            printf '  [2] Selecionar pasta para desbloquear\n'
            printf '  [3] Alterar idioma\n'
            printf '  [0] Sair\n\n'
            printf '> '
        else
            printf 'Removes file locks and restores permissions.\n'
            printf 'NO files are deleted by this tool.\n\n'
            printf 'Prefer items inside\n'
            printf '"On My iPhone / On My iPad".\n\n'
            printf '  [1] Unlock Trash\n'
            printf '  [2] Select folder to unlock\n'
            printf '  [3] Change language\n'
            printf '  [0] Exit\n\n'
            printf '> '
        fi

        IFS= read -r option

        case "$option" in
            1)
                unlock_trash
                pause_screen
                ;;
            2)
                unlock_custom_folder
                pause_screen
                ;;
            3)
                choose_language
                ;;
            0)
                if [ "$UI_LANG" = "pt" ]; then
                    printf '\nSaindo.\n'
                else
                    printf '\nExiting.\n'
                fi
                break
                ;;
            *)
                if [ "$UI_LANG" = "pt" ]; then
                    printf '\nOpção inválida.\n'
                else
                    printf '\nInvalid option.\n'
                fi
                ;;
        esac
    done
}

case "$1" in
    --language|--lang|--reset-language)
        choose_language
        ;;
    --help|-h)
        printf 'iOS/iPadOS File Unlocker v%s\n\n' "$VERSION"
        printf 'Usage:\n'
        printf '  sh %s\n' "$(basename "$0")"
        printf '  sh %s --language\n\n' "$(basename "$0")"
        printf 'Language preference file:\n'
        printf '  %s\n' "$CONFIG_FILE"
        exit 0
        ;;
    *)
        if ! load_language; then
            choose_language
        fi
        ;;
esac

check_commands
show_menu
