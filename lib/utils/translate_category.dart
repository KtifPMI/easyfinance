import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'category_translations.dart';

String tCat(BuildContext context, String russianName) {
  return translateCategory(russianName, context.locale.languageCode);
}
