import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/extensions/enum_labels.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/color_utils.dart';
import '../../core/utils/importador_productos.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/widgets/boton_primario.dart';
import '../../core/widgets/tarjeta_base.dart';
import '../../data/repositories/catalogo_repository.dart';
import '../admin/formulario_producto_view_model.dart';
import 'importar_productos_view_model.dart';
import 'widgets/elementos_panel.dart';

/// Importar varios productos de una marca de una sola vez — Ana.
///
/// Argumento: [ArgumentosProductoMarca] (sin id). La marca copia sus filas
/// de Excel (o abre el CSV), las pega, revisa y sube todo. Vuelve con
/// `true` si importó.
class ImportarProductosView extends StatefulWidget {
  const ImportarProductosView({super.key});

  @override
  State<ImportarProductosView> createState() => _ImportarProductosViewState();
}

class _ImportarProductosViewState extends State<ImportarProductosView> {
  final _texto = TextEditingController();
  ImportarProductosViewModel? _vm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_vm != null) return;
    final marca = context.argumentos<ArgumentosProductoMarca>() ??
        const ArgumentosProductoMarca(marcaId: '', marcaNombre: '');
    _vm = ImportarProductosViewModel(context.read<CatalogoRepository>(), marca);
  }

  @override
  void dispose() {
    _texto.dispose();
    _vm?.dispose();
    super.dispose();
  }

  Future<void> _copiarPlantilla() async {
    await Clipboard.setData(const ClipboardData(text: ImportadorProductos.plantilla));
    if (mounted) SnackbarHelper.info(context, AppStrings.plantillaCopiada);
  }

  void _usarEjemplo() {
    _texto.text = ImportadorProductos.plantilla;
    _vm!.cambiarTexto(_texto.text);
  }

  Future<void> _pegar() async {
    final datos = await Clipboard.getData(Clipboard.kTextPlain);
    final t = datos?.text ?? '';
    if (t.trim().isEmpty) {
      if (mounted) SnackbarHelper.info(context, AppStrings.portapapelesVacio);
      return;
    }
    _texto.text = t;
    _vm!.cambiarTexto(t);
    await _vm!.revisar();
  }

  Future<void> _importar() async {
    final vm = _vm!;
    final total = vm.totalAImportar;
    final ok = await vm.importar();
    if (!mounted) return;
    if (ok) {
      SnackbarHelper.exito(context, AppStrings.productosImportados(total));
      context.volver(true);
    } else {
      SnackbarHelper.error(context, vm.error ?? AppStrings.errorInesperado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final r = vm.resultado;
        return Scaffold(
          backgroundColor: AppColors.fondoClaro,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: EncabezadoPanel(
                  titulo: AppStrings.importarTitulo,
                  subtitulo: vm.marca.marcaNombre,
                  avatar: const IconoEncabezado(icono: Icons.playlist_add_rounded),
                  pie: const PildoraEncabezado(
                    icono: Icons.bolt_rounded,
                    texto: AppStrings.importarSubtitulo,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                sliver: SliverList.list(
                  children: [
                    // 1. Plantilla
                    const TituloSeccion(
                      titulo: AppStrings.importarPaso1,
                      icono: Icons.table_chart_outlined,
                    ),
                    TarjetaBase(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            AppStrings.importarExplicacion,
                            style: TextStyle(color: AppColors.textoSecundario, height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final c in ImportadorProductos.columnas)
                                _ChipColumna(
                                  texto: c,
                                  obligatoria: ImportadorProductos.obligatorias.contains(c),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            AppStrings.importarAyudaValores,
                            style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: vm.ocupado ? null : _copiarPlantilla,
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: const Text(AppStrings.copiarPlantilla),
                              ),
                              TextButton.icon(
                                onPressed: vm.ocupado ? null : _usarEjemplo,
                                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                                label: const Text(AppStrings.usarEjemplo),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 2. Pegar
                    TituloSeccion(
                      titulo: AppStrings.importarPaso2,
                      icono: Icons.content_paste_rounded,
                      accion: TextButton.icon(
                        onPressed: vm.ocupado ? null : _pegar,
                        icon: const Icon(Icons.content_paste_go_rounded, size: 18),
                        label: const Text(AppStrings.pegar),
                      ),
                    ),
                    TarjetaBase(
                      padding: const EdgeInsets.all(4),
                      child: TextField(
                        controller: _texto,
                        onChanged: vm.cambiarTexto,
                        enabled: !vm.importando,
                        minLines: 6,
                        maxLines: 12,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
                        decoration: const InputDecoration(
                          hintText: AppStrings.importarHint,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    BotonPrimario(
                      texto: AppStrings.revisar,
                      icono: Icons.fact_check_outlined,
                      cargando: vm.revisando,
                      onPressed: vm.ocupado || vm.texto.trim().isEmpty ? null : vm.revisar,
                    ),
                    if (vm.error != null) ...[
                      const SizedBox(height: 12),
                      _Aviso(texto: vm.error!, esError: true),
                    ],

                    // 3. Resultado
                    if (r != null) ...[
                      const SizedBox(height: 28),
                      if (r.errorGeneral != null)
                        _Aviso(texto: r.errorGeneral!, esError: true)
                      else ...[
                        const TituloSeccion(
                          titulo: AppStrings.importarPaso3,
                          icono: Icons.checklist_rounded,
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChipMetrica(
                              emoji: '✅',
                              texto: AppStrings.listos(r.validas.length),
                              color: AppColors.exito,
                            ),
                            if (r.conErrores.isNotEmpty)
                              ChipMetrica(
                                emoji: '⚠️',
                                texto: AppStrings.conErrores(r.conErrores.length),
                                color: AppColors.error,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final f in r.conErrores) ...[
                          _FilaError(fila: f),
                          const SizedBox(height: 8),
                        ],
                        for (final f in r.validas) ...[
                          _FilaLista(fila: f),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 12),
                        if (vm.importando) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: vm.progreso,
                              minHeight: 8,
                              backgroundColor: AppColors.fondoRosaSuave,
                              valueColor: const AlwaysStoppedAnimation(AppColors.fucsia),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (r.validas.isNotEmpty)
                          BotonPrimario(
                            texto: AppStrings.importarN(r.validas.length),
                            icono: Icons.cloud_upload_outlined,
                            cargando: vm.importando,
                            onPressed: vm.ocupado ? null : _importar,
                          ),
                        if (r.conErrores.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            AppStrings.importarSoloValidos,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                          ),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChipColumna extends StatelessWidget {
  final String texto;
  final bool obligatoria;

  const _ChipColumna({required this.texto, required this.obligatoria});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: obligatoria ? AppColors.fucsia.withValues(alpha: 0.12) : AppColors.fondoRosaSuave,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: obligatoria ? AppColors.fucsia.withValues(alpha: 0.4) : AppColors.borde,
          ),
        ),
        child: Text(
          obligatoria ? '$texto *' : texto,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: obligatoria ? FontWeight.w700 : FontWeight.w500,
            color: obligatoria ? AppColors.fucsia : AppColors.textoSecundario,
          ),
        ),
      );
}

class _Aviso extends StatelessWidget {
  final String texto;
  final bool esError;

  const _Aviso({required this.texto, this.esError = false});

  @override
  Widget build(BuildContext context) {
    final color = esError ? AppColors.error : AppColors.violeta;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(esError ? Icons.error_outline : Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}

/// Producto listo para importar.
class _FilaLista extends StatelessWidget {
  final FilaImportada fila;

  const _FilaLista({required this.fila});

  @override
  Widget build(BuildContext context) {
    final p = fila.producto!;
    final color = ColorUtils.desdeHex(p.colorHex, porDefecto: AppColors.fucsia);
    return TarjetaBase(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textoPrincipal),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    EtiquetasTexto.categoria(p.categoria),
                    if (p.precio > 0) '\$${p.precio.toStringAsFixed(0)}',
                    if (p.imagenUrl.isEmpty) AppStrings.sinFoto,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final e in p.estacionesCompatibles)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: e.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          e.etiqueta,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color.lerp(e.color, AppColors.textoPrincipal, 0.35),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: AppColors.exito),
        ],
      ),
    );
  }
}

/// Fila con errores (no se importa).
class _FilaError extends StatelessWidget {
  final FilaImportada fila;

  const _FilaError({required this.fila});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppStrings.fila(fila.numero)}${fila.nombre.isEmpty ? '' : ' · ${fila.nombre}'}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.error),
            ),
            const SizedBox(height: 4),
            for (final e in fila.errores)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• $e', style: const TextStyle(fontSize: 12.5, color: AppColors.textoPrincipal)),
              ),
          ],
        ),
      );
}
