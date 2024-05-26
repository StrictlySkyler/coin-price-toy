import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';

/// Arbitrary ~3mo interval:
/// Mo/Yr * Days/wk * Hrs/Day * Min/Hr * Sec/Min * millis
const double chartXInterval = 12 * 7 * 24 * 60 * 60 * 1000;

/// Fetches details for a coin from coingecko.
///
/// Takes a [coin] id and provides the historical market data, decoding it into
/// a Map, and returning an instance of the CoinDetails class.
Future<CoinDetails> fetchCoinData(coin) async {
  final response = await http.get(Uri.parse(
      'https://api.coingecko.com/api/v3/coins/$coin/market_chart?vs_currency=usd&days=365'));

  if (response.statusCode != 200) {
    throw Exception('Failed to load detail data for "$coin"!');
  }
  return CoinDetails.fromJsonMap(json.decode(response.body) as Map);
}

/// Class containing the details of a particular coin.
///
/// Provides the coin's historical prices as a List.
class CoinDetails {
  final Map details;

  const CoinDetails({
    required this.details,
  });

  List getPrices() {
    return details['prices'] as List;
  }

  factory CoinDetails.fromJsonMap(Map json) {
    if (json.isEmpty) {
      throw const FormatException('Failed to load coin details');
    }

    return CoinDetails(details: json);
  }
}

/// Responsible for the detailed coin view.
///
/// Provides a chart and calculator with titles, showing historical price data
/// back 1 year and allowing conversion of USD into the currency based on the
/// latest price we have.
class CoinDetailsView extends StatefulWidget {
  final String id;
  final String symbol;
  final String name;

  const CoinDetailsView({
    required this.id,
    required this.symbol,
    required this.name,
    super.key,
  });
  static const routeName = '/details';

  @override
  State<CoinDetailsView> createState() => _CoinDetailsViewState();
}

/// Manages the state for the CoinDetailsView.
///
/// Covers rendering the view Widgets, their state, as well as event handlers
/// for the form fields.
class _CoinDetailsViewState extends State<CoinDetailsView> {
  late Future<CoinDetails> futureDetails;
  double currentPrice = 0.00;
  double usd = 0.00;
  double qty = 0.00;

  final _usdController = TextEditingController();
  final _qtyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    futureDetails = fetchCoinData(widget.id);
    _usdController.text = usd.toString();
    _qtyController.text = qty.toString();
  }

  @override
  void dispose() {
    super.dispose();
    _usdController.dispose();
    _qtyController.dispose();
  }

  /// Renders X-axis titles for the chart.
  ///
  /// The [value] is a UNIX epoch in millis, while [meta] is provided by the
  /// charting library.
  Widget _bottomTitles(double value, TitleMeta meta) {
    DateTime date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    int month = date.month;
    String year = date.year.toString().substring(2, 4);
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: RotationTransition(
        turns: const AlwaysStoppedAnimation(-30 / 360),
        child: Text("$month '$year", style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  /// Renders the chart title.
  Widget _renderChartTitle() {
    return Container(
      alignment: Alignment.topCenter,
      child: const Text(
        'Price History (1Y)',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Renders the chart, or a progress indicator.
  ///
  /// Waits for the http request to complete before it shows the chart,
  /// assigning each non-zero timestamp/price tuple to the chart.  Evidently,
  /// sometimes the API provides zeroes for its timeseries data; these we can
  /// discard.
  Widget _renderChart() {
    return FractionallySizedBox(
      heightFactor: 0.5,
      widthFactor: 1,
      child: Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.topCenter,
        child: FutureBuilder<CoinDetails>(
          future: futureDetails,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('${snapshot.error}');
            } else if (snapshot.hasData) {
              List? prices = snapshot.data!.getPrices();
              currentPrice = prices[prices.length - 1][1];
              List<FlSpot> spots = [];

              for (var entry in prices) {
                double timestamp = entry[0].toDouble();
                double price = entry[1];
                // Don't chart bogus data
                if (timestamp != 0) {
                  spots.add(FlSpot(timestamp, price));
                }
              }
              return LineChart(
                LineChartData(
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: chartXInterval,
                        getTitlesWidget: _bottomTitles,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      color: Colors.green,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  /// Renders the title for the currency calculator.
  Widget _renderCalcTitle() {
    return Container(
      alignment: Alignment.center,
      child: const Text(
        'Price Calculator (USD)',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Renders the text input for USD.
  ///
  /// Also sets quantity based on latest price we received and updates the
  /// quantity text input, and formats the USD input to represent a dollar
  /// amount, fixing the input to 2 decimals.  The library provides a `$` for
  /// the currency, but only seems to format when updating this field with user
  /// events; not when setting state elsewhere.
  Widget _renderUsdInput() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 10, 0),
        child: TextField(
          controller: _usdController,
          keyboardType: TextInputType.number,
          inputFormatters: [CurrencyTextInputFormatter.simpleCurrency()],
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'USD',
          ),
          onChanged: (text) {
            if (text.isNotEmpty) {
              double price = double.parse(
                text.substring(1, text.length - 1).replaceAll(',', ''),
              );
              setState(() {
                _qtyController.text = (price / currentPrice).toString();
              });
            }
          },
        ),
      ),
    );
  }

  /// Renders the text input for coin quantity.
  ///
  /// Also sets the amount of USD required based on the latest data we received
  /// and updates the USD text input.  Does *not* re-run the input decorator;
  /// this seems to only run at the moment when updating the USD input field.
  /// Fixes the USD amount to 2 decimals.
  Widget _renderQtyInput() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
        child: TextField(
          controller: _qtyController,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'^[0-9]+\.?[0-9]*$'),
            ),
          ],
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'QTY',
          ),
          onChanged: (text) {
            if (text.isNotEmpty) {
              double qty = double.parse(text);
              setState(() {
                _usdController.text = (currentPrice * qty).toStringAsFixed(2);
              });
            }
          },
        ),
      ),
    );
  }

  /// Renders the calculator input widgets.
  Widget _renderCalc() {
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.fromLTRB(20, 100, 20, 0),
      child: Row(
        children: <Widget>[
          _renderUsdInput(),
          _renderQtyInput(),
        ],
      ),
    );
  }

  /// Renders the CoinDetailsView.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: SafeArea(
        child: Stack(
          children: [
            _renderChartTitle(),
            _renderChart(),
            _renderCalcTitle(),
            _renderCalc(),
          ],
        ),
      ),
    );
  }
}
