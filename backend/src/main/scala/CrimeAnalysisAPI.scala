import org.apache.spark.ml.clustering.KMeans
import org.apache.spark.ml.feature.{OneHotEncoder, StandardScaler, StringIndexer, VectorAssembler}
import org.apache.spark.ml.evaluation.{BinaryClassificationEvaluator, ClusteringEvaluator, MulticlassClassificationEvaluator}
import org.apache.spark.ml.regression.LinearRegression
import org.apache.spark.ml.classification.{DecisionTreeClassifier, LogisticRegression, RandomForestClassificationModel, RandomForestClassifier}
import org.apache.spark.sql.functions.udf
import org.apache.spark.sql.functions._
import org.apache.spark.sql.{DataFrame, SparkSession, functions}
import org.apache.spark.ml.Pipeline
import cask.model.Response

import scala.language.postfixOps


object CrimeAnalysisAPI extends cask.MainRoutes {

  // Initialize SparkSession
  // The asterisk in "local[*]" tells Spark to use all available cores.
  val spark: SparkSession = SparkSession.builder()
    .appName("Bigdata_Project")
    .master("local[*]")
    .getOrCreate()

  // val sparkContext = spark.sparkContext
  // sparkContext.setLogLevel("ERROR")

  // Load the DataFrame
  private val dfPolice = spark.read
    .option("header", value = true)
    .option("inferSchema", value = true)
    .csv("data/Crimes_-_2001_to_Present.csv")
  // dfPolice.show() // print the first 20 rows
  // dfPolice.printSchema() // print the database schema

  import spark.implicits._

  /**
   * Adds CORS headers to the HTTP response.
   * This method ensures that the API can be accessed from different origins,
   * allowing web browsers to make cross-origin requests.
   *
   * @param response The raw Cask response.
   * @return The Cask response with added CORS headers.
   */
  def withCorsHeaders(response: cask.Response.Raw): cask.Response.Raw = {
    response.copy(headers = response.headers ++ Seq(
      "Access-Control-Allow-Origin" -> "*",
      "Access-Control-Allow-Methods" -> "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers" -> "Content-Type, Authorization",
      "Access-Control-Allow-Credentials" -> "true"
    ))
  }

  // --- Machine Learning Methods ---

  /**
   * Performs K-Means clustering on crime data based on Latitude and Longitude.
   * It identifies spatial clusters of crime incidents and calculates the silhouette score
   * to evaluate the quality of the clustering.
   *
   * @return A DataFrame containing the Latitude, Longitude, and predicted cluster for each crime,
   * limited to the first 1000 predictions.
   */
  def runClustering(): DataFrame = {
    val dfCluster = dfPolice.select($"Latitude", $"Longitude")
      .where($"Latitude".isNotNull && $"Longitude".isNotNull)

    val assembler = new VectorAssembler()
      .setInputCols(Array("Latitude", "Longitude"))
      .setOutputCol("features")

    val featureDF = assembler.transform(dfCluster)

    val kmeans = new KMeans().setK(4).setSeed(1L)
    val model = kmeans.fit(featureDF)

    val predictions = model.transform(featureDF)

    // Calculate silhouette score
    val evaluator = new ClusteringEvaluator()
    val silhouette = evaluator.evaluate(predictions)

    // Print silhouette score
    println(s"Silhouette with squared Euclidean distance: $silhouette")

    predictions.limit(1000)
  }

