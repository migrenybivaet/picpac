part of '../main.dart';

String? fullNameError(String value) {
  final name = value.trim();
  final parts = name.split(RegExp(r'\s+'));
  final word = RegExp(r"^[\p{L}]+(?:[-’'][\p{L}]+)*$", unicode: true);
  if (name.length > 80 || parts.length < 2 || parts.any((p) => !word.hasMatch(p))) {
    return 'Укажите фамилию и имя буквами.';
  }
  return null;
}

// Валидация на белорусские номера (МТС, А1, life, Белтелеком)
String? phoneError(String value) {
  final phone = value.replaceAll(RegExp(r'[^\d+]'), '');
  
  if (!RegExp(r'^(?:\+?375|80)(?:25|29|33|44|17)\d{7}$').hasMatch(phone)) {
    return 'Введите белорусский номер в формате +375 (XX) XXX-XX-XX';
  }
  return null;
}

// Валидация адреса (хотя бы город и улица)
String? addressError(String value) {
  final text = value.trim().toLowerCase();
  if (text.length < 10) return 'Слишком короткий адрес.';

  final cities = ['минск', 'гомель', 'могилев', 'витебск', 'гродно', 'брест', 'борисов', 'барановичи', 'пинск', 'орша', 'мозырь', 'солигорск', 'новополоцк', 'лида', 'молодечно', 'полоцк', 'жлобин'];
  final streetWords = ['ул', 'улица', 'пр', 'проспект', 'пер', 'переулок', 'д', 'дом', 'кв', 'квартира', 'б-р', 'бульвар'];

  bool hasCity = cities.any((c) => text.contains(c));
  bool hasStreet = streetWords.any((s) => text.contains(s));

  if (!hasCity || !hasStreet) {
    return 'Укажите корректный адрес: город и улицу (например, г. Минск, ул. Ленина).';
  }
  return null;
}