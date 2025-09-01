import 'package:intl/intl.dart';

String formatBrl(dynamic value) {
  if (value == null) return 'R\$ 0,00';
  double? amount;
  if (value is num) {
    amount = value.toDouble();
  } else {
    final raw = value.toString().trim();
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    amount = double.tryParse(normalized);
  }
  final f = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  return f.format(amount ?? 0);
}


