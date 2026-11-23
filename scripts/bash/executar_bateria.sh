#!/usr/bin/env bash
# ==============================================================================
# EXECUÇÃO AUTOMATIZADA DE BENCHMARKS - SBLP 2026 (G1 GC vs. Generational ZGC)
# Uso:
#   sudo ./scripts/bash/executar_bateria.sh tomcat       # Executa 1 benchmark
#   sudo ./scripts/bash/executar_bateria.sh all          # Executa todos os 10
# ==============================================================================
set -euo pipefail

BENCH_ALVO="${1:-all}"
DACAPO_JAR="${DACAPO_JAR:-./dacapo/dacapo-23.11-MR2-chopin.jar}"
DIR_LOGS="${DIR_LOGS:-./logs}"
REPETICOES="${REPETICOES:-18}"   # Oficial: 18 (piloto Tomcat usou 30; baterias brutas usaram 20)
THREADS_APP=4
NUCLEOS="0-3"                    # 4 núcleos físicos isolados sem SMT (taskset)
HEAPS=("2G" "4G" "8G" "16G" "32G" "48G")
COLETORES=("G1" "ZGC")

# Mapeamento: argumento CLI do DaCapo -> Nome padronizado no CSV
declare -A MAPA_NOMES=(
  ["tomcat"]="Tomcat"
  ["spring"]="Spring"
  ["tradesoap"]="TradeSOAP"
  ["tradebeans"]="TradeBeans"
  ["h2"]="H2"
  ["cassandra"]="Cassandra"
  ["kafka"]="Kafka"
  ["lusearch"]="Lusearch"
  ["xalan"]="Xalan"
  ["h2o"]="H2O"
)

ORDEM_BENCHMARKS=("tomcat" "spring" "tradesoap" "tradebeans" "h2" "cassandra" "kafka" "lusearch" "xalan" "h2o")

if [[ ! -f "$DACAPO_JAR" ]]; then
  echo "ERRO: JAR do DaCapo Chopin não encontrado em: $DACAPO_JAR"
  echo "Consulte o README.md para baixar e extrair a suíte 23.11-MR2-chopin."
  exit 1
fi

executar_um_benchmark() {
  local bench_cli="$1"
  local bench_nome="${MAPA_NOMES[$bench_cli]}"

  # Flags de compatibilidade exigidas no OpenJDK 21
  local extra_flags=()
  if [[ "$bench_cli" == "cassandra" ]]; then
    extra_flags+=("-Djava.security.manager=allow")
  elif [[ "$bench_cli" == "h2o" ]]; then
    extra_flags+=("-Dsys.ai.h2o.debug.allowJavaVersions=21")
  fi

  mkdir -p "${DIR_LOGS}/${bench_nome}/G1" "${DIR_LOGS}/${bench_nome}/ZGC"

  echo "======================================================================"
  echo " INICIANDO BATERIA: $bench_nome ($bench_cli) | N=$REPETICOES | CPUs=$NUCLEOS"
  echo "======================================================================"

  for ((i=1; i<=REPETICOES; i++)); do
    echo ">>> RODADA GLOBAL: $i/$REPETICOES ($bench_nome) <<<"

    for HEAP in "${HEAPS[@]}"; do
      for COLETOR in "${COLETORES[@]}"; do
        local dir_saida="${DIR_LOGS}/${bench_nome}/${COLETOR}"
        local log_gc="${dir_saida}/gc_heap${HEAP}_it${i}.log"
        local log_dacapo="${dir_saida}/dacapo_heap${HEAP}_it${i}.txt"

        local gc_flags=()
        if [[ "$COLETOR" == "G1" ]]; then
          gc_flags+=("-XX:+UseG1GC")
        else
          gc_flags+=("-XX:+UseZGC" "-XX:+ZGenerational")
        fi

        echo "  [$(date '+%H:%M:%S')] Heap=$HEAP | GC=$COLETOR | Rodada $i/$REPETICOES"

        # 1. Higienização do cache de páginas do sistema operacional
        sync && echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null

        # 2. Execução isolada em 4 núcleos físicos com pré-alocação física de RAM
        taskset -c "$NUCLEOS" java \
          -Xms"$HEAP" -Xmx"$HEAP" \
          -XX:+AlwaysPreTouch \
          "${gc_flags[@]}" \
          "${extra_flags[@]}" \
          -Xlog:gc*=info:file="$log_gc":uptime,level,tags \
          -jar "$DACAPO_JAR" "$bench_cli" \
          -t "$THREADS_APP" \
          -s default \
          -n 5 \
          -no-pre-iteration-gc \
          > "$log_dacapo" 2>&1 || echo "AVISO: falha em $bench_nome ($HEAP/$COLETOR/it$i)"
      done
    done

    # 3. Resfriamento térmico ao fim de cada rodada global
    echo "Resfriando o processador por 15s..."
    sleep 15
  done
}

if [[ "$BENCH_ALVO" == "all" ]]; then
  for b in "${ORDEM_BENCHMARKS[@]}"; do
    executar_um_benchmark "$b"
  done
elif [[ -n "${MAPA_NOMES[$BENCH_ALVO]:-}" ]]; then
  executar_um_benchmark "$BENCH_ALVO"
else
  echo "Benchmark inválido: $BENCH_ALVO"
  echo "Opções válidas: all ${ORDEM_BENCHMARKS[*]}"
  exit 1
fi

echo "Bateria concluída! Execute 'python3 scripts/python/exportar_csv.py' para consolidar o CSV."
