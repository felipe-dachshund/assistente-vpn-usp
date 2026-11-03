# Suíte de Testes Automatizados - Assistente VPN USP

Este diretório contém a suíte de testes automatizados para o `assistente-vpn-usp.sh`.

## Estrutura dos Testes

- `run_tests.sh`: Script mestre para execução dos testes.
- `test_assistente.py`: Testes unitários e de integração utilizando o módulo `unittest` padrão do Python 3 (sem necessidade de dependências externas).
- `test_live.sh`: Teste interativo de conectividade e autenticação real com os servidores da USP.
- `containers/`: Arquivos Dockerfile e script para testar o script em contêineres multi-distro (Debian 13, Debian 12, Ubuntu 24.04 e Fedora 42).

## Como Executar

### 1. Testes Unitários e de Integração Locais
Para rodar a verificação de sintaxe e os testes automatizados locais (sem necessidade de privilégios de root):

```bash
./tests/run_tests.sh
```

Ou diretamente via Python:
```bash
python3 -m unittest discover tests -v
```

### 2. Testes em Contêineres Multi-distribuição
Para rodar os testes em ambientes isolados simulando distribuições Debian, Ubuntu e Fedora (requer Podman ou Docker instalado):

```bash
./tests/run_tests.sh --containers
```

### 3. Teste de Conexão Real (Interativo)
Para testar a conectividade e autenticação real com o gateway da USP (`orion.uspnet.usp.br:31443`):

```bash
./tests/run_tests.sh --live
```

> **Segurança de Credenciais:** As credenciais de acesso (Número USP e Senha Única) são solicitadas **interativamente** durante o teste. Elas **nunca** são armazenadas em disco, logs ou texto plano, e as variáveis são eliminadas da memória assim que o teste termina.
