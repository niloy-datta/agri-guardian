class Formatters {
  static String formatCurrency(double amount) => '৳ ${amount.toStringAsFixed(0)}';
  static String formatPercentage(double percent) => '${percent.toStringAsFixed(0)}%';
}
