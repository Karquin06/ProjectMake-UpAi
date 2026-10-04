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
  static const String iniciaSesionParaContinuar = 'Inicia sesión para continuar';
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
  static const String terminosYPrivacidad =
      'Al registrarte aceptas nuestros Términos de uso y Política de privacidad.';

  // Home
  static const String inicio = 'Inicio';
  static const String colorimetriaTab = 'Colorimetría';
  static const String asistenteTab = 'Asistente';
  static const String perfilTab = 'Perfil';

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
  static const String errorDatosInvalidos = 'Los datos enviados no son válidos.';
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
  static const String errorAuthCorreoInvalido = 'El correo ingresado no es válido.';
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
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
    'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
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
}
