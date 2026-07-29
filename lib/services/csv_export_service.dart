import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../store/finance_store.dart';

class CsvExportService {
  static Future<String> export(FinanceStore store, DateTime start, DateTime end) async {
    final ops = store.operations.where((o) {
      if (o.isDeleted) return false;
      final d = DateTime.tryParse(o.date);
      return d != null && !d.isBefore(start) && !d.isAfter(DateTime(end.year, end.month, end.day, 23, 59, 59));
    }).toList()..sort((a, b) => a.date.compareTo(b.date));

    final buf = StringBuffer();
    buf.writeln('Дата;Тип;Категория;Счёт;Сумма;Комментарий');
    for (final op in ops) {
      final date = op.date.substring(0, 10);
      final type = op.type == 'income' ? 'Доход' : op.type == 'transfer' ? 'Перевод' : 'Расход';
      final cat = store.getCategory(op.categoryId)?.name ?? '';
      final acc = store.getAccount(op.accountId)?.name ?? '';
      final amount = op.amount.toStringAsFixed(2).replaceAll('.', ',');
      final comment = (op.comment ?? '').replaceAll(';', ',');
      buf.writeln('$date;$type;$cat;$acc;$amount;$comment');
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/easyfinance_export_${start.toIso8601String().substring(0, 10)}_${end.toIso8601String().substring(0, 10)}.csv');
    await file.writeAsString(buf.toString());
    await OpenFilex.open(file.path);
    return file.path;
  }
}
