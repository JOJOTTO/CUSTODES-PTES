# recupération des ovas vms par une url "https://fyc2026.duckdns.org/vms_ovas.zip"

function Find-VMwarePaths {
    <#
    .SYNOPSIS
    Trouve les emplacements de VMware Workstation et des outils requis
    .DESCRIPTION
    Cherche les fichiers requis et retourne le chemin de base SEULEMENT si tous les outils sont trouvés:
    - vnetlib.exe
    - ovftool.exe
    - vmnetdhcp.conf
    Sinon, quitte le script.
    #>
    
    $vmwarePaths = @{
        vnetlib     = $null
        ovftool     = $null
        vmwarePath  = $null
    }
    
    # Chercher les répertoires VMware dans Program Files et Program Files (x86)
    $searchPaths = @(
        "C:\Program Files\VMware",
        "C:\Program Files (x86)\VMware"
    )
    
    Write-Host "Recherche des installations VMware..." -ForegroundColor Cyan
    
    # Chercher vnetlib.exe et ovftool.exe
    foreach ($basePath in $searchPaths) {
        if (Test-Path $basePath) {
            # Chercher vnetlib.exe
            if (-not $vmwarePaths.vnetlib) {
                $vnetlib = Get-ChildItem -Path $basePath -Filter "vnetlib.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($vnetlib) {
                    $vmwarePaths.vnetlib = $vnetlib.FullName
                    Write-Host "[ok] vnetlib trouvé: $($vmwarePaths.vnetlib)" -ForegroundColor Green
                }
            }
            
            # Chercher ovftool.exe
            if (-not $vmwarePaths.ovftool) {
                $ovftool = Get-ChildItem -Path $basePath -Filter "ovftool.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($ovftool) {
                    $vmwarePaths.ovftool = $ovftool.FullName
                    Write-Host "[ok] ovftool trouvé: $($vmwarePaths.ovftool)" -ForegroundColor Green
                }
            }
        }
    }
    
    # Récupérer le répertoire VMware principal
    if ($vmwarePaths.vnetlib) {
        $vmwarePaths.vmwarePath = Split-Path -Parent $vmwarePaths.vnetlib

        # verifier que les deux autres outils sont dans le même répertoire parent
        if (-not ($vmwarePaths.ovftool -like "$($vmwarePaths.vmwarePath)*")) {
            $vmwarePaths.vmwarePath = $Null
        }
    }
    
    # Vérifier que TOUS les outils essentiels sont trouvés
    $missingTools = @()
    
    if (-not $vmwarePaths.vnetlib) {
        $missingTools += "vnetlib.exe"
    }
    if (-not $vmwarePaths.ovftool) {
        $missingTools += "ovftool.exe"
    }
    
    if ($missingTools.Count -gt 0) {
        Write-Host "`n[ERREUR CRITIQUE] Outils manquants:" -ForegroundColor Red
        foreach ($tool in $missingTools) {
            Write-Host "  - $tool" -ForegroundColor Red
        }
        Write-Host "`nVeuillez vérifier que VMware Workstation est correctement installé." -ForegroundColor Yellow
        Write-Host "Chemins attendus:" -ForegroundColor Yellow
        Write-Host "  - C:\Program Files\VMware\" -ForegroundColor Yellow
        Write-Host "  - C:\Program Files (x86)\VMware\" -ForegroundColor Yellow
        throw "Outils VMware manquants. Abandon du script."
    }
    
    Write-Host "`n[OK] Tous les outils VMware trouvés avec succès!" -ForegroundColor Green
    return $vmwarePaths
}
function Generate-UUID {
    <#
    .SYNOPSIS
    Génère un UUID au format VMware (HEX formaté)
    #>
    $guid = [guid]::NewGuid()
    $bytes = $guid.ToByteArray()
    $hex = ($bytes | ForEach-Object { "{0:X2}" -f $_ }) -join " "
    return $hex.Substring(0, 23) + "-" + $hex.Substring(24)
}

function Get-VMwareInventoryPath {
    <#
    .SYNOPSIS
    Trouve dynamiquement le fichier inventory.vmls de VMware
    #>
    $inventoryPath = "$env:APPDATA\VMware\inventory.vmls"
    
    if (Test-Path $inventoryPath) {
        return $inventoryPath
    } else {
        Write-Host "Fichier inventory.vmls non trouvé à: $inventoryPath" -ForegroundColor Yellow
        return $null
    }
}

