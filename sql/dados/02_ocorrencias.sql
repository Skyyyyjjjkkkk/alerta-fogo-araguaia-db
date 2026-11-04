-- =============================================================================
-- Alerta Fogo Araguaia | Dados de teste 02 - ocorrências e registros ligados
-- -----------------------------------------------------------------------------
-- A carga segue o mesmo ciclo de vida que o sistema usará, respeitando as
-- regras de negócio implementadas nos triggers:
--   1) a ocorrência é inserida como PENDENTE (RN01);
--   2) um agente público valida ou descarta (RN03);
--   3) o atendimento é aberto (a ocorrência passa a EM_ATENDIMENTO);
--   4) o atendimento é concluído e só então a ocorrência é ENCERRADA (RN04).
-- Período simulado: estação seca de 2026 (agosto a outubro). Dados fictícios.
-- =============================================================================
SET search_path TO alerta_fogo, public;

-- 1) Registro das ocorrências pelos moradores ---------------------------------
INSERT INTO ocorrencia (id_ocorrencia, id_usuario, id_localidade, descricao,
                        latitude, longitude, data_hora, criado_em) VALUES
    ( 1,  7, 4, 'Fogo em pastagem próxima à estrada vicinal, fumaça densa e vento forte.',
         -11.872300, -51.463100, '2026-08-03 15:20-04', '2026-08-03 15:26-04'),
    ( 2,  8, 6, 'Queimada em área de roça avançando para a reserva do assentamento.',
         -12.026400, -51.395200, '2026-08-10 11:05-04', '2026-08-10 11:12-04'),
    ( 3,  9, 3, 'Fogo em terreno baldio com lixo acumulado atrás da escola.',
         -11.993100, -51.511400, '2026-08-15 17:40-04', '2026-08-15 17:43-04'),
    ( 4, 10, 5, 'Muita fumaça vindo do lado sul da cidade, não consigo ver de onde.',
         -12.081000, -51.536000, '2026-08-22 08:30-04', '2026-08-22 08:41-04'),
    ( 5, 11, 7, 'Incêndio de grandes proporções na mata ciliar do ribeirão.',
         -11.915800, -51.628300, '2026-09-01 13:10-04', '2026-09-01 13:14-04'),
    ( 6,  7, 4, 'Foco reacendeu na mesma região do início de agosto, perto da ponte.',
         -11.876500, -51.468800, '2026-09-05 16:00-04', '2026-09-05 16:03-04'),
    ( 7, 12, 6, 'Fogo em cerca de pasto, chegando perto das casas do lote 14.',
         -12.034700, -51.388100, '2026-09-12 10:25-04', '2026-09-12 10:31-04'),
    ( 8, 13, 2, 'Queima de folhas em lote vazio, fumaça incomodando a vizinhança.',
         -11.980200, -51.496700, '2026-09-20 18:50-04', '2026-09-20 18:52-04'),
    ( 9,  8, 5, 'Linha de fogo extensa em área de cerrado ao lado da rodovia.',
         -12.095300, -51.546200, '2026-09-28 14:15-04', '2026-09-28 14:19-04'),
    (10,  9, 1, 'Fogo em canteiro da avenida principal, próximo ao posto.',
         -11.984600, -51.502300, '2026-10-02 12:30-04', '2026-10-02 12:33-04'),
    (11, 11, 4, 'Fumaça escura saindo da mata perto da ponte da vicinal norte.',
         -11.877000, -51.469500, '2026-10-05 09:10-04', '2026-10-05 09:15-04'),
    (12, 13, 7, 'Teste de envio do aplicativo, registro feito por engano.',
         -11.921000, -51.619000, '2026-10-08 20:00-04', '2026-10-08 20:01-04');

-- 2) Validações e descartes por agentes públicos (RF06) -----------------------
UPDATE ocorrencia SET status = 'VALIDADA', gravidade = 3, id_validador = 2, validada_em = '2026-08-03 15:40-04' WHERE id_ocorrencia = 1;
UPDATE ocorrencia SET status = 'VALIDADA', gravidade = 2, id_validador = 3, validada_em = '2026-08-10 11:30-04' WHERE id_ocorrencia = 2;
UPDATE ocorrencia SET status = 'VALIDADA', gravidade = 1, id_validador = 3, validada_em = '2026-08-15 18:05-04' WHERE id_ocorrencia = 3;
UPDATE ocorrencia SET status = 'VALIDADA', gravidade = 3, id_validador = 5, validada_em = '2026-09-01 13:25-04' WHERE id_ocorrencia = 5;
UPDATE ocorrencia SET status = 'VALIDADA', gravidade = 3, id_validador = 2, validada_em = '2026-09-05 16:12-04' WHERE id_ocorrencia = 6;
UPDATE ocorrencia SET status = 'VALIDADA', gravidade = 2, id_validador = 5, validada_em = '2026-09-12 10:50-04' WHERE id_ocorrencia = 7;
UPDATE ocorrencia SET status = 'VALIDADA', gravidade = 1, id_validador = 3, validada_em = '2026-09-21 08:00-04' WHERE id_ocorrencia = 8;
UPDATE ocorrencia SET status = 'VALIDADA', gravidade = 3, id_validador = 2, validada_em = '2026-09-28 14:35-04' WHERE id_ocorrencia = 9;

