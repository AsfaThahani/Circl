import 'package:flutter/material.dart' as flutter;
import '../l10n/app_localizations.dart';

class Text extends flutter.StatelessWidget {
  final String? data;
  final flutter.InlineSpan? textSpan;
  final flutter.TextStyle? style;
  final flutter.StrutStyle? strutStyle;
  final flutter.TextAlign? textAlign;
  final flutter.TextDirection? textDirection;
  final flutter.Locale? locale;
  final bool? softWrap;
  final flutter.TextOverflow? overflow;
  final double? textScaleFactor;
  final int? maxLines;
  final String? semanticsLabel;
  final flutter.TextWidthBasis? textWidthBasis;
  final flutter.TextHeightBehavior? textHeightBehavior;
  final flutter.Color? selectionColor;

  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    flutter.InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  @override
  flutter.Widget build(flutter.BuildContext context) {
    final l10n = AppLocalizations.of(context);
    flutter.TextStyle? finalStyle = style;

    bool shouldScale = false;
    if (l10n?.localeName == 'ta') {
      if (data != null && RegExp(r'[\u0B80-\u0BFF]').hasMatch(data!)) {
        shouldScale = true;
      } else if (textSpan != null) {
        final spanText = textSpan!.toPlainText();
        if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(spanText)) {
          shouldScale = true;
        }
      }
    }

    if (shouldScale) {
      final double currentFontSize = style?.fontSize ?? 14.0;
      final double newFontSize = currentFontSize > 2 ? currentFontSize - 2 : currentFontSize;
      finalStyle = (style ?? const flutter.TextStyle()).copyWith(fontSize: newFontSize);
    }

    if (textSpan != null) {
      return flutter.Text.rich(
        textSpan!,
        style: finalStyle,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaleFactor: textScaleFactor,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }

    return flutter.Text(
      data ?? '',
      style: finalStyle,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaleFactor: textScaleFactor,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
