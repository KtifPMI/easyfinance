const Map<String, String> currencyIdToCode = {
  '1': 'RUB', '2': 'USD', '3': 'EUR', '4': 'UAH', '5': 'AUD',
  '6': 'BYR', '7': 'DKK', '8': 'ISK', '9': 'KZT', '10': 'CAD',
  '11': 'CNY', '12': 'NOK', '13': 'XDR', '14': 'SGD', '15': 'TRY',
  '16': 'GBP', '17': 'SEK', '18': 'CHF', '19': 'JPY',
  '20': 'AFN', '21': 'ALL', '23': 'ADP', '24': 'AZN', '30': 'AMD',
  '41': 'BIF', '53': 'CZK', '54': 'DOP', '59': 'FKP', '70': 'HKD',
  '71': 'HUF', '72': 'INR', '76': 'ILS', '81': 'KRW', '94': 'MYR',
  '99': 'MXN', '100': 'MNT', '110': 'NZD', '118': 'PHP', '130': 'VND',
  '139': 'THB', '158': 'TWD', '163': 'TJS', '169': 'PLN', '170': 'BRL',
  '174': 'ARS', '176': 'XAU', '177': 'XAG', '178': 'XPT', '184': 'XPD',
  '186': 'BYN',
};

const Map<String, String> currencyCodeToId = {
  'RUB': '1', 'USD': '2', 'EUR': '3', 'UAH': '4', 'AUD': '5',
  'BYR': '6', 'DKK': '7', 'ISK': '8', 'KZT': '9', 'CAD': '10',
  'CNY': '11', 'NOK': '12', 'XDR': '13', 'SGD': '14', 'TRY': '15',
  'GBP': '16', 'SEK': '17', 'CHF': '18', 'JPY': '19',
  'AFN': '20', 'ALL': '21', 'ADP': '23', 'AZN': '24', 'AMD': '30',
  'BIF': '41', 'CZK': '53', 'DOP': '54', 'FKP': '59', 'HKD': '70',
  'HUF': '71', 'INR': '72', 'ILS': '76', 'KRW': '81', 'MYR': '94',
  'MXN': '99', 'MNT': '100', 'NZD': '110', 'PHP': '118', 'VND': '130',
  'THB': '139', 'TWD': '158', 'TJS': '163', 'PLN': '169', 'BRL': '170',
  'ARS': '174', 'XAU': '176', 'XAG': '177', 'XPT': '178', 'XPD': '184',
  'BYN': '186',
};

const Map<String, String> currencySymbols = {
  'RUB': '₽', 'USD': '\$', 'EUR': '€', 'GBP': '£', 'CHF': 'CHF',
  'CNY': '¥', 'JPY': '¥', 'BYN': 'Br', 'UAH': '₴', 'KZT': '₸',
  'PLN': 'zł', 'CZK': 'Kč', 'SEK': 'kr', 'NOK': 'kr',
  'XAG': 'Ag', 'XAU': 'Au',
};

/// Валюты, чей знак по национальному стандарту ставится ПОСЛЕ суммы ($/£/¥/₩ ... ставят перед).
const Set<String> currenciesWithPostfixSign = {
  'RUB', 'EUR', 'CHF', 'BYN', 'PLN', 'CZK', 'HUF', 'SEK', 'NOK', 'DKK',
  'BGN', 'VND', 'MNT', 'UZS', 'AMD', 'AZN', 'GEL', 'UAH', 'KZT',
};

/// Валюты, чей знак по национальному стандарту ставится ПЕРЕД суммой.
const Set<String> currenciesWithPrefixSign = {
  'USD', 'GBP', 'CNY', 'JPY', 'CAD', 'AUD', 'NZD', 'HKD', 'SGD',
  'INR', 'TRY', 'ILS', 'KRW', 'THB', 'MXN', 'BRL', 'COP', 'ZAR',
};

/// ПОЛНОЕ правило: для русского языка все знаки ставятся после суммы
/// (русская типографика), для иностранных — по национальному стандарту валюты.
bool signAfterAmount({String? locale, String currency = 'RUB'}) {
  final loc = locale ?? 'ru';
  if (loc == 'ru') return true;
  return currenciesWithPostfixSign.contains(currency);
}

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
