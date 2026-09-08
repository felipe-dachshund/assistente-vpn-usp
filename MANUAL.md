# Guia de Instalação Manual da VPN da USP

Este documento contém instruções detalhadas para configurar manualmente a VPN da USP em distribuições Linux e no Android, além de um guia para a remoção manual completa do FortiClient.

**Sumário**
 -  Instalação e Configuração no Linux
    - Usando NetworkManager-OpenConnect
    - Usando OpenFortiGUI
    - Usando NetworkManager-fortisslvpn
    - Usando OpenFortiVPN sem Interface
 -  Instalação e Configuração no Android
 -  Remoção Manual Completa do FortiClient

## Instalação e Configuração no Linux

A solução ideal varia conforme a versão da sua distribuição Linux, devido à compatibilidade com o protocolo Fortinet SSL VPN.

- **Debian 13+, Ubuntu 24.04+, Fedora 37+:** Usam versões recentes do NetworkManager que funcionam bem com o plugin OpenConnect. Esta é a opção recomendada, pois se integra perfeitamente ao sistema.
- **Debian 12 ou anterior:** A versão do plugin OpenConnect disponível pode apresentar instabilidade. Nesses casos, a melhor alternativa é o OpenFortiVPN, possivelmente com a interface gráfica do OpenFortiGUI.

### Usando NetworkManager-OpenConnect (Recomendado)

1.  **Instale os pacotes necessários** (para Debian/Ubuntu):
    ```bash
    sudo apt update
    sudo apt install network-manager-openconnect
    ```
    O `NetworkManager-openconnect` já vem instalado no Fedora.

2.  **(Opcional) Para integração com o ambiente GNOME**, instale também:
    ```bash
    sudo apt install network-manager-openconnect-gnome
    ```
    O `NetworkManager-openconnect-gnome` já vem instalado no Fedora.

3.  **Recarregue o NetworkManager** (pode ser necessário no Debian):
    ```bash
    sudo nmcli connection reload
    ```

4.  **Crie a conexão VPN:**
    - Abra as Configurações de Rede do seu sistema.
    - Vá até a seção de VPN e clique para adicionar uma nova (`+`).
    - **GNOME:**
        - Escolha a opção **Cliente VPN Multiprotocolo (openconnect)**.
        - Preencha os campos na aba **Identidade**:
            - **Nome:** VPN USP (ou o nome que preferir)
            - **Protocolo VPN:** Fortinet SSL VPN
            - **Gateway:** `orion.uspnet.usp.br:31443`
    - **KDE:**
        - Escolha a opção **VPN compatível com Fortinet (openconnect)**
        - Preencha o campo **Nome da conexão** com `VPN USP`. Na aba **VPN (openconnect)**, preencha os demais campos:
            - **Protocolo VPN:** Fortinet SSL VPN
            - **Gateway:** `orion.uspnet.usp.br:31443`
    - Salve a configuração.

5.  **Conecte-se:**
    Ao conectar pela primeira vez, o sistema pedirá seu nome de usuário (NUSP) e senha (senha única). Você pode optar por salvá-los para futuros acessos.

### Usando OpenFortiGUI

O OpenFortiGUI é uma interface gráfica em Qt e já vem com OpenFortiVPN. É uma alternativa razoável no Debian 12, onde o NetworkManager-OpenConnect pode não funcionar para o protocolo Fortinet, mas também funciona no Debian 13 e no (K)Ubuntu.

1.  Siga as instruções em https://apt.iteas.at/ para adicionar o repositório APT.
    Obs.: Pode ser necessário entrar numa sessão de _root_ para conseguir executar os comandos sem erro. Faça isso com o comando `su` ou com `sudo su` e, ao terminar, execute `exit` para sair da sessão de _root_ e voltar à anterior.

2.  Atualize a lista de programas e instale o OpenFortiGUI:
    ```bash
    apt update
    apt install openfortigui
    ```

3.  Abra o OpenFortiGUI. Ele deve iniciar o assistente de configuração (_setup wizard_)
    - Clique em _Next_.
    - Recomenda-se selecionar a caixa _Password Manager_ para que a chave criptográfica do openFortiGUI seja armazenada no chaveiro do sistema, mais bem protegida.
    - Recomenda-se também clicar no botão _Autogenerate keys_. Aquelas chaves _default_ do openFortiGUI, começando com yowp2… e VoUT5… são fixas e, portanto, não seguras. Além disso, essas chaves são para uso interno do programa; você não precisará memorizá-las, elas podem ser aleatórias.
    - Encerre o assistente clicando em _Finish_.
    Se tiver saído do assistente de configuração por engano, pode iniciá-lo de novo em _File_ > _Setup wizard_. Todas essas opções também estão disponíveis nas configurações (_File_ > _Settings_).

4.  Para criar um novo perfil VPN, clique em _Add_ > _VPN_ e preencha os campos da caixa de diálogo:
    - Aba _VPN-Preferences_
        - **Common**
            - **Name:** VPN USP (ou o nome que preferir)
            - **VPN-Server:** orion.uspnet.usp.br
            - **VPN-Device:** Fortigate
            - **VPN-Port:** 31443
        - [x] **Credentials**
            - **Username:** NUSP
            - **Password:** senha única
        - **Fortigate Gateway Validation**
            - [x] Trust all certs
    - Aba _Options_
        - **PPPD**
            - [x] Accept remote
                **Atenção:** Marque a caixa _à direita_; a da esquerda é outro campo.
    - Clique em _Save_.

