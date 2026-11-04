-- =============================================================================
-- Alerta Fogo Araguaia | Consultas (SELECT)
-- -----------------------------------------------------------------------------
-- Consultas que atendem às telas e relatórios do sistema. Execute depois de
-- ./scripts/run_all.sh:  psql -f sql/consultas/consultas.sql
-- =============================================================================
SET search_path TO alerta_fogo, public;
SET timezone TO 'America/Cuiaba';

-- C01 | RF04 - Mapa público: ocorrências confirmadas em setembro de 2026,
--       sem dados de quem registrou (RNF06).
SELECT id_ocorrencia, localidade, latitude, longitude,
       to_char(data_hora, 'DD/MM/YYYY HH24:MI') AS data_hora, gravidade, status, qtd_fotos
  FROM vw_mapa_publico
 WHERE data_hora >= '2026-09-01' AND data_hora < '2026-10-01'
 ORDER BY data_hora;

-- C02 | Painel do agente: ocorrências aguardando validação.
SELECT id_ocorrencia, localidade, to_char(data_hora, 'DD/MM/YYYY HH24:MI') AS data_hora, resumo
  FROM vw_fila_validacao;

-- C03 | RF10 - Relatório por localidade no período (ago-out/2026), com
--       contagem por status usando agregação condicional (FILTER).
SELECT l.nome                                                      AS localidade,
       count(o.id_ocorrencia)                                      AS total,
       count(*) FILTER (WHERE o.status = 'PENDENTE')               AS pendentes,
       count(*) FILTER (WHERE o.status IN ('VALIDADA','EM_ATENDIMENTO')) AS em_aberto,
       count(*) FILTER (WHERE o.status = 'ENCERRADA')              AS encerradas,
       count(*) FILTER (WHERE o.status = 'DESCARTADA')             AS descartadas,
       count(*) FILTER (WHERE o.gravidade = 3)                     AS gravidade_alta
  FROM localidade l
  LEFT JOIN ocorrencia o
         ON o.id_localidade = l.id_localidade
        AND o.data_hora >= '2026-08-01' AND o.data_hora < '2026-11-01'
 GROUP BY l.id_localidade, l.nome
 ORDER BY total DESC, l.nome;

-- C04 | Desempenho por órgão: tempo médio entre o registro da ocorrência e o
--       início do atendimento, e duração média dos atendimentos concluídos.
SELECT g.nome                                                   AS orgao,
       count(a.id_atendimento)                                  AS atendimentos,
       justify_interval(avg(a.inicio - o.criado_em))            AS tempo_medio_resposta,
       justify_interval(avg(a.fim - a.inicio))                  AS duracao_media
  FROM atendimento a
  JOIN orgao g      ON g.id_orgao      = a.id_orgao
  JOIN ocorrencia o ON o.id_ocorrencia = a.id_ocorrencia
 GROUP BY g.nome
 ORDER BY tempo_medio_resposta;

-- C05 | Ranking das localidades por focos de calor (função de janela RANK).
SELECT RANK() OVER (ORDER BY count(f.id_foco) DESC) AS posicao,
       COALESCE(l.nome, '(fora das localidades)')  AS localidade,
       count(f.id_foco)                            AS focos,
       round(avg(f.frp), 1)                        AS frp_medio_mw,
       max(f.frp)                                  AS frp_maximo_mw
  FROM foco_satelite f
  LEFT JOIN localidade l ON l.id_localidade = f.id_localidade
 GROUP BY l.nome
 ORDER BY posicao, localidade;

-- C06 | Cruzamento comunidade x satélite: para cada ocorrência confirmada,
--       focos detectados a até 3 km e em até 12 horas (fórmula de haversine).
WITH pares AS (
    SELECT o.id_ocorrencia,
           f.id_foco,
           f.satelite,
           f.data_hora AS deteccao,
           2 * 6371 * asin(sqrt(
               power(sin(radians(f.latitude  - o.latitude)  / 2), 2) +
               cos(radians(o.latitude)) * cos(radians(f.latitude)) *
               power(sin(radians(f.longitude - o.longitude) / 2), 2))) AS distancia_km,
           f.data_hora - o.data_hora AS diferenca
      FROM ocorrencia o
      JOIN foco_satelite f
        ON f.data_hora BETWEEN o.data_hora - INTERVAL '12 hours' AND o.data_hora + INTERVAL '12 hours'
     WHERE o.status IN ('VALIDADA', 'EM_ATENDIMENTO', 'ENCERRADA')
)
SELECT id_ocorrencia, id_foco, satelite,
       to_char(deteccao, 'DD/MM HH24:MI') AS deteccao,
       round(distancia_km::numeric, 2)    AS distancia_km,
       diferenca
  FROM pares
 WHERE distancia_km <= 3
 ORDER BY id_ocorrencia, distancia_km;

