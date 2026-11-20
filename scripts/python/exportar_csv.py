#!/usr/bin/env python3
"""
Consolidador de logs da suíte DaCapo Chopin -> dados_consolidados.csv
Extrai Vazão (tempo wall-clock da 5ª iteração em ms) e Latência de Cauda
Metrificada (percentil 99.99%, em ms) dos arquivos .txt gerados pelo script Bash.
"""

import csv
import re
from pathlib import Path

DIR_LOGS = Path("logs")
ARQUIVO_SAIDA = Path("data/dados_consolidados.csv")

BENCHMARKS = [
    "Tomcat", "Tomcat_Auditoria", "Spring", "TradeSOAP", "TradeBeans",
    "H2", "Cassandra", "Kafka", "Lusearch", "Xalan", "H2O"
]
HEAPS = ["2G", "4G", "8G", "16G", "32G", "48G"]
COLETORES = ["G1", "ZGC"]

REGEX_VAZAO = re.compile(r"PASSED in (\d+) msec")
REGEX_LAT_9999 = re.compile(r"metered full smoothing:.*?99\.99%\s+(\d+)\s+usec")
REGEX_LAT_999 = re.compile(r"metered full smoothing:.*?99\.9%\s+(\d+)\s+usec")


def extrair_metricas(arquivo_txt: Path):
    conteudo = arquivo_txt.read_text(encoding="utf-8", errors="ignore")

    # Pega sempre a última ocorrência (5ª iteração, após 4 ciclos de warm-up)
    matches_vazao = REGEX_VAZAO.findall(conteudo)
    if not matches_vazao:
        return None, None
    vazao_ms = float(matches_vazao[-1])

    matches_lat = REGEX_LAT_9999.findall(conteudo)
    if not matches_lat:
        matches_lat = REGEX_LAT_999.findall(conteudo)

    # Cargas em lote (Xalan e H2O) não emitem Metered Latency -> fica vazio (NA no R)
    latencia_ms = round(int(matches_lat[-1]) / 1000.0, 3) if matches_lat else ""
    return vazao_ms, latencia_ms


def main():
    ARQUIVO_SAIDA.parent.mkdir(parents=True, exist_ok=True)
    linhas = []

    for bench in BENCHMARKS:
        for heap in HEAPS:
            for coletor in COLETORES:
                pasta = DIR_LOGS / bench / coletor
                if not pasta.exists():
                    continue

                arquivos = sorted(
                    pasta.glob(f"dacapo_heap{heap}_it*.txt"),
                    key=lambda p: int(re.search(r"_it(\d+)\.txt$", p.name).group(1)),
                )

                for arq in arquivos:
                    it = int(re.search(r"_it(\d+)\.txt$", arq.name).group(1))
                    vazao_ms, latencia_ms = extrair_metricas(arq)
                    if vazao_ms is not None:
                        linhas.append([bench, heap, coletor, it, vazao_ms, latencia_ms])

    with ARQUIVO_SAIDA.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["Benchmark", "Heap", "Coletor", "Iteracao", "Vazao_ms", "Latencia_ms"])
        writer.writerows(linhas)

    print(f"CSV consolidado gerado com sucesso em '{ARQUIVO_SAIDA}' ({len(linhas)} registros).")


if __name__ == "__main__":
    main()