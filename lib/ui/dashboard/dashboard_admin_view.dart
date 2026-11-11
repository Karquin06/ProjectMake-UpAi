import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/indicador_carga.dart';
import '../../core/widgets/mensaje_error.dart';
import '../../core/widgets/tarjeta_base.dart';
import '../../data/services/marcas_service.dart';
import '../../models/enums.dart';
import '../../models/estadisticas_marca.dart';
import '../marcas/widgets/elementos_panel.dart';
import 'dashboard_admin_view_model.dart';

/// Dashboard de la admin general — Ana: usuarias, análisis, catálogo,
/// estaciones, top productos y ranking de marcas.
class DashboardAdminView extends StatelessWidget {
  const DashboardAdminView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) {
        final vm = DashboardAdminViewModel(c.read<MarcasService>());
        Future.microtask(vm.cargar);
        return vm;
      },
      child: const _Contenido(),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardAdminViewModel>();
    final r = vm.resumen;
    if (r == null) {
      return Scaffold(
        backgroundColor: AppColors.fondoClaro,
        appBar: AppBar(
          title: const Text(AppStrings.dashboardTitulo),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: vm.error != null
            ? MensajeError(mensaje: vm.error!, onReintentar: vm.cargar)
            : const IndicadorCarga(mensaje: AppStrings.cargando),
      );
    }

    // Estación con más usuarias (se resalta en las barras).
    EstacionColor? masUsuarias;
    var maximo = 0;
    for (final e in EstacionColor.values) {
      final n = r.usuariasPorEstacion[e] ?? 0;
      if (n > maximo) {
        maximo = n;
        masUsuarias = e;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      body: RefreshIndicator(
        color: AppColors.fucsia,
        onRefresh: vm.cargar,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: EncabezadoPanel(
                titulo: AppStrings.dashboardTitulo,
                subtitulo: AppStrings.dashboardSubtitulo,
                avatar: const IconoEncabezado(icono: Icons.insights_rounded),
                acciones: [
                  IconButton(
                    tooltip: AppStrings.marcasTitulo,
                    icon: const Icon(Icons.storefront_outlined, color: Colors.white),
                    onPressed: () => context.irA(AppRoutes.marcasAdmin),
                  ),
                ],
                pie: _ProgresoAnalisis(porcentaje: r.porcentajeConAnalisis),
              ),
            ),
            if (vm.cargando)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 2, color: AppColors.fucsia),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              sliver: SliverList.list(
                children: [
                  CuadriculaKpi(
                    tarjetas: [
                      TarjetaKpi(
                        emoji: '👩🏻',
                        etiqueta: AppStrings.kpiUsuarias,
                        valor: r.usuarias,
                        color: AppColors.fucsia,
                      ),
                      TarjetaKpi(
                        emoji: '🎨',
                        etiqueta: AppStrings.kpiConAnalisis,
                        valor: r.conAnalisis,
                        detalle: AppStrings.porcentajeConAnalisis(r.porcentajeConAnalisis),
                        color: AppColors.violeta,
                      ),
                      TarjetaKpi(
                        emoji: '💄',
                        etiqueta: AppStrings.kpiProductos,
                        valor: r.productos,
                        color: AppColors.fucsiaClaro,
                      ),
                      TarjetaKpi(
                        emoji: '👗',
                        etiqueta: AppStrings.kpiPrendas,
                        valor: r.prendas,
                        color: AppColors.estacionVerano,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _TarjetaMarcas(
                    total: r.marcas,
                    onTap: () => context.irA(AppRoutes.marcasAdmin),
                  ),
                  const SizedBox(height: 28),
                  const TituloSeccion(
                    titulo: AppStrings.usuariasPorEstacionTitulo,
                    icono: Icons.palette_outlined,
                  ),
                  BarrasEstacion(valores: r.usuariasPorEstacion, resaltada: masUsuarias),
                  const SizedBox(height: 28),
                  const TituloSeccion(
                    titulo: AppStrings.topProductosTitulo,
                    icono: Icons.emoji_events_outlined,
                    ayuda: AppStrings.comoSeCuentaGusta,
                  ),
                  if (r.topProductos.isEmpty)
                    const _SinDatos()
                  else
                    for (var i = 0; i < r.topProductos.length; i++) ...[
                      FilaProductoEstadistica(
                        producto: r.topProductos[i],
                        puesto: i + 1,
                        onTap: () => context.irA(
                          AppRoutes.formularioProducto,
                          argumentos: r.topProductos[i].id,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  const SizedBox(height: 18),
                  TituloSeccion(
                    titulo: AppStrings.rankingMarcasTitulo,
                    icono: Icons.leaderboard_outlined,
                    accion: TextButton(
                      onPressed: () => context.irA(AppRoutes.marcasAdmin),
                      child: const Text(AppStrings.marcasTitulo),
                    ),
                  ),
                  if (r.ranking.isEmpty)
                    const _SinDatos()
                  else
                    _RankingMarcas(ranking: r.ranking),
                  const NotaPrivacidad(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra blanca en el encabezado: qué porcentaje ya hizo su análisis.
class _ProgresoAnalisis extends StatelessWidget {
  final int porcentaje;

  const _ProgresoAnalisis({required this.porcentaje});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PildoraEncabezado(
            icono: Icons.auto_awesome,
            texto: AppStrings.porcentajeConAnalisis(porcentaje),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: porcentaje / 100),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
        ],
      );
}

class _TarjetaMarcas extends StatelessWidget {
  final int total;
  final VoidCallback onTap;

  const _TarjetaMarcas({required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) => TarjetaBase(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: degradadoMarca(AppColors.fucsia),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.storefront_rounded, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$total ${AppStrings.kpiMarcas.toLowerCase()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textoPrincipal,
                    ),
                  ),
                  const Text(
                    AppStrings.marcasSubtitulo,
                    style: TextStyle(fontSize: 12.5, color: AppColors.textoSecundario),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textoSecundario),
          ],
        ),
      );
}

/// Ranking de marcas por "les gustó", con barra relativa a la primera.
class _RankingMarcas extends StatelessWidget {
  final List<MarcaRanking> ranking;

  const _RankingMarcas({required this.ranking});

  @override
  Widget build(BuildContext context) {
    final maximo = ranking.fold<int>(0, (a, m) => m.gusta > a ? m.gusta : a);
    return TarjetaBase(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < ranking.length; i++) ...[
            _FilaRanking(
              marca: ranking[i],
              puesto: i + 1,
              fraccion: maximo == 0 ? 0 : ranking[i].gusta / maximo,
            ),
            if (i < ranking.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.borde),
          ],
        ],
      ),
    );
  }
}

class _FilaRanking extends StatelessWidget {
  final MarcaRanking marca;
  final int puesto;
  final double fraccion;

  const _FilaRanking({required this.marca, required this.puesto, required this.fraccion});

  @override
  Widget build(BuildContext context) {
    final color = colorDeMarca(marca.colorHex);
    return InkWell(
      onTap: () => context.irA(AppRoutes.miMarca, argumentos: marca.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '$puesto',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: puesto <= 3 ? AppColors.fucsia : AppColors.textoSecundario,
                ),
              ),
            ),
            const SizedBox(width: 6),
            AvatarMarca(
              nombre: marca.nombre,
              logoUrl: marca.logoUrl,
              colorHex: marca.colorHex,
              tamano: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          marca.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textoPrincipal,
                          ),
                        ),
                      ),
                      if (!marca.activa) ...[
                        const SizedBox(width: 6),
                        const Text(
                          AppStrings.marcaInactiva,
                          style: TextStyle(fontSize: 11, color: AppColors.textoSecundario),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: fraccion,
                      minHeight: 6,
                      backgroundColor: color.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '❤️ ${numeroCorto(marca.gusta)}   👁 ${numeroCorto(marca.vistas)}   💄 ${numeroCorto(marca.pruebasAr)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textoSecundario),
          ],
        ),
      ),
    );
  }
}

class _SinDatos extends StatelessWidget {
  const _SinDatos();

  @override
  Widget build(BuildContext context) => const TarjetaBase(
        child: Row(
          children: [
            Text('✨', style: TextStyle(fontSize: 24)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                AppStrings.sinDatosAun,
                style: TextStyle(color: AppColors.textoSecundario),
              ),
            ),
          ],
        ),
      );
}
