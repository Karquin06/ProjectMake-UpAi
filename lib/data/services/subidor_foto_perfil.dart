import 'dart:typed_data';

/// Contrato para subir la foto de perfil a Firebase Storage en
/// `perfiles/{uid}/foto.jpg`. Lo usa `UsuariaProvider` al editar el perfil.
///
/// Dueño del contrato: Karlos. La implementación real la aporta el
/// `StorageService` de Jaider: basta un adaptador que implemente esta
/// interfaz y registrarlo en `app_providers.dart` (ver PUNTO DE CAMBIO).
abstract class SubidorFotoPerfil {
  /// Ruta acordada en las reglas de Storage.
  static String rutaFoto(String uid) => 'perfiles/$uid/foto.jpg';

  /// Sube [jpeg] (ya reducido con `ImageUtils.prepararParaSubir`) y
  /// devuelve la URL de descarga, o `null` si la subida no está disponible.
  Future<String?> subirFotoPerfil({
    required String uid,
    required Uint8List jpeg,
  });
}

/// Implementación temporal mientras no exista `StorageService`
/// (`AppConstants.usarMockStorage`): no sube nada y devuelve `null`, así la
/// app guarda el nombre y avisa que la foto queda pendiente.
class SubidorFotoPerfilMock implements SubidorFotoPerfil {
  @override
  Future<String?> subirFotoPerfil({
    required String uid,
    required Uint8List jpeg,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return null;
  }
}
