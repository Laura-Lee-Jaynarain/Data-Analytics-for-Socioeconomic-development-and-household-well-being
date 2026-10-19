# SOCIOECONOMIC DEVELOPMENT & HOUSEHOLD WELL-BEING IN SOUTH AFRICA (SDHSA)

---
**Project Case Study**__
In South Africa, many households lack full access to basic services. This lack of access is closely tied to poverty. Financially challenged households are usually the ones missing these services. Government departments have limited money to spend on infrastructure, so they need to know which service gaps matter the most, so that they can spend that money where it will be of help to most people.
## Project overview

**Business Question.**
Which basic service (electricity, water or sanitation) is most strongly linked to household poverty in South Africa, so that a limited infrastructure budget can go where it helps most?

**project activity summary**
We combined five household survey files (20,925 households), cleaned and checked them, defined "Low income" as the poorest quarter of households, and compared three prediction models. We tested them on 4,096 households the models had never been trained on. Of which Logistic regression (elastic net) was the most suitable; on the test set it finds 55.6% of low-income households (sensitivity), clears 93.0% of the others (specificity) and has an AUC of 0.879. We used regression and clustering as support checks, and deployed the selected model as an R Shiny app.

**Main Analytical finding.**
No single service is the strongest signal of poverty. Of the three, sanitation (toilet type) is the most consistent. Electricity shows a big gap in the raw numbers, but it affects few households and the link disappears once other factors are included. Water safety shows no link. Income source, assets and household size are stronger signals than any service. These are patterns in one survey, not proof of cause and effect.

---

##  Project reflection

### What worked

- Writing every data step as Problem, Treatment, Verification. Each cleaning decision could be defended with a before-and-after count.
- Checking join keys and row counts before and after every join. This showed exactly where households were lost (15 records with "UNMATCHED" IDs and 15 duplicate households) and that the final table has one row per household.
- Keeping the three services as separate predictors. We built a combined `ServiceAccessScore` but did not use it for modelling, because it would have hidden which service matters most, and that is the question we were asked.
- Removing income-based columns from the predictors and doing median imputation on the training set only. This kept the test results honest.
- Using the same random seed (381), the same train/test split and the same cross-validation folds for all three models, so the comparison was fair and repeatable.
- Judging the models by how many poor households they find (sensitivity), not by accuracy alone. About 3 in 4 households are not poor, so a model that always says "not poor" would already be about 74% accurate.
- Putting the preprocessing in one reusable function, so the notebook and the Shiny app treat new data in exactly the same way.

### What surprised us

- Water safety showed no link to poverty. Households whose water was "not considered safe" were slightly less likely to be in the poorest group than other households.
- Electricity had a large gap in the raw numbers , but only about 5% of households lack access, and in the model the effect disappeared once other factors were included.
- Small households looked poorer than large ones. This is because the survey records income per household, not per person.
- The income column held placeholder values was 999999. The average income was R11,752 but the typical (median) income was only R5,030.
- The model was weakest in the Western Cape , Northern Cape and Gauteng. Gauteng also has the most low-income households, so this matters.

### What changed across the milestones

- Milestone 1 started with four core datasets (D05, D06, D07, D09) and marked D04 Dwelling Conditions as "pending / support". In Milestone 2 we included D04, which added the dwelling conditions score and brought the model to 17 predictors.
- The feature engineering grew from three derived features to a fuller set (asset index, dwelling score, log income, household size bands, ordered factors, low-income flag).
- The modelling started as one classification task. In Milestone 3 we added regression and clustering as cross-checks, and chose R Shiny over Plumber, flexdashboard and Power BI for deployment.
- In Milestone 4 the report was rewritten in plain language for non-technical readers, and the dashboard reports weighted population figures.

### What we learned

- Most of the work, and most of the important decisions, are in data preparation. The three models differ by only a few percentage points, but removing the composite score and the income leakage changed what the results can say.
- Accuracy can be misleading when one class is much smaller. The metric has to match the cost of the mistake: here, missing a poor household is worse than a false alarm.
- A good overall score can hide unfair performance. The province check showed weaknesses that the overall numbers did not.
- Association is not causation. Our data is a single self-reported survey, so we can say what goes together, not what causes what.
- Documenting as we go is much easier than reconstructing decisions afterwards.

