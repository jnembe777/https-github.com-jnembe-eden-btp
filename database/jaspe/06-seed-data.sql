-- ============================================================================
-- EDENFIN JASPE — SCRIPT 06 : DONNÉES DE RÉFÉRENCE ET PARAMÉTRAGE
-- À exécuter APRÈS le script 05
-- Sources consolidées : 04_seed_ohada.sql + 09_seed_parameter_data.sql
-- ============================================================================
-- Contenu :
--   A. Plan comptable OHADA/SYSCOHADA révisé 2017 (classes 1-9)
--   B. Rubriques de paie (30 rubriques)
--   C. Barèmes cotisations CNSS/CRF/CNAMGS Gabon 2025
--   D. Types d'absences
--   E. Catégories d'immobilisations OHADA
--   F. Périodes de paie 2026
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- A. PLAN COMPTABLE OHADA/SYSCOHADA révisé 2017
-- Chargé en 2 temps : common.chart_of_accounts_details → client_demo.chart_of_accounts
-- ────────────────────────────────────────────────────────────────────────────

CREATE TEMP TABLE _ohada_accounts (
  account_number    VARCHAR(10)  NOT NULL,
  account_name      VARCHAR(255) NOT NULL,
  account_type      VARCHAR(50)  NOT NULL,
  account_level     INTEGER      NOT NULL,
  is_detail         BOOLEAN      DEFAULT FALSE,
  normal_balance    VARCHAR(10)  NOT NULL,
  financial_statement VARCHAR(50)
);

-- ── CLASSE 1 : RESSOURCES DURABLES ──
INSERT INTO _ohada_accounts (account_number, account_name, account_type, account_level, normal_balance, financial_statement) VALUES
  ('1', 'COMPTES DE RESSOURCES DURABLES', 'LIABILITY', 1, 'CREDIT', 'BALANCE_SHEET');

