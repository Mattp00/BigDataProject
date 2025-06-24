ThisBuild / version := "0.1.0-SNAPSHOT"

ThisBuild / scalaVersion := "2.13.12"

lazy val root = (project in file("."))
  .settings(
    name := "CrimeAnalysisAPI",
    resolvers += "Maven Central" at "https://repo1.maven.org/maven2/"
  )
libraryDependencies += "org.apache.spark" %% "spark-core" % "3.5.1"
libraryDependencies += "org.apache.spark" %% "spark-sql" % "3.5.1"
libraryDependencies += "org.apache.spark" %% "spark-mllib" % "3.5.1"
libraryDependencies += "com.lihaoyi" %% "cask" % "0.9.4"
libraryDependencies += "org.plotly-scala" %% "plotly-render" % "0.8.4"
libraryDependencies += "org.jboss.xnio" % "xnio-api" % "3.8.16.Final"
libraryDependencies += "ch.megard" %% "akka-http-cors" % "1.2.0"

