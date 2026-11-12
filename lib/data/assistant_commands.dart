part of '../main.dart';

enum AssistantCommand {
  removeBackground,
  chooseBackground,
  whiteBackground,
  blackBackground,
  blueBackground,
  greenBackground,
  squareCrop,
  landscapeCrop,
  portraitCrop,
  rotateRight,
  rotateLeft,
  mono,
  warm,
  brighter,
  reset
}

AssistantCommand? parseAssistantCommand(String input) {
  final text = input.trim().toLowerCase();
  if (text.isEmpty || text.length > 300) return null;

  // Фон
  if (text.contains('фон')) {
    if (text.contains('удал') || text.contains('убери') || text.contains('убрать') || text.contains('прозрачн') || text.contains('без фона')) return AssistantCommand.removeBackground;
    if (text.contains('бел')) return AssistantCommand.whiteBackground;
    if (text.contains('черн') || text.contains('темн')) return AssistantCommand.blackBackground;
    if (text.contains('син') || text.contains('голуб')) return AssistantCommand.blueBackground;
    if (text.contains('зелен')) return AssistantCommand.greenBackground;
    return AssistantCommand.chooseBackground;
  }

  // Обрезка
  if (text.contains('обрез') || text.contains('кадрир') || text.contains('квадрат')) {
    if (text.contains('квадрат') || text.contains('1:1')) return AssistantCommand.squareCrop;
    if (text.contains('вертик') || text.contains('3:4') || text.contains('портрет')) return AssistantCommand.portraitCrop;
    if (text.contains('горизонт') || text.contains('4:3') || text.contains('пейзаж')) return AssistantCommand.landscapeCrop;
    return AssistantCommand.squareCrop;
  }

  // Поворот
  if (text.contains('поверн') || text.contains('разверн')) {
    if (text.contains('влев') || text.contains('налев')) return AssistantCommand.rotateLeft;
    return AssistantCommand.rotateRight;
  }

  // Цвета
  if (text.contains('черно-бел') || text.contains('черно бел') || text.contains('ч/б') || text.contains('моно')) return AssistantCommand.mono;
  if (text.contains('тепл')) return AssistantCommand.warm;
  if (text.contains('ярч') || text.contains('осветл') || text.contains('светл')) return AssistantCommand.brighter;
  
  // Сброс
  if (text.contains('сброс') || text.contains('оригинал')) return AssistantCommand.reset;

  return null;
}