-- =============================================================================
-- Alerta Fogo Araguaia | Testes automatizados das restrições e regras
-- -----------------------------------------------------------------------------
-- Cada teste executa uma operação que DEVE ser rejeitada pelo banco e confere
-- o código de erro (SQLSTATE). Tudo roda dentro de uma transação desfeita ao
-- final (ROLLBACK), então os dados não são alterados.
--   23502 not_null_violation   23503 foreign_key_violation
--   23505 unique_violation     23514 check_violation   22P02 invalid_text_representation
-- =============================================================================
\set ON_ERROR_STOP on
SET search_path TO alerta_fogo, public;
SET client_min_messages TO notice;
\set VERBOSITY terse

BEGIN;

CREATE PROCEDURE pg_temp.deve_falhar(p_descricao TEXT, p_sql TEXT, p_sqlstate TEXT)
LANGUAGE plpgsql AS $$
DECLARE
    v_estado TEXT;
BEGIN
    BEGIN
        EXECUTE p_sql;
    EXCEPTION WHEN OTHERS THEN
        v_estado := SQLSTATE;
    END;

    IF v_estado IS NULL THEN
        RAISE EXCEPTION 'FALHOU: % (o comando foi aceito)', p_descricao;
    ELSIF v_estado <> p_sqlstate THEN
        RAISE EXCEPTION 'FALHOU: % (esperado %, obtido %)', p_descricao, p_sqlstate, v_estado;
    END IF;

    RAISE NOTICE 'ok  %', p_descricao;
END;
$$;

CREATE PROCEDURE pg_temp.deve_ser(p_descricao TEXT, p_consulta TEXT)
LANGUAGE plpgsql AS $$
DECLARE
    v_resultado BOOLEAN;
BEGIN
    EXECUTE p_consulta INTO v_resultado;
    IF v_resultado IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'FALHOU: %', p_descricao;
    END IF;
    RAISE NOTICE 'ok  %', p_descricao;
END;
$$;

-- Integridade de entidade e de domínio --------------------------------------
CALL pg_temp.deve_falhar('PK: órgão com id repetido',
    $q$INSERT INTO orgao (id_orgao, nome, tipo) VALUES (1, 'Órgão X', 'BRIGADA')$q$, '23505');
CALL pg_temp.deve_falhar('UNIQUE: e-mail de usuário repetido',
    $q$INSERT INTO usuario (nome, email, senha_hash) VALUES ('X', 'antonio.silva@exemplo.org', 'h')$q$, '23505');
CALL pg_temp.deve_falhar('CHECK: e-mail inválido',
    $q$INSERT INTO usuario (nome, email, senha_hash) VALUES ('X', 'sem-arroba', 'h')$q$, '23514');
CALL pg_temp.deve_falhar('NOT NULL: usuário sem senha',
    $q$INSERT INTO usuario (nome, email) VALUES ('X', 'x@exemplo.org')$q$, '23502');
CALL pg_temp.deve_falhar('ENUM: perfil inexistente',
    $q$INSERT INTO usuario (nome, email, senha_hash, perfil) VALUES ('X', 'x@exemplo.org', 'h', 'VISITANTE')$q$, '22P02');
CALL pg_temp.deve_falhar('CHECK: tipo de localidade inválido',
    $q$INSERT INTO localidade (nome, tipo, latitude, longitude) VALUES ('X', 'CIDADE', 0, 0)$q$, '23514');
CALL pg_temp.deve_falhar('CHECK: latitude fora do intervalo',
    $q$INSERT INTO localidade (nome, tipo, latitude, longitude) VALUES ('X', 'BAIRRO', 95, 0)$q$, '23514');
CALL pg_temp.deve_falhar('CHECK: gravidade fora de 1 a 3',
    $q$UPDATE ocorrencia SET gravidade = 5 WHERE id_ocorrencia = 8$q$, '23514');
CALL pg_temp.deve_falhar('CHECK: formato de foto não permitido',
    $q$INSERT INTO foto (id_ocorrencia, caminho_arquivo) VALUES (8, 'uploads/x.exe')$q$, '23514');
