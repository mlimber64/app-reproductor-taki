import 'package:flutter/material.dart';

/// Confirma el borrado de la playlist [name]. Devuelve `true` si se confirma.
Future<bool> confirmDeletePlaylist(BuildContext context, String name) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('¿Eliminar «$name»?'),
      content: const Text(
        'Se borrará la playlist. Las canciones siguen en tu teléfono.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
