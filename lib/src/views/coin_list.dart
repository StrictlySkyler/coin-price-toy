import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'coin_details.dart';

/// Make the coin list easier to read for this demo.
///
/// In prod, we'd be using a UI design and may even render icons instead of
/// avatars with the symbol, but for the purpose of this exercise have opted for
/// a minimal UI implementation so as to focus on the requirements.
const evenRowBg = Color(0xffffffee);
const oddRowBg = Color(0xffeeeeff);
const evenSymbolBg = Color(0xffffffaa);
const oddSymbolBg = Color(0xffaaaaff);
const double symbolSize = 75;
const coinListUrl = 'https://api.coingecko.com/api/v3/coins/list';

/// Get the coin list from coingecko.
///
/// Decodes the JSON into a List, and provides a Coins instance to manage the
/// data received.
Future<Coins> fetchCoins() async {
  final response = await http.get(Uri.parse(coinListUrl));
  if (response.statusCode != 200) {
    throw Exception('Failed to load Coins!');
  }
  return Coins.fromJsonArray(json.decode(response.body) as List<dynamic>);
}

/// Responsible for the coin list data.
///
/// Provides a `listCoins` method which accepts a [filter] for returning
/// a subset of the list of coins based on what the user has entered in the
/// Search bar.
class Coins {
  final List coins;

  const Coins({
    required this.coins,
  });

  /// Right now the list we're filtering is a little more than ~1mb in size, and
  /// likely to continue to grow over time.  More filtering, and perhaps a
  /// faster search, could alleviate this -- although each item must still be
  /// compared for the results.
  List listCoins(filter) {
    if (filter.isEmpty) return coins;
    return coins.where((coin) {
      if (coin['symbol'].contains(filter) ||
          coin['name'].contains(filter) ||
          coin['id'].contains(filter)) {
        return true;
      }
      return false;
    }).toList();
  }

  factory Coins.fromJsonArray(List<dynamic> list) {
    if (list.isEmpty) {
      throw const FormatException('Failed to load coin list.');
    }
    return Coins(coins: list);
  }
}

/// Renders the list of coins, the app entrypoint/home.
class CoinListView extends StatefulWidget {
  const CoinListView({super.key});
  static const routeName = '/';

  @override
  State<CoinListView> createState() => _CoinListViewState();
}

/// Manages state fort he CoinListView widget.
///
/// Fetches the list of coins on instantiation, and awaits for the Future
/// providing them to complete before rendering.  Also provides a search bar
/// Widget for the user to filter the coins shown by string input.
class _CoinListViewState extends State<CoinListView> {
  late Future<Coins> futureCoins;
  String filter = '';

  @override
  void initState() {
    super.initState();
    futureCoins = fetchCoins();
  }

  /// Renders the search bar at the bottom of the view.
  ///
  /// No suggestions are provided for this example, but an enhancement might
  /// include a list of suggestions based on prior searches.
  Widget _renderSearchBar() {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        padding: const EdgeInsets.all(10),
        color: Colors.white,
        child: SearchAnchor(
          builder: (context, controller) {
            return SearchBar(
              controller: controller,
              leading: const Icon(Icons.search),
              hintText: 'Search',
              onChanged: (value) {
                setState(() {
                  filter = value;
                });
              },
            );
          },
          suggestionsBuilder: (context, controller) {
            return [];
          },
        ),
      ),
    );
  }

  /// Renders the list of coins after we've received the data fromt he API.
  ///
  /// Shows a waiting indicator until the Future completes.  Navigates to a coin
  /// detail view upon tapping a list entry.
  Widget _renderCoinList() {
    return Scaffold(
      appBar: AppBar(title: const Text('Coin List Toy')),
      body: Center(
        child: FutureBuilder<Coins>(
          future: futureCoins,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('${snapshot.error}');
            } else if (snapshot.hasData) {
              List? coins = snapshot.data?.listCoins(filter);

              return ListView.builder(
                restorationId: 'coinListView',
                itemCount: coins?.length,
                itemBuilder: (BuildContext context, int idx) {
                  final coin = coins?[idx];
                  return ListTile(
                    title: Text(coin['name']),
                    leading: Container(
                      width: symbolSize,
                      height: symbolSize,
                      color: idx % 2 == 0 ? evenSymbolBg : oddSymbolBg,
                      child: Center(child: Text(coin['symbol'])),
                    ),
                    onTap: () {
                      Navigator.restorablePushNamed(
                        context,
                        CoinDetailsView.routeName,
                        arguments: {
                          'name': coin['name'],
                          'id': coin['id'],
                          'symbol': coin['symbol'],
                        },
                      );
                    },
                    tileColor: idx % 2 == 0 ? evenRowBg : oddRowBg,
                  );
                },
              );
            }
            return const CircularProgressIndicator();
          },
        ),
      ),
      bottomNavigationBar: _renderSearchBar(),
    );
  }

  /// Builds the coin list view.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      restorationScopeId: 'app',
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (builder) {
            switch (routeSettings.name) {
              case CoinDetailsView.routeName:
                final args = routeSettings.arguments as Map;
                return CoinDetailsView(
                  id: args['id'],
                  symbol: args['symbol'],
                  name: args['name'],
                );
              default:
                return _renderCoinList();
            }
          },
        );
      },
    );
  }
}
