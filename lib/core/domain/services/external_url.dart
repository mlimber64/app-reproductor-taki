/// Un enlace que la app puede abrir fuera de ella: `http` o `https`, con host.
///
/// Es la única regla de qué se abre; no reescribe ni «arregla» la URL (no
/// añade esquema, no quita parámetros). Cualquier otra cosa devuelve `null`.
Uri? openableUrl(Uri? url) {
  if (url == null) return null;
  final scheme = url.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  if (url.host.isEmpty) return null;
  return url;
}

/// Como [openableUrl] para un texto: vacío, con cualquier espacio en blanco o
/// malformado → `null` (no se recorta ni se corrige).
Uri? openableUrlFromText(String? text) {
  if (text == null || text.isEmpty || text.contains(RegExp(r'\s'))) {
    return null;
  }
  final url = Uri.tryParse(text);
  return openableUrl(url);
}
