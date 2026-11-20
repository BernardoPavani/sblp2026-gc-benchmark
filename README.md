# Análise do Desempenho de Estratégias de Garbage Collectors em Java (G1 GC vs. Generational ZGC)

Repositório oficial de replicabilidade contendo dados consolidados, gráficos e scripts de automação e análise estatística da pesquisa **"Análise do Desempenho de Estratégias de *Garbage Collectors* em Java"** (Trabalho de Conclusão de Curso — Departamento de Ciência da Computação, Universidade Federal de Lavras / padrão SBLP 2026).

**Autores:** Bernardo Pavani & Ricardo Terra (UFLA)

---

## Sobre a Pesquisa

Este estudo investiga empiricamente se, sob contenção realista de processamento (**4 núcleos físicos**, simulando contêineres e máquinas virtuais de nuvem) e escalonamento vertical de memória (**2 GB a 48 GB**), o retorno em desempenho justifica o custo de engenharia para migrar do coletor padrão da JVM (**G1 GC**) para o coletor concorrente de ultrabaixa latência (**Generational ZGC**) no **OpenJDK 21**.

A avaliação abrange **10 benchmarks da suíte DaCapo Chopin (`23.11-MR2-chopin`)** em **108 cenários comparativos diretos** (60 de Vazão e 48 de Latência de Cauda no percentil 99,99%), com dimensionamento amostral formal *a priori* ($N = 18$, derivado de estudo piloto $n=30$ via estatística $\hat{A}_{12}$ de Vargha-Delaney e correção ARE $\pi/3$ de Hodges-Lehmann) e inferência estatística não-paramétrica (Shapiro-Wilk e Wilcoxon-Mann-Whitney).

### Resumo dos Resultados ($\alpha = 0{,}10$, $N = 18$)
* **Não-normalidade:** 76 de 108 cenários (70,4%) rejeitam a normalidade no teste de Shapiro-Wilk, validando o uso de medianas e testes não-paramétricos.
* **Vazão (*Throughput* — 60 cenários):** o **G1 GC** venceu em **42 cenários (70,0%)** e empatou em 12 (20,0%), garantindo **90,0% de não-inferioridade** frente ao ZGC (6 vitórias / 10,0%).
* **Latência de Cauda (*Metered Latency* p99,99 — 48 cenários):** o **G1 GC** conquistou mais que o dobro de vitórias do concorrente (**15 vitórias / 31,2%** contra **7 vitórias / 14,6%** do ZGC, com 26 empates / 54,2%), mantendo **85,4% de não-inferioridade**.

---

## Estrutura do Repositório

```text
sblp2026-gc-benchmark/
├── data/
│   └── dados_consolidados.csv          # Base consolidada (2.760 execuções coletadas)
├── results/
│   └── figures/                        # Figuras oficiais em PDF (Vazão, Latência e Auditoria)
└── scripts/
    ├── bash/
    │   └── executar_bateria.sh         # Script de execução automatizada das simulações
    ├── python/
    │   └── exportar_csv.py             # Parser de logs brutos do DaCapo (.txt) para CSV
    └── r/
        ├── Graficos-AuditTomcat.R      # Geração das Figuras 2 e 3 + gráficos de auditoria
        └── validacao_metodologica.R    # Cálculo do N=18 (piloto n=30) e correlação de Spearman