---

## 4. Dependencies

The notebook was run and tested with R 4.3.3. Packages and the versions used:

- tidyverse 2.0.0 (data handling and charts)
- rsample 1.2.0 (train/test split)
- caret 6.0-94 (model training, cross-validation, metrics)
- glmnet 4.1-8 (elastic-net logistic and linear regression)
- rpart 4.1-23 (decision tree)
- randomForest 4.7-1.1 (random forest)
- pROC 1.18.5 (ROC curves and AUC)
- cluster 2.1.6 (clustering check)
- knitr 1.45 and rmarkdown 2.25 (producing the report)
- scales 1.3.0 (number formatting)
- rpart.plot (optional, only for the tree diagram)
- shiny (only for the app, see `ModelingAndDeployment/README.md`)

Install them once with:

```r
install.packages(c("tidyverse", "rsample", "caret", "glmnet", "rpart", "randomForest",
                   "pROC", "cluster", "knitr", "rmarkdown", "scales"))
```
Dependencies found using copilot summarisation

---

## Reproducability

1. Install R (4.3 or newer) and the packages above.
2. Put the five survey files in the `Data/` folder.
3. Open the project folder as your working directory (or open it in RStudio).
4. Run one of these:

```r
source("R/run_all.R")                       
rmarkdown::render("Final_Analysis.Rmd")     
```

## Project Structure

**By CRISP-DM stage.** 

1. Business understanding
2. Data understanding 
3. Data preparation 
5. Evaluation 
6. Deployment 
---

##  Monitoring and maintenance

The deployed model is a screening aid. A person must always review its results before any decision about resources.

Review it at least once every quarter. Recalculate the numbers below on any new households whose true income is known.

- **Sensitivity (share of low-income households found).** Currently 0.556. If it falls below about 0.50, retrain.
- **AUC.** Currently 0.879. If it falls below 0.80, retrain.
- **Changes in the households.** If the mix of provinces, asset scores or dwelling scores changes noticeably compared with the training data, investigate before trusting new predictions.
- **New survey wave.** Retrain and check the model again.
- **Changed variable codes.** If a future survey changes what the codes mean, retire this model and rebuild the feature set.

**To retrain:** add the new data to `Data/`, delete the `models/` folder, re-run `source("R/run_all.R")`, check the numbers in section 5 against the new results, then copy the new `model_glmnet.rds` and the new `train_data.csv` into `ModelingAndDeployment/` (the app uses the training file to rebuild its factor levels and medians).

---

##  Handover notes

**Decisions that should not be undone without good reason**

- `ServiceAccessScore` stays out of the models, so the three services can be compared with each other.
- Income, log income and anything built from income stay out of the predictors, to prevent leakage.
- median Imputation values are learned from the training data only, and the same values are reused for new data in the app.
- Households with no usable income are recorded but excluded from training data.

**Things to know**

- "Low income" means the poorest 25% of the surveyed households. It is not an official poverty line, and it is household income, not income per person.
- Dashboard figures are weighted by survey weights. Model figures are unweighted . Do not compare them directly.
- Some codes have no codebook (toilet type, income source, geography type, wall material). Very small categories, such as toilet types 10 and 12 (22 and 57 households), are unreliable.
- `MainIncomeSourceCode` overlaps closely with income itself, so it should not be read as an independent cause.
- The model finds the fewest low-income households in the Western Cape, Northern Cape and Gauteng. The app currently shows its caution message for the Western Cape and Northern Cape only, so Gauteng should be added.

---

##  Ethics and responsible AI use

- The data describes the income and living conditions of households. No household is identified anywhere in the outputs.
- The results are patterns in survey data and should never be used on their own to decide whether a household receives help. A "NotLow" prediction is not a reason to refuse support.
- AI tools were used during the project, for example to help write and test R code, structure notebooks and draft report text. All AI use is recorded in the responsible AI usage log, and all code was run and checked by the team.
