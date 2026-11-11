import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/enum_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/widgets/tarjeta_base.dart';
import '../../../models/enums.dart';
import '../../../models/estadisticas_marca.dart';
import '../../recomendaciones/widgets/imagen_item.dart';

/// Piezas visuales de los dashboards (admin general y "Mi marca") — Ana.
///
/// Todo usa el degradado fucsia → violeta de la app, teñido con el color
/// de cada marca, y los colores de cada estación.

/// Color de una marca (o el fucsia de la app si no tiene uno válido).
Color colorDeMarca(String hex) =>
    hex.trim().isEmpty ? AppColors.fucsia : ColorUtils.desdeHex(hex, porDefecto: AppColors.fucsia);

/// Degradado del encabezado: del color de la marca al violeta de la app.
LinearGradient degradadoMarca(Color color) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(color, AppColors.fucsia, 0.15)!,
        Color.lerp(color, AppColors.violetaOscuro, 0.55)!,
      ],
    );

/// Formatea números grandes: 950 · 1,2 k · 3,4 M.
String numeroCorto(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) {
    final k = n / 1000;
    return '${k.toStringAsFixed(k >= 100 ? 0 : 1).replaceAll('.', ',')} k';
  }
  final m = n / 1000000;
  return '${m.toStringAsFixed(1).replaceAll('.', ',')} M';
}

/// Promedio de estrellas con coma decimal (4,6) o "—" si no hay.
String promedioTexto(double p) =>
    p <= 0 ? '—' : p.toStringAsFixed(1).replaceAll('.', ',');

// ---------------------------------------------------------------------------
// Avatar de marca
// ---------------------------------------------------------------------------

/// Logo redondo de la marca, o sus iniciales sobre su color.
class AvatarMarca extends StatelessWidget {
  final String nombre;
  final String logoUrl;
  final String colorHex;
  final double tamano;
  final bool conBorde;

  const AvatarMarca({
    super.key,
    required this.nombre,
    this.logoUrl = '',
    this.colorHex = '',
    this.tamano = 48,
    this.conBorde = false,
  });

  String get _iniciales {
    final partes = nombre
        .trim()
        .split(RegExp(r"[\s'’\-]+"))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) {
      final p = partes.first;
      return p.substring(0, p.length < 2 ? p.length : 2).toUpperCase();
    }
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = colorDeMarca(colorHex);
    final iniciales = Center(
      child: Text(
        _iniciales,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: tamano * 0.36,
          letterSpacing: 0.5,
        ),
      ),
    );
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: degradadoMarca(color),
        border: conBorde ? Border.all(color: Colors.white, width: 3) : null,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl.isEmpty
          ? iniciales
          : Image.network(
              logoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => iniciales,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Encabezado con degradado
// ---------------------------------------------------------------------------

/// Encabezado grande de un panel: degradado, burbujas decorativas, avatar
/// (opcional), título, subtítulo y una píldora de privacidad.
class EncabezadoPanel extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Color color;
  final Widget? avatar;
  final List<Widget> acciones;
  final Widget? pie;

  const EncabezadoPanel({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.color = AppColors.fucsia,
    this.avatar,
    this.acciones = const [],
    this.pie,
  });

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    final puedeVolver = Navigator.of(context).canPop();
    return Container(
      decoration: BoxDecoration(
        gradient: degradadoMarca(color),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Burbujas decorativas.
          Positioned(
            right: -40,
            top: -30,
            child: _Burbuja(tamano: 170, opacidad: 0.10),
          ),
          Positioned(
            left: -30,
            bottom: -50,
            child: _Burbuja(tamano: 130, opacidad: 0.08),
          ),
          Positioned(
            right: 60,
            bottom: 18,
            child: _Burbuja(tamano: 26, opacidad: 0.18),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(8, arriba + 4, 8, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (puedeVolver)
                      const BackButton(color: Colors.white)
                    else
                      const SizedBox(width: 48, height: 48),
                    const Spacer(),
                    ...acciones,
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      if (avatar != null) ...[
                        avatar!,
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titulo,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitulo,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (pie != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                    child: pie!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  final double tamano;
  final double opacidad;

  const _Burbuja({required this.tamano, required this.opacidad});

  @override
  Widget build(BuildContext context) => Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacidad),
        ),
      );
}

/// Píldora translúcida para el pie del encabezado (privacidad, favorita…).
class PildoraEncabezado extends StatelessWidget {
  final IconData icono;
  final String texto;

  const PildoraEncabezado({super.key, required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                texto,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Indicadores
// ---------------------------------------------------------------------------

/// Tarjeta de un indicador: emoji en burbuja de color, número grande
/// (animado) y etiqueta.
class TarjetaKpi extends StatelessWidget {
  final String emoji;
  final String etiqueta;
  final int? valor;

  /// Texto que reemplaza a [valor] (p. ej. el promedio "4,6").
  final String? valorTexto;
  final String? detalle;
  final Color color;

  const TarjetaKpi({
    super.key,
    required this.emoji,
    required this.etiqueta,
    this.valor,
    this.valorTexto,
    this.detalle,
    this.color = AppColors.fucsia,
  });

  @override
  Widget build(BuildContext context) {
    final estiloNumero = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: Color.lerp(color, AppColors.textoPrincipal, 0.35),
      height: 1.1,
    );
    return TarjetaBase(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(height: 12),
          if (valorTexto != null)
            Text(valorTexto!, style: estiloNumero)
          else
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (valor ?? 0).toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Text(numeroCorto(v.round()), style: estiloNumero),
            ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textoPrincipal,
            ),
          ),
          if (detalle != null) ...[
            const SizedBox(height: 2),
            Text(
              detalle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario),
            ),
          ],
        ],
      ),
    );
  }
}

