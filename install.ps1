# Instalador do fdx para Windows — fica público no repositório
# fidexa-team/fdx-install. Uma linha, no PowerShell:
#
#   irm https://raw.githubusercontent.com/fidexa-team/fdx-install/main/install.ps1 | iex
#
# O fdx roda no Linux do WSL2: este script instala o WSL2 com Ubuntu se
# faltar, liga o systemd (para o daemon rodar como serviço) e executa lá
# dentro o instalador de macOS/Linux. Rodar de novo atualiza.

$ErrorActionPreference = 'Stop'
$Bootstrap = 'https://raw.githubusercontent.com/fidexa-team/fdx-install/main/install.sh'

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Green }
function Info($msg) { Write-Host "    $msg" }

# wsl.exe escreve em UTF-16; sem os NULs, a saída vira texto comum.
function Wsl([string[]]$WslArgs) { ((& wsl.exe @WslArgs) -join "`n") -replace "`0", '' }

function Find-Ubuntu {
	$names = (Wsl @('--list', '--quiet')) -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
	return $names | Where-Object { $_ -like 'Ubuntu*' } | Select-Object -First 1
}

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
	throw 'Este Windows não tem o WSL. É preciso o Windows 10 (versão 2004 ou mais nova) ou o Windows 11.'
}

Step 'WSL2 com Ubuntu'
$distro = $null
try { $distro = Find-Ubuntu } catch { }
if (-not $distro) {
	Info 'Instalando o WSL2 e o Ubuntu (pede permissão de administrador)...'
	Start-Process -FilePath 'wsl.exe' -ArgumentList '--install', '--distribution', 'Ubuntu', '--no-launch' -Verb RunAs -Wait
	try { $distro = Find-Ubuntu } catch { }
	if (-not $distro) {
		Info 'O Windows precisa reiniciar para terminar de instalar o WSL.'
		Info 'Depois de reiniciar, rode este mesmo comando de novo.'
		return
	}
	Info 'Abrindo o Ubuntu pela primeira vez: crie seu usuário e senha do Linux e depois digite "exit".'
	& wsl.exe --distribution $distro
}
Info "distribuição: $distro"

Step 'systemd no WSL (para o daemon rodar como serviço)'
$conf = ''
try { $conf = Wsl @('--distribution', $distro, '--user', 'root', '--', 'cat', '/etc/wsl.conf') } catch { }
if ($conf -notmatch '(?m)^\s*systemd\s*=\s*true') {
	& wsl.exe --distribution $distro --user root -- sh -c "printf '\n[boot]\nsystemd=true\n' >> /etc/wsl.conf"
	& wsl.exe --terminate $distro | Out-Null
	Info 'ligado (o Ubuntu foi reiniciado)'
} else {
	Info 'já ligado'
}

Step 'Instalando o fdx dentro do Ubuntu'
& wsl.exe --distribution $distro -- bash -lc "curl -fsSL $Bootstrap | bash"
if ($LASTEXITCODE -ne 0) { throw "a instalação dentro do Ubuntu falhou (código $LASTEXITCODE)" }

Step 'Pronto'
Info "Use o fdx no terminal do Ubuntu (wsl -d $distro) ou abra a interface: http://127.0.0.1:7433"
Info 'Para o Docker, instale o Docker Desktop no Windows e ative a integração com o WSL.'
