const Map<String, String> currencyIdToCode = {
  '1': 'RUB', '2': 'USD', '3': 'EUR', '4': 'GBP', '5': 'CHF',
  '6': 'CNY', '7': 'JPY', '8': 'BYN', '9': 'UAH', '10': 'KZT',
  '11': 'PLN', '12': 'CZK', '13': 'SEK', '14': 'NOK',
};

const Map<String, String> currencyCodeToId = {
  'RUB': '1', 'USD': '2', 'EUR': '3', 'GBP': '4', 'CHF': '5',
  'CNY': '6', 'JPY': '7', 'BYN': '8', 'UAH': '9', 'KZT': '10',
  'PLN': '11', 'CZK': '12', 'SEK': '13', 'NOK': '14',
};

const Map<String, String> currencySymbols = {
  'RUB': '₽', 'USD': '\$', 'EUR': '€', 'GBP': '£', 'CHF': '₣',
  'CNY': '¥', 'JPY': '¥', 'BYN': 'Br', 'UAH': '₴', 'KZT': '₸',
  'PLN': 'zł', 'CZK': 'Kč', 'SEK': 'kr', 'NOK': 'kr',
};

const List<String> allCurrencyCodes = [
  'RUB', 'USD', 'EUR', 'GBP', 'CHF', 'CNY', 'JPY',
  'BYN', 'UAH', 'KZT', 'PLN', 'CZK', 'SEK', 'NOK',
];

const List<String> defaultWatchedCurrencies = ['RUB', 'USD', 'EUR'];

String currencySymbol(String code) => currencySymbols[code] ?? code;

List<String> deriveWatchedCurrencies(String? userDefaultCurrency, List<String> accountCurrencies) {
  final set = <String>{};
  set.add(userDefaultCurrency ?? 'RUB');
  set.addAll(accountCurrencies);
  if (set.length < 3) {
    set.addAll(defaultWatchedCurrencies);
  }
  final result = set.toList();
  result.sort((a, b) {
    final ai = allCurrencyCodes.indexOf(a);
    final bi = allCurrencyCodes.indexOf(b);
    if (ai == -1 && bi == -1) return a.compareTo(b);
    if (ai == -1) return 1;
    if (bi == -1) return -1;
    return ai.compareTo(bi);
  });
  return result;
}
