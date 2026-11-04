#!/usr/bin/env bash
#
# tests/test_live.sh
# Teste de conexão real à VPN da USP.
#
# Importante:
# - As credenciais (NUSP e Senha Única) são solicitadas interativamente
#   durante a execução e NUNCA são salvas em disco ou em texto plano.
# - As variáveis de senha são desfeitas imediatamente da memória após o uso.
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

VPN_GATEWAY="orion.uspnet.usp.br"
VPN_PORT="31443"

# Garante que as variáveis de credenciais sejam limpas ao sair ou interromper
cleanup() {
    unset SENHA_USP OTP_TOKEN NUSP AUTH_INPUT
}
trap cleanup EXIT INT TERM

echo -e "${YELLOW}======================================================${NC}"
echo -e "${YELLOW}       Teste de Conexão Real - VPN da USP             ${NC}"
echo -e "${YELLOW}======================================================${NC}"
echo "Este teste verifica a conectividade e autenticação direta com"
echo "o gateway da VPN da USP ($VPN_GATEWAY:$VPN_PORT)."
echo
echo -e "${GREEN}Segurança:${NC} Suas credenciais são solicitadas interativamente,"
echo "não são gravadas em texto plano nem em logs, e são removidas da memória"
echo "assim que a validação é concluída."
echo

if [ ! -t 0 ]; then
    echo -e "${YELLOW}Ambiente não-interativo detectado (sem terminal TTY).${NC}"
    echo "Pulando teste de autenticação real (credenciais não fornecidas via terminal)."
    exit 0
fi

# Solicitação segura de credenciais
while [ -z "$NUSP" ]; do
    read -r -p "Digite seu Número USP (NUSP): " NUSP
    NUSP=$(echo "$NUSP" | tr -d ' .-/')
    if ! [[ "$NUSP" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}O NUSP deve conter apenas dígitos.${NC}"
        NUSP=""
    fi
done

read -r -s -p "Digite sua Senha Única USP: " SENHA_USP
echo
if [ -z "$SENHA_USP" ]; then
    echo -e "${RED}A senha não pode estar em branco.${NC}"
    exit 1
fi

echo -n "Possui autenticação de dois fatores (OTP/MFA)? [s/N]: "
read -r HAS_OTP
if [[ "$HAS_OTP" =~ ^[sSyY] ]]; then
    read -r -s -p "Digite o código OTP (ou pressione Enter se não aplicável): " OTP_TOKEN
    echo
fi

echo
echo "Testando conectividade de rede com $VPN_GATEWAY:$VPN_PORT..."
if ! nc -z -w 5 "$VPN_GATEWAY" "$VPN_PORT" 2>/dev/null && ! timeout 5 bash -c "</dev/tcp/$VPN_GATEWAY/$VPN_PORT" 2>/dev/null; then
    echo -e "${RED}Não foi possível alcançar o gateway $VPN_GATEWAY na porta $VPN_PORT.${NC}"
    echo "Verifique sua conexão com a internet ou restrições de firewall local."
    exit 1
fi
echo -e "${GREEN}Gateway alcançado com sucesso!${NC}"

# Se o openconnect estiver instalado, testa o handshake e autenticação SSL
if command -v openconnect &>/dev/null; then
    echo "Testando handshake e autenticação com o cliente OpenConnect..."
    # --authenticate efetua autenticação SSL com o gateway Fortinet e valida credenciais sem precisar de root/tun
    AUTH_INPUT="$NUSP"$'\n'"$SENHA_USP"
    if [ -n "${OTP_TOKEN:-}" ]; then
        AUTH_INPUT="$AUTH_INPUT"$'\n'"$OTP_TOKEN"
    fi

    if echo "$AUTH_INPUT" | openconnect --protocol=fortinet --authenticate "$VPN_GATEWAY:$VPN_PORT" >/dev/null 2>&1; then
        echo -e "${GREEN}Autenticação bem-sucedida! As credenciais e o gateway estão funcionando perfeitamente.${NC}"
    else
        echo -e "${YELLOW}A autenticação não pôde ser concluída.${NC}"
        echo "Verifique se o NUSP e a senha única estão corretos."
        exit 1
    fi
else
    echo -e "${YELLOW}Aviso: OpenConnect não está instalado no sistema local.${NC}"
    echo "A porta e o gateway foram validados com sucesso via TCP."
fi

echo
echo -e "${GREEN}Teste de conexão real finalizado com êxito!${NC}"
