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
# (OpenConnect/OpenFortiVPN) e, opcionalmente, remover o Forticlient em
# distribuições Linux (Debian, Ubuntu e Fedora).
#
# ==============================================================================

THIS_VERSION=1.0

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

VPN_NAME='VPN USP'
VPN_GATEWAY=orion.uspnet.usp.br
VPN_PORT=31443
ASK=
DRY_RUN=

#
# Função: exibir_ajuda
# Descrição: Mostra uma mensagem de ajuda com as opções de uso do script.
#
exibir_ajuda() {
    echo "Uso: $0 -h|-v"
    echo " ou  $0 [OPÇÃO...] AÇÃO"
    echo
    echo 'Assistente para migração da VPN da USP para soluções de código aberto em Linux.'
    echo
    echo 'Ações:'
    echo '  install    Instala e configura a nova VPN (OpenConnect ou OpenFortiVPN).'
    echo '  remove     Remove completamente o Forticlient do sistema.'
    echo '  help       Exibe esta mensagem de ajuda.'
    echo '  version    Exibe a versão do assistente.'
    echo
    echo 'Opções:'
    echo '  --nusp=NUSP      Define o NUSP do usuário.'
    echo '  --dry-run        Não executa as ações, apenas as simula.'
    echo '  -y, --yes        Ignora pedidos de confirmação.'
    echo '  --openfortivpn,  Opção de compatibilidade. Em sistemas Debian 12 ou anterior,'
    echo '   --fortisslvpn   força a instalação do NetworkManager-fortisslvpn em vez do'
    echo '                   OpenFortiGUI.'
    echo '  -h, --help       Exibe esta mensagem de ajuda.'
    echo '  -v, --version    Exibe a versão do assistente.'
    echo
    echo 'Exemplos:'
    echo "  sudo $0 --dry-run install  # Simula a instalação da VPN."
    echo "  sudo $0 install            # Instala a nova VPN, perguntando o NUSP."
    echo "  sudo $0 -y --nusp=12345678 # Instala a nova VPN para o NUSP 12.345.678 sem perguntar."
    echo "  sudo $0 --dry-run remove   # Simula a remoção do Forticlient."
    echo "  sudo $0 -y remove          # Remove o Forticlient sem perguntar."
    echo "  sudo $0 --fortisslvpn install # Instala o NM-fortisslvpn no Debian 12, como na v. 1.0 do script."
}

#
# Função: solicitar_nusp
# Descrição: Pede ao usuário que insira seu Número USP (NUSP) e o armazena
# em uma variável global.
#
solicitar_nusp() {
    while [ -z "$NUSP" ]; do
        read -p 'Por favor, digite seu Número USP (NUSP): ' NUSP
        if [ -z "$NUSP" ]; then
            echo -e "${RED}O Número USP não pode ser vazio. Por favor, tente novamente.$NC" >&2
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
        echo -e "${YELLOW}Não foi possível determinar o usuário para a limpeza de dados. Pulando esta etapa.$NC" >&2
        return
    fi

    echo "Verificando arquivos de configuração do Forticlient na pasta do usuário '$REAL_USER'..." >&2
    local USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
    if [[ -z "$USER_HOME" || ! -d "$USER_HOME" ]]; then
        echo -e "${RED}Não foi possível encontrar o diretório home para o usuário '$REAL_USER'.$NC" >&2
    else
        echo "Limpando diretório de configuração em '$USER_HOME'..." >&2
        if [ -z "$DRY_RUN" ]; then
            # Usando caminho absoluto para 'runuser' para garantir que ele
            # seja encontrado mesmo em sessões 'su' que não incluem /usr/sbin
            # no $PATH.
            /usr/sbin/runuser -u "$REAL_USER" -- sh -c "rm -rf '$USER_HOME/.config/FortiClient'"
        fi
    fi

    #TODO: Remover as chaves Forticlient de ~/.local/share/keyrings/login.keyring
    echo -e "\n${YELLOW}Atenção: Se você salvou sua senha no Forticlient, ela pode permanecer no chaveiro do sistema.$NC" >&2
    echo "Para removê-la com segurança, siga as instruções na seção 'Remoção Manual' do nosso guia." >&2
}

