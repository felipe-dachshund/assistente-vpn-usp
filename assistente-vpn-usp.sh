#!/usr/bin/env bash
#
# assistente-vpn-usp.sh
#
# Copyright (C) 2025 Felipe Oliveira da Silva Netto
#
# Este programa é software livre: você pode redistribuí-lo e/ou modificá-lo
# sob os termos da Licença Pública Geral GNU, conforme publicada pela Free
# Software Foundation, seja a versão 3 da Licença ou (a seu critério)
# qualquer versão posterior.
#
# Este programa é distribuído na esperança de que seja útil, mas SEM
# QUALQUER GARANTIA; sem mesmo a garantia implícita de
# COMERCIALIZAÇÃO ou ADEQUAÇÃO A UM FIM ESPECÍFICO. Consulte a
# Licença Pública Geral GNU para obter mais detalhes.
#
# Você deve ter recebido uma cópia da Licença Pública Geral GNU junto
# com este programa. Se não, veja <https://www.gnu.org/licenses/>.

set -e

# ==============================================================================
#
# Script para instalação e configuração da VPN da USP em Linux
#
# Objetivo: Automatizar a instalação de clientes VPN de código aberto
# (OpenConnect/OpenfortiVPN) e, opcionalmente, remover o Forticlient em
# distribuições Linux (Debian, Ubuntu e Fedora).
#
# ==============================================================================

# --- Configuração Inicial ---

THIS_VERSION="1.0"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

VPN_NAME="VPN USP"
VPN_GATEWAY="orion.uspnet.usp.br"
VPN_PORT="31443"

# --- Funções ---

#
# Função: exibir_ajuda
# Descrição: Mostra uma mensagem de ajuda com as opções de uso do script.
#
exibir_ajuda() {
    echo "Uso: $0 [opção]"
    echo ""
    echo "Assistente para migração da VPN da USP para soluções de código aberto em Linux."
    echo ""
    echo "Opções:"
    echo "  -i, --install    Instala e configura a nova VPN (OpenConnect ou OpenfortiVPN)."
    echo "  -r, --remove     Remove completamente o Forticlient do sistema."
    echo "  -h, --help       Exibe esta mensagem de ajuda."
    echo "  -v, --version    Exibe a versão do assistente."
    echo ""
    echo "Exemplos:"
    echo "  sudo $0 --install         # Instala a nova VPN e depois pergunta se deseja remover a antiga."
    echo "  sudo $0 --remove          # Apenas remove o Forticlient."
    echo "  sudo $0 --install --remove # Instala a nova VPN e remove o Forticlient sem perguntar."
}

#
# Função: solicitar_nusp
# Descrição: Pede ao usuário que insira seu Número USP (NUSP) e o armazena
# em uma variável global.
#
solicitar_nusp() {
    while [ -z "$NUSP" ]; do
        read -p "Por favor, digite seu Número USP (NUSP): " NUSP
        if [ -z "$NUSP" ]; then
            echo -e "${RED}O Número USP não pode ser vazio. Por favor, tente novamente.${NC}" >&2
        fi
    done
}

#
# Função: remover_dados_usuario
# Descrição: Realiza uma limpeza completa dos dados do usuário, removendo
# os arquivos de configuração na pasta home.
#
remover_dados_usuario() {
    local REAL_USER="$1"
    if [ -z "$REAL_USER" ]; then
        echo -e "${YELLOW}Não foi possível determinar o usuário para a limpeza de dados. Pulando esta etapa.${NC}" >&2
        return
    fi

    echo "Verificando arquivos de configuração do Forticlient na pasta do usuário '$REAL_USER'..." >&2
    local USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
    if [[ -z "$USER_HOME" || ! -d "$USER_HOME" ]]; then
        echo -e "${RED}Não foi possível encontrar o diretório home para o usuário $REAL_USER.${NC}" >&2
    else
        echo "Limpando diretório de configuração em '$USER_HOME'..." >&2
        # Usamos o caminho absoluto para 'runuser' para garantir que ele seja
        # encontrado mesmo em sessões 'su' que não incluem /usr/sbin no $PATH.
        /usr/sbin/runuser -u "$REAL_USER" -- sh -c "rm -rf '$USER_HOME/.config/FortiClient'"
    fi

    #TODO: Remover as chaves Forticlient de ~/.local/share/keyrings/login.keyring
    echo -e "\n${YELLOW}Atenção: Se você salvou sua senha no Forticlient, ela pode permanecer no chaveiro do sistema.${NC}" &>2
    echo "Para removê-la com segurança, siga as instruções na seção 'Remoção Manual' do nosso guia." &>2
}