  /**
   * Runs a Logistic Regression classification model to predict crime arrest.
   * It preprocesses the data by extracting month and year, categorizing primary crime types,
   * and encoding categorical features. The model is trained and evaluated using accuracy (Area Under ROC).
   *
   * @return A DataFrame with predictions, including Community Area, Month, Category, Arrest status,
   * predicted arrest, and prediction probability.
   */
  def runClassificationLogisticRegressor(): DataFrame = {
    // Extract Month and Year
    val dfWithDate = dfPolice
      .na.drop(Seq("District", "Date"))
      .withColumn("Timestamp", to_timestamp($"Date", "MM/dd/yyyy hh:mm:ss a"))
      .withColumn("Month", month($"Timestamp"))
      .withColumn("Year", year($"Timestamp"))
      .na.drop("any", Seq("Month", "Primary Type", "Community Area", "Arrest"))

    // dfWithDate.select($"Date",$"Month",$"Year",$"Timestamp").show(truncate = false)
    // dfWithDate.printSchema()
    // dfWithDate.groupBy("Primary Type").count().show(60,truncate=false)
    // dfWithDate.groupBy($"Primary Type",$"Arrest",$"Community Area").count().where($"Community Area" === "1").show(500)

    // Create categories
    val categorizedDfbool = dfWithDate.withColumn(
      "Category",
      when(col("Primary Type").isin("ASSAULT", "BATTERY", "ROBBERY", "HOMICIDE", "KIDNAPPING", "INTIMIDATION", "DOMESTIC VIOLENCE"), "VIOLENT CRIMES")
        .when(col("Primary Type").isin("CRIMINAL SEXUAL ASSAULT", "SEX OFFENSE", "HUMAN TRAFFICKING", "PROSTITUTION", "STALKING", "OBSCENITY", "CRIM SEXUAL ASSAULT", "OFFENSE INVOLVING CHILDREN"), "SEXUAL CRIMES")
        .when(col("Primary Type").isin("THEFT", "MOTOR VEHICLE THEFT", "BURGLARY", "ARSON", "CRIMINAL DAMAGE"), "CRIMES AGAINST PROPERTY")
        .when(col("Primary Type").isin("PUBLIC PEACE VIOLATION", "PUBLIC INDECENCY", "INTERFERENCE WITH PUBLIC OFFICER", "WEAPONS VIOLATION", "CRIMINAL TRESPASS"), "PUBLIC SECURITY CRIMES")
        .when(col("Primary Type").isin("GAMBLING", "DECEPTIVE PRACTICE", "LIQUOR LAW VIOLATION"), "ECONOMIC CRIMES")
        .when(col("Primary Type").isin("NARCOTICS", "OTHER NARCOTIC VIOLATION"), "NARCOTICS")
        .when(col("Primary Type").isin("NON-CRIMINAL (SUBJECT SPECIFIED)", "NON-CRIMINAL", "NON - CRIMINAL", "OTHER OFFENSE", "CONCEALED CARRY LICENSE VIOLATION", "RITUALISM"), "VARIOUS CRIMES")
        .otherwise("UNKNOWN")
    )

    val categorizedDf = categorizedDfbool.withColumn(
      "ArrestIndex", when($"Arrest" === true, 1.0).otherwise(0.0)
    )

    // Transform "Category" column into a numeric index
    val categoryIndexer = new StringIndexer()
      .setInputCol("Category")
      .setOutputCol("CategoryIndex")

    val assembler = new VectorAssembler()
      .setInputCols(Array("Community Area", "Month", "CategoryIndex"))
      .setOutputCol("features")

    // Replace RandomForestClassifier with LogisticRegression
    val logisticRegression = new LogisticRegression()
      .setLabelCol("ArrestIndex")
      .setFeaturesCol("features")

    val pipeline = new Pipeline()
      .setStages(Array(categoryIndexer, assembler, logisticRegression))

    // Split data into training and test sets
    val Array(trainingData, testData) = categorizedDf.randomSplit(Array(0.8, 0.2), seed = 12345)

    // Train the model with training data
    val model = pipeline.fit(trainingData)

    // Make predictions on test data
    val predictions = model.transform(testData)

    // Show some predictions
    predictions.select("Community Area", "Month", "Category", "Arrest", "prediction", "probability").show(500, truncate = false)

    // Evaluate the model
    val evaluator = new BinaryClassificationEvaluator()
      .setLabelCol("ArrestIndex")
      .setMetricName("areaUnderROC")

    val accuracy = evaluator.evaluate(predictions)
    println(s"Test Area Under ROC: $accuracy")

    predictions
  }