#
# Função: remover_forticlient
# Descrição: Realiza a remoção completa do Forticlient, incluindo pacotes,
# arquivos de configuração, repositórios e chaves GPG.
#
remover_forticlient() {
    local REAL_USER="$1"
    echo -e "\n$YELLOW--- Iniciando a remoção completa do Forticlient ---$NC" >&2

    if command -v apt-get &> /dev/null; then
        if dpkg-query -W -f='${Status}' forticlient 2>/dev/null | grep -q 'ok installed'; then
            echo "Pacote 'forticlient' encontrado. Tentando remoção completa..." >&2
            apt-get $DRY_RUN $ASK purge forticlient
            echo -e "${GREEN}Pacote 'forticlient' removido com sucesso.$NC"
        else
            echo "Pacote 'forticlient' não está instalado. Pulando para a limpeza de arquivos residuais." >&2
        fi
    elif command -v dnf &> /dev/null; then
        if rpm -q forticlient > /dev/null 2>&1; then
            echo "Pacote 'forticlient' encontrado. Tentando remoção..." >&2
            [ -n "$DRY_RUN" ] || dnf $ASK remove -y forticlient
            echo -e "${GREEN}Pacote 'forticlient' removido com sucesso.$NC"
        else
            echo "Pacote 'forticlient' não está instalado. Pulando para a limpeza de arquivos residuais." >&2
        fi
    else
        echo -e "${RED}Gerenciador de pacotes não suportado. Impossível continuar a remoção.$NC" >&2
        return 1
    fi

    echo 'Removendo diretório de configuração do Forticlient...' >&2
    [ -n "$DRY_RUN" ] || rm -rf /etc/forticlient/

    echo 'Removendo arquivos de repositório...' >&2
    if [ -z "$DRY_RUN" ]; then
        rm -f /etc/apt/sources.list.d/repo.fortinet.com.list
        rm -f /etc/yum.repos.d/fortinet.repo
    fi

    echo 'Removendo chaves de repositório...' >&2
    if command -v apt-get &> /dev/null; then
        if [ -z "$DRY_RUN" ]; then
            rm -f /usr/share/keyrings/repo.fortinet.com.gpg
            rm -f /etc/apt/trusted.gpg.d/repo.fortinet.com.gpg
        fi
        if command -v apt-key &> /dev/null; then
            KEY_ID=$(apt-key list 2>/dev/null | grep -B 1 Fortinet | head -n 1 | tr -d ' ')
            if [ -n "$KEY_ID" ] && [ -z "$DRY_RUN" ]; then
                apt-key del "$KEY_ID" 2>/dev/null || true
            fi
        fi
        apt-get update || true
    elif command -v dnf &> /dev/null; then
        KEY_IDS_TO_REMOVE=
        for key in $(rpm -qa gpg-pubkey*); do
            if rpm -qi "$key" 2>/dev/null | grep -q Fortinet; then
                KEY_IDS_TO_REMOVE="$KEY_IDS_TO_REMOVE $key"
            fi
        done

        if [ -n "$KEY_IDS_TO_REMOVE" ]; then
            echo "Removendo chaves GPG do Fortinet encontradas: $KEY_IDS_TO_REMOVE" >&2
            [ -z "$DRY_RUN" ] && rpm -e $KEY_IDS_TO_REMOVE || true
        fi
        [ -n "$DRY_RUN" ] || dnf clean all
    fi

    echo -e "${GREEN}Remoção de arquivos de sistema do Forticlient concluída!$NC"
    remover_dados_usuario "$REAL_USER"
}