function Add-VMToInventory {
    <#
    .SYNOPSIS
    Ajoute une VM à l'inventaire VMware au format correct
    .PARAMETER VMXPath
    Chemin complet du fichier .vmx de la VM
    .PARAMETER DisplayName
    Nom affiché de la VM dans VMware
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VMXPath,
        
        [Parameter(Mandatory=$true)]
        [string]$DisplayName
    )
    
    $inventoryPath = Get-VMwareInventoryPath
    
    if (-not $inventoryPath) {
        Write-Host "Impossible d'ajouter la VM à l'inventaire" -ForegroundColor Red
        return $false
    }
    
    # Lire l'inventaire existant
    $content = Get-Content $inventoryPath -Raw
    
    # Trouver le prochain numéro de slot disponible
    $matches = [regex]::Matches($content, 'vmlist(\d+)\.config')
    $maxNum = 0
    foreach ($match in $matches) {
        $num = [int]$match.Groups[1].Value
        if ($num -gt $maxNum) { $maxNum = $num }
    }
    $nextNum = $maxNum + 1
    
    # Créer l'UUID pour la VM
    $uuid = [guid]::NewGuid().ToString()
    
    # Ajouter les entrées dans le format VMware
    $newEntries = @"

vmlist$nextNum.config = "$VMXPath"
vmlist$nextNum.DisplayName = "$DisplayName"
vmlist$nextNum.ParentID = "0"
vmlist$nextNum.ItemID = "$nextNum"
vmlist$nextNum.SeqID = "0"
vmlist$nextNum.IsFavorite = "FALSE"
vmlist$nextNum.IsClone = "FALSE"
vmlist$nextNum.CfgVersion = "8"
vmlist$nextNum.State = "normal"
vmlist$nextNum.UUID = "$(Generate-UUID)"
vmlist$nextNum.IsCfgPathNormalized = "TRUE"
vmlist.$uuid = "$VMXPath"
"@
    
    # Ajouter à l'inventaire
    $content += $newEntries
    
    # Sauvegarder
    Set-Content -Path $inventoryPath -Value $content
    
    Write-Host "[ok] VM ajoutée à l'inventaire: $DisplayName (slot $nextNum)" -ForegroundColor Green
    return $true
}

function Get-VmsOvas {
    param (
        [string]$url = "https://fyc2026.duckdns.org/vms_ovas.zip",
        [string]$destinationPath = "$PSScriptRoot\vms_ovas.zip"
    )

    # Télécharger le fichier zip
    $res = Invoke-WebRequest -Uri $url -OutFile $destinationPath
    if ($res.StatusCode -ne 200) {
        throw "Erreur lors du téléchargement du fichier: $($res.StatusCode)"
    }

    return $res
}

function Extract-VmsOvas {
    param (
        [string]$zipPath = "$PSScriptRoot\vms_ovas.zip",
        [string]$extractPath = "$PSScriptRoot"
    )

    # Créer le répertoire de destination s'il n'existe pas
    if (-not (Test-Path -Path $extractPath)) {
        New-Item -ItemType Directory -Path $extractPath | Out-Null
    }

    # Extraire le fichier zip
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    return $extractPath
}

# checker que le dossier vms_ovas existe et contient des fichiers
    # sinon lancer le téléchargement et l'extraction
    # si oui
        # regarde bien qu'on est tout les ovf soit "SRV-WINDOWS-01.ovf", "SRV-WINDOWS-02.ovf", "TLS-DC-01.ovf", "SRV-WEB-01.ovf", "GRB-DC-01.ovf"
        # sinon supprimer tout les fichiers du dossier et relancer le téléchargement et l'extraction

