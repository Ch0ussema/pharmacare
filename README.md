# PharmaCare

Application web de gestion pour une pharmacie indépendante en Tunisie : caisse (POS),
catalogue produits, suivi du stock et tableau de bord. L'interface est en **français**,
la monnaie est le **dinar tunisien (TND, 3 décimales)** et les dates sont affichées dans
le fuseau **Africa/Tunis**.

## Stack

- [Next.js 16](https://nextjs.org) (App Router, Turbopack) et React 19
- Tailwind CSS v4 + [shadcn/ui](https://ui.shadcn.com) (primitives Radix)
- Supabase Postgres (accès serveur uniquement, via la clé secrète)
- TypeScript strict, ESLint

## Prérequis

- **Node.js 22 ou supérieur**
- npm 10 ou supérieur

## Installation

```bash
npm install
cp .env.example .env.local
```

Renseignez ensuite les variables Supabase dans `.env.local` (facultatif en Phase 0 :
aucune requête base de données n'est encore effectuée).

```bash
SUPABASE_URL=https://votre-projet.supabase.co
SUPABASE_SECRET_KEY=votre-cle-secrete
```

> La clé secrète contourne Row Level Security. Elle ne doit jamais être préfixée par
> `NEXT_PUBLIC_` ni importée dans un composant client. Voir `src/lib/supabase/admin.ts`.

## Commandes

```bash
npm run dev     # serveur de développement (http://localhost:3000)
npm run build   # build de production
npm run start   # serveur de production (après build)
npm run lint    # ESLint
npx tsc --noEmit  # vérification TypeScript
```

## Organisation

```
src/
  app/
    (app)/            # shell applicatif : tableau de bord, caisse, produits, paramètres
    layout.tsx        # layout racine (lang fr, polices, Toaster)
    globals.css       # Tailwind v4 + thème shadcn PharmaCare
    not-found.tsx     # 404 en français
  components/
    layout/           # sidebar, topbar, en-têtes de page, états vides
    ui/               # composants shadcn/ui
  lib/
    i18n/             # dictionnaire français typé (source unique des textes)
    format.ts         # formatage TND / dates (millimes, Africa/Tunis)
    auth.ts           # point d'extension pour l'authentification (mode démo)
    supabase/admin.ts # client admin côté serveur (lecture paresseuse des variables)
```

## Conventions

- **Argent** : entiers en millimes (`1 DT = 1000`). Utilisez `formatTND` et
  `parseTNDInput` de `src/lib/format.ts`, jamais de calcul flottant.
- **Dates** : stockage UTC, affichage `Africa/Tunis` via `formatDate`,
  `formatDateTime` et `formatTime`.
- **Textes** : tout le contenu visible provient de `src/lib/i18n/fr.ts`.
- **Composants** : Server Components par défaut ; `"use client"` uniquement lorsque
  l'interaction l'exige.

## Documentation

- [`docs/prd/00-overview.md`](docs/prd/00-overview.md) — vision produit, modèle de données,
  décisions d'architecture.
- [`docs/prd/01-phase-0-foundation.md`](docs/prd/01-phase-0-foundation.md) — périmètre de la
  phase 0 (fondations, shell, design system).
- [`AGENTS.md`](AGENTS.md) — consignes pour les agents et spécificités de cette version de
  Next.js.
