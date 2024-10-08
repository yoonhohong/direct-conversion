# 필요한 패키지 로드
library(SingleCellExperiment)
library(tradeSeq)
library(slingshot)
library(clusterProfiler)
library(org.Hs.eg.db)
library(dplyr)
library(ggplot2)
library(enrichplot)

# 저장된 RDS 파일을 불러오기 (이미 생성된 fitGAM, slingshot 객체 등을 로드)
sce_fitted <- readRDS("20240910_post_fitGAM.rds")
sds_filtered <- readRDS("slingshot_obj.rds")
imputed_pseudotime <- readRDS("pseudotime.rds")
cell_weights <- readRDS("cell_weights.rds")
final_counts <- readRDS("final_counts.rds")

# Lineage 할당 (가중치 기반으로 가장 강한 리니지 선택)
lineage_assignment <- apply(cell_weights, 1, which.max)

# 리니지별 세포 수 계산 및 출력
lineage_counts <- table(lineage_assignment)
cat("리니지별 세포 수:\n")
print(lineage_counts)

# 각 리니지에 속한 세포들 확인
weights_lineage_1 <- cell_weights[, "Lineage1"]
weights_lineage_2 <- cell_weights[, "Lineage2"]
weights_lineage_3 <- cell_weights[, "Lineage3"]

# 각 리니지에서 가장 높은 가중치를 가진 세포들 선택
cells_lineage_1_strict <- which(weights_lineage_1 > weights_lineage_2 & weights_lineage_1 > weights_lineage_3)
cells_lineage_2_strict <- which(weights_lineage_2 > weights_lineage_1 & weights_lineage_2 > weights_lineage_3)
cells_lineage_3_strict <- which(weights_lineage_3 > weights_lineage_1 & weights_lineage_3 > weights_lineage_2)

# 각 리니지에 속한 세포 수 출력
cat("리니지 1에 속한 세포 수:", length(cells_lineage_1_strict), "\n")
cat("리니지 2에 속한 세포 수:", length(cells_lineage_2_strict), "\n")
cat("리니지 3에 속한 세포 수:", length(cells_lineage_3_strict), "\n")

# 리니지 간 교집합 세포 확인
common_cells_12 <- intersect(cells_lineage_1_strict, cells_lineage_2_strict)
common_cells_13 <- intersect(cells_lineage_1_strict, cells_lineage_3_strict)
common_cells_23 <- intersect(cells_lineage_2_strict, cells_lineage_3_strict)
cat("리니지 1과 2의 교집합 세포 수:", length(common_cells_12), "\n")
cat("리니지 1과 3의 교집합 세포 수:", length(common_cells_13), "\n")
cat("리니지 2와 3의 교집합 세포 수:", length(common_cells_23), "\n")

###############################
### 리니지 1과 2에 대한 분석 ###
###############################

# Lineage 1과 2의 가중치(weight) 추출
weights_lineage_1 <- cell_weights[, "Lineage1"]
weights_lineage_2 <- cell_weights[, "Lineage2"]

# Lineage 1에서 더 높은 가중치를 가진 세포를 선택
cells_lineage_1_strict <- which(weights_lineage_1 > weights_lineage_2)

# Lineage 2에서 더 높은 가중치를 가진 세포를 선택
cells_lineage_2_strict <- which(weights_lineage_2 > weights_lineage_1)

# Lineage 1과 2에 속하는 세포 수 확인
cat("리니지 1에 더 강하게 속한 세포 수:", length(cells_lineage_1_strict), "\n")
cat("리니지 2에 더 강하게 속한 세포 수:", length(cells_lineage_2_strict), "\n")

# 두 리니지 모두에 속하는 세포들의 교집합 확인 (동시에 속한 세포 수)
common_cells_strict <- intersect(cells_lineage_1_strict, cells_lineage_2_strict)
cat("리니지 1과 2에 동시에 속하는 세포 수 (강하게 속하는 세포들):", length(common_cells_strict), "\n")

# Lineage 1과 2에 속하는 세포들을 선택하여 새로운 세포 그룹 구성
cells_lineage_1_2_strict <- c(cells_lineage_1_strict, cells_lineage_2_strict)

# sce_fitted 객체에서 해당 세포들만 선택하여 하위 집합 생성
sce_fitted_1_2_strict <- sce_fitted[, cells_lineage_1_2_strict]

# 발현이 거의 없는 유전자를 제거 (발현이 0인 유전자는 제외)
valid_genes_strict <- rowSums(assay(sce_fitted_1_2_strict, "counts")) > 10
sce_fitted_1_2_strict <- sce_fitted_1_2_strict[valid_genes_strict, ]

