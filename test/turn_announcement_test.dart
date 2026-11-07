import 'package:flutter_test/flutter_test.dart';

import 'package:beauty_salons/core/services/turn_announcement.dart';

void main() {
  group('Подсказки поворота не повторяются на каждом тике GPS', () {
    test('этапы по расстоянию', () {
      expect(turnStageForDistance(300), isNull);
      expect(turnStageForDistance(150), TurnStage.far);
      expect(turnStageForDistance(100), isNull); // граница: уже не «далеко»
      expect(turnStageForDistance(70), isNull);
      expect(turnStageForDistance(30), TurnStage.near);
      expect(turnStageForDistance(5), isNull);
    });

    test('несколько тиков подряд в одной зоне — говорим один раз', () {
      TurnAnnouncement? last;
      var spoken = 0;
      for (final d in [158.0, 152.0, 140.0, 127.0, 110.0]) {
        final a = announcementToSpeak(turnIndex: 7, distanceMeters: d, last: last);
        if (a != null) {
          spoken++;
          last = a;
        }
      }
      expect(spoken, 1);
    });

    test('новый этап того же поворота и следующий поворот озвучиваются; после сброса — снова', () {
      TurnAnnouncement? last;
      final far = announcementToSpeak(turnIndex: 7, distanceMeters: 150, last: last);
      expect(far, (turnIndex: 7, stage: TurnStage.far));
      last = far;

      final near = announcementToSpeak(turnIndex: 7, distanceMeters: 35, last: last);
      expect(near, (turnIndex: 7, stage: TurnStage.near));
      last = near;

      expect(announcementToSpeak(turnIndex: 7, distanceMeters: 20, last: last), isNull);
      expect(announcementToSpeak(turnIndex: 12, distanceMeters: 150, last: last), (
        turnIndex: 12,
        stage: TurnStage.far,
      ));

      // перестройка маршрута / повторный старт: last = null — подсказка снова доступна
      expect(announcementToSpeak(turnIndex: 7, distanceMeters: 35, last: null), isNotNull);
    });
  });
}
