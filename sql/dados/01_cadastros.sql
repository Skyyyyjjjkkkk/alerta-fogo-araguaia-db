-- =============================================================================
-- Alerta Fogo Araguaia | Dados de teste 01 - órgãos, localidades e usuários
-- -----------------------------------------------------------------------------
-- ATENÇÃO: todos os nomes, telefones, e-mails e coordenadas são FICTÍCIOS e
-- servem apenas para testar o banco. Nenhum dado pessoal real foi usado.
-- Senha de todos os usuários de teste: Teste@2026
-- =============================================================================
SET search_path TO alerta_fogo, public;

INSERT INTO orgao (id_orgao, nome, tipo, telefone, email) VALUES
    (1, 'Câmara Municipal de Bom Jesus do Araguaia',  'LEGISLATIVO',  '(66) 3000-0001', 'camara@exemplo.org'),
    (2, 'Secretaria Municipal de Meio Ambiente',      'AMBIENTAL',    '(66) 3000-0002', 'meioambiente@exemplo.org'),
    (3, 'Defesa Civil Municipal',                     'DEFESA_CIVIL', '(66) 3000-0003', 'defesacivil@exemplo.org'),
    (4, 'Brigada Municipal de Combate a Incêndios',    'BRIGADA',      '(66) 3000-0004', 'brigada.municipal@exemplo.org'),
    (5, 'Brigada Comunitária do Araguaia',            'BRIGADA',      '(66) 99000-0005', NULL);

INSERT INTO localidade (id_localidade, nome, tipo, latitude, longitude) VALUES
    (1, 'Centro',                     'BAIRRO',       -11.985000, -51.503000),
    (2, 'Jardim das Palmeiras',       'BAIRRO',       -11.979000, -51.495000),
    (3, 'Vila Nova',                  'BAIRRO',       -11.992000, -51.510000),
    (4, 'Zona Rural Norte',           'ZONA_RURAL',   -11.880000, -51.470000),
    (5, 'Zona Rural Sul',             'ZONA_RURAL',   -12.090000, -51.540000),
    (6, 'Assentamento Boa Esperança', 'ASSENTAMENTO', -12.030000, -51.390000),
    (7, 'Distrito Ribeirão Bonito',   'DISTRITO',     -11.920000, -51.620000);

-- As senhas são gravadas apenas como hash bcrypt (RNF05).
INSERT INTO usuario (id_usuario, id_orgao, nome, email, telefone, senha_hash, perfil,
                     cargo, matricula, recebe_alertas, criado_em) VALUES
    ( 1, NULL, 'Administrador do Sistema', 'admin@exemplo.org',          NULL,
      crypt('Teste@2026', gen_salt('bf', 8)), 'ADMINISTRADOR', NULL, NULL, FALSE, '2026-07-20 08:00-04'),
    ( 2, 1,    'Mariana Costa',            'mariana.costa@exemplo.org',  '(66) 99100-0002',
      crypt('Teste@2026', gen_salt('bf', 8)), 'AGENTE_PUBLICO', 'Vereadora',              'CM-0102', TRUE, '2026-07-21 09:00-04'),
    ( 3, 1,    'Ricardo Almeida',          'ricardo.almeida@exemplo.org','(66) 99100-0003',
      crypt('Teste@2026', gen_salt('bf', 8)), 'AGENTE_PUBLICO', 'Assessor legislativo',   'CM-0215', TRUE, '2026-07-21 09:10-04'),
    ( 4, 4,    'Paulo Ribeiro',            'paulo.ribeiro@exemplo.org',  '(66) 99100-0004',
      crypt('Teste@2026', gen_salt('bf', 8)), 'AGENTE_PUBLICO', 'Chefe de brigada',       'BR-0004', TRUE, '2026-07-22 10:00-04'),
    ( 5, 3,    'Luciana Ferreira',         'luciana.ferreira@exemplo.org','(66) 99100-0005',
      crypt('Teste@2026', gen_salt('bf', 8)), 'AGENTE_PUBLICO', 'Coordenadora de Defesa Civil', 'DC-0007', TRUE, '2026-07-22 10:30-04'),
    ( 6, 5,    'Joana Pereira',            'joana.pereira@exemplo.org',  '(66) 99100-0006',
      crypt('Teste@2026', gen_salt('bf', 8)), 'AGENTE_PUBLICO', 'Brigadista',             'BR-0031', TRUE, '2026-07-23 14:00-04'),
    ( 7, NULL, 'Antônio Silva',            'antonio.silva@exemplo.org',  '(66) 99200-0007',
      crypt('Teste@2026', gen_salt('bf', 8)), 'MORADOR', NULL, NULL, TRUE,  '2026-07-25 18:20-04'),
    ( 8, NULL, 'Beatriz Santos',           'beatriz.santos@exemplo.org', '(66) 99200-0008',
      crypt('Teste@2026', gen_salt('bf', 8)), 'MORADOR', NULL, NULL, TRUE,  '2026-07-26 07:45-04'),
    ( 9, NULL, 'Carlos Oliveira',          'carlos.oliveira@exemplo.org','(66) 99200-0009',
      crypt('Teste@2026', gen_salt('bf', 8)), 'MORADOR', NULL, NULL, TRUE,  '2026-07-28 12:00-04'),
    (10, NULL, 'Daniela Lima',             'daniela.lima@exemplo.org',   NULL,
      crypt('Teste@2026', gen_salt('bf', 8)), 'MORADOR', NULL, NULL, FALSE, '2026-08-01 19:30-04'),
    (11, NULL, 'Eduardo Rocha',            'eduardo.rocha@exemplo.org',  '(66) 99200-0011',
      crypt('Teste@2026', gen_salt('bf', 8)), 'MORADOR', NULL, NULL, TRUE,  '2026-08-02 06:15-04'),
    (12, NULL, 'Fernanda Gomes',           'fernanda.gomes@exemplo.org', '(66) 99200-0012',
      crypt('Teste@2026', gen_salt('bf', 8)), 'MORADOR', NULL, NULL, TRUE,  '2026-08-05 21:00-04'),
    (13, NULL, 'Gabriel Martins',          'gabriel.martins@exemplo.org','(66) 99200-0013',
      crypt('Teste@2026', gen_salt('bf', 8)), 'MORADOR', NULL, NULL, TRUE,  '2026-08-09 10:40-04'),
    (14, NULL, 'Helena Barbosa',           'helena.barbosa@exemplo.org', NULL,
      crypt('Teste@2026', gen_salt('bf', 8)), 'MORADOR', NULL, NULL, TRUE,  '2026-09-30 16:00-04');

-- Os IDs foram informados explicitamente para facilitar a leitura dos testes;
-- as sequências de identidade são ajustadas para continuar a partir do maior ID.
DO $$
BEGIN
    PERFORM setval(pg_get_serial_sequence('alerta_fogo.orgao',      'id_orgao'),      (SELECT max(id_orgao)      FROM orgao));
    PERFORM setval(pg_get_serial_sequence('alerta_fogo.localidade', 'id_localidade'), (SELECT max(id_localidade) FROM localidade));
    PERFORM setval(pg_get_serial_sequence('alerta_fogo.usuario',    'id_usuario'),    (SELECT max(id_usuario)    FROM usuario));
END;
$$;
