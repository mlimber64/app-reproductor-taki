/// Cancela una acción programada. Llamarla de nuevo no hace nada.
typedef CancelScheduled = void Function();

/// Programa una acción tras una espera. Abstrae el reloj para que el debounce
/// se pruebe sin esperar de verdad.
abstract interface class SearchScheduler {
  CancelScheduled schedule(Duration delay, void Function() action);
}
