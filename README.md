# Análise do Desempenho de Estratégias de Garbage Collectors em Java (G1 GC vs. Generational ZGC)

Repositório oficial de replicabilidade contendo dados consolidados, gráficos e scripts de automação e análise estatística da pesquisa **"Análise do Desempenho de Estratégias de *Garbage Collectors* em Java"** (Trabalho de Conclusão de Curso — Departamento de Ciência da Computação, Universidade Federal de Lavras / padrão SBLP 2026).

**Autores:** Bernardo Pavani & Ricardo Terra (UFLA)

---

## Sobre a Pesquisa

Este estudo investiga empiricamente se, sob contenção realista de processamento (**4 núcleos físicos**, simulando contêineres e máquinas virtuais de nuvem) e escalonamento vertical de memória (**2 GB a 48 GB**), o retorno em desempenho justifica o custo de engenharia para migrar do coletor padrão da JVM (**G1 GC**) para o coletor concorrente de ultrabaixa latência (**Generational ZGC**) no **OpenJDK 21**.

A avaliação abrange **10 benchmarks da suíte DaCapo Chopin (`23.11-MR2-chopin`)** em **108 cenários comparativos diretos** (60 de Vazão e 48 de Latência de Cauda no percentil 99,99%), com dimensionamento amostral formal *a priori* ($N = 18$, derivado de estudo piloto $n=30$ via estatística $\hat{A}_{12}$ de Vargha-Delaney e correção ARE $\pi/3$ de Hodges-Lehmann) e inferência estatística não-paramétrica (Shapiro-Wilk e Wilcoxon-Mann-Whitney).

### Resumo dos Resultados ($\alpha = 0{,}10$, $N = 18$)
- **Não-normalidade:** 76 de 108 cenários (70,4%) rejeitam a normalidade no teste de Shapiro-Wilk, validando o uso de medianas e testes não-paramétricos.
- **Vazão (*Throughput* — 60 cenários):** o **G1 GC** venceu em **42 cenários (70,0%)** e empatou em 12 (20,0%), garantindo **90,0% de não-inferioridade** frente ao ZGC (6 vitórias / 10,0%).
- **Latência de Cauda (*Metered Latency* p99,99 — 48 cenários):** o **G1 GC** conquistou mais que o dobro de vitórias do concorrente (**15 vitórias / 31,2%** contra **7 vitórias / 14,6%** do ZGC, com 26 empates / 54,2%), mantendo **85,4% de não-inferioridade**.

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
```

---

## Guia de Instalação para Reprodução (Linux / Ubuntu)

### 1. Clonar o Repositório

```bash
git clone https://github.com/BernardoPavani/sblp2026-gc-benchmark.git
cd sblp2026-gc-benchmark
```

### 2. Instalar Dependências de Sistema, OpenJDK 21, Python e R

```bash
sudo apt update
sudo apt install -y openjdk-21-jdk python3 r-base unzip wget util-linux
```

Confirme se a versão ativa do Java é o OpenJDK 21:

```bash
java -version
```

Instale os pacotes R exigidos pelos scripts de validação e geração de gráficos:

```bash
Rscript -e 'install.packages(c("ggplot2", "dplyr", "readr"), repos="https://cloud.r-project.org")'
```

### 3. Baixar e Instalar a Suíte DaCapo Chopin (`23.11-MR2-chopin`)

> **Atenção:** É necessário baixar o arquivo `.zip` completo (e não apenas o `.jar` isolado), pois benchmarks como `h2o`, `cassandra`, `spring` e `kafka` dependem da pasta de dados de carga distribuída no pacote.

```bash
mkdir -p dacapo && cd dacapo
wget https://download.sourceforge.net/project/dacapobench/23.11-chopin/dacapo-23.11-MR2-chopin.zip
unzip dacapo-23.11-MR2-chopin.zip
cd ..
```

*(Alternativamente, o pacote pode ser baixado manualmente na página oficial de releases: `dacapobench v23.11-chopin`.)*

Valide a instalação listando os benchmarks disponíveis:

```bash
java -jar dacapo/dacapo-23.11-MR2-chopin.jar -l
```

---

## Guia de Simulação e Reprodução

### Cenário A — Reproduzir Apenas a Validação Estatística e os Gráficos (com nossos dados)

Para validar imediatamente o dimensionamento amostral ($N = 18$), a independência das métricas (Spearman) e regenerar todos os gráficos em `results/figures/` sem precisar executar a JVM novamente:

```bash
Rscript scripts/r/validacao_metodologica.R
Rscript scripts/r/Graficos-AuditTomcat.R
```

### Cenário B — Executar as Simulações da JVM do Zero

1. **Verifique a topologia física da sua CPU (evitar SMT):**  
   O script confina a JVM em `taskset -c 0-3` (que no Ryzen 7 8700G mapeia para 4 núcleos físicos distintos). Antes de rodar na sua máquina, verifique os índices de núcleos físicos reais com:

   ```bash
   lscpu -e
   ```

   Se os 4 primeiros núcleos físicos do seu processador não forem `0-3`, ajuste a variável `NUCLEOS` em `scripts/bash/executar_bateria.sh`.

2. **Conceda permissão de execução ao script:**

   ```bash
   chmod +x scripts/bash/executar_bateria.sh
   ```

3. **Execute um teste rápido (*Smoke Test* com 1 repetição):**

   ```bash
   REPETICOES=1 sudo -E ./scripts/bash/executar_bateria.sh tomcat
   ```

4. **Execute a bateria oficial completa ($N = 18$):**

   ```bash
   # Executar apenas 1 benchmark (opções: tomcat, spring, tradesoap, tradebeans, h2, cassandra, kafka, lusearch, xalan, h2o)
   sudo ./scripts/bash/executar_bateria.sh tomcat

   # Executar toda a matriz dos 10 benchmarks (processo de longa duração)
   sudo ./scripts/bash/executar_bateria.sh all
   ```

   > **Nota de memória:** A matriz oficial escala a Heap até `48G` com `-XX:+AlwaysPreTouch` (pré-alocação física na RAM). Caso sua máquina possua menos de 64 GB de RAM, edite o array `HEAPS` dentro de `scripts/bash/executar_bateria.sh` para evitar *swapping*.

5. **Consolidar os novos logs em CSV e regenerar gráficos/estatísticas:**

   ```bash
   python3 scripts/python/exportar_csv.py
   Rscript scripts/r/validacao_metodologica.R
   Rscript scripts/r/Graficos-AuditTomcat.R
   ```

---

## Como Citar

```bibtex
@inproceedings{pavani2026gc,
  author    = {Bernardo Pavani and Ricardo Terra},
  title     = {Análise do Desempenho de Estratégias de Garbage Collectors em Java},
  booktitle = {30th Brazilian Symposium on Programming Languages (SBLP)},
  year      = {2026},
  address   = {São Paulo, SP, Brazil}
}
```
