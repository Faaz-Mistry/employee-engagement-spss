* =====================================================================
* PROJECT 2: EMPLOYEE ENGAGEMENT ANALYSIS (Survey and group analysis)
* Data: IBM HR Analytics Employee Attrition & Performance (Kaggle), file
*       WA_Fn-UseC_-HR-Employee-Attrition.csv
* Question: What drives job satisfaction, and does it differ across
*           departments and groups?
* =====================================================================
* HOW TO RUN: change the path in the GET DATA command (section 1),
* then run the sections in order.
* NOTE: the satisfaction items are rated 1-4 (1 = Low ... 4 = Very High).
* =====================================================================


* ---------------------------------------------------------------------
* 1. LOAD DATA
* ---------------------------------------------------------------------
GET DATA
  /TYPE=TXT
  /FILE='C:\SPSS_Portfolio\engagement\WA_Fn-UseC_-HR-Employee-Attrition.csv'
  /ENCODING='UTF8'
  /DELCASE=LINE
  /DELIMITERS=","
  /QUALIFIER='"'
  /ARRANGEMENT=DELIMITED
  /FIRSTCASE=2
  /DATATYPEMIN PERCENTAGE=95.0
  /VARIABLES=
    Age F3.0
    Attrition A3
    BusinessTravel A17
    DailyRate F5.0
    Department A22
    DistanceFromHome F3.0
    Education F1.0
    EducationField A16
    EmployeeCount F1.0
    EmployeeNumber F5.0
    EnvironmentSatisfaction F1.0
    Gender A6
    HourlyRate F3.0
    JobInvolvement F1.0
    JobLevel F1.0
    JobRole A25
    JobSatisfaction F1.0
    MaritalStatus A8
    MonthlyIncome F6.0
    MonthlyRate F6.0
    NumCompaniesWorked F2.0
    Over18 A1
    OverTime A3
    PercentSalaryHike F2.0
    PerformanceRating F1.0
    RelationshipSatisfaction F1.0
    StandardHours F2.0
    StockOptionLevel F1.0
    TotalWorkingYears F2.0
    TrainingTimesLastYear F1.0
    WorkLifeBalance F1.0
    YearsAtCompany F2.0
    YearsInCurrentRole F2.0
    YearsSinceLastPromotion F2.0
    YearsWithCurrManager F2.0
  /MAP.
CACHE.
EXECUTE.
DATASET NAME hr WINDOW=FRONT.

* Drop constant columns that carry no information.
DELETE VARIABLES EmployeeCount StandardHours Over18.


* ---------------------------------------------------------------------
* 2. CLEANING, LABELS AND RECODES
* ---------------------------------------------------------------------
VARIABLE LABELS
  EnvironmentSatisfaction 'Satisfaction with work environment'
  JobSatisfaction 'Job satisfaction'
  RelationshipSatisfaction 'Satisfaction with colleague relationships'
  WorkLifeBalance 'Work-life balance'
  JobInvolvement 'Job involvement'
  MonthlyIncome 'Monthly income'
  YearsAtCompany 'Years at company'
  YearsSinceLastPromotion 'Years since last promotion'
  DistanceFromHome 'Distance from home'.

VALUE LABELS EnvironmentSatisfaction JobSatisfaction RelationshipSatisfaction JobInvolvement
  1 'Low' 2 'Medium' 3 'High' 4 'Very high'
  /WorkLifeBalance 1 'Bad' 2 'Good' 3 'Better' 4 'Best'.

* Numeric versions of string variables.
RECODE Department ('Human Resources'=1) ('Research & Development'=2) ('Sales'=3) INTO dept_n.
RECODE OverTime ('Yes'=1) ('No'=0) INTO overtime_n.
RECODE Gender ('Female'=0) ('Male'=1) INTO male_n.
RECODE Attrition ('Yes'=1) ('No'=0) INTO attrition_n.

VARIABLE LABELS dept_n 'Department' overtime_n 'Works overtime'
  male_n 'Male' attrition_n 'Left the company'.
VALUE LABELS dept_n 1 'Human Resources' 2 'Research & Development' 3 'Sales'
  /overtime_n 0 'No' 1 'Yes'
  /male_n 0 'Female' 1 'Male'
  /attrition_n 0 'Stayed' 1 'Left'.

* Dummy variables for department (Human Resources is the reference).
COMPUTE dept_rd = (dept_n = 2).
COMPUTE dept_sales = (dept_n = 3).
VARIABLE LABELS dept_rd 'Dept: R&D (vs HR)' dept_sales 'Dept: Sales (vs HR)'.

