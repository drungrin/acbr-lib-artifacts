# ACBr Libs - CI/CD Pipeline & DevOps Automation (Unofficial)

![Build Status](https://github.com/drungrin/acbr-lib-artifacts/actions/workflows/sync-and-build.yml/badge.svg)
![License](https://img.shields.io/badge/license-LGPL-blue.svg)

---

## 🚀 Sobre o Projeto

Este repositório contém uma implementação de **Integração Contínua (CI)** para o código fonte do componente ACBr, utilizando GitHub Actions.

O objetivo principal é demonstrar como automatizar o ciclo de vida de desenvolvimento em projetos **Lazarus/Pascal**, resolvendo desafios como:
* Configuração de ambiente de compilação em container (Docker).
* Gerenciamento de dependências nativas Linux/Windows.
* Automação de builds cross-platform.

### Como funciona a Automação?

1.  **Sincronização:** Diariamente, às 06:00 UTC (03:00 no horário de Brasília), o workflow incorpora novos commits da branch `main` do [mirror SVN makerplanet/acbr-mirror](https://github.com/makerplanet/acbr-mirror) na branch `master` deste repositório.
2.  **Ambiente:** Um container Docker (`drungrin/lazarus-builder`) é provisionado com o ambiente Lazarus pré-configurado.
3.  **Compilação:** O pipeline executa a compilação das bibliotecas nativas para **Linux (x64)** e **Windows (x64)**, garantindo a integridade do código.
4.  **Verificação:** O processo valida se o código atual do *upstream* é compilável em um ambiente limpo, servindo como um "Health Check" do projeto.

---

## 📥 Onde Baixar os Binários?

Para obter as bibliotecas compiladas, assinadas digitalmente e com suporte oficial, utilize os canais do mantenedor do projeto:

* **Site Oficial:** [Projeto ACBr](https://www.projetoacbr.com.br/)
* **Fórum:** [Fórum ACBr](https://www.projetoacbr.com.br/forum/)

---

## 🛠️ Detalhes Técnicos (DevOps)

A infraestrutura como código (IaC) deste repositório utiliza a seguinte stack:

* **CI/CD:** GitHub Actions.
* **Ambiente de Build:** Docker.
* **Imagem Base:** `drungrin/lazarus-builder:1.0.0` (Imagem customizada mantida por mim para build de Lazarus).
* **Script de Build:** Shell scripts otimizados para detecção de mudanças e compilação condicional.

### Estrutura do Workflow

* O sistema busca `makerplanet/acbr-mirror/main` e mantém a branch `master` sincronizada via `git merge upstream/main`.
* O agendamento diário e o disparo manual compartilham uma fila para evitar sincronizações simultâneas.
* A compilação é feita em ambiente efêmero (limpo) a cada execução.
* O build ocorre quando o merge incorpora alterações ou quando o workflow é disparado manualmente.
* O script de build também usa o novo mirror e mantém o checkout no diretório `ACBr`.

### Migração do Histórico

O antigo repositório `ProjetoACBr/ACBr` ficou indisponível. O novo mirror mantém o código do SVN `trunk2`, mas os commits recentes têm hashes diferentes dos da origem anterior.

A revisão SVN `r48491`, última incorporada antes da migração, tem a mesma árvore de arquivos nas duas origens: `3202212fc875b35dc927d23ef19daf2f7bfccaf8` no histórico antigo e `6b4156c1ed886641e56da0d01cead1ed02605d62` no novo mirror. Um commit inicial com a estratégia `ours` reconhece essa revisão equivalente como já incorporada, preservando os arquivos locais. Depois disso, as atualizações usam merges normais de `upstream/main`.

A estratégia `ours` é usada somente nessa migração inicial da revisão equivalente; o workflow diário aplica as alterações do mirror com o merge padrão.

---

## ⚖️ Licença e Créditos

Todo o código fonte do componente ACBr pertence ao **Projeto ACBr** e seus colaboradores.

* **Código Fonte Original:** [SVN trunk2 do Projeto ACBr](https://svn.code.sf.net/p/acbr/code/trunk2/)
* **Mirror utilizado na automação:** [makerplanet/acbr-mirror](https://github.com/makerplanet/acbr-mirror)
* **Licença:** LGPL (Lesser General Public License).

Este repositório respeita a licença original e o trabalho dos autores. O foco aqui é estritamente nas práticas de Engenharia de Software e Automação.
