# =========================================================================
# GERACAO DE GRAFICOS - SBLP 2026 (10 BENCHMARKS + AUDITORIA TOMCAT)
# =========================================================================
library(ggplot2)
library(dplyr)
library(readr)

# Detecta automaticamente a raiz do repositório (funciona da raiz ou de scripts/r/)
if (file.exists("data/dados_consolidados.csv")) {
  raiz_repo <- "."
} else if (file.exists("../../data/dados_consolidados.csv")) {
  raiz_repo <- "../.."
} else {
  stop("Arquivo 'data/dados_consolidados.csv' não encontrado. Execute a partir da raiz do repositório ou de 'scripts/r/'.")
}

caminho_arquivo <- file.path(raiz_repo, "data", "dados_consolidados.csv")
dir_figuras <- file.path(raiz_repo, "results", "figures")
dados <- read_csv(caminho_arquivo, show_col_types = FALSE)

# Garantir filtro padrao N <= 18 e ordenacao dos Heaps
dados_limpos <- dados %>%
  filter(Heap != "1G", Iteracao <= 18)

dados_limpos$Heap <- factor(dados_limpos$Heap, levels = c("2G", "4G", "8G", "16G", "32G", "48G"))

# =========================================================================
# PARTE A: GRAFICOS OFICIAIS DOS 10 BENCHMARKS (FORMATO COMPACTO HORIZONTAL)
# =========================================================================
ordem_10_benchmarks <- c("Tomcat", "Spring", "TradeSOAP", "TradeBeans", 
                         "H2", "Cassandra", "Kafka", "Lusearch", "Xalan", "H2O")

dados_principais <- dados_limpos %>%
  filter(Benchmark %in% ordem_10_benchmarks) %>%
  mutate(Benchmark = factor(Benchmark, levels = intersect(ordem_10_benchmarks, unique(Benchmark))))

# Substitua os blocos de plot_latencia e plot_vazao no seu script R por estes:

dados_latencia <- dados_principais %>%
  filter(!is.na(Latencia_ms)) %>%
  group_by(Benchmark, Heap, Coletor) %>%
  summarize(
    Mediana = median(Latencia_ms, na.rm = TRUE),
    Q1 = quantile(Latencia_ms, 0.25, na.rm = TRUE),
    Q3 = quantile(Latencia_ms, 0.75, na.rm = TRUE),
    .groups = "drop"
  )

plot_latencia <- ggplot(dados_latencia, aes(x = Heap, y = Mediana, fill = Coletor, color = Coletor)) +
  geom_errorbar(aes(ymin = Q1, ymax = Q3), width = 0.25, linewidth = 0.5,
                position = position_dodge(width = 0.5), color = "gray30") +
  geom_point(shape = 21, size = 3.4, position = position_dodge(width = 0.5), color = "black") +
  facet_wrap(~ Benchmark, scales = "free_y", ncol = 4) +
  theme_bw(base_size = 11) +
  scale_fill_manual(values = c("G1" = "#2c7bb6", "ZGC" = "#d7191c")) +
  labs(title = expression("Latência de Cauda (99.99%) por " * italic("Benchmark") * " e Tamanho de " * italic("Heap")),
       subtitle = "Medianas e Intervalo Interquartil (Q1-Q3) sob contenção de 4 Núcleos (N=18, Menor é melhor)",
       x = expression("Tamanho de " * italic("Heap") * " (GB)"),
       y = "Latência Mediana (ms)",
       fill = expression(italic("Garbage Collector"))) +
  theme(legend.position = "bottom", strip.background = element_rect(fill = "lightgray"),
        strip.text = element_text(face = "bold"), panel.grid.major.x = element_blank())

dados_vazao <- dados_principais %>%
  filter(!is.na(Vazao_ms)) %>%
  group_by(Benchmark, Heap, Coletor) %>%
  summarize(
    Mediana = median(Vazao_ms, na.rm = TRUE),
    Q1 = quantile(Vazao_ms, 0.25, na.rm = TRUE),
    Q3 = quantile(Vazao_ms, 0.75, na.rm = TRUE),
    .groups = "drop"
  )