CALL pg_temp.deve_falhar('CHECK: atendimento com fim antes do início',
    $q$UPDATE atendimento SET fim = inicio - INTERVAL '1 hour' WHERE id_atendimento = 6$q$, '23514');
CALL pg_temp.deve_falhar('UNIQUE: foco de satélite importado duas vezes',
    $q$INSERT INTO foco_satelite (data_hora, latitude, longitude, satelite)
       SELECT data_hora, latitude, longitude, satelite FROM foco_satelite LIMIT 1$q$, '23505');

-- Integridade referencial ----------------------------------------------------
CALL pg_temp.deve_falhar('FK: ocorrência com localidade inexistente',
    $q$INSERT INTO ocorrencia (id_usuario, id_localidade, descricao, latitude, longitude, data_hora)
       VALUES (7, 999, 'Fogo em local inexistente', 0, 0, now())$q$, '23503');
CALL pg_temp.deve_falhar('FK RESTRICT: remover localidade com ocorrências',
    $q$DELETE FROM localidade WHERE id_localidade = 4$q$, '23503');
CALL pg_temp.deve_falhar('FK RESTRICT: remover órgão com agentes vinculados',
    $q$DELETE FROM orgao WHERE id_orgao = 1$q$, '23503');

-- Regras de negócio ----------------------------------------------------------
CALL pg_temp.deve_falhar('RN01: ocorrência não pode nascer VALIDADA',
    $q$INSERT INTO ocorrencia (id_usuario, id_localidade, descricao, latitude, longitude, data_hora, status)
       VALUES (7, 1, 'Tentativa de pular a validação', -11.98, -51.50, now(), 'VALIDADA')$q$, '23514');
CALL pg_temp.deve_falhar('RN03: agente público precisa de órgão',
    $q$INSERT INTO usuario (nome, email, senha_hash, perfil) VALUES ('X', 'x@exemplo.org', 'h', 'AGENTE_PUBLICO')$q$, '23514');
CALL pg_temp.deve_falhar('RN03: morador não pode validar ocorrência',
    $q$UPDATE ocorrencia SET status = 'DESCARTADA', id_validador = 7, justificativa_descarte = 'teste'
        WHERE id_ocorrencia = 8$q$, '23514');
CALL pg_temp.deve_falhar('RN03: morador não pode emitir alerta',
    $q$INSERT INTO alerta (id_localidade, id_emissor, titulo, mensagem, nivel_risco)
       VALUES (1, 8, 'Falso alerta', 'Teste', 'ALTO')$q$, '23514');
CALL pg_temp.deve_falhar('RN03: morador não pode registrar atendimento',
    $q$INSERT INTO atendimento (id_ocorrencia, id_orgao, id_responsavel, providencia)
       VALUES (8, 5, 9, 'Teste')$q$, '23514');
CALL pg_temp.deve_falhar('RN04: descarte sem justificativa',
    $q$UPDATE ocorrencia SET status = 'DESCARTADA', id_validador = 2 WHERE id_ocorrencia = 8$q$, '23514');
CALL pg_temp.deve_falhar('RN04: encerrar ocorrência sem atendimento concluído',
    $q$UPDATE ocorrencia SET status = 'ENCERRADA' WHERE id_ocorrencia = 6$q$, '23514');
CALL pg_temp.deve_falhar('Ciclo de vida: ENCERRADA não volta para PENDENTE',
    $q$UPDATE ocorrencia SET status = 'PENDENTE' WHERE id_ocorrencia = 1$q$, '23514');
INSERT INTO ocorrencia (id_ocorrencia, id_usuario, id_localidade, descricao, latitude, longitude, data_hora)
VALUES (900, 7, 1, 'Ocorrência criada pelo teste', -11.98, -51.50, now());
CALL pg_temp.deve_falhar('Ciclo de vida: PENDENTE não pula para ENCERRADA',
    $q$UPDATE ocorrencia SET status = 'ENCERRADA' WHERE id_ocorrencia = 900$q$, '23514');
