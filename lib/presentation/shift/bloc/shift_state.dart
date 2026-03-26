import '../../../data/remote/shift_service.dart';

enum ShiftStatus { initial, loading, open, closed, error }

class ShiftState {
  final ShiftStatus status;
  final ShiftStats? shift;
  final String? errorMessage;
  final String? successMessage;

  const ShiftState({
    this.status = ShiftStatus.initial,
    this.shift,
    this.errorMessage,
    this.successMessage,
  });

  bool get isOpen => status == ShiftStatus.open && shift != null;

  ShiftState copyWith({
    ShiftStatus? status,
    ShiftStats? shift,
    String? errorMessage,
    String? successMessage,
    bool clearShift = false,
  }) {
    return ShiftState(
      status: status ?? this.status,
      shift: clearShift ? null : (shift ?? this.shift),
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}
