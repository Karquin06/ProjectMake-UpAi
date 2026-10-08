class AppStrings {
  AppStrings._();

  static const String nombreApp = 'MAKE UP AI';
  static const String eslogan = 'Tu imagen, nuestra inteligencia';

  // Onboarding
  static const String onboardingTitulo1 =
      'Tu belleza, potenciada por la inteligencia artificial';
  static const String onboardingDescripcion1 =
      'Descubrimos tu colorimetría personal y te ofrecemos '
      'recomendaciones únicas de maquillaje, ropa y accesorios.';

  static const String onboardingTitulo2 = 'Simula antes de comprar';
  static const String onboardingDescripcion2 =
      'Prueba tu maquillaje con realidad aumentada y evita compras '
      'que no te favorecen.';

  static const String onboardingTitulo3 = 'Un asistente que te conoce';
  static const String onboardingDescripcion3 =
      'Resuelve tus dudas de estilo con un asistente de IA que entiende '
      'tu propio perfil de colorimetría.';

  static const String botonComenzar = 'Comenzar';
  static const String yaTienesCuenta = '¿Ya tienes cuenta? ';
  static const String iniciaSesion = 'Inicia sesión';

  // Login
  static const String bienvenida = '¡Bienvenida!';
  static const String iniciaSesionParaContinuar =
      'Inicia sesión para continuar';
  static const String continuarConGoogle = 'Continuar con Google';
  static const String continuarConApple = 'Continuar con Apple';
  static const String correoElectronico = 'CORREO ELECTRÓNICO';
  static const String contrasena = 'CONTRASEÑA';
  static const String olvidasteContrasena = '¿Olvidaste tu contraseña?';
  static const String botonIniciarSesion = 'Iniciar sesión';
  static const String noTienesCuenta = '¿No tienes una cuenta? ';
  static const String registrate = 'Regístrate';

  // Registro
  static const String crearCuenta = 'Crear cuenta';
  static const String nombreCompleto = 'NOMBRE COMPLETO';
  static const String botonCrearCuentaGratis = 'Crear cuenta gratis';
  static const String confirmarContrasena = 'CONFIRMAR CONTRASEÑA';
  static const String consentimientoPrefijo = 'He leído y acepto el ';
  static const String consentimientoEnlace = 'Aviso de privacidad';
  static const String errorConsentimientoRequerido =
      'Debes aceptar el aviso de privacidad para crear tu cuenta.';
  static const String errorConsentimientoGoogle =
      'Para usar Make Up AI debes aceptar el aviso de privacidad.';
  static const String recordarme = 'Recordarme';
  static const String appleProximamente =
      'El inicio de sesión con Apple estará disponible próximamente.';

  // Aviso de privacidad
  // BORRADOR ACADÉMICO: revisar en equipo antes de publicar. Si el texto
  // cambia, sube AppConstants.versionConsentimiento.
  static const String avisoPrivacidadTitulo = 'Aviso de privacidad';
  static String avisoPrivacidadVersion(String version) =>
      'Versión $version · Ley 1581 de 2012 (Colombia)';
  static const String botonAcepto = 'Acepto';
  static const List<(String, String)> avisoPrivacidadSecciones = [
    (
      'Responsable',
      'Make Up AI es un proyecto académico de la asignatura Programación '
          'Móvil de la Universidad Popular del Cesar. Su equipo de desarrollo '
          'es responsable del tratamiento de tus datos personales.',
    ),
    (
      'Datos que recopilamos',
      'Nombre, correo electrónico y foto de perfil (opcional); las fotos que '
          'tomes para el análisis de colorimetría y de prendas; los '
          'resultados de tu colorimetría, tus preferencias, tus '
          'conversaciones con el asistente y el identificador de '
          'notificaciones de tu dispositivo.',
    ),
    (
      'Para qué los usamos',
      'Para crear y proteger tu cuenta, analizar tu colorimetría, generarte '
          'recomendaciones personalizadas de maquillaje y ropa, responder tus '
          'preguntas en el asistente y enviarte notificaciones si lo '
          'autorizas. No vendemos tus datos ni los usamos con fines '
          'publicitarios.',
    ),
    (
      'Datos sensibles',
      'Las fotos de tu rostro pueden considerarse datos sensibles. Solo se '
          'usan para el análisis que tú solicitas y no estás obligada a '
          'proporcionarlas.',
    ),
    (
      'Dónde se almacenan',
      'Tus datos se guardan en los servicios de Google Firebase '
          '(Authentication, Firestore, Storage y Cloud Functions). Algunas '
          'funciones de inteligencia artificial pueden procesar tus fotos o '
          'mensajes con servicios de terceros únicamente para generar la '
          'respuesta que pediste.',
    ),
    (
      'Tus derechos',
      'Puedes conocer, actualizar, rectificar y suprimir tus datos, y '
          'revocar esta autorización en cualquier momento. Edita tu '
          'información desde Perfil o elimina tu cuenta desde Perfil > '
          'Eliminar cuenta; al hacerlo se borran tus datos.',
    ),
    (
      'Cambios a este aviso',
      'Si este aviso cambia, te pediremos aceptarlo de nuevo antes de '
          'continuar usando la app.',
    ),
  ];

  // Verificar correo
  static const String verificarCorreoTitulo = 'Verifica tu correo';
  static String verificarCorreoDescripcion(String correo) =>
      'Enviamos un enlace de verificación a $correo. Ábrelo y luego toca '
      '"Ya verifiqué". Revisa también la carpeta de spam.';
  static const String reenviarCorreo = 'Reenviar correo';
  static String reenviarEn(int segundos) => 'Reenviar en $segundos s';
  static const String yaVerifique = 'Ya verifiqué';
  static const String correoReenviado =
      'Te enviamos un nuevo correo de verificación.';
  static const String correoAunNoVerificado =
      'Aún no has verificado tu correo. Abre el enlace que te enviamos.';
  static const String usarOtraCuenta = 'Usar otra cuenta';
  static String errorEsperaReenvio(int segundos) =>
      'Espera $segundos segundos antes de pedir otro correo.';

  // Recuperar contraseña
  static const String recuperarTitulo = 'Recuperar contraseña';
  static const String recuperarDescripcion =
      'Ingresa tu correo y te enviaremos un enlace para crear una nueva '
      'contraseña.';
  static const String botonEnviarEnlace = 'Enviar enlace';
  static const String recuperarEnviadoTitulo = 'Revisa tu correo';
  static String recuperarEnviadoDescripcion(String correo) =>
      'Si existe una cuenta con $correo, recibirás un enlace para '
      'restablecer tu contraseña. Revisa también la carpeta de spam.';
  static const String volverAlLogin = 'Volver a iniciar sesión';

  // Home
  static const String inicio = 'Inicio';
  static const String colorimetriaTab = 'Colorimetría';
  static const String asistenteTab = 'Asistente';
  static const String perfilTab = 'Perfil';
  static String saludo(String nombre) =>
      nombre.isEmpty ? '¡Hola! 👋' : 'Hola, $nombre 👋';
  static const String saludoSubtitulo = '¿Qué quieres descubrir hoy?';
  static const String seccionExplorar = 'Explorar';
  static const String seccionRecomendado = 'Recomendado para ti';
  static const String verTodo = 'Ver todo';
  static const String sinNotificaciones = 'No tienes notificaciones nuevas.';
  static const String cerrarSesion = 'Cerrar sesión';

  // Perfil
  static const String miPerfil = 'Mi perfil';
  static const String editarPerfil = 'Editar perfil';
  static const String editarPerfilSubtitulo = 'Cambia tu nombre y tu foto';
  static const String avisoPrivacidadSubtitulo = 'Cómo cuidamos tus datos';
  static const String cerrarSesionSubtitulo = 'Sal de tu cuenta en este equipo';
  static const String cerrarSesionTitulo = '¿Cerrar sesión?';
  static const String cerrarSesionMensaje =
      'Tendrás que volver a iniciar sesión para usar Make Up AI.';
  static const String eliminarCuenta = 'Eliminar cuenta';
  static const String eliminarCuentaSubtitulo =
      'Borra tu cuenta y todos tus datos';
  static const String eliminarCuentaTitulo = '¿Eliminar tu cuenta?';
  static const String eliminarCuentaMensaje =
      'Se borrarán tu perfil, tu colorimetría, tus recomendaciones y tus '
      'fotos. Esta acción no se puede deshacer.';
  static const String confirmarIdentidadTitulo = 'Confirma que eres tú';
  static const String confirmarIdentidadMensaje =
      'Por seguridad, escribe tu contraseña para eliminar la cuenta.';
  static const String cuentaEliminada =
      'Tu cuenta fue eliminada. ¡Gracias por usar Make Up AI!';
  static const String errorContrasenaIncorrecta =
      'La contraseña no es correcta.';
  static const String seccionCuenta = 'CUENTA';
  static const String seccionPrivacidad = 'PRIVACIDAD Y SESIÓN';

  // Editar perfil
  static const String guardarCambios = 'Guardar cambios';
  static const String cambiarFoto = 'Cambiar foto';
  static const String tomarFoto = 'Tomar foto';
  static const String elegirDeGaleria = 'Elegir de la galería';
  static const String perfilActualizado = 'Tu perfil se actualizó.';
  static const String fotoPendienteStorage =
      'Tu nombre se guardó. La foto se subirá cuando el servicio de '
      'almacenamiento esté listo.';
  static const String errorImagenMuyGrande =
      'La imagen pesa demasiado (máximo 15 MB). Elige otra.';

  // Notificaciones
  static const String notificacionNueva = 'Nueva notificación';

  // Tarjeta de colorimetría
  static const String tuEstacionDeColor = 'Tu estación de color';
  static String estacionConSubtono(String estacion, String subtono) =>
      '$estacion · subtono $subtono';
  static const String verMiPaleta = 'Toca para ver tu paleta';
  static const String sinAnalisisTitulo = 'Aún no tienes un análisis';
  static const String sinAnalisisAccion = 'Analiza tu colorimetría ahora';

  // Recomendaciones destacadas
  static const String sinRecomendacionesTitulo =
      'Aún no tienes recomendaciones';
  static const String sinRecomendacionesMensaje =
      'Haz tu análisis de colorimetría para recibir sugerencias '
      'de maquillaje y ropa hechas para ti.';
  static const String hacerMiAnalisis = 'Hacer mi análisis';

  // Accesos directos
  static const String accesoColorimetria = 'Colorimetría';
  static const String accesoPaleta = 'Mi paleta';
  static const String accesoOutfits = 'Outfits';
  static const String accesoMaquillaje = 'Maquillaje';
  static const String accesoAsistente = 'Asistente IA';
  static const String accesoSimulador = 'Simulador AR';
  static const String accesoArmario = 'Armario';
  static String accesoProximamente(String acceso) =>
      '$acceso estará disponible próximamente.';

  // ---------------------------------------------------------------------
  // Acciones genéricas
  // ---------------------------------------------------------------------
  static const String aceptar = 'Aceptar';
  static const String cancelar = 'Cancelar';
  static const String confirmar = 'Confirmar';
  static const String eliminar = 'Eliminar';
  static const String reintentar = 'Reintentar';
  static const String volver = 'Volver';
  static const String cargando = 'Cargando...';
  static const String proximamente = 'Próximamente';

  // ---------------------------------------------------------------------
  // Estados genéricos de pantalla
  // ---------------------------------------------------------------------
  static const String estadoVacioTitulo = 'Aún no hay nada por aquí';
  static const String errorTitulo = 'Algo salió mal';

  // ---------------------------------------------------------------------
  // Validaciones de formularios
  // ---------------------------------------------------------------------
  static const String validacionObligatorio = 'Este campo es obligatorio';
  static const String validacionCorreo = 'Ingresa un correo válido';
  static const String validacionContrasenaCorta =
      'La contraseña debe tener mínimo 6 caracteres';
  static const String validacionContrasenasDistintas =
      'Las contraseñas no coinciden';
  static const String validacionNombreCorto = 'Ingresa tu nombre completo';
  static const String validacionNombreLargo =
      'El nombre no puede superar 50 caracteres';
  static const String validacionNombreCaracteres =
      'El nombre solo puede contener letras y espacios';

  // ---------------------------------------------------------------------
  // Errores (usados por FirebaseErrorMapper)
  // ---------------------------------------------------------------------
  static const String errorInesperado =
      'Ocurrió un error inesperado. Intenta nuevamente.';
  static const String errorSinConexion =
      'Sin conexión a internet. Intenta nuevamente.';
  static const String errorTiempoAgotado =
      'La operación tardó demasiado. Intenta nuevamente.';
  static const String errorSinPermiso =
      'No tienes permiso para realizar esta acción.';
  static const String errorSesionRequerida =
      'Tu sesión expiró. Inicia sesión nuevamente.';
  static const String errorNoEncontrado = 'No se encontró la información.';
  static const String errorYaExiste = 'Este elemento ya existe.';
  static const String errorServicioNoDisponible =
      'El servicio no está disponible en este momento. Intenta más tarde.';
  static const String errorLimiteExcedido =
      'Se alcanzó el límite de uso. Intenta más tarde.';
  static const String errorOperacionCancelada = 'La operación fue cancelada.';
  static const String errorDatosInvalidos =
      'Los datos enviados no son válidos.';
  static const String errorImagenInvalida =
      'No se pudo leer la imagen. Elige otra foto.';

  // Google Sign-In
  static const String errorGoogleCancelado =
      'Cancelaste el inicio de sesión con Google.';
  static const String errorGoogleInterrumpido =
      'El inicio de sesión con Google fue interrumpido. Intenta nuevamente.';
  static const String errorGoogleConfiguracion =
      'El inicio de sesión con Google no está configurado correctamente '
      'para esta app.';
  static const String errorGoogleGenerico =
      'No se pudo iniciar sesión con Google. Intenta nuevamente.';

  // Firebase Authentication
  static const String errorAuthCorreoInvalido =
      'El correo ingresado no es válido.';
  static const String errorAuthCuentaDeshabilitada =
      'Esta cuenta ha sido deshabilitada.';
  static const String errorAuthUsuariaNoExiste =
      'No existe una cuenta con este correo.';
  static const String errorAuthCredencialesIncorrectas =
      'Correo o contraseña incorrectos.';
  static const String errorAuthCorreoEnUso =
      'Ya existe una cuenta con este correo. Intenta iniciar sesión.';
  static const String errorAuthContrasenaDebil =
      'La contraseña es demasiado débil (mínimo 6 caracteres).';
  static const String errorAuthDemasiadosIntentos =
      'Demasiados intentos fallidos. Intenta más tarde.';
  static const String errorAuthMetodoNoHabilitado =
      'Este método de inicio de sesión no está habilitado.';
  static const String errorAuthCuentaOtroMetodo =
      'Ya existe una cuenta con este correo usando otro método '
      'de inicio de sesión.';
  static const String errorAuthReautenticar =
      'Por seguridad, vuelve a ingresar tu contraseña para continuar.';
  static const String errorAuthCuentaDistinta =
      'La cuenta ingresada no coincide con la sesión actual.';
  static const String errorAuthCamposVacios =
      'Completa todos los campos para continuar.';

  // Cloud Firestore
  static const String errorFirestoreAbortado =
      'La operación no pudo completarse por un conflicto. Intenta nuevamente.';

  // Firebase Storage
  static const String errorStorageArchivoNoExiste =
      'El archivo solicitado no existe.';
  static const String errorStorageCuota =
      'Se superó el espacio de almacenamiento disponible.';
  static const String errorStorageReintentos =
      'No se pudo subir el archivo. Revisa tu conexión e intenta nuevamente.';
  static const String errorStorageArchivoDanado =
      'El archivo se dañó durante la subida. Intenta nuevamente.';

  // Cloud Functions
  static const String errorFunctionsInterno =
      'Ocurrió un error en el servidor. Intenta más tarde.';
  static const String errorFunctionsPrecondicion =
      'No se cumplen las condiciones para realizar esta acción.';

  // ---------------------------------------------------------------------
  // Fechas (datetime_extensions)
  // ---------------------------------------------------------------------
  static const List<String> meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  static const String hoy = 'Hoy';
  static const String ayer = 'Ayer';
  static const String haceUnMomento = 'Hace un momento';
  static String haceMinutos(int n) => 'Hace $n min';
  static String haceHoras(int n) => n == 1 ? 'Hace 1 hora' : 'Hace $n horas';
  static String haceDias(int n) => 'Hace $n días';

  // ---------------------------------------------------------------------
  // Etiquetas de enums (enum_labels)
  // ---------------------------------------------------------------------
  static const String estacionPrimavera = 'Primavera';
  static const String estacionVerano = 'Verano';
  static const String estacionOtono = 'Otoño';
  static const String estacionInvierno = 'Invierno';

  static const String subtonoCalido = 'Cálido';
  static const String subtonoFrio = 'Frío';
  static const String subtonoNeutro = 'Neutro';

  // Colorimetría — Jaider
  static const String contrasteBajo = 'Bajo';
  static const String contrasteMedio = 'Medio';
  static const String contrasteAlto = 'Alto';

  static const String intensidadSuave = 'Suave';
  static const String intensidadMedia = 'Media';
  static const String intensidadBrillante = 'Brillante';

  // ---------------------------------------------------------------------
  // Colorimetría y paleta — Jaider
  // ---------------------------------------------------------------------

  // Consentimiento biométrico
  static const String consentimientoTitulo = 'Antes de tomar tu selfie';
  static const String consentimientoQueCapturamos =
      'Qué capturamos: una foto de tu rostro (selfie).';
  static const String consentimientoParaQue =
      'Para qué: analizar el tono de tu piel, ojos y cabello y así '
      'calcular tu estación de color, subtono y paleta.';
  static const String consentimientoBorrado =
      'Qué pasa con la foto: se usa solo para este análisis y se borra '
      'automáticamente al terminar (como máximo en una hora). Solo '
      'guardamos el resultado, nunca la imagen.';
  static const String consentimientoEliminacion =
      'Cómo pedir la eliminación: puedes borrar tu resultado repitiendo '
      'el análisis o eliminando tu cuenta desde Perfil.';
  static const String consentimientoCasilla =
      'Acepto que se use mi selfie para el análisis de colorimetría.';
  static const String continuar = 'Continuar';

  // Permisos
  static const String permisoCamaraDenegado =
      'Necesitamos la cámara para tomar tu selfie.';
  static const String permisoCamaraPermanente =
      'Bloqueaste el acceso a la cámara. Actívalo en los ajustes del '
      'teléfono para continuar.';
  static const String permitirCamara = 'Permitir cámara';
  static const String abrirAjustes = 'Abrir ajustes';

  // Pantalla de colorimetría
  static const String colorimetriaTitulo = 'Tu colorimetría';
  static const String colorimetriaSinAnalisisMensaje =
      'Tómate una selfie y descubre tu estación de color, tu subtono y '
      'los colores que más te favorecen.';
  static const String iniciarAnalisis = 'Iniciar análisis';
  static const String repetirAnalisis = 'Repetir análisis';
  static const String repetirAnalisisTitulo = '¿Repetir el análisis?';
  static const String repetirAnalisisMensaje =
      'Tu resultado actual se reemplazará por el del nuevo análisis.';
  static const String repetir = 'Repetir';
  static const String verMiPaletaBoton = 'Ver mi paleta';
  static const String etiquetaSubtono = 'Subtono';
  static const String etiquetaContraste = 'Contraste';
  static const String etiquetaIntensidad = 'Intensidad';
  static const String etiquetaConfianza = 'Confianza';
  static String analizadoEl(String fecha) => 'Analizado el $fecha';

  // Captura de selfie
  static const String capturaTitulo = 'Toma tu selfie';
  static const String capturaGuia = 'Ubica tu rostro dentro del óvalo';
  static const List<String> capturaConsejos = [
    'Luz natural de frente, sin sombras',
    'Sin maquillaje, filtros ni lentes',
    'Recoge tu cabello para que se vea tu rostro',
  ];
  static const String usarFoto = 'Usar foto';
  static const String repetirFoto = 'Repetir';
  static const String preparandoFoto = 'Preparando tu foto…';
  static const String errorCamaraNoDisponible =
      'No encontramos una cámara disponible en este dispositivo.';
  static const String errorCamara =
      'No pudimos abrir la cámara. Inténtalo de nuevo.';

  // Análisis
  static const String analisisTitulo = 'Analizando tu selfie';
  static const String subiendoSelfie = 'Subiendo tu selfie…';
  static const List<String> analisisMensajes = [
    'Detectando el tono de tu piel…',
    'Observando tus ojos y tu cabello…',
    'Calculando tu subtono…',
    'Midiendo tu contraste natural…',
    'Buscando tu estación de color…',
  ];
  static const String analisisNoSeGuardaFoto =
      'Tu foto se borra apenas termina el análisis.';
  static const String tomarOtraFoto = 'Tomar otra foto';
  static const String errorAnalisisTitulo = 'No pudimos analizar tu selfie';

  // Resultado
  static const String resultadoTitulo = 'Tu resultado';
  static const String guardandoResultado = 'Guardando tu resultado…';
  static const String errorGuardarResultado =
      'No pudimos guardar tu resultado. Revisa tu conexión e inténtalo de nuevo.';
  static const String volverAlInicio = 'Volver al inicio';
  static const String queSignificaSubtono = '¿Qué significa tu subtono?';
  static const String subtonoCalidoDetalle =
      'Tu piel tiene reflejos dorados o melocotón. Te favorecen los colores '
      'con base amarilla: corales, dorados, verdes oliva y tonos tierra.';
  static const String subtonoFrioDetalle =
      'Tu piel tiene reflejos rosados o azulados. Te favorecen los colores '
      'con base azul: fucsias, azules, esmeraldas y plateados.';
  // Paleta
  static const String paletaTitulo = 'Mi paleta';
  static const String tusColores = 'Tus colores';
  static const String pestanaRopa = 'Ropa';
  static const String pestanaMaquillaje = 'Maquillaje';
  static const String pestanaEvitar = 'Evitar';
  static const String seccionBasicos = 'Básicos';
  static const String seccionBasicosAyuda =
      'Para prendas grandes: pantalones, abrigos, bolsos y zapatos.';
  static const String seccionDestacar = 'Para destacar';
  static const String seccionDestacarAyuda =
      'Para blusas, camisas y accesorios cerca del rostro.';
  static const String seccionLabiales = 'Labiales';
  static const String seccionRubores = 'Rubores';
  static const String seccionSombras = 'Sombras';
  static const String seccionBase = 'Tu base';
  static const String seccionEvitarAyuda =
      'Lejos del rostro apagan tu tono; mejor no usarlos en blusas ni '
      'maquillaje.';
  static const String paraTuRopa = 'Para tu ropa';
  static const String paraTuMaquillaje = 'Para tu maquillaje';
  static const String baseCalida =
      'Busca bases con subtono dorado o amarillo.';
  static const String baseFria = 'Busca bases con subtono rosado.';
  static const String baseNeutra =
      'Busca bases neutras: ni muy rosadas ni muy amarillas.';
  static const String coloresAEvitar = 'Colores a evitar';
  static String paletaDeEstacion(String estacion) => 'Paleta de $estacion';
  static const String paletaToca =
      'Toca un color para ver su nombre y código.';
  static const String paletaSinAnalisisMensaje =
      'Haz tu análisis de colorimetría para conocer los colores que más '
      'te favorecen.';
  static const String paletaVacia = 'Esta paleta aún no tiene colores.';
  static const String copiarHex = 'Copiar código';
  static String hexCopiado(String hex) => '$hex copiado';
  static const String colorRecomendado = 'Te favorece';
  static const String colorAEvitar = 'Mejor evitarlo cerca del rostro';
  static const String errorSinPerfilColorimetria =
      'Primero haz tu análisis de colorimetría.';

  static const String subtonoNeutroDetalle =
      'Tu piel combina reflejos cálidos y fríos. Puedes usar colores de '
      'ambas familias, sobre todo en sus versiones intermedias.';

  // Errores del análisis
  static const String errorRostroNoDetectado =
      'No pudimos detectar tu rostro. Toma otra foto de frente y sin '
      'accesorios que lo cubran.';
  static const String errorImagenOscura =
      'La foto está muy oscura. Busca luz natural y vuelve a intentarlo.';

  static const String tipoMaquillaje = 'Maquillaje';
  static const String tipoOutfit = 'Outfit';
  static const String tipoCabello = 'Cabello';

  // ---------------------------------------------------------------------
  // Rutas
  // ---------------------------------------------------------------------
  static const String enConstruccion = 'En construcción';
  static const String enConstruccionDescripcion =
      'Esta pantalla todavía se está desarrollando.';
  static String pantallaResponsable(String pantalla, String responsable) =>
      'Pantalla: $pantalla\nResponsable: $responsable';
  static const String rutaNoEncontrada = 'Ruta no encontrada';
  static const String funcionDeshabilitada =
      'Esta función estará disponible próximamente.';

  // ---------------------------------------------------------------------
  // Catálogo de administración — Ana
  // ---------------------------------------------------------------------
  static const String catalogoTitulo = 'Catálogo';
  static const String pestanaPrendas = 'Prendas';
  static const String pestanaProductos = 'Productos';
  static const String buscarEnCatalogo = 'Buscar por nombre...';
  static const String filtroTodas = 'Todas';
  static const String filtroCategoria = 'Categoría';
  static const String filtroEstacion = 'Estación';
  static const String limpiarFiltros = 'Limpiar filtros';
  static const String nuevaPrenda = 'Nueva prenda';
  static const String nuevoProducto = 'Nuevo producto';
  static const String editar = 'Editar';
  static const String activar = 'Activar';
  static const String desactivar = 'Desactivar';
  static const String itemInactivo = 'Inactivo';
  static const String cargarMas = 'Cargar más';
  static const String catalogoVacioTitulo = 'El catálogo está vacío';
  static const String catalogoVacioMensaje =
      'Agrega el primer ítem para que las usuarias reciban recomendaciones.';
  static const String catalogoSinResultadosTitulo = 'Sin resultados';
  static const String catalogoSinResultadosMensaje =
      'Ningún ítem coincide con la búsqueda o los filtros.';
  static const String eliminarItemTitulo = '¿Eliminar este ítem?';
  static String eliminarItemMensaje(String nombre) =>
      '"$nombre" se borrará del catálogo junto con su imagen. '
      'Esta acción no se puede deshacer.';
  static const String itemEliminado = 'Ítem eliminado del catálogo';
  static const String itemActivado = 'Ítem activado';
  static const String itemDesactivado = 'Ítem desactivado';
  static const String sinNombre = 'Sin nombre';

  // Categorías de prenda y producto (EtiquetasTexto.categoria)
  static const String categoriaSuperior = 'Superior';
  static const String categoriaInferior = 'Inferior';
  static const String categoriaVestido = 'Vestido';
  static const String categoriaAbrigo = 'Abrigo';
  static const String categoriaAccesorio = 'Accesorio';
  static const String categoriaLabial = 'Labial';
  static const String categoriaRubor = 'Rubor';
  static const String categoriaSombra = 'Sombra';
  static const String categoriaBase = 'Base';

  // Ocasiones (EtiquetasTexto.ocasion)
  static const String ocasionTrabajo = 'Trabajo';
  static const String ocasionCasual = 'Casual';
  static const String ocasionFiesta = 'Fiesta';
  static const String ocasionEntrevista = 'Entrevista';
  static const String ocasionCita = 'Cita';
  static const String ocasionDeporte = 'Deporte';
}
