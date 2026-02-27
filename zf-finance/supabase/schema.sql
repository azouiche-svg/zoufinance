-- ═══════════════════════════════════════════════════════════════
-- ZF Finance v3 — Supabase Schema complet (à zéro)
-- Exécuter en une seule fois dans : Supabase → SQL Editor → New query
-- ═══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────
-- 0. EXTENSIONS
-- ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ──────────────────────────────────────────────
-- 1. WORKSPACES — un espace = une entreprise
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workspaces (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  nom         text        NOT NULL,
  slug        text        UNIQUE,
  secteur     text        DEFAULT '',
  pays        text        DEFAULT 'DZ',
  created_by  uuid,                          -- user_id du CFO fondateur
  plan        text        DEFAULT 'free',    -- 'free' | 'pro' (pour usage futur)
  created_at  timestamptz DEFAULT now()
);


-- ──────────────────────────────────────────────
-- 2. PROFILES — utilisateurs (étend auth.users)
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  id           uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nom          text        NOT NULL DEFAULT '',
  email        text        NOT NULL DEFAULT '',
  role         text        NOT NULL DEFAULT 'employe'
                           CHECK (role IN ('cfo','manager','compta','employe','admin')),
  equipe_id    uuid,                          -- FK vers equipes (nullable)
  workspace_id uuid        REFERENCES workspaces(id) ON DELETE SET NULL,
  created_at   timestamptz DEFAULT now()
);


-- ──────────────────────────────────────────────
-- 3. WORKSPACE INVITATIONS
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workspace_invitations (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid        NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  email         text        NOT NULL,
  role          text        NOT NULL DEFAULT 'employe'
                            CHECK (role IN ('cfo','manager','compta','employe')),
  invited_by    uuid        REFERENCES profiles(id) ON DELETE SET NULL,
  token         text        UNIQUE NOT NULL,
  accepted_at   timestamptz,
  created_at    timestamptz DEFAULT now()
);


-- ──────────────────────────────────────────────
-- 4. EQUIPES
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS equipes (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  nom          text        NOT NULL,
  color        text        DEFAULT '#6366f1',
  manager_id   uuid        REFERENCES profiles(id) ON DELETE SET NULL,
  workspace_id uuid        NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  created_at   timestamptz DEFAULT now()
);

-- FK équipe sur profiles (après création)
ALTER TABLE profiles
  ADD CONSTRAINT fk_profiles_equipe
  FOREIGN KEY (equipe_id) REFERENCES equipes(id) ON DELETE SET NULL;


-- ──────────────────────────────────────────────
-- 5. CATEGORIES
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS categories (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  nom          text        NOT NULL,
  color        text        DEFAULT '#6366f1',
  workspace_id uuid        NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  created_at   timestamptz DEFAULT now()
);


-- ──────────────────────────────────────────────
-- 6. AXES ANALYTIQUES
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS axes_analytiques (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  code         text        NOT NULL,
  libelle      text        NOT NULL DEFAULT '',
  workspace_id uuid        NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  created_at   timestamptz DEFAULT now()
);


-- ──────────────────────────────────────────────
-- 7. COMPTES BANCAIRES
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS comptes_bancaires (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  libelle      text        NOT NULL,
  banque       text        DEFAULT '',
  numero       text        DEFAULT '',
  devise       text        DEFAULT 'DZD',
  workspace_id uuid        NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  created_at   timestamptz DEFAULT now()
);


-- ──────────────────────────────────────────────
-- 8. PLAN COMPTABLE (SCF Algérien)
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS plan_comptable (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  numero       text        NOT NULL,
  libelle      text        NOT NULL DEFAULT '',
  classe       text        GENERATED ALWAYS AS (substring(numero, 1, 1)) STORED,
  workspace_id uuid        NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  created_at   timestamptz DEFAULT now(),
  UNIQUE (workspace_id, numero)
);


-- ──────────────────────────────────────────────
-- 9. FOURNISSEURS
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS fournisseurs (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  nom          text        NOT NULL,
  email        text        DEFAULT '',
  tel          text        DEFAULT '',
  adresse      text        DEFAULT '',
  notes        text        DEFAULT '',
  created_by   uuid        REFERENCES profiles(id) ON DELETE SET NULL,
  workspace_id uuid        NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  created_at   timestamptz DEFAULT now()
);


