import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/dialogo_confirmacion.dart';
import '../../core/widgets/indicador_carga.dart';
import '../../core/widgets/mensaje_error.dart';
import '../../core/widgets/tarjeta_base.dart';
import '../../providers/sesion_provider.dart';
import 'perfil_view_model.dart';
import 'widgets/boton_eliminar_cuenta.dart';
import 'widgets/encabezado_perfil.dart';
import 'widgets/opcion_perfil.dart';

/// Perfil de la usuaria: datos, editar perfil, aviso de privacidad,
/// cerrar sesión y eliminar cuenta. Se usa como pestaña y como ruta.
class PerfilView extends StatelessWidget {
  const PerfilView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider<SesionProvider, PerfilViewModel>(
      create: (c) => PerfilViewModel(
        notificaciones: c.read(),
        auth: c.read(),
        usuarias: c.read(),
      ),
      update: (_, sesion, vm) => vm!..actualizarSesion(sesion),
      child: Consumer<PerfilViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            backgroundColor: AppColors.fondoClaro,
            appBar: AppBar(title: const Text(AppStrings.miPerfil)),
            body: _cuerpo(context, vm),
          );
        },
      ),
    );
  }

  Widget _cuerpo(BuildContext context, PerfilViewModel vm) {
    if (vm.errorUsuaria != null && vm.nombre.isEmpty) {
      return MensajeError(
        mensaje: vm.errorUsuaria!,
        onReintentar: vm.reintentar,
      );
    }
    if (vm.cargando) return const IndicadorCarga();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        EncabezadoPerfil(
          nombre: vm.nombre,
          correo: vm.correo,
          fotoUrl: vm.fotoUrl,
          onTapAvatar: () => context.irA(AppRoutes.editarPerfil),
        ),
        const SizedBox(height: 28),
        const _TituloGrupo(AppStrings.seccionCuenta),
        TarjetaBase(
          padding: EdgeInsets.zero,
          child: OpcionPerfil(
            icono: Icons.edit_outlined,
            titulo: AppStrings.editarPerfil,
            subtitulo: AppStrings.editarPerfilSubtitulo,
            onTap: () => context.irA(AppRoutes.editarPerfil),
          ),
        ),
        const SizedBox(height: 20),
        const _TituloGrupo(AppStrings.seccionPrivacidad),
        TarjetaBase(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              OpcionPerfil(
                icono: Icons.privacy_tip_outlined,
                titulo: AppStrings.avisoPrivacidadTitulo,
                subtitulo: AppStrings.avisoPrivacidadSubtitulo,
                // `false`: solo lectura, sin botón "Acepto".
                onTap: () =>
                    context.irA(AppRoutes.avisoPrivacidad, argumentos: false),
              ),
              const Divider(height: 1, indent: 70, color: AppColors.borde),
              OpcionPerfil(
                icono: Icons.logout,
                titulo: AppStrings.cerrarSesion,
                subtitulo: AppStrings.cerrarSesionSubtitulo,
                cargando: vm.cerrandoSesion,
                onTap: () => _cerrarSesion(context, vm),
              ),
              const Divider(height: 1, indent: 70, color: AppColors.borde),
              BotonEliminarCuenta(vm: vm),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _cerrarSesion(BuildContext context, PerfilViewModel vm) async {
    final confirmado = await DialogoConfirmacion.mostrar(
      context,
      titulo: AppStrings.cerrarSesionTitulo,
      mensaje: AppStrings.cerrarSesionMensaje,
      textoConfirmar: AppStrings.cerrarSesion,
      destructiva: true,
    );
    if (!confirmado || !context.mounted) return;
    final navigator = Navigator.of(context);
    if (await vm.cerrarSesion()) {
      navigator.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    } else if (context.mounted && vm.error != null) {
      SnackbarHelper.error(context, vm.error!);
    }
  }
}

class _TituloGrupo extends StatelessWidget {
  final String texto;

  const _TituloGrupo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(texto, style: AppTextStyles.etiquetaCampo),
    );
  }
}