CALL pg_temp.deve_falhar('Atendimento só para ocorrência validada',
    $q$INSERT INTO atendimento (id_ocorrencia, id_orgao, id_responsavel, providencia)
       VALUES (4, 4, 4, 'Ocorrência descartada')$q$, '23514');

-- RF03: limite de 5 fotos. A ocorrência 1 tem 2 fotos; 3 entram, a 6ª falha.
INSERT INTO foto (id_ocorrencia, caminho_arquivo) VALUES
    (1, 'teste/1/a.jpg'), (1, 'teste/1/b.jpg'), (1, 'teste/1/c.jpg');
CALL pg_temp.deve_falhar('RF03: sexta foto na mesma ocorrência',
    $q$INSERT INTO foto (id_ocorrencia, caminho_arquivo) VALUES (1, 'teste/1/d.jpg')$q$, '23514');

-- Comportamentos esperados (casos que devem funcionar) -----------------------
CALL pg_temp.deve_ser('Senhas gravadas como hash bcrypt e verificáveis',
    $q$SELECT senha_hash = crypt('Teste@2026', senha_hash) AND senha_hash LIKE '$2a$%'
       FROM usuario WHERE id_usuario = 2$q$);
CALL pg_temp.deve_ser('Mapa público não expõe o autor da ocorrência (RNF06)',
    $q$SELECT NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = 'alerta_fogo' AND table_name = 'vw_mapa_publico'
                   AND column_name IN ('id_usuario', 'nome', 'email', 'telefone'))$q$);
CALL pg_temp.deve_ser('Mapa público só mostra ocorrências confirmadas (RN01)',
    $q$SELECT NOT EXISTS (SELECT 1 FROM vw_mapa_publico WHERE status NOT IN ('VALIDADA','EM_ATENDIMENTO','ENCERRADA'))$q$);

UPDATE ocorrencia SET status = 'VALIDADA', gravidade = 3, id_validador = 4 WHERE id_ocorrencia = 900;
CALL pg_temp.deve_ser('RN02: ocorrência de gravidade alta gera sugestão de alerta',
    $q$SELECT EXISTS (SELECT 1 FROM vw_sugestao_alerta WHERE id_ocorrencia = 900)$q$);
CALL pg_temp.deve_ser('Validação preenche validada_em automaticamente',
    $q$SELECT validada_em IS NOT NULL FROM ocorrencia WHERE id_ocorrencia = 900$q$);

INSERT INTO atendimento (id_ocorrencia, id_orgao, id_responsavel, providencia)
VALUES (900, 4, 4, 'Atendimento criado pelo teste');
CALL pg_temp.deve_ser('Abrir atendimento muda a ocorrência para EM_ATENDIMENTO',
    $q$SELECT status = 'EM_ATENDIMENTO' FROM ocorrencia WHERE id_ocorrencia = 900$q$);

INSERT INTO localidade (id_localidade, nome, tipo, latitude, longitude)
VALUES (900, 'Localidade temporária', 'BAIRRO', -11.9, -51.5);
INSERT INTO foco_satelite (id_foco, id_localidade, data_hora, latitude, longitude, satelite)
VALUES (900, 900, now(), -11.9, -51.5, 'TESTE');
DELETE FROM localidade WHERE id_localidade = 900;
CALL pg_temp.deve_ser('ON DELETE SET NULL: foco mantido sem localidade',
    $q$SELECT id_localidade IS NULL FROM foco_satelite WHERE id_foco = 900$q$);

CALL pg_temp.deve_ser('Pré-condição: ocorrência 10 possui foto',
    $q$SELECT EXISTS (SELECT 1 FROM foto WHERE id_ocorrencia = 10)$q$);
DELETE FROM ocorrencia WHERE id_ocorrencia = 10;
CALL pg_temp.deve_ser('ON DELETE CASCADE: fotos removidas com a ocorrência',
    $q$SELECT NOT EXISTS (SELECT 1 FROM foto WHERE id_ocorrencia = 10)$q$);

ROLLBACK;

\echo 'Todos os testes passaram.'