plot_vazao <- ggplot(dados_vazao, aes(x = Heap, y = Mediana, fill = Coletor, color = Coletor)) +
  geom_errorbar(aes(ymin = Q1, ymax = Q3), width = 0.25, linewidth = 0.5,
                position = position_dodge(width = 0.5), color = "gray30") +
  geom_point(shape = 21, size = 3.4, position = position_dodge(width = 0.5), color = "black") +
  facet_wrap(~ Benchmark, scales = "free_y", ncol = 5) +
  theme_bw(base_size = 11) +
  scale_fill_manual(values = c("G1" = "#2c7bb6", "ZGC" = "#d7191c")) +
  labs(title = expression("Vazão (Tempo Total de Execução) por " * italic("Benchmark") * " e Tamanho de " * italic("Heap")),
       subtitle = "Medianas e Intervalo Interquartil (Q1-Q3) sob contenção de 4 Núcleos (N=18, Menor é melhor)",
       x = expression("Tamanho de " * italic("Heap") * " (GB)"),
       y = "Tempo Total Mediano (ms)",
       fill = expression(italic("Garbage Collector"))) +
  theme(legend.position = "bottom", strip.background = element_rect(fill = "lightgray"),
        strip.text = element_text(face = "bold"), panel.grid.major.x = element_blank())

dir.create(dir_figuras, recursive = TRUE, showWarnings = FALSE)
ggsave(file.path(dir_figuras, "grafico_latencia_10bench.pdf"), plot = plot_latencia, width = 13, height = 4.6)
ggsave(file.path(dir_figuras, "grafico_vazao_10bench.pdf"), plot = plot_vazao, width = 14, height = 4.6)

# =========================================================================
# PARTE B: PAINEL ISOLADO DE AUDITORIA (TOMCAT ORIGINAL vs TOMCAT AUDITORIA)
# =========================================================================
if ("Tomcat_Auditoria" %in% unique(dados_limpos$Benchmark)) {
  dados_auditoria <- dados_limpos %>%
    filter(Benchmark %in% c("Tomcat", "Tomcat_Auditoria")) %>%
    mutate(Benchmark = factor(Benchmark, levels = c("Tomcat", "Tomcat_Auditoria"),
                              labels = c("Tomcat (Bateria 1 - Original)", "Tomcat (Bateria 2 - Auditoria)"))) %>%
    group_by(Benchmark, Heap, Coletor) %>%
    summarize(
      Latencia_Mediana = median(Latencia_ms, na.rm = TRUE),
      Vazao_Mediana = median(Vazao_ms, na.rm = TRUE),
      .groups = "drop"
    )
  
  plot_aud_lat <- ggplot(dados_auditoria, aes(x = Heap, y = Latencia_Mediana, fill = Coletor)) +
    geom_point(shape = 21, size = 4.5, position = position_dodge(width = 0.5), color = "black") +
    facet_wrap(~ Benchmark, ncol = 2) +
    theme_bw(base_size = 12) +
    scale_fill_manual(values = c("G1" = "#2c7bb6", "ZGC" = "#d7191c")) +
    labs(title = "Auditoria de Reprodutibilidade: Latência de Cauda no Tomcat (N=18)",
         subtitle = "Comparação direta sob mesma escala vertical entre duas baterias independentes",
         x = "Tamanho do Heap (GB)", y = "Latência Mediana 99.99% (ms)", fill = "Garbage Collector") +
    theme(legend.position = "bottom",
          strip.background = element_rect(fill = "lightgray"),
          strip.text = element_text(face = "bold"),
          panel.grid.major.x = element_blank())
  
  plot_aud_vaz <- ggplot(dados_auditoria, aes(x = Heap, y = Vazao_Mediana, fill = Coletor)) +
    geom_point(shape = 21, size = 4.5, position = position_dodge(width = 0.5), color = "black") +
    facet_wrap(~ Benchmark, ncol = 2) +
    theme_bw(base_size = 12) +
    scale_fill_manual(values = c("G1" = "#2c7bb6", "ZGC" = "#d7191c")) +
    labs(title = "Auditoria de Reprodutibilidade: Vazão (Tempo Total) no Tomcat (N=18)",
         subtitle = "Comparação direta sob mesma escala vertical entre duas baterias independentes",
         x = "Tamanho do Heap (GB)", y = "Tempo Total Mediano (ms)", fill = "Garbage Collector") +
    theme(legend.position = "bottom",
          strip.background = element_rect(fill = "lightgray"),
          strip.text = element_text(face = "bold"),
          panel.grid.major.x = element_blank())
  
  print(plot_aud_lat)
  print(plot_aud_vaz)
  
  ggsave(file.path(dir_figuras, "auditoria_tomcat_latencia.pdf"), plot = plot_aud_lat, width = 11, height = 5.0)
  ggsave(file.path(dir_figuras, "auditoria_tomcat_vazao.pdf"), plot = plot_aud_vaz, width = 11, height = 5.0)
}