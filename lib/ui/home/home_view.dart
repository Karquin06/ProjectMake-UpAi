import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'home_view_model.dart';
import 'widgets/accesos_directos.dart';
import 'widgets/recomendaciones_destacadas.dart';
import 'widgets/resumen_colorimetria_card.dart';

/// conectado a su navegación/lógica final todavía.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(),
      child: Consumer<HomeViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            backgroundColor: AppColors.fondoClaro,
            body: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _EncabezadoHome(nombre: vm.nombreUsuaria),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: ResumenColorimetriaCard(
                        tieneColorimetria: vm.tieneColorimetria,
                        estacionColor: vm.estacionColor,
                        onTap: () {
                          // TODO: navegar a colorimetria_view.
                        },
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _TituloSeccion('Explorar'),
                    ),
                  ),
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverToBoxAdapter(child: AccesosDirectos()),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _TituloSeccion('Recomendado para ti'),
                    ),
                  ),
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
                    sliver: SliverToBoxAdapter(
                      child: RecomendacionesDestacadas(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EncabezadoHome extends StatelessWidget {
  final String nombre;

  const _EncabezadoHome({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, $nombre 👋',
                style: AppTextStyles.tituloPantalla.copyWith(fontSize: 21),
              ),
              const SizedBox(height: 2),
              Text(
                '¿Qué quieres descubrir hoy?',
                style: AppTextStyles.subtitulo,
              ),
            ],
          ),
        ),
        Material(
          color: AppColors.fondoRosaSuave,
          borderRadius: BorderRadius.circular(14),
          child: IconButton(
            onPressed: () {
              // TODO: conectar navegación a notificaciones.
            },
            icon: const Icon(
              Icons.notifications_outlined,
              color: AppColors.violeta,
            ),
          ),
        ),
      ],
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  final String texto;

  const _TituloSeccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: AppTextStyles.tituloPantalla.copyWith(fontSize: 17),
    );
  }
}