  /**
   * Runs a Random Forest classification model to predict crime arrest.
   * Similar to the Logistic Regression method, it preprocesses the data by extracting date information,
   * categorizing crime types, and preparing features. It then trains a Random Forest model,
   * evaluates its performance using Area Under ROC, and prints feature importances.
   *
   * @return A DataFrame with predictions, including relevant crime details and the predicted arrest status.
   */
  def runClassificationRandomForest(): DataFrame = {
    // Extract Month and Year
    val dfWithDate = dfPolice
      .na.drop(Seq("District", "Date"))
      .withColumn("Timestamp", to_timestamp($"Date", "MM/dd/yyyy hh:mm:ss a"))
      .withColumn("Month", month($"Timestamp"))
      .withColumn("Year", year($"Timestamp"))
      .na.drop("any", Seq("Month", "Primary Type", "Community Area", "Arrest"))

    // dfWithDate.select($"Date",$"Month",$"Year",$"Timestamp").show(truncate = false)
    // dfWithDate.printSchema()
    // dfWithDate.groupBy("Primary Type").count().show(60,truncate=false)
    // dfWithDate.groupBy($"Primary Type",$"Arrest",$"Community Area").count().where($"Community Area" === "1").show(500)

    // Create categories
    val categorizedDfbool = dfWithDate.withColumn(
      "Category",
      when(col("Primary Type").isin("ASSAULT", "BATTERY", "ROBBERY", "HOMICIDE", "KIDNAPPING", "INTIMIDATION", "DOMESTIC VIOLENCE"), "VIOLENT CRIMES")
        .when(col("Primary Type").isin("CRIMINAL SEXUAL ASSAULT", "SEX OFFENSE", "HUMAN TRAFFICKING", "PROSTITUTION", "STALKING", "OBSCENITY", "CRIM SEXUAL ASSAULT", "OFFENSE INVOLVING CHILDREN"), "SEXUAL CRIMES")
        .when(col("Primary Type").isin("THEFT", "MOTOR VEHICLE THEFT", "BURGLARY", "ARSON", "CRIMINAL DAMAGE"), "CRIMES AGAINST PROPERTY")
        .when(col("Primary Type").isin("PUBLIC PEACE VIOLATION", "PUBLIC INDECENCY", "INTERFERENCE WITH PUBLIC OFFICER", "WEAPONS VIOLATION", "CRIMINAL TRESPASS"), "PUBLIC SECURITY CRIMES")
        .when(col("Primary Type").isin("GAMBLING", "DECEPTIVE PRACTICE", "LIQUOR LAW VIOLATION"), "ECONOMIC CRIMES")
        .when(col("Primary Type").isin("NARCOTICS", "OTHER NARCOTIC VIOLATION"), "NARCOTICS")
        .when(col("Primary Type").isin("NON-CRIMINAL (SUBJECT SPECIFIED)", "NON-CRIMINAL", "NON - CRIMINAL", "OTHER OFFENSE", "CONCEALED CARRY LICENSE VIOLATION", "RITUALISM"), "VARIOUS CRIMES")
        .otherwise("UNKNOWN")
    )

    val categorizedDf = categorizedDfbool.withColumn(
      "ArrestIndex", when($"Arrest" === true, 1.0).otherwise(0.0)
    )

    // categorizedDf.show(200, truncate = false)

    // Transform "Category" column into a numeric index
    val categoryIndexer = new StringIndexer()
      .setInputCol("Category")
      .setOutputCol("CategoryIndex")

    val assembler = new VectorAssembler()
      .setInputCols(Array("Community Area", "Month", "CategoryIndex"))
      .setOutputCol("features")

    val randomForest = new RandomForestClassifier()
      .setLabelCol("ArrestIndex")
      .setFeaturesCol("features")
      .setNumTrees(3)

    val pipeline = new Pipeline()
      .setStages(Array(categoryIndexer, assembler, randomForest))

    val Array(trainingData, testData) = categorizedDf.randomSplit(Array(0.8, 0.2), seed = 12345)

    val model = pipeline.fit(trainingData)

    val predictions = model.transform(testData)

    // predictions.select("Community Area", "Month", "Category", "Arrest", "prediction", "probability").show(500, truncate= false)

    predictions.groupBy($"Category", $"prediction").count().show()

    // Evaluation
    val evaluator = new BinaryClassificationEvaluator()
      .setLabelCol("ArrestIndex")
      .setMetricName("areaUnderROC")

    val accuracy = evaluator.evaluate(predictions)
    println(s"Test Area Under ROC: $accuracy")

    // Cast the pipeline model to RandomForestClassificationModel to access feature importances
    val rfModel = model.stages.last.asInstanceOf[RandomForestClassificationModel]

    // Print feature importances
    println(s"Feature Importances: ${rfModel.featureImportances}")

    predictions
  }

