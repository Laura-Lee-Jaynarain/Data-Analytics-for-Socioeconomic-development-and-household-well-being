# SDHSA Low-Income Household Risk Predictor
# Milestone 3 - Task 4 Deployment

# Deploys the selected classification model (logistic regression,
# elastic net, model_glmnet.rds) chosen in Task 1-2. Supports:
# 1- Single-household scoring 
# 2- Batch scoring of a CSV of new households


library(shiny)
library(caret)
library(glmnet)
library(dplyr)

#Load model and training reference data 
model <- readRDS("model_glmnet.rds")
train_raw <- read.csv("train_data.csv", stringsAsFactors = FALSE)

predictor_cols <- c( "Province_clean", "GeoTypeCode","WaterSafe_label", "MainToiletCode_clean", "ElectricityAccess_label", "Loadshedding_ord",
                     "HouseholdSize_clean", "AdultHunger_ord", "MainIncomeSourceCode", "TotalVehicles_clean","AssetIndex", "WallMaterialCode", "RoofMaterial_clean", "TenureCode_clean", "RDPHousing_clean", "HousingSubsidy_clean", "DwellingConditionsScore")

numeric_predictors<- c("HouseholdSize_clean", "TotalVehicles_clean", "AssetIndex", "DwellingConditionsScore")

factor_predictors  <- setdiff(predictor_cols, numeric_predictors)

train_model <- train_raw[, predictor_cols]

#medians used at training time (fit on train only) and reused for new data
train_medians <- sapply(train_model[numeric_predictors], median, na.rm = TRUE)

#rebuild the exacct factor levels the model was trained on
level_list <- list()
for (col in factor_predictors) {
  v<- as.character(train_model[[col]])
  v[is.na(v) | v == ""] <- "Missing"
  level_list[[col]] <- sort(unique(v))
}


friendly_labels <- c(
  Province_clean = "Province",
  GeoTypeCode = "Geography type (coded, no codebook available)",
  WaterSafe_label   = "Water considered safe?",
  MainToiletCode_clean= "Main toiilet type (coded, no codebook available)",
  ElectricityAccess_label= "Electricity access",
  Loadshedding_ord = "Loadshedding frequency (ordered code)",
  HouseholdSize_clean = "Household size (people)",
  AdultHunger_ord = "Adult hunger frequency (ordered code)",
  MainIncomeSourceCode= "Main income source (coded, no codebook available)",
  TotalVehicles_clean= "Vehicles owned (code; 88/99 likely non-response in source data)",
  AssetIndex= "Asset index (0-7, composite of 7 owned assets)",
  WallMaterialCode= "Wall material (coded, no codebook available)",
  RoofMaterial_clean= "Roof material (coded, no codebook available)",
  TenureCode_clean= "Tenure type (coded, no codebook available)",
  RDPHousing_clean= "RDP housing status (coded)",
  HousingSubsidy_clean = "Housing subsidy status (coded)",
  DwellingConditionsScore = "Dwelling conditions score (0-3, higher = more issues)"
)


safe_level <- function(col, value) {
  value <- as.character(value)
  if (value %in% level_list[[col]]) value else "Missing"
}


build_row <- function(inputs) {
  row <- as.data.frame(inputs, stringsAsFactors = FALSE)
  for (col in numeric_predictors) {
    val <- suppressWarnings(as.numeric(row[[col]]))
    if (is.na(val)) val <- train_medians[[col]]
    row[[col]] <- val
  }
  for (col in factor_predictors) {
    lv <- level_list[[col]]
    row[[col]] <- factor(safe_level(col, row[[col]]), levels = lv)
  }
  row[, predictor_cols]
}

#score a batch data frame, validating columns required
score_batch <- function(df) {
  missing_cols <- setdiff(predictor_cols, names(df))
  if (length(missing_cols) > 0) {
    stop(paste("Missing required column(s):", paste(missing_cols, collapse = ", ")))
  }
  df_clean <- df
  for (col in numeric_predictors) {
    v <- suppressWarnings(as.numeric(df_clean[[col]]))
    v[is.na(v)] <- train_medians[[col]]
    df_clean[[col]] <- v
  }
  for (col in factor_predictors) {
    v <- as.character(df_clean[[col]])
    v[is.na(v) | v == ""] <- "Missing"
    v <- ifelse(v %in% level_list[[col]], v, "Missing")   # unseen codes -> Missing, not an error
    df_clean[[col]] <- factor(v, levels = level_list[[col]])
  }
  pred_class <- predict(model, newdata = df_clean[, predictor_cols])
  pred_prob  <- predict(model, newdata = df_clean[, predictor_cols], type = "prob")[, "Low"]
  out <- df
  out$Predicted_Class <- pred_class
  out$Low_Income_Probability <- round(pred_prob, 3)
  out
}

