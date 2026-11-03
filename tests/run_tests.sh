#!/usr/bin/env bash
#
# tests/run_tests.sh
# Executor principal da suíte de testes do Assistente VPN USP.
#
# Uso:
#   ./tests/run_tests.sh             # Executa verificações de sintaxe e testes unitários/integração
#   ./tests/run_tests.sh --containers# Executa os testes em contêineres (Podman/Docker)
#   ./tests/run_tests.sh --live      # Executa teste interativo de conexão real com a USP
#   ./tests/run_tests.sh --all       # Executa todos os testes
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RUN_UNIT=true
RUN_CONTAINERS=false
RUN_LIVE=false

for arg in "$@"; do
    case "$arg" in
        --containers)
            RUN_UNIT=false
            RUN_CONTAINERS=true
            ;;
        --live)
            RUN_UNIT=false
            RUN_LIVE=true
            ;;
        --all)
            RUN_UNIT=true
            RUN_CONTAINERS=true
            RUN_LIVE=true
            ;;
        -h|--help)
            echo "Uso: $0 [OPÇÕES]"
            echo
            echo "Opções:"
            echo "  (sem opções)   Executa verificação de sintaxe e testes unitários locais."
            echo "  --containers   Executa testes em contêineres multi-distro (Debian, Ubuntu, Fedora)."
            echo "  --live         Executa teste de autenticação real com a USP (solicita credenciais de forma segura)."
            echo "  --all          Executa todos os testes (unitários, contêineres e live)."
            echo "  -h, --help     Exibe esta ajuda."
            exit 0
            ;;
        *)
            echo -e "${RED}Opção desconhecida: $arg${NC}" >&2
            exit 1
            ;;
    esac
done

if [ "$RUN_UNIT" = true ]; then
    echo -e "${YELLOW}======================================================${NC}"
    echo -e "${YELLOW}  1. Verificação de Sintaxe Bash                      ${NC}"
    echo -e "${YELLOW}======================================================${NC}"
    echo -n "Verificando assistente-vpn-usp.sh... "
    bash -n "$ROOT_DIR/assistente-vpn-usp.sh"
    echo -e "${GREEN}OK!${NC}"

    if command -v shellcheck &>/dev/null; then
        echo -n "Executando shellcheck... "
        shellcheck -e SC1091 "$ROOT_DIR/assistente-vpn-usp.sh"
        echo -e "${GREEN}OK!${NC}"
    fi

    echo
    echo -e "${YELLOW}======================================================${NC}"
    echo -e "${YELLOW}  2. Testes Unitários e de Integração (Python)        ${NC}"
    echo -e "${YELLOW}======================================================${NC}"
    python3 "$SCRIPT_DIR/test_assistente.py" -v
    echo -e "${GREEN}Testes unitários concluídos com sucesso!${NC}\n"
fi

if [ "$RUN_CONTAINERS" = true ]; then
    echo -e "${YELLOW}======================================================${NC}"
    echo -e "${YELLOW}  3. Testes em Contêineres Multi-distribuição        ${NC}"
    echo -e "${YELLOW}======================================================${NC}"
    bash "$SCRIPT_DIR/containers/run_containers.sh"
    echo
fi

if [ "$RUN_LIVE" = true ]; then
    echo -e "${YELLOW}======================================================${NC}"
    echo -e "${YELLOW}  4. Teste de Conexão Real (Interativo)              ${NC}"
    echo -e "${YELLOW}======================================================${NC}"
    bash "$SCRIPT_DIR/test_live.sh"
    echo
fi

echo -e "${GREEN}Suíte de testes finalizada com êxito!${NC}"