-- ──────────────────────────────────────────────
-- 10. FACTURES FOURNISSEURS
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS factures (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Identité
  ref                text        NOT NULL,
  fournisseur_id     uuid        REFERENCES fournisseurs(id) ON DELETE SET NULL,
  -- Montants
  ht                 numeric     DEFAULT 0,
  tva                numeric     DEFAULT 0,
  ttc                numeric     DEFAULT 0,
  -- Dates
  date_facture       date,
  echeance           date,
  -- Workflow
  status             text        NOT NULL DEFAULT 'pending'
                     CHECK (status IN (
                       'pending','mgr_validated','cfo_validated','validated',
                       'topay','partial','paid','rejected','archived'
                     )),
  created_by         uuid        REFERENCES profiles(id) ON DELETE SET NULL,
  equipe_id          uuid        REFERENCES equipes(id) ON DELETE SET NULL,
  manager_id         uuid        REFERENCES profiles(id) ON DELETE SET NULL,
  -- Classification
  categorie_id       uuid        REFERENCES categories(id) ON DELETE SET NULL,
  axe_analytique_id  uuid        REFERENCES axes_analytiques(id) ON DELETE SET NULL,
  periode            text,                              -- ex: '2026-02'
  justif             text        DEFAULT 'non',
  budget_flag        text        CHECK (budget_flag IN (NULL,'opex','capex','hors_budget','exceptionnel')),
  -- Comptabilité
  plan_comptable     text,                              -- n° de compte SCF
  compte_debit       text,
  compte_credit      text,
  libelle_ecriture   text,
  tva_deductible     numeric     DEFAULT 0,
  banque_debit       text,
  lettree            boolean     DEFAULT false,
  date_lettrage      date,
  -- Paiement
  paid_amount        numeric     DEFAULT 0,
  payment_date       date,
  payment_ref        text,
  payment_banque_id  uuid        REFERENCES comptes_bancaires(id) ON DELETE SET NULL,
  payment_mode       text,
  payment_proof_url  text,
  date_paiement_prev date,
  -- Pièce jointe
  attachment_url     text,
  attachment_name    text,
  -- Divers
  notes              text,
  history            jsonb       DEFAULT '[]',
  archived_at        timestamptz,
  workspace_id       uuid        NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  created_at         timestamptz DEFAULT now()
);


-- ──────────────────────────────────────────────
-- 11. NOTES DE FRAIS
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notes_frais (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Identité
  titre              text        NOT NULL DEFAULT '',
  date               date,
  total              numeric     DEFAULT 0,
  lignes             jsonb       DEFAULT '[]',        -- détail des lignes NDF
  -- Workflow
  status             text        NOT NULL DEFAULT 'pending'
                     CHECK (status IN (
                       'pending','mgr_ok','cfo_ok','paid','rejected','archived'
                     )),
  employe_id         uuid        REFERENCES profiles(id) ON DELETE SET NULL,
  equipe_id          uuid        REFERENCES equipes(id) ON DELETE SET NULL,
  manager_id         uuid        REFERENCES profiles(id) ON DELETE SET NULL,
  created_by         uuid        REFERENCES profiles(id) ON DELETE SET NULL,
  -- Classification
  categorie_id       uuid        REFERENCES categories(id) ON DELETE SET NULL,
  fournisseur_id     uuid        REFERENCES fournisseurs(id) ON DELETE SET NULL,
  periode            text,
  justif             text        DEFAULT 'non',
  budget_flag        text        CHECK (budget_flag IN (NULL,'opex','capex','hors_budget','exceptionnel')),
  -- Comptabilité
  compte_debit       text,
  compte_credit      text,
  libelle_ecriture   text,
  -- Paiement
  payment_date       date,
  payment_ref        text,
  payment_banque_id  uuid        REFERENCES comptes_bancaires(id) ON DELETE SET NULL,
  date_paiement_prev date,
  -- Pièce jointe
  attachment_url     text,
  attachment_name    text,
  -- Divers
  notes              text,
  history            jsonb       DEFAULT '[]',
  archived_at        timestamptz,
  workspace_id       uuid        NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  created_at         timestamptz DEFAULT now()
);


-- ──────────────────────────────────────────────
-- 12. JOURNAL DES ACHATS (écritures libres)
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ecritures_libres (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  date            date        NOT NULL,
  piece           text        DEFAULT '',
  libelle         text        NOT NULL DEFAULT '',
  montant         numeric     DEFAULT 0,
  compte_debit    text,
  compte_credit   text,
  fournisseur_id  uuid        REFERENCES fournisseurs(id) ON DELETE SET NULL,
  banque_id       uuid        REFERENCES comptes_bancaires(id) ON DELETE SET NULL,
  type_ecriture   text        DEFAULT 'paiement',
  notes           text,
  created_by      uuid        REFERENCES profiles(id) ON DELETE SET NULL,
  workspace_id    uuid        NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  created_at      timestamptz DEFAULT now()
);


-- ──────────────────────────────────────────────
-- 13. NOTIFICATIONS
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  titre       text        NOT NULL DEFAULT '',
  sub         text        DEFAULT '',
  ref_id      uuid,
  ref_type    text        DEFAULT 'facture',
  read        boolean     DEFAULT false,
  is_read     boolean     DEFAULT false,
  workspace_id uuid       REFERENCES workspaces(id) ON DELETE CASCADE,
  created_at  timestamptz DEFAULT now()
);