#
# Função: remover_forticlient
# Descrição: Realiza a remoção completa do Forticlient, incluindo pacotes,
# arquivos de configuração, repositórios e chaves GPG.
#
remover_forticlient() {
    local REAL_USER="$1"
    echo -e "\n${YELLOW}--- Iniciando a remoção completa do Forticlient ---${NC}" >&2

    if command -v apt-get &> /dev/null; then
        if dpkg-query -W -f='${Status}' forticlient 2>/dev/null | grep -q "ok installed"; then
            echo "Pacote 'forticlient' encontrado. Tentando remoção completa..." >&2
            apt-get purge -y forticlient
            echo -e "${GREEN}Pacote 'forticlient' removido com sucesso.${NC}"
        else
            echo "Pacote 'forticlient' não está instalado. Pulando para a limpeza de arquivos residuais." >&2
        fi
    elif command -v dnf &> /dev/null; then
        if rpm -q forticlient > /dev/null 2>&1; then
            echo "Pacote 'forticlient' encontrado. Tentando remoção..." >&2
            dnf remove -y forticlient
            echo -e "${GREEN}Pacote 'forticlient' removido com sucesso.${NC}"
        else
            echo "Pacote 'forticlient' não está instalado. Pulando para a limpeza de arquivos residuais." >&2
        fi
    else
        echo -e "${RED}Gerenciador de pacotes não suportado. Impossível continuar a remoção.${NC}" >&2
        return 1
    fi

    echo "Removendo diretório de configuração do Forticlient..." >&2
    rm -rf /etc/forticlient/

    echo "Removendo arquivos de repositório..." >&2
    rm -f /etc/apt/sources.list.d/repo.fortinet.com.list
    rm -f /etc/yum.repos.d/fortinet.repo

    echo "Removendo chaves de repositório..." >&2
    if command -v apt-get &> /dev/null; then
        rm -f /usr/share/keyrings/repo.fortinet.com.gpg
        rm -f /etc/apt/trusted.gpg.d/repo.fortinet.com.gpg
        if command -v apt-key &> /dev/null; then
            KEY_ID=$(apt-key list 2>/dev/null | grep -B 1 "Fortinet" | head -n 1 | tr -d ' ')
            if [ ! -z "$KEY_ID" ]; then
                apt-key del "$KEY_ID" 2>/dev/null || true
            fi
        fi
        apt-get update || true
    elif command -v dnf &> /dev/null; then
        KEY_IDS_TO_REMOVE=""
        for key in $(rpm -qa gpg-pubkey*); do
            if rpm -qi "$key" 2>/dev/null | grep -q "Fortinet"; then
                KEY_IDS_TO_REMOVE="$KEY_IDS_TO_REMOVE $key"
            fi
        done

        if [ ! -z "$KEY_IDS_TO_REMOVE" ]; then
            echo "Removendo chaves GPG do Fortinet encontradas: $KEY_IDS_TO_REMOVE" >&2
            rpm -e $KEY_IDS_TO_REMOVE || true
        fi
        dnf clean all
    fi

    echo -e "${GREEN}Remoção de arquivos de sistema do Forticlient concluída!${NC}"
    remover_dados_usuario "$REAL_USER"
}

