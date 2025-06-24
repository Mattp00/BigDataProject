import 'package:chicagocrimes/visualization/getClassification.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class GetClassificationResults extends StatelessWidget {
  final List<ChartSampleDataClassification> data;

  GetClassificationResults({required this.data});

  List<ClassificationResults> calculateClassificationResults(
      List<ChartSampleDataClassification> classifications) {
    int truePositive = 0;
    int trueNegative = 0;
    int falsePositive = 0;
    int falseNegative = 0;

    for (var classification in classifications) {
      if (classification.prediction == 1 && classification.label == 1) {
        truePositive++;
      } else if (classification.prediction == 0 && classification.label == 0) {
        trueNegative++;
      } else if (classification.prediction == 1 && classification.label == 0) {
        falsePositive++;
      } else if (classification.prediction == 0 && classification.label == 1) {
        falseNegative++;
      }
    }

    return [
      ClassificationResults(metric: 'True Positive', count: truePositive),
      ClassificationResults(metric: 'True Negative', count: trueNegative),
      ClassificationResults(metric: 'False Positive', count: falsePositive),
      ClassificationResults(metric: 'False Negative', count: falseNegative),
      ClassificationResults(
          metric: "Correct Predictions", count: truePositive + trueNegative),
      ClassificationResults(
          metric: "Wrong Predictions", count: falsePositive + falseNegative)
    ];
  }

  ClassificationResults? getMetric(
      List<ClassificationResults> results, String metricName) {
    for (var result in results) {
      if (result.metric == metricName) {
        return result;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    List<ClassificationResults> totalResults =
        calculateClassificationResults(data);

    // Ottieni solo le metriche desiderate
    List<ClassificationResults> score1 = [
      getMetric(totalResults, "Correct Predictions")!,
      getMetric(totalResults, "Wrong Predictions")!
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Classification results'),
        backgroundColor: Colors.cyan,
      ),
      body: SfCartesianChart(
        primaryXAxis: CategoryAxis(),
        title: ChartTitle(text: 'Classification predictions'),
        legend: Legend(isVisible: true),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries>[
          ColumnSeries<ClassificationResults, String>(
            dataSource: score1,
            xValueMapper: (ClassificationResults result, _) => result.metric,
            yValueMapper: (ClassificationResults result, _) => result.count,
            name: 'Predictions',
            dataLabelSettings: DataLabelSettings(isVisible: true),
          ),
        ],
      ),
    );
  }
}

class ClassificationResults {
  final String metric;
  final int count;

  ClassificationResults({required this.metric, required this.count});
}