5.  Para se conectar, selecione o perfil VPN desejado e clique em _Connect_.

### Usando NetworkManager-fortisslvpn

Outra alternativa para Debian 12 é o OpenFortiVPN integrado ao NetworkManager. No entanto, o NetworkManager-fortisslvpn parece ter deixado de funcionar em atualizações mais recentes do Debian 12.

1.  **Instale os pacotes necessários** (para Debian/Ubuntu):
    ```bash
    sudo apt update
    sudo apt install network-manager-fortisslvpn
    ```

2.  **(Opcional) Para integração com o ambiente GNOME**, instale também:
    ```bash
    sudo apt install network-manager-fortisslvpn-gnome
    ```

3.  **Crie a conexão VPN:**
    - Abra as Configurações de Rede do seu sistema.
    - Vá até a seção de VPN e clique para adicionar uma nova (`+`).
    - Escolha a opção **Fortinet SSLVPN**.
    - **GNOME:**
        - Preencha os campos na aba **Identidade**:
            - **Nome:** VPN USP (ou o nome que preferir)
            - **Gateway:** `orion.uspnet.usp.br:31443`
            - **Nome de usuário:** NUSP
        Se preferir, clique no ícone do campo **Senha**, escolha para armazená-la e insira sua senha única.
    - **KDE:**
        - Preencha o campo **Nome da conexão** com `VPN USP`. Na aba **VPN (fortisslvpn)**, preencha os demais campos:
            - **Gateway:** `orion.uspnet.usp.br:31443`
            - **Nome de usuário:** NUSP
            - **Senha:** senha única
    - Salve a configuração.

### Usando OpenFortiVPN sem Interface

1.  Instale apenas o OpenFortiVPN:
    ```bash
    sudo apt update
    sudo apt install openfortivpn
    ```

2.  Como _root_, crie o arquivo de configuração `/etc/openfortivpn/vpn-usp` com o conteúdo a seguir (substituindo `NUSP` pelo seu NUSP):
    ```ini
    host = orion.uspnet.usp.br
    port = 31443
    username = NUSP
    ```

3.  Inicie a conexão com `sudo openfortivpn -c /etc/openfortivpn/vpn-usp`. Ele vai pedir a senha; use sua senha única. A conexão estará estabelecida quando surgir a mensagem `Tunnel is up and running`. Para encerrar a conexão, volte ao terminal e pressione Ctrl+C.

## Instalação e Configuração no Android

1.  **Instale o cliente OpenConnect** a partir do [F-Droid](https://f-droid.org/packages/net.openconnect_vpn.android/).
    **Atenção:** Não instale versões da Play Store. A versão do F-Droid é a oficial, livre de anúncios e de código aberto.

2.  **Abra o app e adicione um novo perfil** (`+` no canto superior direito).
3.  Digite o endereço do servidor: `orion.uspnet.usp.br:31443` e confirme.
4.  **Edite o perfil criado.** Na seção _Server_, preencha os campos:
    - **Profile name:** VPN USP
    - **VPN Protocol:** Fortinet SSL VPN
    Na seção _Advanced_, desmarque a caixa _Use DTLS_.
5.  **Conecte-se:**
    Toque no perfil **VPN USP**. Na primeira vez, insira seu NUSP e senha única. Marque a opção para salvar a senha, se desejar.

## Remoção Manual Completa do FortiClient

Se você já migrou suas conexões e deseja remover o FortiClient manualmente, siga estes passos para uma limpeza completa.

1.  Remova o pacote principal:
    - **Debian/Ubuntu:** `sudo apt purge forticlient`
    - **Fedora:** `sudo dnf remove forticlient`

2.  Exclua diretórios de configuração:
    ```bash
    sudo rm -r /etc/forticlient/
    rm -r ~/.config/FortiClient/
    ```

3.  Remova os arquivos do repositório:
    - **Debian/Ubuntu:**
        ```bash
        sudo rm /etc/apt/sources.list.d/repo.fortinet.com.list \
            /etc/apt/trusted.gpg.d/repo.fortinet.com.gpg \
            /usr/share/keyrings/repo.fortinet.com.gpg
        ```
        Remova também todas as linhas de `/etc/apt/sources.list` que contenham a URL base `https://repo.fortinet.com/`.
    - **Fedora:**
        ```bash
        sudo rm -f /etc/yum.repos.d/fortinet.repo
        ```

4.  Remova as chaves GPG do repositório:
    - **Debian/Ubuntu** (se usou `apt-key`):
        ```bash
        # Encontra e remove a chave antiga
        KEY_ID=$(apt-key list 2>/dev/null | grep -B 1 "Fortinet" | head -n 1 | tr -d ' ')
        if [ ! -z "$KEY_ID" ]; then sudo apt-key del "$KEY_ID"; fi
        sudo apt update
        ```
    - **Fedora:**
        ```bash
        # Encontra e remove as chaves GPG do Fortinet
        rpm -qa gpg-pubkey* | xargs -I {} sh -c 'rpm -qi {} 2>/dev/null | grep -q "Fortinet" && echo {}' | xargs sudo rpm -e
        sudo dnf clean all
        ```

5.  (Opcional) Remova senhas salvas:
    O FortiClient pode salvar credenciais no chaveiro do sistema.
    - Instale o aplicativo `seahorse` (Senhas e chaves), se não o tiver:
        - **Debian/Ubuntu:** `sudo apt install seahorse`
        - **Fedora:** `sudo dnf install seahorse`
    - Abra o programa, procure por chaves relacionadas ao FortiClient no chaveiro "Login" e as remova.
