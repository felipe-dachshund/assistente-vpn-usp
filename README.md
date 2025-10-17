# Assistente de Configuração da VPN da USP

Um script em Bash que automatiza a configuração da VPN da Universidade de São Paulo (USP) em distribuições Linux. Ele instala clientes de código aberto (OpenConnect ou Openfortivpn), configura a conexão e, opcionalmente, remove por completo o software proprietário FortiClient.

## Por que usar este script?

- **Simplicidade:** Automatiza todo o processo de instalação e configuração com um único comando.
- **Limpeza:** Oferece uma remoção completa e segura do FortiClient, eliminando arquivos residuais que a desinstalação padrão pode deixar.
- **Inteligente:** Detecta sua distribuição Linux e escolhe a melhor solução de software livre para o seu sistema.
- **Código Aberto:** Ajuda você a migrar de uma solução proprietária para alternativas livres e mantidas pela comunidade.

## Uso Rápido

1.  **Baixe o script:**
    ```bash
    wget -O assistente-vpn-usp.sh https://raw.githubusercontent.com/felipe-dachshund/assistente-vpn-usp/main/assistente-vpn-usp.sh
    ```

2.  **Dê permissão de execução:**
    ```bash
    chmod +x assistente-vpn-usp.sh
    ```

### Comandos Principais

- **Para instalar a nova VPN:**
    ```bash
    sudo ./assistente-vpn-usp.sh --install
    ```
    O script solicitará seu Número USP, se necessário, e configurará tudo. Ao final, ele perguntará se você deseja remover o FortiClient.

- **Para remover o FortiClient:**
    Se você já tem a nova VPN funcionando ou quer apenas limpar uma instalação antiga, use:
    ```bash
    sudo ./assistente-vpn-usp.sh --remove
    ```

> **Aviso:** Antes de remover o FortiClient, garanta que todas as suas conexões VPN importantes já foram migradas para o novo software e estão funcionando corretamente.

## Como testar se a VPN funcionou

Não importa como você instalou, o teste é o mesmo:
1.  Conecte-se à VPN.
2.  Acesse o [Portal de Periódicos da CAPES](https://www.periodicos.capes.gov.br/).
3.  Se a conexão foi bem-sucedida, você verá a mensagem **"Você está acessando esse portal por: USP"** logo abaixo do título do site. Do contrário, você verá a mensagem "Você tem acesso ao conteúdo gratuito do Portal de Periódicos da CAPES".

## Compatibilidade

O script foi testado e é compatível com as seguintes distribuições Linux:

- **Debian** 12 ou superior (GNOME e KDE)
- **Ubuntu** 24.04 ou superior
- **Kubuntu** 25.10
- **Fedora** 42

Ele deve funcionar em derivados (como Linux Mint), mas não foi testado formalmente.

## Instalação Manual e Outras Plataformas

Prefere fazer tudo manualmente ou quer configurar a VPN no Android?

➡️ **Consulte o nosso [Guia de Instalação Manual](MANUAL.md)**.
