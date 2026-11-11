import '../../models/enums.dart';
import '../../models/producto_maquillaje.dart';

/// Una fila del texto importado: el producto listo o sus errores — Ana.
class FilaImportada {
  /// Número de fila de datos (1 = la primera después del encabezado).
  final int numero;
  final ProductoMaquillaje? producto;
  final List<String> errores;

  /// Nombre escrito en la fila (para mostrarlo aunque tenga errores).
  final String nombre;

  const FilaImportada({
    required this.numero,
    required this.nombre,
    this.producto,
    this.errores = const [],
  });

  bool get valida => producto != null && errores.isEmpty;

  FilaImportada conError(String error) => FilaImportada(
        numero: numero,
        nombre: nombre,
        errores: [...errores, error],
      );
}

/// Resultado de analizar un texto pegado desde Excel o un CSV.
class ResultadoImportacion {
  final List<FilaImportada> filas;

  /// Error que impide leer todo el texto (sin encabezado, columnas que
  /// faltan...).
  final String? errorGeneral;

  const ResultadoImportacion({this.filas = const [], this.errorGeneral});

  List<FilaImportada> get validas => filas.where((f) => f.valida).toList();
  List<FilaImportada> get conErrores => filas.where((f) => !f.valida).toList();
  List<ProductoMaquillaje> get productos =>
      [for (final f in validas) f.producto!];
}

/// Convierte filas de Excel / CSV en productos de una marca — Ana.
///
/// - Separador automático: tabulación (copiar y pegar desde Excel), punto y
///   coma (CSV de Excel en español) o coma.
/// - Celdas entre comillas con separadores o saltos de línea adentro.
/// - Encabezados sin importar mayúsculas ni tildes, con sinónimos
///   ("Categoría", "tipo", "Foto", "Link"...).
/// - Varias estaciones o subtonos en una celda: `primavera|otoño`,
///   `verano / invierno`, `todas`.
class ImportadorProductos {
  ImportadorProductos._();

  /// Máximo de filas por importación.
  static const maximoFilas = 300;

  static const obligatorias = ['nombre', 'categoria', 'color', 'estaciones', 'subtonos'];

  /// Columnas en el orden de la plantilla.
  static const columnas = [
    'nombre',
    'categoria',
    'color',
    'estaciones',
    'subtonos',
    'precio',
    'imagen',
    'enlace',
    'descripcion',
    'tono',
    'acabado',
  ];

  /// Plantilla con dos filas de ejemplo (separada por punto y coma, como el
  /// CSV que guarda Excel en español).
  static const plantilla =
      'nombre;categoria;color;estaciones;subtonos;precio;imagen;enlace;descripcion;tono;acabado\n'
      'Labial Rubí Intenso;labial;#9B111E;invierno|verano;frio|neutro;45900;https://ejemplo.com/rubi.jpg;;Rojo frío de larga duración;Rubí;mate\n'
      'Rubor Durazno;rubor;#F4A582;primavera|otono;calido;38500;;;Rubor en polvo luminoso;Durazno;satinado\n';

  static const Map<String, String> _alias = {
    'nombre': 'nombre',
    'producto': 'nombre',
    'nombredelproducto': 'nombre',
    'categoria': 'categoria',
    'tipo': 'categoria',
    'color': 'color',
    'colorhex': 'color',
    'hex': 'color',
    'estaciones': 'estaciones',
    'estacion': 'estaciones',
    'subtonos': 'subtonos',
    'subtono': 'subtonos',
    'precio': 'precio',
    'valor': 'precio',
    'imagen': 'imagen',
    'imagenurl': 'imagen',
    'foto': 'imagen',
    'urlimagen': 'imagen',
    'enlace': 'enlace',
    'link': 'enlace',
    'url': 'enlace',
    'enlacedecompra': 'enlace',
    'descripcion': 'descripcion',
    'tono': 'tono',
    'acabado': 'acabado',
  };

  static const Map<String, String> _categorias = {
    'labial': 'labial',
    'labiales': 'labial',
    'lipstick': 'labial',
    'gloss': 'labial',
    'rubor': 'rubor',
    'rubores': 'rubor',
    'blush': 'rubor',
    'sombra': 'sombra',
    'sombras': 'sombra',
    'sombradeojos': 'sombra',
    'sombrasdeojos': 'sombra',
    'eyeshadow': 'sombra',
    'base': 'base',
    'bases': 'base',
    'basedemaquillaje': 'base',
    'foundation': 'base',
  };

