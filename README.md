# ACBr Libs - Builds Diários Automatizados (Unofficial)

![Build Status](https://github.com/drungrin/acbr-lib-artifacts/actions/workflows/sync-and-build.yml/badge.svg)
![License](https://img.shields.io/badge/license-LGPL-blue.svg)
![Release](https://img.shields.io/github/v/release/drungrin/acbr-lib-artifacts?label=latest%20build)

> ⚠️ **AVISO LEGAL:** Este projeto é uma iniciativa independente e **NÃO OFICIAL**. Não possui qualquer vínculo comercial ou administrativo com o "Projeto ACBr" ou seus mantenedores. Este repositório foca puramente em práticas de DevOps e CI/CD.

---

## 🚀 Sobre o Projeto

Este repositório mantém um **espelho automatizado** do código fonte do componente ACBr e utiliza o GitHub Actions para compilar as bibliotecas diariamente.

O objetivo é agilizar o processo de desenvolvimento, disponibilizando os binários compilados (`.dll` e `.so`) atualizados, eliminando a necessidade de configurar manualmente todo o ambiente de compilação (Lazarus/Pascal/Docker) apenas para testar ou utilizar as bibliotecas.

### Como funciona?

1.  **Sincronização:** Diariamente (às 06:00 UTC), um script verifica se há novos commits no [repositório oficial do ACBr](https://github.com/ProjetoACBr/ACBr).
2.  **Build:** Se houver atualizações, um container Docker é iniciado.
3.  **Compilação:** O ambiente compila as bibliotecas nativas para **Linux (x64)** e **Windows (x64)**.
4.  **Release:** Um arquivo `.zip` contendo todos os artefatos gerados é publicado automaticamente na aba "Releases".

---

## 📥 Como Baixar (Downloads)

Os arquivos compilados estão disponíveis na aba **Releases** deste repositório.

1.  Clique em [**Releases**](https://github.com/SEU-USUARIO/SEU-REPO/releases) no menu lateral.
2.  Escolha a versão mais recente (identificada pela data).
3.  Baixe o arquivo `acbr-libs-AAAA-MM-DD.zip`.

O pacote inclui binários para diversos componentes, como:
* ACBrLibNFe / NFCe
* ACBrLibSAT
* ACBrLibBoleto
* ACBrLibPIXCD
* E os demais componentes suportados pelo script de build.

---

## 🛠️ Detalhes Técnicos

O pipeline de build utiliza a seguinte stack:

* **CI/CD:** GitHub Actions.
* **Ambiente de Build:** Docker.
* **Imagem Base:** `drungrin/lazarus-builder:1.0.0` (Ambiente Lazarus pré-configurado).
* **Script de Build:** Customizado para gerenciamento de dependências.

### Estrutura do Workflow

* O sistema mantém o fork atualizado via `git merge upstream/master`.
* A compilação é feita em ambiente limpo a cada execução.
* Caso não haja mudanças no código fonte original, o build não é executado para otimizar recursos.

---

## ⚖️ Licença e Créditos

Todo o código fonte utilizado para gerar estes binários pertence ao **Projeto ACBr** e seus colaboradores.

* **Código Fonte Original:** [github.com/ProjetoACBr/ACBr](https://github.com/ProjetoACBr/ACBr)
* **Licença:** LGPL (Lesser General Public License).

Este repositório respeita a licença original, mantendo o código fonte aberto e acessível. Para suporte oficial ou consultoria, recomendamos o contato direto com os autores originais.

---
