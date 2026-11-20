import 'package:flutter_test/flutter_test.dart';
import 'package:hairdesk/features/staff/staff.dart';

void main() {
  test('서버 응답 JSON을 Staff로 바꾼다', () {
    final staff = Staff.fromJson({
      'id': 2,
      'name': '이지수',
      'position': '실장',
      'owner': false,
      'active': true,
    });

    expect(staff.id, 2);
    expect(staff.name, '이지수');
    expect(staff.position, '실장');
    expect(staff.owner, isFalse);
    expect(staff.active, isTrue);
  });

  test('화면에 보여줄 이름은 번호를 함께 적는다 (동명이인 구별)', () {
    const a = Staff(id: 2, name: '이지수', position: '실장', owner: false, active: true);
    const b = Staff(id: 5, name: '이지수', position: '실장', owner: false, active: true);

    expect(a.displayName, '이지수 (#2)');
    expect(b.displayName, '이지수 (#5)'); // 이름과 직책이 같아도 번호로 구별된다
    expect(formatStaffName('원장', 1), '원장 (#1)');
  });

  test('등록·수정 요청에는 이름과 직책만 담고, 주인·근무 여부는 보내지 않는다', () {
    const input = StaffInput(name: '박민수', position: '디자이너');

    expect(input.toJson(), {'name': '박민수', 'position': '디자이너'});
  });
}
