-- =============================================================================
-- Alerta Fogo Araguaia | 06 - Visões (views)
-- =============================================================================
SET search_path TO alerta_fogo, public;

-- -----------------------------------------------------------------------------
-- Mapa público (RF04, RN01, RNF06): apenas ocorrências confirmadas e sem
-- nenhum dado pessoal de quem registrou.
-- -----------------------------------------------------------------------------
CREATE VIEW vw_mapa_publico AS
SELECT o.id_ocorrencia,
       l.nome        AS localidade,
       o.latitude,
       o.longitude,
       o.data_hora,
       CASE o.gravidade WHEN 1 THEN 'BAIXA' WHEN 2 THEN 'MÉDIA' WHEN 3 THEN 'ALTA' END AS gravidade,
       o.status,
       (SELECT count(*) FROM foto f WHERE f.id_ocorrencia = o.id_ocorrencia) AS qtd_fotos
  FROM ocorrencia o
  JOIN localidade l ON l.id_localidade = o.id_localidade
 WHERE o.status IN ('VALIDADA', 'EM_ATENDIMENTO', 'ENCERRADA');

COMMENT ON VIEW vw_mapa_publico IS 'Ocorrências exibidas no mapa público, sem identificação do autor (LGPD).';

-- -----------------------------------------------------------------------------
-- RN02: ocorrências validadas com gravidade alta que ainda não originaram
-- alerta para a localidade são sugeridas ao agente público.
-- -----------------------------------------------------------------------------
CREATE VIEW vw_sugestao_alerta AS
SELECT o.id_ocorrencia,
       o.id_localidade,
       l.nome AS localidade,
       o.data_hora,
       o.validada_em,
       'Risco de queimada em ' || l.nome AS titulo_sugerido
  FROM ocorrencia o
  JOIN localidade l ON l.id_localidade = o.id_localidade
 WHERE o.gravidade = 3
   AND o.status IN ('VALIDADA', 'EM_ATENDIMENTO')
   AND NOT EXISTS (SELECT 1 FROM alerta a WHERE a.id_ocorrencia = o.id_ocorrencia);

COMMENT ON VIEW vw_sugestao_alerta IS 'RN02: sugestões automáticas de alerta para ocorrências de gravidade alta.';

-- -----------------------------------------------------------------------------
-- Painel do agente: fila de ocorrências pendentes, da mais antiga à mais nova.
-- -----------------------------------------------------------------------------
CREATE VIEW vw_fila_validacao AS
SELECT o.id_ocorrencia,
       l.nome AS localidade,
       o.data_hora,
       now() - o.criado_em AS aguardando_ha,
       left(o.descricao, 80) AS resumo
  FROM ocorrencia o
  JOIN localidade l ON l.id_localidade = o.id_localidade
 WHERE o.status = 'PENDENTE'
 ORDER BY o.criado_em;