/// Cuadrícula de 2 columnas de [TarjetaKpi] (sin scroll propio).
class CuadriculaKpi extends StatelessWidget {
  final List<Widget> tarjetas;

  const CuadriculaKpi({super.key, required this.tarjetas});

  @override
  Widget build(BuildContext context) {
    final filas = <Widget>[];
    for (var i = 0; i < tarjetas.length; i += 2) {
      filas.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tarjetas[i]),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < tarjetas.length ? tarjetas[i + 1] : const SizedBox(),
              ),
            ],
          ),
        ),
      );
      if (i + 2 < tarjetas.length) filas.add(const SizedBox(height: 12));
    }
    return Column(children: filas);
  }
}

// ---------------------------------------------------------------------------
// Secciones
// ---------------------------------------------------------------------------

/// Título de una sección del panel, con icono y texto de ayuda opcional.
class TituloSeccion extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final String? ayuda;
  final Widget? accion;

  const TituloSeccion({
    super.key,
    required this.titulo,
    required this.icono,
    this.ayuda,
    this.accion,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icono, size: 20, color: AppColors.fucsia),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textoPrincipal,
                ),
              ),
            ),
            if (ayuda != null)
              Tooltip(
                message: ayuda!,
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 5),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.info_outline, size: 18, color: AppColors.textoSecundario),
                ),
              ),
            ?accion,
          ],
        ),
      );
}

/// Barras horizontales por estación (cada una con su color e icono).
class BarrasEstacion extends StatelessWidget {
  final Map<EstacionColor, int> valores;

  /// Estación a resaltar (la favorita o la de la usuaria).
  final EstacionColor? resaltada;

  const BarrasEstacion({super.key, required this.valores, this.resaltada});