#
# Função: configurar_vpn
# Descrição: Instala e configura o OpenConnect, o OpenFortiVPN ou o
# OpenFortiGUI, conforme os parâmetros fornecidos.
#
configurar_vpn() {
    local REAL_USER="$1"
    local VPN_CLIENT="$2"
    local PLUGIN_NAME=openconnect
    if [[ "$VPN_CLIENT" == 'OpenFortiVPN' ]]; then
        PLUGIN_NAME=fortisslvpn
    fi

    if [[ "$VPN_CLIENT" == 'OpenFortiGUI' ]]; then
        echo -e "\n$YELLOW--- Configurando VPN com OpenFortiVPN (via OpenFortiGUI) ---$NC" >&2
    else
        echo -e "\n$YELLOW--- Configurando VPN com $VPN_CLIENT (via NetworkManager) ---$NC" >&2
    fi
    if [[ "$VPN_CLIENT" == 'OpenFortiVPN' ]] || [[ "$VPN_CLIENT" == 'OpenFortiGUI' ]]; then
        solicitar_nusp
    fi

    if command -v apt-get &> /dev/null; then
        local PACKAGES="network-manager-$PLUGIN_NAME"
        local GNOME=
        if echo "$XDG_CURRENT_DESKTOP" | grep -qi gnome; then
            GNOME='$XDG_CURRENT_DESKTOP'
        elif command -v gnome-session &> /dev/null; then
            GNOME="comando 'gnome-session'"
        fi

        if [[ "$VPN_CLIENT" == 'OpenFortiGUI' ]]; then
            echo 'Adicionando chaves e repositório do OpenFortiGUI.' >&2
            if [ -z "$DRY_RUN" ]; then
                gpg -k
                gpg --no-default-keyring --keyring /usr/share/keyrings/iteas-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 23CAE45582EB0928
                echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/iteas-keyring.gpg] https://apt.iteas.at/iteas bookworm main' > /etc/apt/sources.list.d/iteas.list
            fi
            PACKAGES=openfortigui
        elif [ -z "$GNOME" ]; then
            echo 'Ambiente de trabalho não-GNOME detectado. Instalando apenas o pacote base.' >&2
        else
            echo "Ambiente de trabalho GNOME detectado (via $GNOME). Adicionando pacote de integração." >&2
            PACKAGES="$PACKAGES network-manager-$PLUGIN_NAME-gnome"
        fi
        echo "Pacote(s) a ser(em) instalado(s): $PACKAGES" >&2
        apt-get update
        apt-get $DRY_RUN $ASK install $PACKAGES || [ -n "$DRY_RUN" ]
    fi

    local PERMISSIONS=
    if [ -n "$REAL_USER" ]; then
        PERMISSIONS="user:$REAL_USER:;"
        echo "Configurando permissões da VPN para o usuário '$REAL_USER'" >&2
    else
        echo -n 'Não foi possível determinar o usuário padrão. A VPN será configurada como ' >&2
        if [[ "$VPN_CLIENT" == 'OpenFortiGUI' ]]; then
            echo 'global.' >&2
        else
            echo 'uma conexão de sistema.' >&2
        fi
    fi

    local CONN_PATH=
    local CONN_UUID=
    if [[ "$VPN_CLIENT" != 'OpenFortiGUI' ]]; then
        CONN_PATH="/etc/NetworkManager/system-connections/$VPN_NAME.nmconnection"
        CONN_UUID=$(< /proc/sys/kernel/random/uuid)
    elif [ -n "$REAL_USER" ]; then
        if [ -z "$DRY_RUN" ]; then
            sudo -u "$REAL_USER" mkdir -p "/home/$REAL_USER/.openfortigui/vpnprofiles"
        fi
        CONN_PATH="/home/$REAL_USER/.openfortigui/vpnprofiles/$VPN_NAME.conf"
    else
        [ -n "$DRY_RUN" ] || mkdir -p /etc/openfortigui/vpnprofiles
        CONN_PATH="/etc/openfortigui/vpnprofiles/$VPN_NAME.conf"
    fi

    echo "Criando arquivo de configuração em '$CONN_PATH'..." >&2

    if [[ "$VPN_CLIENT" == 'OpenConnect' ]]; then
        [ -n "$DRY_RUN" ] || tee "$CONN_PATH" > /dev/null << EOF
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
    elif [[ "$VPN_CLIENT" == 'OpenFortiVPN' ]]; then
        [ -n "$DRY_RUN" ] || tee "$CONN_PATH" > /dev/null << EOF
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
    elif [ -z "$DRY_RUN" ]; then
        tee "$CONN_PATH" > /dev/null << EOF
[cert]
ca_file=
trust_all_gw_certs=true
trusted_cert=
user_cert=
user_key=
verify_cert=false

[options]
always_ask_otp=false
autostart=false
debug=false
half_internet_routers=false
insecure_ssl=false
min_tls=Default
otp_delay=0
otp_prompt=
pppd_accept_remote=true
pppd_call=
pppd_ifname=
pppd_ipparam=
pppd_log_file=
pppd_no_peerdns=false
pppd_plugin_file=
realm=
saml_login=false
saml_port=8020
seclevel1=false
set_dns=true
set_routes=true