UPDATE ocorrencia
   SET status = 'DESCARTADA', id_validador = 5, validada_em = '2026-08-22 10:00-04',
       justificativa_descarte = 'Fumaça proveniente de queima controlada autorizada pela Secretaria de Meio Ambiente.'
 WHERE id_ocorrencia = 4;

UPDATE ocorrencia
   SET status = 'DESCARTADA', id_validador = 3, validada_em = '2026-10-09 08:00-04',
       justificativa_descarte = 'Registro de teste enviado por engano pelo próprio morador.'
 WHERE id_ocorrencia = 12;

-- 3) Fotos anexadas (RF03: até 5 por ocorrência) -------------------------------
INSERT INTO foto (id_foto, id_ocorrencia, caminho_arquivo, enviada_em) VALUES
    ( 1,  1, 'uploads/ocorrencias/1/foto-01.jpg', '2026-08-03 15:26-04'),
    ( 2,  1, 'uploads/ocorrencias/1/foto-02.jpg', '2026-08-03 15:26-04'),
    ( 3,  1, 'uploads/ocorrencias/1/foto-03.jpg', '2026-08-03 15:27-04'),
    ( 4,  2, 'uploads/ocorrencias/2/foto-01.jpg', '2026-08-10 11:12-04'),
    ( 5,  3, 'uploads/ocorrencias/3/foto-01.png', '2026-08-15 17:43-04'),
    ( 6,  5, 'uploads/ocorrencias/5/foto-01.jpg', '2026-09-01 13:14-04'),
    ( 7,  5, 'uploads/ocorrencias/5/foto-02.jpg', '2026-09-01 13:15-04'),
    ( 8,  6, 'uploads/ocorrencias/6/foto-01.jpg', '2026-09-05 16:03-04'),
    ( 9,  7, 'uploads/ocorrencias/7/foto-01.webp','2026-09-12 10:31-04'),
    (10,  9, 'uploads/ocorrencias/9/foto-01.jpg', '2026-09-28 14:19-04'),
    (11,  9, 'uploads/ocorrencias/9/foto-02.jpg', '2026-09-28 14:20-04'),
    (12, 10, 'uploads/ocorrencias/10/foto-01.jpg','2026-10-02 12:33-04'),
    (13, 12, 'uploads/ocorrencias/12/foto-01.jpg','2026-10-08 20:01-04'),
    (14, 12, 'uploads/ocorrencias/12/foto-02.jpg','2026-10-08 20:01-04');

-- 4) Atendimentos (RF07). O trigger muda a ocorrência para EM_ATENDIMENTO. ----
INSERT INTO atendimento (id_atendimento, id_ocorrencia, id_orgao, id_responsavel, inicio, fim, providencia) VALUES
    (1, 1, 4, 4, '2026-08-03 16:10-04', '2026-08-03 21:30-04', 'Combate com duas viaturas e abertura de aceiro de 300 m.'),
    (2, 1, 5, 6, '2026-08-04 07:00-04', '2026-08-04 11:00-04', 'Rescaldo e monitoramento de pontos de reignição.'),
    (3, 2, 5, 6, '2026-08-10 12:00-04', '2026-08-10 16:45-04', 'Brigada conteve o fogo antes da área de reserva.'),
    (4, 3, 2, 3, '2026-08-16 08:30-04', '2026-08-16 10:00-04', 'Fogo extinto; proprietário notificado para limpeza do terreno.'),
    (5, 5, 4, 4, '2026-09-01 13:50-04', '2026-09-02 02:15-04', 'Combate noturno com apoio de caminhão-pipa da prefeitura.'),
    (6, 6, 5, 6, '2026-09-05 16:40-04', NULL,                  'Brigada em campo; foco controlado, aguardando rescaldo.'),
    (7, 7, 3, 5, '2026-09-12 11:20-04', NULL,                  'Defesa Civil isolou a área e acionou os bombeiros.');

