import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/playlist_name.dart';

/// Pide el nombre de una playlist. Devuelve el nombre recortado, o `null` si
/// se cancela. Valida con las reglas del dominio ([PlaylistName]).
Future<String?> showPlaylistNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialName = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _PlaylistNameDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
    ),
  );
}

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialName,
  });

  final String title;
  final String confirmLabel;
  final String initialName;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialName.length,
        );
  bool _edited = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  PlaylistNameError? get _error => PlaylistName.validate(_controller.text);

  String? get _errorText {
    // "Vacío" solo se avisa después de escribir, no al abrir el diálogo.
    return switch (_error) {
      PlaylistNameError.empty when _edited => 'Escribe un nombre',
      PlaylistNameError.tooLong =>
        'Máximo ${PlaylistName.maxLength} caracteres',
      _ => null,
    };
  }

  void _submit() {
    if (_error != null) return;
    Navigator.of(context).pop(PlaylistName.normalize(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: PlaylistName.maxLength,
        // Se deja escribir de más para mostrar el error en vez de cortar.
        maxLengthEnforcement: MaxLengthEnforcement.none,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: 'Nombre de la playlist',
          errorText: _errorText,
        ),
        onChanged: (_) => setState(() => _edited = true),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _error == null ? _submit : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