  /**
   * Performs Linear Regression to analyze the relationship between Per Capita Income (PCI)
   * and the normalized number of high-entity theft crimes per capita in different community areas.
   * It preprocesses crime data, merges it with population and income data,
   * and then trains a linear regression model.
   *
   * @return A DataFrame containing the normalized PCI, crimes per capita, and the coefficients
   * and intercept of the linear regression model.
   */
  def runRegression(): DataFrame = {
    // Here we find the population for community area and the mean in 2006-2022
    var dfPopulationIncome = spark.read
      .option("header", value = true)
      .option("inferSchema", value = true)
      .csv("data/Chicago Health Atlas Data - MeanIncome - Mean population.csv")
    dfPopulationIncome = dfPopulationIncome.filter(col("Layer").isNotNull)
    dfPopulationIncome.show()

    // Theft categorization
    val categorizedDf = dfPolice.withColumn(
      "Theft Description",
      when(col("Description").isin(
        "OVER $500", "OVER $300", "FINANCIAL ID THEFT: OVER $300",
        "AGG: FINANCIAL ID THEFT", "FINANCIAL IDENTITY THEFT: OVER $300"), "HIGH ENTITY THEFT")
        .when(col("Description").isin(
          "$500 AND UNDER", "$300 AND UNDER", "FINANCIAL ID THEFT:$300 &UNDER",
          "FROM BUILDING", "POCKET-PICKING", "PURSE-SNATCHING",
          "RETAIL THEFT", "THEFT RETAIL", "FROM COIN-OP MACHINE/DEVICE",
          "ATTEMPT THEFT", "ATTEMPT FINANCIAL IDENTITY THEFT",
          "FROM COIN-OPERATED MACHINE OR DEVICE", "DELIVERY CONTAINER THEFT"), "LOW ENTITY THEFT")
        .otherwise("NON THEFT CRIME")
    ).filter(col("Theft Description") === "HIGH ENTITY THEFT")

    // Normalization by the number of people that live in that community area (number of crimes per capita)
    var dfRegression = categorizedDf.groupBy($"Community Area", $"Year").count()
    // Cleaning of the null rows
    dfRegression = dfRegression.filter(col("Community Area").isNotNull)

    // Creation of intervals
    dfRegression = dfRegression.withColumn("Interval",
      when(col("Year").between(2018, 2021), "2018-2021")
        .when(col("Year").between(2014, 2017), "2014-2017")
        .when(col("Year").between(2010, 2013), "2010-2013")
        .when(col("Year").between(2006, 2009), "2006-2009")
        .when(col("Year").between(2001, 2005), "2001-2005")
        .otherwise(null))

    // Counting the number of cases in the intervals
    dfRegression = dfRegression.groupBy($"Community Area", $"Interval")
      .agg(functions.sum("count").as("crimes_number"))
    // Dividing by the number of years of each interval
    dfRegression = dfRegression.withColumn("CrimesPerYear",
      when(col("Interval") === "2018-2021", col("crimes_number") / 4)
        .when(col("Interval") === "2014-2017", col("crimes_number") / 4)
        .when(col("Interval") === "2010-2013", col("crimes_number") / 4)
        .when(col("Interval") === "2006-2009", col("crimes_number") / 4)
        .when(col("Interval") === "2001-2005", col("crimes_number") / 5))
    dfRegression.show()

    // Now join the two tables of per capita income and mean total crimes for each community area
    dfRegression = dfRegression.join(dfPopulationIncome, dfRegression("Community Area") === dfPopulationIncome("GEOID"))

    // Cast every column from String to Double for the PCI and population
    dfRegression = dfRegression.withColumn("POP_2018-2022", col("POP_2018-2022").cast("Double"))
      .withColumn("POP_2014-2018", col("POP_2014-2018").cast("Double"))
      .withColumn("POP_2010-2014", col("POP_2010-2014").cast("Double"))
      .withColumn("POP_2006-2010", col("POP_2006-2010").cast("Double"))
      .withColumn("PCI_2018-2022", col("PCI_2018-2022").cast("Double"))
      .withColumn("PCI_2014-2018", col("POP_2014-2018").cast("Double"))
      .withColumn("PCI_2010-2014", col("POP_2010-2014").cast("Double"))
      .withColumn("PCI_2006-2010", col("POP_2006-2010").cast("Double"))

    // Now use the population field to normalize the number of crimes per capita for each community area
    dfRegression = dfRegression.withColumn("CrimesPerCapita",
      when(col("Interval") === "2018-2021", col("CrimesPerYear") / col("POP_2018-2022"))
        .when(col("Interval") === "2014-2017", col("CrimesPerYear") / col("POP_2014-2018"))
        .when(col("Interval") === "2010-2013", col("CrimesPerYear") / col("POP_2010-2014"))
        .when(col("Interval") === "2006-2009", col("CrimesPerYear") / col("POP_2006-2010"))
        .when(col("Interval") === "2001-2005", col("CrimesPerYear") / col("POP_2006-2010")))
    dfRegression.show()
    // dfRegression = dfRegression.select($"Community Area",$"Interval",$"CrimesPerYear",$"CrimesPerCapita")

    dfRegression.printSchema()

    // Now we have the number of crimesPerCapita for each time-interval using the American census data
    // The next step is to select for each interval the PerCapitaIncome of the Community Area
    dfRegression = dfRegression.withColumn("PCI",
        when(col("Interval") === "2018-2021", col("PCI_2018-2022"))
          .when(col("Interval") === "2014-2017", col("PCI_2014-2018"))
          .when(col("Interval") === "2010-2013", col("PCI_2010-2014"))
          .when(col("Interval") === "2006-2009", col("PCI_2006-2010")))
      .filter($"PCI".isNotNull)

    // dfRegression.select($"Community Area",$"Interval",$"CrimesPerCapita",$"PCI").show(200)

    // Normalization of income (Income / mean)
    val meanIncome = dfRegression.agg(avg($"PCI")).first().getDouble(0)
    val dfFinal = dfRegression.withColumn("PCI_Normalized", $"PCI" / meanIncome)

    dfFinal.show()

    // Regression example for only 1 interval
    // Transform 'PCI' (feature) and 'total_crimes' (label) columns into the required format
    val assembler = new VectorAssembler()
      .setInputCols(Array("PCI_Normalized"))
      .setOutputCol("features")

    val dfFeatures = assembler.transform(dfFinal)
      .select("features", "CrimesPerCapita") // select only necessary columns

    val lr = new LinearRegression()
      .setLabelCol("CrimesPerCapita")
      .setFeaturesCol("features")

    val lrModel = lr.fit(dfFeatures)

    println(s"The coefficient of the model are: ${lrModel.coefficients}, intercept: ${lrModel.intercept}")

    // Mean of target value
    val mean = dfFinal.agg(avg("CrimesPerCapita")).first().getDouble(0)
    // Model summary to get metrics like R^2 and root squared error
    val trainingSummary = lrModel.summary
    val normalizedRMSE = trainingSummary.rootMeanSquaredError / mean
    println(s"R2: ${trainingSummary.r2}, RMSE: ${trainingSummary.rootMeanSquaredError}, MeanTarget: $mean, NMRSE: $normalizedRMSE")

    // There's a slight negative correlation between the per capita income and the CrimesPerCapita
    // But there's not a clear correlation between these two variables.

    // Add coefficients and intercept
    val coefficientValue = lrModel.coefficients(0)
    val interceptValue = lrModel.intercept

    // Add columns for coefficients and intercept
    val dfWithModelParams = dfFinal.withColumn("Coefficient", lit(coefficientValue))
      .withColumn("Intercept", lit(interceptValue))

    dfWithModelParams.printSchema()
    dfWithModelParams
  }