# patternTest 실행: 유전자 발현 패턴 분석
pattern_results_1_2_strict <- patternTest(sce_fitted_1_2_strict, nPoints = 100)

# FDR (False Discovery Rate) 계산 및 유의미한 유전자 선택
pattern_results_1_2_strict$FDR <- p.adjust(pattern_results_1_2_strict$pvalue, method = "fdr")
significant_genes_1_2_strict <- pattern_results_1_2_strict %>%
  filter(FDR < 0.05)

# 유의미한 유전자 수 출력
cat("리니지 1과 2에서 유의미한 유전자의 수:", nrow(significant_genes_1_2_strict), "\n")

# 유의미한 유전자 목록 추출 및 출력
significant_genes_1_2_list <- rownames(significant_genes_1_2_strict)
cat("리니지 1과 2에서 유의미한 유전자 목록:\n")
print(significant_genes_1_2_list)

# 유의미한 유전자 목록을 CSV 파일로 저장
write.csv(significant_genes_1_2_list, file = "20240917_significant_genes_1_2_strict.csv", row.names = FALSE)

#############################################
### 리니지 2과 3에 대한 분석 및 시각화 ###
#############################################

# Lineage 2와 3의 가중치(weight) 추출
weights_lineage_2 <- cell_weights[, "Lineage2"]
weights_lineage_3 <- cell_weights[, "Lineage3"]

# Lineage 2와 3에 더 강하게 속한 세포 선택
cells_lineage_2_strict <- which(weights_lineage_2 > weights_lineage_3)
cells_lineage_3_strict <- which(weights_lineage_3 > weights_lineage_2)

# 세포 수 확인
cat("리니지 2에 더 강하게 속한 세포 수:", length(cells_lineage_2_strict), "\n")
cat("리니지 3에 더 강하게 속한 세포 수:", length(cells_lineage_3_strict), "\n")

# 두 리니지에 동시에 속하는 세포 수 확인
common_cells_strict <- intersect(cells_lineage_2_strict, cells_lineage_3_strict)
cat("리니지 2와 3에 동시에 속하는 세포 수 (강하게 속하는 세포들):", length(common_cells_strict), "\n")

# 선택한 세포들로 하위 집합 생성
cells_lineage_2_3_strict <- c(cells_lineage_2_strict, cells_lineage_3_strict)
sce_fitted_2_3_strict <- sce_fitted[, cells_lineage_2_3_strict]

# 발현이 거의 없는 유전자 제거
valid_genes_strict <- rowSums(assay(sce_fitted_2_3_strict, "counts")) > 10
sce_fitted_2_3_strict <- sce_fitted_2_3_strict[valid_genes_strict, ]

# patternTest 실행
pattern_results_2_3_strict <- patternTest(sce_fitted_2_3_strict, nPoints = 100)

# FDR 계산 및 유의미한 유전자 선택
pattern_results_2_3_strict$FDR <- p.adjust(pattern_results_2_3_strict$pvalue, method = "fdr")
significant_genes_2_3_strict <- pattern_results_2_3_strict %>%
  filter(FDR < 0.05)

# 유의미한 유전자 수 출력 및 목록 확인
cat("리니지 2와 3에서 유의미한 유전자 수:", nrow(significant_genes_2_3_strict), "\n")
significant_genes_2_3_list <- rownames(significant_genes_2_3_strict)
cat("리니지 2와 3에서 유의미한 유전자 목록:\n")
print(significant_genes_2_3_list)

# 유전자 목록을 CSV로 저장
write.csv(significant_genes_2_3_list, file = "20240917_significant_genes_2_3_strict.csv", row.names = FALSE)

##################################
### 교집합 및 차집합 계산 ###
##################################

# 리니지 1-2와 리니지 2-3의 교집합 및 차집합 계산
common_genes12_23 <- intersect(significant_genes_1_2_list, significant_genes_2_3_list)
diff_1_2_only <- setdiff(significant_genes_1_2_list, significant_genes_2_3_list)
diff_2_3_only <- setdiff(significant_genes_2_3_list, significant_genes_1_2_list)

# 교집합과 차집합 결과 출력
cat("리니지 1-2와 리니지 2-3의 교집합 유전자 수:", length(common_genes12_23), "\n")
cat("리니지 1-2에만 있는 유전자 수:", length(diff_1_2_only), "\n")
cat("리니지 2-3에만 있는 유전자 수:", length(diff_2_3_only), "\n")