* Tenure band for a descriptive chart.
RECODE YearsAtCompany (0 thru 2=1) (3 thru 5=2) (6 thru 10=3) (11 thru Highest=4)
  INTO tenure_band.
VALUE LABELS tenure_band 1 '0-2 yrs' 2 '3-5 yrs' 3 '6-10 yrs' 4 '11+ yrs'.
VARIABLE LABELS tenure_band 'Tenure band'.

MEASURE /dept_n overtime_n male_n attrition_n tenure_band (NOMINAL)
  /EnvironmentSatisfaction JobSatisfaction RelationshipSatisfaction WorkLifeBalance JobInvolvement (ORDINAL).
EXECUTE.

* Data quality: missing values, ranges, outliers.
FREQUENCIES VARIABLES=JobSatisfaction EnvironmentSatisfaction RelationshipSatisfaction
    WorkLifeBalance JobInvolvement dept_n overtime_n
  /ORDER=ANALYSIS.
EXAMINE VARIABLES=MonthlyIncome YearsAtCompany DistanceFromHome
  /PLOT=BOXPLOT HISTOGRAM
  /STATISTICS=DESCRIPTIVES EXTREME
  /MISSING=LISTWISE.
* MonthlyIncome and YearsAtCompany are right-skewed. Decide whether to
* keep, cap or log-transform, and say so in your README.
COMPUTE ln_income = LN(MonthlyIncome).
VARIABLE LABELS ln_income 'Log of monthly income'.
EXECUTE.


* ---------------------------------------------------------------------
* 3. DESCRIPTIVES
* ---------------------------------------------------------------------
DESCRIPTIVES VARIABLES=Age MonthlyIncome YearsAtCompany DistanceFromHome
  /STATISTICS=MEAN STDDEV MIN MAX SKEWNESS KURTOSIS.
MEANS TABLES=JobSatisfaction BY dept_n BY overtime_n
  /CELLS=MEAN COUNT STDDEV.

GRAPH
  /BAR(SIMPLE)=MEAN(JobSatisfaction) BY dept_n
  /TITLE='Mean job satisfaction by department'.
GRAPH
  /BAR(SIMPLE)=MEAN(JobSatisfaction) BY overtime_n
  /TITLE='Mean job satisfaction by overtime status'.
GRAPH
  /BAR(SIMPLE)=MEAN(JobSatisfaction) BY tenure_band
  /TITLE='Mean job satisfaction by tenure'.