  // --- API Endpoints ---

  /**
   * Handles OPTIONS requests for the location crime distribution endpoint.
   * This is necessary for CORS preflight requests.
   *
   * @return A Cask response with appropriate CORS headers.
   */
  @cask.options("/distributions/locationCrimeDistribution")
  def optionsHandlerLocation(): cask.Response.Raw = {
    withCorsHeaders(cask.Response(""))
  }

  /**
   * Handles OPTIONS requests for the crime type distribution endpoint.
   *
   * @return A Cask response with appropriate CORS headers.
   */
  @cask.options("/distributions/typeDistribution")
  def optionsHandlerType(): cask.Response.Raw = {
    withCorsHeaders(cask.Response(""))
  }

  /**
   * Handles OPTIONS requests for the domestic crime distribution endpoint.
   *
   * @return A Cask response with appropriate CORS headers.
   */
  @cask.options("/distributions/domesticDistribution")
  def optionsHandlerDomestic(): cask.Response.Raw = {
    withCorsHeaders(cask.Response(""))
  }

  /**
   * Handles OPTIONS requests for the theft distribution endpoint.
   *
   * @return A Cask response with appropriate CORS headers.
   */
  @cask.options("/distributions/theftDistribution")
  def optionsHandlerTheft(): cask.Response.Raw = {
    withCorsHeaders(cask.Response(""))
  }

  /**
   * API endpoint to retrieve regression predictions.
   * It calls `runRegression()` to perform the analysis and then formats the results as JSON.
   *
   * @return A Cask response containing JSON data of PCI, Crimes Per Capita, Coefficient, and Intercept.
   */
  @cask.get("/regression/predictions")
  def getRegressionPredictions(): Response.Raw = {
    val predictionDF = runRegression()

    val resultDF = predictionDF.select($"PCI_Normalized".as("PCI"), $"CrimesPerCapita".as("Crimes"), $"Coefficient", $"Intercept")

    val jsonData = resultDF.toJSON.collect().mkString("[", ",", "]")

    // print(jsonData)

    val ret = withCorsHeaders(Response(jsonData))

    ret
  }

  /**
   * API endpoint to retrieve clustering predictions.
   * It executes the clustering analysis using `runClustering()` and returns the results
   * (Latitude, Longitude, and predicted cluster) in JSON format.
   *
   * @return A Cask response containing JSON data of crime locations and their cluster predictions.
   */
  @cask.get("/cluster/predictions")
  def getClusterPredictions(): Response.Raw = {
    val predictionsDF = runClustering()

    val resultDF = predictionsDF.select($"Latitude", $"Longitude", $"prediction").withColumn("Latitude", col("Latitude"))
      .withColumn("Longitude", col("Longitude")).limit(5000)

    // Convert DataFrame to JSON
    val jsonData = resultDF.toJSON.collect().mkString("[", ",", "]")

    val ret = withCorsHeaders(Response(jsonData))

    ret
  }