[vpn]
cookie=
device_type=0
gateway_host=orion.uspnet.usp.br
gateway_port=31443
name=VPN USP
persistent=false
sni=
username=$NUSP
EOF
    fi

    if [ -n "$CONN_UUID" ]; then
        if [ -z "$DRY_RUN" ]; then
            chmod 600 "$CONN_PATH"
            chown root:root "$CONN_PATH"
        fi

        echo 'Recarregando as conexões do NetworkManager...' >&2
        if [ -z "$DRY_RUN" ]; then
            if nmcli connection reload; then
                echo -e "${GREEN}Conexões do NetworkManager recarregadas com sucesso.$NC"
            else
                echo -e "${RED}Houve um erro ao recarregar as conexões do NetworkManager.$NC" >&2
            fi
        fi
    elif [ -n "$REAL_USER" ] && [ -z "$DRY_RUN" ]; then
        chown "$REAL_USER:$REAL_USER" "$CONN_PATH"
    fi

    echo -e "\n${GREEN}Configuração do $VPN_CLIENT concluída!$NC"
    echo "Uma nova conexão chamada '$VPN_NAME' foi criada."
    echo 'Para conectar:'
    if [[ "$VPN_CLIENT" == 'OpenFortiGUI' ]]; then
        echo '1. Abra o OpenFortiGUI.'
        echo '2. Na primeira vez:'
        echo '   - Siga o assistente de configuração clicando em "Next".'
        echo '   - Marque a caixa "Password Manager", clique em "Autogenerate keys" e "Finish"'
        echo '     (não use as senhas iniciais que começam com yowp2... e VoUT5...).'
        echo "   - Clique duas vezes na VPN '$VPN_NAME' para editá-la, insira sua senha única"
        echo "     no campo 'Password' e clique em 'Save'."
        echo "3. Selecione a VPN '$VPN_NAME' e clique em 'Connect'."
    else
        echo '1. Vá até as configurações de rede do seu sistema.'
        echo "2. Ative a VPN '$VPN_NAME'."
        if [[ "$VPN_CLIENT" == 'OpenConnect' ]]; then
            echo '3. Na primeira vez, ele pedirá seu NUSP e sua senha única. Você pode salvá-la.'
        else
            echo '3. Na primeira vez, ele pedirá sua senha única.'
        fi
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

    args=$(getopt -o 'yhv' -l 'nusp:,yes,dry-run,openfortivpn,fortisslvpn,help,version' -- "$@")
    eval "set -- $args"

    local VPN_CLIENT=OpenConnect
    while true; do
        case $1 in
        --nusp)
            shift
            NUSP=$1;;
        -y|--yes) ASK='--yes';;
        --dry-run) DRY_RUN='--dry-run';;
        --openfortivpn|--fortisslvpn) VPN_CLIENT=OpenFortiVPN;;
        -h|--help)
            exibir_ajuda
            exit;;
        -v|--version)
            echo $THIS_VERSION
            exit;;
        --)
            shift
            break;;
        -*)
            echo -e "${RED}Opção inválida: $1$NC" >&2
            exibir_ajuda
            exit 1;;
        esac
        shift
    done

    if [ $# -eq 0 ] || [ -z "$1" ]; then
        echo -e "${RED}AÇÃO ausente.$NC" >&2
    fi
    if [ $# -ne 1 ]; then 
        exibir_ajuda
        exit 1
    fi

    local ACTION="$1"
    if [ "$ACTION" == 'help' ]; then
        exibir_ajuda
        exit
    elif [ "$ACTION" == 'version' ]; then
        echo $THIS_VERSION
        exit
    elif [ "$ACTION" != 'install' ] && [ "$ACTION" != 'remove' ]; then
        echo -e "${RED}Ação desconhecida: $ACTION$NC" >&2
        exibir_ajuda
        exit 1
    fi

    if [ "$EUID" -ne 0 ]; then
      echo -e "${RED}Esta operação requer privilégios de superusuário.$NC" >&2
      echo -e "${YELLOW}Por favor, execute o comando novamente com 'sudo'. Ex: sudo $0 install$NC" >&2
      exit 2
    fi

    local REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
    if [[ "$REAL_USER" == 'root' ]]; then
      REAL_USER=
    fi

    if [ "$ACTION" = 'install' ]; then
        if [ ! -f /etc/os-release ]; then
            echo -e "${RED}Não foi possível encontrar o arquivo /etc/os-release para determinar a sua distribuição. Saindo.$NC" >&2
            exit 3
        fi
        . /etc/os-release

        echo -e "\nDetectando distribuição: ${NAME:-'desconhecida'} ${VERSION:-''}" >&2

        if [[ "${ID:-}" == 'debian' || "${ID_LIKE:-}" == 'debian' ]] && [[ "${VERSION_ID%%.*}" -lt 13 ]] && [[ "$VPN_CLIENT" != 'OpenFortiVPN' ]]; then
            VPN_CLIENT=OpenFortiGUI
        fi
        configurar_vpn "$REAL_USER" "$VPN_CLIENT"
    elif [ "$ACTION" = 'remove' ]; then
        remover_forticlient "$REAL_USER"
    fi
}

main "$@"
