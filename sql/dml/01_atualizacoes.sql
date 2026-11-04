-- =============================================================================
-- Alerta Fogo Araguaia | DML 01 - Operações de atualização (UPDATE)
-- -----------------------------------------------------------------------------
-- Cada bloco reproduz uma ação real do sistema. Os comandos usam RETURNING
-- para mostrar o resultado da alteração.
-- =============================================================================
SET search_path TO alerta_fogo, public;

-- U1 | RF06 - Agente público valida a ocorrência 10 e classifica a gravidade.
--      O trigger verifica se o validador é agente público (RN03) e se a
--      transição PENDENTE -> VALIDADA é permitida.
UPDATE ocorrencia
   SET status       = 'VALIDADA',
       gravidade    = 2,
       id_validador = 3,
       validada_em  = '2026-10-02 13:00-04'
 WHERE id_ocorrencia = 10
RETURNING id_ocorrencia, status, gravidade, id_validador, validada_em;

-- U2 | RN04 - Ocorrência 11 é descartada por ser duplicada da ocorrência 6.
UPDATE ocorrencia
   SET status                 = 'DESCARTADA',
       id_validador           = 2,
       validada_em            = '2026-10-05 10:00-04',
       justificativa_descarte = 'Duplicada: mesmo foco da ocorrência 6, já em atendimento pela brigada.'
 WHERE id_ocorrencia = 11
RETURNING id_ocorrencia, status, justificativa_descarte;

-- U3 | RN02 - Emite alerta para cada sugestão pendente (ocorrência de
--      gravidade alta sem alerta). Na carga de teste, a ocorrência 9.
INSERT INTO alerta (id_localidade, id_emissor, id_ocorrencia, titulo, mensagem, nivel_risco, emitido_em)
SELECT s.id_localidade,
       2,
       s.id_ocorrencia,
       s.titulo_sugerido,
       'Linha de fogo próxima à rodovia. Evite a região e comunique novos focos pelo aplicativo.',
       'ALTO',
       s.validada_em + INTERVAL '5 minutes'
  FROM vw_sugestao_alerta s
RETURNING id_alerta, id_localidade, id_ocorrencia, titulo, nivel_risco;

-- U4 | RF07 - Abertura de atendimento para a ocorrência 9. O trigger de
--      ATENDIMENTO altera a ocorrência de VALIDADA para EM_ATENDIMENTO.
INSERT INTO atendimento (id_ocorrencia, id_orgao, id_responsavel, inicio, providencia)
VALUES (9, 4, 4, '2026-09-28 15:00-04', 'Equipe de bombeiros deslocada com uma viatura e apoio da brigada.')
RETURNING id_atendimento, id_ocorrencia, inicio;

SELECT id_ocorrencia, status FROM ocorrencia WHERE id_ocorrencia = 9;

-- U5 | RF07 e RN04 - Conclusão do atendimento da ocorrência 7 e encerramento.
UPDATE atendimento
   SET fim         = '2026-09-12 17:40-04',
       providencia = providencia || ' Bombeiros extinguiram o fogo às 17h40; nenhuma casa atingida.'
 WHERE id_ocorrencia = 7
   AND fim IS NULL
RETURNING id_atendimento, inicio, fim, fim - inicio AS duracao;

UPDATE ocorrencia
   SET status = 'ENCERRADA'
 WHERE id_ocorrencia = 7
RETURNING id_ocorrencia, status;

-- U6 | Reclassificação de gravidade após vistoria (ocorrência 8: baixa -> média).
UPDATE ocorrencia
   SET gravidade = 2
 WHERE id_ocorrencia = 8
   AND status = 'VALIDADA'
RETURNING id_ocorrencia, gravidade;

-- U7 | RF12 - Atualização cadastral: novo telefone e preferência de alertas.
UPDATE usuario
   SET telefone       = '(66) 99200-1010',
       recebe_alertas = TRUE
 WHERE email = 'daniela.lima@exemplo.org'
RETURNING id_usuario, nome, telefone, recebe_alertas;

-- U8 | RF12 - Atualização com filtro: completa o e-mail das brigadas que
--      ainda não tinham contato eletrônico cadastrado.
UPDATE orgao
   SET email = 'brigada.araguaia@exemplo.org'
 WHERE tipo = 'BRIGADA'
   AND email IS NULL
RETURNING id_orgao, nome, email;