  /**
   * API endpoint to retrieve classification predictions (using Random Forest).
   * It runs the Random Forest classification model and returns the Category, Arrest status,
   * predicted arrest, Longitude, and Latitude in JSON format.
   *
   * @return A Cask response containing JSON data of crime classification predictions.
   */
  @cask.get("/classification/predictions")
  def getClassificationPredictions(): Response.Raw = {
    val predictionsDF = runClassificationRandomForest()

    // predictionsDF.printSchema()

    val resultDF = predictionsDF.select($"Category", $"Arrest", $"ArrestIndex".as("Label"), $"prediction".as("Prediction"), $"Longitude", $"Latitude")
      .na.drop("any", Seq("Longitude", "Latitude")).limit(500)

    resultDF.show()

    // Convert DataFrame to JSON
    val jsonData = resultDF.toJSON.collect().mkString("[", ",", "]")

    // print(jsonData)

    val ret = withCorsHeaders(Response(jsonData))

    ret
  }

  /**
   * API endpoint to get the distribution of crimes per year.
   * It counts the number of crimes for each year in the dataset and returns the result as JSON.
   *
   * @return A Cask response containing JSON data of crime counts per year.
   */
  @cask.get("/distributions/crimesPerYear")
  def getCrimesPerYear(): Response.Raw = {
    val dfWithDate = dfPolice
      .na.drop(Seq("Community Area", "Date"))
      .withColumn("Timestamp", to_timestamp($"Date", "MM/dd/yyyy hh:mm:ss a"))
      .withColumn("Month", month($"Timestamp"))
      .withColumn("Year", year($"Timestamp"))
      .na.drop("any", Seq("Month", "Primary Type", "Community Area", "Arrest"))

    val crimesDistributionPerYear = dfWithDate.groupBy($"Year").count().withColumnRenamed("count", "Crimes").orderBy($"Year".asc)

    // crimesDistributionPerYear.show(50)
    // crimesDistributionPerYear.printSchema()

    val crimeDistributionJson = crimesDistributionPerYear.toJSON.collect().mkString("[", ",", "]")

    // println(crimeDistributionJson)

    val ret = withCorsHeaders(Response(crimeDistributionJson))

    ret
  }

  /**
   * API endpoint to get the distribution of crime types for a specific month.
   * It receives the month as a parameter in the request body, categorizes crime types,
   * and returns the count of each category for the specified month in JSON format.
   *
   * @param request The Cask request containing the month.
   * @return A Cask response containing JSON data of crime type distribution per month.
   */
  @cask.post("/distributions/typeDistribution")
  def getTypePerMonth(request: cask.Request): Response.Raw = {
    val requestBody = ujson.read(request.text())
    val monthExtracted = requestBody("month").str

    print(monthExtracted)

    val dfWithDate = dfPolice
      .na.drop(Seq("Community Area", "Date"))
      .withColumn("Timestamp", to_timestamp($"Date", "MM/dd/yyyy hh:mm:ss a"))
      .withColumn("Month", month($"Timestamp"))
      .withColumn("Year", year($"Timestamp"))
      .na.drop("any", Seq("Month", "Primary Type", "Community Area", "Arrest"))

    // dfWithDate.printSchema()

    // Create categories
    val categorizedDf = dfWithDate.withColumn(
      "Category",
      when(col("Primary Type").isin("ASSAULT", "BATTERY", "ROBBERY", "HOMICIDE", "KIDNAPPING", "INTIMIDATION", "DOMESTIC VIOLENCE"), "VIOLENT")
        .when(col("Primary Type").isin("CRIMINAL SEXUAL ASSAULT", "SEX OFFENSE", "HUMAN TRAFFICKING", "PROSTITUTION", "STALKING", "OBSCENITY", "CRIM SEXUAL ASSAULT", "OFFENSE INVOLVING CHILDREN"), "SEXUAL")
        .when(col("Primary Type").isin("THEFT", "MOTOR VEHICLE THEFT", "BURGLARY", "ARSON", "CRIMINAL DAMAGE"), "PROPERTY")
        .when(col("Primary Type").isin("PUBLIC PEACE VIOLATION", "PUBLIC INDECENCY", "INTERFERENCE WITH PUBLIC OFFICER", "WEAPONS VIOLATION", "CRIMINAL TRESPASS"), "PUBLIC SECURITY")
        .when(col("Primary Type").isin("GAMBLING", "DECEPTIVE PRACTICE", "LIQUOR LAW VIOLATION"), "ECONOMIC")
        .when(col("Primary Type").isin("NARCOTICS", "OTHER NARCOTIC VIOLATION"), "NARCOTICS")
        .when(col("Primary Type").isin("NON-CRIMINAL (SUBJECT SPECIFIED)", "NON-CRIMINAL", "NON - CRIMINAL", "OTHER OFFENSE", "CONCEALED CARRY LICENSE VIOLATION", "RITUALISM"), "VARIOUS")
        .otherwise("UNKNOWN")
    )

    // Filter by the specified month
    val crimesDistributionPerMonth = categorizedDf
      .filter($"Month" === monthExtracted)
      .groupBy($"Category")
      .count()
      .withColumnRenamed("count", "Crimes")

    // crimesDistributionPerMonth.show()

    val crimeDistributionJson = crimesDistributionPerMonth.toJSON.collect().mkString("[", ",", "]")

    // print(crimeDistributionJson)

    val ret = withCorsHeaders(Response(crimeDistributionJson))

    ret
  }