-- 5) Encerramento das ocorrências com atendimento concluído (RN04) ------------
UPDATE ocorrencia SET status = 'ENCERRADA' WHERE id_ocorrencia IN (1, 2, 3, 5);

-- 6) Alertas emitidos (RF08, RN02) -------------------------------------------
INSERT INTO alerta (id_alerta, id_localidade, id_emissor, id_ocorrencia, titulo, mensagem, nivel_risco, emitido_em) VALUES
    (1, 4, 2, 1,    'Incêndio ativo na Zona Rural Norte',
        'Evite a estrada vicinal norte. Bombeiros em atuação. Não acenda fogo.', 'ALTO',     '2026-08-03 15:45-04'),
    (2, 7, 5, 5,    'Incêndio de grandes proporções no Ribeirão Bonito',
        'Moradores próximos à mata ciliar devem se afastar e manter portas fechadas.', 'CRITICO', '2026-09-01 13:30-04'),
    (3, 4, 2, 6,    'Reignição de foco na Zona Rural Norte',
        'Foco reacendeu perto da ponte. Brigada em campo. Comunique novos focos pelo app.', 'ALTO', '2026-09-05 16:15-04'),
    (4, 5, 5, NULL, 'Período crítico de seca na Zona Rural Sul',
        'Umidade abaixo de 20%. Queimadas estão proibidas. Denuncie pelo aplicativo ou 193.', 'MODERADO', '2026-09-15 07:00-04');

-- 7) Focos de calor importados do BDQueimadas/INPE (RF11). Valores fictícios. -
INSERT INTO foco_satelite (id_localidade, data_hora, latitude, longitude, satelite, frp) VALUES
    -- focos antigos, usados para demonstrar a limpeza de dados em 02_remocoes.sql
    (4,    '2025-07-14 13:40-04', -11.881000, -51.471000, 'AQUA_M-T',  18.40),
    (5,    '2025-07-30 14:10-04', -12.088000, -51.542000, 'NPP-375',   9.75),
    -- estação seca de 2026
    (4,    '2026-08-03 14:55-04', -11.873000, -51.462000, 'NPP-375',   42.10),
    (4,    '2026-08-03 15:30-04', -11.874200, -51.465900, 'NOAA-20',   55.80),
    (6,    '2026-08-10 10:40-04', -12.027000, -51.396500, 'AQUA_M-T',  21.30),
    (5,    '2026-08-22 13:20-04', -12.079500, -51.534800, 'NPP-375',    6.20),
    (7,    '2026-09-01 12:50-04', -11.914900, -51.627100, 'NOAA-20',   88.60),
    (7,    '2026-09-01 14:30-04', -11.917200, -51.630400, 'NPP-375',  102.45),
    (7,    '2026-09-01 15:05-04', -11.919000, -51.632000, 'GOES-16',   64.00),
    (4,    '2026-09-05 15:35-04', -11.877100, -51.468000, 'NPP-375',   37.90),
    (6,    '2026-09-12 10:05-04', -12.035100, -51.387600, 'AQUA_M-T',  25.00),
    (6,    '2026-09-13 13:15-04', -12.040000, -51.380000, 'NOAA-20',   12.30),
    (5,    '2026-09-28 13:55-04', -12.094800, -51.545100, 'NPP-375',   73.20),
    (5,    '2026-09-28 14:40-04', -12.097000, -51.549000, 'NOAA-20',   69.10),
    (5,    '2026-10-01 13:30-04', -12.110000, -51.560000, 'AQUA_M-T',  15.60),
    (4,    '2026-10-05 08:50-04', -11.876800, -51.470200, 'NPP-375',   28.40),
    (NULL, '2026-10-06 14:00-04', -11.700000, -51.300000, 'NOAA-20',   44.00),
    (NULL, '2026-10-07 13:45-04', -12.300000, -51.800000, 'NPP-375',   31.70);

-- Ajuste das sequências após a carga com IDs explícitos.
DO $$
BEGIN
    PERFORM setval(pg_get_serial_sequence('alerta_fogo.ocorrencia',  'id_ocorrencia'),  (SELECT max(id_ocorrencia)  FROM ocorrencia));
    PERFORM setval(pg_get_serial_sequence('alerta_fogo.foto',        'id_foto'),        (SELECT max(id_foto)        FROM foto));
    PERFORM setval(pg_get_serial_sequence('alerta_fogo.atendimento', 'id_atendimento'), (SELECT max(id_atendimento) FROM atendimento));
    PERFORM setval(pg_get_serial_sequence('alerta_fogo.alerta',      'id_alerta'),      (SELECT max(id_alerta)      FROM alerta));
END;
$$;
