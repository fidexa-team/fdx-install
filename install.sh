#!/usr/bin/env bash
# Instalador do fdx para macOS, Linux e WSL — fica público no repositório
# fidexa-team/fdx-install. Uma linha:
#
#   curl -fsSL https://raw.githubusercontent.com/fidexa-team/fdx-install/main/install.sh | bash
#
# Ele instala o git e o GitHub CLI se faltarem, faz o login no GitHub e
# executa o instalador da release do fdx (privada: só para quem tem acesso
# a fidexa-team/fdx), que instala o resto e sobe o serviço. Rodar de novo
# atualiza. No Windows, use o install.ps1 no PowerShell.
set -euo pipefail

REPO="fidexa-team/fdx"

red=$'\033[31m' green=$'\033[32m' bold=$'\033[1m' reset=$'\033[0m'
[ -t 1 ] || { red='' green='' bold='' reset=''; }
step() { printf '\n%s==>%s %s%s%s\n' "$green" "$reset" "$bold" "$*" "$reset"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\n%serro:%s %s\n' "$red" "$reset" "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
TTY=""
{ : </dev/tty; } 2>/dev/null && TTY=/dev/tty

sudo_() { if [ "$(id -u)" = 0 ]; then "$@"; elif have sudo; then sudo "$@"; else die "é preciso sudo (ou root) para instalar: $*"; fi; }

case "$(uname -s)" in
	Darwin) os=macOS ;;
	Linux) os=Linux ;;
	*) die "sistema não suportado: $(uname -s). No Windows, rode no PowerShell: irm https://raw.githubusercontent.com/fidexa-team/fdx-install/main/install.ps1 | iex" ;;
esac

# ---- git e GitHub CLI ----

need=()
have git || need+=(git)
have gh || need+=(gh)
if [ ${#need[@]} -gt 0 ]; then
	step "Instalando ${need[*]}"
	if [ "$os" = macOS ]; then
		if ! have brew; then
			info "instalando o Homebrew (pede a sua senha)…"
			[ -n "$TTY" ] || export NONINTERACTIVE=1
			/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" <"${TTY:-/dev/null}"
			for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)"; done
		fi
		brew install "${need[@]}"
	elif have apt-get; then
		if [[ " ${need[*]} " == *" gh "* ]]; then
			# Repositório oficial do GitHub CLI.
			sudo_ mkdir -p -m 755 /etc/apt/keyrings
			curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo_ tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
			sudo_ chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
			echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
				sudo_ tee /etc/apt/sources.list.d/github-cli.list >/dev/null
		fi
		sudo_ apt-get update -qq
		sudo_ env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${need[@]}" >/dev/null
	elif have dnf; then
		if [[ " ${need[*]} " == *" gh "* ]]; then
			sudo_ dnf install -y -q 'dnf-command(config-manager)' >/dev/null 2>&1 || true
			sudo_ dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo >/dev/null 2>&1 ||
				sudo_ dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo >/dev/null
		fi
		sudo_ dnf install -y -q "${need[@]}"
	else
		die "não sei instalar pacotes nesta distribuição: instale ${need[*]} (https://cli.github.com) e rode de novo"
	fi
	for c in "${need[@]}"; do have "$c" || die "$c não ficou disponível depois da instalação"; done
fi

# ---- login no GitHub ----

if [ -z "${GH_TOKEN:-}" ] && ! gh auth status -h github.com >/dev/null 2>&1; then
	step "Login no GitHub"
	[ -n "$TTY" ] || die "o GitHub CLI não está logado e não há terminal para o login: rode \`gh auth login\` e de novo este comando"
	gh auth login --hostname github.com --git-protocol ssh --web <"$TTY"
fi
gh api "repos/$REPO" --silent 2>/dev/null ||
	die "sua conta GitHub ($(gh api user --jq .login 2>/dev/null || echo '?')) não tem acesso a $REPO: peça acesso à organização fidexa-team"

# ---- instalador da release ----

step "Baixando o instalador do fdx ${FDX_VERSION:-(última versão)}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
gh release download ${FDX_VERSION:+"$FDX_VERSION"} --repo "$REPO" --pattern install.sh --pattern checksums.txt --dir "$tmp"
if have sha256sum; then check="sha256sum -c -"; else check="shasum -a 256 -c -"; fi
(cd "$tmp" && grep " install.sh\$" checksums.txt | $check >/dev/null) || die "o checksum do instalador não confere"
bash "$tmp/install.sh"
