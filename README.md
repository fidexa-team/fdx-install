# fdx — instalador

Instala o [fdx](https://github.com/fidexa-team/fdx) e deixa a máquina pronta para rodar. O código e os binários do fdx são privados: é preciso ter acesso a `fidexa-team/fdx` no GitHub (o instalador faz o login e confere).

**macOS, Linux e WSL:**

```bash
curl -fsSL https://raw.githubusercontent.com/fidexa-team/fdx-install/main/install.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/fidexa-team/fdx-install/main/install.ps1 | iex
```

No Windows, o fdx roda no Linux do WSL2: o script instala o WSL2 com Ubuntu se faltar, liga o systemd e executa o instalador lá dentro.

O instalador instala o git, o GitHub CLI e o Claude Code se faltarem, faz os logins, baixa a última release do fdx, sobe o daemon como serviço e verifica o Docker. Rodar de novo atualiza; para uma versão específica, `FDX_VERSION=v0.1.0` antes do `bash`.

Estes arquivos são cópias de `install/bootstrap.sh` e `install/install.ps1` do repositório do fdx: mude lá e copie para cá.