function Ensure-VmsOvas {
    param (
        [string]$vmsOvfsPath = "$PSScriptRoot\vms_ovfs"
    )

    $requiredOvfs = @(
        "SRV-WINDOWS-01.ovf",
        "SRV-WINDOWS-02.ovf",
        "TLS-DC-01.ovf",
        "SRV-WEB-01.ovf",
        "GRB-DC-01.ovf"
    )
    try {
        
        # Vérifier si le dossier existe et contient les fichiers
        if (Test-Path -Path $vmsOvfsPath) {
            $ovfFiles = @(Get-ChildItem -Path $vmsOvfsPath -Filter "*.ovf" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
            
            # Vérifier que tous les fichiers requis sont présents
            $allPresent = $true
            foreach ($requiredOvf in $requiredOvfs) {
                if ($requiredOvf -notin $ovfFiles) {
                    $allPresent = $false
                    break
                }
            }

            # Si tous les fichiers sont présents, retourner le chemin
            if ($allPresent) {
                Write-Host "Les fichiers OVF sont déjà présents." -ForegroundColor Green
                return $True
            }

            Write-Host "Suppression des fichiers OVF incomplets..." -ForegroundColor Yellow
            #Remove-Item -Path $vmsOvfsPath -Recurse -Force
            return $True
        }

        if (-not (Test-Path -Path "$vmsOvfsPath.zip")) {
            Write-Host "Téléchargement des fichiers OVF..." -ForegroundColor Yellow
            Get-VmsOvas
        } else {
            Write-Host "Fichier zip des OVF déjà téléchargé." -ForegroundColor Green
        }
        
        Write-Host "Extraction des fichiers OVF..." -ForegroundColor Yellow
        Extract-VmsOvas -extractPath $vmsOvfsPath

        return $True
    } catch {
        Write-Host "Une erreur est survenue: $_" -ForegroundColor Red
        return $False
    }
}  

Write-Host "=== Vérification des fichiers OVF des labs ===" -ForegroundColor Cyan
$success = Ensure-VmsOvas
if (-not $success) {
    Write-Host "Impossible de vérifier ou d'extraire les fichiers OVF. Abandon." -ForegroundColor Red
    exit 1
}

# Vérifier admin
# $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
# if (-not $isAdmin) {
#     Write-Host "ERREUR: Exécuter en tant qu'administrateur!" -ForegroundColor Red
#     exit 1
# }

# Trouver les chemins VMware
Write-Host "`n=== Détection des outils VMware ===" -ForegroundColor Cyan
$vmwarePaths = Find-VMwarePaths

# ===== DÉPLOIEMENT DES VMS =====
Write-Host "`n`n=== Déploiement des VMs ===" -ForegroundColor Cyan

$ovfsFolder = "$PSScriptRoot\vms_ovfs"

# Trouver le dossier des VMs de VMware dynamiquement
Write-Host "Recherche du dossier des VMs VMware..." -ForegroundColor Cyan
$prefsFile = "$env:APPDATA\VMware\preferences.ini"

if (Test-Path $prefsFile) {
    $prefs = Get-Content $prefsFile -Raw
    $vmxPath = [regex]::Match($prefs, 'pref\.mruVM0\.filename\s*=\s*"([^"]+)"').Groups[1].Value
    
    if ($vmxPath) {
        $vmFolder = Split-Path -Parent (Split-Path -Parent $vmxPath)
        Write-Host "Dossier trouvé: $vmFolder" -ForegroundColor Green
    } else {
        Write-Host "Impossible de trouver le dossier. Utilisation par défaut..." -ForegroundColor Yellow
        $vmFolder = "$env:USERPROFILE\Vms\LabVms"
    }
} else {
    Write-Host "Fichier preferences.ini non trouvé. Utilisation par défaut..." -ForegroundColor Yellow
    $vmFolder = "$env:USERPROFILE\Vms\LabVms"
}

# Vérifier ovftool (déjà trouvé via Find-VMwarePaths)
$ovftool = $vmwarePaths.ovftool

if (-not (Test-Path $vmFolder)) {
    New-Item -ItemType Directory -Path $vmFolder -Force | Out-Null
}

if (-not (Test-Path $ovfsFolder)) {
    Write-Host "Dossier vms_ovfs n'existe pas. Arret du script" -ForegroundColor Yellow
    exit 0
}

$ovfFiles = Get-ChildItem -Path $ovfsFolder -Filter "*.ovf" -ErrorAction SilentlyContinue

if ($ovfFiles.Count -eq 0) {
    Write-Host "Aucun fichier OVF trouvé dans $ovfsFolder" -ForegroundColor Yellow
    exit 0
}

Write-Host "Trouvé $($ovfFiles.Count) OVF(s) à déployer`n" -ForegroundColor Green
foreach ($ovfFile in $ovfFiles) {
    $vmName = $ovfFile.BaseName
    $ovfPath = $ovfFile.FullName
    $vmPath = "$vmFolder\$vmName"
    
    Write-Host "--- $vmName ---" -ForegroundColor Yellow

    if ((Test-Path $vmPath)) {
        Write-Host "[SKIP] Déjà présente" -ForegroundColor Yellow
        continue
    }

    Write-Host "Déploiement ..." -ForegroundColor Cyan
    
    # Exécuter ovftool
    & $ovftool --machineOutput --X:logLevel=verbose --name=$vmName --maxVirtualHardwareVersion=21 --acceptAllEulas --allowExtraConfig "$ovfPath" "$vmFolder" | Out-Null
    
    if (Test-Path "$vmPath\$vmName.vmx") {
        Write-Host "[ok] Importée" -ForegroundColor Green
        
        $success = Add-VMToInventory -VMXPath "$vmPath\$vmName.vmx" -DisplayName $vmName

    } else {
        Write-Host "[ERREUR] Échouée" -ForegroundColor Red
        continue
    }
}

Write-Host "`n=== Terminé ===" -ForegroundColor Green
