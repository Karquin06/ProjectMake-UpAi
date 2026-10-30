import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/extensions/enum_labels.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/avatar_usuaria.dart';
import '../../core/widgets/dialogo_confirmacion.dart';
import '../../core/widgets/indicador_carga.dart';
import '../../core/widgets/mensaje_error.dart';
import '../../core/widgets/tarjeta_base.dart';
import '../../models/perfil_colorimetria_model.dart';
import '../../providers/colorimetria_provider.dart';
import '../../providers/sesion_provider.dart';
import 'perfil_view_model.dart';
import 'widgets/boton_eliminar_cuenta.dart';
import 'widgets/opcion_perfil.dart';

/// Perfil de la usuaria: datos, colorimetría, editar perfil, aviso de
/// privacidad, cerrar sesión y eliminar cuenta. Se usa como pestaña y como
/// ruta.
class PerfilView extends StatelessWidget {
  const PerfilView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider<SesionProvider, PerfilViewModel>(
      create: (c) => PerfilViewModel(
        notificaciones: c.read(),
        auth: c.read(),
        usuarias: c.read(),
        colorimetria: _colorimetria(c),
      ),
      update: (_, sesion, vm) => vm!..actualizarSesion(sesion),
      child: Consumer<PerfilViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            backgroundColor: AppColors.fondoClaro,
            body: SafeArea(child: _cuerpo(context, vm)),
          );
        },
      ),
    );
  }

  /// La colorimetría es opcional (las pruebas del perfil no la registran).
  static ColorimetriaProvider? _colorimetria(BuildContext c) {
    try {
      return c.read<ColorimetriaProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Widget _cuerpo(BuildContext context, PerfilViewModel vm) {
    if (vm.errorUsuaria != null && vm.nombre.isEmpty) {
      return MensajeError(
        mensaje: vm.errorUsuaria!,
        onReintentar: vm.reintentar,
      );
    }
    if (vm.cargando) return const IndicadorCarga();

    void editar() => context.irA(AppRoutes.editarPerfil);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.miPerfil,
                style: AppTextStyles.tituloPantalla.copyWith(fontSize: 26),
              ),
            ),
            _BotonCuadrado(
              icono: Icons.settings_outlined,
              tooltip: AppStrings.editarPerfil,
              onTap: editar,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            AvatarUsuaria(
              nombre: vm.nombre,
              fotoUrl: vm.fotoUrl,
              radio: 46,
              onTap: editar,
              mostrarEditar: true,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vm.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.tituloPantalla.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vm.correo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitulo,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _MisDatos(vm: vm, onEditar: editar),
        const SizedBox(height: 16),
        _MiColorimetria(perfil: vm.perfilColorimetria),
        const SizedBox(height: 16),
        TarjetaBase(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              OpcionPerfil(
                icono: Icons.edit_outlined,
                titulo: AppStrings.editarPerfil,
                onTap: editar,
              ),
              // Solo la cuenta admin ve el acceso al catálogo.
              if (vm.esAdmin) ...[
                const _Separador(),
                OpcionPerfil(
                  icono: Icons.inventory_2_outlined,
                  titulo: AppStrings.catalogoTitulo,
                  onTap: () => context.irA(AppRoutes.catalogoAdmin),
                ),
              ],
              const _Separador(),
              OpcionPerfil(
                icono: Icons.privacy_tip_outlined,
                titulo: AppStrings.avisoPrivacidadTitulo,
                // `false`: solo lectura, sin botón "Acepto".
                onTap: () =>
                    context.irA(AppRoutes.avisoPrivacidad, argumentos: false),
              ),
              const _Separador(),
              OpcionPerfil(
                icono: Icons.logout,
                titulo: AppStrings.cerrarSesion,
                cargando: vm.cerrandoSesion,
                onTap: () => _cerrarSesion(context, vm),
              ),
              const _Separador(),
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

class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) => const Divider(
    height: 1,
    indent: 60,
    endIndent: 16,
    color: AppColors.borde,
  );
}

/// Botón cuadrado rosado de las cabeceras (ajustes, nueva conversación).
class _BotonCuadrado extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final VoidCallback onTap;

  const _BotonCuadrado({
    required this.icono,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: AppColors.fondoRosaSuave,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 52,
          child: Icon(icono, color: AppColors.violeta),
        ),
      ),
    ),
  );
}

/// Título de tarjeta con su icono.
class _TituloTarjeta extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Widget? accion;

  const _TituloTarjeta(this.icono, this.texto, {this.accion});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icono, color: AppColors.violeta, size: 26),
      const SizedBox(width: 14),
      Expanded(
        child: Text(
          texto,
          style: AppTextStyles.botonSecundario.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.violetaOscuro,
          ),
        ),
      ),
      ?accion,
    ],
  );
}

