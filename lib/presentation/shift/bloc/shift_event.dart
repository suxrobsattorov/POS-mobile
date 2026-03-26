abstract class ShiftEvent {}

class ShiftCheckRequested extends ShiftEvent {}

class ShiftOpenRequested extends ShiftEvent {
  final double openingBalance;
  final String? note;
  ShiftOpenRequested({required this.openingBalance, this.note});
}

class ShiftCloseRequested extends ShiftEvent {
  final double closingBalance;
  final String? note;
  ShiftCloseRequested({required this.closingBalance, this.note});
}
