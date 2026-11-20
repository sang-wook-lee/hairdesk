import 'staff_repository.dart';

/// 예약에 담당자를 보여줄지 정한다. 직원이 **2명 이상**일 때만 보여준다. (ADR 0011과 같은 원칙)
///
/// 혼자 일하는 사용자에게는 모든 예약 줄에 같은 이름이 반복되어 소음이 된다.
/// 근무를 마친 직원도 센다: 지난 예약에 그 직원이 남아 있고, 직원이 둘이었던 적이 있으면 구분이 필요하다.
///
/// 담당자 표시는 보조 정보다. 직원 목록을 못 불러와도 일정 자체는 보여줘야 하므로,
/// 실패하면 예외를 올리지 않고 "보여주지 않는다"(false)로 처리한다.
Future<bool> shouldShowStaff(StaffRepository repository) async {
  try {
    final everyone = await repository.fetchAll(includeInactive: true);
    return everyone.length >= 2;
  } catch (_) {
    return false;
  }
}