#
# Função: configurar_vpn
# Descrição: Instala e configura o OpenConnect ou o OpenfortiVPN, conforme os
# parâmetros fornecidos.
#
configurar_vpn() {
    local REAL_USER="$1"
    local VPN_CLIENT="$2"
    local PLUGIN_NAME="openconnect"
    if [[ "$VPN_CLIENT" == "OpenfortiVPN" ]]; then
        PLUGIN_NAME="fortisslvpn"
    fi

    echo -e "\n${YELLOW}--- Configurando VPN com $VPN_CLIENT (via NetworkManager) ---${NC}" >&2
    if [[ "$VPN_CLIENT" == "OpenfortiVPN" ]]; then
        solicitar_nusp
    fi

    if command -v apt-get &> /dev/null; then
        local NM_PACKAGES="network-manager-$PLUGIN_NAME"
        if echo "$XDG_CURRENT_DESKTOP" | grep -qi "gnome"; then
            echo "Ambiente de trabalho GNOME detectado (via \$XDG_CURRENT_DESKTOP). Adicionando pacote de integração." >&2
            NM_PACKAGES="$NM_PACKAGES network-manager-$PLUGIN_NAME-gnome"
        elif command -v gnome-session &> /dev/null; then
            echo "Ambiente de trabalho GNOME detectado (via comando 'gnome-session'). Adicionando pacote de integração." >&2
            NM_PACKAGES="$NM_PACKAGES network-manager-$PLUGIN_NAME-gnome"
        else
            echo "Ambiente de trabalho não-GNOME detectado. Instalando apenas o pacote base." >&2
        fi
        echo "Pacote(s) a ser(em) instalado(s): $NM_PACKAGES" >&2
        apt-get update && apt-get install -y $NM_PACKAGES
    fi

    local CONN_UUID=$(< /proc/sys/kernel/random/uuid)

    local PERMISSIONS=""
    if [ -n "$REAL_USER" ]; then
        PERMISSIONS="user:$REAL_USER:;"
        echo "Configurando permissões da VPN para o usuário: $REAL_USER" >&2
    else
        echo "Não foi possível determinar o usuário padrão. A VPN será configurada como uma conexão de sistema." >&2
    fi

    local NM_CONN_PATH="/etc/NetworkManager/system-connections/$VPN_NAME.nmconnection"
    echo "Criando arquivo de configuração para o NetworkManager em '$NM_CONN_PATH'..." >&2

    if [[ "$VPN_CLIENT" == "OpenConnect" ]]; then
        tee "$NM_CONN_PATH" > /dev/null << EOF
[connection]
id=$VPN_NAME
uuid=$CONN_UUID
type=vpn
autoconnect=false
permissions=$PERMISSIONS

[vpn]
authtype=password
autoconnect-flags=0
certsigs-flags=0
cookie-flags=2
disable_udp=no
enable_csd_trojan=no
gateway=$VPN_GATEWAY:$VPN_PORT
gateway-flags=2
gwcert-flags=2
lasthost-flags=0
pem_passphrase_fsid=no
prevent_invalid_cert=no
protocol=fortinet
resolve-flags=2
stoken_source=disabled
xmlconfig-flags=0
service-type=org.freedesktop.NetworkManager.$PLUGIN_NAME

[ipv4]
method=auto

[ipv6]
addr-gen-mode=default
method=auto

[proxy]
EOF
    else
        tee "$NM_CONN_PATH" > /dev/null << EOF
[connection]
id=$VPN_NAME
uuid=$CONN_UUID
type=vpn
autoconnect=false
permissions=$PERMISSIONS

[vpn]
gateway=$VPN_GATEWAY:$VPN_PORT
otp-flags=0
password-flags=1
user=$NUSP
service-type=org.freedesktop.NetworkManager.$PLUGIN_NAME

[ipv4]
method=auto

[ipv6]
addr-gen-mode=default
method=auto

[proxy]
EOF
    fi

    chmod 600 "$NM_CONN_PATH"
    chown root:root "$NM_CONN_PATH"

    echo "Recarregando as conexões do NetworkManager..." >&2
    if nmcli connection reload; then
        echo -e "${GREEN}Conexões do NetworkManager recarregadas com sucesso.${NC}"
    else
        echo -e "${RED}Houve um erro ao recarregar as conexões do NetworkManager.${NC}" >&2
    fi

    echo -e "\n${GREEN}Configuração do $VPN_CLIENT concluída!${NC}"
    echo "Uma nova conexão chamada '$VPN_NAME' foi criada."
    echo "Para conectar:"
    echo "1. Vá até as configurações de rede do seu sistema."
    echo "2. Ative a VPN '$VPN_NAME'."
    if [[ "$VPN_CLIENT" == "OpenConnect" ]]; then
        echo "3. Na primeira vez, ele pedirá seu NUSP e sua senha única. Você pode salvá-la."
    else
        echo "3. Na primeira vez, ele pedirá sua senha única."
    fi
}

#
# Função: main
# Descrição: Ponto de entrada do script. Verifica permissões de root,
# processa os argumentos de linha de comando e chama as funções apropriadas.
#
main() {
    if [ $# -eq 0 ]; then
        exibir_ajuda
        exit 1
    fi

    local ACTION_INSTALL=false
    local ACTION_REMOVE=false
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -i|--install)
            ACTION_INSTALL=true
            ;;
            -r|--remove)
            ACTION_REMOVE=true
            ;;
            -h|--help)
            exibir_ajuda
            exit 0
            ;;
            -v|--version)
            echo $THIS_VERSION
            exit 0
            ;;
            *)
            echo -e "${RED}Opção inválida: $1${NC}" >&2
            exibir_ajuda
            exit 1
            ;;
        esac
        shift
    done

    if [ "$EUID" -ne 0 ]; then
      echo -e "${RED}Esta operação requer privilégios de superusuário.${NC}" >&2
      echo -e "${YELLOW}Por favor, execute o comando novamente com 'sudo'. Ex: sudo $0 --install${NC}" >&2
      exit 2
    fi

    local REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
    if [[ "$REAL_USER" == "root" ]]; then
      REAL_USER=""
    fi

    if [ "$ACTION_INSTALL" = true ]; then
        if [ ! -f /etc/os-release ]; then
            echo -e "${RED}Não foi possível encontrar o arquivo /etc/os-release para determinar a sua distribuição. Saindo.${NC}" >&2
            exit 3
        fi
        . /etc/os-release

        echo -e "\nDetectando distribuição: ${NAME:-'desconhecida'} ${VERSION:-''}" >&2

        local VPN_CLIENT="OpenConnect"
        if [[ "${ID:-}" == "debian" || "${ID_LIKE:-}" == "debian" ]] && [[ "${VERSION_ID%%.*}" -lt 13 ]]; then
            VPN_CLIENT=OpenfortiVPN
        fi
        configurar_vpn "$REAL_USER" "$VPN_CLIENT"
    fi

    if [ "$ACTION_REMOVE" = true ]; then
        remover_forticlient "$REAL_USER"
    elif [ "$ACTION_INSTALL" = true ]; then
        read -p $'\n\nA nova VPN foi configurada. Deseja remover o Forticlient agora? (s/n): ' remove_choice
        if [[ "$remove_choice" =~ ^[Ss]$ ]]; then
            remover_forticlient "$REAL_USER"
        else
            echo -e "\nOk. Você pode executar 'sudo $0 --remove' para remover o Forticlient mais tarde."
        fi
    fi

    echo -e "\n${GREEN}Operação concluída!${NC}"
}

main "$@"
