import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// An event's `name` in words, such as "Submit form" for `submit_form` or
/// `submitForm`: the label of an action whose button shows no text.
///
/// An underscore, a hyphen or a space separates words, as does an uppercase
/// letter after a lowercase one. The words are lowercase, but for the first
/// letter. A name made only of separators, such as `_`, gives an empty
/// string.
///
/// Internal to the package.
@internal
String a2uiWords(String name) {
  final words = <String>[];
  var word = '';
  for (final character in name.characters) {
    final separates = character == '_' || character == '-' || character == ' ';
    final startsWord = _isUppercase(character) && word.isNotEmpty && _isLowercase(word.characters.last);
    if (separates || startsWord) {
      if (word.isNotEmpty) words.add(word);
      word = separates ? '' : character;
    } else {
      word += character;
    }
  }
  if (word.isNotEmpty) words.add(word);
  // A capital I with a dot is the one letter whose lowercase is two
  // characters, an i and the dot, which `toLowerCase` writes as a plain i.
  final sentence = words.join(' ').replaceAll('\u0130', 'i\u0307').toLowerCase();
  if (sentence.isEmpty) return sentence;
  final first = sentence.characters.first;
  return first.toUpperCase() + sentence.substring(first.length);
}

bool _isUppercase(String character) => character.toLowerCase() != character && character.toUpperCase() == character;

bool _isLowercase(String character) => character.toUpperCase() != character && character.toLowerCase() == character;