class _MisDatos extends StatelessWidget {
  final PerfilViewModel vm;
  final VoidCallback onEditar;

  const _MisDatos({required this.vm, required this.onEditar});

  @override
  Widget build(BuildContext context) {
    return TarjetaBase(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        children: [
          const _TituloTarjeta(Icons.person_outline, AppStrings.misDatos),
          const SizedBox(height: 6),
          _Dato(
            icono: Icons.person_outline,
            etiqueta: AppStrings.datoNombre,
            valor: vm.nombre,
            onTap: onEditar,
          ),
          _Dato(
            icono: Icons.mail_outline,
            etiqueta: AppStrings.datoCorreo,
            valor: vm.correo,
          ),
          if (vm.miembroDesde != null)
            _Dato(
              icono: Icons.calendar_today_outlined,
              etiqueta: AppStrings.datoMiembroDesde,
              valor: vm.miembroDesde!,
            ),
          _Dato(
            icono: Icons.verified_user_outlined,
            etiqueta: AppStrings.datoTipoCuenta,
            valor: vm.esAdmin
                ? AppStrings.cuentaAdministradora
                : AppStrings.cuentaUsuaria,
            destacado: true,
            ultimo: true,
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;
  final VoidCallback? onTap;
  final bool destacado;
  final bool ultimo;

  const _Dato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.onTap,
    this.destacado = false,
    this.ultimo = false,
  });

  @override
  Widget build(BuildContext context) {
    final valorTexto = Text(
      valor,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: TextStyle(
        fontSize: 13.5,
        color: destacado ? AppColors.fucsia : AppColors.textoPrincipal,
        fontWeight: destacado ? FontWeight.w600 : FontWeight.w400,
      ),
    );
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: ultimo
            ? null
            : const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borde)),
              ),
        child: Row(
          children: [
            Icon(icono, color: AppColors.violeta, size: 22),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Text(
                etiqueta,
                style: AppTextStyles.subtitulo.copyWith(fontSize: 13.5),
              ),
            ),
            Expanded(
              flex: 5,
              child: destacado
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.fondoRosaSuave,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: valorTexto,
                      ),
                    )
                  : valorTexto,
            ),
            SizedBox(
              width: 26,
              child: onTap == null
                  ? null
                  : const Icon(
                      Icons.chevron_right,
                      color: AppColors.textoSecundario,
                      size: 20,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estación, subtono, contraste e intensidad; sin análisis invita a hacerlo.
class _MiColorimetria extends StatelessWidget {
  final PerfilColorimetria? perfil;

  const _MiColorimetria({required this.perfil});

  @override
  Widget build(BuildContext context) {
    final p = perfil;
    void abrir() =>
        context.irA(p == null ? AppRoutes.colorimetria : AppRoutes.paleta);
    return TarjetaBase(
      onTap: abrir,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TituloTarjeta(
            Icons.palette_outlined,
            AppStrings.miColorimetria,
            accion: Icon(Icons.chevron_right, color: AppColors.violeta),
          ),
          const SizedBox(height: 14),
          if (p == null) ...[
            Text(
              AppStrings.perfilSinColorimetria,
              style: AppTextStyles.subtitulo.copyWith(fontSize: 13.5),
            ),
            TextButton(
              onPressed: abrir,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.fucsia,
              ),
              child: const Text(AppStrings.hacerMiAnalisis),
            ),
          ] else ...[
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: p.estacionColor.color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    p.estacionColor.icono,
                    color: p.estacionColor.color,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '${p.estacionColor.etiqueta} '
                    '${p.subtono.etiqueta.toLowerCase()}',
                    style: AppTextStyles.tituloPantalla.copyWith(fontSize: 18),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.fondoRosaSuave,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 16, color: AppColors.violeta),
                      SizedBox(width: 4),
                      Text(
                        AppStrings.colorimetriaActiva,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.violeta,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                children: [
                  _Rasgo(AppStrings.etiquetaSubtono, p.subtono.etiqueta),
                  const VerticalDivider(color: AppColors.borde),
                  _Rasgo(AppStrings.etiquetaContraste, p.contraste.etiqueta),
                  const VerticalDivider(color: AppColors.borde),
                  _Rasgo(AppStrings.etiquetaIntensidad, p.intensidad.etiqueta),
                ],
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: abrir,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.fucsia,
              ),
              child: const Text(AppStrings.verDetalles),
            ),
          ],
        ],
      ),
    );
  }
}

class _Rasgo extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _Rasgo(this.etiqueta, this.valor);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(etiqueta, style: AppTextStyles.subtitulo.copyWith(fontSize: 11.5)),
        const SizedBox(height: 4),
        Text(
          valor,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textoPrincipal,
          ),
        ),
      ],
    ),
  );
}