  @override
  Widget build(BuildContext context) {
    final total = valores.values.fold<int>(0, (a, b) => a + b);
    final maximo = valores.values.fold<int>(0, (a, b) => a > b ? a : b);
    return TarjetaBase(
      child: Column(
        children: [
          for (final e in EstacionColor.values) ...[
            _FilaEstacion(
              estacion: e,
              valor: valores[e] ?? 0,
              fraccion: maximo == 0 ? 0 : (valores[e] ?? 0) / maximo,
              porcentaje: total == 0 ? 0 : ((valores[e] ?? 0) * 100 / total).round(),
              resaltada: e == resaltada,
            ),
            if (e != EstacionColor.values.last) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _FilaEstacion extends StatelessWidget {
  final EstacionColor estacion;
  final int valor;
  final double fraccion;
  final int porcentaje;
  final bool resaltada;

  const _FilaEstacion({
    required this.estacion,
    required this.valor,
    required this.fraccion,
    required this.porcentaje,
    required this.resaltada,
  });

  @override
  Widget build(BuildContext context) {
    final color = estacion.color;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: resaltada ? 1 : 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            estacion.icono,
            size: 18,
            color: resaltada ? Colors.white : color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    estacion.etiqueta,
                    style: TextStyle(
                      fontWeight: resaltada ? FontWeight.w800 : FontWeight.w600,
                      color: AppColors.textoPrincipal,
                    ),
                  ),
                  if (resaltada) ...[
                    const SizedBox(width: 6),
                    const Text('★', style: TextStyle(color: AppColors.fucsia)),
                  ],
                  const Spacer(),
                  Text(
                    '${numeroCorto(valor)} · $porcentaje %',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textoSecundario),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Container(height: 10, color: color.withValues(alpha: 0.12)),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: fraccion),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, f, _) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: f.clamp(0.0, 1.0),
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withValues(alpha: 0.75), color],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Productos
// ---------------------------------------------------------------------------

/// Pastilla pequeña con un emoji y un número (❤️ 12).
class ChipMetrica extends StatelessWidget {
  final String emoji;
  final String texto;
  final Color color;

  const ChipMetrica({
    super.key,
    required this.emoji,
    required this.texto,
    this.color = AppColors.fucsia,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$emoji $texto',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color.lerp(color, AppColors.textoPrincipal, 0.4),
          ),
        ),
      );
}

/// Un producto con sus métricas. Con [puesto] se muestra la medalla del
/// top (🥇🥈🥉 o el número).
class FilaProductoEstadistica extends StatelessWidget {
  final EstadisticaProducto producto;
  final int? puesto;
  final String? subtitulo;
  final VoidCallback? onTap;
  final bool mostrarConversion;

  const FilaProductoEstadistica({
    super.key,
    required this.producto,
    this.puesto,
    this.subtitulo,
    this.onTap,
    this.mostrarConversion = false,
  });

  static const _medallas = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final p = producto;
    return TarjetaBase(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (puesto != null) ...[
            SizedBox(
              width: 30,
              child: Text(
                puesto! <= 3 ? _medallas[puesto! - 1] : '#$puesto',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: puesto! <= 3 ? 22 : 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textoSecundario,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Opacity(
            opacity: p.activo ? 1 : 0.45,
            child: ImagenItem(
              url: p.imagenUrl,
              colorHex: p.colorHex,
              esPrenda: false,
              ancho: 56,
              alto: 56,
              radio: 12,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nombre.isEmpty ? '—' : p.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textoPrincipal,
                  ),
                ),
                if (subtitulo != null || !p.activo)
                  Text(
                    !p.activo ? AppStrings.marcaInactiva : subtitulo!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChipMetrica(emoji: '❤️', texto: numeroCorto(p.gusta)),
                    ChipMetrica(
                      emoji: '⭐',
                      texto: promedioTexto(p.promedio),
                      color: const Color(0xFFE0A100),
                    ),
                    ChipMetrica(
                      emoji: '👁',
                      texto: numeroCorto(p.vistas),
                      color: AppColors.violeta,
                    ),
                    ChipMetrica(
                      emoji: '💄',
                      texto: numeroCorto(p.pruebasAr),
                      color: AppColors.fucsiaClaro,
                    ),
                  ],
                ),
                if (mostrarConversion && p.vistas > 0) ...[
                  const SizedBox(height: 8),
                  _BarraConversion(porcentaje: p.conversion),
                ],
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, color: AppColors.textoSecundario),
        ],
      ),
    );
  }
}

class _BarraConversion extends StatelessWidget {
  final int porcentaje;

  const _BarraConversion({required this.porcentaje});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: porcentaje / 100,
              minHeight: 6,
              backgroundColor: AppColors.fondoRosaSuave,
              valueColor: const AlwaysStoppedAnimation(AppColors.fucsia),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            AppStrings.conversion(porcentaje),
            style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario),
          ),
        ],
      );
}

/// Nota de privacidad al final de los paneles.
class NotaPrivacidad extends StatelessWidget {
  const NotaPrivacidad({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 14, color: AppColors.textoSecundario),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                AppStrings.privacidadDashboard,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
              ),
            ),
          ],
        ),
      );
}

/// Icono blanco en burbuja para el encabezado de pantallas sin logo.
class IconoEncabezado extends StatelessWidget {
  final IconData icono;

  const IconoEncabezado({super.key, required this.icono});

  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(icono, color: Colors.white, size: 30),
      );
}

/// Botón flotante con el degradado de la app.
class BotonFlotanteDegradado extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback onPressed;

  const BotonFlotanteDegradado({super.key, required this.icono, required this.texto, required this.onPressed});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.marca,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.fucsia.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: onPressed,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          highlightElevation: 0,
          icon: Icon(icono),
          label: Text(texto, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
}
