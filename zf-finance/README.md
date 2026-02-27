# ZF Finance v3 — Guide de déploiement complet

## Structure du projet

```
zf-finance/
├── index.html          ← Application complète (single-file)
├── netlify.toml        ← Config Netlify
├── README.md           ← Ce fichier
└── supabase/
    └── schema.sql      ← Schema Supabase complet
```

---

## ÉTAPE 1 — Supabase (base de données)

### 1.1 Créer le projet

1. Aller sur **[supabase.com](https://supabase.com)** → Se connecter
2. Cliquer **"New project"**
3. Remplir :
   - **Name** : `zf-finance-prod`
   - **Database password** : générer un mot de passe fort → **le noter dans un gestionnaire de mots de passe**
   - **Region** : `West EU (Ireland)` — le plus proche pour DZ/FR
4. Attendre ~2 minutes que le projet soit prêt

### 1.2 Exécuter le schema SQL

1. Dans le dashboard Supabase → **SQL Editor** (icône `</>` dans la sidebar)
2. Cliquer **"+ New query"**
3. Copier-coller **tout le contenu** de `supabase/schema.sql`
4. Cliquer **"Run"** (ou `Ctrl+Enter`)
5. Vérifier qu'il n'y a pas d'erreurs rouges (les warnings sont ok)
6. La dernière requête affiche la liste des tables créées — vérifier qu'il y en a 14

### 1.3 Récupérer les clés API

1. Dans Supabase → **Settings** (roue dentée) → **API**
2. Copier :
   - **Project URL** : `https://XXXXXXXX.supabase.co`
   - **anon public** key : `eyJhbGci...` (longue chaîne)
3. ⚠️ NE PAS utiliser la `service_role` key dans l'app front-end — seulement `anon`

### 1.4 Configurer l'authentification

1. Supabase → **Authentication** → **Settings**
2. **Site URL** : mettre ton URL Netlify/Cloudflare (ex: `https://zf-finance.netlify.app`)
3. **Redirect URLs** : ajouter aussi `http://localhost:3000` pour le dev local
4. Optionnel : activer **Email confirmations** → désactiver pour les tests

### 1.5 Mettre à jour l'app avec les nouvelles clés

Dans `index.html`, trouver et remplacer les 2 lignes du `createClient` :

```javascript
const sb = window.supabase.createClient(
  'https://TON_NOUVEAU_PROJET.supabase.co',  // ← remplacer
  'eyJhbGci...TON_ANON_KEY...'               // ← remplacer
);
```

---

## ÉTAPE 2 — GitHub

### 2.1 Créer le repository

1. Aller sur **[github.com](https://github.com)** → **New repository**
2. Nom : `zf-finance`
3. Visibilité : **Private** (recommandé — contient les clés Supabase)
4. Ne pas initialiser avec README (tu vas pusher le tien)
5. Cliquer **"Create repository"**

### 2.2 Pusher le code

```bash
# Dans le dossier zf-finance/ sur ton ordi
git init
git add .
git commit -m "ZF Finance v3 — Initial deploy"
git branch -M main
git remote add origin https://github.com/TON_USERNAME/zf-finance.git
git push -u origin main
```

### 2.3 Workflow quotidien

```bash
# Modifier index.html → sauvegarder → puis :
git add index.html
git commit -m "Fix: description du changement"
git push
# → Netlify/Cloudflare redéploie automatiquement en ~30 secondes
```

---

## ÉTAPE 3A — Déploiement Netlify (recommandé pour débuter)

### 3A.1 Connecter GitHub

1. Aller sur **[netlify.com](https://netlify.com)** → Log in
2. **"Add new site"** → **"Import an existing project"**
3. **"Deploy with GitHub"** → Autoriser Netlify
4. Choisir le repo `zf-finance`

### 3A.2 Paramètres de build

| Champ | Valeur |
|-------|--------|
| Branch | `main` |
| Base directory | *(laisser vide)* |
| Build command | *(laisser vide)* |
| Publish directory | `.` |

5. Cliquer **"Deploy site"**

### 3A.3 Domaine personnalisé (optionnel)

1. **Site settings** → **Domain management** → **Add custom domain**
2. Ex: `finance.zouichefinance.com`
3. Suivre les instructions DNS (ajouter un CNAME chez ton registrar)

### 3A.4 URL de l'app

Netlify génère une URL du style : `https://wonderful-name-12345.netlify.app`
Tu peux la renommer dans : **Site settings** → **Site details** → **Change site name**
→ Ex: `zf-finance.netlify.app`

---

## ÉTAPE 3B — Déploiement Cloudflare Pages (alternative)

### 3B.1 Connecter GitHub

1. Aller sur **[pages.cloudflare.com](https://pages.cloudflare.com)** → Dashboard
2. **Workers & Pages** → **"Create application"** → **"Pages"** → **"Connect to Git"**
3. Autoriser Cloudflare → Choisir `zf-finance`

### 3B.2 Paramètres de build

| Champ | Valeur |
|-------|--------|
| Framework preset | `None` |
| Build command | *(laisser vide)* |
| Build output directory | `/` |

### 3B.3 Déployer

1. Cliquer **"Save and Deploy"**
2. URL générée : `https://zf-finance.pages.dev`
3. Domaine perso : **Custom domains** → Ajouter ton domaine (si hébergé chez Cloudflare c'est automatique)

---

## COMPARAISON Netlify vs Cloudflare Pages

| | Netlify | Cloudflare Pages |
|---|---|---|
| Free tier | 100GB/mois, 300 min build | Unlimited bandwidth |
| Vitesse | Bien | Excellent (CDN Cloudflare mondial) |
| Setup | ⭐⭐⭐ Très simple | ⭐⭐ Simple |
| Preview URLs | ✅ PR previews | ✅ PR previews |
| Analytics | Payant | Gratuit basique |
| **Recommandation** | Pour démarrer vite | Pour la prod longue durée |

**Conseil** : Commence sur Netlify, migre sur Cloudflare quand tu veux optimiser les perf.

---

## ÉTAPE 4 — Mettre à jour l'URL Supabase

Une fois ton URL de déploiement connue, retourner dans Supabase :

1. **Authentication** → **Settings** → **Site URL**
2. Mettre l'URL exacte de ton app : `https://zf-finance.netlify.app`
3. Ajouter aussi dans **Redirect URLs** pour que le login magic link fonctionne

---

## ÉTAPE 5 — Premier login et migration des données

### 5.1 Créer le premier compte (CFO)

1. Ouvrir ton URL déployée
2. Cliquer **"Créer mon espace"**
3. Remplir : nom de l'entreprise, pays, secteur
4. Étape 2 : ton nom, email, mot de passe
5. → Workspace créé automatiquement, compte CFO configuré

### 5.2 Migrer les données existantes (si tu as un ancien Supabase)

Si tu as des données sur l'ancien projet (`kspncjixslphxkfooyjj.supabase.co`) :

```sql
-- À exécuter dans l'ANCIEN Supabase pour exporter
-- Puis importer dans le nouveau via CSV ou script

-- Option simple : dans Supabase Dashboard → Table Editor → chaque table → "Export CSV"
-- Puis dans le nouveau : Table Editor → Import CSV
-- ⚠️ Respecter l'ordre : workspaces → profiles → equipes → categories → fournisseurs → factures → ndf
```

---

## Développement local (sans serveur)

Tu n'as pas besoin d'un serveur local — `index.html` fonctionne directement dans le navigateur :

```bash
# Option 1 : double-clic sur index.html
# Option 2 : Python simple server (recommandé pour éviter les erreurs CORS)
cd zf-finance
python3 -m http.server 3000
# → Ouvrir http://localhost:3000
```

---

## Sécurité

| Élément | Status | Note |
|---------|--------|------|
| Clé `anon` Supabase dans le HTML | ✅ OK | C'est la clé publique — normal |
| Clé `service_role` | ❌ JAMAIS | Ne jamais mettre dans le front |
| RLS activé sur toutes les tables | ✅ | Fait dans schema.sql |
| Repo GitHub Private | ✅ Recommandé | Évite l'exposition des clés |
| HTTPS | ✅ Automatique | Netlify/Cloudflare gèrent le SSL |

---

## Checklist de déploiement

- [ ] Nouveau projet Supabase créé
- [ ] `schema.sql` exécuté sans erreurs
- [ ] Clés API récupérées
- [ ] `index.html` mis à jour avec les nouvelles clés
- [ ] Repo GitHub créé et code pushé
- [ ] Site Netlify ou Cloudflare connecté au repo
- [ ] URL dans Supabase → Authentication → Site URL
- [ ] Premier login testé → workspace créé
- [ ] Invitation d'un autre membre testée

---

## En cas de problème

**Login bloqué sur "Connexion..."**
→ Ouvrir la console navigateur (F12) → vérifier les erreurs
→ Souvent : mauvaise URL Supabase ou RLS trop restrictif

**"Erreur : JSON object requested, multiple rows returned"**
→ La RLS retourne trop de lignes → vérifier que `get_user_workspace_id()` est bien définie

**Les données ne s'affichent pas après connexion**
→ Vérifier que `workspace_id` est bien rempli sur les données
→ SQL Editor : `SELECT id, workspace_id FROM profiles WHERE id = 'TON_USER_ID';`

**Notification d'erreur sur les budgets**
→ La table `budgets` dans `loadAll()` peut provoquer une erreur si vide — normal au démarrage

---

*ZF Finance v3 — ZOUICHE Finance © 2026*