#UI
ui <- fluidPage(
  titlePanel("SDHSA Household Risk Predictor (Deployment Prototype)"),
  tags$p(
    "Predicts whether a household falls in the bottom income quartile (",
    tags$b("Low"), ") based on service access, assets and dwelling characteristics. ",
    "Model: logistic regression (elastic net), selected in Milestone 3 for its superior ",
    "sensitivity in identifying Low-income households."
  ),
  tags$div(
    style = "background:white; border:1px solid red; padding:10px; border-radius:4px; margin-bottom:15px;",
    tags$b("Known limitations (Task 3): "),
    "the model misses about  44% of true Low-income households (sensitivity ~ 0.56) and is less ",
    "reliable in Western Cape and Northern Cape. Treat outputs as a control tool, not a final decision."
  ),
  tabsetPanel(
    tabPanel("Single household",
             sidebarLayout(
               sidebarPanel(
                 width = 4,
                 lapply(predictor_cols, function(col) {
                   label <- friendly_labels[[col]]
                   if (col %in% numeric_predictors) {
                     numericInput(paste0("in_", col), label, value = round(train_medians[[col]]))
                   } else {
                     selectInput(paste0("in_", col), label, choices = level_list[[col]])
                   }
                 }),
                 actionButton("predict_btn", "Predict", class = "btn-primary")
               ),
               mainPanel(
                 width = 8,
                 h3("Prediction"),
                 uiOutput("single_result")
               )
             )
    ),
    tabPanel("Batch scoring (CSV)",
             sidebarPanel(
               width = 4,
               fileInput("batch_file", "Upload CSV of new households",
                         accept = c(".csv")),
               tags$p("The CSV must contain these columns:"),
               tags$pre(paste(predictor_cols, collapse = "\n")),
               downloadButton("download_scored", "Download scored CSV")
             ),
             mainPanel(
               width = 8,
               h3("Scored data (preview)"),
               tableOutput("batch_preview"),
               textOutput("batch_error")
             )
    ),
    tabPanel("About / Monitoring",
             h4("Deployment summary"),
             tags$ul(
               tags$li("Intended users: project/NGO staff or policy analysts deciding where to prioritise service access interventions"),
               tags$li("Decision supported: flagging households oor areas that are  likely to be in the Low income group for further review."),
               tags$li("Inputs: the 17 predictors used in Milestone 3 Task 1, namely province, service access, assets, dwelling and  income source."),
               tags$li("Output: the predicted class  (Low or Not Low) and predicted probability of Low.")
             ),
             h4("Monitoring plan"),
             tags$ul(
               tags$li("Performance threshold: train again should the  sensitivity on new labelled data drops below ~ 0.50 (current test-set sensitivity is 0.556), or ROC-AUC drops under 0.80 (currentis  0.879)."),
               tags$li("Drift indicator: large shifts in predictor distributions (e.g. province mix, asset index) versus the training data."),
               tags$li("Retraining trigger: new wave of survey data becomes available, or quarterly review shows metric drift beyond threshold."),
               tags$li("Retirement condition: if a newer data collection changes variable definitionsor codes such that the feature set is no longer comparable.")
             )
    )
  )
)

#SERVER
server <- function(input, output, session) {
  
  observeEvent(input$predict_btn, {
    inputs <- setNames(
      lapply(predictor_cols, function(col) input[[paste0("in_", col)]]),
      predictor_cols
    )
    row <- build_row(inputs)
    pred_class <- predict(model, newdata = row)
    pred_prob  <- predict(model, newdata = row, type = "prob")[, "Low"]
    
    output$single_result <- renderUI({
      colour <- if (pred_class == "Low") "hotpink" else "green"
      tagList(
        tags$h4(style = paste0("color:", colour, ";"),
                paste("Predicted class:", as.character(pred_class))),
        tags$p(paste0("Estimated probability of Low income: ", round(pred_prob * 100, 1), "%")),
        if (as.character(row$Province_clean) %in% c("Western Cape", "Northern Cape")) {
          tags$p(style = "color:black;", "Please note that this model is less reliable for Western Cape and  Northern Cape, treat with extra caution.")
        }
      )
    })
  })
  
  scored_batch <- reactive({
    req(input$batch_file)
    df <- read.csv(input$batch_file$datapath, stringsAsFactors = FALSE)
    score_batch(df)
  })
  
  output$batch_preview <- renderTable({
    tryCatch({
      head(scored_batch(), 10)
    }, error = function(e) {
      output$batch_error <- renderText(paste("Error:", e$message))
      NULL
    })
  })
  
  output$download_scored <- downloadHandler(
    filename = function() paste0("scored_households_", Sys.Date(), ".csv"),
    content = function(file) {
      write.csv(scored_batch(), file, row.names = FALSE)
    }
  )
}

shinyApp(ui, server)
