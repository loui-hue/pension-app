/// Contraseñas que elige una persona: al menos 8 caracteres, con letras y números.
/// Es la misma regla del servidor (app/Reglas/ReglasDeContrasena.php); aquí solo
/// sirve para avisar antes de enviar. Se prueba en test/contrasena_test.dart.
const int minimoContrasena = 8;

final _letra = RegExp(r'\p{L}', unicode: true);
final _numero = RegExp(r'\p{N}', unicode: true);

bool esContrasenaSegura(String password) =>
    password.length >= minimoContrasena && _letra.hasMatch(password) && _numero.hasMatch(password);

/// Mensaje si la contraseña no cumple, o null si está bien.
String? problemaDeContrasena(String password, {String cual = 'La contraseña'}) =>
    esContrasenaSegura(password)
        ? null
        : '$cual debe tener al menos $minimoContrasena caracteres, con letras y números';