  static final _hex = RegExp(r'^#?([0-9a-fA-F]{6})$');
  static final _miles = RegExp(r'^\d{1,3}([.,]\d{3})+$');

  /// Analiza [texto] y arma productos de la marca [marcaId].
  static ResultadoImportacion analizar(
    String texto, {
    required String marcaId,
    required String marcaNombre,
  }) {
    final limpio = texto
        .replaceAll('\uFEFF', '') // BOM de los CSV que guarda Excel
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    if (limpio.isEmpty) {
      return const ResultadoImportacion(errorGeneral: 'Pega primero tu lista de productos.');
    }
    final primeraLinea = limpio.split('\n').first;
    final separador = _separador(primeraLinea);
    final filas = _partir(limpio, separador)
        .where((f) => f.any((c) => c.trim().isNotEmpty))
        .toList();
    if (filas.length < 2) {
      return const ResultadoImportacion(
        errorGeneral: 'Faltan filas: la primera es el encabezado y debajo van los productos.',
      );
    }

    // Encabezado → índice de cada columna conocida.
    final indices = <String, int>{};
    for (var i = 0; i < filas.first.length; i++) {
      final columna = _alias[_clave(filas.first[i])];
      if (columna != null) indices.putIfAbsent(columna, () => i);
    }
    final faltan = obligatorias.where((c) => !indices.containsKey(c)).toList();
    if (faltan.isNotEmpty) {
      return ResultadoImportacion(
        errorGeneral: 'Al encabezado le faltan las columnas: ${faltan.join(', ')}.',
      );
    }

    final datos = filas.skip(1).toList();
    if (datos.length > maximoFilas) {
      return const ResultadoImportacion(
        errorGeneral: 'Son demasiadas filas: máximo $maximoFilas por importación.',
      );
    }

    final nombresVistos = <String>{};
    final resultado = <FilaImportada>[];
    for (var n = 0; n < datos.length; n++) {
      final celdas = datos[n];
      String celda(String columna) {
        final i = indices[columna];
        return i == null || i >= celdas.length ? '' : celdas[i].trim();
      }

      final fila = _fila(
        numero: n + 1,
        celda: celda,
        marcaId: marcaId,
        marcaNombre: marcaNombre,
      );
      final clave = fila.nombre.toLowerCase();
      if (fila.valida && !nombresVistos.add(clave)) {
        resultado.add(fila.conError('Está repetido en la lista.'));
      } else {
        resultado.add(fila);
      }
    }
    return ResultadoImportacion(filas: resultado);
  }

  static FilaImportada _fila({
    required int numero,
    required String Function(String columna) celda,
    required String marcaId,
    required String marcaNombre,
  }) {
    final errores = <String>[];
    final nombre = celda('nombre');
    if (nombre.isEmpty) errores.add('Falta el nombre.');
    if (nombre.length > 120) errores.add('El nombre es muy largo (máx. 120).');

    final categoria = _categorias[_clave(celda('categoria'))];
    if (categoria == null) {
      errores.add('Categoría "${celda('categoria')}" no válida: usa labial, rubor, sombra o base.');
    }

    final colorMatch = _hex.firstMatch(celda('color'));
    if (colorMatch == null) {
      errores.add('Color "${celda('color')}" no válido: usa un HEX como #C2185B.');
    }

    final estaciones = _estaciones(celda('estaciones'));
    if (estaciones.isEmpty) {
      errores.add('Pon al menos una estación: primavera, verano, otoño o invierno.');
    }
    final subtonos = _subtonos(celda('subtonos'));
    if (subtonos.isEmpty) {
      errores.add('Pon al menos un subtono: cálido, frío o neutro.');
    }

    final precio = precioDesde(celda('precio'));
    if (precio == null) errores.add('Precio "${celda('precio')}" no válido.');

    final imagen = celda('imagen');
    if (imagen.isNotEmpty && !_esUrl(imagen)) {
      errores.add('La imagen debe ser un enlace que empiece por http.');
    }
    final enlace = celda('enlace');
    if (enlace.isNotEmpty && !_esUrl(enlace)) {
      errores.add('El enlace debe empezar por http.');
    }

    if (errores.isNotEmpty) {
      return FilaImportada(numero: numero, nombre: nombre, errores: errores);
    }
    final tono = celda('tono');
    return FilaImportada(
      numero: numero,
      nombre: nombre,
      producto: ProductoMaquillaje(
        id: '',
        nombre: nombre,
        descripcion: celda('descripcion'),
        marca: marcaNombre,
        marcaId: marcaId,
        categoria: categoria!,
        tono: tono.isEmpty ? nombre : tono,
        colorHex: '#${colorMatch!.group(1)!.toUpperCase()}',
        subtonoCompatible: subtonos,
        acabado: celda('acabado').toLowerCase(),
        estacionesCompatibles: estaciones,
        precio: precio!,
        imagenUrl: imagen,
        enlace: enlace.isEmpty ? null : enlace,
      ),
    );
  }

