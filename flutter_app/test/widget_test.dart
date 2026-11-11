import 'package:flutter_test/flutter_test.dart';
import 'package:viril/core/models/viril_state.dart';

void main() {
  test('Viril starts with a clean level-one state', () {
    final state = VirilState.defaults();
    expect(state.xp, 0);
    expect(state.level, 1);
    expect(state.goals, isEmpty);
  });
}
