/// Этап голосовой подсказки перед поворотом
enum TurnStage { far, near }

/// Озвученная подсказка: какой поворот маршрута и на каком этапе.
typedef TurnAnnouncement = ({int turnIndex, TurnStage stage});

/// Этап подсказки для расстояния до поворота (в метрах); `null` — говорить рано или поздно.
TurnStage? turnStageForDistance(double meters) {
  if (meters <= 160 && meters > 100) return TurnStage.far;
  if (meters <= 40 && meters > 10) return TurnStage.near;
  return null;
}

/// Решает, нужно ли озвучить подсказку сейчас. Возвращает её, если она отличается от [last]
/// (другой поворот или другой этап), иначе `null` — повторять фразу на каждом тике не нужно.
TurnAnnouncement? announcementToSpeak({
  required int turnIndex,
  required double distanceMeters,
  required TurnAnnouncement? last,
}) {
  final stage = turnStageForDistance(distanceMeters);
  if (stage == null) return null;
  final next = (turnIndex: turnIndex, stage: stage);
  return next == last ? null : next;
}
