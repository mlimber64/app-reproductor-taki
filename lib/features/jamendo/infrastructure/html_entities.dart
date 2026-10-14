/// Decodifica las entidades HTML con las que Jamendo entrega algunos textos
/// (`Don&#039;t Cry`, `Tom &amp; Jerry`).
///
/// Es un decodificador **pequeño y específico**, no un intérprete de HTML:
/// - **Una sola pasada**, de izquierda a derecha: lo decodificado no se vuelve
///   a examinar (`&amp;quot;` → `&quot;`, nunca `"`).
/// - Entidades **nombradas** admitidas (sensibles a mayúsculas): `amp`, `quot`,
///   `apos`, `lt`, `gt` y `nbsp` (este último, como un espacio normal).
/// - Referencias **numéricas**, decimales (`&#039;`) y hexadecimales
///   (`&#x27;`, `&#X27;`), de un valor escalar Unicode válido (1…10FFFF, sin
///   los sustitutos D800–DFFF).
/// - **Se dejan intactos**: entidades desconocidas (`&foo;`), sin `;` (`&amp`),
///   un `&` suelto (`AT&T`), numéricas inválidas (`&#0;`, sustitutos, fuera de
///   rango) y cualquier otro texto, incluidas las etiquetas (`<b>` no se toca).
///
/// Solo para texto que se muestra; no se aplica a URLs, ids ni licencias.
String decodeHtmlEntities(String text) {
  return text.replaceAllMapped(_entity, (match) {
    final decimal = match.group(1);
    final hex = match.group(2);
    final named = match.group(3);
    if (named != null) return _named[named] ?? match[0]!;
    final code = decimal != null
        ? int.tryParse(decimal)
        : int.tryParse(hex!, radix: 16);
    return _fromCodePoint(code) ?? match[0]!;
  });
}

final RegExp _entity = RegExp(
  r'&(?:#([0-9]+)|#[xX]([0-9a-fA-F]+)|([A-Za-z][A-Za-z0-9]*));',
);

const Map<String, String> _named = {
  'amp': '&',
  'quot': '"',
  'apos': "'",
  'lt': '<',
  'gt': '>',
  'nbsp': ' ',
};

String? _fromCodePoint(int? code) {
  if (code == null || code < 1 || code > 0x10FFFF) return null;
  if (code >= 0xD800 && code <= 0xDFFF) return null;
  return String.fromCharCode(code);
}