# 리니지별 차집합 유전자 목록 출력
cat("리니지 1-2에만 있는 유전자 목록:\n", diff_1_2_only, "\n")
cat("리니지 2-3에만 있는 유전자 목록:\n", diff_2_3_only, "\n")

###############################################
### GO 및 KEGG pathway 분석 (리니지 차집합) ###
###############################################

# 리니지 1-2 차집합 유전자에 대한 GO 및 KEGG pathway 분석
gene_list_1_2 <- bitr(diff_1_2_only, fromType = "SYMBOL", toType = "ENTREZID", OrgDb = org.Hs.eg.db)
go_results_1_2 <- enrichGO(gene = gene_list_1_2$ENTREZID, OrgDb = org.Hs.eg.db, ont = "BP", pAdjustMethod = "BH")
kegg_results_1_2 <- enrichKEGG(gene = gene_list_1_2$ENTREZID, organism = 'hsa', pvalueCutoff = 0.05)

# 리니지 2-3 차집합 유전자에 대한 GO 및 KEGG pathway 분석
gene_list_2_3 <- bitr(diff_2_3_only, fromType = "SYMBOL", toType = "ENTREZID", OrgDb = org.Hs.eg.db)
go_results_2_3 <- enrichGO(gene = gene_list_2_3$ENTREZID, OrgDb = org.Hs.eg.db, ont = "BP", pAdjustMethod = "BH")
kegg_results_2_3 <- enrichKEGG(gene = gene_list_2_3$ENTREZID, organism = 'hsa', pvalueCutoff = 0.05)

# GO 및 KEGG 분석 결과 시각화
dotplot(go_results_1_2, title = "GO terms for lineage 1-2 specific genes")
ggsave("20240920_GOdotplot12.png", plot = dotplot(go_results_1_2, title = "GO terms for lineage 1-2 specific genes"), width = 8, height = 6, units = "in", dpi = 600)
dotplot(go_results_2_3, title = "GO terms for lineage 2-3 specific genes")
ggsave("20240920_GOdotplot23.png", plot = dotplot(go_results_2_3, title = "GO terms for lineage 2-3 specific genes"), width = 8, height = 6, units = "in", dpi = 600)
dotplot(kegg_results_1_2, title = "KEGG Pathways for lineage 1-2 specific genes")
ggsave("20240917_dotplot12.png", plot = dotplot(kegg_results_1_2, title = "KEGG Pathways for lineage 1-2 specific genes"), width = 8, height = 6, units = "in", dpi = 600)
dotplot(kegg_results_2_3, title = "KEGG Pathways for lineage 2-3 specific genes")
ggsave("20240917_dotplot23.png", plot = dotplot(kegg_results_2_3, title = "KEGG Pathways for lineage 2-3 specific genes"), width = 8, height = 6, units = "in", dpi = 600)

# GO 및 KEGG 분석 결과의 유사성 계산
go_results_1_2_sim <- pairwise_termsim(go_results_1_2)
go_results_2_3_sim <- pairwise_termsim(go_results_2_3)
kegg_results_1_2_sim <- pairwise_termsim(kegg_results_1_2)
kegg_results_2_3_sim <- pairwise_termsim(kegg_results_2_3)

# Emapplot (유사성 네트워크 시각화) 생성
emapplot(go_results_1_2_sim, showCategory = 10)
ggsave("20240920_GOemapplot12.png", plot = last_plot(), width = 8, height = 6, units = "in", dpi = 600)

emapplot(go_results_2_3_sim, showCategory = 10)
ggsave("20240920_GOemapplot23.png", plot = last_plot(), width = 8, height = 6, units = "in", dpi = 600)

emapplot(kegg_results_1_2_sim, showCategory = 10)
ggsave("20240920_KEGGemapplot12.png", plot = last_plot(), width = 8, height = 6, units = "in", dpi = 600)

emapplot(kegg_results_2_3_sim, showCategory = 10)
ggsave("20240920_KEGGemapplot23.png", plot = last_plot(), width = 8, height = 6, units = "in", dpi = 600)

############################################
### 신경 관련 경로에서 유전자 발현 시각화 ###
############################################

# KEGG 경로 분석 결과를 보기 쉽게 변환 (geneID를 읽기 가능한 형식으로 변환)
kegg_gene_sets <- setReadable(kegg_results_2_3, OrgDb = org.Hs.eg.db, keyType = "ENTREZID")

# 데이터 프레임으로 변환하여 'kegg_gene_sets_df'로 저장
kegg_gene_sets_df <- as.data.frame(kegg_gene_sets)

# KEGG 경로 분석 결과에서 신경 퇴행성 질환에 해당하는 유전자 목록 추출
neuro_diseases <- c("Parkinson disease", 
                    "Alzheimer disease", "Prion disease",
                    "Pathways of neurodegeneration - multiple diseases")

