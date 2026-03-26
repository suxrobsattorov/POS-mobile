import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/remote/shift_service.dart';
import 'shift_event.dart';
import 'shift_state.dart';

class ShiftBloc extends Bloc<ShiftEvent, ShiftState> {
  final ShiftService _shiftService;

  ShiftBloc({required ShiftService shiftService})
      : _shiftService = shiftService,
        super(const ShiftState()) {
    on<ShiftCheckRequested>(_onCheck);
    on<ShiftOpenRequested>(_onOpen);
    on<ShiftCloseRequested>(_onClose);
  }

  Future<void> _onCheck(
      ShiftCheckRequested event, Emitter<ShiftState> emit) async {
    emit(state.copyWith(status: ShiftStatus.loading));
    try {
      await _shiftService.checkCurrentShift();
      final shift = _shiftService.currentShift;
      if (shift != null) {
        emit(state.copyWith(status: ShiftStatus.open, shift: shift));
      } else {
        emit(state.copyWith(status: ShiftStatus.closed, clearShift: true));
      }
    } catch (e) {
      emit(state.copyWith(
        status: ShiftStatus.closed,
        clearShift: true,
        errorMessage: 'Smena ma\'lumotlari yuklanmadi',
      ));
    }
  }

  Future<void> _onOpen(
      ShiftOpenRequested event, Emitter<ShiftState> emit) async {
    emit(state.copyWith(status: ShiftStatus.loading));
    try {
      await _shiftService.openShift(openingBalance: event.openingBalance);
      final shift = _shiftService.currentShift;
      emit(state.copyWith(
        status: ShiftStatus.open,
        shift: shift,
        successMessage: 'Smena muvaffaqiyatli ochildi',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ShiftStatus.closed,
        errorMessage: 'Smena ochishda xatolik: ${e.toString()}',
      ));
    }
  }

  Future<void> _onClose(
      ShiftCloseRequested event, Emitter<ShiftState> emit) async {
    emit(state.copyWith(status: ShiftStatus.loading));
    try {
      await _shiftService.closeShift();
      emit(state.copyWith(
        status: ShiftStatus.closed,
        clearShift: true,
        successMessage: 'Smena yopildi',
      ));
    } catch (e) {
      // Smena holati o'zgarmagan
      emit(state.copyWith(
        status: _shiftService.currentShift != null
            ? ShiftStatus.open
            : ShiftStatus.closed,
        shift: _shiftService.currentShift,
        errorMessage: 'Smena yopishda xatolik: ${e.toString()}',
      ));
    }
  }
}
