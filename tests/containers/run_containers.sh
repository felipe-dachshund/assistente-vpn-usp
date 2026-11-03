#!/usr/bin/env bash
#
# tests/containers/run_containers.sh
# Constrói e executa testes automatizados nos contêineres Debian, Ubuntu e Fedora
# utilizando Podman ou Docker.
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Detecta engine de contêineres
CONTAINER_CMD=""
if command -v podman &>/dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker &>/dev/null; then
    CONTAINER_CMD="docker"
fi

if [ -z "$CONTAINER_CMD" ]; then
    echo -e "${RED}Erro: Nem 'podman' nem 'docker' foram encontrados no sistema.${NC}"
    echo "Para executar os testes em contêineres, instale podman ou docker:"
    echo "  Debian/Ubuntu: sudo apt install podman (ou docker.io)"
    echo "  Fedora:        sudo dnf install podman (ou moby-engine)"
    exit 1
fi

echo -e "${GREEN}Utilizando engine de contêiner: $CONTAINER_CMD${NC}\n"

DISTROS=("debian13" "debian12" "ubuntu24" "fedora42")

for distro in "${DISTROS[@]}"; do
    dockerfile="$SCRIPT_DIR/Dockerfile.$distro"
    tag="assistente-vpn-test:$distro"

    if [ ! -f "$dockerfile" ]; then
        echo -e "${YELLOW}Aviso: Dockerfile não encontrado para $distro ($dockerfile). Pulando.${NC}"
        continue
    fi

    echo -e "${YELLOW}======================================================${NC}"
    echo -e "${YELLOW} Testando contêiner: $distro ($tag)                 ${NC}"
    echo -e "${YELLOW}======================================================${NC}"

    echo "Construindo imagem para $distro..."
    $CONTAINER_CMD build -t "$tag" -f "$dockerfile" "$ROOT_DIR"

    echo "Executando testes no contêiner $distro..."
    $CONTAINER_CMD run --rm -t "$tag"

    echo -e "${GREEN}Testes concluídos com sucesso em $distro!${NC}\n"
done

echo -e "${GREEN}Todos os testes em contêineres foram concluídos com êxito!${NC}"
