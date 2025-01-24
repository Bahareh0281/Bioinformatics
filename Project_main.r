# نصب کتابخانه‌های لازم
install.packages("dplyr")
install.packages("ggplot2")
install.packages("readr")
install.packages("GenomicRanges")

library(dplyr)
library(ggplot2)
library(readr)
library(GenomicRanges)

# مرحله 1: بارگذاری داده‌ها
case_data <- read.table("PC_case.txt", header = FALSE, sep = "\t", stringsAsFactors = FALSE)
control_data <- read.table("PC_control.txt", header = FALSE, sep = "\t", stringsAsFactors = FALSE)
gene_data <- read.table("geneList.txt", header = FALSE, sep = "\t", stringsAsFactors = FALSE)

# نامگذاری ستون‌ها
colnames(case_data) <- c("chromosome", "start", "end", "variation", "patient_id")
colnames(control_data) <- c("chromosome", "start", "end", "variation", "patient_id")
colnames(gene_data) <- c("gene_id", "chromosome", "gene_start", "gene_end")

# مرحله 2: شناسایی مناطق مهم
# ایجاد GRanges برای Case و Control
case_gr <- GRanges(seqnames = case_data$chromosome,
                   ranges = IRanges(start = case_data$start, end = case_data$end),
                   variation = case_data$variation)

control_gr <- GRanges(seqnames = control_data$chromosome,
                      ranges = IRanges(start = control_data$start, end = control_data$end),
                      variation = control_data$variation)

# پیدا کردن مناطق منحصر به فرد در Case
unique_case <- setdiff(case_gr, control_gr)

# مرحله 3: تطبیق مناطق با ژن‌ها
gene_gr <- GRanges(seqnames = gene_data$chromosome,
                   ranges = IRanges(start = gene_data$gene_start, end = gene_data$gene_end),
                   gene_id = gene_data$gene_id)

# پیدا کردن ژن‌های مرتبط با CNVها
overlaps <- findOverlaps(unique_case, gene_gr)
genes_in_regions <- gene_data[subjectHits(overlaps), ]

# ذخیره ژن‌ها در فایل خروجی
write.csv(genes_in_regions, "genes_associated_with_cnv.csv", row.names = FALSE)

# مرحله 4: بصری‌سازی
# توزیع CNVها
ggplot(case_data, aes(x = chromosome)) +
  geom_bar(fill = "blue") +
  theme_minimal() +
  labs(title = "توزیع CNVها در Case", x = "کروموزوم", y = "تعداد")

# مرحله 5: ذخیره مناطق مهم
write.csv(as.data.frame(unique_case), "unique_cnv_regions.csv", row.names = FALSE)

