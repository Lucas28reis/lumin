class PeriodicCare {
  const PeriodicCare(this.date, this.time, this.days);
  final String date;
  final String time;
  final int days;

  static const labels = {
    'deworm': 'Vermífugo',
    'medication': 'Remédio',
    'bath': 'Banho',
  };
  Map<String, dynamic> toJson() => {'date': date, 'time': time, 'days': days};
  factory PeriodicCare.fromJson(Map<String, dynamic> json) =>
      PeriodicCare(json['date'], json['time'], json['days']);
}