  /**
   * API endpoint to get the distribution of domestic crimes for a specific community area.
   * It receives the community area as a parameter and returns the count of domestic vs. non-domestic crimes
   * for that area in JSON format.
   *
   * @param request The Cask request containing the community area.
   * @return A Cask response containing JSON data of domestic crime distribution per community area.
   */
  @cask.post("/distributions/domesticDistribution")
  def getDomesticPerCommunityArea(request: cask.Request): Response.Raw = {
    val requestBody = ujson.read(request.text())
    val communityAreaExtracted = requestBody("community-area").str

    val crimesDomesticPerArea = dfPolice.where($"Community Area" === communityAreaExtracted).groupBy($"Domestic").count().withColumnRenamed("count", "Crimes")

    // crimesDomesticPerArea.show()
    // crimesDomesticPerArea.printSchema()

    val crimeDistributionJson = crimesDomesticPerArea.toJSON.collect().mkString("[", ",", "]")

    // print(crimeDistributionJson)

    val ret = withCorsHeaders(Response(crimeDistributionJson))

    ret
  }

  /**
   * API endpoint to get the distribution of theft crimes (categorized by value) for a specific community area.
   * It receives the community area as a parameter, categorizes theft descriptions, and returns
   * the counts of "HIGH ENTITY THEFT," "LOW ENTITY THEFT," and "NON THEFT CRIME" for that area in JSON format.
   *
   * @param request The Cask request containing the community area.
   * @return A Cask response containing JSON data of theft crime distribution per community area.
   */
  @cask.post("/distributions/theftDistribution")
  def getTheftPerCommunityArea(request: cask.Request): Response.Raw = {
    val requestBody = ujson.read(request.text())
    val communityAreaExtracted = requestBody("community-area").str

    val categorizedDf = dfPolice.withColumn(
      "Theft Description",
      when(col("Description").isin(
        "OVER $500", "OVER $300", "FINANCIAL ID THEFT: OVER $300",
        "AGG: FINANCIAL ID THEFT", "FINANCIAL IDENTITY THEFT: OVER $300"), "HIGH ENTITY THEFT")
        .when(col("Description").isin(
          "$500 AND UNDER", "$300 AND UNDER", "FINANCIAL ID THEFT:$300 &UNDER",
          "FROM BUILDING", "POCKET-PICKING", "PURSE-SNATCHING",
          "RETAIL THEFT", "THEFT RETAIL", "FROM COIN-OP MACHINE/DEVICE",
          "ATTEMPT THEFT", "ATTEMPT FINANCIAL IDENTITY THEFT",
          "FROM COIN-OPERATED MACHINE OR DEVICE", "DELIVERY CONTAINER THEFT"), "LOW ENTITY THEFT")
        .otherwise("NON THEFT CRIME")
    )

    // val crimesTheftPerArea = dfPolice.where($"Community Area" === communityAreaExtracted and($"Primary Type" === "THEFT")).groupBy($"Description").count().withColumnRenamed("count","Crimes")

    val crimesTheftPerArea = categorizedDf.where($"Primary Type" === "THEFT" and ($"Community Area" === communityAreaExtracted)).groupBy("Theft Description").count().withColumnRenamed("count", "Crimes")

    crimesTheftPerArea.show(false)
    crimesTheftPerArea.printSchema()

    val crimeDistributionJson = crimesTheftPerArea.toJSON.collect().mkString("[", ",", "]")

    // print(crimeDistributionJson)

    val ret = withCorsHeaders(Response(crimeDistributionJson))

    ret
  }

