-- =============================================================================
-- Alerta Fogo Araguaia | DML 02 - Operações de remoção (DELETE)
-- -----------------------------------------------------------------------------
-- Demonstra remoções seguras e o comportamento das chaves estrangeiras:
--   ON DELETE CASCADE  -> FOTO acompanha a OCORRENCIA (composição);
--   ON DELETE RESTRICT -> não se apaga usuário que registrou ocorrências;
--   ON DELETE SET NULL -> foco de satélite perde a localidade, mas é mantido.
-- =============================================================================
SET search_path TO alerta_fogo, public;

-- D1 | Remove uma foto enviada por engano (ocorrência 1 continua com 2 fotos).
DELETE FROM foto
 WHERE caminho_arquivo = 'uploads/ocorrencias/1/foto-03.jpg'
RETURNING id_foto, id_ocorrencia, caminho_arquivo;

-- D2 | Remove a ocorrência de teste 12 (descartada). As fotos dela são
--      removidas automaticamente pelo ON DELETE CASCADE.
SELECT count(*) AS fotos_da_ocorrencia_12_antes FROM foto WHERE id_ocorrencia = 12;

DELETE FROM ocorrencia
 WHERE id_ocorrencia = 12
   AND status = 'DESCARTADA'
   AND NOT EXISTS (SELECT 1 FROM atendimento a WHERE a.id_ocorrencia = 12)
RETURNING id_ocorrencia, status;

SELECT count(*) AS fotos_da_ocorrencia_12_depois FROM foto WHERE id_ocorrencia = 12;

-- D3 | Remove um morador que nunca registrou ocorrência.
DELETE FROM usuario u
 WHERE u.email  = 'helena.barbosa@exemplo.org'
   AND u.perfil = 'MORADOR'
   AND NOT EXISTS (SELECT 1 FROM ocorrencia o WHERE o.id_usuario = u.id_usuario)
RETURNING id_usuario, nome;

-- D4 | Tentativa de remover um morador COM ocorrências: a FK com RESTRICT
--      impede a remoção e preserva o histórico. O erro é capturado para que o
--      script continue e mostre a mensagem.
DO $$
BEGIN
    DELETE FROM usuario WHERE id_usuario = 7;
    RAISE NOTICE 'Inesperado: usuário 7 removido.';
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Remoção bloqueada pela integridade referencial: %', SQLERRM;
END;
$$;

-- D5 | LGPD (RNF06): quando um morador com ocorrências pede a exclusão da
--      conta, os dados pessoais são anonimizados em vez de apagar a linha,
--      o que mantém as estatísticas e o histórico de atendimentos.
UPDATE usuario
   SET nome           = 'Usuário removido',
       email          = 'removido-' || id_usuario || '@anonimo.invalid',
       telefone       = NULL,
       senha_hash     = crypt(gen_random_uuid()::text, gen_salt('bf', 8)),
       recebe_alertas = FALSE,
       ativo          = FALSE
 WHERE id_usuario = 13
RETURNING id_usuario, nome, email, ativo;

-- D6 | Retenção de dados: remove focos de satélite com mais de um ano em
--      relação ao início da estação seca analisada (01/08/2026). Em produção,
--      a data de referência seria current_date.
DELETE FROM foco_satelite
 WHERE data_hora < TIMESTAMPTZ '2026-08-01 00:00-04' - INTERVAL '1 year'
RETURNING id_foco, data_hora, satelite;
