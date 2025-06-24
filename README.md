# BigDataProject

## Introduction

The goal of this project was to develop an application capable of performing aggregate queries on a dataset related to crimes reported in the city of Chicago, available on the [Chicago Data Portal](https://data.cityofchicago.org/).  
This online service provides public access to detailed records of criminal incidents starting from 2001. The dataset is updated regularly and contains information on various types of crimes, excluding homicides (for which data is only available for the victims). 

The data, extracted from the Chicago Police Department's CLEAR system, does not disclose exact addresses but instead reports incidents at the block level to protect individual privacy.  
In addition to the data extracted from the Chicago Data Portal, it was also necessary to obtain information on the income and population of Chicago's community areas (to calculate the per capita income for each area). This data is available on the [Chicago Health Atlas](https://chicagohealthatlas.org/) website.

The purpose of the queries and the corresponding services exposed by our application is to conduct an exploratory analysis of this dataset, aiming to derive meaningful insights regarding crime patterns in Chicago.  
Specifically, the application was designed to extract relevant information from the crime data, build predictive models, and provide a web interface to explore and visualize the results.

## Task

The implemented task in this project could be divided in two partitions:

1) SQL-like queries
2) Machine learning prediction models

### SQL-like queries

The SQL queries aim to extract useful information from the dataset.  
They are simple queries designed to answer the following five questions:

1. **Crimes per Year**  
2. **Crime Category Distribution in a Particular Month**  
3. **Domestic Crimes in a Specific Community Area**  
4. **Theft Type Distribution** (high, low, non-theft crimes) in a Specific Community Area  
5. **Crimes per Year for a Selected Community Area and Location** (e.g., street, apartment, etc.)


### Machine-Learning data

The machine learning methods used in this project aim to extract useful information from the dataset.  
Some models are not strictly predictive; for example, clustering methods simply partition the macro areas of crimes based on geographical coordinates.

The implemented models can be summarized as follows:

- **Clustering**:  
  Used to divide the city into clusters based on the geographical coordinates of crimes. This method is not predictive but exploratory, helping to understand the spatial distribution of incidents.

- **Classification**:  
  Aimed at predicting whether an arrest will be made for a given crime. The model uses features such as Community Area, Month, and Crime Category to predict the arrest outcome (binary classification: arrest or no arrest).  
  Two algorithms were trained for this task:
  1) Logistic Regression
  2) Random Forest

- **Regression**:  
  Designed to analyze the correlation between per-capita income and per-capita crime rates. This model is intended for inference rather than prediction, aiming to explore possible relationships between economic factors and crime levels.

## Technical implementation

For the technical implementation, it was necessary to define an Apache Spark distributed engine using scala languagae.  
The frontend provided a simple way to visualize the information extracted from the dataset by the backend.

### Backend

The backend was developed in Scala using the **Cask** framework to handle REST operations.

### Frontend

The frontend was developed using the **Flutter** framework.  
To visualize the results, the following libraries were used:

1. **Flutter Map**:  
   Used to display the map of Chicago and show the crime locations.

2. **Syncfusion Chart**:  
   Used to display the necessary plots and charts.


