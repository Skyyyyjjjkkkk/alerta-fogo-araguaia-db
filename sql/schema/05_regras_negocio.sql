-- =============================================================================
-- Alerta Fogo Araguaia | 05 - Regras de negócio (funções e triggers)
-- -----------------------------------------------------------------------------
-- Regras que não podem ser expressas apenas com CHECK/FK, pois dependem de
-- outras linhas ou tabelas:
--   RN01 - toda ocorrência nasce PENDENTE;
--   RN03 - só agente público vinculado a órgão valida, atende e emite alerta;
--   RN04 - ocorrência só é encerrada com atendimento concluído;
--   RF03 - no máximo 5 fotos por ocorrência;
--   ciclo de vida - transições de status permitidas.
-- =============================================================================
SET search_path TO alerta_fogo, public;

-- -----------------------------------------------------------------------------
-- Função auxiliar: falha se o usuário não for agente público ativo com órgão.
-- -----------------------------------------------------------------------------
CREATE FUNCTION fn_exigir_agente_publico(p_id_usuario INTEGER, p_acao TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM usuario
         WHERE id_usuario = p_id_usuario
           AND perfil     = 'AGENTE_PUBLICO'
           AND id_orgao   IS NOT NULL
           AND ativo
    ) THEN
        RAISE EXCEPTION 'RN03: o usuário % não é agente público ativo vinculado a um órgão e não pode %.',
                        p_id_usuario, p_acao
              USING ERRCODE = 'check_violation';
    END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- RN01: a ocorrência é sempre criada como PENDENTE, sem dados de validação.
-- -----------------------------------------------------------------------------
CREATE FUNCTION fn_ocorrencia_antes_inserir()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status <> 'PENDENTE' THEN
        RAISE EXCEPTION 'RN01: toda ocorrência deve ser criada com status PENDENTE (recebido: %).', NEW.status
              USING ERRCODE = 'check_violation';
    END IF;

    IF NEW.id_validador IS NOT NULL OR NEW.gravidade IS NOT NULL OR NEW.validada_em IS NOT NULL THEN
        RAISE EXCEPTION 'RN01: gravidade e validador só podem ser informados na validação.'
              USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ocorrencia_antes_inserir
    BEFORE INSERT ON ocorrencia
    FOR EACH ROW EXECUTE FUNCTION fn_ocorrencia_antes_inserir();

-- -----------------------------------------------------------------------------
-- Ciclo de vida: transições permitidas de status.
--   PENDENTE       -> VALIDADA | DESCARTADA
--   VALIDADA       -> EM_ATENDIMENTO | DESCARTADA
--   EM_ATENDIMENTO -> ENCERRADA
--   ENCERRADA e DESCARTADA são estados finais.
-- -----------------------------------------------------------------------------
CREATE FUNCTION fn_ocorrencia_antes_atualizar()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = OLD.status THEN
        RETURN NEW;
    END IF;

    IF NOT (
           (OLD.status = 'PENDENTE'       AND NEW.status IN ('VALIDADA', 'DESCARTADA'))
        OR (OLD.status = 'VALIDADA'       AND NEW.status IN ('EM_ATENDIMENTO', 'DESCARTADA'))
        OR (OLD.status = 'EM_ATENDIMENTO' AND NEW.status = 'ENCERRADA')
    ) THEN
        RAISE EXCEPTION 'Transição de status inválida para a ocorrência %: % -> %.',
                        OLD.id_ocorrencia, OLD.status, NEW.status
              USING ERRCODE = 'check_violation';
    END IF;

    -- RN03: validação e descarte só por agente público.
    IF NEW.status IN ('VALIDADA', 'DESCARTADA') THEN
        PERFORM fn_exigir_agente_publico(NEW.id_validador, 'validar ou descartar ocorrências');
        NEW.validada_em := COALESCE(NEW.validada_em, now());
    END IF;

    -- RN04: encerramento exige ao menos um atendimento concluído.
    IF NEW.status = 'ENCERRADA' AND NOT EXISTS (
        SELECT 1 FROM atendimento
         WHERE id_ocorrencia = NEW.id_ocorrencia
           AND fim IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'RN04: a ocorrência % não possui atendimento concluído e não pode ser encerrada.',
                        NEW.id_ocorrencia
              USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ocorrencia_antes_atualizar
    BEFORE UPDATE OF status ON ocorrencia
    FOR EACH ROW EXECUTE FUNCTION fn_ocorrencia_antes_atualizar();

-- -----------------------------------------------------------------------------
-- RF03: no máximo 5 fotos por ocorrência. A linha da ocorrência é bloqueada
-- (FOR UPDATE) para que dois envios simultâneos não ultrapassem o limite.
-- -----------------------------------------------------------------------------
CREATE FUNCTION fn_foto_limite()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    PERFORM 1 FROM ocorrencia WHERE id_ocorrencia = NEW.id_ocorrencia FOR UPDATE;

    IF (SELECT count(*) FROM foto WHERE id_ocorrencia = NEW.id_ocorrencia) >= 5 THEN
        RAISE EXCEPTION 'RF03: a ocorrência % já possui o máximo de 5 fotos.', NEW.id_ocorrencia
              USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_foto_limite
    BEFORE INSERT OR UPDATE OF id_ocorrencia ON foto
    FOR EACH ROW EXECUTE FUNCTION fn_foto_limite();

-- -----------------------------------------------------------------------------
-- ATENDIMENTO: responsável deve ser agente público (RN03) e a ocorrência deve
-- estar validada ou em atendimento. Ao abrir o primeiro atendimento, a
-- ocorrência passa automaticamente para EM_ATENDIMENTO.
-- -----------------------------------------------------------------------------
CREATE FUNCTION fn_atendimento_antes_gravar()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_status status_ocorrencia;
BEGIN
    PERFORM fn_exigir_agente_publico(NEW.id_responsavel, 'registrar atendimentos');

    SELECT status INTO v_status FROM ocorrencia WHERE id_ocorrencia = NEW.id_ocorrencia;

    IF TG_OP = 'INSERT' AND v_status NOT IN ('VALIDADA', 'EM_ATENDIMENTO') THEN
        RAISE EXCEPTION 'Atendimento só pode ser registrado para ocorrência VALIDADA ou EM_ATENDIMENTO (ocorrência %: %).',
                        NEW.id_ocorrencia, v_status
              USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_atendimento_antes_gravar
    BEFORE INSERT OR UPDATE OF id_responsavel, id_ocorrencia ON atendimento
    FOR EACH ROW EXECUTE FUNCTION fn_atendimento_antes_gravar();

CREATE FUNCTION fn_atendimento_apos_inserir()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE ocorrencia
       SET status = 'EM_ATENDIMENTO'
     WHERE id_ocorrencia = NEW.id_ocorrencia
       AND status = 'VALIDADA';
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_atendimento_apos_inserir
    AFTER INSERT ON atendimento
    FOR EACH ROW EXECUTE FUNCTION fn_atendimento_apos_inserir();

-- -----------------------------------------------------------------------------
-- ALERTA: somente agente público emite alertas (RN03).
-- -----------------------------------------------------------------------------
CREATE FUNCTION fn_alerta_antes_gravar()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    PERFORM fn_exigir_agente_publico(NEW.id_emissor, 'emitir alertas');
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_alerta_antes_gravar
    BEFORE INSERT OR UPDATE OF id_emissor ON alerta
    FOR EACH ROW EXECUTE FUNCTION fn_alerta_antes_gravar();