* ---------------------------------------------------------------------
* 4. SCALE RELIABILITY (Cronbach's alpha)
* ---------------------------------------------------------------------
* Treat the five rating items as a candidate "engagement" scale.
* Report alpha, and inspect "Cronbach's Alpha if Item Deleted" and the
* item-total correlations. These items come from different survey
* topics, so alpha may be low. If it is, report that honestly and use
* single items below instead of a composite score.
RELIABILITY
  /VARIABLES=EnvironmentSatisfaction JobSatisfaction RelationshipSatisfaction
             WorkLifeBalance JobInvolvement
  /SCALE('Engagement') ALL
  /MODEL=ALPHA
  /STATISTICS=DESCRIPTIVE SCALE CORR
  /SUMMARY=TOTAL.


* ---------------------------------------------------------------------
* 5. EXPLORATORY FACTOR ANALYSIS (PCA with varimax rotation)
* ---------------------------------------------------------------------
* Check KMO (should be above 0.6) and Bartlett's test (p < .05) first.
* Choose the number of factors using eigenvalues above 1 and the scree
* plot. Factor scores are saved as FAC1_1, FAC2_1, and so on.
FACTOR
  /VARIABLES EnvironmentSatisfaction JobSatisfaction RelationshipSatisfaction
             WorkLifeBalance JobInvolvement
             YearsAtCompany YearsInCurrentRole YearsSinceLastPromotion YearsWithCurrManager
  /MISSING LISTWISE
  /ANALYSIS EnvironmentSatisfaction JobSatisfaction RelationshipSatisfaction
             WorkLifeBalance JobInvolvement
             YearsAtCompany YearsInCurrentRole YearsSinceLastPromotion YearsWithCurrManager
  /PRINT INITIAL KMO EXTRACTION ROTATION
  /FORMAT SORT BLANK(.30)
  /PLOT EIGEN
  /CRITERIA MINEIGEN(1) ITERATE(25)
  /EXTRACTION PC
  /CRITERIA ITERATE(25)
  /ROTATION VARIMAX
  /SAVE REG(ALL)
  /METHOD=CORRELATION.
* Expect the four "years" variables to form a tenure factor. Whether the
* satisfaction items cluster into one factor is part of your finding.


* ---------------------------------------------------------------------
* 6. GROUP COMPARISONS: JOB SATISFACTION BY DEPARTMENT
* ---------------------------------------------------------------------
* 6a. One-way ANOVA with Levene's test, Welch correction and post-hoc.
*     If Levene's p < .05, read Welch and Games-Howell instead of ANOVA
*     and Tukey.
ONEWAY JobSatisfaction BY dept_n
  /STATISTICS DESCRIPTIVES HOMOGENEITY WELCH EFFECTS
  /PLOT MEANS
  /MISSING ANALYSIS
  /POSTHOC=TUKEY GH ALPHA(0.05).

* 6b. Normality check of the outcome within each department.
EXAMINE VARIABLES=JobSatisfaction BY dept_n
  /PLOT=NPPLOT HISTOGRAM
  /STATISTICS=DESCRIPTIVES
  /MISSING=LISTWISE.

* 6c. Kruskal-Wallis, a robust alternative because the outcome is a
*     4-point ordinal rating and not normally distributed.
NPAR TESTS
  /K-W=JobSatisfaction BY dept_n(1 3)
  /MISSING ANALYSIS.

* 6d. Two-group comparisons: overtime and gender.
T-TEST GROUPS=overtime_n(0 1)
  /MISSING=ANALYSIS
  /VARIABLES=JobSatisfaction
  /CRITERIA=CI(.95).
NPAR TESTS
  /M-W=JobSatisfaction BY overtime_n(0 1)
  /MISSING ANALYSIS.
T-TEST GROUPS=male_n(0 1)
  /MISSING=ANALYSIS
  /VARIABLES=JobSatisfaction
  /CRITERIA=CI(.95).

* 6e. Is satisfaction linked to leaving? Chi-square plus Cramer's V.
CROSSTABS
  /TABLES=JobSatisfaction BY attrition_n
  /STATISTICS=CHISQ PHI
  /CELLS=COUNT ROW.


* ---------------------------------------------------------------------
* 7. MULTIPLE LINEAR REGRESSION: PREDICTING JOB SATISFACTION
* ---------------------------------------------------------------------
* Checks to report: R-square and adjusted R-square, VIF (below 5 is
* fine), Durbin-Watson (about 2), residual histogram, normal P-P plot,
* and the ZRESID vs ZPRED scatterplot (look for a random cloud).
REGRESSION
  /MISSING LISTWISE
  /STATISTICS COEFF OUTS CI(95) R ANOVA COLLIN TOL
  /CRITERIA=PIN(.05) POUT(.10)
  /NOORIGIN
  /DEPENDENT JobSatisfaction
  /METHOD=ENTER EnvironmentSatisfaction RelationshipSatisfaction WorkLifeBalance
                JobInvolvement ln_income YearsAtCompany YearsSinceLastPromotion
                Age DistanceFromHome overtime_n male_n dept_rd dept_sales
  /SCATTERPLOT=(*ZRESID ,*ZPRED)
  /RESIDUALS DURBIN HISTOGRAM(ZRESID) NORMPROB(ZRESID)
  /SAVE COOK.

* Influential cases: Cook's distance above 4/n is worth a look.
COMPUTE influential = (COO_1 > 4/1470).
EXECUTE.
FREQUENCIES VARIABLES=influential.

* 7b. Sensitivity check: ordinal logistic regression, which respects the
*     ordered 4-point outcome. Compare the direction and significance of
*     effects with the linear model. If they agree, your conclusions are
*     robust.
PLUM JobSatisfaction BY overtime_n male_n dept_n WITH EnvironmentSatisfaction
    RelationshipSatisfaction WorkLifeBalance JobInvolvement ln_income YearsAtCompany
    YearsSinceLastPromotion Age DistanceFromHome
  /CRITERIA=CIN(95) DELTA(0) LCONVERGE(0) MXITER(100) MXSTEP(5) PCONVERGE(1.0E-6) SINGULAR(1.0E-8)
  /LINK=LOGIT
  /PRINT=FIT PARAMETER SUMMARY TPARALLEL.


* ---------------------------------------------------------------------
* 8. SAVE CLEAN DATA
* ---------------------------------------------------------------------
SAVE OUTFILE='C:\SPSS_Portfolio\engagement\hr_clean.sav'.
* File > Export to save the Viewer output as PDF or Word, and right-click
* charts > Export for README images.