  /// Precio escrito como 45900, 45.900, $ 45.900, 45,900 o 45900,50.
  /// `null` si no es un número; vacío = 0.
  static double? precioDesde(String texto) {
    var t = texto.replaceAll(RegExp(r'[\s$]|COP', caseSensitive: false), '');
    if (t.isEmpty) return 0;
    if (_miles.hasMatch(t)) return double.parse(t.replaceAll(RegExp('[.,]'), ''));
    if (t.contains('.') && t.contains(',')) {
      // 62.500,50 o 62,500.50: el último separador es el decimal.
      final decimal = t.lastIndexOf(',') > t.lastIndexOf('.') ? ',' : '.';
      t = t.replaceAll(decimal == ',' ? '.' : ',', '').replaceAll(decimal, '.');
    }
    final v = double.tryParse(t.replaceAll(',', '.'));
    return v == null || v < 0 ? null : v;
  }

  static List<EstacionColor> _estaciones(String texto) {
    final partes = _partes(texto);
    if (partes.contains('todas') || partes.contains('todos')) {
      return EstacionColor.values.toList();
    }
    final set = <EstacionColor>{};
    for (final p in partes) {
      for (final e in EstacionColor.values) {
        if (p == e.name) set.add(e);
      }
    }
    return EstacionColor.values.where(set.contains).toList();
  }

  static List<Subtono> _subtonos(String texto) {
    final partes = _partes(texto);
    if (partes.contains('todos') || partes.contains('todas')) {
      return Subtono.values.toList();
    }
    final set = <Subtono>{};
    for (final p in partes) {
      for (final s in Subtono.values) {
        if (p == s.name) set.add(s);
      }
    }
    return Subtono.values.where(set.contains).toList();
  }

  /// "Primavera | Otoño / verano y invierno" → [primavera, otono, verano, invierno].
  static List<String> _partes(String texto) => _sinTildes(texto.toLowerCase())
      .split(RegExp(r'[|/,;+]|\s+y\s+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  static bool _esUrl(String t) =>
      t.startsWith('http://') || t.startsWith('https://');

  static String _separador(String encabezado) {
    if (encabezado.contains('\t')) return '\t';
    final puntoYComa = ';'.allMatches(encabezado).length;
    final comas = ','.allMatches(encabezado).length;
    return puntoYComa >= comas && puntoYComa > 0 ? ';' : ',';
  }

  /// Divide en filas y celdas respetando comillas ("a; b" o "línea\notra").
  static List<List<String>> _partir(String texto, String sep) {
    final filas = <List<String>>[];
    var fila = <String>[];
    final celda = StringBuffer();
    var enComillas = false;
    for (var i = 0; i < texto.length; i++) {
      final c = texto[i];
      if (enComillas) {
        if (c == '"') {
          if (i + 1 < texto.length && texto[i + 1] == '"') {
            celda.write('"');
            i++;
          } else {
            enComillas = false;
          }
        } else {
          celda.write(c);
        }
      } else if (c == '"' && celda.isEmpty) {
        enComillas = true;
      } else if (c == sep) {
        fila.add(celda.toString());
        celda.clear();
      } else if (c == '\n') {
        fila.add(celda.toString());
        celda.clear();
        filas.add(fila);
        fila = <String>[];
      } else {
        celda.write(c);
      }
    }
    fila.add(celda.toString());
    filas.add(fila);
    return filas;
  }

  static String _clave(String texto) =>
      _sinTildes(texto.toLowerCase()).replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String _sinTildes(String t) => t
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
}