INSERT INTO _ohada_accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
  ('10', 'CAPITAL', 'EQUITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('101', 'Capital social', 'EQUITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('1011', 'Capital souscrit, non appelé', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('1012', 'Capital souscrit, appelé, non versé', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('1013', 'Capital souscrit, appelé, versé, non amorti', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('102', 'Capital par dotation', 'EQUITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('1021', 'Dotation initiale', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('103', 'Capital personnel', 'EQUITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('104', 'Compte de l''exploitant', 'EQUITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('105', 'Primes liées au capital social', 'EQUITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('1051', 'Primes d''émission', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('1052', 'Primes d''apport', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('1053', 'Primes de fusion', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('109', 'Actionnaires, capital souscrit, non appelé', 'EQUITY', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('11', 'RÉSERVES', 'EQUITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('111', 'Réserve légale', 'EQUITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('112', 'Réserves statutaires ou contractuelles', 'EQUITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('118', 'Autres réserves', 'EQUITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('12', 'REPORT À NOUVEAU', 'EQUITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('121', 'Report à nouveau créditeur', 'EQUITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('129', 'Report à nouveau débiteur', 'EQUITY', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('13', 'RÉSULTAT NET DE L''EXERCICE', 'EQUITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('131', 'Résultat net : bénéfice', 'EQUITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('139', 'Résultat net : perte', 'EQUITY', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('14', 'SUBVENTIONS D''INVESTISSEMENT', 'EQUITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('141', 'Subventions d''équipement', 'EQUITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('15', 'PROVISIONS RÉGLEMENTÉES ET FONDS ASSIMILÉS', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('151', 'Amortissements dérogatoires', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('152', 'Plus-values de cession à réinvestir', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('16', 'EMPRUNTS ET DETTES ASSIMILÉES', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('161', 'Emprunts obligataires', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('162', 'Emprunts et dettes auprès des établissements de crédit', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('163', 'Avances reçues de l''État', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('164', 'Avances reçues et comptes courants bloqués', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('165', 'Dépôts et cautionnements reçus', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('166', 'Intérêts courus', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('17', 'DETTES DE CRÉDIT-BAIL ET CONTRATS ASSIMILÉS', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('171', 'Emprunts équivalents de crédit-bail immobilier', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('172', 'Emprunts équivalents de crédit-bail mobilier', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('18', 'DETTES LIÉES À DES PARTICIPATIONS', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('181', 'Dettes liées à des participations (groupe)', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('182', 'Dettes liées à des participations (hors groupe)', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('19', 'PROVISIONS FINANCIÈRES POUR RISQUES ET CHARGES', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('191', 'Provisions pour litiges', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('192', 'Provisions pour garanties données aux clients', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('193', 'Provisions pour pertes sur marchés à achèvement futur', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('194', 'Provisions pour pertes de change', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('195', 'Provisions pour impôts', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('196', 'Provisions pour pensions et obligations similaires', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('197', 'Provisions pour charges à répartir', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('198', 'Autres provisions financières pour risques et charges', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- ── CLASSE 2 : ACTIF IMMOBILISÉ ──
INSERT INTO _ohada_accounts VALUES
  ('2', 'COMPTES D''ACTIF IMMOBILISÉ', 'ASSET', 1, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('20', 'CHARGES IMMOBILISÉES', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('201', 'Frais d''établissement', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('202', 'Charges à répartir sur plusieurs exercices', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('206', 'Primes de remboursement des obligations', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('21', 'IMMOBILISATIONS INCORPORELLES', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('211', 'Frais de recherche et de développement', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('212', 'Brevets, licences, concessions', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('213', 'Logiciels', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('214', 'Marques', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('215', 'Fonds commercial', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('216', 'Droit au bail', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('217', 'Investissements de création', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('218', 'Autres droits et valeurs incorporels', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('22', 'TERRAINS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('221', 'Terrains agricoles et forestiers', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('222', 'Terrains nus', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('223', 'Terrains bâtis', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('224', 'Travaux de mise en valeur des terrains', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('225', 'Terrains de gisement', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('23', 'BÂTIMENTS, INSTALLATIONS TECHNIQUES ET AGENCEMENTS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('231', 'Bâtiments industriels', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('232', 'Bâtiments commerciaux', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('233', 'Bâtiments administratifs', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('234', 'Installations techniques', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('235', 'Aménagements de bureaux', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('24', 'MATÉRIEL', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('241', 'Matériel et outillage industriel et commercial', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('242', 'Matériel et outillage agricole', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('243', 'Matériel d''emballage récupérable', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('244', 'Matériel et mobilier de bureau', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('245', 'Matériel de transport', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('246', 'Matériel informatique', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('247', 'Agencements et installations dans immeubles non propriété', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('248', 'Autres matériels', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('25', 'AVANCES ET ACOMPTES VERSÉS SUR IMMOBILISATIONS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('251', 'Avances et acomptes sur immobilisations incorporelles', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('252', 'Avances et acomptes sur immobilisations corporelles', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('26', 'TITRES DE PARTICIPATION', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('261', 'Titres de participation dans des sociétés sous contrôle exclusif', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('262', 'Titres de participation dans des sociétés sous contrôle conjoint', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('263', 'Titres de participation dans des sociétés conférant influence notable', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('265', 'Participations dans des organismes professionnels', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('266', 'Autres titres de participation', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('27', 'AUTRES IMMOBILISATIONS FINANCIÈRES', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('271', 'Prêts et créances non commerciales', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('272', 'Prêts au personnel', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('273', 'Créances sur l''État', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('274', 'Titres immobilisés', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('275', 'Dépôts et cautionnements versés', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('276', 'Intérêts courus', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('28', 'AMORTISSEMENTS', 'ASSET', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('281', 'Amortissements des immobilisations incorporelles', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('282', 'Amortissements des terrains', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('283', 'Amortissements des bâtiments', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('284', 'Amortissements du matériel', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('29', 'PROVISIONS POUR DÉPRÉCIATION', 'ASSET', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('291', 'Provisions pour dépréciation des immobilisations incorporelles', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('292', 'Provisions pour dépréciation des terrains', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('293', 'Provisions pour dépréciation des bâtiments', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('296', 'Provisions pour dépréciation des titres de participation', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('297', 'Provisions pour dépréciation des autres immobilisations financières', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- ── CLASSE 3 : STOCKS ──
INSERT INTO _ohada_accounts VALUES
  ('3', 'COMPTES DE STOCKS', 'ASSET', 1, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('31', 'MARCHANDISES', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('311', 'Marchandises A', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('312', 'Marchandises B', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('32', 'MATIÈRES PREMIÈRES ET FOURNITURES LIÉES', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('321', 'Matières premières', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('322', 'Fournitures liées', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('33', 'AUTRES APPROVISIONNEMENTS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('331', 'Matières consommables', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('332', 'Fournitures d''atelier et d''usine', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('333', 'Fournitures de magasin', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('334', 'Fournitures de bureau', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('335', 'Emballages', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('34', 'PRODUITS EN COURS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('341', 'Produits en cours', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('35', 'SERVICES EN COURS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('351', 'Travaux en cours', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('36', 'PRODUITS FINIS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('361', 'Produits finis A', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('37', 'PRODUITS INTERMÉDIAIRES ET RÉSIDUELS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('371', 'Produits intermédiaires', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('372', 'Produits résiduels (déchets, rebuts)', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('38', 'STOCKS EN COURS DE ROUTE, EN CONSIGNATION', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('381', 'Marchandises en cours de route', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('39', 'DÉPRÉCIATIONS DES STOCKS', 'ASSET', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('391', 'Dépréciations des marchandises', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('392', 'Dépréciations des matières premières', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('393', 'Dépréciations des autres approvisionnements', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- ── CLASSE 4 : TIERS ──
INSERT INTO _ohada_accounts VALUES
  ('4', 'COMPTES DE TIERS', 'LIABILITY', 1, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('40', 'FOURNISSEURS ET COMPTES RATTACHÉS', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('401', 'Fournisseurs, dettes en compte', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('4011', 'Fournisseurs', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('4017', 'Fournisseurs, retenues de garantie', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('402', 'Fournisseurs, effets à payer', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('408', 'Fournisseurs, factures non parvenues', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('409', 'Fournisseurs débiteurs', 'LIABILITY', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('4091', 'Fournisseurs, avances et acomptes versés', 'LIABILITY', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('41', 'CLIENTS ET COMPTES RATTACHÉS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('411', 'Clients, créances en compte', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('4111', 'Clients', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('4117', 'Clients, retenues de garantie', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('412', 'Clients, effets à recevoir', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('413', 'Clients, chèques et effets non échus', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('416', 'Créances clients litigieuses ou douteuses', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('418', 'Clients, produits à recevoir', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('419', 'Clients créditeurs', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('4191', 'Clients, avances et acomptes reçus', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('42', 'PERSONNEL', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('421', 'Personnel, avances et acomptes', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('422', 'Personnel, rémunérations dues', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('423', 'Personnel, oppositions, saisies-arrêts', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('424', 'Personnel, œuvres sociales internes', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('425', 'Représentants du personnel', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('428', 'Personnel, charges à payer', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('43', 'ORGANISMES SOCIAUX', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('431', 'Sécurité sociale', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('432', 'Caisses de retraite', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('433', 'Autres organismes sociaux', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('438', 'Organismes sociaux, charges à payer', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('44', 'ÉTAT ET COLLECTIVITÉS PUBLIQUES', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('441', 'État, impôt sur les bénéfices', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('442', 'État, autres impôts et taxes', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('443', 'État, TVA facturée', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('4431', 'TVA facturée sur ventes', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('4432', 'TVA facturée sur prestations de services', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('4435', 'TVA sur factures à établir', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('444', 'État, TVA due', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('445', 'État, TVA récupérable', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('4451', 'TVA récupérable sur immobilisations', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('4452', 'TVA récupérable sur achats', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('4453', 'TVA récupérable sur transport', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('4454', 'TVA récupérable sur services extérieurs', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('446', 'État, autres taxes sur le chiffre d''affaires', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('447', 'État, impôts retenus à la source', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('448', 'État, charges à payer', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('449', 'État, créances et dettes diverses', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('45', 'ORGANISMES INTERNATIONAUX', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('46', 'ASSOCIÉS ET GROUPE', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('461', 'Associés, opérations sur le capital', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('462', 'Associés, comptes courants', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('463', 'Associés, dividendes à payer', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('465', 'Associés, créances sur appels de fonds', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('47', 'DÉBITEURS ET CRÉDITEURS DIVERS', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('471', 'Comptes d''attente débiteurs', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('472', 'Comptes d''attente créditeurs', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('476', 'Charges constatées d''avance', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('477', 'Produits constatés d''avance', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('478', 'Écarts de conversion - Actif', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('479', 'Écarts de conversion - Passif', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('48', 'CRÉANCES ET DETTES HORS ACTIVITÉS ORDINAIRES', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('49', 'DÉPRÉCIATIONS ET PROVISIONS POUR RISQUES (TIERS)', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('491', 'Dépréciations des comptes de tiers', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('499', 'Risques provisionnés à caractère financier', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- ── CLASSE 5 : TRÉSORERIE ──
INSERT INTO _ohada_accounts VALUES
  ('5', 'COMPTES DE TRÉSORERIE', 'ASSET', 1, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('50', 'TITRES DE PLACEMENT', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('501', 'Actions', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('502', 'Obligations', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('506', 'Intérêts courus', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('51', 'BANQUES, ÉTABLISSEMENTS FINANCIERS ET ASSIMILÉS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('511', 'Valeurs à encaisser', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('512', 'Banques comptes courants', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('5121', 'Banque A', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('5122', 'Banque B', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('513', 'Chèques à encaisser', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('514', 'Chèques à l''encaissement', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('515', 'Cartes de crédit à encaisser', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('516', 'Virements de fonds', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('518', 'Intérêts courus sur comptes bancaires', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('519', 'Concours bancaires courants', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('5191', 'Crédits de trésorerie', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('5193', 'Découverts bancaires', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
  ('52', 'INSTRUMENTS DE TRÉSORERIE', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('53', 'ÉTABLISSEMENTS FINANCIERS ET ASSIMILÉS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('531', 'Chèques postaux', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('532', 'Trésor', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('54', 'RÉGIES D''AVANCES, ACCRÉDITIFS ET VIREMENTS INTERNES', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('541', 'Régies d''avances', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('542', 'Accréditifs', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('543', 'Virements internes de fonds', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('56', 'BANQUES, CRÉDITS DE TRÉSORERIE', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('57', 'CAISSE', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('571', 'Caisse siège social', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('572', 'Caisse succursale A', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('58', 'VIREMENTS INTERNES', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
  ('581', 'Virements de fonds', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
  ('59', 'DÉPRÉCIATIONS DES TITRES DE PLACEMENT', 'ASSET', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
  ('591', 'Dépréciations des titres de placement', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- ── CLASSE 6 : CHARGES ──
INSERT INTO _ohada_accounts VALUES
  ('6', 'COMPTES DE CHARGES DES ACTIVITÉS ORDINAIRES', 'EXPENSE', 1, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
  ('60', 'ACHATS ET VARIATIONS DE STOCKS', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
  ('601', 'Achats de marchandises', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('602', 'Achats de matières premières', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('603', 'Variations des stocks de biens achetés', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('604', 'Achats stockés de matières et fournitures', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('605', 'Autres achats', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('608', 'Achats d''emballages', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('61', 'TRANSPORTS', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
  ('611', 'Transports sur achats', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('612', 'Transports sur ventes', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('613', 'Transports pour le compte de tiers', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('614', 'Transports du personnel', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('62', 'SERVICES EXTÉRIEURS A', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
  ('621', 'Sous-traitance générale', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('622', 'Locations et charges locatives', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('623', 'Redevances de crédit-bail', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('624', 'Entretien, réparations et maintenance', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('625', 'Primes d''assurance', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('626', 'Études, recherches et documentation', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('627', 'Publicité, publications, relations publiques', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('628', 'Frais de télécommunications', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('63', 'SERVICES EXTÉRIEURS B', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
  ('631', 'Frais bancaires', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('632', 'Rémunérations d''intermédiaires et honoraires', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('633', 'Frais de formation du personnel', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('634', 'Redevances pour brevets et licences', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('635', 'Cotisations', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('636', 'Frais de réception', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('637', 'Rémunérations du personnel extérieur à l''entreprise', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('638', 'Autres charges externes', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('64', 'IMPÔTS ET TAXES', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
  ('641', 'Impôts et taxes directs', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('642', 'Impôts et taxes indirects', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('645', 'Impôts sur les sociétés', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('646', 'Droits d''enregistrement', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('647', 'Pénalités et amendes fiscales', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('648', 'Autres impôts et taxes', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('65', 'AUTRES CHARGES', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
  ('651', 'Pertes sur créances clients', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('652', 'Quote-part de résultat sur opérations faites en commun', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('654', 'Valeurs comptables de cession d''immobilisations', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('658', 'Charges diverses', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('659', 'Charges provisionnées d''exploitation', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('66', 'CHARGES DE PERSONNEL', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
  ('661', 'Rémunérations directes versées au personnel national', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('662', 'Rémunérations directes versées au personnel non national', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('663', 'Indemnités forfaitaires versées au personnel', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('664', 'Charges sociales', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('6641', 'Charges sociales sur rémunérations du personnel national', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('6642', 'Charges sociales sur rémunérations du personnel non national', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('666', 'Rémunérations et charges sociales de l''exploitant', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('667', 'Rémunérations transférées de personnel extérieur', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('668', 'Autres charges sociales', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('67', 'FRAIS FINANCIERS ET CHARGES ASSIMILÉES', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
  ('671', 'Intérêts des emprunts', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('672', 'Intérêts dans loyers de crédit-bail', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('673', 'Escomptes accordés', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('674', 'Pertes de change', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('675', 'Escomptes des effets de commerce', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('676', 'Pertes sur cessions de titres de placement', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('677', 'Pertes sur créances financières', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('678', 'Autres charges financières', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('679', 'Charges provisionnées financières', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('68', 'DOTATIONS AUX AMORTISSEMENTS', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
  ('681', 'Dotations aux amortissements d''exploitation', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('6811', 'Dotations aux amortissements des immobilisations incorporelles', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('6812', 'Dotations aux amortissements des immobilisations corporelles', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('686', 'Dotations aux provisions d''exploitation', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('687', 'Dotations aux provisions financières', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('69', 'DOTATIONS HORS ACTIVITÉS ORDINAIRES', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
  ('691', 'Dotations aux provisions HAO', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT');

-- ── CLASSE 7 : PRODUITS ──
INSERT INTO _ohada_accounts VALUES
  ('7', 'COMPTES DE PRODUITS DES ACTIVITÉS ORDINAIRES', 'REVENUE', 1, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
  ('70', 'VENTES', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
  ('701', 'Ventes de marchandises', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('702', 'Ventes de produits finis', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('703', 'Ventes de produits intermédiaires', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('704', 'Ventes de produits résiduels', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('705', 'Travaux facturés', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('706', 'Services vendus', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('707', 'Produits accessoires', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('71', 'SUBVENTIONS D''EXPLOITATION', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
  ('711', 'Subventions d''exploitation reçues', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('72', 'PRODUCTION IMMOBILISÉE', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
  ('721', 'Production immobilisée - immobilisations incorporelles', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('722', 'Production immobilisée - immobilisations corporelles', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('73', 'VARIATIONS DE STOCKS DE BIENS ET SERVICES PRODUITS', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
  ('734', 'Variation de stocks de produits en cours', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('735', 'Variation de stocks de services en cours', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('736', 'Variation de stocks de produits finis', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('75', 'AUTRES PRODUITS', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
  ('752', 'Quote-part de résultat sur opérations faites en commun', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('754', 'Produits des cessions d''immobilisations', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('758', 'Produits divers', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('759', 'Reprises de charges provisionnées d''exploitation', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('76', 'PRODUITS FINANCIERS', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
  ('761', 'Produits de participations', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('762', 'Produits de placements', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('764', 'Revenus de titres de placement', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('765', 'Escomptes obtenus', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('766', 'Gains de change', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('767', 'Gains sur cessions de titres de placement', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('768', 'Autres produits financiers', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('77', 'REPRISES DE PROVISIONS ET DÉPRÉCIATIONS FINANCIÈRES', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
  ('771', 'Reprises de provisions financières', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('78', 'TRANSFERTS DE CHARGES', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
  ('781', 'Transferts de charges d''exploitation', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('787', 'Transferts de charges financières', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('79', 'REPRISES DE PROVISIONS HAO', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
  ('791', 'Reprises de provisions HAO', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT');

-- ── CLASSE 8 : AUTRES CHARGES ET PRODUITS ──
INSERT INTO _ohada_accounts VALUES
  ('8', 'COMPTES DES AUTRES CHARGES ET PRODUITS', 'EXPENSE', 1, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
  ('81', 'VALEURS COMPTABLES DES CESSIONS D''IMMOBILISATIONS', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
  ('811', 'Valeurs comptables des cessions d''immobilisations incorporelles', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('812', 'Valeurs comptables des cessions d''immobilisations corporelles', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('816', 'Valeurs comptables des cessions d''immobilisations financières', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('82', 'PRODUITS DES CESSIONS D''IMMOBILISATIONS', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
  ('821', 'Produits des cessions d''immobilisations incorporelles', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('822', 'Produits des cessions d''immobilisations corporelles', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('826', 'Produits des cessions d''immobilisations financières', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('83', 'CHARGES HAO', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
  ('831', 'Charges HAO constatées', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('834', 'Pertes sur créances HAO', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('835', 'Dons et libéralités accordés', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('836', 'Abandons de créances consentis', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('84', 'PRODUITS HAO', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
  ('841', 'Produits HAO constatés', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('845', 'Dons et libéralités obtenus', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('846', 'Abandons de créances obtenus', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('848', 'Transferts de charges HAO', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('85', 'DOTATIONS HAO', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
  ('851', 'Dotations aux provisions HAO', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('852', 'Dotations aux dépréciations HAO', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('86', 'REPRISES HAO', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
  ('861', 'Reprises de provisions HAO', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('862', 'Reprises de dépréciations HAO', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('87', 'PARTICIPATIONS DES TRAVAILLEURS', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
  ('871', 'Participation légale des travailleurs aux bénéfices', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('88', 'SUBVENTIONS D''ÉQUILIBRE', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
  ('881', 'Subventions d''équilibre reçues', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
  ('89', 'IMPÔTS SUR LE RÉSULTAT', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
  ('891', 'Impôts sur les bénéfices de l''exercice', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('892', 'Rappel d''impôts sur résultats antérieurs', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('895', 'Impôt minimum forfaitaire', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
  ('899', 'Dégrèvements et annulations d''impôts sur résultats', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT');

-- ── CLASSE 9 : COMPTABILITÉ ANALYTIQUE ──
INSERT INTO _ohada_accounts VALUES
  ('9', 'COMPTES DE LA COMPTABILITÉ ANALYTIQUE DE GESTION', 'EXPENSE', 1, FALSE, 'DEBIT', NULL),
  ('90', 'COMPTES DE LIAISON INTERNES', 'EXPENSE', 2, TRUE, 'DEBIT', NULL),
  ('91', 'MARGE SUR MATIÈRES', 'EXPENSE', 2, TRUE, 'DEBIT', NULL),
  ('92', 'CENTRES D''ANALYSE', 'EXPENSE', 2, TRUE, 'DEBIT', NULL),
  ('93', 'COÛTS DES PRODUITS FABRIQUÉS', 'EXPENSE', 2, TRUE, 'DEBIT', NULL),
  ('94', 'INVENTAIRE PERMANENT DES STOCKS', 'EXPENSE', 2, TRUE, 'DEBIT', NULL),
  ('95', 'COÛTS DE REVIENT', 'EXPENSE', 2, TRUE, 'DEBIT', NULL),
  ('96', 'ÉCARTS SUR COÛTS PRÉÉTABLIS', 'EXPENSE', 2, TRUE, 'DEBIT', NULL),
  ('97', 'DIFFÉRENCES D''INCORPORATION', 'EXPENSE', 2, TRUE, 'DEBIT', NULL),
  ('98', 'RÉSULTATS ANALYTIQUES', 'EXPENSE', 2, TRUE, 'DEBIT', NULL),
  ('99', 'LIAISONS INTERNES', 'EXPENSE', 2, TRUE, 'DEBIT', NULL);

-- ── Insertion dans common.chart_of_accounts_details ──
INSERT INTO common.chart_of_accounts_details (
  chart_template_id, account_number, account_label, account_type,
  parent_account_number, level, is_detail_account, normal_balance, financial_statement
)
SELECT
  (SELECT id FROM common.chart_of_accounts_templates WHERE code = 'OHADA_2017'),
  a.account_number, a.account_name, a.account_type,
  CASE
    WHEN a.account_level = 1 THEN NULL
    WHEN a.account_level = 2 THEN LEFT(a.account_number, 1)
    WHEN a.account_level = 3 THEN LEFT(a.account_number, 2)
    WHEN a.account_level = 4 THEN LEFT(a.account_number, 3)
  END,
  a.account_level,
  COALESCE(a.is_detail, FALSE),
  a.normal_balance,
  a.financial_statement
FROM _ohada_accounts a
ON CONFLICT (chart_template_id, account_number) DO NOTHING;

-- ── Copie vers client_demo.chart_of_accounts ──
INSERT INTO client_demo.chart_of_accounts (
  template_id, account_number, account_label, account_type,
  level, is_detail_account, normal_balance, financial_statement
)
SELECT
  (SELECT id FROM common.chart_of_accounts_templates WHERE code = 'OHADA_2017'),
  a.account_number, a.account_name, a.account_type,
  a.account_level, COALESCE(a.is_detail, FALSE),
  a.normal_balance, a.financial_statement
FROM _ohada_accounts a
ON CONFLICT (account_number) DO NOTHING;

DROP TABLE _ohada_accounts;

-- ────────────────────────────────────────────────────────────────────────────
-- B. RUBRIQUES DE PAIE (30 rubriques)
-- ────────────────────────────────────────────────────────────────────────────

INSERT INTO client_demo.payroll_rubrics
  (code, label, rubric_type, rubric_category, calc_mode, default_base,
   default_rate, bulletin_section, display_order)
VALUES
  -- Gains
  ('100', 'Salaire de base',              'EARNING', 'BASE',     'FIXED',         'BASE_SALARY', NULL,   'GROSS', 10),
  ('110', 'Heures supplémentaires 25%',   'EARNING', 'OVERTIME', 'QUANTITY_RATE', 'HOURLY_RATE', 1.2500, 'GROSS', 20),
  ('120', 'Heures supplémentaires 50%',   'EARNING', 'OVERTIME', 'QUANTITY_RATE', 'HOURLY_RATE', 1.5000, 'GROSS', 30),
  ('130', 'Heures supplémentaires 100%',  'EARNING', 'OVERTIME', 'QUANTITY_RATE', 'HOURLY_RATE', 2.0000, 'GROSS', 40),
  ('200', 'Prime d''ancienneté',          'EARNING', 'BONUS',    'RATE_ON_BASE',  'BASE_SALARY', NULL,   'GROSS', 50),
  ('210', 'Prime de rendement',           'EARNING', 'BONUS',    'MANUAL',        NULL,          NULL,   'GROSS', 60),
  ('220', 'Prime exceptionnelle',         'EARNING', 'BONUS',    'MANUAL',        NULL,          NULL,   'GROSS', 70),
  ('230', 'Indemnité de transport',       'EARNING', 'BONUS',    'FIXED',         NULL,          NULL,   'GROSS', 80),
  ('240', 'Avantage en nature logement',  'EARNING', 'BENEFIT',  'FIXED',         NULL,          NULL,   'GROSS', 90),
  ('250', 'Avantage en nature véhicule',  'EARNING', 'BENEFIT',  'FIXED',         NULL,          NULL,   'GROSS', 100),
  ('260', '13ème mois',                   'EARNING', 'BONUS',    'RATE_ON_BASE',  'BASE_SALARY', 1.0000, 'GROSS', 110),
  ('270', 'Indemnité de logement',        'EARNING', 'BONUS',    'FIXED',         NULL,          NULL,   'GROSS', 120),
  ('280', 'Prime de technicité',          'EARNING', 'BONUS',    'MANUAL',        NULL,          NULL,   'GROSS', 130),
  ('290', 'Retenue absence non payée',    'EARNING', 'OTHER',    'FORMULA',       'DAILY_RATE',  NULL,   'GROSS', 140),
  -- Cotisations salariales
  ('300', 'CNSS - Vieillesse (salariale)',       'DEDUCTION_EMP',  'SOCIAL',     'RATE_ON_GROSS', 'CAPPED_A', 0.0250, 'EMPLOYEE_CONTRIB', 200),
  ('310', 'Retraite complémentaire (salariale)', 'DEDUCTION_EMP',  'RETIREMENT', 'RATE_ON_GROSS', 'GROSS',    0.0360, 'EMPLOYEE_CONTRIB', 210),
  ('320', 'CNAMGS - Assurance maladie',          'DEDUCTION_EMP',  'SOCIAL',     'RATE_ON_GROSS', 'GROSS',    0.0100, 'EMPLOYEE_CONTRIB', 220),
  -- Cotisations patronales
  ('400', 'CNSS - Vieillesse (patronale)',       'DEDUCTION_EMPR', 'SOCIAL',     'RATE_ON_GROSS', 'CAPPED_A', 0.1600, 'EMPLOYER_CONTRIB', 300),
  ('410', 'Prestations familiales',              'DEDUCTION_EMPR', 'SOCIAL',     'RATE_ON_GROSS', 'GROSS',    0.0800, 'EMPLOYER_CONTRIB', 310),
  ('420', 'Accident du travail',                 'DEDUCTION_EMPR', 'SOCIAL',     'RATE_ON_GROSS', 'GROSS',    0.0250, 'EMPLOYER_CONTRIB', 320),
  ('430', 'Retraite complémentaire (patronale)', 'DEDUCTION_EMPR', 'RETIREMENT', 'RATE_ON_GROSS', 'GROSS',    0.0770, 'EMPLOYER_CONTRIB', 330),
  ('440', 'Taxe d''apprentissage',               'DEDUCTION_EMPR', 'SOCIAL',     'RATE_ON_GROSS', 'GROSS',    0.0120, 'EMPLOYER_CONTRIB', 340),
  ('450', 'Contribution formation professionnelle','DEDUCTION_EMPR','SOCIAL',    'RATE_ON_GROSS', 'GROSS',    0.0060, 'EMPLOYER_CONTRIB', 350),
  -- Impôts
  ('500', 'IRPP retenu à la source',        'TAX', 'TAX', 'FORMULA', 'NET_TAXABLE', NULL, 'NET', 400),
  ('510', 'Contribution foncière',          'TAX', 'TAX', 'MANUAL',  NULL,          NULL, 'NET', 410),
  -- Retenues sur net
  ('600', 'Avance sur salaire',             'NET_DEDUCTION', 'OTHER', 'MANUAL', NULL, NULL, 'NET', 500),
  ('610', 'Saisie-arrêt',                  'NET_DEDUCTION', 'OTHER', 'MANUAL', NULL, NULL, 'NET', 510),
  ('620', 'Remboursement prêt employeur',   'NET_DEDUCTION', 'OTHER', 'FIXED',  NULL, NULL, 'NET', 520),
  ('630', 'Cession sur salaire',            'NET_DEDUCTION', 'OTHER', 'MANUAL', NULL, NULL, 'NET', 530)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────────────────
-- C. BARÈMES COTISATIONS CNSS/CRF/CNAMGS GABON 2025
-- Source normative : lus depuis cette table (jamais hardcodés dans les RPC)
-- Référence : Décret n° 000266/PR/MTEPS + Convention CRF + Loi CNAMGS 2007
-- ────────────────────────────────────────────────────────────────────────────

INSERT INTO client_demo.contribution_rates
  (rubric_id, organism_code, organism_label, bracket_code, bracket_floor,
   bracket_ceiling, employee_rate, employer_rate, applies_to,
   effective_date, legal_reference)
SELECT r.id, v.organism_code, v.organism_label, v.bracket_code,
       v.bracket_floor::DECIMAL, v.bracket_ceiling,
       v.employee_rate::DECIMAL, v.employer_rate::DECIMAL,
       v.applies_to, v.effective_date::DATE, v.legal_reference
FROM (VALUES
  -- CNSS Vieillesse — tranche A plafonnée à 1 500 000 XAF/mois
  ('300', 'CNSS',   'CNSS - Vieillesse salariale',  'A',     0, 1500000::DECIMAL, 0.02500, 0.00000, 'ALL', '2025-01-01', 'Décret CNSS Gabon'),
  ('400', 'CNSS',   'CNSS - Vieillesse patronale',  'A',     0, 1500000::DECIMAL, 0.00000, 0.16000, 'ALL', '2025-01-01', 'Décret CNSS Gabon'),
  -- Prestations familiales — sur totalité
  ('410', 'CNSS',   'Prestations familiales',        'TOTAL', 0, NULL,             0.00000, 0.08000, 'ALL', '2025-01-01', 'Décret CNSS Gabon'),
  -- Accident du travail
  ('420', 'CNSS',   'Accident du travail',           'TOTAL', 0, NULL,             0.00000, 0.02500, 'ALL', '2025-01-01', 'Arrêté ministériel AT'),
  -- Retraite complémentaire CRF
  ('310', 'CRF',    'Retraite complémentaire sal.',  'TOTAL', 0, NULL,             0.03600, 0.00000, 'ALL', '2025-01-01', 'Convention CRF'),
  ('430', 'CRF',    'Retraite complémentaire pat.',  'TOTAL', 0, NULL,             0.00000, 0.07700, 'ALL', '2025-01-01', 'Convention CRF'),
  -- CNAMGS
  ('320', 'CNAMGS', 'Assurance maladie obligatoire', 'TOTAL', 0, NULL,             0.01000, 0.00000, 'ALL', '2025-01-01', 'Loi CNAMGS 2007'),
  -- Taxes
  ('440', 'ETAT',   'Taxe d''apprentissage',         'TOTAL', 0, NULL,             0.00000, 0.01200, 'ALL', '2025-01-01', 'Code fiscal gabonais'),
  ('450', 'ETAT',   'Formation professionnelle',     'TOTAL', 0, NULL,             0.00000, 0.00600, 'ALL', '2025-01-01', 'Code du travail gabonais')
) AS v(rubric_code, organism_code, organism_label, bracket_code, bracket_floor,
       bracket_ceiling, employee_rate, employer_rate, applies_to, effective_date, legal_reference)
JOIN client_demo.payroll_rubrics r ON r.code = v.rubric_code;

-- ────────────────────────────────────────────────────────────────────────────
-- D. TYPES D'ABSENCES
-- ────────────────────────────────────────────────────────────────────────────

INSERT INTO client_demo.absence_types
  (code, label, is_paid, deduction_method, waiting_days,
   accrual_per_month, max_balance, requires_justification, requires_approval)
VALUES
  ('CP',     'Congés payés',           TRUE,  'NONE',          0, 2.5, 30.0, FALSE, TRUE),
  ('RTT',    'RTT',                    TRUE,  'NONE',          0, 1.0, 12.0, FALSE, TRUE),
  ('MAL',    'Maladie',                TRUE,  'WORKING_DAYS',  3, 0,   NULL, TRUE,  FALSE),
  ('AT',     'Accident du travail',    TRUE,  'NONE',          0, 0,   NULL, TRUE,  FALSE),
  ('MAT',    'Maternité',              TRUE,  'NONE',          0, 0,   NULL, TRUE,  FALSE),
  ('PAT',    'Paternité',              TRUE,  'NONE',          0, 0,   NULL, TRUE,  FALSE),
  ('SS',     'Sans solde',             FALSE, 'CALENDAR_DAYS', 0, 0,   NULL, FALSE, TRUE),
  ('ABS',    'Absence non justifiée',  FALSE, 'WORKING_DAYS',  0, 0,   NULL, FALSE, FALSE),
  ('FORM',   'Formation',              TRUE,  'NONE',          0, 0,   NULL, TRUE,  TRUE),
  ('EVT',    'Événement familial',     TRUE,  'NONE',          0, 0,   NULL, TRUE,  TRUE),
  ('DEUIL',  'Congé décès proche',     TRUE,  'NONE',          0, 0,   5.0,  TRUE,  FALSE),
  ('MARIAGE','Congé mariage',          TRUE,  'NONE',          0, 0,   4.0,  TRUE,  TRUE)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────────────────
-- E. CATÉGORIES D'IMMOBILISATIONS OHADA
-- Coefficients dégressifs stockés ici — lus par rpc_generate_depreciation
-- ────────────────────────────────────────────────────────────────────────────

INSERT INTO client_demo.asset_categories
  (code, label, default_method, default_useful_life_months,
   default_residual_pct, min_capitalization_amount,
   declining_coeff_short, declining_coeff_medium, declining_coeff_long)
VALUES
  ('LOGICIEL',  'Logiciels',                    'LINEAR',  12,  0, 500, 1.25, 1.75, 2.25),
  ('MAT_INFO',  'Matériel informatique',        'LINEAR',  36,  0, 500, 1.25, 1.75, 2.25),
  ('MAT_BUR',   'Matériel de bureau',           'LINEAR',  60,  0, 500, 1.25, 1.75, 2.25),
  ('MOBILIER',  'Mobilier de bureau',           'LINEAR', 120,  0, 500, 1.25, 1.75, 2.25),
  ('VEHICULE',  'Matériel de transport',        'LINEAR',  48,  0, 500, 1.25, 1.75, 2.25),
  ('MAT_INDUS', 'Matériel industriel',          'LINEAR',  84,  0, 500, 1.25, 1.75, 2.25),
  ('AGENC',     'Agencements et installations', 'LINEAR', 120,  0, 500, 1.25, 1.75, 2.25),
  ('CONSTRUCT', 'Constructions',                'LINEAR', 240,  0, 500, 1.25, 1.75, 2.25),
  ('TERRAIN',   'Terrains',                     'NONE',     0,  0,   0, 1.25, 1.75, 2.25),
  ('BREVET',    'Brevets et licences',          'LINEAR',  60,  0, 500, 1.25, 1.75, 2.25),
  ('FONDS',     'Fonds de commerce',            'NONE',     0,  0,   0, 1.25, 1.75, 2.25),
  ('OUTILLAGE', 'Outillage',                    'LINEAR',  60,  0, 500, 1.25, 1.75, 2.25)
ON CONFLICT (code) DO NOTHING;

-- ────────────────────────────────────────────────────────────────────────────
-- F. PÉRIODES DE PAIE 2026
-- ────────────────────────────────────────────────────────────────────────────

INSERT INTO client_demo.pay_periods
  (fiscal_year, period_month, start_date, end_date, payment_date, variable_deadline, status)
SELECT
  2026, n,
  make_date(2026, n, 1),
  (make_date(2026, n, 1) + INTERVAL '1 month' - INTERVAL '1 day')::DATE,
  (make_date(2026, n, 1) + INTERVAL '1 month' - INTERVAL '1 day')::DATE,
  make_date(2026, n, 20),
  CASE
    WHEN n < EXTRACT(MONTH FROM CURRENT_DATE)::INT THEN 'CLOSED'
    WHEN n = EXTRACT(MONTH FROM CURRENT_DATE)::INT THEN 'OPEN'
    ELSE 'OPEN'
  END
FROM generate_series(1, 12) AS n
ON CONFLICT (fiscal_year, period_month) DO NOTHING;

-- ────────────────────────────────────────────────────────────────────────────
-- VÉRIFICATION FINALE
-- ────────────────────────────────────────────────────────────────────────────

DO $$
DECLARE
  v_common_coa    INT;
  v_client_coa    INT;
  v_rubrics       INT;
  v_rates         INT;
  v_absence_types INT;
  v_categories    INT;
  v_pay_periods   INT;
BEGIN
  SELECT COUNT(*) INTO v_common_coa FROM common.chart_of_accounts_details;
  SELECT COUNT(*) INTO v_client_coa FROM client_demo.chart_of_accounts;
  SELECT COUNT(*) INTO v_rubrics FROM client_demo.payroll_rubrics;
  SELECT COUNT(*) INTO v_rates FROM client_demo.contribution_rates;
  SELECT COUNT(*) INTO v_absence_types FROM client_demo.absence_types;
  SELECT COUNT(*) INTO v_categories FROM client_demo.asset_categories;
  SELECT COUNT(*) INTO v_pay_periods FROM client_demo.pay_periods;

  RAISE NOTICE '════════════════════════════════════════════════════════';
  RAISE NOTICE '  EDENFIN JASPE — INITIALISATION BASE SUPABASE';
  RAISE NOTICE '════════════════════════════════════════════════════════';
  RAISE NOTICE '  Plan comptable common   : % comptes', v_common_coa;
  RAISE NOTICE '  Plan comptable client   : % comptes', v_client_coa;
  RAISE NOTICE '  Rubriques de paie       : % rubriques', v_rubrics;
  RAISE NOTICE '  Barèmes cotisations     : % lignes', v_rates;
  RAISE NOTICE '  Types d''absences        : % types', v_absence_types;
  RAISE NOTICE '  Catégories immo OHADA   : % catégories', v_categories;
  RAISE NOTICE '  Périodes de paie 2026   : % périodes', v_pay_periods;
  RAISE NOTICE '════════════════════════════════════════════════════════';
END $$;

-- ============================================================================
DO $$ BEGIN RAISE NOTICE '✅ Script 06 OK — Données OHADA et paramétrage JASPE chargés';
END $$;
