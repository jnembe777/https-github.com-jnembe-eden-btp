-- ============================================================================
-- PLAN COMPTABLE OHADA/SYSCOHADA RÃ‰VISÃ‰ - VERSION COMPLÃˆTE
-- Conforme au SystÃ¨me Comptable OHADA rÃ©visÃ© (2017)
-- Zone CEMAC / UEMOA
-- ============================================================================
-- Auteur: Application Multi-Gammes
-- Date: 2026
-- Version: 1.0
-- ============================================================================

-- Suppression de la table si elle existe
DROP TABLE IF EXISTS accounts CASCADE;

-- ============================================================================
-- STRUCTURE DE LA TABLE DES COMPTES
-- ============================================================================

CREATE TABLE accounts (
    id SERIAL PRIMARY KEY,
    account_number VARCHAR(10) NOT NULL UNIQUE,
    account_name VARCHAR(255) NOT NULL,
    account_type VARCHAR(50) NOT NULL,  -- ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE, OTHER
    account_level INTEGER NOT NULL,      -- 1=Classe, 2=Compte principal, 3=Sous-compte, 4=Compte dÃ©taillÃ©
    is_detail BOOLEAN DEFAULT FALSE,     -- TRUE = compte utilisable pour les Ã©critures
    normal_balance VARCHAR(10) NOT NULL, -- DEBIT ou CREDIT
    financial_statement VARCHAR(50),     -- BALANCE_SHEET ou INCOME_STATEMENT
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_account_type CHECK (account_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE', 'OTHER')),
    CONSTRAINT chk_normal_balance CHECK (normal_balance IN ('DEBIT', 'CREDIT')),
    CONSTRAINT chk_financial_statement CHECK (financial_statement IN ('BALANCE_SHEET', 'INCOME_STATEMENT'))
);

-- ============================================================================
-- CLASSE 1 : COMPTES DE RESSOURCES DURABLES
-- ============================================================================

INSERT INTO accounts (account_number, account_name, account_type, account_level, normal_balance, financial_statement) VALUES
    ('1', 'COMPTES DE RESSOURCES DURABLES', 'LIABILITY', 1, 'CREDIT', 'BALANCE_SHEET');

-- 10 - CAPITAL
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('10', 'CAPITAL', 'EQUITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('101', 'Capital social', 'EQUITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('1011', 'Capital souscrit, non appelÃ©', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1012', 'Capital souscrit, appelÃ©, non versÃ©', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1013', 'Capital souscrit, appelÃ©, versÃ©, non amorti', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1014', 'Capital souscrit, appelÃ©, versÃ©, amorti', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('102', 'Capital par dotation', 'EQUITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('1021', 'Dotation initiale', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1022', 'Dotations complÃ©mentaires', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1028', 'Autres dotations', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('103', 'Capital personnel', 'EQUITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('104', 'Compte de l''exploitant', 'EQUITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('105', 'Primes liÃ©es au capital social', 'EQUITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('1051', 'Primes d''Ã©mission', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1052', 'Primes d''apport', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1053', 'Primes de fusion', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1054', 'Primes de conversion', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1058', 'Autres primes', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('109', 'Actionnaires, capital souscrit, non appelÃ©', 'EQUITY', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 11 - RÃ‰SERVES
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('11', 'RÃ‰SERVES', 'EQUITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('111', 'RÃ©serve lÃ©gale', 'EQUITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('112', 'RÃ©serves statutaires ou contractuelles', 'EQUITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('113', 'RÃ©serves rÃ©glementÃ©es', 'EQUITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('1131', 'RÃ©serves de plus-values nettes Ã  long terme', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1133', 'RÃ©serves consÃ©cutives Ã  l''octroi de subventions d''investissement', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1138', 'Autres rÃ©serves rÃ©glementÃ©es', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('118', 'Autres rÃ©serves', 'EQUITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('1181', 'RÃ©serves facultatives', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1188', 'RÃ©serves diverses', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- 12 - REPORT Ã€ NOUVEAU
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('12', 'REPORT Ã€ NOUVEAU', 'EQUITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('121', 'Report Ã  nouveau crÃ©diteur', 'EQUITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('129', 'Report Ã  nouveau dÃ©biteur', 'EQUITY', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 13 - RÃ‰SULTAT NET DE L'EXERCICE
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('13', 'RÃ‰SULTAT NET DE L''EXERCICE', 'EQUITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('130', 'RÃ©sultat en instance d''affectation', 'EQUITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('1301', 'RÃ©sultat en instance d''affectation : BÃ©nÃ©fice', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1309', 'RÃ©sultat en instance d''affectation : Perte', 'EQUITY', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('131', 'RÃ©sultat net : BÃ©nÃ©fice', 'EQUITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('139', 'RÃ©sultat net : Perte', 'EQUITY', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 14 - SUBVENTIONS D'INVESTISSEMENT
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('14', 'SUBVENTIONS D''INVESTISSEMENT', 'EQUITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('141', 'Subventions d''Ã©quipement', 'EQUITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('1411', 'Ã‰tat', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1412', 'CollectivitÃ©s publiques', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1413', 'Organismes internationaux', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1418', 'Autres', 'EQUITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('142', 'Subventions d''Ã©quipement inscrites au compte de rÃ©sultat', 'EQUITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('148', 'Autres subventions d''investissement', 'EQUITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- 15 - PROVISIONS RÃ‰GLEMENTÃ‰ES ET FONDS ASSIMILÃ‰S
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('15', 'PROVISIONS RÃ‰GLEMENTÃ‰ES ET FONDS ASSIMILÃ‰S', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('151', 'Amortissements dÃ©rogatoires', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('152', 'Plus-values de cession Ã  rÃ©investir', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('153', 'Fonds rÃ©glementÃ©s', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('154', 'Provisions rÃ©glementÃ©es relatives aux immobilisations', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('155', 'Provisions rÃ©glementÃ©es relatives aux stocks', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('156', 'Provisions spÃ©ciales de rÃ©Ã©valuation', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('157', 'Provisions pour investissement', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('158', 'Autres provisions et fonds rÃ©glementÃ©s', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- 16 - EMPRUNTS ET DETTES ASSIMILÃ‰ES
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('16', 'EMPRUNTS ET DETTES ASSIMILÃ‰ES', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('161', 'Emprunts obligataires', 'LIABILITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('1611', 'Emprunts obligataires ordinaires', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1612', 'Emprunts obligataires convertibles', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1618', 'Autres emprunts obligataires', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('162', 'Emprunts et dettes auprÃ¨s des Ã©tablissements de crÃ©dit', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('163', 'Avances reÃ§ues de l''Ã‰tat', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('164', 'Avances reÃ§ues et comptes courants bloquÃ©s', 'LIABILITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('1641', 'Avances reÃ§ues des associÃ©s', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1642', 'Comptes courants bloquÃ©s', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('165', 'DÃ©pÃ´ts et cautionnements reÃ§us', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('166', 'IntÃ©rÃªts courus', 'LIABILITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('1661', 'IntÃ©rÃªts courus sur emprunts obligataires', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1662', 'IntÃ©rÃªts courus sur emprunts et dettes auprÃ¨s des Ã©tablissements de crÃ©dit', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1663', 'IntÃ©rÃªts courus sur avances reÃ§ues de l''Ã‰tat', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1664', 'IntÃ©rÃªts courus sur avances reÃ§ues et comptes courants bloquÃ©s', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1665', 'IntÃ©rÃªts courus sur dÃ©pÃ´ts et cautionnements reÃ§us', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1668', 'IntÃ©rÃªts courus sur autres emprunts et dettes', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('167', 'Avances assorties de conditions particuliÃ¨res', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('168', 'Autres emprunts et dettes', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- 17 - DETTES DE CRÃ‰DIT-BAIL ET CONTRATS ASSIMILÃ‰S
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('17', 'DETTES DE CRÃ‰DIT-BAIL ET CONTRATS ASSIMILÃ‰S', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('172', 'Emprunts Ã©quivalents de crÃ©dit-bail immobilier', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('173', 'Emprunts Ã©quivalents de crÃ©dit-bail mobilier', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('176', 'IntÃ©rÃªts courus', 'LIABILITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('1762', 'IntÃ©rÃªts courus sur crÃ©dit-bail immobilier', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1763', 'IntÃ©rÃªts courus sur crÃ©dit-bail mobilier', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('178', 'Emprunts Ã©quivalents d''autres contrats', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- 18 - DETTES LIÃ‰ES Ã€ DES PARTICIPATIONS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('18', 'DETTES LIÃ‰ES Ã€ DES PARTICIPATIONS ET COMPTES DE LIAISON', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('181', 'Dettes liÃ©es Ã  des participations (groupe)', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('182', 'Dettes liÃ©es Ã  des participations (hors groupe)', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('183', 'Dettes liÃ©es Ã  des sociÃ©tÃ©s en participation', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('184', 'Comptes de liaison des Ã©tablissements', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('185', 'Comptes de liaison des sociÃ©tÃ©s en participation', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('186', 'Comptes de liaison charges', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('187', 'Comptes de liaison produits', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('188', 'Comptes de liaison - OpÃ©rations faites en commun', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- 19 - PROVISIONS POUR RISQUES ET CHARGES
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('19', 'PROVISIONS POUR RISQUES ET CHARGES', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('191', 'Provisions pour litiges', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('192', 'Provisions pour garanties donnÃ©es aux clients', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('193', 'Provisions pour pertes sur marchÃ©s Ã  achÃ¨vement futur', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('194', 'Provisions pour pertes de change', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('195', 'Provisions pour impÃ´ts', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('196', 'Provisions pour pensions et obligations similaires', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('197', 'Provisions pour charges Ã  rÃ©partir sur plusieurs exercices', 'LIABILITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('1971', 'Provisions pour grosses rÃ©parations', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('1972', 'Provisions pour renouvellement des immobilisations', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('198', 'Autres provisions pour charges', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- ============================================================================
-- CLASSE 2 : COMPTES D'ACTIF IMMOBILISÃ‰
-- ============================================================================

INSERT INTO accounts (account_number, account_name, account_type, account_level, normal_balance, financial_statement) VALUES
    ('2', 'COMPTES D''ACTIF IMMOBILISÃ‰', 'ASSET', 1, 'DEBIT', 'BALANCE_SHEET');

-- 20 - CHARGES IMMOBILISÃ‰ES
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('20', 'CHARGES IMMOBILISÃ‰ES', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('201', 'Frais d''Ã©tablissement', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('2011', 'Frais de constitution', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2012', 'Frais de prospection', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2013', 'Frais de publicitÃ© et de lancement', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2014', 'Frais de fonctionnement antÃ©rieurs au dÃ©marrage', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2015', 'Frais de modification du capital', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2016', 'Frais d''entrÃ©e Ã  la bourse', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2017', 'Frais de restructuration', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2018', 'Frais divers d''Ã©tablissement', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('202', 'Charges Ã  rÃ©partir sur plusieurs exercices', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('2021', 'Charges diffÃ©rÃ©es', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2022', 'Frais d''acquisition d''immobilisations', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2026', 'Frais d''Ã©mission des emprunts', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2028', 'Charges Ã  Ã©taler', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('206', 'Primes de remboursement des obligations', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 21 - IMMOBILISATIONS INCORPORELLES
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('21', 'IMMOBILISATIONS INCORPORELLES', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('211', 'Frais de recherche et de dÃ©veloppement', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('212', 'Brevets, licences, concessions et droits similaires', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('213', 'Logiciels et sites internet', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('2131', 'Logiciels acquis', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2132', 'Logiciels crÃ©Ã©s', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2133', 'Sites internet', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('214', 'Marques', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('215', 'Fonds commercial', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('216', 'Droit au bail', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('217', 'Investissements de crÃ©ation', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('218', 'Autres droits et valeurs incorporels', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('219', 'Immobilisations incorporelles en cours', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 22 - TERRAINS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('22', 'TERRAINS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('221', 'Terrains agricoles et forestiers', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('2211', 'Terrains d''exploitation agricole', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2212', 'Terrains d''exploitation forestiÃ¨re', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2218', 'Autres terrains agricoles et forestiers', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('222', 'Terrains nus', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('223', 'Terrains bÃ¢tis', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('2231', 'Terrains bÃ¢tis propres', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2232', 'Terrains bÃ¢tis louÃ©s', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('224', 'Travaux de mise en valeur des terrains', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('225', 'Terrains de gisement', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('2251', 'CarriÃ¨res', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2252', 'Terrains pÃ©trolifÃ¨res et gaziers', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2258', 'Autres terrains de gisement', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('226', 'Terrains amÃ©nagÃ©s', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('227', 'Terrains mis en concession', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('228', 'Autres terrains', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('229', 'AmÃ©nagements des terrains en cours', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 23 - BÃ‚TIMENTS, INSTALLATIONS TECHNIQUES ET AGENCEMENTS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('23', 'BÃ‚TIMENTS, INSTALLATIONS TECHNIQUES ET AGENCEMENTS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('231', 'BÃ¢timents industriels', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('2311', 'BÃ¢timents industriels propres', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2312', 'BÃ¢timents industriels louÃ©s', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('232', 'BÃ¢timents administratifs et commerciaux', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('2321', 'BÃ¢timents administratifs et commerciaux propres', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2322', 'BÃ¢timents administratifs et commerciaux louÃ©s', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('233', 'Ouvrages d''infrastructure', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('234', 'Installations techniques', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('235', 'AmÃ©nagements de bureaux', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('237', 'BÃ¢timents industriels, administratifs et commerciaux mis en concession', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('238', 'Autres bÃ¢timents', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('239', 'BÃ¢timents et installations en cours', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 24 - MATÃ‰RIEL
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('24', 'MATÃ‰RIEL', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('241', 'MatÃ©riel et outillage industriel et commercial', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('2411', 'MatÃ©riel industriel', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2412', 'Outillage industriel', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2413', 'MatÃ©riel commercial', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2414', 'Outillage commercial', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('242', 'MatÃ©riel et outillage agricole', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('243', 'MatÃ©riel d''emballage rÃ©cupÃ©rable et identifiable', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('244', 'MatÃ©riel et mobilier', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('2441', 'MatÃ©riel de bureau', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2442', 'MatÃ©riel informatique', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2443', 'MatÃ©riel bureautique', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2444', 'Mobilier de bureau', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2446', 'MatÃ©riel et mobilier des logements', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('245', 'MatÃ©riel de transport', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('2451', 'MatÃ©riel automobile', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2452', 'MatÃ©riel ferroviaire', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2453', 'MatÃ©riel fluvial, lagunaire', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2454', 'MatÃ©riel naval', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2455', 'MatÃ©riel aÃ©rien', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2458', 'Autres matÃ©riels de transport', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('246', 'Immobilisations animales et agricoles', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('2461', 'Cheptel, animaux de trait', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2462', 'Cheptel, animaux reproducteurs', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2468', 'Autres immobilisations animales et agricoles', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('247', 'Agencements et amÃ©nagements du matÃ©riel', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('248', 'Autres matÃ©riels', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('249', 'MatÃ©riel en cours', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 25 - AVANCES ET ACOMPTES SUR IMMOBILISATIONS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('25', 'AVANCES ET ACOMPTES VERSÃ‰S SUR IMMOBILISATIONS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('251', 'Avances et acomptes versÃ©s sur immobilisations incorporelles', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('252', 'Avances et acomptes versÃ©s sur immobilisations corporelles', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 26 - TITRES DE PARTICIPATION
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('26', 'TITRES DE PARTICIPATION', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('261', 'Titres de participation dans des sociÃ©tÃ©s du groupe', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('262', 'Titres de participation dans des sociÃ©tÃ©s hors groupe', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('263', 'Titres de participation dans des organismes professionnels', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('265', 'Participations dans des sociÃ©tÃ©s en participation', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('266', 'Parts dans des GIE', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('268', 'Autres titres de participation', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 27 - AUTRES IMMOBILISATIONS FINANCIÃˆRES
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('27', 'AUTRES IMMOBILISATIONS FINANCIÃˆRES', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('271', 'PrÃªts et crÃ©ances non commerciales', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('2711', 'PrÃªts participatifs', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2712', 'PrÃªts aux associÃ©s', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2713', 'Billets de fonds', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2714', 'PrÃªts au personnel', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2718', 'Autres prÃªts et crÃ©ances', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('272', 'PrÃªts au personnel', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('273', 'CrÃ©ances sur l''Ã‰tat', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('274', 'Titres immobilisÃ©s', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('2741', 'Titres immobilisÃ©s de l''activitÃ© de portefeuille', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2742', 'Autres titres immobilisÃ©s', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('275', 'DÃ©pÃ´ts et cautionnements versÃ©s', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('2751', 'DÃ©pÃ´ts', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2752', 'Cautionnements', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('276', 'IntÃ©rÃªts courus', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('2761', 'IntÃ©rÃªts courus sur prÃªts et crÃ©ances non commerciales', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2762', 'IntÃ©rÃªts courus sur prÃªts au personnel', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2763', 'IntÃ©rÃªts courus sur crÃ©ances sur l''Ã‰tat', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2764', 'IntÃ©rÃªts courus sur titres immobilisÃ©s', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2765', 'IntÃ©rÃªts courus sur dÃ©pÃ´ts et cautionnements', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2767', 'CrÃ©ances rattachÃ©es Ã  des participations', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('2768', 'IntÃ©rÃªts courus sur crÃ©ances rattachÃ©es Ã  des participations', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('277', 'CrÃ©ances rattachÃ©es Ã  des participations (groupe)', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('278', 'CrÃ©ances rattachÃ©es Ã  des participations (hors groupe)', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 28 - AMORTISSEMENTS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('28', 'AMORTISSEMENTS', 'ASSET', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('280', 'Amortissements des charges immobilisÃ©es', 'ASSET', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('2801', 'Amortissements des frais d''Ã©tablissement', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2802', 'Amortissements des charges Ã  rÃ©partir', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2806', 'Amortissements des primes de remboursement des obligations', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('281', 'Amortissements des immobilisations incorporelles', 'ASSET', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('2811', 'Amortissements des frais de recherche et dÃ©veloppement', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2812', 'Amortissements des brevets, licences, concessions', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2813', 'Amortissements des logiciels et sites internet', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2815', 'Amortissements du fonds commercial', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2816', 'Amortissements du droit au bail', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2817', 'Amortissements des investissements de crÃ©ation', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2818', 'Amortissements des autres droits et valeurs incorporels', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('282', 'Amortissements des terrains', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('283', 'Amortissements des bÃ¢timents, installations techniques', 'ASSET', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('2831', 'Amortissements des bÃ¢timents industriels', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2832', 'Amortissements des bÃ¢timents administratifs et commerciaux', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2833', 'Amortissements des ouvrages d''infrastructure', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2834', 'Amortissements des installations techniques', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2835', 'Amortissements des amÃ©nagements de bureaux', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2838', 'Amortissements des autres bÃ¢timents', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('284', 'Amortissements du matÃ©riel', 'ASSET', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('2841', 'Amortissements du matÃ©riel et outillage industriel', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2842', 'Amortissements du matÃ©riel et outillage agricole', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2843', 'Amortissements du matÃ©riel d''emballage', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2844', 'Amortissements du matÃ©riel et mobilier', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2845', 'Amortissements du matÃ©riel de transport', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2846', 'Amortissements des immobilisations animales et agricoles', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('2848', 'Amortissements des autres matÃ©riels', 'ASSET', 4, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- 29 - PROVISIONS POUR DÃ‰PRÃ‰CIATION
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('29', 'PROVISIONS POUR DÃ‰PRÃ‰CIATION', 'ASSET', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('291', 'Provisions pour dÃ©prÃ©ciation des immobilisations incorporelles', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('292', 'Provisions pour dÃ©prÃ©ciation des terrains', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('293', 'Provisions pour dÃ©prÃ©ciation des bÃ¢timents', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('294', 'Provisions pour dÃ©prÃ©ciation du matÃ©riel', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('296', 'Provisions pour dÃ©prÃ©ciation des titres de participation', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('297', 'Provisions pour dÃ©prÃ©ciation des autres immobilisations financiÃ¨res', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- ============================================================================
-- CLASSE 3 : COMPTES DE STOCKS
-- ============================================================================

INSERT INTO accounts (account_number, account_name, account_type, account_level, normal_balance, financial_statement) VALUES
    ('3', 'COMPTES DE STOCKS', 'ASSET', 1, 'DEBIT', 'BALANCE_SHEET');

-- 31 - MARCHANDISES
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('31', 'MARCHANDISES', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('311', 'Marchandises A', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('312', 'Marchandises B', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('318', 'Autres marchandises', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 32 - MATIÃˆRES PREMIÃˆRES ET FOURNITURES LIÃ‰ES
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('32', 'MATIÃˆRES PREMIÃˆRES ET FOURNITURES LIÃ‰ES', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('321', 'MatiÃ¨res A', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('322', 'MatiÃ¨res B', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('323', 'Fournitures (A, B, C...)', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 33 - AUTRES APPROVISIONNEMENTS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('33', 'AUTRES APPROVISIONNEMENTS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('331', 'MatiÃ¨res consommables', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('332', 'Fournitures d''atelier et d''usine', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('333', 'Fournitures de magasin', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('334', 'Fournitures de bureau', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('335', 'Emballages perdus', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('336', 'Emballages rÃ©cupÃ©rables non identifiables', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('337', 'Emballages Ã  usage mixte', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('338', 'Autres matiÃ¨res', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 34 - PRODUITS EN COURS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('34', 'PRODUITS EN COURS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('341', 'Produits en cours', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('342', 'Travaux en cours', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('343', 'Produits intermÃ©diaires en cours', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('344', 'Produits rÃ©siduels en cours', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('345', 'Services en cours', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 35 - SERVICES EN COURS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('35', 'SERVICES EN COURS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('351', 'Ã‰tudes en cours', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('352', 'Prestations de services en cours', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 36 - PRODUITS FINIS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('36', 'PRODUITS FINIS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('361', 'Produits finis A', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('362', 'Produits finis B', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('368', 'Autres produits finis', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 37 - PRODUITS INTERMÃ‰DIAIRES ET RÃ‰SIDUELS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('37', 'PRODUITS INTERMÃ‰DIAIRES ET RÃ‰SIDUELS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('371', 'Produits intermÃ©diaires', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('372', 'Produits rÃ©siduels', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 38 - STOCKS EN COURS DE ROUTE, EN CONSIGNATION OU EN DÃ‰PÃ”T
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('38', 'STOCKS EN COURS DE ROUTE, EN CONSIGNATION OU EN DÃ‰PÃ”T', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('381', 'Marchandises en cours de route', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('382', 'MatiÃ¨res premiÃ¨res en cours de route', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('383', 'Autres approvisionnements en cours de route', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('386', 'Produits finis en cours de route', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('387', 'Stocks en consignation ou en dÃ©pÃ´t', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 39 - DÃ‰PRÃ‰CIATIONS DES STOCKS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('39', 'DÃ‰PRÃ‰CIATIONS DES STOCKS', 'ASSET', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('391', 'DÃ©prÃ©ciations des marchandises', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('392', 'DÃ©prÃ©ciations des matiÃ¨res premiÃ¨res', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('393', 'DÃ©prÃ©ciations des autres approvisionnements', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('394', 'DÃ©prÃ©ciations des produits en cours', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('395', 'DÃ©prÃ©ciations des services en cours', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('396', 'DÃ©prÃ©ciations des produits finis', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('397', 'DÃ©prÃ©ciations des produits intermÃ©diaires et rÃ©siduels', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('398', 'DÃ©prÃ©ciations des stocks en cours de route', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- ============================================================================
-- CLASSE 4 : COMPTES DE TIERS
-- ============================================================================

INSERT INTO accounts (account_number, account_name, account_type, account_level, normal_balance, financial_statement) VALUES
    ('4', 'COMPTES DE TIERS', 'ASSET', 1, 'DEBIT', 'BALANCE_SHEET');

-- 40 - FOURNISSEURS ET COMPTES RATTACHÃ‰S
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('40', 'FOURNISSEURS ET COMPTES RATTACHÃ‰S', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('401', 'Fournisseurs', 'LIABILITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('4011', 'Fournisseurs locaux', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4012', 'Fournisseurs groupe', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4013', 'Fournisseurs hors groupe', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4017', 'Fournisseurs retenues de garantie', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('402', 'Fournisseurs, effets Ã  payer', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('408', 'Fournisseurs, factures non parvenues', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('409', 'Fournisseurs dÃ©biteurs', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('4091', 'Fournisseurs, avances et acomptes versÃ©s', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('4092', 'Fournisseurs, crÃ©ances pour emballages Ã  rendre', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('4098', 'Rabais, remises et ristournes Ã  obtenir et autres avoirs', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 41 - CLIENTS ET COMPTES RATTACHÃ‰S
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('41', 'CLIENTS ET COMPTES RATTACHÃ‰S', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('411', 'Clients', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('4111', 'Clients locaux', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('4112', 'Clients groupe', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('4113', 'Clients hors groupe', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('4114', 'Clients, Ã‰tat et organismes internationaux', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('4117', 'Clients retenues de garantie', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('412', 'Clients, effets Ã  recevoir en portefeuille', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('413', 'Clients, effets Ã  l''encaissement', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('414', 'Clients, effets escomptÃ©s et non Ã©chus', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('415', 'Clients, effets impayÃ©s', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('416', 'CrÃ©ances clients litigieuses ou douteuses', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('418', 'Clients, produits Ã  recevoir', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('419', 'Clients crÃ©diteurs', 'LIABILITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('4191', 'Clients, avances et acomptes reÃ§us', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4192', 'Clients, dettes pour emballages consignÃ©s', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4198', 'Rabais, remises et ristournes Ã  accorder', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- 42 - PERSONNEL
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('42', 'PERSONNEL', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('421', 'Personnel, avances et acomptes', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('422', 'Personnel, rÃ©munÃ©rations dues', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('423', 'Personnel, oppositions, saisies-arrÃªts', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('424', 'Personnel, oeuvres sociales internes', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('425', 'ReprÃ©sentants du personnel', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('426', 'Personnel, participation aux bÃ©nÃ©fices', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('427', 'Personnel, dÃ©pÃ´ts reÃ§us', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('428', 'Personnel, charges Ã  payer et produits Ã  recevoir', 'LIABILITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('4281', 'Dettes provisionnÃ©es pour congÃ©s Ã  payer', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4286', 'Autres charges Ã  payer', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4287', 'Produits Ã  recevoir', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 43 - ORGANISMES SOCIAUX
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('43', 'ORGANISMES SOCIAUX', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('431', 'SÃ©curitÃ© sociale', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('432', 'Caisses de retraite obligatoire', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('433', 'Autres organismes sociaux', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('434', 'MutualitÃ©', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('438', 'Organismes sociaux, charges Ã  payer et produits Ã  recevoir', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- 44 - Ã‰TAT ET COLLECTIVITÃ‰S PUBLIQUES
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('44', 'Ã‰TAT ET COLLECTIVITÃ‰S PUBLIQUES', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('441', 'Ã‰tat, impÃ´t sur les bÃ©nÃ©fices', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('442', 'Ã‰tat, autres impÃ´ts et taxes', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('443', 'Ã‰tat, TVA facturÃ©e', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('444', 'Ã‰tat, TVA due ou crÃ©dit de TVA', 'LIABILITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('4441', 'Ã‰tat, TVA due', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4449', 'Ã‰tat, crÃ©dit de TVA', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('445', 'Ã‰tat, TVA rÃ©cupÃ©rable', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('4451', 'TVA rÃ©cupÃ©rable sur immobilisations', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('4452', 'TVA rÃ©cupÃ©rable sur achats', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('4453', 'TVA rÃ©cupÃ©rable sur transports', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('4454', 'TVA rÃ©cupÃ©rable sur services', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('446', 'Ã‰tat, autres taxes sur le chiffre d''affaires', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('447', 'Ã‰tat, impÃ´ts retenus Ã  la source', 'LIABILITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('4471', 'ImpÃ´t sur les revenus salariaux', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4472', 'ImpÃ´t sur les revenus des crÃ©ances', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4473', 'ImpÃ´t sur les revenus des valeurs mobiliÃ¨res', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4478', 'Autres impÃ´ts retenus Ã  la source', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('448', 'Ã‰tat, charges Ã  payer et produits Ã  recevoir', 'LIABILITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('4481', 'Charges Ã  payer sur impÃ´ts et taxes', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4486', 'Charges Ã  payer sur subventions d''exploitation', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4487', 'Produits Ã  recevoir sur subventions', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('449', 'Ã‰tat, crÃ©ances et dettes diverses', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('4491', 'Ã‰tat, obligations cautionnÃ©es', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4492', 'Ã‰tat, avances et acomptes versÃ©s sur impÃ´ts', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('4493', 'Ã‰tat, fonds de dotation Ã  recevoir', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('4494', 'Ã‰tat, subventions Ã  recevoir', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('4495', 'Ã‰tat, fonds rÃ©glementÃ©s, provision', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4496', 'Ã‰tat, crÃ©ances diverses', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('4499', 'Ã‰tat, dettes diverses', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- 45 - ORGANISMES INTERNATIONAUX
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('45', 'ORGANISMES INTERNATIONAUX', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('451', 'OpÃ©rations avec les organismes africains', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('452', 'OpÃ©rations avec les autres organismes internationaux', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('458', 'Organismes internationaux, charges Ã  payer et produits Ã  recevoir', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 46 - ASSOCIÃ‰S ET GROUPE
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('46', 'ASSOCIÃ‰S ET GROUPE', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('461', 'AssociÃ©s, opÃ©rations sur le capital', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('4611', 'Actionnaires, capital souscrit et appelÃ© non versÃ©', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('4612', 'Actionnaires, versements reÃ§us sur augmentation de capital', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4613', 'Actionnaires, capital Ã  rembourser', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4614', 'AssociÃ©s, apport en nature', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('4615', 'AssociÃ©s, apport en numÃ©raire', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('4616', 'AssociÃ©s, apport en industrie', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('4617', 'Actionnaires dÃ©faillants', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('462', 'AssociÃ©s, comptes courants', 'LIABILITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('4621', 'Comptes courants des associÃ©s (principal)', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4626', 'Comptes courants des associÃ©s (intÃ©rÃªts courus)', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('463', 'AssociÃ©s, opÃ©rations faites en commun', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('464', 'AssociÃ©s, dividendes Ã  payer', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('465', 'AssociÃ©s, titres Ã  rembourser', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('466', 'Groupe, comptes courants', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('467', 'Actionnaires, restant dÃ» sur capital appelÃ©', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 47 - DÃ‰BITEURS ET CRÃ‰DITEURS DIVERS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('47', 'DÃ‰BITEURS ET CRÃ‰DITEURS DIVERS', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('471', 'Comptes d''attente dÃ©biteurs', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('472', 'Comptes d''attente crÃ©diteurs', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('473', 'Recettes Ã  classer', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('474', 'DÃ©penses Ã  classer', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('475', 'CrÃ©ances sur travaux non encore facturables', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('476', 'Charges constatÃ©es d''avance', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('477', 'Produits constatÃ©s d''avance', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('478', 'Ã‰carts de conversion - Actif', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('4781', 'Diminution des crÃ©ances', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('4782', 'Augmentation des dettes', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('479', 'Ã‰carts de conversion - Passif', 'LIABILITY', 3, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('4791', 'Augmentation des crÃ©ances', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('4792', 'Diminution des dettes', 'LIABILITY', 4, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- 48 - CRÃ‰ANCES ET DETTES HORS ACTIVITÃ‰ ORDINAIRE
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('48', 'CRÃ‰ANCES ET DETTES HAO', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('481', 'Fournisseurs d''investissements', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('482', 'Fournisseurs d''investissements, effets Ã  payer', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('483', 'Fournisseurs d''investissements, factures non parvenues', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('484', 'Autres dettes HAO', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('485', 'CrÃ©ances sur cessions d''immobilisations', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('486', 'CrÃ©ances sur cessions de titres de placement', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('488', 'Autres crÃ©ances HAO', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 49 - DÃ‰PRÃ‰CIATIONS ET PROVISIONS POUR RISQUES Ã€ COURT TERME
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('49', 'DÃ‰PRÃ‰CIATIONS ET PROVISIONS POUR RISQUES Ã€ CT', 'ASSET', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('490', 'DÃ©prÃ©ciations des comptes fournisseurs', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('491', 'DÃ©prÃ©ciations des comptes clients', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('492', 'DÃ©prÃ©ciations des comptes personnel', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('493', 'DÃ©prÃ©ciations des comptes organismes sociaux', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('494', 'DÃ©prÃ©ciations des comptes Ã‰tat et collectivitÃ©s publiques', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('495', 'DÃ©prÃ©ciations des comptes organismes internationaux', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('496', 'DÃ©prÃ©ciations des comptes associÃ©s et groupe', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('497', 'DÃ©prÃ©ciations des comptes dÃ©biteurs divers', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('498', 'DÃ©prÃ©ciations des comptes crÃ©ances HAO', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('499', 'Provisions pour risques Ã  court terme', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- ============================================================================
-- CLASSE 5 : COMPTES DE TRÃ‰SORERIE
-- ============================================================================

INSERT INTO accounts (account_number, account_name, account_type, account_level, normal_balance, financial_statement) VALUES
    ('5', 'COMPTES DE TRÃ‰SORERIE', 'ASSET', 1, 'DEBIT', 'BALANCE_SHEET');

-- 50 - TITRES DE PLACEMENT
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('50', 'TITRES DE PLACEMENT', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('501', 'Titres du TrÃ©sor et bons de caisse Ã  court terme', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('502', 'Actions', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('503', 'Obligations', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('504', 'Bons de souscription', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('505', 'Titres nÃ©gociables hors rÃ©gion', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('506', 'IntÃ©rÃªts courus sur titres de placement', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('508', 'Autres titres de placement', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 51 - VALEURS Ã€ ENCAISSER
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('51', 'VALEURS Ã€ ENCAISSER', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('511', 'Effets Ã  encaisser', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('512', 'Effets Ã  l''encaissement', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('513', 'ChÃ¨ques Ã  encaisser', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('514', 'ChÃ¨ques Ã  l''encaissement', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('515', 'Cartes de crÃ©dit Ã  encaisser', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('518', 'Autres valeurs Ã  l''encaissement', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('519', 'Valeurs Ã  l''encaissement impayÃ©es', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 52 - BANQUES
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('52', 'BANQUES', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('521', 'Banques locales', 'ASSET', 3, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('5211', 'Banque A', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('5212', 'Banque B', 'ASSET', 4, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('522', 'Banques autres Ã‰tats rÃ©gion', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('523', 'Banques autres Ã‰tats hors rÃ©gion', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('524', 'Agences de transfert', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('525', 'Ã‰tablissements financiers, crÃ©dit de mobilisation', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('526', 'Ã‰tablissements financiers, crÃ©dit de trÃ©sorerie', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 53 - Ã‰TABLISSEMENTS FINANCIERS ET ASSIMILÃ‰S
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('53', 'Ã‰TABLISSEMENTS FINANCIERS ET ASSIMILÃ‰S', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('531', 'ChÃ¨ques postaux', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('532', 'TrÃ©sor', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('533', 'Organismes financiers de microfinance', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('534', 'Mobile money', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('538', 'Autres Ã©tablissements financiers', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 54 - INSTRUMENTS DE TRÃ‰SORERIE
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('54', 'INSTRUMENTS DE TRÃ‰SORERIE', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('541', 'Options de taux d''intÃ©rÃªt', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('542', 'Options de taux de change', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('543', 'Options de taux boursiers', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('544', 'Instruments de gestion des risques de taux d''intÃ©rÃªt', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('545', 'Instruments de gestion des risques de change', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('546', 'Instruments de gestion des risques de cours boursiers', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('548', 'Autres instruments de trÃ©sorerie', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 56 - BANQUES, CRÃ‰DITS DE TRÃ‰SORERIE ET D'ESCOMPTE
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('56', 'BANQUES, CRÃ‰DITS DE TRÃ‰SORERIE ET D''ESCOMPTE', 'LIABILITY', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('561', 'CrÃ©dits de trÃ©sorerie', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('564', 'Escompte de crÃ©dits ordinaires', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('565', 'Escompte de crÃ©dits de campagne', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('566', 'Banques, dÃ©couverts', 'LIABILITY', 3, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- 57 - CAISSE
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('57', 'CAISSE', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('571', 'Caisse siÃ¨ge social', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('572', 'Caisse succursale A', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('573', 'Caisse succursale B', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('574', 'Caisse succursale C', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('578', 'Autres caisses', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 58 - RÃ‰GIES D'AVANCES, ACCRÃ‰DITIFS ET VIREMENTS INTERNES
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('58', 'RÃ‰GIES D''AVANCES, ACCRÃ‰DITIFS ET VIREMENTS INTERNES', 'ASSET', 2, FALSE, 'DEBIT', 'BALANCE_SHEET'),
    ('581', 'RÃ©gies d''avances', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('582', 'AccrÃ©ditifs', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('585', 'Virements de fonds', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET'),
    ('588', 'Autres rÃ©gies', 'ASSET', 3, TRUE, 'DEBIT', 'BALANCE_SHEET');

-- 59 - DÃ‰PRÃ‰CIATIONS DES TITRES DE PLACEMENT
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('59', 'DÃ‰PRÃ‰CIATIONS DES TITRES DE PLACEMENT', 'ASSET', 2, FALSE, 'CREDIT', 'BALANCE_SHEET'),
    ('591', 'DÃ©prÃ©ciations des titres du TrÃ©sor et bons de caisse', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('592', 'DÃ©prÃ©ciations des actions', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('593', 'DÃ©prÃ©ciations des obligations', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('594', 'DÃ©prÃ©ciations des bons de souscription', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET'),
    ('598', 'DÃ©prÃ©ciations des autres titres de placement', 'ASSET', 3, TRUE, 'CREDIT', 'BALANCE_SHEET');

-- ============================================================================
-- CLASSE 6 : COMPTES DE CHARGES
-- ============================================================================

INSERT INTO accounts (account_number, account_name, account_type, account_level, normal_balance, financial_statement) VALUES
    ('6', 'COMPTES DE CHARGES', 'EXPENSE', 1, 'DEBIT', 'INCOME_STATEMENT');

-- 60 - ACHATS ET VARIATIONS DE STOCKS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('60', 'ACHATS ET VARIATIONS DE STOCKS', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('601', 'Achats de marchandises', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6011', 'Achats de marchandises dans la rÃ©gion', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6012', 'Achats de marchandises hors rÃ©gion', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6013', 'Achats de marchandises importÃ©es', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6019', 'Rabais, remises, ristournes obtenus (non ventilÃ©s)', 'EXPENSE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('602', 'Achats de matiÃ¨res premiÃ¨res et fournitures liÃ©es', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6021', 'Achats de matiÃ¨res premiÃ¨res dans la rÃ©gion', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6022', 'Achats de matiÃ¨res premiÃ¨res hors rÃ©gion', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6023', 'Achats de matiÃ¨res premiÃ¨res importÃ©es', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6024', 'Achats de fournitures liÃ©es', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6029', 'Rabais, remises, ristournes obtenus (non ventilÃ©s)', 'EXPENSE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('603', 'Variations des stocks de biens achetÃ©s', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6031', 'Variations des stocks de marchandises', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6032', 'Variations des stocks de matiÃ¨res premiÃ¨res', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6033', 'Variations des stocks d''autres approvisionnements', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('604', 'Achats stockÃ©s de matiÃ¨res et fournitures consommables', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6041', 'MatiÃ¨res consommables', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6042', 'MatiÃ¨res combustibles', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6043', 'Produits d''entretien', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6044', 'Fournitures d''atelier et d''usine', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6045', 'Fournitures de magasin', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6046', 'Fournitures de bureau', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6047', 'Achats d''emballages', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6049', 'Rabais, remises, ristournes obtenus (non ventilÃ©s)', 'EXPENSE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('605', 'Autres achats', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6051', 'Fournitures non stockables - eau', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6052', 'Fournitures non stockables - Ã©lectricitÃ©', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6053', 'Fournitures non stockables - autres Ã©nergies', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6054', 'Fournitures d''entretien non stockables', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6055', 'Fournitures de bureau non stockables', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6056', 'Achats de petits matÃ©riels et outillages', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6057', 'Achats d''Ã©tudes et de prestations de services', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6058', 'Achats de travaux, matÃ©riels et Ã©quipements', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6059', 'Rabais, remises, ristournes obtenus (non ventilÃ©s)', 'EXPENSE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('608', 'Achats d''emballages', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6081', 'Emballages perdus', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6082', 'Emballages rÃ©cupÃ©rables non identifiables', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6089', 'Rabais, remises, ristournes obtenus (non ventilÃ©s)', 'EXPENSE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT');

-- 61 - TRANSPORTS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('61', 'TRANSPORTS', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('611', 'Transports sur achats', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('612', 'Transports sur ventes', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('613', 'Transports pour le compte de tiers', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('614', 'Transports du personnel', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('616', 'Transports de plis', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('618', 'Autres frais de transport', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT');

-- 62 - SERVICES EXTÃ‰RIEURS A
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('62', 'SERVICES EXTÃ‰RIEURS A', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('621', 'Sous-traitance gÃ©nÃ©rale', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('622', 'Locations et charges locatives', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6221', 'Locations de terrains', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6222', 'Locations de bÃ¢timents', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6223', 'Locations de matÃ©riel et outillage', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6224', 'Malis sur emballages', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6225', 'Locations d''emballages', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6228', 'Locations et charges locatives diverses', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('623', 'Redevances de crÃ©dit-bail et contrats assimilÃ©s', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6232', 'CrÃ©dit-bail immobilier', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6233', 'CrÃ©dit-bail mobilier', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6238', 'Autres redevances de contrats assimilÃ©s', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('624', 'Entretien, rÃ©parations et maintenance', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6241', 'Entretien et rÃ©parations des biens immobiliers', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6242', 'Entretien et rÃ©parations des biens mobiliers', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6243', 'Maintenance', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6248', 'Autres entretiens et rÃ©parations', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('625', 'Primes d''assurance', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6251', 'Assurances multirisques', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6252', 'Assurances matÃ©riel de transport', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6253', 'Assurances risques d''exploitation', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6254', 'Assurances responsabilitÃ© du producteur', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6255', 'Assurances insolvabilitÃ© clients', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6256', 'Assurances transport sur achats', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6257', 'Assurances transport sur ventes', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6258', 'Autres primes d''assurance', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('626', 'Ã‰tudes, recherches et documentation', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6261', 'Ã‰tudes et recherches', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6262', 'Documentation gÃ©nÃ©rale', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6263', 'Documentation technique', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('627', 'PublicitÃ©, publications, relations publiques', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6271', 'Annonces et insertions', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6272', 'Catalogues et imprimÃ©s', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6273', 'Ã‰chantillons', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6274', 'Foires et expositions', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6275', 'Publications', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6276', 'Cadeaux Ã  la clientÃ¨le', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6277', 'Frais de colloques, sÃ©minaires, confÃ©rences', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6278', 'Autres charges de publicitÃ© et relations publiques', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('628', 'Frais de tÃ©lÃ©communications', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6281', 'Frais de tÃ©lÃ©phone', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6282', 'Frais de tÃ©lex et de tÃ©lÃ©copie', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6283', 'Frais d''internet', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6288', 'Autres frais de tÃ©lÃ©communications', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT');

-- 63 - SERVICES EXTÃ‰RIEURS B
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('63', 'SERVICES EXTÃ‰RIEURS B', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('631', 'Frais bancaires', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6311', 'Frais sur titres', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6312', 'Frais sur effets', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6313', 'Locations de coffres', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6314', 'Commissions sur cartes de crÃ©dit', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6315', 'Commissions sur opÃ©rations de bourse', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6316', 'Frais d''Ã©mission d''emprunts', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6318', 'Autres frais bancaires', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('632', 'RÃ©munÃ©rations d''intermÃ©diaires et de conseils', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6321', 'Commissions et courtages sur achats', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6322', 'Commissions et courtages sur ventes', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6323', 'RÃ©munÃ©rations des transitaires', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6324', 'Honoraires', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6325', 'Frais d''actes et de contentieux', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6326', 'Frais d''expertise comptable', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6327', 'Frais d''audit et de rÃ©vision', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6328', 'Autres rÃ©munÃ©rations d''intermÃ©diaires et de conseils', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('633', 'Redevances pour brevets, licences, logiciels et valeurs similaires', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6331', 'Redevances pour brevets', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6332', 'Redevances pour licences', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6333', 'Redevances pour logiciels', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6334', 'Redevances pour marques', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6338', 'Autres redevances', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('634', 'Redevances pour brevets, licences, concessions', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('635', 'Cotisations', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6351', 'Cotisations aux groupements professionnels', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6358', 'Cotisations diverses', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('637', 'RÃ©munÃ©rations du personnel extÃ©rieur Ã  l''entreprise', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6371', 'Personnel intÃ©rimaire', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6372', 'Personnel dÃ©tachÃ© ou prÃªtÃ© Ã  l''entreprise', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('638', 'Autres charges externes', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6381', 'Frais de recrutement de personnel', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6382', 'Frais de dÃ©mÃ©nagement', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6383', 'RÃ©ceptions', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6384', 'Missions', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6385', 'DÃ©placements', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6388', 'Autres charges externes diverses', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT');

-- 64 - IMPÃ”TS ET TAXES
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('64', 'IMPÃ”TS ET TAXES', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('641', 'ImpÃ´ts et taxes directs', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6411', 'ImpÃ´ts fonciers et taxes annexes', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6412', 'Patentes, licences et taxes annexes', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6413', 'Taxes sur appointements et salaires', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6414', 'Taxes d''apprentissage', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6415', 'Formation professionnelle continue', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6418', 'Autres impÃ´ts et taxes directs', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('642', 'ImpÃ´ts et taxes indirects', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('645', 'ImpÃ´ts et taxes sur les vÃ©hicules', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('646', 'Droits d''enregistrement', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('647', 'PÃ©nalitÃ©s et amendes fiscales', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('648', 'Autres impÃ´ts et taxes', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT');

-- 65 - AUTRES CHARGES
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('65', 'AUTRES CHARGES', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('651', 'Pertes sur crÃ©ances clients', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('652', 'Quote-part de rÃ©sultat sur opÃ©rations faites en commun', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('653', 'Quote-part de rÃ©sultat annulÃ©e sur exÃ©cution partielle de contrats pluri-exercices', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('654', 'Valeur comptable des cessions courantes d''immobilisations', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('658', 'Charges diverses', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT');

-- 66 - CHARGES DE PERSONNEL
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('66', 'CHARGES DE PERSONNEL', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('661', 'RÃ©munÃ©rations directes versÃ©es au personnel national', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('662', 'RÃ©munÃ©rations directes versÃ©es au personnel non national', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('663', 'IndemnitÃ©s de logement', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('664', 'IndemnitÃ©s de reprÃ©sentation', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('665', 'IndemnitÃ©s d''expatriation', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('666', 'RÃ©munÃ©rations et primes des administrateurs', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('667', 'Charges sociales', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6671', 'Charges sociales sur rÃ©munÃ©rations du personnel national', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6672', 'Charges sociales sur rÃ©munÃ©rations du personnel non national', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('668', 'Autres charges de personnel', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6681', 'Versements aux syndicats et comitÃ©s d''entreprise', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6682', 'Frais de formation', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6683', 'MÃ©decine du travail et pharmacie', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6684', 'Allocations aux oeuvres sociales', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6688', 'Autres charges sociales', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT');

-- 67 - FRAIS FINANCIERS ET CHARGES ASSIMILÃ‰ES
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('67', 'FRAIS FINANCIERS ET CHARGES ASSIMILÃ‰ES', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('671', 'IntÃ©rÃªts des emprunts', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('672', 'IntÃ©rÃªts dans loyers de crÃ©dit-bail', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('673', 'Escomptes accordÃ©s', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('674', 'Autres intÃ©rÃªts', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('676', 'Pertes de change', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('677', 'Pertes sur cessions de titres de placement', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('678', 'Pertes sur risques financiers', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('679', 'Charges financiÃ¨res diverses', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT');

-- 68 - DOTATIONS AUX AMORTISSEMENTS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('68', 'DOTATIONS AUX AMORTISSEMENTS', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('681', 'Dotations aux amortissements d''exploitation', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6811', 'Dotations aux amortissements des charges immobilisÃ©es', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6812', 'Dotations aux amortissements des immobilisations incorporelles', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6813', 'Dotations aux amortissements des immobilisations corporelles', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('687', 'Dotations aux amortissements Ã  caractÃ¨re financier', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT');

-- 69 - DOTATIONS AUX PROVISIONS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('69', 'DOTATIONS AUX PROVISIONS', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('691', 'Dotations aux provisions d''exploitation', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6911', 'Dotations aux provisions pour risques et charges', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6912', 'Dotations aux provisions pour grosses rÃ©parations', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6913', 'Dotations aux provisions pour dÃ©prÃ©ciation des immobilisations', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6914', 'Dotations aux provisions pour dÃ©prÃ©ciation des stocks', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6915', 'Dotations aux provisions pour dÃ©prÃ©ciation des crÃ©ances', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('697', 'Dotations aux provisions financiÃ¨res', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6971', 'Dotations aux provisions pour risques et charges financiers', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('6972', 'Dotations aux provisions pour dÃ©prÃ©ciation des titres', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT');

-- ============================================================================
-- CLASSE 7 : COMPTES DE PRODUITS
-- ============================================================================

INSERT INTO accounts (account_number, account_name, account_type, account_level, normal_balance, financial_statement) VALUES
    ('7', 'COMPTES DE PRODUITS', 'REVENUE', 1, 'CREDIT', 'INCOME_STATEMENT');

-- 70 - VENTES
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('70', 'VENTES', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
    ('701', 'Ventes de marchandises', 'REVENUE', 3, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7011', 'Ventes de marchandises dans la rÃ©gion', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7012', 'Ventes de marchandises hors rÃ©gion', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7013', 'Ventes de marchandises Ã  l''exportation', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('702', 'Ventes de produits finis', 'REVENUE', 3, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7021', 'Ventes de produits finis dans la rÃ©gion', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7022', 'Ventes de produits finis hors rÃ©gion', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7023', 'Ventes de produits finis Ã  l''exportation', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('703', 'Ventes de produits intermÃ©diaires', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('704', 'Ventes de produits rÃ©siduels', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('705', 'Travaux facturÃ©s', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('706', 'Services vendus', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('707', 'Produits accessoires', 'REVENUE', 3, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7071', 'Ports, emballages perdus et autres frais facturÃ©s', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7072', 'Commissions et courtages', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7073', 'Locations', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7074', 'Bonis sur reprises d''emballages consignÃ©s', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7075', 'Mise Ã  disposition de personnel', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7076', 'Redevances pour brevets, logiciels, licences', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7078', 'Autres produits accessoires', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT');

-- 71 - SUBVENTIONS D'EXPLOITATION
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('71', 'SUBVENTIONS D''EXPLOITATION', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
    ('711', 'Subventions d''exploitation reÃ§ues', 'REVENUE', 3, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7111', 'Ã‰tat', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7112', 'CollectivitÃ©s publiques', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7113', 'Organismes internationaux', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7114', 'Autres', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT');

-- 72 - PRODUCTION IMMOBILISÃ‰E
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('72', 'PRODUCTION IMMOBILISÃ‰E', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
    ('721', 'Immobilisations incorporelles', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('722', 'Immobilisations corporelles', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('726', 'Immobilisations financiÃ¨res', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT');

-- 73 - VARIATIONS DE STOCKS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('73', 'VARIATIONS DE STOCKS DE BIENS PRODUITS', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
    ('734', 'Variation des stocks de produits en cours', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('735', 'Variation des stocks de services en cours', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('736', 'Variation des stocks de produits finis', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('737', 'Variation des stocks de produits intermÃ©diaires et rÃ©siduels', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT');

-- 75 - AUTRES PRODUITS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('75', 'AUTRES PRODUITS', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
    ('752', 'Quote-part de rÃ©sultat sur opÃ©rations faites en commun', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('753', 'Quote-part de rÃ©sultat affÃ©rente aux opÃ©rations obtenues conjointement', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('754', 'Produits des cessions courantes d''immobilisations', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('758', 'Produits divers', 'REVENUE', 3, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7581', 'Jetons de prÃ©sence et autres rÃ©munÃ©rations d''administrateurs', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7582', 'IndemnitÃ©s d''assurances reÃ§ues', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7588', 'Autres produits divers', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT');

-- 77 - REVENUS FINANCIERS ET PRODUITS ASSIMILÃ‰S
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('77', 'REVENUS FINANCIERS ET PRODUITS ASSIMILÃ‰S', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
    ('771', 'IntÃ©rÃªts de prÃªts', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('772', 'Revenus de participations', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('773', 'Escomptes obtenus', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('774', 'Revenus de titres de placement', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('776', 'Gains de change', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('777', 'Gains sur cessions de titres de placement', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('778', 'Gains sur risques financiers', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('779', 'Revenus financiers divers', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT');

-- 79 - REPRISES DE PROVISIONS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('79', 'REPRISES DE PROVISIONS', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
    ('791', 'Reprises de provisions d''exploitation', 'REVENUE', 3, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7911', 'Reprises sur provisions pour risques et charges', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7912', 'Reprises sur provisions pour grosses rÃ©parations', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7913', 'Reprises sur provisions pour dÃ©prÃ©ciation des immobilisations', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7914', 'Reprises sur provisions pour dÃ©prÃ©ciation des stocks', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7915', 'Reprises sur provisions pour dÃ©prÃ©ciation des crÃ©ances', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('797', 'Reprises de provisions financiÃ¨res', 'REVENUE', 3, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7971', 'Reprises sur provisions pour risques et charges financiers', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('7972', 'Reprises sur provisions pour dÃ©prÃ©ciation des titres', 'REVENUE', 4, TRUE, 'CREDIT', 'INCOME_STATEMENT');

-- ============================================================================
-- CLASSE 8 : COMPTES DES AUTRES CHARGES ET AUTRES PRODUITS
-- ============================================================================

INSERT INTO accounts (account_number, account_name, account_type, account_level, normal_balance, financial_statement) VALUES
    ('8', 'COMPTES DES AUTRES CHARGES ET AUTRES PRODUITS', 'OTHER', 1, 'DEBIT', 'INCOME_STATEMENT');

-- 81 - VALEURS COMPTABLES DES CESSIONS D'IMMOBILISATIONS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('81', 'VALEURS COMPTABLES DES CESSIONS D''IMMOBILISATIONS', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('811', 'Immobilisations incorporelles', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('812', 'Immobilisations corporelles', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('816', 'Immobilisations financiÃ¨res', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT');

-- 82 - PRODUITS DES CESSIONS D'IMMOBILISATIONS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('82', 'PRODUITS DES CESSIONS D''IMMOBILISATIONS', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
    ('821', 'Immobilisations incorporelles', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('822', 'Immobilisations corporelles', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('826', 'Immobilisations financiÃ¨res', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT');

-- 83 - CHARGES HORS ACTIVITÃ‰S ORDINAIRES
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('83', 'CHARGES HORS ACTIVITÃ‰S ORDINAIRES', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('831', 'Charges HAO constatÃ©es', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('834', 'Pertes sur crÃ©ances HAO', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('835', 'Dons et libÃ©ralitÃ©s accordÃ©s', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('836', 'Abandons de crÃ©ances consentis', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('838', 'Autres charges HAO', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT');

-- 84 - PRODUITS HORS ACTIVITÃ‰S ORDINAIRES
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('84', 'PRODUITS HORS ACTIVITÃ‰S ORDINAIRES', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
    ('841', 'Produits HAO constatÃ©s', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('845', 'Dons et libÃ©ralitÃ©s obtenus', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('846', 'Abandons de crÃ©ances obtenus', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('848', 'Autres produits HAO', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT');

-- 85 - DOTATIONS HAO
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('85', 'DOTATIONS HAO', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('851', 'Dotations aux provisions rÃ©glementÃ©es', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('852', 'Dotations aux amortissements HAO', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('853', 'Dotations aux provisions pour risques et charges HAO', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('854', 'Dotations aux provisions pour dÃ©prÃ©ciation HAO', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT');

-- 86 - REPRISES HAO
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('86', 'REPRISES HAO', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
    ('861', 'Reprises de provisions rÃ©glementÃ©es', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('862', 'Reprises d''amortissements HAO', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('863', 'Reprises de provisions pour risques et charges HAO', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('864', 'Reprises de provisions pour dÃ©prÃ©ciation HAO', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT');

-- 87 - PARTICIPATIONS DES TRAVAILLEURS
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('87', 'PARTICIPATIONS DES TRAVAILLEURS', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('871', 'Participation lÃ©gale aux bÃ©nÃ©fices', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('872', 'Participation contractuelle aux bÃ©nÃ©fices', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('873', 'Participation facultative aux bÃ©nÃ©fices', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('874', 'Participation des travailleurs aux fruits de l''expansion', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT');

-- 88 - SUBVENTIONS D'Ã‰QUILIBRE
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('88', 'SUBVENTIONS D''Ã‰QUILIBRE', 'REVENUE', 2, FALSE, 'CREDIT', 'INCOME_STATEMENT'),
    ('881', 'Ã‰tat', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('882', 'CollectivitÃ©s publiques', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('883', 'Organismes internationaux', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('884', 'Groupe', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT'),
    ('888', 'Autres', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT');

-- 89 - IMPÃ”TS SUR LE RÃ‰SULTAT
INSERT INTO accounts (account_number, account_name, account_type, account_level, is_detail, normal_balance, financial_statement) VALUES
    ('89', 'IMPÃ”TS SUR LE RÃ‰SULTAT', 'EXPENSE', 2, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('891', 'ImpÃ´ts sur les bÃ©nÃ©fices de l''exercice', 'EXPENSE', 3, FALSE, 'DEBIT', 'INCOME_STATEMENT'),
    ('8911', 'ActivitÃ©s exercÃ©es dans l''Ã‰tat', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('8912', 'ActivitÃ©s exercÃ©es dans les autres Ã‰tats de la rÃ©gion', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('8913', 'ActivitÃ©s exercÃ©es hors rÃ©gion', 'EXPENSE', 4, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('895', 'ImpÃ´t minimum forfaitaire (IMF)', 'EXPENSE', 3, TRUE, 'DEBIT', 'INCOME_STATEMENT'),
    ('899', 'DÃ©grÃ¨vements et annulations d''impÃ´ts sur rÃ©sultat', 'REVENUE', 3, TRUE, 'CREDIT', 'INCOME_STATEMENT');

-- ============================================================================
-- CRÃ‰ATION DES INDEX POUR OPTIMISATION
-- ============================================================================

CREATE INDEX idx_accounts_number ON accounts(account_number);
CREATE INDEX idx_accounts_type ON accounts(account_type);
CREATE INDEX idx_accounts_level ON accounts(account_level);
CREATE INDEX idx_accounts_is_detail ON accounts(is_detail);
CREATE INDEX idx_accounts_financial_statement ON accounts(financial_statement);
CREATE INDEX idx_accounts_active ON accounts(is_active);

-- ============================================================================
-- VUES UTILITAIRES
-- ============================================================================

-- Vue pour les comptes de dÃ©tail uniquement (utilisables pour les Ã©critures)
CREATE OR REPLACE VIEW v_detail_accounts AS
SELECT account_number, account_name, account_type, normal_balance
FROM accounts
WHERE is_detail = TRUE AND is_active = TRUE
ORDER BY account_number;

-- Vue pour le bilan
CREATE OR REPLACE VIEW v_balance_sheet_accounts AS
SELECT account_number, account_name, account_type, account_level, normal_balance
FROM accounts
WHERE financial_statement = 'BALANCE_SHEET' AND is_active = TRUE
ORDER BY account_number;

-- Vue pour le compte de rÃ©sultat
CREATE OR REPLACE VIEW v_income_statement_accounts AS
SELECT account_number, account_name, account_type, account_level, normal_balance
FROM accounts
WHERE financial_statement = 'INCOME_STATEMENT' AND is_active = TRUE
ORDER BY account_number;

-- Vue hiÃ©rarchique des comptes
CREATE OR REPLACE VIEW v_account_hierarchy AS
SELECT 
    a.account_number,
    a.account_name,
    a.account_type,
    a.account_level,
    a.is_detail,
    CASE 
        WHEN LENGTH(a.account_number) > 1 THEN LEFT(a.account_number, LENGTH(a.account_number) - 1)
        ELSE NULL
    END AS parent_account_number
FROM accounts a
WHERE a.is_active = TRUE
ORDER BY a.account_number;

-- Vue des comptes par classe
CREATE OR REPLACE VIEW v_accounts_by_class AS
SELECT 
    LEFT(account_number, 1) AS classe,
    CASE LEFT(account_number, 1)
        WHEN '1' THEN 'Ressources durables'
        WHEN '2' THEN 'Actif immobilisÃ©'
        WHEN '3' THEN 'Stocks'
        WHEN '4' THEN 'Tiers'
        WHEN '5' THEN 'TrÃ©sorerie'
        WHEN '6' THEN 'Charges'
        WHEN '7' THEN 'Produits'
        WHEN '8' THEN 'Autres charges et produits'
    END AS classe_libelle,
    COUNT(*) AS nombre_comptes,
    SUM(CASE WHEN is_detail THEN 1 ELSE 0 END) AS comptes_detail
FROM accounts
WHERE is_active = TRUE
GROUP BY LEFT(account_number, 1)
ORDER BY classe;

-- ============================================================================
-- FONCTION POUR OBTENIR LE CHEMIN COMPLET D'UN COMPTE
-- ============================================================================

CREATE OR REPLACE FUNCTION get_account_path(p_account_number VARCHAR)
RETURNS TEXT AS $$
DECLARE
    v_path TEXT := '';
    v_current VARCHAR;
    v_name VARCHAR;
BEGIN
    v_current := p_account_number;
    
    WHILE LENGTH(v_current) > 0 LOOP
        SELECT account_name INTO v_name FROM accounts WHERE account_number = v_current;
        IF v_name IS NOT NULL THEN
            IF v_path = '' THEN
                v_path := v_name;
            ELSE
                v_path := v_name || ' > ' || v_path;
            END IF;
        END IF;
        v_current := LEFT(v_current, LENGTH(v_current) - 1);
    END LOOP;
    
    RETURN v_path;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STATISTIQUES FINALES
-- ============================================================================

-- Affichage des statistiques du plan comptable
SELECT 
    'Plan Comptable OHADA' AS description,
    COUNT(*) AS total_comptes,
    SUM(CASE WHEN is_detail THEN 1 ELSE 0 END) AS comptes_imputables,
    SUM(CASE WHEN account_type = 'ASSET' THEN 1 ELSE 0 END) AS comptes_actif,
    SUM(CASE WHEN account_type = 'LIABILITY' THEN 1 ELSE 0 END) AS comptes_passif,
    SUM(CASE WHEN account_type = 'EQUITY' THEN 1 ELSE 0 END) AS comptes_capitaux,
    SUM(CASE WHEN account_type = 'EXPENSE' THEN 1 ELSE 0 END) AS comptes_charges,
    SUM(CASE WHEN account_type = 'REVENUE' THEN 1 ELSE 0 END) AS comptes_produits
FROM accounts;

-- Comptage par classe
SELECT * FROM v_accounts_by_class;