-- ──────────────────────────────────────────────
-- 14. SETTINGS (clé/valeur par workspace)
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS settings (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  key          text        NOT NULL,
  value        jsonb,
  workspace_id uuid        REFERENCES workspaces(id) ON DELETE CASCADE,
  created_at   timestamptz DEFAULT now(),
  UNIQUE (workspace_id, key)
);

-- Note : les budgets sont stockés dans settings
-- clé = 'budgets_2026', valeur = { equipe_id: { 1: 500000, 2: 480000, ... } }


-- ══════════════════════════════════════════════
-- INDEX — performance
-- ══════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_factures_workspace    ON factures(workspace_id);
CREATE INDEX IF NOT EXISTS idx_factures_status       ON factures(status);
CREATE INDEX IF NOT EXISTS idx_factures_date         ON factures(date_facture);
CREATE INDEX IF NOT EXISTS idx_factures_equipe       ON factures(equipe_id);
CREATE INDEX IF NOT EXISTS idx_ndf_workspace         ON notes_frais(workspace_id);
CREATE INDEX IF NOT EXISTS idx_ndf_status            ON notes_frais(status);
CREATE INDEX IF NOT EXISTS idx_ndf_employe           ON notes_frais(employe_id);
CREATE INDEX IF NOT EXISTS idx_profiles_workspace    ON profiles(workspace_id);
CREATE INDEX IF NOT EXISTS idx_notifs_user           ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifs_workspace      ON notifications(workspace_id);
CREATE INDEX IF NOT EXISTS idx_fournisseurs_ws       ON fournisseurs(workspace_id);
CREATE INDEX IF NOT EXISTS idx_ecritures_workspace   ON ecritures_libres(workspace_id);
CREATE INDEX IF NOT EXISTS idx_ecritures_date        ON ecritures_libres(date);


-- ══════════════════════════════════════════════
-- ROW LEVEL SECURITY (RLS)
-- Chaque utilisateur ne voit que son workspace
-- ══════════════════════════════════════════════

-- Helper function : récupérer le workspace_id de l'utilisateur connecté
CREATE OR REPLACE FUNCTION get_user_workspace_id()
RETURNS uuid AS $$
  SELECT workspace_id FROM profiles WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Helper function : vérifier si l'utilisateur est CFO de son workspace
CREATE OR REPLACE FUNCTION is_workspace_cfo()
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role IN ('cfo', 'admin')
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;


-- WORKSPACES
ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ws_select" ON workspaces FOR SELECT USING (
  id = get_user_workspace_id()
);
CREATE POLICY "ws_update" ON workspaces FOR UPDATE USING (
  id = get_user_workspace_id() AND is_workspace_cfo()
);
CREATE POLICY "ws_insert" ON workspaces FOR INSERT WITH CHECK (true);
-- Note: insert ouvert car nécessaire au signup


-- PROFILES
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles_select" ON profiles FOR SELECT USING (
  workspace_id = get_user_workspace_id()
  OR id = auth.uid()
);
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (
  id = auth.uid() OR (workspace_id = get_user_workspace_id() AND is_workspace_cfo())
);


-- WORKSPACE INVITATIONS
ALTER TABLE workspace_invitations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "inv_select" ON workspace_invitations FOR SELECT USING (
  workspace_id = get_user_workspace_id()
  OR token IS NOT NULL  -- lecture par token pour le flow d'invitation
);
CREATE POLICY "inv_insert" ON workspace_invitations FOR INSERT WITH CHECK (
  workspace_id = get_user_workspace_id() AND is_workspace_cfo()
);
CREATE POLICY "inv_update" ON workspace_invitations FOR UPDATE USING (true);
CREATE POLICY "inv_delete" ON workspace_invitations FOR DELETE USING (
  workspace_id = get_user_workspace_id() AND is_workspace_cfo()
);


-- Macro pour les tables métier (toutes isolées par workspace)
-- (répété pour chaque table pour éviter les dynamic SQL)

-- EQUIPES
ALTER TABLE equipes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "equipes_all" ON equipes FOR ALL USING (workspace_id = get_user_workspace_id());

-- CATEGORIES
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "categories_all" ON categories FOR ALL USING (workspace_id = get_user_workspace_id());

-- AXES ANALYTIQUES
ALTER TABLE axes_analytiques ENABLE ROW LEVEL SECURITY;
CREATE POLICY "axes_all" ON axes_analytiques FOR ALL USING (workspace_id = get_user_workspace_id());

-- COMPTES BANCAIRES
ALTER TABLE comptes_bancaires ENABLE ROW LEVEL SECURITY;
CREATE POLICY "banques_all" ON comptes_bancaires FOR ALL USING (workspace_id = get_user_workspace_id());