-- C07 | Ocorrências confirmadas SEM nenhum foco de satélite próximo: mostram
--       o valor do registro comunitário, que detecta o que o satélite não vê.
SELECT o.id_ocorrencia, l.nome AS localidade, o.gravidade, o.status
  FROM ocorrencia o
  JOIN localidade l ON l.id_localidade = o.id_localidade
 WHERE o.status IN ('VALIDADA', 'EM_ATENDIMENTO', 'ENCERRADA')
   AND NOT EXISTS (
        SELECT 1 FROM foco_satelite f
         WHERE f.data_hora BETWEEN o.data_hora - INTERVAL '12 hours' AND o.data_hora + INTERVAL '12 hours'
           AND abs(f.latitude - o.latitude) < 0.03 AND abs(f.longitude - o.longitude) < 0.03)
 ORDER BY o.id_ocorrencia;

-- C08 | RF08 - Destinatários de um alerta: moradores ativos que aceitam
--       receber notificações.
SELECT a.id_alerta, a.titulo, count(u.id_usuario) AS destinatarios
  FROM alerta a
 CROSS JOIN usuario u
 WHERE u.perfil = 'MORADOR' AND u.ativo AND u.recebe_alertas
 GROUP BY a.id_alerta, a.titulo
 ORDER BY a.id_alerta;

-- C09 | Histórico de alertas com emissor, órgão e ocorrência de origem.
SELECT a.id_alerta,
       to_char(a.emitido_em, 'DD/MM/YYYY HH24:MI') AS emitido_em,
       l.nome   AS localidade,
       a.nivel_risco,
       u.nome   AS emissor,
       g.nome   AS orgao_emissor,
       COALESCE(a.id_ocorrencia::text, '-') AS ocorrencia_origem
  FROM alerta a
  JOIN localidade l ON l.id_localidade = a.id_localidade
  JOIN usuario    u ON u.id_usuario    = a.id_emissor
  JOIN orgao      g ON g.id_orgao      = u.id_orgao
 ORDER BY a.emitido_em;

-- C10 | Atuação dos agentes públicos: validações, atendimentos e alertas,
--       incluindo quem ainda não atuou (LEFT JOIN + subconsultas).
SELECT u.nome, u.cargo, g.nome AS orgao,
       (SELECT count(*) FROM ocorrencia  o WHERE o.id_validador   = u.id_usuario) AS validacoes,
       (SELECT count(*) FROM atendimento a WHERE a.id_responsavel = u.id_usuario) AS atendimentos,
       (SELECT count(*) FROM alerta     al WHERE al.id_emissor    = u.id_usuario) AS alertas
  FROM usuario u
  LEFT JOIN orgao g ON g.id_orgao = u.id_orgao
 WHERE u.perfil = 'AGENTE_PUBLICO'
 ORDER BY validacoes DESC, atendimentos DESC;

-- C11 | Evolução mensal: ocorrências da comunidade x focos de satélite.
WITH meses AS (
    SELECT generate_series(DATE '2026-08-01', DATE '2026-10-01', INTERVAL '1 month')::date AS mes
)
SELECT to_char(m.mes, 'MM/YYYY') AS mes,
       (SELECT count(*) FROM ocorrencia o
         WHERE date_trunc('month', o.data_hora)::date = m.mes)          AS ocorrencias,
       (SELECT count(*) FROM ocorrencia o
         WHERE date_trunc('month', o.data_hora)::date = m.mes
           AND o.status <> 'DESCARTADA')                                AS nao_descartadas,
       (SELECT count(*) FROM foco_satelite f
         WHERE date_trunc('month', f.data_hora)::date = m.mes)          AS focos_satelite
  FROM meses m
 ORDER BY m.mes;

-- C12 | Ocorrências em aberto e há quanto tempo estão sem conclusão.
SELECT o.id_ocorrencia, l.nome AS localidade, o.status, o.gravidade,
       string_agg(DISTINCT g.nome, ', ')        AS orgaos_em_campo,
       justify_interval(TIMESTAMPTZ '2026-10-15 12:00-04' - o.data_hora) AS em_aberto_ha
  FROM ocorrencia o
  JOIN localidade l       ON l.id_localidade = o.id_localidade
  LEFT JOIN atendimento a ON a.id_ocorrencia = o.id_ocorrencia
  LEFT JOIN orgao g       ON g.id_orgao      = a.id_orgao
 WHERE o.status IN ('VALIDADA', 'EM_ATENDIMENTO')
 GROUP BY o.id_ocorrencia, l.nome
 ORDER BY o.data_hora;
