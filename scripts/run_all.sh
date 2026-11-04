#!/usr/bin/env bash
# =============================================================================
# Recria o banco do Alerta Fogo Araguaia do zero e executa todos os scripts.
#
# Uso:
#   ./scripts/run_all.sh                  # usa o banco padrão do psql
#   PGDATABASE=alerta ./scripts/run_all.sh
#   ./scripts/run_all.sh --sem-testes     # não executa tests/
#
# As variáveis padrão do PostgreSQL (PGHOST, PGPORT, PGUSER, PGPASSWORD,
# PGDATABASE) definem a conexão.
# =============================================================================
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXECUTAR_TESTES=1
[[ "${1:-}" == "--sem-testes" ]] && EXECUTAR_TESTES=0

PSQL=(psql -X -q -v ON_ERROR_STOP=1 --pset=pager=off)

executar() {
    echo "==> $1"
    PGOPTIONS="-c client_min_messages=warning -c timezone=America/Cuiaba" "${PSQL[@]}" -f "$RAIZ/$1"
}

echo "==> Removendo esquema anterior (se existir)"
"${PSQL[@]}" -c "SET client_min_messages = warning; DROP SCHEMA IF EXISTS alerta_fogo CASCADE;"

for arquivo in \
    sql/schema/01_extensoes_tipos.sql \
    sql/schema/02_tabelas_cadastro.sql \
    sql/schema/03_tabelas_ocorrencia.sql \
    sql/schema/04_tabelas_alerta_foco.sql \
    sql/schema/05_regras_negocio.sql \
    sql/schema/06_views.sql \
    sql/dados/01_cadastros.sql \
    sql/dados/02_ocorrencias.sql \
    sql/dml/01_atualizacoes.sql \
    sql/dml/02_remocoes.sql
do
    executar "$arquivo"
done

if [[ $EXECUTAR_TESTES -eq 1 ]]; then
    echo "==> tests/test_regras_negocio.sql"
    PGOPTIONS="-c timezone=America/Cuiaba" "${PSQL[@]}" < "$RAIZ/tests/test_regras_negocio.sql"
fi

echo "==> Banco criado com sucesso. Consultas de exemplo: sql/consultas/consultas.sql"
