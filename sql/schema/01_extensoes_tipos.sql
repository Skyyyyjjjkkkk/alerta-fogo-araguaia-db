-- =============================================================================
-- Alerta Fogo Araguaia | 01 - Esquema, extensões e tipos enumerados
-- -----------------------------------------------------------------------------
-- Cria o esquema isolado do projeto e os tipos de domínio usados nas tabelas.
-- Os tipos ENUM garantem que só valores válidos sejam gravados nas colunas de
-- perfil, status e nível de risco (restrição de domínio).
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS alerta_fogo;
SET search_path TO alerta_fogo, public;

-- pgcrypto fornece crypt()/gen_salt() para gravar senhas com hash bcrypt (RNF05).
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;

-- Perfis de acesso do sistema (RF01).
CREATE TYPE perfil_usuario AS ENUM ('MORADOR', 'AGENTE_PUBLICO', 'ADMINISTRADOR');

-- Ciclo de vida da ocorrência (diagrama de classe: StatusOcorrencia; RN01 e RN04).
CREATE TYPE status_ocorrencia AS ENUM (
    'PENDENTE',        -- registrada pelo morador, aguardando validação
    'VALIDADA',        -- confirmada por um agente público
    'EM_ATENDIMENTO',  -- há atendimento em andamento
    'ENCERRADA',       -- atendimento concluído
    'DESCARTADA'       -- não confirmada (exige justificativa)
);

-- Nível de risco dos alertas emitidos para uma localidade (RF08).
CREATE TYPE nivel_risco AS ENUM ('BAIXO', 'MODERADO', 'ALTO', 'CRITICO');
