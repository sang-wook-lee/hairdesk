import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/core/api_client.dart';
import 'package:hairdesk/features/staff/staff_visibility.dart';

import '../../support/fakes.dart';

void main() {
  test('직원이 1명이면 담당자를 보여주지 않는다 (혼자 일하는 사용자에게는 소음)', () async {
    final repo = FakeStaffRepository([staffOf(1, '원장', '원장')]);

    expect(await shouldShowStaff(repo), isFalse);
  });

  test('직원이 2명 이상이면 담당자를 보여준다', () async {
    final repo = FakeStaffRepository([staffOf(1, '원장', '원장'), staffOf(2, '이지수', '실장')]);

    expect(await shouldShowStaff(repo), isTrue);
  });

  test('근무를 마친 직원도 센다: 지금은 1명이 근무 중이어도 지난 예약에 다른 직원이 남아 있다', () async {
    final repo = FakeStaffRepository([
      staffOf(1, '원장', '원장'),
      staffOf(4, '서하윤', '인턴', active: false),
    ]);

    expect(await shouldShowStaff(repo), isTrue);
    expect(repo.fetchedWithInactive, [true]); // 근무 종료 직원까지 요청했다
  });

  test('직원 목록을 못 불러와도 예외를 올리지 않고 "보여주지 않는다"로 처리한다 (일정은 계속 보여야 한다)', () async {
    final repo = FakeStaffRepository([staffOf(1, '원장', '원장'), staffOf(2, '이지수', '실장')])
      ..failOnFetch = ApiException(500, '서버 오류');

    expect(await shouldShowStaff(repo), isFalse);
  });
}
