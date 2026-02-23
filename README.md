# ducratif_ct — Contrôle Technique & Carte Grise RP

Ressource ESX Legacy compatible **ox_lib + ox_inventory**.

## Features
- CT **7 / 14 / 30 jours** (durées/prix configurables)
- Mode **NPC** (public) ou **Métier CT**
- Item **ct_paper** (metadata) pour montrer le CT
- Item **ct_scanner** police (portée 200m configurable)
- Commande police **/ctcontrol** (menu complet + amende auto)
- Amende auto basée sur **classe véhicule + jours de retard**
- Logs complets: CT + actions police + amendes offline

## Installation
1) Importer `sql/install.sql`
2) Ajouter les items dans `ox_inventory/data/items.lua` (voir `docs/index.html`)
3) Mettre le dossier `ducratif_ct` dans tes resources
4) Configurer `config.lua`
5) `ensure ducratif_ct`

## Docs
[`ducratif_ct/docs/`](https://ducratif.github.io/controle_technique_fivem/)
