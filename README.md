# LAB CUSTODES PTES - Déploiement Automatisé de Lab VMware (Auto-Download)

Ce script PowerShell automatise entièrement la mise en place de l'environnement de laboratoire. Il se charge de télécharger les sources (fichiers OVF), de vérifier la présence des outils VMware nécessaires, et de déployer les machines virtuelles dans VMware Workstation.

## 📋 Fonctionnalités Clés

1.  **Téléchargement Automatique :**
    * Récupère l'archive `vms_ovas.zip` depuis le serveur distant (`fyc2026.duckdns.org`).
    * Extrait automatiquement les fichiers `.ovf` dans le dossier local.
    * Vérifie l'intégrité des fichiers requis avant de poursuivre.

2.  **Détection Intelligente :**
    * Localise automatiquement l'installation de **VMware Workstation**, `ovftool.exe` et `vnetlib.exe`.
    * Détecte le dossier de destination des VMs configuré dans vos préférences VMware (ou utilise `~/Vms/LabVms` par défaut).

3.  **Déploiement et Inventaire :**
    * Importe les VMs via `ovftool` (conversion OVF vers VMX).
    * **Enregistrement direct :** Ajoute les machines importées directement dans l'interface graphique de VMware (fichier `inventory.vmls`), les rendant immédiatement visibles sans redémarrage.

## 📦 Machines Déployées

Le script s'assure de la présence et du déploiement des machines suivantes :

| Machine Virtuelle | Type de fichier |
| :--- | :--- |
| **TLS-DC-01** | `.ovf` |
| **SRV-WEB-01** | `.ovf` |
| **SRV-WINDOWS-01** | `.ovf` |
| **SRV-WINDOWS-02** | `.ovf` |
| **GRB-DC-01** | `.ovf` |

## ⚙️ Prérequis

* **Connexion Internet** (pour le téléchargement initial des OVFs).
* **VMware Workstation Pro** installé.
* **PowerShell 5.1** ou supérieur.
* Espace disque suffisant pour télécharger et extraire les VMs.

## 🚀 Utilisation

1.  Placez le script `deploy_vmware.ps1` dans un dossier vide dédié (le script y téléchargera les fichiers ZIP et extraira les VMs).
2.  Ouvrez PowerShell.
3.  Exécutez la commande suivante :

```powershell
# Autoriser l'exécution de scripts
Set-ExecutionPolicy Unrestricted -Scope Process -Force

# Lancer le script
.\deploy_vmware.ps1
```

**Note :** Le premier lancement peut être long car il inclut le téléchargement de l'archive ZIP. Les exécutions suivantes détecteront les fichiers locaux et passeront directement au déploiement si nécessaire.

## ⚠️ Dépannage

* Erreur de téléchargement : Vérifiez votre connexion internet et l'accessibilité de l'URL fyc2026.duckdns.org.

* Outils manquants : Si le script indique [ERREUR CRITIQUE] Outils manquants, assurez-vous que VMware Workstation est installé dans les répertoires par défaut (C:\Program Files...).

* Doublons : Si une VM existe déjà dans le dossier de destination, le script affichera [SKIP] et ne l'écrasera pas. Supprimez le dossier de la VM sur le disque si vous souhaitez forcer un redéploiement.

* Certaines versions de vmware peuvent provoquer des erreurs de type écran bleu, plusieurs redémarrages peuvent être nécessaires.

__________________________________________________________________________________________________________________________________________


# L'équipe CUSTODES