-- PLAN COMPTABLE
ALTER TABLE plan_comptable ENABLE ROW LEVEL SECURITY;
CREATE POLICY "plan_all" ON plan_comptable FOR ALL USING (workspace_id = get_user_workspace_id());

-- FOURNISSEURS
ALTER TABLE fournisseurs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "fournisseurs_all" ON fournisseurs FOR ALL USING (workspace_id = get_user_workspace_id());

-- FACTURES
ALTER TABLE factures ENABLE ROW LEVEL SECURITY;
CREATE POLICY "factures_all" ON factures FOR ALL USING (workspace_id = get_user_workspace_id());

-- NOTES DE FRAIS
ALTER TABLE notes_frais ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ndf_all" ON notes_frais FOR ALL USING (workspace_id = get_user_workspace_id());

-- ECRITURES LIBRES
ALTER TABLE ecritures_libres ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ecritures_all" ON ecritures_libres FOR ALL USING (workspace_id = get_user_workspace_id());

-- NOTIFICATIONS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "notifs_select" ON notifications FOR SELECT USING (
  user_id = auth.uid() OR workspace_id = get_user_workspace_id()
);
CREATE POLICY "notifs_insert" ON notifications FOR INSERT WITH CHECK (
  workspace_id = get_user_workspace_id()
);
CREATE POLICY "notifs_update" ON notifications FOR UPDATE USING (
  user_id = auth.uid()
);

-- SETTINGS
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "settings_all" ON settings FOR ALL USING (workspace_id = get_user_workspace_id());


-- ══════════════════════════════════════════════
-- REALTIME — activer pour les notifications live
-- ══════════════════════════════════════════════
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;


-- ══════════════════════════════════════════════
-- STORAGE — bucket pour les pièces jointes
-- ══════════════════════════════════════════════
-- À faire manuellement dans Supabase Dashboard :
-- Storage → New bucket → "factures" → Public: NON
-- Puis ajouter les policies :
--   SELECT : authenticated users can read leur workspace
--   INSERT : authenticated users can upload
--
-- Ou via SQL :
INSERT INTO storage.buckets (id, name, public)
VALUES ('factures', 'factures', false)
ON CONFLICT DO NOTHING;

CREATE POLICY "storage_read" ON storage.objects FOR SELECT USING (
  bucket_id = 'factures' AND auth.role() = 'authenticated'
);
CREATE POLICY "storage_insert" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'factures' AND auth.role() = 'authenticated'
);
CREATE POLICY "storage_delete" ON storage.objects FOR DELETE USING (
  bucket_id = 'factures' AND auth.role() = 'authenticated'
);


-- ══════════════════════════════════════════════
-- DONNÉES PAR DÉFAUT (facultatif — pour test)
-- ══════════════════════════════════════════════
-- Ces données sont créées automatiquement par l'app lors du signup.
-- Si tu veux pré-remplir manuellement un workspace de test :
--
-- 1. Créer un compte via l'app → récupérer le workspace_id dans la table workspaces
-- 2. Remplacer 'WORKSPACE_ID_ICI' ci-dessous et décommenter

/*
DO $$
DECLARE ws_id uuid := 'WORKSPACE_ID_ICI';
BEGIN
  -- Catégories par défaut
  INSERT INTO categories (nom, color, workspace_id) VALUES
    ('Achats & Fournitures',       '#3b82f6', ws_id),
    ('Frais de déplacement',       '#10b981', ws_id),
    ('Loyers & Charges',           '#f59e0b', ws_id),
    ('COGS - Production',          '#1a2766', ws_id),
    ('Services & Sous-traitance',  '#8b5cf6', ws_id),
    ('Marketing & Com.',           '#be1e2d', ws_id)
  ON CONFLICT DO NOTHING;

  -- Équipes par défaut
  INSERT INTO equipes (nom, color, workspace_id) VALUES
    ('Direction',   '#1a2766', ws_id),
    ('Finance/RH',  '#0d9488', ws_id),
    ('Opérations',  '#2563eb', ws_id),
    ('Commercial',  '#be1e2d', ws_id)
  ON CONFLICT DO NOTHING;

  -- Compte bancaire exemple
  INSERT INTO comptes_bancaires (libelle, banque, devise, workspace_id) VALUES
    ('Compte Principal', 'CPA', 'DZD', ws_id)
  ON CONFLICT DO NOTHING;
END $$;
*/


-- ══════════════════════════════════════════════
-- VÉRIFICATION FINALE
-- ══════════════════════════════════════════════
-- Après exécution, vérifier que toutes les tables existent :
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- Doit afficher : axes_analytiques, categories, comptes_bancaires, ecritures_libres,
-- equipes, factures, fournisseurs, notes_frais, notifications, plan_comptable,
-- profiles, settings, workspace_invitations, workspaces
