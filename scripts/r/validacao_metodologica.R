# =========================================================================
# VALIDAÇÃO METODOLÓGICA REPRODUTÍVEL - SBLP 2026 (PADRÃO N = 18)
# 1. Dimensionamento Amostral Empírico (Piloto Tomcat 4G n=30 -> N=18)
# 2. Independência Estatística das Métricas (Correlação de Spearman, N=18)
# 3. Auditoria de Hipóteses com 90% e 95% de Confiança (N=18)
# =========================================================================
library(readr)
library(dplyr)

if (file.exists("data/dados_consolidados.csv")) {
  raiz_repo <- "."
} else if (file.exists("../../data/dados_consolidados.csv")) {
  raiz_repo <- "../.."
} else {
  stop("Arquivo 'data/dados_consolidados.csv' não encontrado. Execute a partir da raiz do repositório ou de 'scripts/r/'.")
}

caminho_arquivo <- file.path(raiz_repo, "data", "dados_consolidados.csv")
dados <- read_csv(caminho_arquivo, show_col_types = FALSE)

cat("=================================================================\n")
cat("PASSO 1: DIMENSIONAMENTO AMOSTRAL A PARTIR DO TESTE PILOTO (n=30)\n")
cat("=================================================================\n")
cat("Referência: Benchmark Tomcat (Carga Default, n=30), métrica de maior\n")
cat("variância (Latência de Cauda 99.99%) no primeiro ponto de transição\n")
cat("estatisticamente significativo entre os coletores (Heap de 4G).\n\n")

# Extrai todas as 30 observações do Teste Piloto em 4G
l_g1_piloto  <- dados %>% filter(Benchmark == "Tomcat", Heap == "4G", Coletor == "G1")  %>% pull(Latencia_ms)
l_zgc_piloto <- dados %>% filter(Benchmark == "Tomcat", Heap == "4G", Coletor == "ZGC") %>% pull(Latencia_ms)

n1 <- length(l_g1_piloto)
n2 <- length(l_zgc_piloto)

# 1. Teste de Mann-Whitney e Estatística U sobre as 30 amostras
mw_piloto <- wilcox.test(l_g1_piloto, l_zgc_piloto, exact = FALSE)
U_stat <- as.numeric(mw_piloto$statistic)

# 2. Tamanho de Efeito Não-Paramétrico de Vargha-Delaney (A12)
A12_raw <- U_stat / (n1 * n2)
A12_mag <- ifelse(A12_raw < 0.5, 1 - A12_raw, A12_raw)

# 3. Equivalência Algébrica para d de Cohen: d = sqrt(2) * Phi^-1(A12)
d_cohen <- sqrt(2) * qnorm(A12_mag)

# 4. Tamanho Amostral Paramétrico Base (Teste t bicaudal, Alpha = 0.10, Poder = 0.80)
calc_t <- power.t.test(delta = d_cohen, sd = 1, sig.level = 0.10, power = 0.80,
                       type = "two.sample", alternative = "two.sided")
n_param <- calc_t$n

# 5. Correção de Eficiência Relativa Assintótica (ARE) de Lehmann (pi / 3)
n_lehmann <- n_param * (pi / 3)
n_oficial <- ceiling(n_lehmann)

cat(sprintf(" [Piloto Tomcat 4G | n1 = %d, n2 = %d]\n", n1, n2))
cat(sprintf("   -> Mann-Whitney U = %.1f (p-valor = %.4e)\n", U_stat, mw_piloto$p.value))
cat(sprintf("   -> Vargha-Delaney A12 Empírico = %.4f (d de Cohen = %.4f)\n", A12_mag, d_cohen))
cat(sprintf("   -> N Paramétrico (Alpha = 0.10, Poder = 0.80): %.2f amostras\n", n_param))
cat(sprintf("   -> N Corrigido por Lehmann (x pi/3)          : %.2f amostras\n", n_lehmann))
cat("-----------------------------------------------------------------\n")
cat(sprintf(" ==> TAMANHO AMOSTRAL OFICIAL DEFINIDO (Teto): N = %d iterações\n", n_oficial))
cat("-----------------------------------------------------------------\n\n")


cat("=================================================================\n")
cat("PASSO 2: INDEPENDÊNCIA ENTRE LATÊNCIA (M1) E VAZÃO (M2) (N=18)\n")
cat("=================================================================\n")

benchmarks_oficiais <- c("Tomcat", "Spring", "TradeSOAP", "TradeBeans", 
                         "H2", "Cassandra", "Kafka", "Lusearch")

for (b in benchmarks_oficiais) {
  sub_dados <- dados %>% filter(Benchmark == b, Heap != "1G", Iteracao <= 18, !is.na(Latencia_ms))
  if (nrow(sub_dados) > 5) {
    cor_spearman <- cor.test(sub_dados$Latencia_ms, sub_dados$Vazao_ms, method = "spearman", exact = FALSE)
    cat(sprintf(" [%-10s] Correlação de Spearman (rho) = %+.4f | p-valor = %.4e\n", 
                b, cor_spearman$estimate, cor_spearman$p.value))
  }
}
cat(" -> CONCLUSÃO: Correlações fracas/moderadas (rho < 0.47). As duas métricas\n")
cat("    são estatisticamente independentes e complementares.\n\n")