  /**
   * API endpoint to get the distribution of crimes by location category for a specific community area.
   * It receives the community area and a location category as parameters, categorizes location descriptions,
   * and returns the annual crime counts for the specified location category within that community area in JSON format.
   *
   * @param request The Cask request containing the community area and location category.
   * @return A Cask response containing JSON data of crime distribution by location category per community area.
   */
  @cask.post("/distributions/locationCrimeDistribution")
  def getLocationCrimePerCommunityArea(request: cask.Request): Response.Raw = {
    val requestBody = ujson.read(request.text())
    val communityAreaExtracted = requestBody("community-area").str
    val locationCategoryExtracted = requestBody("location-category").str

    print(requestBody)

    val dfWithDate = dfPolice
      .na.drop(Seq("Community Area", "Date"))
      .withColumn("Timestamp", to_timestamp($"Date", "MM/dd/yyyy hh:mm:ss a"))
      .withColumn("Month", month($"Timestamp"))
      .withColumn("Year", year($"Timestamp"))
      .na.drop("any", Seq("Month", "Primary Type", "Community Area", "Arrest"))

    val categorizedDf = dfWithDate.withColumn(
      "Location Category",
      when($"Location Description".isin(
        "APARTMENT", "HOUSE", "RESIDENCE", "RESIDENCE PORCH/HALLWAY",
        "CHA APARTMENT", "CHA HALLWAY / STAIRWELL / ELEVATOR",
        "RESIDENCE-GARAGE", "CHA GROUNDS", "CHA PARKING LOT",
        "COLLEGE/UNIVERSITY RESIDENCE HALL", "RESIDENCE - GARAGE",
        "RESIDENTIAL YARD (FRONT/BACK)"
      ), "Apartment")
        .when($"Location Description".isin(
          "STREET", "SIDEWALK", "ALLEY", "DRIVEWAY - RESIDENTIAL",
          "VACANT LOT/LAND", "PARKING LOT / GARAGE (NON RESIDENTIAL)",
          "CTA PLATFORM", "PARK PROPERTY", "HIGHWAY/EXPRESSWAY",
          "LAKEFRONT/WATERFRONT/RIVERBANK", "BRIDGE", "AIRPORT PARKING LOT",
          "POLICE FACILITY/VEH PARKING LOT", "ABANDONED BUILDING",
          "TAXICAB", "CHA PARKING LOT/GROUNDS"
        ), "Street")
        .when($"Location Description".isin(
          "GROCERY FOOD STORE", "CONVENIENCE STORE", "COMMERCIAL / BUSINESS OFFICE",
          "DEPARTMENT STORE", "RESTAURANT", "TAVERN / LIQUOR STORE",
          "SMALL RETAIL STORE", "GAS STATION", "CURRENCY EXCHANGE",
          "BANK", "WAREHOUSE", "APPLIANCE STORE", "AUTO / BOAT / RV DEALERSHIP",
          "AIRPORT/AIRCRAFT ", "MEDICAL/DENTAL OFFICE ", "CHA HALLWAY/STAIRWELL/ELEVATOR",
          "DRUG STORE", "HOTEL/MOTEL", "NURSING HOME/RETIREMENT HOME", "TAVERN/LIQUOR STORE",
          "BAR OR TAVERN", "AIRPORT/AIRCRAFT", "CONSTRUCTION SITE "
        ), "Commercial")
        .when($"Location Description".isin(
          "CTA BUS", "CTA TRAIN", "CTA PLATFORM", "CTA STATION",
          "TAXICAB", "AIRPORT TERMINAL", "VEHICLE - COMMERCIAL",
          "VEHICLE - OTHER RIDE SHARE SERVICE", "VEHICLE NON-COMMERCIAL", "HIGHWAY/EXPRESSWAY",
          "PARKING LOT / GARAGE (NON RESIDENTIAL)", "OTHER COMMERCIAL TRANSPORTATION", "PARKING LOT/GARAGE(NON.RESID.)"
        ), "Transportation")
        .when($"Location Description".isin(
          "PARK PROPERTY", "SCHOOL - PUBLIC BUILDING", "SCHOOL - PRIVATE BUILDING",
          "SCHOOL, PUBLIC, GROUNDS", "SCHOOL, PRIVATE, GROUNDS",
          "LIBRARY", "HOSPITAL BUILDING/GROUNDS", "GOVERNMENT BUILDING / PROPERTY",
          "CHURCH / SYNAGOGUE / PLACE OF WORSHIP", "SCHOOL, PUBLIC, BUILDING",
          "SCHOOL, PRIVATE, BUILDING", "GOVERNMENT BUILDING/PROPERTY", "CHURCH/SYNAGOGUE/PLACE OF WORSHIP"
        ), "Public Spaces")
        .otherwise("Other")
    )

    val crimesLocationPerArea = categorizedDf.where($"Community Area" === communityAreaExtracted and ($"Location Category" === locationCategoryExtracted)).groupBy($"Year").count().withColumnRenamed("count", "Crimes")
      .orderBy($"Year".asc)

    crimesLocationPerArea.show(500, truncate = false)

    val crimeDistributionJson = crimesLocationPerArea.toJSON.collect().mkString("[", ",", "]")

    // print(crimeDistributionJson)

    val ret = withCorsHeaders(Response(crimeDistributionJson))

    ret
  }

  initialize()
}