# 각 질환별 유전자 목록 추출
neuro_genes_list <- list()

for (disease in neuro_diseases) {
  # 해당 질환에 대한 유전자 목록 추출
  gene_ids <- kegg_gene_sets_df[kegg_gene_sets_df$Description == disease, "geneID"]
  
  # 유전자 ID를 분리하고 고유한 유전자 목록 생성
  neuro_genes_list[[disease]] <- unique(unlist(strsplit(gene_ids, "/")))
}

# 결과 확인 (예: 각 질환별 유전자 수 출력)
for (disease in neuro_diseases) {
  cat(paste("질환:", disease, "- 유전자 수:", length(neuro_genes_list[[disease]]), "\n"))
}

# Parkinson, ALS, Huntington, Prion, Neurodegeneration 유전자 목록 확인
print(neuro_genes_list)

# 특정 유전자를 정의
gene <- "NDUFB2"  # 분석하고자 하는 유전자

# plotSmoothers로 시각화한 ggplot 객체를 저장
p <- plotSmoothers(sce_fitted, counts = final_counts, gene = gene)

# y축 범위를 조정한 그래프에 유전자 이름을 제목으로 추가
p_adjusted <- p + 
  scale_y_continuous(limits = c(1, 1.5)) +  # y축 범위 설정
  labs(title = paste("Gene Expression Pattern for", gene))  # 유전자 이름을 제목으로 추가

# 그래프 저장
ggsave("20240924_gene_expression_plot.png", plot = p_adjusted, width = 8, height = 6, dpi = 600)

# 특정 유전자를 정의
gene2 <- "UQCRB"  # 분석하고자 하는 유전자

# plotSmoothers로 시각화한 ggplot 객체를 저장
p2 <- plotSmoothers(sce_fitted, counts = final_counts, gene = gene2)

# y축 범위를 조정한 그래프에 유전자 이름을 제목으로 추가
p2_adjusted <- p2 + 
  scale_y_continuous(limits = c(1.2, 1.6)) +  # y축 범위 설정
  labs(title = paste("Gene Expression Pattern for", gene2))  # 유전자 이름을 제목으로 추가

# 그래프 저장
ggsave("20240924_gene_expression_plot2.png", plot = p2_adjusted, width = 8, height = 6, dpi = 600)

# 특정 유전자를 정의
gene3 <- "PTGS2"  # 분석하고자 하는 유전자

# plotSmoothers로 시각화한 ggplot 객체를 저장
p3 <- plotSmoothers(sce_fitted, counts = final_counts, gene = gene3)

# y축 범위를 조정한 그래프에 유전자 이름을 제목으로 추가
p3_adjusted <- p3 + 
  scale_y_continuous(limits = c(0, 1.7)) +  # y축 범위 설정
  labs(title = paste("Gene Expression Pattern for", gene3))  # 유전자 이름을 제목으로 추가

# 그래프 저장
ggsave("20240924_gene_expression_plot3.png", plot = p3_adjusted, width = 8, height = 6, dpi = 600)

# 특정 유전자를 정의
gene4 <- "COX7C"  # 분석하고자 하는 유전자

# plotSmoothers로 시각화한 ggplot 객체를 저장
p4 <- plotSmoothers(sce_fitted, counts = final_counts, gene = gene4)

# y축 범위를 조정한 그래프에 유전자 이름을 제목으로 추가
p4_adjusted <- p4 + 
  scale_y_continuous(limits = c(1.2, 1.6)) +  # y축 범위 설정
  labs(title = paste("Gene Expression Pattern for", gene4))  # 유전자 이름을 제목으로 추가

# 그래프 저장
ggsave("20240924_gene_expression_plot4.png", plot = p4_adjusted, width = 8, height = 6, dpi = 600)

# 특정 유전자를 정의
gene5 <- "COX6C"  # 분석하고자 하는 유전자

# plotSmoothers로 시각화한 ggplot 객체를 저장
p5 <- plotSmoothers(sce_fitted, counts = final_counts, gene = gene5)

# y축 범위를 조정한 그래프에 유전자 이름을 제목으로 추가
p5_adjusted <- p5 + 
  scale_y_continuous(limits = c(1.2, 1.6)) +  # y축 범위 설정
  labs(title = paste("Gene Expression Pattern for", gene5))  # 유전자 이름을 제목으로 추가

# 그래프 저장
ggsave("20240924_gene_expression_plot5.png", plot = p5_adjusted, width = 8, height = 6, dpi = 600)
