install.packages("caret")
install.packages("randomForest")

# Load necessary libraries
library(dplyr)
library(tidyr)
library(readr)
library(caret)
library(randomForest)
library(ggplot2)

# Load datasets
case_data <- read_csv('PC_case.csv', col_names = FALSE)
control_data <- read_csv('PC_control.csv', col_names = FALSE)
gene_data <- read_csv('geneList.csv', col_names = FALSE)

# Rename columns for clarity
colnames(case_data) <- c('Chromosome', 'Start', 'End', 'Type', 'Patient_ID')
colnames(control_data) <- c('Chromosome', 'Start', 'End', 'Type', 'Patient_ID')
colnames(gene_data) <- c('Gene_ID', 'Chromosome_ID', 'Chromosome', 'Gene_Start', 'Gene_End')

# Combine case and control data
case_data <- mutate(case_data, target = 1)
control_data <- mutate(control_data, target = 0)
combined_data <- bind_rows(case_data, control_data)

# Map significant regions to genes
map_to_genes <- function(chromosome, start, end, genes) {
  overlapping_genes <- genes %>%
    filter(Chromosome == paste0("chr", chromosome),
           Gene_End >= start,
           Gene_Start <= end)
  paste(overlapping_genes$Gene_ID, collapse = ";")
}

combined_data <- combined_data %>%
  rowwise() %>%
  mutate(Associated_Genes = map_to_genes(Chromosome, Start, End, gene_data))

# Export the combined data to a CSV file
write_csv(combined_data, "combined_data.csv")

# Feature engineering
combined_data <- combined_data %>%
  mutate(VariationLength = End - Start) %>%
  select(-Patient_ID)

# One-Hot Encoding
encoded_data <- combined_data %>%
  mutate(across(c(Chromosome, Type, Associated_Genes), as.factor)) %>%
  model.matrix(~ . - 1, data = .) %>%
  as.data.frame()

# Train a model
set.seed(42)
X <- encoded_data %>% select(-target)
y <- encoded_data$target
train_index <- createDataPartition(y, p = 0.8, list = FALSE)
X_train <- X[train_index, ]
X_test <- X[-train_index, ]
y_train <- y[train_index]
y_test <- y[-train_index]

model <- randomForest(X_train, as.factor(y_train))

# Evaluate the model
y_pred <- predict(model, X_test)
confusion_matrix <- confusionMatrix(as.factor(y_pred), as.factor(y_test))
print(confusion_matrix)

# Feature importance
feature_importance <- data.frame(Feature = colnames(X_train), Importance = importance(model)) %>%
  arrange(desc(Importance))

# Identify significant genes
gene_columns <- grep("Associated_Genes_", colnames(encoded_data), value = TRUE)
significant_genes <- encoded_data %>%
  filter(target == 1) %>%
  select(all_of(gene_columns)) %>%
  summarise(across(everything(), sum)) %>%
  pivot_longer(everything(), names_to = "Gene", values_to = "Count") %>%
  arrange(desc(Count))

write_csv(significant_genes, "significant_genes.csv")

# Gene counts
significant_genes <- read_csv("significant_genes.csv")

# Split the genes and count occurrences
gene_counts <- significant_genes %>%
  separate_rows(Gene, sep = ";") %>%
  count(Gene, name = "Count") %>%
  arrange(desc(Count))

write_csv(gene_counts, "gene_counts.csv")

# Plot the top 20 genes with the highest counts
top_genes <- head(gene_counts, 20)

ggplot(top_genes, aes(x = reorder(Gene, Count), y = Count)) +
  geom_bar(stat = "identity", fill = "skyblue") +
  coord_flip() +
  labs(title = "Top 20 Genes with Highest Counts", x = "Gene", y = "Count") +
  theme_minimal()